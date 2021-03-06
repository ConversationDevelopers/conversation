/* 
 Copyright (c) 2014-2015, Tobias Pollmann.
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holders nor the names of its contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "IRCConnection.h"
#import "IRCClient.h"

#define floodControlInterval 2
#define floodControlMessageLimit 4

@interface IRCConnection ()

@property (nonatomic, assign) BOOL sslEnabled;
@property (nonatomic, assign) BOOL floodControlEnabled;
@property (nonatomic, strong) IRCClient *client;
@property (nonatomic, strong) NSTimer *floodControlTimer;
@property (nonatomic, strong) NSMutableArray *messageQueue;
@property (nonatomic, assign) int messagesSentSinceLastTick;
@property (nonatomic, strong) NSString *connectionHost;
@property (nonatomic, assign) UInt16 connectionPort;
@end

@implementation IRCConnection

- (id)initWithClient:(IRCClient *)client
{
    if ((self = [super init])) {
        self.sslEnabled = NO;
        self.client = client;
        
        /* Initialise dispatch queue used for parsing incoming data from this connection */
        NSString *queueName = [@"conversation-client-" stringByAppendingString:self.client.configuration.uniqueIdentifier];
        queue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);
        
        self.messagesSentSinceLastTick = 0;
        self.messageQueue = [[NSMutableArray alloc] init];
        self.floodControlEnabled = NO;
        self.floodControlTimer = nil;
        return self;
    }
    return nil;
}

- (void)connectToHost:(NSString *)host onPort:(UInt16)port useSSL:(BOOL)sslEnabled
{
    self.sslEnabled = sslEnabled;
    NSError *err = nil;
    
    /* Initialise socket and ensure it uses our queue to operate off the UI thread */
    socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    self.connectionHost = host;
    self.connectionPort = port;
    
    /* Establish a TCP connection */
    if (![socket connectToHost:host onPort:port withTimeout:15.0 error:&err]) {
        [self.client outputToConsole:[NSString stringWithFormat:NSLocalizedString(@"Could not connect: %@", @"Could not connect: {Error}"), err]];
    } else {
        [self.client outputToConsole:[NSString stringWithFormat:NSLocalizedString(@"Connecting to [%@] on port %d", @"Connecting to [{host name}] on port {port number}"), host, port]];
    }
}

/*!
 *    @brief  Called when a connection to the host has been established.
 *
 *    @param sock The GCDAsyncSocket object of the established connection.
 *    @param host The remote hostname or IP address of the established connection.
 *    @param port The port which the connection was established on.
 */
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    [self.client outputToConsole:[NSString stringWithFormat:NSLocalizedString(@"Connection to host at [%@] established.", @"Connection to host at [{host name}] established."), host]];
    
    /* Start SSL/TLS handshake if appropriate */
    if (self.client.configuration.connectUsingSecureLayer) {
        NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:1];
        [settings setObject:@YES forKey:GCDAsyncSocketManuallyEvaluateTrust];
        [socket startTLS:settings];
    }
    
    [self.client clientDidConnect];
    
    /* The server will probably send us some initial data, let's queue up a read immediately */
    [socket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:1];
}

/*!
 *    @brief  Called when an SSL handshake has been initialised and we have to evaluate a remote certificate.
 *
 *    @param sock              The GCDAsyncSocket object of the established connection.
 *    @param trust             The SSL trust reference of this certificate.
 *    @param completionHandler Completion handler to call with whether or not to allow this connection.
 */
- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler
{
    SecTrustResultType trustResult;
    SecTrustEvaluate(trust, &trustResult);
	
	self.client.certificate = trust;
    
    switch (trustResult) {
        case kSecTrustResultProceed:
        case kSecTrustResultUnspecified:
            /* This certificate is completely valid, we can proceed with no further issue */
            completionHandler(YES);
            break;
            
        case kSecTrustResultInvalid:
        case kSecTrustResultRecoverableTrustFailure: {
            /* An issue occured validating this certificate, it might have some mismatching information
             or it is simply unsigned. Many users run small IRC users or bouncers on sunsigned certificates
             so we will present this predicament to the user and let them decide what to do. */
            IRCCertificateTrust *trustDialog = [[IRCCertificateTrust alloc] init:trust onClient:self.client];
            [trustDialog requestTrustFromUser:completionHandler];
            break;
        }
        
        case kSecTrustResultDeny:
        case kSecTrustResultFatalTrustFailure:
        case kSecTrustResultOtherError:
            /* The ssl verification encountered an unrecoverable error. We will terminate the connection immediately. */
            completionHandler(NO);
            [self.client disconnect];
            break;
    }
}

/*!
 *    @brief  Called when data has been successfully written to the socket.
 *
 *    @param sock The GCDAsyncSocket object of the established connection.
 *    @param tag  An arbitrary long value which has been passed to identity the origin of this data.
 */
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    if (tag == 0) {
        [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
    }
    [self.client clientDidSendData];
}

/*!
 *    @brief  Called when the socket has read some data.
 *
 *    @param sock The GCDAsyncSocket object of the established connection.
 *    @param data The data received from the socket.
 *    @param tag  An arbitrary long value which has been passed to identity the origin of this data.
 */
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    dispatch_async(queue, ^{
        /* While the socket is supposed to only read to the next linebreak we may at some point
         encounter a data overflow, therefor we will manually validate the input from the socket
         and truncate the message at any potential linebreak before passing it to the parser */
        const char *bytes = [data bytes] + '\0';
        int positionOfLineBreak = 0;
        const char* positionBeforeIteration = bytes;
        while (*bytes != '\0' && *bytes != '\n' && *bytes != '\r') {
            bytes++;
            positionOfLineBreak++;
        }
        bytes = positionBeforeIteration;
        char* message = malloc(positionOfLineBreak +1);
        strncpy(message, bytes, positionOfLineBreak);
        message[positionOfLineBreak] = '\0';
        
        if (message) {
            [self.client clientDidReceiveData:message];
        } else {
            [self.client outputToConsole:[NSString stringWithFormat:NSLocalizedString(@"Unable to decode message: %s", @"Unable to decode message: {raw message}"), message]];
        }
        [socket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:1];
        free(message);
    });
}

/*!
 *    @brief  Called when an SSL connection has been successfuly established and the handshake is complete.
 *
 *    @param sock The GCDAsyncSocket object of the established connection.
 */
- (void)socketDidSecure:(GCDAsyncSocket *)sock
{
    NSLog(@"onSocketDidSecure:%p", sock);
    [self.client outputToConsole:[NSString stringWithFormat:NSLocalizedString(@"Connection secured using %@", @"Connection secured using {encryption scheme}"), [IRCConnection getSSLProtocolAsString:sock]]];
}

/*!
 *    @brief  Called when the socket was disconnected due to an error.
 *
 *    @param socket The GCDAsyncSocket object of the established connection.
 *    @param err    An NSError instance representing the error.
 */
- (void)socketDidDisconnect:(GCDAsyncSocket *)socket withError:(NSError *)err
{
    if (err == nil || [err code] == errSSLClosedGraceful) {
        return;
    }
    
    NSString *errorMessage = nil;
    if ([self badSSLCertificateErrorFound:err]) {
        [self.client outputToConsole:NSLocalizedString(@"Disconnected from server due to an untrusted SSL certificate",
														@"Disconnected from server due to an untrusted SSL certificate")];
    } else {
        if ([err.domain isEqualToString:NSPOSIXErrorDomain]) {
            const char *error = strerror((int)err.domain);
            errorMessage = [NSString stringWithCString:error encoding:NSUTF8StringEncoding];
        } else {
            errorMessage = [err.userInfo objectForKey:@"NSLocalizedDescription"];
            if (errorMessage == nil) {
                errorMessage = [err localizedDescription];
            }
        }
    }
    [self.client clientDidDisconnectWithError:errorMessage];
}

/*!
 *    @brief  Check if an error is an SSL certificate validation failure state.
 *
 *    @param error The NSError object to check for SSL validation error codes.
 *
 *    @return A boolean value indicating whether this is an SSL certificate validation error.
 */
- (BOOL)badSSLCertificateErrorFound:(NSError *)error
{
    if ([error.domain isEqualToString:@"kCFStreamErrorDomainSSL"]) {
        NSArray *errorCodes = @[
                                @(errSSLBadCert),
                                @(errSSLNoRootCert),
                                @(errSSLCertExpired),
                                @(errSSLPeerBadCert),
                                @(errSSLPeerCertRevoked),
                                @(errSSLPeerCertExpired),
                                @(errSSLPeerCertUnknown),
                                @(errSSLUnknownRootCert),
                                @(errSSLCertNotYetValid),
                                @(errSSLXCertChainInvalid),
                                @(errSSLPeerUnsupportedCert),
                                @(errSSLPeerUnknownCA),
                                @(errSSLHostNameMismatch
                                )];
        
        return [errorCodes containsObject:@([error code])];
    }
    
    return NO;
}

/*!
 *    @brief  Called when the socket is gracefully disconnected.
 *
 *    @param sock The GCDAsyncSocket object of the established connection.
 */
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock
{
    [self.messageQueue removeAllObjects];
    [self.client clientDidDisconnect];
}

/*!
 *    @brief  Write data to the socket.
 *
 *    @param data The encoded data to write.
 */
- (void)writeDataToSocket:(NSData *)data
{
    [socket writeData:data withTimeout:-1 tag:1];
}

- (void)close
{
    if (socket) {
        [socket disconnect];
        [socket setDelegate:nil delegateQueue:NULL];
        [self.messageQueue removeAllObjects];
        [self.client clientDidDisconnect];
    }
}

- (void)sendData:(NSString *)line
{
    if ([line hasSuffix:@"\r\n"] == NO) {
        line = [line stringByAppendingString:@"\r\n"];
    }
    NSLog(@">> %@", line);
    NSData *data = [line dataUsingEncodingFromConfiguration:self.client.configuration];
    [self writeDataToSocket:data];
}

- (void)enableFloodControl {
    /* Enable flood control. This will ensure no more than 5 messages every 2 seconds get sent over the connection.
     This is necessary because many servers employ anti attack measures that will forcibly disconnect us if we overwhelm
     the server with messages. */
    self.floodControlEnabled = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.floodControlTimer = [NSTimer scheduledTimerWithTimeInterval:floodControlInterval
                                                                  target:self
                                                                selector:@selector(floodTimerTick)
                                                                userInfo:nil
                                                                 repeats:YES];
    });
}

- (void)disableFloodControl {
    /* The flood control is no longer necessary. We will disable it.*/
    self.floodControlEnabled = NO;
    [self.floodControlTimer invalidate];
    self.floodControlTimer = nil;
}

/*!
 *    @brief  This method is activated by a time every two seconds. It will clear the message limit and send any messages currently backlogged until the limit is reached again.
 */
- (void)floodTimerTick {
    self.messagesSentSinceLastTick = 0;
    BOOL messageQueueIsSendingItems = YES;
    while (messageQueueIsSendingItems) {
        messageQueueIsSendingItems = [self continueSending];
    }
}

- (void)send:(NSString *)line
{
    /* Add the outgoing message to our queue and attempt to send it immediately. 
     If the flood control is on a backlog it might not be sent right away. */
    [self.messageQueue addObject:line];
    [self continueSending];
}

/*!
 *    @brief  Attempt to send any eventual messages in the queue to the socket.
 *
 *    @return A boolean indicating whether we were successful in sending data or we have reached the message limit.
 */
- (BOOL)continueSending
{
    @synchronized(self) {
        /* There are no messages in the queue, we have nothing to do. */
        if ([self.messageQueue count] == 0 || self.client.isConnected == NO) {
            return NO;
        }
        
        if (self.floodControlEnabled) {
            /* We have reached the message limit, messages are now backloged until the next flood control tick.
             We wil llet the queue handler know it must stop attempting a send until the next tick. */
            if (self.messagesSentSinceLastTick > floodControlMessageLimit) {
                return NO;
            }
            
            self.messagesSentSinceLastTick++;
        }
        
        /* We are under the message limit and are free to send the message to the server.
         We will send it to the socket and clear it from the queue immediately. */
        NSString *queueItemToSend = [self.messageQueue objectAtIndex:0];
        [self sendData:queueItemToSend];
        [self.messageQueue removeObjectAtIndex:0];
        return YES;
    }
}

/*!
 *    @brief  Get a human readable localised text indicating the SSL technology used for this connection.
 *
 *    @param socket The GCDAsyncSocket object to use for deciding the SSL connection details.
 *
 *    @return A localised string with the SSL technology and version used.
 */
+ (NSString *) getSSLProtocolAsString:(GCDAsyncSocket*)socket
{
    __block SSLProtocol protocol;
    
    OSStatus status = SSLGetNegotiatedProtocolVersion(socket.sslContext, &protocol);
    #pragma unused(status)
    
    switch (protocol) {
        case kSSLProtocol2:
            return NSLocalizedString(@"Secure Sockets Layer (SSL) version 2.0", @"Secure Sockets Layer (SSL) version 2.0");
        case kSSLProtocol3:
        case kSSLProtocol3Only:
            return NSLocalizedString(@"Secure Sockets Layer (SSL) version 3.0", @"Secure Sockets Layer (SSL) version 3.0");
        case kTLSProtocol1:
        case kTLSProtocol1Only:
            return NSLocalizedString(@"Transport Layer Security (TLS) version 1.0", @"Transport Layer Security (TLS) version 1.0");
        case kTLSProtocol11:
            return NSLocalizedString(@"Transport Layer Security (TLS) version 1.1", @"Transport Layer Security (TLS) version 1.1");
        case kTLSProtocol12:
            return NSLocalizedString(@"Transport Layer Security (TLS) version 1.2", @"Transport Layer Security (TLS) version 1.2");
        default:
            return NSLocalizedString(@"unknown security layer", @"unknown security layer");
    }
}

@end

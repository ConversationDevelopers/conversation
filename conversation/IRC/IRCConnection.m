/* 
 Copyright (c) 2014-2015, Tobias Pollmann, Alex Sørlie Glomsaas.
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
        NSLog(@"Error: %@", err);
    } else {
        NSLog(@"Connecting..");
    }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"onSocket:%p didConnectToHost:%@ port:%hu", sock, host, port);
    
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

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler {
    
    /* A TLS/SSL handshake has been initialised, let's verify the certificate. */
    SecTrustResultType trustResult;
    SecTrustEvaluate(trust, &trustResult);
    
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

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    if (tag == 0) {
        [sock readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:0];
    }
    [self.client clientDidSendData];
}

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
            NSLog(@"Read msg error: %s",message);
        }
        [socket readDataToData:[GCDAsyncSocket CRLFData] withTimeout:-1 tag:1];
        free(message);
    });
}

- (void)socketDidSecure:(GCDAsyncSocket *)sock
{
    NSLog(@"onSocketDidSecure:%p", sock);
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)socket withError:(NSError *)err
{
    if (err == nil) return;
    
    NSString *errorMessage = nil;
    if ([err.domain isEqualToString:NSPOSIXErrorDomain]) {
        const char *error = strerror((int)err.domain);
        errorMessage = [NSString stringWithCString:error encoding:NSUTF8StringEncoding];
    } else {
        errorMessage = [err.userInfo objectForKey:@"NSLocalizedDescription"];
        if (errorMessage == nil) {
            errorMessage = [err localizedFailureReason];
        }
    }
    [self.client clientDidDisconnectWithError:errorMessage];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock
{
    [self.messageQueue removeAllObjects];
    [self.client clientDidDisconnect];
}

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

- (void)floodTimerTick {
    /* This method is activated by a time every two seconds. It will clear the message limit
     and send any messages currently backlogged until the limit is reached again. */
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

- (BOOL)continueSending
{
    /* There are no messages in the queue, we have nothing to do. So we will let the queue handler know
     the flood gates are open. */
    @synchronized(self) {
        
        if ([self.messageQueue count] == 0) {
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

@end

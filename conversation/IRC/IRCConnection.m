/* 
 Copyright (c) 2014, Tobias Pollmann, Alex Sørlie Glomsaas.
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
#define floodControlMessageLimit 5

@interface IRCConnection ()

@property (nonatomic, assign) BOOL sslEnabled;
@property (nonatomic, assign) BOOL floodControlEnabled;
@property (nonatomic, strong) IRCClient *client;
@property (nonatomic, strong) NSTimer *floodControlTimer;
@property (nonatomic, strong) NSMutableArray *messageQueue;
@property (nonatomic, assign) int messagesSentSinceLastTick;

@end

@implementation IRCConnection

- (id)initWithClient:(IRCClient *)client
{
    if ((self = [super init])) {
        self.sslEnabled = NO;
        self.client = client;
        
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
    asyncSocket = [[AsyncSocket alloc] initWithDelegate:self];
    if (![asyncSocket connectToHost:host onPort:port error:&err]) {
        NSLog(@"Error: %@", err);
    } else {
        NSLog(@"Connecting..");
    }
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"onSocket:%p didConnectToHost:%@ port:%hu", sock, host, port);
    
    // Configure SSL/TLS settings
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:3];
    
    [settings setObject:host forKey:(NSString *)kCFStreamSSLPeerName];
    
    // Skip certificate validation. FOR TESTING PURPOSES ONLY DO NEVER LET THIS GET INTO PRODUCTION EVER.
    [settings setObject:[NSNumber numberWithBool:NO] forKey:(NSString *)kCFStreamSSLValidatesCertificateChain];
    
    if (self.client.configuration.connectUsingSecureLayer) {
        [sock startTLS:settings];
    }
    
    [self.client clientDidConnect];
    
    [asyncSocket readDataToData:[AsyncSocket CRLFData] withTimeout:-1 tag:1];
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    if (tag == 0) {
        [sock readDataToData:[AsyncSocket CRLFData] withTimeout:-1 tag:0];
    }
    [self.client clientDidSendData];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
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
    [asyncSocket readDataToData:[AsyncSocket CRLFData] withTimeout:-1 tag:1];
}

- (void)onSocketDidSecure:(AsyncSocket *)sock
{
    NSLog(@"onSocketDidSecure:%p", sock);
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
    [self.client clientDidDisconnectWithError:[err localizedFailureReason]];
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
    [self.messageQueue removeAllObjects];
    [self.client clientDidDisconnect];
}

- (void)writeDataToSocket:(NSData *)data
{
    [asyncSocket writeData:data withTimeout:-1 tag:1];
}

- (void)close
{
    [asyncSocket disconnectAfterReadingAndWriting];
}

- (void)sendData:(NSString *)line
{
    if ([line hasSuffix:@"\r\n"] == NO) {
        line = [line stringByAppendingString:@"\r\n"];
    }
    NSLog(@">> %@", line);
    NSData *data = [line dataUsingEncoding:self.client.configuration];
    [self writeDataToSocket:data];
}

- (void)enableFloodControl {
    self.floodControlEnabled = YES;
    self.floodControlTimer = [NSTimer scheduledTimerWithTimeInterval:floodControlInterval
                                                              target:self
                                                            selector:@selector(floodTimerTick)
                                                            userInfo:nil
                                                             repeats:YES];
}

- (void)disableFloodControl {
    self.floodControlEnabled = NO;
    [self.floodControlTimer invalidate];
    self.floodControlTimer = nil;
}

- (void)floodTimerTick {
    self.messagesSentSinceLastTick = 0;
    BOOL messageQueueIsSendingItems = YES;
    while (messageQueueIsSendingItems) {
        messageQueueIsSendingItems = [self continueSending];
    }
}

- (void)send:(NSString *)line
{
    [self.messageQueue addObject:line];
    [self continueSending];
}

- (BOOL)continueSending
{
    if ([self.messageQueue count] == 0) {
        return NO;
    }
    
    if (self.floodControlEnabled) {
        if (self.messagesSentSinceLastTick > floodControlMessageLimit) {
            return NO;
        }
        self.messagesSentSinceLastTick++;
    }
    NSString *queueItemToSend = [self.messageQueue objectAtIndex:0];
    [self sendData:queueItemToSend];
    [self.messageQueue removeObjectAtIndex:0];
    return YES;
}

@end

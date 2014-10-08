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

#import "IRCClient.h"
#import "IRCConnection.h"

#define CONNECTION_RETRY_INTERVAL       30
#define CONNECTION_RETRY_ATTEMPTS       10
#define CONNECTION_IRC_PING_INTERVAL    280
#define CONNECTION_IRC_PONG_INTERVAL    30
#define CONNECTION_TIMEOUT_INTERVAL     300

@interface IRCClient ()

@property (nonatomic, strong) IRCConnection *connection;
@property (nonatomic, assign) BOOL connectionIsBeingClosed;
@property (nonatomic, assign) NSInteger alternativeNickNameAttempts;
@property (nonatomic, strong) NSString *currentNicknameOnConnection;
@property (nonatomic, strong) NSTimer *connectionRetryTimer;

@end

@implementation IRCClient

- (instancetype)initWithConfiguration:(IRCConnectionConfiguration *)config
{
    if ((self = [super init])) {
        /* Set the configuration associated with this connection */
        if (config) {
            self.configuration = config;
        } else {
            NSAssert(NO, @"Invalid Configuration");
        }
        
        
        /* Setup the client to a state where it is ready for a future connection attempt */
        self.connection = [[IRCConnection alloc] initWithClient:self];
        self.isConnected =                      NO;
        self.isAttemptingRegistration =         NO;
        self.isAttemptingConnection =           NO;
        self.hasSuccessfullyAuthenticated =     NO;
        self.isAwaitingAuthenticationResponse = NO;
        self.isBNCConnection =                  NO;
        self.isProcessingTermination =          NO;
        
        self.alternativeNickNameAttempts = 0;
        self.channels = [[NSDictionary alloc] init];
        
        return self;
    }
    return nil;
}

- (void)connect
{
    if (self.isConnected || self.isAttemptingConnection) {
        /* For some reason multiple connection attempts on the same instance has fired, we will ignore these */
        return;
    }
    self.isAttemptingConnection = YES;
    
    NSLog(@"Connecting to %@ on %ld", self.configuration.serverAddress, self.configuration.connectionPort);
    
    [self.connection connectToHost:self.configuration.serverAddress onPort:self.configuration.connectionPort useSSL:self.configuration.connectUsingSecureLayer];
    
}

- (void)clientDidConnect
{
    self.isConnected = YES;
    self.isAttemptingConnection = NO;
    
    NSLog(@"sending registration");
    /* Send initial registration */
    [self sendData:[NSString stringWithFormat:@"NICK %@",
                    self.configuration.primaryNickname]];
    [self sendData:[NSString stringWithFormat:@"USER %@ 0 * :%@",
                    self.configuration.usernameForRegistration,
                    self.configuration.realNameForRegistration]];
}

- (void)clientDidReceiveData:(const char *)line
{
    NSLog(@"Received: %s", line);
    BOOL isServerMessage = NO;
    
    long messageLength = strlen(line);
    const char* messageBounds = line + messageLength - 2;
    
    if (*line != ':' || messageLength < 3) {
        /* This is not a valid IRC message, we will ignore it. */
        return;
    }
    
    /* Consume the : at the start of the message. */
    line++;
    
    long senderLength   = 0;
    long nicknameLength = 0;
    long usernameLength = 0;
    
    char* lineBeforeIteration = malloc(strlen(line));
    strcpy(lineBeforeIteration, line);
    
    
    while (line != messageBounds && *line != ' ' && *line != '!') {
        nicknameLength++;
        line++;
        senderLength++;
    }
    if (*line != ' ') {
        while (line != messageBounds && *line != ' ' && *line != '@') {
            usernameLength++;
            line++;
            senderLength++;
        }
        while (line != messageBounds && *line != ' ') {
            senderLength++;
            line++;
        }
    } else {
        isServerMessage = YES;
    }
    
    char* sender = malloc(senderLength);
    strncpy(sender, lineBeforeIteration, senderLength);
    
    char* nickname = malloc(nicknameLength);
    strncpy(nickname, lineBeforeIteration, nicknameLength);
    lineBeforeIteration = lineBeforeIteration + nicknameLength + 1;
    
    
    NSLog(@"sender: %s\n", sender);
    NSLog(@"nick: %s\n", nickname);
    
    char* username = malloc(usernameLength -1);
    if (usernameLength > 0) {
        strncpy(username, lineBeforeIteration, usernameLength -1);
        lineBeforeIteration = lineBeforeIteration + usernameLength;
        
        NSLog(@"username: %s\n", username);
    }
    
    long hostnameLength = (senderLength - usernameLength - nicknameLength -2);
    char* hostname = malloc(hostnameLength);
    if (hostnameLength > 0) {
        strncpy(hostname, lineBeforeIteration, hostnameLength);
        NSLog(@"host: %s\n", hostname);
    }
}

- (void)clientDidSendData
{
}

- (void)sendData:(NSString *)line
{
    if ([line hasSuffix:@"\n"] == NO) {
        line = [line stringByAppendingString:@"\n"];
    }
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    [self.connection writeDataToSocket:data];
}

@end
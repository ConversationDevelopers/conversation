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
#import "NSString+Methods.h"
#import "IRCChannel.h"

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
        self.featuresSupportedByServer = [[NSMutableDictionary alloc] init];
        
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
    
    /* Send initial registration */
    [self sendData:[NSString stringWithFormat:@"NICK %@",
                    self.configuration.primaryNickname]];
    [self sendData:[NSString stringWithFormat:@"USER %@ 0 * :%@",
                    self.configuration.usernameForRegistration,
                    self.configuration.realNameForRegistration]];
}

- (void)clientDidReceiveData:(const char *)line
{
    NSLog(@"<< %s", line);
    BOOL isServerMessage = NO;
    
    long messageLength = strlen(line);
    const char* messageBounds = line + messageLength - 2;
    
    char* lineBeforeIteration;
    char* sender;
    char* nickname;
    char* username;
    char* hostname;
    
    
    if (*line == ':') {
        /* Consume the : at the start of the message. */
        line++;
        
        long senderLength   = 0;
        long nicknameLength = 0;
        long usernameLength = 0;
        
        /* Make a copy of the full message string */
        lineBeforeIteration = malloc(strlen(line));
        strcpy(lineBeforeIteration, line);
        
        /* Pass over the string until we either reach a space, end of message, or an exclamation mark (Part of a user's hostmask) */
        while (line != messageBounds && *line != ' ' && *line != '!') {
            nicknameLength++;
            line++;
            senderLength++;
        }
        /* If there was not an ! in this message and we have reached a space already, the sender was the server, which does not have a hostmask. */
        if (*line != ' ') {
            /* Pass over the string until we reach a space, end of message, or an @ sign (Part of the user's hostmask) */
            while (line != messageBounds && *line != ' ' && *line != '@') {
                usernameLength++;
                line++;
                senderLength++;
            }
            /* Pass over the rest of the string leading to a space, to get the position of the host address. */
            while (line != messageBounds && *line != ' ') {
                senderLength++;
                line++;
            }
        } else {
            isServerMessage = YES;
        }
        
        /* Copy the characters of the entire sender */
        sender = malloc(senderLength);
        strncpy(sender, lineBeforeIteration, senderLength);
        sender[senderLength] = '\0';
        
        /* Copy the characters of the nickname range we calculated earlier, and consume the same characters from the string as well as the following '!' */
        nickname = malloc(nicknameLength+1);
        strncpy(nickname, lineBeforeIteration, nicknameLength);
        nickname[nicknameLength] = '\0';
        lineBeforeIteration = lineBeforeIteration + nicknameLength + 1;
        
        /* Copy the characters from the username range we calculated earlier, and consume the same characters from the string as well as the following '@' */
        username = malloc(usernameLength);
        if (usernameLength > 0) {
            strncpy(username, lineBeforeIteration, usernameLength -1);
            username[usernameLength] = '\0';
            lineBeforeIteration = lineBeforeIteration + usernameLength;
        }
        
        /* Copy the characters from the hostname range we calculated earlier */
        long hostnameLength = (senderLength - usernameLength - nicknameLength -1);
        hostname = malloc(hostnameLength);
        if (hostnameLength > 0) {
            strncpy(hostname, lineBeforeIteration, hostnameLength);
            hostname[hostnameLength] = '\0';
        }
        
        lineBeforeIteration = lineBeforeIteration + hostnameLength;
        
        /* Consume the following space leading to the IRC command */
        line++;
        lineBeforeIteration++;
    } else {
        lineBeforeIteration = malloc(strlen(line));
        strcpy(lineBeforeIteration, line);
    }
    char *senderDict[] = {
        sender,
        nickname,
        username,
        hostname
    };
    
        /* Pass over the string to the next space or end of the line to get the range of the IRC command */
    int commandLength = 0;
    while (line != messageBounds && *line != ' ') {
        commandLength++;
        line++;
    }
    
    /* Copy the characters from the IRC command range we calculated earlier */
    char* command = malloc(commandLength + 1);
    strncpy(command, lineBeforeIteration, commandLength);
    command[commandLength] = '\0';
    lineBeforeIteration = lineBeforeIteration + commandLength;
    
    /* Consume the following space leading to the recepient */
    line++;
    lineBeforeIteration++;
    
    char* recipient;
    if (*line != ':') {
        /* Pass over the string to the next space or end of the line to get the range of the recipient. */
        int recipientLength = 0;
        while (line != messageBounds && *line != ' ') {
            recipientLength++;
            line++;
        }
        
        /* Copy the characters from the recipient range we calculated earlier */
        recipient = malloc(recipientLength + 1);
        strncpy(recipient, lineBeforeIteration, recipientLength);
        command[commandLength] = '\0';
        lineBeforeIteration = lineBeforeIteration + recipientLength;
        
        /* Consume the following space leading to the message */
        line++;
        lineBeforeIteration++;
    } else {
        recipient = NULL;
    }
    
    /* The message may start with a colon. We will trim this before continuing */
    if (*line == ':') {
        line++;
        lineBeforeIteration++;
    }
    
    NSString *commandString = [NSString stringWithCString:command encoding:NSUTF8StringEncoding];
    IRCMessage commandIndexValue = [IRCMessageIndex indexValueFromString:commandString];
    
    switch (commandIndexValue) {
        case PING:
            [self sendData:[NSString stringWithFormat:@"PONG :%s", line]];
            break;
        case ERROR:
            
            break;
            
        case CAP:
            
            break;
            
        case PRIVMSG:
            [self userReceivedMessage:line onRecepient:recipient byUser:senderDict];
            break;
            
        case NOTICE:
            
            break;
            
        case JOIN:
            
            break;
            
        case PART:
            
            break;
            
        case QUIT:
            
            break;
            
        case TOPIC:
            
            break;
            
        case KICK:
            
            break;
            
        case MODE:
            
            break;
            
        case NICK:
            
            break;
            
        case RPL_ISUPPORT:
            [self updateServerSupportedFeatures:line];
            break;
            
        default:
            break;
    }
}

- (void)updateServerSupportedFeatures:(const char*)data
{
    /* Create a mutable copy of the data */
    char* mline = malloc(strlen(data));
    strcpy(mline, data);
    
    /* Split the string by spaces and iterate over the result. This will give us key value pairs seperated by '=' or
     just simply keys which we will translate to booleans */
    const char delimeter[2] = " ";
    char *token;
    token = strtok(mline, delimeter);
    
    /* Iterate over the key-value pair */
    while(token != NULL) {
        /* This is the end of the key-value list, we will break here.  */
        if (*token == ':') {
            break;
        }
        
        /* Make a copy of key-value pair that we will use to retrieve the key. */
        char* tokenBeforeIteration = malloc(strlen(token));
        strcpy(tokenBeforeIteration, token);
        
        /* Iterate over the string until we reach either the end, or a '=' */
        long keyLength = 0;
        while (*token != '\0' && *token != '=') {
            keyLength++;
            token++;
        }
        
        /* Set the key to the result of our previous iteration */
        char* key = malloc(keyLength);
        strncpy(key, tokenBeforeIteration, keyLength);
        key[keyLength] = '\0';
        
        NSString *keyString = [NSString stringWithCString:key encoding:NSUTF8StringEncoding];
        
        /* If the next character is an '=', this is a key-value pair, and we will continue iterating to get the value.
         If not, we will interpret it as a positive boolean. */
        if (*token == '=') {
            token++;
            NSString *valueString = [NSString stringWithCString:token encoding:NSUTF8StringEncoding];
            
            /* Save key value pair to dictionary */
            [self.featuresSupportedByServer setObject:valueString forKey:keyString];
        } else {
            /* Save boolean to dictionary */
            [self.featuresSupportedByServer setObject:@YES forKey:keyString];
        }
        
        token = strtok(NULL, delimeter);
    }
}

- (void)userReceivedMessage:(const char *)message onRecepient:(char *)recepient byUser:(char **)senderDict
{
    NSString *recipientString = [NSString stringWithCString:recepient encoding:NSUTF8StringEncoding];
    
    /* Check if this message is a channel message or a private message */
    if ([recipientString isValidChannelName:self]) {
        /* Get the channel object associated with this channel */
        IRCChannel *channel = [IRCChannel fromString:recipientString WithClient:self];
        if (channel == nil) {
            /* We do not have a channel object with this channel, we must create one. */
            channel = [IRCChannel createNewFromString:recipientString WithClient:self];
        }
    } else {
    
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
    NSLog(@">> %@", line);
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    [self.connection writeDataToSocket:data];
}

@end

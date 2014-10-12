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
        self.channels = [[NSArray alloc] init];
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
    self.isAttemptingRegistration = YES;
    
    self.currentNicknameOnConnection = self.configuration.primaryNickname;
    
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
    
    const char* lineBeforeIteration;
    char* sender;
    char* nickname;
    char* username;
    char* hostname;
    
    
    /* Make a copy of the full message string */
    lineBeforeIteration = line;
    
    if (*line == ':') {
        /* Consume the : at the start of the message. */
        line++;
        lineBeforeIteration++;
        
        long senderLength   = 0;
        long nicknameLength = 0;
        long usernameLength = 0;
        
        
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
        if (senderLength > 0) {
            sender = malloc(senderLength);
            strncpy(sender, lineBeforeIteration, senderLength);
            sender[senderLength] = '\0';
        } else {
            sender = NULL;
        }
        
        /* Copy the characters of the nickname range we calculated earlier, and consume the same characters from the string as well as the following '!' */
        nickname = malloc(nicknameLength+1);
        strncpy(nickname, lineBeforeIteration, nicknameLength);
        nickname[nicknameLength] = '\0';
        lineBeforeIteration = lineBeforeIteration + nicknameLength + 1;
        
        /* Copy the characters from the username range we calculated earlier, and consume the same characters from the string as well as the following '@' */
        if (usernameLength > 0) {
            username = malloc(usernameLength);
            strncpy(username, lineBeforeIteration, usernameLength -1);
            username[usernameLength] = '\0';
            lineBeforeIteration = lineBeforeIteration + usernameLength;
        } else {
            username = NULL;
        }
        
        /* Copy the characters from the hostname range we calculated earlier */
        long hostnameLength = (senderLength - usernameLength - nicknameLength -1);
        if (hostnameLength > 0) {
            hostname = malloc(hostnameLength);
            strncpy(hostname, lineBeforeIteration, hostnameLength);
            hostname[hostnameLength] = '\0';
        } else {
            hostname = NULL;
        }
        
        lineBeforeIteration = lineBeforeIteration + hostnameLength;
        
        /* Consume the following space leading to the IRC command */
        line++;
        lineBeforeIteration++;
    } else {
        sender   = NULL;
        username = NULL;
        hostname = NULL;
        nickname = NULL;
        lineBeforeIteration = line;
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
            if (nickname) {
                [self userReceivedMessage:line onRecepient:recipient byUser:senderDict];
            }
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
            
        case RPL_WELCOME:
            self.isAttemptingRegistration = NO;
            break;
            
        case RPL_ISUPPORT:
            [self updateServerSupportedFeatures:line];
            break;
            
        case ERR_ERRONEUSNICKNAME:
        case ERR_NICKNAMEINUSE:
            /* The server did not accept our nick request, let's see if this happened during initial registration. */
            if ([self isAttemptingRegistration]) {
                /* The nick error did happen during initial registration, we will check if we have already tried the secondary nickname */
                if ([self.currentNicknameOnConnection isEqualToString:self.configuration.primaryNickname]) {
                    /* This is the first occurance of this error, so we will try registration again with the secondary nickname. */
                    [self sendData:[NSString stringWithFormat:@"NICK %@", self.configuration.secondaryNickname]];
                    self.currentNicknameOnConnection = self.configuration.secondaryNickname;
                } else {
                    /* The secondary nickname has already been attempted, so we will append an underscore to the nick until
                     we find one that the server accepts. If we cannot find a nick within 25 characters, we will abort. */
                    if ([self.currentNicknameOnConnection length] < 25) {
                        NSString *newNickName = [NSString stringWithFormat:@"%@_", self.currentNicknameOnConnection];
                        [self sendData:[@"NICK " stringByAppendingString:newNickName]];
                        self.currentNicknameOnConnection = newNickName;
                    } else {
                        //TODO: Disconnect
                    }
                }
            }
            break;
            
        case RPL_ENDOFMOTD:
            [self sendData:@"JOIN #conversation"];
            
        default:
            break;
    }
    free(command);
    free(sender);
    free(recipient);
    free(nickname);
    free(username);
}

- (void)updateServerSupportedFeatures:(const char*)data
{
    /* Create a mutable copy of the data */
    char* mline = malloc(strlen(data) + 1);
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
        
        /* Make a pointer to the key-value pair that we will use to retrieve the key. */
        char* tokenBeforeIteration = token;
        char* keySearchToken = token;
        
        /* Iterate over the string until we reach either the end, or a '=' */
        long keyLength = 0;
        while (*keySearchToken != '\0' && *keySearchToken != '=' && *keySearchToken != ' ') {
            keyLength++;
            keySearchToken++;
        }
        
        /* Set the key to the result of our previous iteration */
        char* key;
        if (keyLength > 0) {
            key = malloc(keyLength);
            strncpy(key, tokenBeforeIteration, keyLength);
            key[keyLength] = '\0';
            
            NSString *keyString = [NSString stringWithCString:key encoding:NSUTF8StringEncoding];
            
            /* If the next character is an '=', this is a key-value pair, and we will continue iterating to get the value.
             If not, we will interpret it as a positive boolean. */
            if (*keySearchToken == '=') {
                keySearchToken++;
                NSString *valueString = [NSString stringWithCString:keySearchToken encoding:NSUTF8StringEncoding];
                
                /* Save key value pair to dictionary */
                [self.featuresSupportedByServer setObject:valueString forKey:keyString];
            } else {
                /* Save boolean to dictionary */
                [self.featuresSupportedByServer setObject:@YES forKey:keyString];
            }
            
        }
        
        token = strtok(NULL, delimeter);
    }
    free(mline);
}

- (void)userReceivedMessage:(const char *)message onRecepient:(char *)recepient byUser:(char **)senderDict
{
    /* Check if the message begins and ends with a 0x01 character, denoting this is a CTCP request. */
    if (*message == '\001' && message[strlen(message) -1] == '\001') {
        [self userReceivedCTCPMessage:message onRecepient:recepient byUser:senderDict];
        return;
    }
    
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

- (void)userReceivedCTCPMessage:(const char *)message onRecepient:(char *)recepient byUser:(char **)senderDict
{
    
    /* Consume the begining CTCP character (0x01) */
    message++;
    
    /* Make a copy of the string */
    char* messageCopy = malloc(strlen(message));
    strcpy(messageCopy, message);
    
    /* Iterate to the first space or the end of the message to get the "CTCP command" received. */
    int commandLength = 1;
    while (*message != ' ' && *message != '\0' && *message != '\001') {
        commandLength++;
        message++;
    }
    
    /* Get past the next space (if there is one) */
    message++;
    
    if (commandLength > 0) {
        /* Get the CTCP command by copying the range we calculated earlier */
        char* ctcpCommand = malloc(commandLength);
        strlcpy(ctcpCommand, messageCopy, commandLength);
        ctcpCommand[commandLength +1] = '\0';
        
        if (strcmp(ctcpCommand, "ACTION") == 0) {
            /* This is a CTCP ACTION, also known as an action message or a /me. We will send this to it's own handler.  */
            [self userReceivedACTIONMessage:message onRecepient:recepient byUser:senderDict];
            free(ctcpCommand);
            free(messageCopy);
            return;
        } else if (strcmp(ctcpCommand, "VERSION") == 0) {
            /* This is a CTCP VERSION, we will respond to it automatically by sending our IRC client version information.
             The current way of doing this is a placeholder. */
            [self sendData:[NSString stringWithFormat:@"NOTICE %s :\001VERSION Conversation IRC Client (https://github.com/ConversationDevelopers/conversation)\001", senderDict[1]]];
        }
        free(ctcpCommand);
    }
    free(messageCopy);
}

- (void)userReceivedACTIONMessage:(const char *)message onRecepient:(char *)recepient byUser:(char **)senderDict
{
    
}

- (void)clientDidSendData
{
}

- (void)disconnect
{
    self.isProcessingTermination = YES;
    [self sendData:[NSString stringWithFormat:@"QUIT %@", self.configuration.disconnectMessage]];
    [self.connection close];
}

- (void)clientDidDisconnectWithError:(NSString *)error
{
    NSLog(@"Disconnected: %@", error);
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

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

#import "znc-buffextras.h"
#import "IRCChannel.h"
#import "IRCClient.h"
#import "IRCMessage.h"

@implementation znc_buffextras

+ (void)messageWithBufferString:(const char *)line onChannel:(IRCChannel *)channel onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags
{
    char* sender;
    char* nickname;
    char* username;
    char* hostname;
    
    long senderLength   = 0;
    long nicknameLength = 0;
    long usernameLength = 0;
    
    const char* lineBeforeIteration = line;
    
    
    /* Pass over the string until we either reach a space, end of message, or an exclamation mark (Part of a user's hostmask) */
    while (*line != '\0' && *line != ' ' && *line != '!') {
        nicknameLength++;
        line++;
        senderLength++;
    }
    /* If there was not an ! in this message and we have reached a space already, the sender was the server, which does not have a hostmask. */
    if (*line != ' ') {
        /* Pass over the string until we reach a space, end of message, or an @ sign (Part of the user's hostmask) */
        while (*line != '\0' && *line != ' ' && *line != '@') {
            usernameLength++;
            line++;
            senderLength++;
        }
        /* Pass over the rest of the string leading to a space, to get the position of the host address. */
        while (*line != '\0' && *line != ' ') {
            senderLength++;
            line++;
        }
    }
    
    /* Copy the characters of the entire sender */
    if (senderLength > 0) {
        sender = malloc(senderLength+1);
        strncpy(sender, lineBeforeIteration, senderLength);
        sender[senderLength] = '\0';
    } else {
        sender = malloc(1);
    }
    
    /* Copy the characters of the nickname range we calculated earlier, and consume the same characters from the string as well as the following '!' */
    if (nicknameLength > 0) {
        nickname = malloc(nicknameLength+1);
        strncpy(nickname, lineBeforeIteration, nicknameLength);
        nickname[nicknameLength] = '\0';
        lineBeforeIteration = lineBeforeIteration + nicknameLength + 1;
    } else {
        nickname = malloc(1);
    }
    
    /* Copy the characters from the username range we calculated earlier, and consume the same characters from the string as well as the following '@' */
    username = malloc(usernameLength + 1);
    if (usernameLength > 0) {
        strncpy(username, lineBeforeIteration, usernameLength -1);
        username[usernameLength] = '\0';
        lineBeforeIteration = lineBeforeIteration + usernameLength;
    } else {
        username = malloc(1);
    }
    
    /* Copy the characters from the hostname range we calculated earlier */
    long hostnameLength = (senderLength - usernameLength - nicknameLength);
    if (hostnameLength > 0) {
        hostname = malloc(hostnameLength+1);
        strncpy(hostname, lineBeforeIteration, hostnameLength);
        hostname[hostnameLength] = '\0';
    } else {
        hostname = malloc(1);
    }
    
    const char* senderDict[] = {
        nickname,
        username,
        hostname
    };

    line++;
    
    IRCUser *user = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    client.configuration.lastMessageTime = (long) [now timeIntervalSince1970];
    
    NSString *message = [NSString stringWithCString:line usingEncodingPreference:client.configuration];
    
    NSMutableArray *messageComponents = [[message componentsSeparatedByString:@" "] mutableCopy];
    NSString *type = messageComponents[0];
    
    if ([type isEqualToString:@"set"]) {
        // MODE
    } else if ([type isEqualToString:@"joined"]) {
        // JOIN
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:nil
                                                           OfType:ET_JOIN
                                                   inConversation:channel
                                                         bySender:user
                                                           atTime:now
                                                         withTags:tags
                                                  isServerMessage:NO
                                                         onClient:client];
        [channel addMessageToConversation:message];
    } else if ([type isEqualToString:@"parted"]) {
        // PART
        NSString *partMessage = @"";
        if ([messageComponents count] > 1) {
            NSRange range;
            range.location = 0;
            range.length = 3;
            [messageComponents removeObjectsInRange:range];
            partMessage = [messageComponents componentsJoinedByString:@" "];
            
            NSRange substrRange;
            substrRange.location = 1;
            substrRange.length = [partMessage length] - 2;
            partMessage = [partMessage substringWithRange:substrRange];
        }
        
        IRCMessage *messageObject = [[IRCMessage alloc] initWithMessage:partMessage
                                                                 OfType:ET_PART
                                                         inConversation:channel
                                                               bySender:user
                                                                 atTime:now
                                                               withTags:tags
                                                        isServerMessage:NO
                                                               onClient:client];
        
        [channel addMessageToConversation:messageObject];
    } else if ([type isEqualToString:@"is"]) {
        // NICK
        NSString *newNick = messageComponents[4];
        IRCMessage *messageObject = [[IRCMessage alloc] initWithMessage:newNick
                                                                 OfType:ET_NICK
                                                         inConversation:channel
                                                               bySender:user
                                                                 atTime:now
                                                               withTags:tags
                                                        isServerMessage:NO
                                                               onClient:client];
        
        [channel addMessageToConversation:messageObject];
    } else if ([type isEqualToString:@"quit"]) {
        // QUIT
        NSRange range;
        range.location = 0;
        range.length = 3;
        [messageComponents removeObjectsInRange:range];
        NSString *quitMessage = [messageComponents componentsJoinedByString:@" "];
        
        NSRange substrRange;
        substrRange.location = 1;
        substrRange.length = [quitMessage length] - 2;
        quitMessage = [quitMessage substringWithRange:substrRange];
        
        IRCMessage *messageObject = [[IRCMessage alloc] initWithMessage:quitMessage
                                                                 OfType:ET_QUIT
                                                         inConversation:channel
                                                               bySender:user
                                                                 atTime:now
                                                               withTags:tags
                                                        isServerMessage:NO
                                                               onClient:client];
        
        [channel addMessageToConversation:messageObject];
    }
    
    free(sender);
    free(nickname);
    free(username);
    free(hostname);
}

@end

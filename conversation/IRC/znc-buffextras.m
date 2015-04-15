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

#import "znc-buffextras.h"
#import "IRCChannel.h"
#import "IRCClient.h"
#import "IRCMessage.h"
#import "NSMutableArray+Methods.h"

@implementation znc_buffextras

+ (void)message:(IRCMessage *)message
{
    NSMutableArray *messageComponents = [[message.message componentsSeparatedByString:@" "] mutableCopy];
    
    message.isConversationHistory = YES;
    
    NSString *nickname = @"";
    NSString *username = @"";
    NSString *hostname = @"";
    [messageComponents[0] getUserHostComponents:&nickname username:&username hostname:&hostname onClient:message.client];

    message.sender = [[IRCUser alloc] initWithNickname:nickname andUsername:username andHostname:hostname andRealname:nil onClient:message.client];
    
    NSString *type = messageComponents[1];
    
    if ([type isEqualToString:@"set"]) {
        // MODE
        message.messageType = ET_MODE;
        message.message = [messageComponents componentsJoinedByString:@" " fromIndex:3];
    } else if ([type isEqualToString:@"joined"]) {
        // JOIN
        message.message = message.conversation.name;
        message.messageType = ET_JOIN;
    } else if ([type isEqualToString:@"parted"]) {
        // PART
        NSString *partMessage = @"";
        if ([messageComponents count] > 1) {
			partMessage = [messageComponents componentsJoinedByString:@" " fromIndex:5];
			
            NSRange substrRange;
            substrRange.location = 1;
            substrRange.length = [partMessage length] - 2;
            partMessage = [partMessage substringWithRange:substrRange];
        }
        
        message.message = partMessage;
        message.messageType = ET_PART;
    } else if ([type isEqualToString:@"is"]) {
        // NICK
        NSString *newNick = messageComponents[5];
        message.message = newNick;
        message.messageType = ET_NICK;
    } else if ([type isEqualToString:@"quit"]) {
        // QUIT
        NSString *quitMessage = [messageComponents componentsJoinedByString:@" " fromIndex:5];
        
        NSRange substrRange;
        substrRange.location = 1;
        substrRange.length = [quitMessage length] - 2;
        quitMessage = [quitMessage substringWithRange:substrRange];
        
        message.message = quitMessage;
        message.messageType = ET_QUIT;
    } else if ([type isEqualToString:@"kicked"]) {
        NSString *kickMessage = [messageComponents componentsJoinedByString:@" " fromIndex:5];
        
        NSRange substrRange;
        substrRange.location = 1;
        substrRange.length = [kickMessage length] - 2;
        kickMessage = [kickMessage substringWithRange:substrRange];
        
        NSString *nick = messageComponents[2];
        IRCUser *kickedUser = [[IRCUser alloc] initWithNickname:nick andUsername:nick andHostname:@"localhost" andRealname:nick onClient:message.client];
        
        if (kickMessage && kickedUser) {
            message.messageType = ET_KICK;
            message.kickedUser = kickedUser;
            message.message = kickMessage;
        }
    }
    
    [message.conversation addMessageToConversation:message];
}

@end

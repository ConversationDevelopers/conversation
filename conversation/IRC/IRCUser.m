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

#import "IRCUser.h"

@implementation IRCUser

- (instancetype) initWithSenderDict:(const char **)senderDict onClient:(IRCClient *)client
{
    if ((self = [super init])) {
        self.nick = [NSString stringWithCString:senderDict[1] usingEncodingPreference:[client configuration]];
        self.username = [NSString stringWithCString:senderDict[2] usingEncodingPreference:[client configuration]];
        self.hostname = [NSString stringWithCString:senderDict[3] usingEncodingPreference:[client configuration]];
        
        self.isAway = NO;
        
        self.channelPrivileges = 0;
        return self;
    }
    return nil;
}

- (instancetype) initWithNickname:(NSString *)nickname andUsername:(NSString *)username andHostname:(NSString *)hostname onClient:(IRCClient *)client
{
    if ((self = [super init])) {
        self.nick = nickname;
        self.username = username;
        self.hostname = hostname;
        
        self.isAway = NO;
        
        self.channelPrivileges = 0;
        return self;
    }
    return nil;
}

+ (IRCUser *)fromSender:(const char **)senderDict onChannel:(IRCChannel *)channel createIfMissing:(BOOL)createIfMissing
{
    NSString *nickString = [NSString stringWithCString:senderDict[1] usingEncodingPreference:[[channel client] configuration]];
    
    IRCUser *userFromUserlist = nil;
    for (IRCUser *user in [channel users]) {
        if ([[user nick] isEqualToString:nickString]) {
            userFromUserlist = user;
            break;
        }
    }
    if (userFromUserlist == nil && createIfMissing) {
        return [[IRCUser alloc] initWithSenderDict:senderDict onClient:[channel client]];
    }
    return userFromUserlist;
}

@end

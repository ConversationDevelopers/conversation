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

#import "IRCConversation.h"
#import "IRCClient.h"

@implementation IRCConversation

- (instancetype) initWithName:(NSString *)name withClient:(IRCClient *)client
{
    if ((self = [super init])) {
        self.name = name;
        // TODO: Send ISON command to verify that conversation partner is connected.
        
        return self;
    }
    return nil;
}

+ (id) fromString:(NSString *)name withClient:(IRCClient *)client
{
    if ([name isValidChannelName:client]) {
        for (IRCChannel *channel in [client getChannels]) {
            if ([channel.name isEqualToString:name])
                return channel;
        }
    } else if ([name isValidNickname]) {
        for (IRCConversation *query in [client getQueries]) {
            if ([query.name isEqualToString:name]) {
                return query;
            }
        }
    }
    return nil;
}

- (BOOL)isActive
{
    return [self.client isConnected] && self.conversationPartnerIsOnline;
}

@end
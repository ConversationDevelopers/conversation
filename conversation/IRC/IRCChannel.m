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

#import "IRCChannel.h"
#import "IRCClient.h"

@implementation IRCChannel

- (instancetype)initWithConfiguration:(IRCChannelConfiguration *)config withClient:(IRCClient *)client
{
    if ((self = [super init])) {
        self.name = config.name;
        self.client = client;
        self.topic = @"(No Topic)";
        self.users = [[NSMutableArray alloc] init];
        self.configuration = config;
        self.channelModes = [[NSMutableArray alloc] init];
        return self;
    }
    return nil;
}

+ (IRCChannel *) getChannelOrCreate:(NSString *)channelName onClient:(IRCClient *)client
{
    IRCChannel *channel = (IRCChannel *) [IRCChannel fromString:channelName withClient:client];
    if (channel == nil) {
        /* We don't have this channel, let's make a request to the UI to create the channel. */
        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
        [controller joinChannelWithName:channelName onClient:client];
        channel =  [IRCChannel fromString:channelName withClient:client];
    }
    return channel;
}

- (BOOL)isActive
{
    return [self.client isConnected] && self.isJoinedByUser;
}

- (void)setTopic:(NSString *)topic
{
    
}

- (void)removeUserByName:(NSString *)nickname
{
    for (IRCUser *user in self.users) {
        if ([[user nick] isEqualToString:nickname]) {
            [self.users removeObject:user];
            break;
        }
    }
}

@end

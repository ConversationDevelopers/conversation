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

#define MAX_BUFFER_COUNT 3000

@implementation IRCConversation

- (instancetype)initWithConfiguration:(IRCChannelConfiguration *)config withClient:(IRCClient *)client
{
    if ((self = [super init])) {
        self.name = config.name;
        self.client = client;
        self.conversationPartnerIsOnline = NO;
        self.configuration = config;
        self.messages = [[NSMutableArray alloc] init];
        self.unreadCount = 0;        
        return self;
    }
    return nil;
}

+ (IRCConversation *) getConversationOrCreate:(NSString *)nickname onClient:(IRCClient *)client
{
    IRCConversation *conversation = [IRCConversation fromString:nickname withClient:client];
    if (conversation == nil) {
        /* We don't have a query for this message, we need to create one */
        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
        [controller createConversationWithName:nickname onClient:client];
        conversation = [IRCConversation fromString:nickname withClient:client];
    }
    return conversation;
}

+ (id) fromString:(NSString *)name withClient:(IRCClient *)client
{
    if ([name isValidChannelName:client]) {
        for (IRCChannel *channel in [client getChannels]) {
            if ([channel.name isEqualToString:name])
                return channel;
        }
    } else if ([name isValidNickname:client]) {
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

- (void)addPreviewMessage:(NSAttributedString *)message
{
    if(!_previewMessages)
        _previewMessages = [[NSMutableArray alloc] init];
    
    if (_previewMessages.count > 1) {
        id string = _previewMessages[1];
        [_previewMessages removeObjectAtIndex:0];
        [_previewMessages setObject:string atIndexedSubscript:0];
    }
    [_previewMessages addObject:message];
}


- (void)addMessageToConversation:(id)object
{
    [self.messages addObject:object];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:object];
    while ([self.messages count] > MAX_BUFFER_COUNT) {
        [self.messages removeObjectAtIndex:0];
    }
}

@end

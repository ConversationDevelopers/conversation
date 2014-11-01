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
        dispatch_async(dispatch_get_main_queue(), ^{
            /* We don't have a query for this message, we need to create one */
            ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
            [controller createConversationWithName:nickname onClient:client];
        });
    }
    return conversation;
}

+ (id) fromString:(NSString *)name withClient:(IRCClient *)client
{
    /* Return an existing channel or query in this client */
    if ([name isValidChannelName:client]) {
        /* If this is a channel iterate through the list of channels and return one that matches */
        for (IRCChannel *channel in [client getChannels]) {
            if ([channel.name caseInsensitiveCompare:name] == NSOrderedSame)
                return channel;
        }
    } else if ([name isValidNickname:client]) {
        /* If this is a query, iterate through the list of queries and return one that matches*/
        for (IRCConversation *query in [client getQueries]) {
            if ([query.name caseInsensitiveCompare:name] == NSOrderedSame) {
                return query;
            }
        }
    }
    /* We couldn't find any object that matches, we will return nil. */
    return nil;
}


- (BOOL)isActive
{
    return [self.client isConnected] && self.conversationPartnerIsOnline;
}

- (void)addPreviewMessage:(NSAttributedString *)message
{
    /* Create the preview messages list if it is not already created */
    if(!_previewMessages)
        _previewMessages = [[NSMutableArray alloc] init];
    
    /* We can only display two items at a time. If we have already reached capacity, we will remove the first item. and move the second one to take its place. */
    if (_previewMessages.count > 1) {
        id string = _previewMessages[1];
        [_previewMessages removeObjectAtIndex:0];
        [_previewMessages setObject:string atIndexedSubscript:0];
    }
    /* Add the new item to the list */
    [_previewMessages addObject:message];
}


- (void)addMessageToConversation:(id)object
{
    /* Add the message to the message list. */
    [self.messages addObject:object];
    
    /* Notify all parts of the application listening for messages that a new message has been added. */
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:object];
    });
    
    /* We cannot store an unlimited amount of messages. To keep memory consumption down we will remove the
     oldest messages if necessary. */
    while ([self.messages count] > MAX_BUFFER_COUNT) {
        [self.messages removeObjectAtIndex:0];
    }
}

@end

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

#import "IRCConversation.h"
#import "IRCClient.h"
#import "IRCMessage.h"
#import "ConsoleViewController.h"

#define MAX_BUFFER_COUNT 3000

@implementation IRCConversation

- (instancetype)initWithConfiguration:(IRCChannelConfiguration *)config withClient:(IRCClient *)client
{
    if ((self = [super init])) {
        self.name = config.name;
        self.client = client;
        self.conversationPartnerIsOnline = NO;
        self.hasNewMessages = NO;
        self.configuration = config;
        self.unreadCount = 0;        
        return self;
    }
    return nil;
}

+ (void) getConversationOrCreate:(NSString *)name onClient:(IRCClient *)client withCompletionHandler:(void (^)(IRCConversation *))completionHandler
{
    if ([name isValidChannelName:client]) {
        __block IRCChannel *channel = (IRCChannel *) [IRCChannel fromString:name withClient:client];
        if (channel == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                /* We don't have a query for this message, we need to create one */
                ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
                channel = [controller joinChannelWithName:name onClient:client];
                if (completionHandler) completionHandler(channel);
            });
        } else {
            if (completionHandler) completionHandler(channel);
        }
    } else {
        __block IRCConversation *conversation = [IRCConversation fromString:name withClient:client];
        if (conversation == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                /* We don't have a query for this message, we need to create one */
                ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
                conversation = [controller createConversationWithName:name onClient:client];
                if (completionHandler) completionHandler(conversation);
            });
        } else {
            if (completionHandler) completionHandler(conversation);
        }
    }
}

+ (id) fromString:(NSString *)name withClient:(IRCClient *)client
{
    /* Return an existing channel or query in this client */
    if ([name isValidChannelName:client]) {
        /* If this is a channel iterate through the list of channels and return one that matches */
        for (IRCChannel *channel in [client channels]) {
            if ([channel.name isEqualToStringCaseInsensitive:name])
                return channel;
        }
    } else if ([name isValidNickname:client]) {
        /* If this is a query, iterate through the list of queries and return one that matches*/
        for (IRCConversation *query in [client queries]) {
            if ([query.name isEqualToStringCaseInsensitive:name]) {
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
    IRCMessage *message = (IRCMessage *)object;
    if ([message.sender isIgnoredHostMask:message.conversation.client]) {
        return;
    }
    
    if (message.isConversationHistory == NO)
        self.hasNewMessages = YES;
    
    /* Notify all parts of the application listening for messages that a new message has been added. */
    dispatch_async(dispatch_get_main_queue(), ^{
        if (message.messageType == ET_RAW) {
            if (message.client.showConsole)
                message.client.console.contentView.text = [message.client.console.contentView.text stringByAppendingFormat:@"%@\n", message.message];
        } else
            [message.conversation.contentView addMessage:message];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:object];
    });

}

@end

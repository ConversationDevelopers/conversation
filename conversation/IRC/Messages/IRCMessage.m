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

#import "IRCMessage.h"
#import "AppPreferences.h"

@implementation IRCMessage

- (instancetype) initWithMessage:(NSString *)message OfType:(NSUInteger)type inConversation:(IRCConversation *)conversation bySender:(IRCUser *)sender atTime:(NSDate *)timestamp withTags:(NSDictionary *)tags isServerMessage:(BOOL)isServerMessage onClient:(IRCClient *)client
{
    if ((self = [super init])) {
        self.message = message;
        self.messageType = type;
        self.conversation = conversation;
        self.sender = sender;
        self.timestamp = timestamp;
        self.tags = tags;
        self.isServerMessage = isServerMessage;
        self.client = client;
        self.isConversationHistory = NO;
        return self;
    }
    return nil;
}


-(id)copyWithZone:(NSZone *)zone
{
    IRCMessage *copy = [[IRCMessage alloc] initWithMessage:self.message
                                                    OfType:self.messageType
                                            inConversation:self.conversation
                                                  bySender:self.sender
                                                    atTime:self.timestamp
                                                  withTags:self.tags
                                           isServerMessage:self.isServerMessage
                                                  onClient:self.client];
    
    return copy;
}

- (id)serializedDatabaseRepresentationOfValue:(id)instanceValue forPropertyNamed:(NSString *)propertyName
{
//    [super serializedDatabaseRepresentationOfValue:instanceValue forPropertyNamed:propertyName];
    
    if ([instanceValue isKindOfClass:IRCClient.class]) {
        IRCClient *client = (IRCClient *)instanceValue;
        return client.configuration.uniqueIdentifier;
        
    } else if ([instanceValue isKindOfClass:IRCConversation.class]) {
        IRCConversation *conversaiton = (IRCConversation*)instanceValue;
        return conversaiton.configuration.uniqueIdentifier;
    } else if ([instanceValue isKindOfClass:IRCUser.class]) {
        IRCUser *user = (IRCUser *)instanceValue;
        return user.fullhostmask;
    }

    return instanceValue;
}

- (id)unserializedRepresentationOfDatabaseValue:(id)databaseValue forPropertyNamed:(NSString *)propertyName
{
//    [super unserializedRepresentationOfDatabaseValue:databaseValue forPropertyNamed:propertyName];
    
    if ([propertyName isEqualToString:@"client"]) {
        NSDictionary *prefs = [[AppPreferences sharedPrefs] preferences];
        NSArray *connections = prefs[@"configurations"];
        for (NSDictionary *dict in connections) {
            if ([dict[@"uniqueIdentifier"] isEqualToString:databaseValue]) {
                IRCConnectionConfiguration *config = [[IRCConnectionConfiguration alloc] initWithDictionary:dict];
                return [[IRCClient alloc] initWithConfiguration:config];
            }
        }
        
    }
    
    if ([propertyName isEqualToString:@"conversation"]) {
        NSDictionary *prefs = [[AppPreferences sharedPrefs] preferences];
        NSArray *connections = prefs[@"configurations"];
        for (NSDictionary *dict in connections) {
            for (NSDictionary *channel in dict[@"channels"]) {
                if ([channel[@"uniqueIdentifier"] isEqualToString:databaseValue]) {
//                    IRCConnectionConfiguration *connection = [[IRCConnectionConfiguration alloc] initWithDictionary:dict];
//                    IRCClient *client = [[IRCClient alloc] initWithConfiguration:connection];
                    IRCChannelConfiguration *config = [[IRCChannelConfiguration alloc] initWithDictionary:channel];
                    return [[IRCChannel alloc] initWithConfiguration:config withClient:self.client];
                }
                
            }
            for (NSDictionary *query in dict[@"queries"]) {
                if ([query[@"uniqueIdentifier"] isEqualToString:databaseValue]) {
//                    IRCConnectionConfiguration *connection = [[IRCConnectionConfiguration alloc] initWithDictionary:dict];
//                    IRCClient *client = [[IRCClient alloc] initWithConfiguration:connection];
                    IRCChannelConfiguration *config = [[IRCChannelConfiguration alloc] initWithDictionary:query];
                    return [[IRCConversation alloc] initWithConfiguration:config withClient:self.client];
                }
            }

        }
    }
    
    if ([propertyName isEqualToString:@"sender"]) {
        NSString *fullhost = (NSString *)databaseValue;
        if (fullhost.length) {
            NSArray *components = [fullhost componentsSeparatedByString:@"@"];
            NSString *nick = [components[0] componentsSeparatedByString:@"!"][0];
            NSString *user = [components[0] componentsSeparatedByString:@"!"][0];
            NSString *host = components[1];
            return [[IRCUser alloc] initWithNickname:nick andUsername:user andHostname:host andRealname:@"" onClient:self.client];
        }
    }

    if ([propertyName isEqualToString:@"timestamp"]) {
        return [NSDate dateWithTimeIntervalSince1970:[databaseValue doubleValue]];
    }
    
    return databaseValue;
}

@end

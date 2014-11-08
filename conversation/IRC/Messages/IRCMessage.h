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

#import <Foundation/Foundation.h>
#import "IRCConversation.h"
#import "IRCChannel.h"

@class IRCUser;

@interface IRCMessage : NSObject

@property (nonatomic) IRCUser *sender;
@property (nonatomic) NSString *message;
@property (nonatomic) NSDate *timestamp;
@property (nonatomic) IRCConversation* conversation;
@property (nonatomic) NSUInteger messageType;

- (instancetype) initWithMessage:(NSString *)message OfType:(NSUInteger)type inConversation:(IRCConversation *)conversation bySender:(IRCUser *)sender atTime:(NSDate *)timestamp;

typedef NS_ENUM(NSUInteger, EventType) {
    ET_ACTION,
    ET_PRIVMSG,
    ET_CTCP,
    ET_NICK,
    ET_CTCPREPLY,
    ET_NOTICE,
    ET_SERVERNOTICE,
    ET_INVITE,
    ET_JOIN,
    ET_PART,
    ET_QUIT,
    ET_KICK,
    ET_TOPIC,
    ET_RAW
};

@end

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
#import "IRCClient.h"
#import "NSString+Methods.h"

@class IRCChannel;

@interface IRCUser : NSObject

@property (nonatomic) NSString *nick;
@property (nonatomic) NSString *username;
@property (nonatomic) NSString *hostname;
@property (nonatomic, assign) BOOL isAway;

@property (nonatomic) BOOL ircop;
@property (nonatomic) BOOL owner;
@property (nonatomic) BOOL admin;
@property (nonatomic) BOOL op;
@property (nonatomic) BOOL halfop;
@property (nonatomic) BOOL voice;

- (instancetype) initWithSenderDict:(const char **)senderDict onClient:(IRCClient *)client;
- (instancetype) initWithNickname:(NSString *)nickname andUsername:(NSString *)username andHostname:(NSString *)hostname onClient:(IRCClient *)client;
- (int) channelPrivilege;
- (void)setPrivilegeMode:(const char *)mode granted:(BOOL)granted;

+ (IRCUser *)fromNickname:(const char *)sender onChannel:(IRCChannel *)channel;
+ (IRCUser *)fromNicknameString:(NSString *)sender onChannel:(IRCChannel *)channel;
+ (NSString *)statusToModeSymbol:(int)status;
- (NSString *)description;
- (NSString *)fullhostmask;
- (BOOL)isIgnoredHostMask:(IRCClient *)client;

typedef enum ChannelPrivileges : NSUInteger {
    NORMAL,
    VOICE,
    HALFOP,
    OPERATOR,
    ADMIN,
    OWNER,
    IRCOP
} ChannelPrivileges;

@end

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
#import "IRCConnectionConfiguration.h"
#import "IRCMessageIndex.h"
#import "Messages.h"
#import "NSString+Methods.h"
#import "SSKeychain.h"

@class IRCConnection;
@class IRCChannel;
@class IRCUser;
@class IRCConversation;
@class ConversationListViewController;

@interface IRCClient : NSObject

@property (nonatomic, strong) IRCConnectionConfiguration *configuration;
@property (nonatomic, strong) IRCConnection *connection;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) BOOL isAttemptingConnection;
@property (nonatomic, assign) BOOL hasSuccessfullyAuthenticated;
@property (nonatomic, assign) BOOL isAwaitingAuthenticationResponse;
@property (nonatomic, assign) BOOL isAttemptingRegistration;
@property (nonatomic, assign) BOOL isBNCConnection;
@property (nonatomic, assign) BOOL isProcessingTermination;
@property (nonatomic, strong) IRCUser *currentUserOnConnection;


@property (nonatomic, strong) NSMutableDictionary *featuresSupportedByServer;
@property (nonatomic, strong) NSMutableArray *ircv3CapabilitiesSupportedByServer;

@property (nonatomic) char* ircopUserModeCharacter;
@property (nonatomic) char* ownerUserModeCharacter;
@property (nonatomic) char* adminUserModeCharacter;
@property (nonatomic) char* operatorUserModeCharacter;
@property (nonatomic) char* halfopUserModeCharacter;
@property (nonatomic) char* voiceUserModeCharacter;

+ (NSArray *) IRCv3CapabilitiesSupportedByApplication;

- (instancetype)initWithConfiguration:(IRCConnectionConfiguration *)config;
- (void)connect;
- (void)clientDidConnect;
- (void)clientDidDisconnect;
- (void)clientDidDisconnectWithError:(NSString *)error;
- (void)clientDidReceiveData:(const char *)decodedData;
- (void)clientDidSendData;
+ (NSString *)getChannelPrefixCharacters:(IRCClient *)client;
- (void)validateQueryStatusOnAllItems;
- (void)disconnect;
- (void)autojoin;

- (BOOL)addChannel:(IRCChannel *)channel;
- (BOOL)removeChannel:(IRCChannel *)channel;

- (BOOL)addQuery:(IRCConversation *)query;
- (BOOL)removeQuery:(IRCConversation *)query;

- (NSMutableArray *)getChannels;
- (NSMutableArray *)getQueries;

- (NSMutableArray *)sortChannelItems;
- (NSMutableArray *)sortQueryItems;

+ (NSDate *)getTimestampFromMessageTags:(NSMutableDictionary *)tags;

@end

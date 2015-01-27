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
#import <Foundation/Foundation.h>

@class IRCClient;
@class IRCConversation;
@class IRCChannel;

@interface IRCCommands : NSObject

+ (void)sendMessage:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client;
+ (void)sendCTCPMessage:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client;
+ (void)sendACTIONMessage:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client;
+ (void)sendNotice:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client;
+ (void)sendCTCPReply:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client;
+ (void)changeNicknameToNick:(NSString *)nickname onClient:(IRCClient *)client;
+ (void)leaveChannel:(NSString *)channel withMessage:(NSString *)message onClient:(IRCClient *)client;
+ (void)joinChannel:(NSString *)channel onClient:(IRCClient *)client;
+ (void)rejoinChannel:(NSString *)channel withMessage:(NSString *)message onClient:(IRCClient *)client;
+ (void)sendServerPasswordForClient:(IRCClient *)client;
+ (void)onTimer:(float)seconds runCommand:(NSString *)command inConversation:(IRCConversation *)conversation;
+ (void)kickUser:(NSString *)nickname onChannel:(IRCChannel *)channel withMessage:(NSString *)message;
+ (void)banUser:(NSString *)nickname onChannel:(IRCChannel *)channel;
+ (void)kickBanUser:(NSString *)nickname onChannel:(IRCChannel *)channel withMessage:(NSString *)message;
+ (void)setTopic:(NSString *)topic onChannel:(NSString *)channel onClient:(IRCClient *)client;
+ (void)setMode:(NSString *)topic onRecepient:(NSString *)recepient onClient:(IRCClient *)client;
+ (void)closeConversation:(id)conversation onClient:(IRCClient *)client;

@end

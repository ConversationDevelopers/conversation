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
#import "AppDelegate.h"
#import "IRCChannel.h"
#import "IRCMessage.h"
#import "NSString+Methods.h"

@class IRCClient;
@class IRCUser;
@class ConversationListViewController;

@interface Messages : NSObject

+ (void)userReceivedMessage:(const char *)message onRecepient:(char *)recepient byUser:(const char *[4])senderDict onClient:(IRCClient *)client;

+ (void)userReceivedCTCPMessage:(const char *)message onRecepient:(char *)recepient byUser:(const char *[4])senderDict onClient:(IRCClient *)client;

+ (void)userReceivedACTIONMessage:(const char *)message onRecepient:(char *)recepient byUser:(const char *[4])senderDict onClient:(IRCClient *)client;

+ (void)userReceivedJOIN:(const char **)senderDict onChannel:(const char *)rchannel onClient:(IRCClient *)client;

+ (void)userReceivedNickchange:(const char *[4])senderDict toNick:(char *)newNick onClient:(IRCClient *)client;

+ (void)userReceivedTOPIC:(const char *)topic onChannel:(char *)rchannel byUser:(const char *[4])senderDict onClient:(IRCClient *)client;

+ (void)clientReceivedISONResponse:(const char *)message onClient:(IRCClient *)client;

+ (void)clientReceivedServerPasswordMismatchError:(IRCClient *)client;

@end

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

@class IRCConversation;
@class IRCClient;

@interface InputCommands : NSObject

+ (void)performCommand:(NSString *)message inConversation:(IRCConversation *)conversation onClient:(IRCClient *)client;

+ (NSUInteger)indexValueFromString:(NSString *)key;

typedef NS_ENUM(NSUInteger, InputCommand) {
    CMD_ADMIN,
    CMD_BAN,
    CMD_CLEAR,
    CMD_CLEARALL,
    CMD_CLOSE,
    CMD_CTCP,
    CMD_CTCPREPLY,
    CMD_DEADMIN,
    CMD_DEHALFOP,
    CMD_DEOP,
    CMD_DEVOICE,
    CMD_DEOWNER,
    CMD_ECHO,
    CMD_HALFOP,
    CMD_HOP,
    CMD_J,
    CMD_JOIN,
    CMD_KB,
    CMD_K,
    CMD_KICK,
    CMD_KICKBAN,
    CMD_LEAVE,
    CMD_ME,
    CMD_MODE,
    CMD_MSG,
    CMD_MUTE,
    CMD_NICK,
    CMD_OP,
    CMD_NOTICE,
    CMD_PART,
    CMD_QUERY,
    CMD_QUIT,
    CMD_QUOTE,
    CMD_RAW,
    CMD_REJOIN,
    CMD_TOPIC,
    CMD_VOICE,
    CMD_UMODE,
    CMD_UNBAN,
    CMD_UNMUTE
};

@end

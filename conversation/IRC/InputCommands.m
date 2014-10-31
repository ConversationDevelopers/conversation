/*
 Copyright (c) 2014", Tobias Pollmann, Alex Sørlie Glomsaas.
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

#import "InputCommands.h"
#import "IRCClient.h"
#import "IRCConnection.h"
#import "IRCConversation.h"

@implementation InputCommands

+ (void)performCommand:(NSString *)message inConversation:(IRCConversation *)conversation onClient:(IRCClient *)client
{
    NSArray *messageComponents = [message componentsSeparatedByString:@" "];
    if ([messageComponents count] > 0) {
        InputCommand command = [InputCommands indexValueFromString:messageComponents[0]];
        switch (command) {
            default:
                [client.connection send:message];
                break;
        }
    }
}

+ (NSUInteger)indexValueFromString:(NSString *)key
{
    NSUInteger indexFromArray = [[InputCommands inputCommandReference] indexOfObject:key];
    if (indexFromArray) {
        return indexFromArray;
    }
    return NSNotFound;
}

+ (NSArray *)inputCommandReference
{
    return @[
        @"ADMIN",
        @"CMD_BAN",
        @"CLEAR",
        @"CLEARALL",
        @"CLOSE",
        @"CTCP",
        @"CTCPREPLY",
        @"DEADMIN",
        @"DEHALFOP",
        @"DEHOP",
        @"DEVOICE",
        @"DEOWNER",
        @"ECHO",
        @"HALFOP",
        @"HOP",
        @"J",
        @"JOIN",
        @"KB",
        @"KICK",
        @"KICKBAN",
        @"LEAVE",
        @"ME",
        @"MODE",
        @"MSG",
        @"MUTE",
        @"NICK",
        @"OP",
        @"NOTICE",
        @"PART",
        @"QUERY",
        @"QUIT",
        @"QUOTE",
        @"RAW",
        @"REJOIN",
        @"TOPIC",
        @"VOICE",
        @"UMODE",
        @"UNBAN",
        @"UNMUTE"
    ];
}

@end

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
#import "IRCCommands.h"
#import "IRCConnection.h"
#import "IRCClient.h"

@implementation IRCCommands

+ (void)sendMessage:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client
{
    NSArray *lines = [message componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        if ([line length] > 0) {
            [client.connection send:[NSString stringWithFormat:@"PRIVMSG %@ :%@", recipient, line]];
        }
    }
}

+ (void)sendCTCPMessage:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client
{
    [client.connection send:[NSString stringWithFormat:@"PRIVMSG %@ :\001%@\001", recipient, message]];
}

+ (void)sendACTIONMessage:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client
{
    [self sendCTCPMessage:[@"ACTION " stringByAppendingString:message] toRecipient:recipient onClient:client];
}

+ (void)sendNotice:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client
{
    [client.connection send:[NSString stringWithFormat:@"NOTICE %@ :%@", recipient, message]];
}

+ (void)sendCTCPReply:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client
{
    [client.connection send:[NSString stringWithFormat:@"NOTICE %@ :\001%@\001", recipient, message]];
}

+ (void)changeNicknameToNick:(NSString *)nickname onClient:(IRCClient *)client
{
    [client.connection send:[NSString stringWithFormat:@"NICK %@", nickname]];
}

+ (void)leaveChannel:(NSString *)channel withMessage:(NSString *)message onClient:(IRCClient *)client
{
    if (message == nil || [message length] == 0) {
        message = client.configuration.channelDepartMessage;
    }
    [client.connection send:[NSString stringWithFormat:@"PART %@ %@", channel, message]];
}

+ (void)joinChannel:(NSString *)channel onClient:(IRCClient *)client
{
    [client.connection send:[NSString stringWithFormat:@"JOIN %@", channel]];
}

+ (void)rejoinChannel:(NSString *)channel withMessage:(NSString *)message onClient:(IRCClient *)client
{
    [IRCCommands leaveChannel:channel withMessage:message onClient:client];
    [IRCCommands joinChannel:channel onClient:client];
}

+ (void)kickUser:(NSString *)nickname onChannel:(IRCChannel *)channel withMessage:(NSString *)message
{
    if (message == nil || [message length] == 0) {
        //TODO use a default kick message.
    }
    [channel.client.connection send:[NSString stringWithFormat:@"KICK %@ %@ %@", channel.name, nickname, message]];
}

+ (void)banUser:(NSString *)nickname onChannel:(IRCChannel *)channel
{
    NSString *banMask;
    if ([nickname containsString:@"@"]) {
        banMask = nickname;
    } else {
        IRCUser *bannedUser = [IRCUser fromNicknameString:nickname onChannel:channel];
        if (bannedUser != nil) {
            banMask = [NSString stringWithFormat:@"*!*@%@", bannedUser.hostname];
        } else {
            banMask = [NSString stringWithFormat:@"%@!*@*", nickname];
        }
    }
    
    [channel.client.connection send:[NSString stringWithFormat:@"MODE %@ +b %@", channel.name, banMask]];
}

+ (void)kickBanUser:(NSString *)nickname onChannel:(IRCChannel *)channel withMessage:(NSString *)message
{
    [IRCCommands banUser:nickname onChannel:channel];
    [IRCCommands kickUser:nickname onChannel:channel withMessage:message];
}

+ (void)onTimer:(float)seconds runCommand:(NSString *)command inConversation:(IRCConversation *)conversation
{
    SEL selector = @selector(performCommand:inConversation:);
    NSMethodSignature *signature = [self methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:[InputCommands class]];
    [invocation setSelector:selector];
    [invocation setArgument:&command atIndex:2];
    [invocation setArgument:&conversation atIndex:3];
    [NSTimer scheduledTimerWithTimeInterval:seconds invocation:invocation repeats:NO];
}

@end

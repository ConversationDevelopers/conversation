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
#import "IRCCommands.h"
#import "IRCConnection.h"
#import "IRCClient.h"
#import "NSString+Methods.h"
#import "ConversationListViewController.h"

@implementation IRCCommands

+ (void)sendMessage:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client
{
    /* The message may be multiple lines, we will split them by their line break and send them as inividual messages. */
    NSArray *lines = [message componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        if ([line length] > 0) {
            
            [client.connection send:[NSString stringWithFormat:@"PRIVMSG %@ :%@", recipient, line]];
            [IRCConversation getConversationOrCreate:recipient onClient:client withCompletionHandler:^(IRCConversation *conversation) {
                
                // Workaround to set channel status
                IRCUser *user = client.currentUserOnConnection;
                if ([conversation isKindOfClass:[IRCChannel class]]) {
                    IRCChannel *channel = (IRCChannel*)conversation;
                    for (IRCUser *u in channel.users) {
                        if ([u.nick isEqualToString:client.currentUserOnConnection.nick]) {
                            user = u;
                        }
                    }
                }
                
                IRCMessage *message = [[IRCMessage alloc] initWithMessage:line
                                                                   OfType:ET_PRIVMSG
                                                           inConversation:conversation
                                                                 bySender:user
                                                                   atTime:[NSDate date]
                                                                 withTags:[[NSDictionary alloc] init]
                                                          isServerMessage:NO
                                                                 onClient:client];
                
                [conversation addMessageToConversation:message];
            }];
        }
    }
}

+ (void)sendCTCPMessage:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client
{
    [client.connection send:[NSString stringWithFormat:@"PRIVMSG %@ :\001%@\001", recipient, message]];
    [IRCConversation getConversationOrCreate:recipient onClient:client withCompletionHandler:^(IRCConversation *conversation) {
        IRCMessage *messageObj = [[IRCMessage alloc] initWithMessage:message
                                                           OfType:ET_CTCP
                                                   inConversation:conversation
                                                         bySender:client.currentUserOnConnection
                                                           atTime:[NSDate date]
                                                         withTags:[[NSDictionary alloc] init]
                                                  isServerMessage:NO
                                                         onClient:client];
        
        [conversation addMessageToConversation:messageObj];
    }];
}

+ (void)sendACTIONMessage:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client
{
    [client.connection send:[NSString stringWithFormat:@"PRIVMSG %@ :\001ACTION %@\001", recipient, message]];
    [IRCConversation getConversationOrCreate:recipient onClient:client withCompletionHandler:^(IRCConversation *conversation) {
        IRCMessage *messageObj = [[IRCMessage alloc] initWithMessage:message
                                                           OfType:ET_ACTION
                                                   inConversation:conversation
                                                         bySender:client.currentUserOnConnection
                                                           atTime:[NSDate date]
                                                         withTags:[[NSDictionary alloc] init]
                                                  isServerMessage:NO
                                                         onClient:client];
        
        [conversation addMessageToConversation:messageObj];
    }];
}

+ (void)sendNotice:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client
{
    [client.connection send:[NSString stringWithFormat:@"NOTICE %@ :%@", recipient, message]];
    [IRCConversation getConversationOrCreate:recipient onClient:client withCompletionHandler:^(IRCConversation *conversation) {
        IRCMessage *messageObj = [[IRCMessage alloc] initWithMessage:message
                                                           OfType:ET_NOTICE
                                                   inConversation:conversation
                                                         bySender:client.currentUserOnConnection
                                                           atTime:[NSDate date]
                                                         withTags:[[NSDictionary alloc] init]
                                                  isServerMessage:NO
                                                         onClient:client];
        
        [conversation addMessageToConversation:messageObj];
    }];
}

+ (void)sendCTCPReply:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client
{
    [client.connection send:[NSString stringWithFormat:@"NOTICE %@ :\001%@\001", recipient, message]];
    [IRCConversation getConversationOrCreate:recipient onClient:client withCompletionHandler:^(IRCConversation *conversation) {
        IRCMessage *messageObj = [[IRCMessage alloc] initWithMessage:message
                                                              OfType:ET_CTCPREPLY
                                                      inConversation:conversation
                                                            bySender:client.currentUserOnConnection
                                                              atTime:[NSDate date]
                                                            withTags:[[NSDictionary alloc] init]
                                                     isServerMessage:NO
                                                            onClient:client];
        
        [conversation addMessageToConversation:messageObj];
    }];
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
    [client.connection send:[NSString stringWithFormat:@"PART %@ :%@", channel, message]];
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
    if ([nickname isValidWildcardIgnoreMask]) {
        /* The input seems to already be a hostmask. We will use it as it is. */
        banMask = nickname;
    } else {
        IRCUser *bannedUser = [IRCUser fromNickname:nickname onChannel:channel];
        if (bannedUser != nil) {
            /* We found the user in the userlist, we will use their information to ban the hostname. */
            banMask = [NSString stringWithFormat:@"*!*@%@", bannedUser.hostname];
        } else {
            /* This user dosen't seem to be online so we can't find their hostname. We will just do a general ban on their nick */
            banMask = [NSString stringWithFormat:@"%@!*@*", nickname];
        }
    }
    
    /* Set the ban. */
    [channel.client.connection send:[NSString stringWithFormat:@"MODE %@ +b %@", channel.name, banMask]];
}

+ (void)setTopic:(NSString *)topic onChannel:(NSString *)channel onClient:(IRCClient *)client
{
    [client.connection send:[NSString stringWithFormat:@"TOPIC %@ :%@", channel, topic]];
}

+ (void)setMode:(NSString *)topic onRecepient:(NSString *)recepient onClient:(IRCClient *)client
{
    [client.connection send:[NSString stringWithFormat:@"MODE %@ :%@", recepient, topic]];
}

+ (void)kickBanUser:(NSString *)nickname onChannel:(IRCChannel *)channel withMessage:(NSString *)message
{
    [IRCCommands banUser:nickname onChannel:channel];
    [IRCCommands kickUser:nickname onChannel:channel withMessage:message];
}

+ (void)sendServerPasswordForClient:(IRCClient *)client
{
    /* Send server password if applicable */
    if ([client.configuration.serverPasswordReference length] > 0) {
        NSString *password = [SSKeychain passwordForService:@"conversation" account:client.configuration.serverPasswordReference];
        if (password != nil && [password length] > 0) {
            [client.connection send:[NSString stringWithFormat:@"PASS %@", password]];
        } else {
            NSLog(@"A server password reference was found but no password: %@", client.configuration.serverPasswordReference);
        }
    }
}

+ (void)closeConversation:(id)conversation onClient:(IRCClient *)client
{
    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    [controller deleteConversationWithIdentifier:[[(IRCConversation*)conversation configuration] uniqueIdentifier]];
}

+ (void)onTimer:(float)seconds runCommand:(NSString *)command inConversation:(IRCConversation *)conversation
{
    /* Create the invocation for the command */
    SEL selector = @selector(performCommand:inConversation:);
    NSMethodSignature *signature = [self methodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:[InputCommands class]];
    [invocation setSelector:selector];
    [invocation setArgument:&command atIndex:2];
    [invocation setArgument:&conversation atIndex:3];
    
    /* Set the timer to run the invocation */
    [NSTimer scheduledTimerWithTimeInterval:seconds invocation:invocation repeats:NO];
}

@end

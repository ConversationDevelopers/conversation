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
#import "IRCChannel.h"
#import "IRCConversation.h"
#import "IRCCommands.h"

@implementation InputCommands

+ (void)performCommand:(NSString *)message inConversation:(IRCConversation *)conversation
{
    NSMutableArray *messageComponents = [[message componentsSeparatedByString:@" "] mutableCopy];
    if ([messageComponents count] > 0) {
        InputCommand command = [InputCommands indexValueFromString:[messageComponents[0] uppercaseString]];
        switch (command) {
            case CMD_ADMIN:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel givePrivilegieToUsers:messageComponents toStatus:ADMIN onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<user1> <user2> etc.."];
                }
                break;
            
            case CMD_BAN:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    NSString *nickname = messageComponents[1];
                    [IRCCommands banUser:nickname onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<nickname/host>"];
                }
                break;
                
            case CMD_CLEAR:
                [conversation.contentView clear];
                break;
                
            case CMD_CLEARALL:
                for (IRCChannel *channel in conversation.client.channels) {
                    [channel.contentView clear];
                }
                for (IRCChannel *query in conversation.client.queries) {
                    [query.contentView clear];
                }
                break;
                
            case CMD_CLOSE:
                if ([messageComponents count] > 1) {
                    id conversationToClose = [IRCConversation fromString:[messageComponents objectAtIndex:1] withClient:conversation.client];
                    [IRCCommands closeConversation:conversationToClose onClient:conversation.client];
                } else {
                    [IRCCommands closeConversation:conversation onClient:conversation.client];
                }
                break;
                
            case CMD_CTCP:
                if ([messageComponents count] > 2) {
                    NSString *recipient = messageComponents[1];
                    
                    NSRange range;
                    range.location = 0;
                    range.length = 2;
                    [messageComponents removeObjectsInRange:range];
                    
                    NSString *message = [messageComponents componentsJoinedByString:@" "];
                    [IRCCommands sendCTCPMessage:message toRecipient:recipient onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<channel/user> <command>"];
                }
                break;
                
            case CMD_CTCPREPLY:
                if ([messageComponents count] > 3) {
                    NSString *recipient = messageComponents[1];
                    
                    NSRange range;
                    range.location = 0;
                    range.length = 2;
                    [messageComponents removeObjectsInRange:range];
                    
                    NSString *message = [messageComponents componentsJoinedByString:@" "];
                    [IRCCommands sendCTCPReply:message toRecipient:recipient onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<channel/user> <command> <response>"];
                }
                break;
                break;
                
            case CMD_DEADMIN:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:ADMIN onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<user1> <user2> etc.."];
                }
                break;
                
            case CMD_DEHALFOP:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:HALFOP onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<user1> <user2> etc.."];
                }
                break;
                
            case CMD_DEOP:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:OPERATOR onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<user1> <user2> etc.."];
                }
                break;
                
            case CMD_DEVOICE:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:VOICE onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<user1> <user2> etc.."];
                }
                break;
                
            case CMD_DEOWNER:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:OWNER onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<user1> <user2> etc.."];
                }
                break;
                
            case CMD_ECHO:
                break;
                
            case CMD_HALFOP:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel givePrivilegieToUsers:messageComponents toStatus:HALFOP onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<user1> <user2> etc.."];
                }
                break;
                
            case CMD_CYCLE:
            case CMD_REJOIN:
            case CMD_HOP:
                if ([messageComponents count] > 1) {
                    NSString *channel = messageComponents[1];
                    NSString *partMessage = nil;
                    
                    if ([messageComponents count] > 2) {
                        NSRange range;
                        range.location = 0;
                        range.length = 2;
                        [messageComponents removeObjectsInRange:range];
                        
                        partMessage = [messageComponents componentsJoinedByString:@" "];
                    }
                    [IRCCommands rejoinChannel:channel withMessage:partMessage onClient:conversation.client];
                } else {
                    [IRCCommands rejoinChannel:[conversation name] withMessage:nil onClient:conversation.client];
                }
                break;
                
            case CMD_J:
            case CMD_JOIN:
                if ([messageComponents count] > 1) {
                    NSString *channel = messageComponents[1];
                    [IRCCommands joinChannel:channel onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<channel>"];
                }
                break;
                
            case CMD_K:
            case CMD_KICK:
                if ([messageComponents count] > 1) {
                    NSString *nickname = messageComponents[1];
                    IRCChannel *channel = (IRCChannel *)conversation;
                    NSString *kickMessage = nil;
                    
                    if ([messageComponents count] > 2) {
                        NSRange range;
                        range.location = 0;
                        range.length = 2;
                        [messageComponents removeObjectsInRange:range];
                        
                        kickMessage = [messageComponents componentsJoinedByString:@" "];
                    }
                    [IRCCommands kickUser:nickname onChannel:channel withMessage:kickMessage];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<nickname> [<message>]"];
                }
                break;
                
            case CMD_KB:
            case CMD_KICKBAN:
                if ([messageComponents count] > 1) {
                    NSString *nickname = messageComponents[1];
                    IRCChannel *channel = (IRCChannel *)conversation;
                    NSString *kickMessage = nil;
                    
                    if ([messageComponents count] > 2) {
                        NSRange range;
                        range.location = 0;
                        range.length = 2;
                        [messageComponents removeObjectsInRange:range];
                        
                        kickMessage = [messageComponents componentsJoinedByString:@" "];
                    }
                    [IRCCommands kickBanUser:nickname onChannel:channel withMessage:kickMessage];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<nickname> [<message>]"];
                }
                break;
                
            case CMD_PART:
            case CMD_LEAVE:
                if ([messageComponents count] > 1) {
                    NSString *channel = messageComponents[1];
                    NSString *partMessage = nil;
                    
                    if ([messageComponents count] > 2) {
                        NSRange range;
                        range.location = 0;
                        range.length = 2;
                        [messageComponents removeObjectsInRange:range];
                        
                        partMessage = [messageComponents componentsJoinedByString:@" "];
                    }
                    [IRCCommands leaveChannel:channel withMessage:partMessage onClient:conversation.client];
                } else {
                    [IRCCommands leaveChannel:[conversation name] withMessage:nil onClient:conversation.client];
                }
                break;
                
            case CMD_ME:
                if ([messageComponents count] > 1) {
                    [messageComponents removeObjectAtIndex:0];
                    NSString *message = [messageComponents componentsJoinedByString:@" "];
                    [IRCCommands sendACTIONMessage:message toRecipient:[conversation name] onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<action>"];
                }
                break;
                
            case CMD_MODE:
                if ([messageComponents count] > 2) {
                    NSString *recipient = messageComponents[1];
                    
                    NSRange range;
                    range.location = 0;
                    range.length = 2;
                    [messageComponents removeObjectsInRange:range];
                    
                    NSString *message = [messageComponents componentsJoinedByString:@" "];
                    [IRCCommands setMode:message onRecepient:recipient onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<nick/channel> <modes>"];
                }
                break;
                
            case CMD_MSG: {
                if ([messageComponents count] > 2) {
                    NSString *recipient = messageComponents[1];
                    
                    NSRange range;
                    range.location = 0;
                    range.length = 2;
                    [messageComponents removeObjectsInRange:range];
                    
                    NSString *message = [messageComponents componentsJoinedByString:@" "];
                    [IRCCommands sendMessage:message toRecipient:recipient onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<channel/user> <message>"];
                }
                break;
            }
                
            case CMD_MUTE:
                break;
                
            case CMD_MYVERSION:
                [IRCCommands sendMessage:[NSString stringWithFormat:@"%cCurrent Version:%c Conversation %@ (https://github.com/ConversationDevelopers/conversation)",
                                          IRC_BOLD,
                                          IRC_BOLD,
                                          [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]]
                  toRecipient:[conversation name] onClient:[conversation client]];
                break;
                
            case CMD_NICK:
                if ([messageComponents count] > 1) {
                    [messageComponents removeObjectAtIndex:0];
                    NSString *message = [messageComponents componentsJoinedByString:@" "];
                    [IRCCommands changeNicknameToNick:message onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<new nickname>"];
                }
                break;
                
            case CMD_NOTICE:
                if ([messageComponents count] > 2) {
                    NSString *recipient = messageComponents[1];
                    
                    NSRange range;
                    range.location = 0;
                    range.length = 2;
                    [messageComponents removeObjectsInRange:range];
                    
                    NSString *message = [messageComponents componentsJoinedByString:@" "];
                    [IRCCommands sendNotice:message toRecipient:recipient onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<channel/user> <message>"];
                }
                break;
                
            case CMD_OP:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel givePrivilegieToUsers:messageComponents toStatus:OPERATOR onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<user1> <user2> etc.."];
                }
                break;
                
            case CMD_OWNER:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:OWNER onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<user1> <user2> etc.."];
                }
                break;
                
            case CMD_QUERY:
                break;
                
            case CMD_QUIT:
                if ([messageComponents count] > 1) {
                    [messageComponents removeObjectAtIndex:0];
                    NSString *quitMessage = [messageComponents componentsJoinedByString:@" "];
                    [conversation.client disconnectWithMessage:quitMessage];
                } else {
                    [conversation.client disconnect];
                }
                break;
                
            case CMD_QUOTE:
            case CMD_RAW:
                if ([messageComponents count] > 1) {
                    [messageComponents removeObjectAtIndex:0];
                    NSString *commandString = [messageComponents componentsJoinedByString:@" "];
                    [conversation.client.connection send:commandString];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<command>"];
                }
                break;
                
            case CMD_TIMER:
                if ([messageComponents count] > 2) {
                    float seconds = [messageComponents[1] floatValue];
                    
                    NSRange range;
                    range.location = 0;
                    range.length = 2;
                    [messageComponents removeObjectsInRange:range];
                    NSString *commandMessage = [messageComponents componentsJoinedByString:@" "];
                    [IRCCommands onTimer:seconds runCommand:commandMessage inConversation:conversation];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<seconds> <command>"];
                }
                break;
                
            case CMD_TOPIC:
                if ([messageComponents count] > 2) {
                    NSString *recipient = messageComponents[1];
                    
                    NSRange range;
                    range.location = 0;
                    range.length = 2;
                    [messageComponents removeObjectsInRange:range];
                    
                    NSString *message = [messageComponents componentsJoinedByString:@" "];
                    [IRCCommands setTopic:message onChannel:recipient onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<channel> <topic>"];
                }
                break;
                
            case CMD_UMODE:
                if ([messageComponents count] > 1) {
                    NSString *modes = messageComponents[1];
                    [IRCCommands setMode:modes onRecepient:conversation.client.currentUserOnConnection.nick onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<modes>"];
                }
                break;
                
            case CMD_UNBAN:
                break;
                
            case CMD_UNMUTE:
                break;
                
            case CMD_VOICE:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel givePrivilegieToUsers:messageComponents toStatus:VOICE onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:@"<user1> <user2> etc.."];
                }
                break;
                
            default:
                [conversation.client.connection send:message];
                break;
        }
    }
}

+ (void)incompleteParametersError:(NSInteger)command withParameters:(NSString *)parameters
{
    
}

+ (void)sendMessage:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client
{
    [IRCCommands sendMessage:message toRecipient:recipient onClient:client];
}

+ (NSUInteger)indexValueFromString:(NSString *)key
{
    return [[InputCommands inputCommandReference] indexOfObject:key];
}

+ (NSArray *)inputCommandReference
{
    return @[
        @"ADMIN",
        @"BAN",
        @"CLEAR",
        @"CLEARALL",
        @"CLOSE",
        @"CTCP",
        @"CTCPREPLY",
        @"CYCLE",
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
        @"K",
        @"KB",
        @"KICK",
        @"KICKBAN",
        @"LEAVE",
        @"ME",
        @"MODE",
        @"MSG",
        @"MUTE",
        @"MYVERSION",
        @"NICK",
        @"OP",
        @"NOTICE",
        @"OWNER",
        @"PART",
        @"QUERY",
        @"QUIT",
        @"QUOTE",
        @"RAW",
        @"REJOIN",
        @"TIMER",
        @"TOPIC",
        @"VOICE",
        @"UMODE",
        @"UNBAN",
        @"UNMUTE"
    ];
}

@end

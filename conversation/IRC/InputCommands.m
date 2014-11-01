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
        InputCommand command = [InputCommands indexValueFromString:messageComponents[0]];
        switch (command) {
            case CMD_ADMIN:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel givePrivilegieToUsers:messageComponents toStatus:ADMIN onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:@"/ADMIN <user1> <user2> etc.."];
                }
                break;
            
            case CMD_BAN:
                break;
                
            case CMD_CLEAR:
                break;
                
            case CMD_CLEARALL:
                break;
                
            case CMD_CLOSE:
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
                    [InputCommands incompleteParametersError:@"/CTCP <channel/user> <command>"];
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
                    [InputCommands incompleteParametersError:@"/CTCPREPLY <channel/user> <command> <response>"];
                }
                break;
                break;
                
            case CMD_DEADMIN:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:ADMIN onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:@"/DEADMIN <user1> <user2> etc.."];
                }
                break;
                
            case CMD_DEHALFOP:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:HALFOP onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:@"/DEHALFOP <user1> <user2> etc.."];
                }
                break;
                
            case CMD_DEOP:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:OPERATOR onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:@"/DEOP <user1> <user2> etc.."];
                }
                break;
                
            case CMD_DEVOICE:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:VOICE onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:@"/DEVOICE <user1> <user2> etc.."];
                }
                break;
                
            case CMD_DEOWNER:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:OWNER onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:@"/DEOWNER <user1> <user2> etc.."];
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
                    [InputCommands incompleteParametersError:@"/HALFOP <user1> <user2> etc.."];
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
                    [InputCommands incompleteParametersError:@"/JOIN <channel>"];
                }
                break;
                
            case CMD_K:
            case CMD_KICK:
                break;
                
            case CMD_KB:
            case CMD_KICKBAN:
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
                    [IRCCommands leaveChannel:channel withMessage:message onClient:conversation.client];
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
                    [InputCommands incompleteParametersError:@"/ME <action>"];
                }
                break;
                
            case CMD_MODE:
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
                    [InputCommands incompleteParametersError:@"/MSG <channel/user> <message>"];
                }
                break;
            }
                
            case CMD_MUTE:
                break;
                
            case CMD_NICK:
                if ([messageComponents count] > 1) {
                    [messageComponents removeObjectAtIndex:0];
                    NSString *message = [messageComponents componentsJoinedByString:@" "];
                    [IRCCommands changeNicknameToNick:message onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:@"/NICK <new nickname>"];
                }
                break;
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
                    [InputCommands incompleteParametersError:@"/NOTICE <channel/user> <message>"];
                }
                break;
                
            case CMD_OP:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel givePrivilegieToUsers:messageComponents toStatus:OPERATOR onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:@"/OP <user1> <user2> etc.."];
                }
                break;
                
            case CMD_OWNER:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:OWNER onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:@"/OWNER <user1> <user2> etc.."];
                }
                break;
                
            case CMD_QUERY:
                break;
                
            case CMD_QUIT:
                break;
                
            case CMD_QUOTE:
            case CMD_RAW:
                break;
                
            case CMD_TOPIC:
                break;
                
            case CMD_UMODE:
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
                    [InputCommands incompleteParametersError:@"/VOICE <user1> <user2> etc.."];
                }
                break;
                
            default:
                [conversation.client.connection send:message];
                break;
        }
    }
}

+ (void)incompleteParametersError:(NSString *)parameters
{
    
}

+ (void)sendMessage:(NSString *)message toRecipient:(NSString *)recipient onClient:(IRCClient *)client
{
    [IRCCommands sendMessage:message toRecipient:recipient onClient:client];
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
        @"OWNER",
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

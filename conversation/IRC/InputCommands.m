/*
 Copyright (c) 2014", Tobias Pollmann.
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
#import "ConversationListViewController.h"
#import "ChatViewController.h"
#import "ChannelListViewController.h"
#import "BuildConfig.h"
#import "DeviceInformation.h"
#import "NSArray+Methods.h"
#import "UserInfoViewController.h"

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
					[InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<user1> <user2> etc..", @"<user1> <user2> etc..") inConversation:conversation];
                }
                break;
            
            case CMD_BAN:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    NSString *nickname = messageComponents[1];
                    [IRCCommands banUser:nickname onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<nickname/host>", @"<nickname/host>") inConversation:conversation];
                }
                break;
                
            case CMD_CLEAR:
                [conversation clear];
                break;
                
            case CMD_CLEARALL:
                for (IRCChannel *channel in conversation.client.channels) {
                    [channel clear];
                }
                for (IRCChannel *query in conversation.client.queries) {
                    [query clear];
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
                    
					NSString *message = [messageComponents componentsJoinedByString:@" " fromIndex:3];
                    [IRCCommands sendCTCPMessage:message toRecipient:recipient onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<channel/user> <command>", @"<channel/user> <command>") inConversation:conversation];
                }
                break;
                
            case CMD_CTCPREPLY:
                if ([messageComponents count] > 3) {
                    NSString *recipient = messageComponents[1];
					
					NSString *message = [messageComponents componentsJoinedByString:@" " fromIndex:3];
                    [IRCCommands sendCTCPReply:message toRecipient:recipient onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<channel/user> <command> <response>", @"<channel/user> <command> <response>") inConversation:conversation];
                }
                break;
                break;
                
            case CMD_DEADMIN:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:ADMIN onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<user1> <user2> etc..", @"<user1> <user2> etc..") inConversation:conversation];
                }
                break;
                
            case CMD_DEHALFOP:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:HALFOP onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<user1> <user2> etc..", @"<user1> <user2> etc..") inConversation:conversation];
                }
                break;
                
            case CMD_DEOP:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:OPERATOR onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<user1> <user2> etc..", @"<user1> <user2> etc..") inConversation:conversation];
                }
                break;
                
            case CMD_DEVOICE:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:VOICE onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<user1> <user2> etc..", @"<user1> <user2> etc..") inConversation:conversation];
                }
                break;
                
            case CMD_DEOWNER:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:OWNER onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<user1> <user2> etc..", @"<user1> <user2> etc..") inConversation:conversation];
                }
                break;
                
            case CMD_DETACH:
                if ([messageComponents count] > 1) {
                    [messageComponents removeObjectAtIndex:0];
                    [InputCommands performCommand:[NSString stringWithFormat:@"ZNC DETACH %@", [messageComponents componentsJoinedByString:@" "]] inConversation:conversation];
                    
                } else {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    if ([channel isKindOfClass:[channel class]]) {
                        channel.configuration.autoJoin = NO;
                        [InputCommands performCommand:[NSString stringWithFormat:@"ZNC DETACH %@", channel.name] inConversation:conversation];
                    } else
                        [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<channel1> <channel2> etc..", @"") inConversation:conversation];
                }
                break;
                
            case CMD_HALFOP:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel givePrivilegieToUsers:messageComponents toStatus:HALFOP onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<user1> <user2> etc..", @"") inConversation:conversation];
                }
                break;
                
            case CMD_CYCLE:
            case CMD_REJOIN:
            case CMD_HOP:
                if ([messageComponents count] > 1) {
                    NSString *channel = messageComponents[1];
                    NSString *partMessage = nil;
                    
					if ([messageComponents count] > 2) {
						partMessage = [messageComponents componentsJoinedByString:@" " fromIndex:3];
                    }
                    [IRCCommands rejoinChannel:channel withMessage:partMessage onClient:conversation.client];
                } else {
                    [IRCCommands rejoinChannel:[conversation name] withMessage:nil onClient:conversation.client];
                }
                break;
            case CMD_IGNORE: {
                if ([messageComponents count] > 1) {
                    NSString *mask = messageComponents[1];
                    if ([mask isValidUsername]) {
                        mask = [NSString stringWithFormat:@"%@!*@*", mask];
                    }
                    if ([mask isValidWildcardIgnoreMask]) {
                        NSMutableArray *array = [[NSMutableArray alloc] initWithArray:conversation.client.configuration.ignores];
                        [array addObject:mask];
                        conversation.client.configuration.ignores = [array copy];
                    }
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<hostmask>", @"<hostmask>") inConversation:conversation];
                }
                break;
            }
            case CMD_INVITE: {
                if ([messageComponents count] > 1) {
                    NSString *channel;
                    if ([messageComponents count] < 3) {
                        if ([conversation.name isValidChannelName:conversation.client])
                            channel = conversation.name;
                        else
                            [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<nick> [channel]", @"<nick> [channel]") inConversation:conversation];
                        
                    } else {
                        channel = [messageComponents objectAtIndex:2];
                    }
                    NSString *cmd = [NSString stringWithFormat:@"INVITE %@ %@", [messageComponents objectAtIndex:1], channel];
                    [conversation.client.connection send:cmd];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<nickname> [channel]", @"<nickname> [channel]") inConversation:conversation];
                }
                break;
            }
            case CMD_J:
            case CMD_JOIN:
                if ([messageComponents count] > 1) {
                    NSString *channel = messageComponents[1];
                    [IRCCommands joinChannel:channel onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<channel>", @"<channel>") inConversation:conversation];
                }
                break;
                
            case CMD_K:
            case CMD_KICK:
                if ([messageComponents count] > 1) {
                    NSString *nickname = messageComponents[1];
                    IRCChannel *channel = (IRCChannel *)conversation;
                    NSString *kickMessage = nil;
                    
					if ([messageComponents count] > 2) {
						kickMessage = [messageComponents componentsJoinedByString:@" " fromIndex:3];
                    }
                    [IRCCommands kickUser:nickname onChannel:channel withMessage:kickMessage];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<nickname> [message]", @"<nickname> [message]") inConversation:conversation];
                }
                break;
                
            case CMD_KB:
            case CMD_KICKBAN:
                if ([messageComponents count] > 1) {
                    NSString *nickname = messageComponents[1];
                    IRCChannel *channel = (IRCChannel *)conversation;
                    NSString *kickMessage = nil;
                    
					if ([messageComponents count] > 2) {
						kickMessage = [messageComponents componentsJoinedByString:@" " fromIndex:3];
                    }
                    [IRCCommands kickBanUser:nickname onChannel:channel withMessage:kickMessage];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<nickname> [message]", @"<nickname> [message]") inConversation:conversation];
                }
                break;
                
            case CMD_PART:
            case CMD_LIST: {
                ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
                ChannelListViewController *channelList = [[ChannelListViewController alloc] init];
                channelList.client = conversation.client;
                UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:channelList];
                navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
                navigationController.navigationBar.tintColor = [UIColor lightGrayColor];
                navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
                navigationController.navigationBar.translucent = NO;
                [controller presentViewController:navigationController animated:YES completion:^(void){
                    [controller.chatViewController hideAccessories:nil];
                }];
                break;
            }
            case CMD_LEAVE:
                if ([messageComponents count] > 1) {
                    NSString *channel = messageComponents[1];
                    NSString *partMessage = nil;
                    
					if ([messageComponents count] > 2) {
						partMessage = [messageComponents componentsJoinedByString:@" " fromIndex:3];
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
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<action>", @"<action>") inConversation:conversation];
                }
                break;
                
            case CMD_MODE:
                if ([messageComponents count] > 2) {
                    NSString *recipient = messageComponents[1];
					
					NSString *message = [messageComponents componentsJoinedByString:@" " fromIndex:3];
                    [IRCCommands setMode:message onRecepient:recipient onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<nick/channel> <modes>", @"<nick/channel> <modes>") inConversation:conversation];
                }
                break;
                
            case CMD_MSG: {
                if ([messageComponents count] > 2) {
                    NSString *recipient = messageComponents[1];
					
					NSString *message = [messageComponents componentsJoinedByString:@" " fromIndex:3];
                    [IRCCommands sendMessage:message toRecipient:recipient onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<channel/user> <message>", @"<channel/user> <message>") inConversation:conversation];
                }
                break;
            }
                
            case CMD_MYVERSION:
                [IRCCommands sendMessage:[NSString stringWithFormat:NSLocalizedString(@"%cCurrent Version:%c %@ %@-%@ (Build Date: %@) (%@)",
																					  @"{bold}Current Version:{end bold} {Bundle name} {Version name}-{Build reference} (Build Date: {Build date}) ({Build Type})"),
                                          IRC_BOLD,
                                          IRC_BOLD,
                                          ConversationBundleName,
                                          ConversationVersion,
                                          ConversationBuildRef,
                                          ConversationBuildDate,
                                          ConversationBuildType]
                  toRecipient:[conversation name] onClient:[conversation client]];
                break;
                
            case CMD_NICK:
                if ([messageComponents count] > 1) {
                    [messageComponents removeObjectAtIndex:0];
                    NSString *message = [messageComponents componentsJoinedByString:@" "];
                    [IRCCommands changeNicknameToNick:message onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<new nickname>", @"<new nickname>") inConversation:conversation];
                }
                break;
                
            case CMD_NOTICE:
                if ([messageComponents count] > 2) {
                    NSString *recipient = messageComponents[1];
					
					NSString *message = [messageComponents componentsJoinedByString:@" " fromIndex:3];
                    [IRCCommands sendNotice:message toRecipient:recipient onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<channel/user> <message>", @"<channel/user> <message>") inConversation:conversation];
                }
                break;
                
            case CMD_OP:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel givePrivilegieToUsers:messageComponents toStatus:OPERATOR onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<user1> <user2> etc..", @"<user1> <user2> etc..") inConversation:conversation];
                }
                break;
                
            case CMD_OWNER:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel revokePrivilegieFromUsers:messageComponents toStatus:OWNER onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<user1> <user2> etc..", @"<user1> <user2> etc..") inConversation:conversation];
                }
                break;
                
            case CMD_QUERY:
                if ([messageComponents count] > 1) {
                    [messageComponents removeObjectAtIndex:0];
                    NSString *name = [messageComponents componentsJoinedByString:@" "];
                    [IRCConversation getConversationOrCreate:name onClient:conversation.client withCompletionHandler:^(IRCConversation *conversation) {
                        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
                        [controller selectConversationWithIdentifier:conversation.configuration.uniqueIdentifier];
                    }];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<user>", @"<user>") inConversation:conversation];
                }
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
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<command>", @"<command>") inConversation:conversation];
                }
                break;
				
			case CMD_SSLCONTEXT:
				if (conversation.client.certificate) {
					IRCCertificateTrust *trustDialog = [[IRCCertificateTrust alloc] init:conversation.client.certificate onClient:conversation.client];
					[trustDialog displayCertificateInformation];
				}
				break;
			
				
				
            case CMD_SYSINFO: {
                NSString *infoString = [NSString stringWithFormat:@"System Information: %cModel:%c %@ %cOS%c: iOS %@ %cOrientation:%c %@ %cBattery Level:%c %@",
                                        IRC_BOLD,
                                        IRC_BOLD,
                                        [DeviceInformation deviceName],
                                        IRC_BOLD,
                                        IRC_BOLD,
                                        [DeviceInformation firmwareVersion],
                                        IRC_BOLD,
                                        IRC_BOLD,
                                        [DeviceInformation orientation],
                                        IRC_BOLD,
                                        IRC_BOLD,
                                        [DeviceInformation batteryLevel]
                                        ];
                [IRCCommands sendMessage:infoString toRecipient:[conversation name] onClient:conversation.client];
                break;
            }
            case CMD_TIMER:
                if ([messageComponents count] > 2) {
                    float seconds = [messageComponents[1] floatValue];
					
					NSString *commandMessage = [messageComponents componentsJoinedByString:@" " fromIndex:3];
                    [IRCCommands onTimer:seconds runCommand:commandMessage inConversation:conversation];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<seconds> <command>", @"<seconds> <command>") inConversation:conversation];
                }
                break;
                
            case CMD_TOPIC:
                if ([messageComponents count] > 2) {
                    NSString *recipient = messageComponents[1];
					
					NSString *message = [messageComponents componentsJoinedByString:@" " fromIndex:3];
                    [IRCCommands setTopic:message onChannel:recipient onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<channel> <topic>", @"<channel> <topic>") inConversation:conversation];
                }
                break;
                
            case CMD_UMODE:
                if ([messageComponents count] > 1) {
                    NSString *modes = messageComponents[1];
                    [IRCCommands setMode:modes onRecepient:conversation.client.currentUserOnConnection.nick onClient:conversation.client];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<modes>", @"<modes>") inConversation:conversation];
                }
                break;
                
            case CMD_UNBAN:
                break;
            case CMD_UNIGNORE: {
                if ([messageComponents count] > 1) {
                    NSString *mask = messageComponents[1];
                    if ([mask isValidUsername]) {
                        mask = [NSString stringWithFormat:@"%@!*@*", mask];
                    }
                    if ([mask isValidWildcardIgnoreMask]) {
                        NSMutableArray *array = [[NSMutableArray alloc] init];
                        for (NSString *string in array) {
                            if ([string isEqualToString:mask] == NO)
                                [array addObject:string];
                        }
                        conversation.client.configuration.ignores = [array copy];
                    }
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<hostmask>", @"<hostmask>") inConversation:conversation];
                }
                break;
                
            }
            case CMD_VOICE:
                if ([messageComponents count] > 1) {
                    IRCChannel *channel = (IRCChannel *)conversation;
                    [messageComponents removeObjectAtIndex:0];
                    [channel givePrivilegieToUsers:messageComponents toStatus:VOICE onChannel:channel];
                } else {
                    [InputCommands incompleteParametersError:command withParameters:NSLocalizedString(@"<user1> <user2> etc..", @"<user1> <user2> etc..") inConversation:conversation];
                }
                break;
                
            case CMD_WHOIS: {
                if ([messageComponents count] > 1) {
                    [messageComponents removeObjectAtIndex:0];
                    NSString *nick = [messageComponents objectAtIndex:0];
                    
                    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
                    UserInfoViewController *infoViewController = [[UserInfoViewController alloc] init];
                    infoViewController.nickname = nick;
                    infoViewController.client = conversation.client;
                    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:infoViewController];
                    
                    navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
                    [controller presentViewController:navigationController animated:YES completion:^(void){
                        [controller.chatViewController hideAccessories:nil];
                    }];
                    
                }
            }
                break;
                
            default:
                [conversation.client.connection send:message];
                break;
        }
    }
}

+ (void)incompleteParametersError:(NSInteger)command withParameters:(NSString *)parameters inConversation:conversation
{
	IRCMessage *messageObject = [[IRCMessage alloc] initWithMessage:[NSString stringWithFormat:
																	 NSLocalizedString(@"Command usage: /%@ %@", @"Command usage: /{Name of command} {Syntax for command}"),
																	 [[InputCommands inputCommandReference] objectAtIndex:command],
																	 parameters]
															 OfType:ET_ERROR
													 inConversation:conversation
														   bySender:nil
															 atTime:[NSDate date]
														   withTags:nil
													isServerMessage:YES
														   onClient:[conversation client]];
	[Messages clientReceivedRecoverableErrorFromServer:messageObject];
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
        @"DETACH",
        @"HALFOP",
        @"HOP",
        @"IGNORE",
        @"INVITE",
        @"J",
        @"JOIN",
        @"K",
        @"KB",
        @"KICK",
        @"KICKBAN",
        @"LEAVE",
        @"LIST",
        @"ME",
        @"MODE",
        @"MSG",
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
		@"SSLCONTEXT",
        @"SYSINFO",
        @"TIMER",
        @"TOPIC",
        @"UNIGNORE",
        @"UMODE",
        @"UNBAN",
        @"VOICE",
        @"WHOIS",
        @"ZNC"
    ];
}

@end

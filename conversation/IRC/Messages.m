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

#import "Messages.h"
#import "IRCUser.h"
#import "IRCClient.h"
#import "IRCConnection.h"
#import "IRCMessage.h"
#import "IRCKickMessage.h"
#import "ConversationListViewController.h"
#import "znc-buffextras.h"
#import "AppPreferences.h"
#import "IRCCommands.h"

#define AssertIsNotServerMessage(x) if ([x isServerMessage] == YES) return;

@implementation Messages

+ (void)clientReceivedAuthenticationMessage:(IRCMessage *)message
{
    /* This method is called when the client has received an authentication SASL request from the server under initial negotiation. */
    if (message.client.isAwaitingAuthenticationResponse) {
        if (message.client.configuration.authenticationPasswordReference) {
            /* Retrieve the appropriate password from keychain using our identifier from the user's preferences */
            NSString *password = [SSKeychain passwordForService:@"conversation" account:message.client.configuration.authenticationPasswordReference];
            if (password != nil && [password length] > 0) {
                /* Send authentication to the server. As of now we only support SASL PLAIN authentication. Which is username username password encoded
                 in base64 separated by an ASCII null termination character. */
                NSData *authenticationStringAsBinaryData = [[NSString stringWithFormat:@"%@\0%@\0%@",
                                                             message.client.configuration.usernameForRegistration,
                                                             message.client.configuration.usernameForRegistration,
                                                             password]
                                                            dataUsingEncoding:NSUTF8StringEncoding];
                
                [message.client.connection send:[NSString stringWithFormat:@"AUTHENTICATE %@", [authenticationStringAsBinaryData base64EncodedStringWithOptions:0]]];
                return;
            } else {
                /* We had a reference to an item in keychain but the keychain item didn't exist for some reason.
                 We will act like there is no password saved and abort authentication. */
                NSLog(@"An authentication password reference was found but no password: %@", message.client.configuration.authenticationPasswordReference);
            }
        }
    }
    /* Authentication was unsuccessful somewhere earlier in the method so we will abort authentication.*/
    [message.client.connection send:@"CAP END"];
}

+ (void)clientReceivedAuthenticationAccepted:(IRCMessage *)message
{
    /* Our password has bene accepted by SASL and we can end the authentication process and continue registration */
    message.client.isAwaitingAuthenticationResponse = NO;
    [message.client.connection send:@"CAP END"];
}

+ (void)clientreceivedAuthenticationAborted:(IRCMessage *)message
{
    /* Authentication was aborted either by the servers actions or ours. We will continue registration as normal. */
    message.client.isAwaitingAuthenticationResponse = NO;
}

+ (void)clientReceivedAuthenticationError:(IRCMessage *)message
{
    /* SASL has rejected our authentication attempt, the username, password, or authentication method is wrong.
    We will stop attempting authentication at this point and just try again with nickserv if possible at a later stage. */
    [message.client.connection send:@"CAP END"];
}

+ (void)clientReceivedCAPMessage:(IRCMessage *)message
{
    /* Client received An IRCv3 CAP message. We will parse the message and find out what command it is sending. */
    NSMutableArray *messageComponents = [[[message message] componentsSeparatedByString:@" "] mutableCopy];
    NSString *command = [messageComponents objectAtIndex:0];
    
    [messageComponents removeObjectAtIndex:0];
    
    /* The message may be a single word command, but in case it is not, we will get the remaining text */
    NSString *parameters = [messageComponents componentsJoinedByString:@" "];
    
    /* This next bit may be prefixed by an ':' let's consume it. */
    if ([parameters hasPrefix:@":"]) {
        parameters = [parameters substringFromIndex:1];
    }
    
    /* Parse the command we retrived and call the appropriate method. */
    CapMessageType capIndexValue = [IRCMessageIndex capIndexValueFromString:command];
    switch (capIndexValue) {
        case CAP_LS:
            /* The server has returned a list of capabilities. We will call the method to negotiate these with the server. */
            [Messages clientReceivedListOfServerIRCv3Capabilities:parameters onClient:message.client];
            break;
            
        case CAP_ACK:
            /* The server has accepted our requested list of capabilities. */
            [Messages clientReceivedAcknowledgedCapabilities:parameters onClient:message.client];
            break;
            
        case CAP_NAK:
            /* The server has rejected our requested list of capabilities. It is not worth wasting time trying to negotiate why so let's just
             end negotiating and connect in IRCv2 mode. */
            [message.client.connection send:@"CAP END"];
            break;
            
        case CAP_CLEAR:
            /* The server has asked us to clear our IRCv3 capabilities. Possibly in await for a new list of capabilities. */
            message.client.ircv3CapabilitiesSupportedByServer = [[NSMutableArray alloc] init];
            break;
            
        default:
            break;
    }
}

+ (void)clientReceivedListOfServerIRCv3Capabilities:(NSString *)capabilities onClient:(IRCClient *)client
{
    NSArray *capabilitiesList = [capabilities componentsSeparatedByString:@" "];
    
    NSMutableArray *capabilitiesToNegotiate = [[NSMutableArray alloc] init];
    for (NSString *capability in capabilitiesList) {
        /* Check if our application supports this capability, if it does we will add it to the list of capabilities to request later */
        if ([[IRCClient IRCv3CapabilitiesSupportedByApplication] indexOfObject:capability] != NSNotFound) {
            [capabilitiesToNegotiate addObject:capability];
        }
    }
    
    if ([capabilitiesToNegotiate count] > 0) {
        /* We were able to find at least one IRCv3 capability that both our application and the server supports. We will request them. */
        NSString *negotiateCapabilitiesString = [capabilitiesToNegotiate componentsJoinedByString:@" "];
        [client.connection send:[NSString stringWithFormat:@"CAP REQ :%@", negotiateCapabilitiesString]];
    } else {
        /* We couldn't agree on any feature set to use :( End negotiation and continue registration */
        [client.connection send:@"CAP END"];
    }
}

+ (void)clientReceivedAcknowledgedCapabilities:(NSString *)capabilities onClient:(IRCClient *)client
{
    /* The server accepted our requested list of capabilities to enable. Let's add them to our list so other parts of
     the application are aware of them being turned on. */
    NSArray *capabilitiesList = [capabilities componentsSeparatedByString:@" "];
    client.ircv3CapabilitiesSupportedByServer = [capabilitiesList mutableCopy];
    
    if ([client.ircv3CapabilitiesSupportedByServer indexOfObject:@"sasl"] != NSNotFound) {
        /* This server supports SASL based authentication. We will atttempt to use it if applicable. */
        NSString *password = [SSKeychain passwordForService:@"conversation" account:client.configuration.authenticationPasswordReference];
        if (password != nil && [password length] > 0) {
            client.isAwaitingAuthenticationResponse = YES;
            [client.connection send:@"AUTHENTICATE PLAIN"];
            return;
        }
    }
    /* there is nothing more for us to do. End negotiation and continue registration. */
    [client.connection send:@"CAP END"];
}

+ (void)userReceivedMessage:(IRCMessage *)message
{
    AssertIsNotServerMessage(message);
    
    if ([[message message] hasPrefix:@"\001"] && [[message message] hasSuffix:@"\001"]) {
        [self userReceivedCTCPMessage:message];
        return;
    }
    
    message.messageType = ET_PRIVMSG;
    
    [IRCConversation getConversationOrCreate:[[message conversation] name] onClient:[message client] withCompletionHandler:^(IRCConversation *conversation) {
        message.conversation = conversation;
        [conversation addMessageToConversation:message];
    }];
}

+ (void)userReceivedCTCPMessage:(IRCMessage *)message
{
    /* Check that the message contains both CTCP characters and at least one other character */
    if ([[message message] length] > 3) {
        /* Consume the begining and ending CTCP character (0x01) */
        message.message = [[message message] substringWithRange:NSMakeRange(1, [[message message] length] - 2)];
        
        NSMutableArray *messageComponents = [[[message message] componentsSeparatedByString:@" "] mutableCopy];
        
        
        #define isCTCPCommand(x) [[message message] caseInsensitiveCompare:x] == NSOrderedSame
        
        if (isCTCPCommand(@"ACTION")) {
            [messageComponents removeObjectAtIndex:0];
            message.message = [messageComponents componentsJoinedByString:@" "];
            
            [self userReceivedACTIONMessage:message];
        } else {
            message.message = [messageComponents objectAtIndex:0];
            message.messageType = ET_CTCP;
            
            if (isCTCPCommand(@"VERSION")) {
                [IRCCommands sendCTCPReply:[NSString stringWithFormat:@"VERSION Conversation %@ (https://github.com/ConversationDevelopers/conversation)",
                                            [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]]
                               toRecipient:[[message sender] nick] onClient:[message client]];
            } else if (isCTCPCommand(@"TIME")) {
                NSDate* now = [NSDate date];
                NSDateFormatter* df = [[NSDateFormatter alloc] init];
                [df setDateStyle:NSDateFormatterFullStyle];
                [df setTimeStyle:NSDateFormatterFullStyle];
                [IRCCommands sendCTCPReply:[NSString stringWithFormat:@"TIME %@",
                                            [df stringFromDate:now]]
                               toRecipient:[[message sender] nick]
                                  onClient:[message client]];
            } else if (isCTCPCommand(@"SOURCE")) {
                [IRCCommands sendCTCPReply:@"https://github.com/ConversationDevelopers/conversation"
                               toRecipient:[[message sender] nick]
                                  onClient:[message client]];
            } else if (isCTCPCommand(@"CLIENTINFO")) {
                [IRCCommands sendCTCPReply:@"CLIENTINFO VERSION TIME SOURCE PING CLIENTINFO"
                               toRecipient:[[message sender] nick]
                                  onClient:[message client]];
            } else if (isCTCPCommand(@"PING")) {
                [IRCCommands sendCTCPReply:[NSString stringWithFormat:@"PING %f",
                                            [[NSDate date] timeIntervalSince1970]]
                               toRecipient:[[message sender] nick] onClient:[message client]];
            }
            
            [IRCConversation getConversationOrCreate:[[message conversation] name] onClient:[message client] withCompletionHandler:^(IRCConversation *conversation) {
                message.conversation = conversation;
                [conversation addMessageToConversation:message];
            }];
        }
    }
}

+ (void)userReceivedACTIONMessage:(IRCMessage *)message
{
    message.messageType = ET_ACTION;
    
    [IRCConversation getConversationOrCreate:[[message conversation] name] onClient:[message client] withCompletionHandler:^(IRCConversation *conversation) {
        message.conversation = conversation;
        [conversation addMessageToConversation:message];
    }];
}

+ (void)userReceivedNotice:(IRCMessage *)message
{
    if ([[message message] hasPrefix:@"\001"] && [[message message] hasSuffix:@"\001"]) {
        [self userReceivedCTCPReply:message];
        return;
    }
    
    AssertIsNotServerMessage(message);
    
    message.messageType = ET_NOTICE;
    
    [IRCConversation getConversationOrCreate:[[message conversation] name] onClient:[message client] withCompletionHandler:^(IRCConversation *conversation) {
        message.conversation = conversation;
        [conversation addMessageToConversation:message];
    }];
}

+ (void)userReceivedCTCPReply:(IRCMessage *)message
{
    AssertIsNotServerMessage(message);
    
    /* Check that the message contains both CTCP characters and at least one other character */
    if ([[message message] length] > 3) {
        message.message = [[message message] substringWithRange:NSMakeRange(1, [[message message] length] - 2)];
        NSMutableArray *messageComponents = [[[message message] componentsSeparatedByString:@" "] mutableCopy];
        
        message.message = [messageComponents objectAtIndex:0];
        message.messageType = ET_CTCPREPLY;
        
        [IRCConversation getConversationOrCreate:[[message conversation] name] onClient:[message client] withCompletionHandler:^(IRCConversation *conversation) {
            message.conversation = conversation;
            [conversation addMessageToConversation:message];
        }];
    }
}

+ (void)userReceivedJoinOnChannel:(IRCMessage *)message
{
    IRCChannel *channel = (IRCChannel *)message.conversation;
    if ([[[message sender] nick] caseInsensitiveCompare:message.client.currentUserOnConnection.nick] == NSOrderedSame) {
        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
        [message.client.connection send:[NSString stringWithFormat:@"WHO %@", message.conversation.name]];
        [message.client.connection send:[NSString stringWithFormat:@"MODE %@", message.conversation.name]];
        
        channel.isJoinedByUser = YES;
        message.conversation = channel;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [controller reloadClient:message.client];
        });
    }
    
    if (IRCv3CapabilityEnabled(message.client, @"extended-join") && [[message message] length] > 0) {
        NSString *realname = [message message];
        if ([realname hasPrefix:@":"]) {
            realname = [realname substringFromIndex:1];
        }
        message.sender.realname = realname;
    }
    
    message.messageType = ET_JOIN;
    [[channel users] addObject:[message sender]];
    message.conversation = channel;
    
    
    [[message conversation] addMessageToConversation:message];
}

+ (void)userReceivedPartChannel:(IRCMessage *)message
{
    IRCChannel *channel = (IRCChannel *)message.conversation;
    if ([[[message sender] nick] caseInsensitiveCompare:message.client.currentUserOnConnection.nick] == NSOrderedSame) {
        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
        
        /* The user that left is ourselves, we need check if the item is still in our list or if it was deleted */
        if (channel != nil) {
            channel.isJoinedByUser = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller reloadClient:message.client];
            });
        }
    } else {
        [channel removeUserByName:[[message sender] nick]];
    }
    
    message.messageType = ET_PART;
    message.conversation = channel;
    [[message conversation] addMessageToConversation:message];
}

+ (void)userReceivedNickChange:(IRCMessage *)message
{
    if ([[[message sender] nick] caseInsensitiveCompare:message.client.currentUserOnConnection.nick] == NSOrderedSame) {
        message.client.currentUserOnConnection.nick     = message.message;
        message.client.currentUserOnConnection.username = message.sender.username;
        message.client.currentUserOnConnection.hostname = message.sender.hostname;
    }
    
    message.messageType = ET_NICK;
    
    for (IRCChannel *channel in [message.client channels]) {
        IRCUser *userOnChannel = [IRCUser fromNickname:message.sender.nick onChannel:channel];
        if (userOnChannel) {
            IRCMessage *nickMessage = [message copy];
            nickMessage.conversation = channel;
            
            userOnChannel.nick = message.message;
            [channel removeUserByName:[userOnChannel nick]];
            [channel.users addObject:userOnChannel];
            [channel sortUserlist];
            
            [nickMessage.conversation addMessageToConversation:nickMessage];
        }
    }
    
    for (IRCConversation *conversation in [message.client queries]) {
        if ([[conversation name] caseInsensitiveCompare:[message.sender nick]] == NSOrderedSame) {
            IRCConversation *conversationWithChanges = conversation;
            conversationWithChanges.name = message.message;
            IRCMessage *nickMessage = [message copy];
            nickMessage.conversation = conversation;
            
            [[message.client queries] removeObject:conversation];
            [[message.client queries] addObject:conversationWithChanges];
            
            [nickMessage.conversation addMessageToConversation:nickMessage];
        }
    }
    
}

+ (void)userReceivedKickMessage:(IRCMessage *)message
{
    NSMutableArray *messageComponents = [[[message message] componentsSeparatedByString:@" "] mutableCopy];
    NSString *kickedUserNickname = [messageComponents objectAtIndex:0];
    [messageComponents removeObjectAtIndex:0];
    
    NSString *kickMessage = [messageComponents componentsJoinedByString:@" "];
    if ([kickMessage hasPrefix:@":"]) {
        kickMessage = [kickMessage substringFromIndex:1];
    }
    
    IRCUser *kickedUser = [IRCUser fromNickname:kickedUserNickname onChannel:(IRCChannel *)message.conversation];
    IRCChannel *channel = (IRCChannel *)message.conversation;
    
    if ([[kickedUser nick] caseInsensitiveCompare:message.client.currentUserOnConnection.nick] == NSOrderedSame) {
        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
        
        /* The user that left is ourselves, we need check if the item is still in our list or if it was deleted */
        if (channel != nil) {
            channel.isJoinedByUser = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller reloadClient:message.client];
            });
        }
    } else {
        [[channel users] removeObject:channel];
    }
    
    IRCKickMessage *kick = [[IRCKickMessage alloc] initWithMessage:kickMessage
                                                    inConversation:channel
                                                        kickedUser:kickedUser
                                                          bySender:message.sender
                                                            atTime:message.timestamp
                                                          withTags:message.tags
                                                   isServerMessage:NO
                                                          onClient:message.client];
    
    [channel addMessageToConversation:kick];
}

+ (void)userReceivedQuitMessage:(IRCMessage *)message
{
    
    for (IRCChannel *channel in [message.client channels]) {
        IRCUser *userOnChannel = [IRCUser fromNickname:message.sender.nick onChannel:channel];
        if (userOnChannel) {
            [channel removeUserByName:[userOnChannel nick]];
            
            /* Create an IRCMessage object and add it to the chat buffer. */
            IRCMessage *quitMessage = [message copy];
            quitMessage.conversation = channel;
            
            [channel addMessageToConversation:quitMessage];
        }
    }
    
    for (IRCConversation *conversation in [message.client queries]) {
        if ([[conversation name] caseInsensitiveCompare:message.sender.nick] == NSOrderedSame) {
            conversation.conversationPartnerIsOnline = NO;
            IRCMessage *quitMessage = [message copy];
            quitMessage.conversation = conversation;
            
            [conversation addMessageToConversation:quitMessage];
        }
    }
}

+ (void)userReceivedModesOnChannel:(IRCMessage *)message
{
    if ([[message conversation] isKindOfClass:[IRCChannel class]]) {
        NSArray *modeComponents = [message.message componentsSeparatedByString:@" "];
        BOOL isGrantedMode = NO;
        int componentIndex = 1;
        
        IRCChannel *channel = (IRCChannel *)message.conversation;
        
        const char* modes = [[modeComponents objectAtIndex:0] UTF8String];
        
        while (*modes != ' ' && *modes != '\0') {
            switch (*modes) {
                case '+':
                    isGrantedMode = YES;
                    break;
                    
                case '-':
                    isGrantedMode = NO;
                    break;
                    
                case 'q': case 'a': case 'o': case 'h': case 'v':
                    if ([modeComponents count] >= componentIndex - 1) {
                        NSString *nickname = [modeComponents objectAtIndex:componentIndex];
                        
                        IRCUser *user = [IRCUser fromNickname:nickname onChannel:channel];
                        if (user != nil) {
                            [user setPrivilegeMode:modes granted:isGrantedMode];
                        }
                    }
                    componentIndex++;
                    break;
                    
                case 'b':
                    break;
                    
                case 'k':
                    if (isGrantedMode) {
                        if ([message.conversation.configuration.passwordReference length] == 0) {
                            message.conversation.configuration.passwordReference = [[NSUUID UUID] UUIDString];
                        }
                        
                        [SSKeychain setPassword:[modeComponents objectAtIndex:componentIndex] forService:@"conversation" account:message.conversation.configuration.passwordReference];
                    } else {
                        if ([message.conversation.configuration.passwordReference length] > 0) {
                            [SSKeychain deletePasswordForService:@"conversation" account:message.conversation.configuration.passwordReference];
                            message.conversation.configuration.passwordReference = @"";
                        }
                    }
                    
                    componentIndex++;
                    
                default:
                    if (isGrantedMode) {
                        [channel.channelModes addObject:[NSString stringWithFormat:@"%c", *modes]];
                    } else {
                        [channel.channelModes removeObject:[NSString stringWithFormat:@"%c", *modes]];
                    }
                    break;
            }
            modes++;
        }
        
        message.conversation = channel;
        message.messageType = ET_MODE;
        [message.conversation addMessageToConversation:message];
    }
}

+ (void)userReceivedChannelTopic:(IRCMessage *)message
{
    IRCChannel *channel = (IRCChannel *)[message conversation];
    channel.topic = message.message;
    message.conversation = channel;
    
    [message.conversation addMessageToConversation:message];
}

+ (void)clientReceivedISONResponse:(IRCMessage *)message
{
    NSArray *users = [message.message componentsSeparatedByString:@" "];
    
    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    
    int indexOfItem = 0;
    for (IRCConversation *conversation in message.client.queries) {
        if ([users containsObject:conversation.name]) {
            conversation.conversationPartnerIsOnline = YES;
            
            /* Set the conversation item in "enabled" mode. */
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller reloadClient:message.client];
            });
        } else {
            conversation.conversationPartnerIsOnline = NO;
            
            /* Set the conversation item in "disabled" mode */
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller reloadClient:message.client];
            });
        }
        indexOfItem++;
    }
    
    if ([message.client.queries count] > 0) {
        [NSTimer scheduledTimerWithTimeInterval:30.0
                                         target:message.client
                                       selector:@selector(validateQueryStatusOnAllItems)
                                       userInfo:nil
                                        repeats:NO];
    }
    
}

+ (void)clientReceivedWHOReply:(NSString *)line onClient:(IRCClient *)client
{
    NSMutableArray *messageComponents = [[line componentsSeparatedByString:@" "] mutableCopy];
    NSString *channel   = [messageComponents objectAtIndex:0];
    NSString *username  = [messageComponents objectAtIndex:1];
    NSString *hostname  = [messageComponents objectAtIndex:2];
    NSString *nickname  = [messageComponents objectAtIndex:4];
    NSString *modes     = [messageComponents objectAtIndex:5];
    
    [messageComponents removeObjectsInRange:NSMakeRange(0, 6)];
    NSString *realname  = [messageComponents componentsJoinedByString:@" "];
    
    IRCChannel *ircChannel = [IRCChannel fromString:channel withClient:client];
    IRCUser *user = [IRCUser fromNickname:nickname onChannel:ircChannel];
    if (user == nil) {
        user = [[IRCUser alloc] initWithNickname:nickname andUsername:username andHostname:hostname andRealname:realname onClient:client];
    }
    
    if (IRCv3CapabilityEnabled(client, @"away-notify")) {
        user.isAway = ([modes hasPrefix:@"G"]);
    }
    
    modes = [modes substringFromIndex:1];
    
    if ([modes hasPrefix:@"*"]) {
        user.ircop = YES;
        modes = [modes substringFromIndex:1];
    }
    
    for (NSUInteger i = 0; i < [modes length]; i++) {
        NSString *mode = [modes substringWithRange:NSMakeRange(i, 1)];
        
        #define matchesUserMode(x) ([mode isEqualToString:[[client userModeCharacters] objectForKey:(x)]])
        
        if (matchesUserMode(@"y")) {
            user.ircop = YES;
        } else if (matchesUserMode(@"q")) {
            user.owner = YES;
        } else if (matchesUserMode(@"a")) {
            user.admin = YES;
        } else if (matchesUserMode(@"o")) {
            user.op = YES;
        } else if (matchesUserMode(@"h")) {
            user.halfop = YES;
        } else if (matchesUserMode(@"v")) {
            user.voice = YES;
        }
    }
    
    [ircChannel removeUserByName:nickname];
    [[ircChannel users] addObject:user];
    [ircChannel sortUserlist];
}

+ (void)clientReceivedServerPasswordMismatchError:(IRCClient *)client
{
    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    dispatch_async(dispatch_get_main_queue(), ^{
        [controller displayPasswordEntryDialog:client];
    });
}

+ (void)clientReceivedModesForChannel:(IRCMessage *)message
{
    
}

+ (void)clientReceivedAwayNotification:(IRCMessage *)message
{
    BOOL userIsAway = ([[message message] length] > 0);
    
    message.messageType = ET_AWAY;
    
    for (IRCChannel *channel in [message.client channels]) {
        IRCUser *userOnChannel = [IRCUser fromNickname:message.sender.nick onChannel:channel];
        if (userOnChannel) {
            userOnChannel.isAway = userIsAway;
            [channel removeUserByName:[userOnChannel nick]];
            [channel.users addObject:userOnChannel];
            [channel sortUserlist];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:message];
            });
        }
    }
}

+ (void)userReceivedInviteToChannel:(IRCMessage *)message
{
    message.messageType = ET_INVITE;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:message];
    });
}

+ (void)clientReceivedRecoverableErrorFromServer:(IRCMessage *)message
{
    message.messageType = ET_ERROR;
    
    [message.conversation addMessageToConversation:message];
}

@end

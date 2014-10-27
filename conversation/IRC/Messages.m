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
#import "IRCQuitMessage.h"
#import "IRCKickMessage.h"
#import "ConversationListViewController.h"

@implementation Messages

+ (void)clientReceivedAuthenticationMessage:(const char*)message onClient:(IRCClient *)client
{
    if (client.isAwaitingAuthenticationResponse) {
        if (client.configuration.authenticationPasswordReference) {
            NSString *password = [SSKeychain passwordForService:@"conversation" account:client.configuration.authenticationPasswordReference];
            if (password != nil && [password length] > 0) {
                NSData *authenticationStringAsBinaryData = [[NSString stringWithFormat:@"%@\0%@\0%@",
                                                             client.configuration.primaryNickname,
                                                             client.configuration.usernameForRegistration,
                                                             password]
                                                            dataUsingEncoding:NSUTF8StringEncoding];
                
                [client.connection send:[NSString stringWithFormat:@"AUTHENTICATE %@", [authenticationStringAsBinaryData base64EncodedStringWithOptions:0]]];
                return;
            } else {
                NSLog(@"An authentication password reference was found but no password: %@", client.configuration.authenticationPasswordReference);
            }
        }
    }
    [client.connection send:@"CAP END"];
}

+ (void)clientReceivedAuthenticationAccepted:(const char*)message onClient:(IRCClient *)client
{
    [client.connection send:@"CAP END"];
}

+ (void)clientreceivedAuthenticationAborted:(const char *)message onClient:(IRCClient *)client
{
    client.isAwaitingAuthenticationResponse = NO;
}

+ (void)clientReceivedAuthenticationError:(const char*)message onClient:(IRCClient *)client
{
    [client.connection send:@"CAP END"];
}

+ (void)clientReceivedCAPMessage:(const char *)message onClient:(IRCClient *)client
{
    const char* messageBeforeIteration = message;
    int lengthOfCommand = 0;
    while (*message != ' ' && *message != '\0') {
        lengthOfCommand++;
        message++;
    }
    char* capCommand = malloc(lengthOfCommand + 1);
    strncpy(capCommand, messageBeforeIteration, lengthOfCommand);
    capCommand[lengthOfCommand + 1] = '\0';
    
    messageBeforeIteration = message;
    
    if (*message != '\0') {
        message++;
        messageBeforeIteration++;
        
        if (*message == ':') {
            message++;
            messageBeforeIteration++;
        }
    }
    
    NSString *capCommandString = [NSString stringWithCString:capCommand usingEncodingPreference:client.configuration];
    CapMessageType capIndexValue = [IRCMessageIndex capIndexValueFromString:capCommandString];
    switch (capIndexValue) {
        case CAP_LS:
            [Messages clientReceivedListOfServerIRCv3Capabilities:message onClient:client];
            break;
            
        case CAP_ACK:
            [Messages clientReceivedAcknowledgedCapabilities:message onClient:client];
            break;
            
        case CAP_NAK:
            [client.connection send:@"CAP END"];
            break;
            
        case CAP_CLEAR:
            client.ircv3CapabilitiesSupportedByServer = [[NSMutableArray alloc] init];
            break;
            
        default:
            break;
    }
    free(capCommand);
}

+ (void)clientReceivedListOfServerIRCv3Capabilities:(const char *)capabilities onClient:(IRCClient *)client
{
    NSString *capabilitiesString = [NSString stringWithCString:capabilities usingEncodingPreference:client.configuration];
    NSArray *capabilitiesList = [capabilitiesString componentsSeparatedByString:@" "];
    
    NSArray *applicationCapabilities = ((AppDelegate *)[UIApplication sharedApplication].delegate).IRCv3CapabilitiesSupportedByApplication;
    
    NSMutableArray *capabilitiesToNegotiate = [[NSMutableArray alloc] init];
    for (NSString *capability in capabilitiesList) {
        if ([applicationCapabilities indexOfObject:capability] != NSNotFound) {
            [capabilitiesToNegotiate addObject:capability];
        }
    }
    if ([capabilitiesToNegotiate count] > 0) {
        NSString *negotiateCapabilitiesString = [capabilitiesToNegotiate componentsJoinedByString:@" "];
        [client.connection send:[NSString stringWithFormat:@"CAP REQ :%@", negotiateCapabilitiesString]];
    } else {
        [client.connection send:@"CAP END"];
    }
}

+ (void)clientReceivedAcknowledgedCapabilities:(const char*)capabilities onClient:(IRCClient *)client
{
    NSString *capabilitiesString = [NSString stringWithCString:capabilities usingEncodingPreference:client.configuration];
    NSArray *capabilitiesList = [capabilitiesString componentsSeparatedByString:@" "];
    client.ircv3CapabilitiesSupportedByServer = [capabilitiesList mutableCopy];
    if ([client.ircv3CapabilitiesSupportedByServer indexOfObject:@"sasl"] != NSNotFound) {
        NSString *password = [SSKeychain passwordForService:@"conversation" account:client.configuration.authenticationPasswordReference];
        if (password != nil && [password length] > 0) {
            client.isAwaitingAuthenticationResponse = YES;
            [client.connection send:@"AUTHENTICATE PLAIN"];
            return;
        }
    }
    [client.connection send:@"CAP END"];
}

+ (void)userReceivedMessage:(const char *)message onRecepient:(char *)recepient byUser:(const char *[4])senderDict onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags
{
    /* Check if the message begins and ends with a 0x01 character, denoting this is a CTCP request. */
    if (*message == '\001' && message[strlen(message) -1] == '\001') {
        [self userReceivedCTCPMessage:message onRecepient:recepient byUser:senderDict onClient:client withTags:tags];
        return;
    }
    
    NSString *recipientString = [NSString stringWithCString:recepient usingEncodingPreference:[client configuration]];
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    /* Check if this message is a channel message or a private message */
    if ([recipientString isValidChannelName:client]) {
        /* Get the channel object associated with this channel */
        IRCChannel *channel = [IRCChannel getChannelOrCreate:recipientString onClient:client];
        
        IRCUser *sender = [IRCUser fromNickname:senderDict[0] onChannel:channel];
        if (sender == nil) {
            sender = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
        }
        NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:ET_PRIVMSG
                                                   inConversation:channel
                                                         bySender:sender
                                                           atTime:now];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:message];
        
    } else {
        IRCUser *sender = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
        IRCConversation *conversation = [IRCConversation getConversationOrCreate:sender.nick onClient:client];
        
        NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:ET_PRIVMSG
                                                   inConversation:conversation
                                                         bySender:sender
                                                           atTime:now];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:message];
    }
}

+ (void)userReceivedCTCPMessage:(const char *)message onRecepient:(char *)recepient byUser:(const char *[4])senderDict onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags
{
    
    /* Consume the begining CTCP character (0x01) */
    message++;
    
    /* Make a copy of the string */
    char* messageCopy = malloc(strlen(message)+1);
    strcpy(messageCopy, message);
    
    /* Iterate to the first space or the end of the message to get the "CTCP command" received. */
    int commandLength = 1;
    while (*message != ' ' && *message != '\0' && *message != '\001') {
        commandLength++;
        message++;
    }
    
    /* Get past the next space (if there is one) */
    message++;
    
    if (commandLength > 0) {
        /* Get the CTCP command by copying the range we calculated earlier */
        char* ctcpCommand = malloc(commandLength);
        strlcpy(ctcpCommand, messageCopy, commandLength);
        ctcpCommand[commandLength +1] = '\0';
        
        if (strcmp(ctcpCommand, "ACTION") == 0) {
            /* This is a CTCP ACTION, also known as an action message or a /me. We will send this to it's own handler.  */
            [self userReceivedACTIONMessage:message onRecepient:recepient byUser:senderDict onClient:client withTags:tags];
            free(ctcpCommand);
            free(messageCopy);
            return;
        } else if (strcmp(ctcpCommand, "VERSION") == 0) {
            
        }
        free(ctcpCommand);
    }
    NSString *messageString = [NSString stringWithCString:messageCopy usingEncodingPreference:client.configuration];
    NSString *recipientString = [NSString stringWithCString:recepient usingEncodingPreference:client.configuration];
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    if ([recipientString isValidChannelName:client]) {
        IRCChannel *channel = [IRCChannel getChannelOrCreate:recipientString onClient:client];
        
        IRCUser *sender = [IRCUser fromNickname:senderDict[0] onChannel:channel];
        if (sender == nil) {
            sender = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
        }
        
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:ET_CTCP
                                                   inConversation:channel
                                                         bySender:sender
                                                           atTime:now];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:message];
    } else {
        IRCUser *sender = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
        IRCConversation *conversation = [IRCConversation getConversationOrCreate:sender.nick onClient:client];
        
        NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:ET_CTCP
                                                   inConversation:conversation
                                                         bySender:sender
                                                           atTime:now];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:message];
    }
    free(messageCopy);
}

+ (void)userReceivedACTIONMessage:(const char *)message onRecepient:(char *)recepient byUser:(const char *[3])senderDict onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags
{
    NSString *recipientString = [NSString stringWithCString:recepient usingEncodingPreference:[client configuration]];
    IRCUser *sender = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
    
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    /* TODO: handle timestamps */
    
    /* Check if this message is a channel message or a private message */
    if ([recipientString isValidChannelName:client]) {
        /* Get the channel object associated with this channel */
        IRCChannel *channel = [IRCChannel getChannelOrCreate:recipientString onClient:client];
        
        NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:ET_ACTION
                                                   inConversation:channel
                                                         bySender:sender
                                                           atTime:now];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:message];
        
    } else {
        IRCConversation *conversation = [IRCConversation getConversationOrCreate:recipientString onClient:client];
        
        NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:ET_ACTION
                                                   inConversation:conversation
                                                         bySender:sender
                                                           atTime:now];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:message];
    }
}

+ (void)userReceivedJOIN:(const char *[3])senderDict onChannel:(const char *)rchannel onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags
{
    /* Get the user that performed the JOIN */
    IRCUser *user = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
    NSString *channelName = [NSString stringWithCString:rchannel usingEncodingPreference:client.configuration];
    IRCChannel *channel =  [IRCChannel fromString:channelName withClient:client];
    if ([[user nick] isEqualToString:client.currentUserOnConnection.nick]) {
        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
        [client.connection send:[NSString stringWithFormat:@"WHO %@", channelName]];
        channel.isJoinedByUser = YES;
        [controller reloadClient:client];
    }
    
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    IRCMessage *message = [[IRCMessage alloc] initWithMessage:nil
                                                       OfType:ET_JOIN
                                               inConversation:channel
                                                     bySender:user
                                                       atTime:now];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:message];
    
    [[channel users] addObject:user];
}

+ (void)userReceivedPART:(const char *[3])senderDict onChannel:(char *)rchannel onClient:(IRCClient *)client withMessage:(const char *)message withTags:(NSMutableDictionary *)tags
{
    /* Get the user that performed the PART */
    IRCUser *user = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
    NSString *channelName = [NSString stringWithCString:rchannel usingEncodingPreference:client.configuration];
    IRCChannel *channel =  [IRCChannel fromString:channelName withClient:client];
    if ([[user nick] isEqualToString:client.currentUserOnConnection.nick]) {
        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
        
        /* The user that left is ourselves, we need check if the item is still in our list or if it was deleted */
        if (channel != nil) {
            channel.isJoinedByUser = NO;
            [controller reloadClient:client];
        }
    } else {
        [[channel users] removeObject:channel];
    }
    
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    NSString *partMessage = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
    
    IRCMessage *messageObject = [[IRCMessage alloc] initWithMessage:partMessage
                                                       OfType:ET_PART
                                               inConversation:channel
                                                     bySender:user
                                                       atTime:now];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:messageObject];
}

+ (void)userReceivedNickchange:(const char *[3])senderDict toNick:(const char *)newNick onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags
{
    IRCUser *user = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
    if ([[user nick] isEqualToString:client.currentUserOnConnection.nick]) {
        client.currentUserOnConnection.nick     =   [NSString stringWithCString:newNick usingEncodingPreference:client.configuration];
        client.currentUserOnConnection.username =   [NSString stringWithCString:senderDict[1] usingEncodingPreference:client.configuration];
        client.currentUserOnConnection.hostname =   [NSString stringWithCString:senderDict[2] usingEncodingPreference:client.configuration];
    }
    for (IRCChannel *channel in [client getChannels]) {
        IRCUser *userOnChannel = [IRCUser fromNickname:senderDict[0] onChannel:channel];
        if (userOnChannel) {
            userOnChannel.nick = [NSString stringWithCString:newNick usingEncodingPreference:client.configuration];
            [channel removeUserByName:[userOnChannel nick]];
             [channel.users addObject:userOnChannel];
        }
    }
}

+ (void)userReceivedKICK:(const char *[3])senderDict onChannel:(char *)rchannel onClient:(IRCClient *)client withMessage:(const char *)message withTags:(NSMutableDictionary *)tags
{
    const char *pointerBeforeIteration = message;
    int lengthOfKickedUser = 0;
    while (*message != ' ' && *message != '\0') {
        lengthOfKickedUser++;
        message++;
    }
    char* kickedUserChar = malloc(lengthOfKickedUser + 1);
    strncpy(kickedUserChar, pointerBeforeIteration, lengthOfKickedUser);
    kickedUserChar[lengthOfKickedUser] = '\0';
    
    message++;
    
    if (*message == ':') {
        message++;
    }
    
    /* Get the user that performed the KICK  */
    NSString *channelName = [NSString stringWithCString:rchannel usingEncodingPreference:client.configuration];
    IRCChannel *channel =  [IRCChannel fromString:channelName withClient:client];
    IRCUser *user = [IRCUser fromNickname:senderDict[0] onChannel:channel];
    
    IRCUser *kickedUser = [IRCUser fromNickname:kickedUserChar onChannel:channel];
    
    if ([[kickedUser nick] isEqualToString:client.currentUserOnConnection.nick]) {
        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
        
        /* The user that left is ourselves, we need check if the item is still in our list or if it was deleted */
        if (channel != nil) {
            channel.isJoinedByUser = NO;
            [controller reloadClient:client];
        }
    } else {
        [[channel users] removeObject:channel];
    }
    
    NSString *kickMessage = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    IRCKickMessage *messageObject = [[IRCKickMessage alloc] initWithMessage:kickMessage
                                                             inConversation:channel
                                                                 kickedUser:kickedUser
                                                                   bySender:user
                                                                     atTime:now];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:messageObject];
}

+ (void)userReceivedQUIT:(const char*[3])senderDict onClient:(IRCClient *)client withMessage:(const char *)message withTags:(NSMutableDictionary *)tags
{
    NSMutableArray *conversationsWithUser = [[NSMutableArray alloc] init];
    for (IRCChannel *channel in [client getChannels]) {
        IRCUser *userOnChannel = [IRCUser fromNickname:senderDict[0] onChannel:channel];
        if (userOnChannel) {
            [channel removeUserByName:[userOnChannel nick]];
            [conversationsWithUser addObject:channel];
        }
    }
    NSString *nickString = [NSString stringWithCString:senderDict[0] usingEncodingPreference:client.configuration];
    NSString *userString = [NSString stringWithCString:senderDict[1] usingEncodingPreference:client.configuration];
    NSString *hostString = [NSString stringWithCString:senderDict[2] usingEncodingPreference:client.configuration];
    
    for (IRCConversation *conversation in [client getQueries]) {
        if (conversation.name == nickString) {
            [conversationsWithUser addObject:conversation];
        }
    }
    
    NSString *quitMessage = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
    IRCUser *user = [[IRCUser alloc] initWithNickname:nickString andUsername:userString andHostname:hostString onClient:client];
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    IRCQuitMessage *messageObject = [[IRCQuitMessage alloc] initWithMessage:quitMessage inConversations:conversationsWithUser bySender:user atTime:now];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:messageObject];
}

+ (void)userReceivedTOPIC:(const char *)topic onChannel:(char *)rchannel byUser:(const char *[3])senderDict onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags
{
    NSString *topicString = [NSString stringWithCString:topic usingEncodingPreference:[client configuration]];
    NSString *channelString = [NSString stringWithCString:rchannel usingEncodingPreference:[client configuration]];
    
    IRCChannel *channel = (IRCChannel *) [IRCChannel fromString:channelString withClient:client];
    if (channel != nil) {
        channel.topic = topicString;
    }
    
    [channel setTopic:topicString];
}

+ (void)clientReceivedISONResponse:(const char *)message onClient:(IRCClient *)client;
{
    
    NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:[client configuration]];
    NSArray *users = [messageString componentsSeparatedByString:@" "];
    
    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    
    int indexOfItem = 0;
    for (IRCConversation *conversation in client.getQueries) {
    
        if ([users containsObject:conversation.name]) {
            conversation.conversationPartnerIsOnline = YES;
            
            /* Set the conversation item in "enabled" mode. */
            [controller reloadClient:client];
        } else {
            conversation.conversationPartnerIsOnline = NO;
            
            /* Set the conversation item in "disabled" mode */
            [controller reloadClient:client];
        }
        indexOfItem++;
    }
    
    if ([client.getQueries count] > 0) {
        [NSTimer scheduledTimerWithTimeInterval:30.0
                                         target:client
                                       selector:@selector(validateQueryStatusOnAllItems)
                                       userInfo:nil
                                        repeats:NO];
    }
    
}

+ (void)clientReceivedWHOReply:(const char *)line onClient:(IRCClient *)client
{
    const char* pointerBeforeIteration = line;
    int lengthOfChannel = 0;
    while (*line != ' ' && *line != '\0') {
        lengthOfChannel++;
        line++;
    }
    char* channel = malloc(lengthOfChannel + 1);
    strncpy(channel, pointerBeforeIteration, lengthOfChannel);
    
    line++;
    pointerBeforeIteration = line;
    
    int lengthOfUsername = 0;
    while (*line != ' ' && *line != '\0') {
        lengthOfUsername++;
        line++;
    }
    char* username = malloc(lengthOfUsername + 1);
    strncpy(username, pointerBeforeIteration, lengthOfUsername);
    
    line++;
    pointerBeforeIteration = line;
    
    int lengthOfHostname = 0;
    while (*line != ' ' && *line != '\0') {
        lengthOfHostname++;
        line++;
    }
    char* hostname = malloc(lengthOfHostname + 1);
    strncpy(hostname, pointerBeforeIteration, lengthOfHostname);
    
    line++;
    pointerBeforeIteration = line;
    
    while (*line != ' ' && *line != '\0') {
        line++;
        pointerBeforeIteration++;
    }
    
    line++;
    pointerBeforeIteration++;
    
    int lengthOfNickname = 0;
    while (*line != ' ' && *line != '\0') {
        lengthOfNickname++;
        line++;
    }
    char* nickname = malloc(lengthOfNickname + 1);
    strncpy(nickname, pointerBeforeIteration, lengthOfNickname);
    
    line = line + 2;
    
    NSString *channelString = [NSString stringWithCString:channel usingEncodingPreference:client.configuration];
    IRCChannel *ircChannel = [IRCChannel fromString:channelString withClient:client];
    
    IRCUser *user = [IRCUser fromNickname:nickname onChannel:ircChannel];
    NSString *nicknameString = [NSString stringWithCString:nickname usingEncodingPreference:client.configuration];
    if (user == nil) {
        NSString *usernameString = [NSString stringWithCString:username usingEncodingPreference:client.configuration];
        NSString *hostnameString = [NSString stringWithCString:hostname usingEncodingPreference:client.configuration];
        user = [[IRCUser alloc] initWithNickname:nicknameString andUsername:usernameString andHostname:hostnameString onClient:client];
    }
    
    if (*line == *[client ownerUserModeCharacter]) {
        user.channelPrivileges = OWNER;
    } else if (*line == *[client adminUserModeCharacter]) {
        user.channelPrivileges = ADMIN;
    } else if (*line == *[client operatorUserModeCharacter]) {
        user.channelPrivileges = OPERATOR;
    } else if (*line == *[client halfopUserModeCharacter]) {
        user.channelPrivileges = HALFOP;
    } else if (*line == *[client voiceUserModeCharacter]) {
        user.channelPrivileges = VOICE;
    } else {
        user.channelPrivileges = NORMAL;
    }
    
    [ircChannel removeUserByName:nicknameString];
    [[ircChannel users] addObject:user];
}

+ (void)clientReceivedServerPasswordMismatchError:(IRCClient *)client
{
    // TODO: Display password entry dialog.
}

@end

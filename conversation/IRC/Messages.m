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

@implementation Messages

+ (void)clientReceivedAuthenticationMessage:(const char*)message onClient:(IRCClient *)client
{
    /* This method is called when the client has received an authentication SASL request from the server under initial negotiation. */
    if (client.isAwaitingAuthenticationResponse) {
        if (client.configuration.authenticationPasswordReference) {
            /* Retrieve the appropriate password from keychain using our identifier from the user's preferences */
            NSString *password = [SSKeychain passwordForService:@"conversation" account:client.configuration.authenticationPasswordReference];
            if (password != nil && [password length] > 0) {
                /* Send authentication to the server. As of now we only support SASL PLAIN authentication. Which is username username password encoded
                 in base64 separated by an ASCII null termination character. */
                NSData *authenticationStringAsBinaryData = [[NSString stringWithFormat:@"%@\0%@\0%@",
                                                             client.configuration.usernameForRegistration,
                                                             client.configuration.usernameForRegistration,
                                                             password]
                                                            dataUsingEncoding:NSUTF8StringEncoding];
                
                [client.connection send:[NSString stringWithFormat:@"AUTHENTICATE %@", [authenticationStringAsBinaryData base64EncodedStringWithOptions:0]]];
                return;
            } else {
                /* We had a reference to an item in keychain but the keychain item didn't exist for some reason.
                 We will act like there is no password saved and abort authentication. */
                NSLog(@"An authentication password reference was found but no password: %@", client.configuration.authenticationPasswordReference);
            }
        }
    }
    /* Authentication was unsuccessful somewhere earlier in the method so we will abort authentication.*/
    [client.connection send:@"CAP END"];
}

+ (void)clientReceivedAuthenticationAccepted:(const char*)message onClient:(IRCClient *)client
{
    /* Our password has bene accepted by SASL and we can end the authentication process and continue registration */
    client.isAwaitingAuthenticationResponse = NO;
    [client.connection send:@"CAP END"];
}

+ (void)clientreceivedAuthenticationAborted:(const char *)message onClient:(IRCClient *)client
{
    /* Authentication was aborted either by the servers actions or ours. We will continue registration as normal. */
    client.isAwaitingAuthenticationResponse = NO;
}

+ (void)clientReceivedAuthenticationError:(const char*)message onClient:(IRCClient *)client
{
    /* SASL has rejected our authentication attempt, the username, password, or authentication method is wrong.
    We will stop attempting authentication at this point and just try again with nickserv if possible at a later stage. */
    [client.connection send:@"CAP END"];
}

+ (void)clientReceivedCAPMessage:(const char *)message onClient:(IRCClient *)client
{
    /* Client received An IRCv3 CAP message. We will parse the message and find out what command it is sending. */
    const char* messageBeforeIteration = message;
    int lengthOfCommand = 0;
    
    /* Iterate until the next space and copy it to our command string. */
    while (*message != ' ' && *message != '\0') {
        lengthOfCommand++;
        message++;
    }
    char* capCommand = malloc(lengthOfCommand + 1);
    strncpy(capCommand, messageBeforeIteration, lengthOfCommand);
    capCommand[lengthOfCommand] = '\0';
    
    messageBeforeIteration = message;
    
    /* The message may be a single word command, but in case it is not, let's continue parsing past the next space. */
    if (*message != '\0') {
        message++;
        messageBeforeIteration++;
        
        /* This next bit may be prefixed by an ':' let's consume it. */
        if (*message == ':') {
            message++;
            messageBeforeIteration++;
        }
    }
    
    /* Parse the command we retrived and call the appropriate method. */
    NSString *capCommandString = [NSString stringWithCString:capCommand usingEncodingPreference:client.configuration];
    CapMessageType capIndexValue = [IRCMessageIndex capIndexValueFromString:capCommandString];
    switch (capIndexValue) {
        case CAP_LS:
            /* The server has returned a list of capabilities. We will call the method to negotiate these with the server. */
            [Messages clientReceivedListOfServerIRCv3Capabilities:message onClient:client];
            break;
            
        case CAP_ACK:
            /* The server has accepted our requested list of capabilities. */
            [Messages clientReceivedAcknowledgedCapabilities:message onClient:client];
            break;
            
        case CAP_NAK:
            /* The server has rejected our requested list of capabilities. It is not worth wasting time trying to negotiate why so let's just
             end negotiating and connect in IRCv2 mode. */
            [client.connection send:@"CAP END"];
            break;
            
        case CAP_CLEAR:
            /* The server has asked us to clear our IRCv3 capabilities. Possibly in await for a new list of capabilities. */
            client.ircv3CapabilitiesSupportedByServer = [[NSMutableArray alloc] init];
            break;
            
        default:
            break;
    }
    free(capCommand);
}

+ (void)clientReceivedListOfServerIRCv3Capabilities:(const char *)capabilities onClient:(IRCClient *)client
{
    /* The server has sent us a list of capabilities, these capabilities are delimited by a space. We will seperate them into an array
     and parse them accordingly. */
    NSString *capabilitiesString = [NSString stringWithCString:capabilities usingEncodingPreference:client.configuration];
    NSArray *capabilitiesList = [capabilitiesString componentsSeparatedByString:@" "];
    
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

+ (void)clientReceivedAcknowledgedCapabilities:(const char*)capabilities onClient:(IRCClient *)client
{
    /* The server accepted our requested list of capabilities to enable. Let's add them to our list so other parts of 
     the application are aware of them being turned on. */
    NSString *capabilitiesString = [NSString stringWithCString:capabilities usingEncodingPreference:client.configuration];
    NSArray *capabilitiesList = [capabilitiesString componentsSeparatedByString:@" "];
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

+ (void)userReceivedMessage:(const char *)message onRecepient:(char *)recepient byUser:(const char *[4])senderDict onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags
{
    /* Check if the message begins and ends with a 0x01 character, denoting this is a CTCP request. */
    if (*message == '\001' && message[strlen(message) -1] == '\001') {
        [self userReceivedCTCPMessage:message onRecepient:recepient byUser:senderDict onClient:client withTags:tags];
        return;
    }
    
    NSString *recipientString = [NSString stringWithCString:recepient usingEncodingPreference:[client configuration]];
    
    /* Get the timestamp from the message or create one if it is not available. */
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    /* Set the time of the last message received by this client. This is useful for the ZNC playback feature. */
    client.configuration.lastMessageTime = (long) [now timeIntervalSince1970];
    
    /* Check if this message is a channel message or a private message */
    if ([recipientString isValidChannelName:client]) {
        /* Get the channel object associated with this channel */
        IRCChannel *channel = [IRCChannel getChannelOrCreate:recipientString onClient:client];
        
        IRCUser *sender = [IRCUser fromNickname:senderDict[0] onChannel:channel];
        if (sender == nil) {
            sender = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
        }
        
        /* This is a message by the ZNC buffextras module. We will send it off to be parsed and not show this message as a channel message */
        if ([[sender nick] isEqualToString:@"*buffextras"]) {
            [znc_buffextras messageWithBufferString:message onChannel:channel onClient:client withTags:tags];
            return;
        }
        
        /* Create an IRCMessage object and add it to the chat buffer. */
        NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:ET_PRIVMSG
                                                   inConversation:channel
                                                         bySender:sender
                                                           atTime:now];
        [channel addMessageToConversation:message];
        
    } else {
        IRCUser *sender = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
        IRCConversation *conversation;
        if ([recipientString caseInsensitiveCompare:client.currentUserOnConnection.nick] != NSOrderedSame) {
            conversation = [IRCConversation getConversationOrCreate:recipientString onClient:client];
        } else {
            conversation = [IRCConversation getConversationOrCreate:sender.nick onClient:client];
        }
        
        /* Create an IRCMessage object and add it to the chat buffer */
        NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:ET_PRIVMSG
                                                   inConversation:conversation
                                                         bySender:sender
                                                           atTime:now];
        
        [conversation addMessageToConversation:message];
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
    
    /* Get the timestamp from the message or create one if it is not available. */
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    /* Set the time of the last message received by this client. This is useful for the ZNC playback feature. */
    client.configuration.lastMessageTime = (long) [now timeIntervalSince1970];
    
    if ([recipientString isValidChannelName:client]) {
        IRCChannel *channel = [IRCChannel getChannelOrCreate:recipientString onClient:client];
        
        IRCUser *sender = [IRCUser fromNickname:senderDict[0] onChannel:channel];
        if (sender == nil) {
            sender = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
        }
        
        /* Create an IRCMessage object and add it to the chat buffer. */
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:ET_CTCP
                                                   inConversation:channel
                                                         bySender:sender
                                                           atTime:now];
        [channel addMessageToConversation:message];
    } else {
        IRCUser *sender = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
        IRCConversation *conversation = [IRCConversation getConversationOrCreate:sender.nick onClient:client];
        
        /* Create an IRCMessage object and add it to the chat buffer. */
        NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:ET_CTCP
                                                   inConversation:conversation
                                                         bySender:sender
                                                           atTime:now];
        
        [conversation addMessageToConversation:message];
    }
    free(messageCopy);
}

+ (void)userReceivedACTIONMessage:(const char *)message onRecepient:(char *)recepient byUser:(const char *[3])senderDict onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags
{
    NSString *recipientString = [NSString stringWithCString:recepient usingEncodingPreference:[client configuration]];
    IRCUser *sender = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
    
    /* Get the timestamp from the message or create one if it is not available. */
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    /* Set the time of the last message received by this client. This is useful for the ZNC playback feature. */
    client.configuration.lastMessageTime = (long) [now timeIntervalSince1970];
    
    /* Check if this message is a channel message or a private message */
    if ([recipientString isValidChannelName:client]) {
        /* Get the channel object associated with this channel */
        IRCChannel *channel = [IRCChannel getChannelOrCreate:recipientString onClient:client];
        
        /* Create an IRCMessage object and add it to the chat buffer. */
        NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:ET_ACTION
                                                   inConversation:channel
                                                         bySender:sender
                                                           atTime:now];
        [channel addMessageToConversation:message];
        
    } else {
        IRCConversation *conversation = [IRCConversation getConversationOrCreate:recipientString onClient:client];
        
        /* Create an IRCMessage object and add it to the chat buffer. */
        NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:ET_ACTION
                                                   inConversation:conversation
                                                         bySender:sender
                                                           atTime:now];
        [conversation addMessageToConversation:message];
    }
}

+ (void)userReceivedNOTICE:(const char *)message onRecepient:(char *)recepient byUser:(const char *[3])senderDict onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags isServerMessage:(BOOL)isServer;
{
    /* Check if the message begins and ends with a 0x01 character, denoting this is a CTCP reply. */
    if (*message == '\001' && message[strlen(message) -1] == '\001') {
        [self userReceivedCTCPReply:message onRecepient:recepient byUser:senderDict onClient:client withTags:tags];
        return;
    }
    
    NSString *recipientString = [NSString stringWithCString:recepient usingEncodingPreference:[client configuration]];
    
    /* Get the timestamp from the message or create one if it is not available. */
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    /* Set the time of the last message received by this client. This is useful for the ZNC playback feature. */
    client.configuration.lastMessageTime = (long) [now timeIntervalSince1970];
    
    int messageType = isServer ? ET_SERVERNOTICE : ET_NOTICE;
    
    /* Check if this message is a channel message or a private message */
    if ([recipientString isValidChannelName:client]) {
        /* Get the channel object associated with this channel */
        IRCChannel *channel = [IRCChannel getChannelOrCreate:recipientString onClient:client];
        
        IRCUser *sender = [IRCUser fromNickname:senderDict[0] onChannel:channel];
        if (sender == nil) {
            sender = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
        }
        
        /* Create an IRCMessage object and add it to the chat buffer. */
        NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:messageType
                                                   inConversation:channel
                                                         bySender:sender
                                                           atTime:now];
        [channel addMessageToConversation:message];
        
    } else {
        IRCUser *sender = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
        IRCConversation *conversation = nil;
        if (messageType != ET_SERVERNOTICE) {
            conversation = [IRCConversation getConversationOrCreate:sender.nick onClient:client];
        }
        
        /* Create an IRCMessage object and add it to the chat buffer. */
        NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:messageType
                                                   inConversation:conversation
                                                         bySender:sender
                                                           atTime:now];
        
        if (conversation != nil) {
            [conversation addMessageToConversation:message];
        } else {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReceived" object:message];
        }
    }
}
    
+ (void)userReceivedCTCPReply:(const char *)message onRecepient:(char *)recepient byUser:(const char *[3])senderDict onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags
{
    NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
    NSString *recipientString = [NSString stringWithCString:recepient usingEncodingPreference:client.configuration];
    
    /* Get the timestamp from the message or create one if it is not available. */
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    /* Set the time of the last message received by this client. This is useful for the ZNC playback feature. */
    client.configuration.lastMessageTime = (long) [now timeIntervalSince1970];
    
    if ([recipientString isValidChannelName:client]) {
        IRCChannel *channel = [IRCChannel getChannelOrCreate:recipientString onClient:client];
        
        IRCUser *sender = [IRCUser fromNickname:senderDict[0] onChannel:channel];
        if (sender == nil) {
            sender = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
        }
        
        /* Create an IRCMessage object and add it to the chat buffer. */
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:ET_CTCPREPLY
                                                   inConversation:channel
                                                         bySender:sender
                                                           atTime:now];
        [channel addMessageToConversation:message];
    } else {
        IRCUser *sender = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
        IRCConversation *conversation = [IRCConversation getConversationOrCreate:sender.nick onClient:client];
        
        /* Create an IRCMessage object and add it to the chat buffer. */
        NSString *messageString = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
        IRCMessage *message = [[IRCMessage alloc] initWithMessage:messageString
                                                           OfType:ET_CTCPREPLY
                                                   inConversation:conversation
                                                         bySender:sender
                                                           atTime:now];
        
        [conversation addMessageToConversation:message];
    }
}

+ (void)userReceivedJOIN:(const char *[3])senderDict onChannel:(const char *)rchannel onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags
{
    /* Get the user that performed the JOIN */
    IRCUser *user = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
    NSString *channelName = [NSString stringWithCString:rchannel usingEncodingPreference:client.configuration];
    IRCChannel *channel =  [IRCChannel fromString:channelName withClient:client];
    if ([[user nick] caseInsensitiveCompare:client.currentUserOnConnection.nick] == NSOrderedSame) {
        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
        [client.connection send:[NSString stringWithFormat:@"WHO %@", channelName]];
        [client.connection send:[NSString stringWithFormat:@"MODE %@", channelName]];
        channel.isJoinedByUser = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [controller reloadClient:client];
        });
    }
    
    /* Get the timestamp from the message or create one if it is not available. */
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    /* Set the time of the last message received by this client. This is useful for the ZNC playback feature. */
    client.configuration.lastMessageTime = (long) [now timeIntervalSince1970];
    
    /* Create an IRCMessage object and add it to the chat buffer. */
    IRCMessage *message = [[IRCMessage alloc] initWithMessage:nil
                                                       OfType:ET_JOIN
                                               inConversation:channel
                                                     bySender:user
                                                       atTime:now];
    [channel addMessageToConversation:message];
    
    [[channel users] addObject:user];
}

+ (void)userReceivedPART:(const char *[3])senderDict onChannel:(char *)rchannel onClient:(IRCClient *)client withMessage:(const char *)message withTags:(NSMutableDictionary *)tags
{
    /* Get the user that performed the PART */
    IRCUser *user = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
    NSString *channelName = [NSString stringWithCString:rchannel usingEncodingPreference:client.configuration];
    IRCChannel *channel =  [IRCChannel fromString:channelName withClient:client];
    if ([[user nick] caseInsensitiveCompare:client.currentUserOnConnection.nick] == NSOrderedSame) {
        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
        
        /* The user that left is ourselves, we need check if the item is still in our list or if it was deleted */
        if (channel != nil) {
            channel.isJoinedByUser = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller reloadClient:client];
            });
        }
    } else {
        [channel removeUserByName:[user nick]];
    }
    
    /* Get the timestamp from the message or create one if it is not available. */
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    /* Set the time of the last message received by this client. This is useful for the ZNC playback feature. */
    client.configuration.lastMessageTime = (long) [now timeIntervalSince1970];
    
    NSString *partMessage = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
    
    /* Create an IRCMessage object and add it to the chat buffer. */
    IRCMessage *messageObject = [[IRCMessage alloc] initWithMessage:partMessage
                                                       OfType:ET_PART
                                               inConversation:channel
                                                     bySender:user
                                                       atTime:now];
    [channel addMessageToConversation:messageObject];
}

+ (void)userReceivedNickchange:(const char *[3])senderDict toNick:(const char *)newNick onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags
{
    IRCUser *user = [[IRCUser alloc] initWithSenderDict:senderDict onClient:client];
    if ([[user nick] caseInsensitiveCompare:client.currentUserOnConnection.nick] == NSOrderedSame) {
        client.currentUserOnConnection.nick     =   [NSString stringWithCString:newNick usingEncodingPreference:client.configuration];
        client.currentUserOnConnection.username =   [NSString stringWithCString:senderDict[1] usingEncodingPreference:client.configuration];
        client.currentUserOnConnection.hostname =   [NSString stringWithCString:senderDict[2] usingEncodingPreference:client.configuration];
    }
    
    /* Get the timestamp from the message or create one if it is not available. */
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    /* Set the time of the last message received by this client. This is useful for the ZNC playback feature. */
    client.configuration.lastMessageTime = (long) [now timeIntervalSince1970];
    
    NSString *newNickString = [NSString stringWithCString:newNick usingEncodingPreference:client.configuration];
    
    for (IRCChannel *channel in [client getChannels]) {
        IRCUser *userOnChannel = [IRCUser fromNickname:senderDict[0] onChannel:channel];
        if (userOnChannel) {
            userOnChannel.nick = newNickString;
            [channel removeUserByName:[userOnChannel nick]];
            [channel.users addObject:userOnChannel];
            [channel sortUserlist];
            
            /* Create an IRCMessage object and add it to the chat buffer. */
            IRCMessage *messageObject = [[IRCMessage alloc] initWithMessage:newNickString
                                                                     OfType:ET_NICK
                                                             inConversation:channel
                                                                   bySender:user
                                                                     atTime:now];
            
            [channel addMessageToConversation:messageObject];
        }
    }
    
    for (IRCConversation *conversation in [client getQueries]) {
        if ([[conversation name] caseInsensitiveCompare:[user nick]] == NSOrderedSame) {
            IRCConversation *conversationWithChanges = conversation;
            conversationWithChanges.name = newNickString;
            
            [[client getQueries] removeObject:conversation];
            [[client getQueries] addObject:conversationWithChanges];
            
            /* Create an IRCMessage object and add it to the chat buffer. */
            IRCMessage *messageObject = [[IRCMessage alloc] initWithMessage:newNickString
                                                                     OfType:ET_NICK
                                                             inConversation:conversation
                                                                   bySender:user
                                                                     atTime:now];
            
            [conversation addMessageToConversation:messageObject];
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
    
    if ([[kickedUser nick] caseInsensitiveCompare:client.currentUserOnConnection.nick] == NSOrderedSame) {
        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
        
        /* The user that left is ourselves, we need check if the item is still in our list or if it was deleted */
        if (channel != nil) {
            channel.isJoinedByUser = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller reloadClient:client];
            });
        }
    } else {
        [[channel users] removeObject:channel];
    }
    
    NSString *kickMessage = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
    
    /* Get the timestamp from the message or create one if it is not available. */
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    /* Set the time of the last message received by this client. This is useful for the ZNC playback feature. */
    client.configuration.lastMessageTime = (long) [now timeIntervalSince1970];
    
    /* Create an IRCMessage object and add it to the chat buffer. */
    IRCKickMessage *messageObject = [[IRCKickMessage alloc] initWithMessage:kickMessage
                                                             inConversation:channel
                                                                 kickedUser:kickedUser
                                                                   bySender:user
                                                                     atTime:now];
    
    [channel addMessageToConversation:messageObject];
    free(kickedUserChar);
}

+ (void)userReceivedQUIT:(const char*[3])senderDict onClient:(IRCClient *)client withMessage:(const char *)message withTags:(NSMutableDictionary *)tags
{
    NSString *nickString = [NSString stringWithCString:senderDict[0] usingEncodingPreference:client.configuration];
    NSString *userString = [NSString stringWithCString:senderDict[1] usingEncodingPreference:client.configuration];
    NSString *hostString = [NSString stringWithCString:senderDict[2] usingEncodingPreference:client.configuration];
    NSString *quitMessage = [NSString stringWithCString:message usingEncodingPreference:client.configuration];
    IRCUser *user = [[IRCUser alloc] initWithNickname:nickString andUsername:userString andHostname:hostString onClient:client];
    
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    /* Set the time of the last message received by this client. This is useful for the ZNC playback feature. */
    client.configuration.lastMessageTime = (long) [now timeIntervalSince1970];
    
    for (IRCChannel *channel in [client getChannels]) {
        IRCUser *userOnChannel = [IRCUser fromNickname:senderDict[0] onChannel:channel];
        if (userOnChannel) {
            [channel removeUserByName:[userOnChannel nick]];
            
            /* Create an IRCMessage object and add it to the chat buffer. */
            IRCMessage *messageObject = [[IRCMessage alloc] initWithMessage:quitMessage
                                                                     OfType:ET_QUIT
                                                             inConversation:channel
                                                                   bySender:user
                                                                     atTime:now];
            
            [channel addMessageToConversation:messageObject];
        }
    }
    
    for (IRCConversation *conversation in [client getQueries]) {
        if ([[conversation name] caseInsensitiveCompare:nickString] == NSOrderedSame) {
            
            IRCConversation *conversationWithChanges = conversation;
            conversationWithChanges.conversationPartnerIsOnline = NO;
            [[client getQueries] removeObject:conversation];
            [[client getQueries] addObject:conversationWithChanges];
            
            /* Create an IRCMessage object and add it to the chat buffer. */
            IRCMessage *messageObject = [[IRCMessage alloc] initWithMessage:quitMessage
                                                                         OfType:ET_QUIT
                                                                 inConversation:conversation
                                                                       bySender:user
                                                                         atTime:now];
            
            [conversation addMessageToConversation:messageObject];
        }
    }
}

+ (void)userReceivedModesOnChannel:(const char*)modes inChannel:(char *)rchannel byUser:(const char *[3])senderDict onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags
{
    NSString *modeString = [NSString stringWithCString:modes usingEncodingPreference:client.configuration];
    NSArray *modeComponents = [modeString componentsSeparatedByString:@" "];
    int componentIndex = 1;
    BOOL isGrantedMode = NO;
    
    NSString *channelName = [NSString stringWithCString:rchannel usingEncodingPreference:client.configuration];
    
    if ([channelName isValidChannelName:client] == NO)
        return;
    
    IRCChannel *channel = [IRCChannel fromString:channelName withClient:client];
    
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
                    
                    IRCUser *user = [IRCUser fromNicknameString:nickname onChannel:channel];
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
                    if ([channel.configuration.passwordReference length] == 0) {
                        channel.configuration.passwordReference = [[NSUUID UUID] UUIDString];
                    }
                    
                    [SSKeychain setPassword:[modeComponents objectAtIndex:componentIndex] forService:@"conversation" account:channel.configuration.passwordReference];
                } else {
                    if ([channel.configuration.passwordReference length] > 0) {
                        [SSKeychain deletePasswordForService:@"conversation" account:channel.configuration.passwordReference];
                        channel.configuration.passwordReference = @"";
                    }
                }
                
                NSUInteger index = 0;
                for (NSDictionary *config in [[AppPreferences sharedPrefs] getConnectionConfigurations]) {
                    if ([config[@"uniqueIdentifier"] isEqualToString:client.configuration.uniqueIdentifier]) {
                        [[AppPreferences sharedPrefs] setConnectionConfiguration:client.configuration atIndex:index];
                    }
                    index++;
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
    IRCUser *user = [IRCUser fromNickname:senderDict[0] onChannel:channel];
    NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
    
    IRCMessage *messageObject = [[IRCMessage alloc] initWithMessage:modeString
                                                             OfType:ET_MODE
                                                     inConversation:channel
                                                           bySender:user
                                                             atTime:now];
    
    [channel addMessageToConversation:messageObject];
}

+ (void)userReceivedTOPIC:(const char *)topic onChannel:(char *)rchannel byUser:(const char *[3])senderDict onClient:(IRCClient *)client withTags:(NSMutableDictionary *)tags
{
    NSString *topicString = [NSString stringWithCString:topic usingEncodingPreference:[client configuration]];
    
    /* If there is no sender this is a topic message sent as the user joins the channel. We must process it differently */
    if (senderDict == nil) {
        NSMutableArray *topicComponents = [[topicString componentsSeparatedByString:@" "] mutableCopy];
        
        /* Get the channel name from the first "word" */
        NSString *channelString = topicComponents[0];
        [topicComponents removeObjectAtIndex:0];
        
        /* Get the topic message by removing the first "word" and consuming the colon in front of it. */
        topicString = [topicComponents componentsJoinedByString:@" "];
        topicString = [topicString substringFromIndex:1];
        
        /* Update the channel topic */
        IRCChannel *channel = (IRCChannel *) [IRCChannel fromString:channelString withClient:client];
        if (channel != nil) {
            channel.topic = topicString;
        }
    } else {
        /* A user has just set the topic, update the channel topic and send a topic message to the user interface. */
        NSString *channelString = [NSString stringWithCString:rchannel usingEncodingPreference:[client configuration]];
        IRCChannel *channel = (IRCChannel *) [IRCChannel fromString:channelString withClient:client];
        
        if (channel != nil) {
            channel.topic = topicString;
            
            IRCUser *user = [IRCUser fromNickname:senderDict[0] onChannel:channel];
            NSDate* now = [IRCClient getTimestampFromMessageTags:tags];
            
            IRCMessage *messageObject = [[IRCMessage alloc] initWithMessage:topicString
                                                                     OfType:ET_TOPIC
                                                             inConversation:channel
                                                                   bySender:user
                                                                     atTime:now];
            
            [channel addMessageToConversation:messageObject];
        }
    }
    
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
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller reloadClient:client];
            });
        } else {
            conversation.conversationPartnerIsOnline = NO;
            
            /* Set the conversation item in "disabled" mode */
            dispatch_async(dispatch_get_main_queue(), ^{
                [controller reloadClient:client];
            });
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
    channel[lengthOfChannel] = '\0';
    
    line++;
    pointerBeforeIteration = line;
    
    int lengthOfUsername = 0;
    while (*line != ' ' && *line != '\0') {
        lengthOfUsername++;
        line++;
    }
    char* username = malloc(lengthOfUsername + 1);
    strncpy(username, pointerBeforeIteration, lengthOfUsername);
    username[lengthOfUsername] = '\0';
    
    line++;
    pointerBeforeIteration = line;
    
    int lengthOfHostname = 0;
    while (*line != ' ' && *line != '\0') {
        lengthOfHostname++;
        line++;
    }
    char* hostname = malloc(lengthOfHostname + 1);
    strncpy(hostname, pointerBeforeIteration, lengthOfHostname);
    hostname[lengthOfHostname] = '\0';
    
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
    nickname[lengthOfNickname] = '\0';
    
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
    
    while (*line != ' ' & *line != '\0') {
        if (*line == *[client ircopUserModeCharacter]) {
            user.ircop = YES;
        } else if (*line == *[client ownerUserModeCharacter]) {
            user.owner = YES;
        } else if (*line == *[client adminUserModeCharacter]) {
            user.admin = YES;
        } else if (*line == *[client operatorUserModeCharacter]) {
            user.op = YES;
        } else if (*line == *[client halfopUserModeCharacter]) {
            user.halfop = YES;
        } else if (*line == *[client voiceUserModeCharacter]) {
            user.voice = YES;
        }
        line++;
    }
    
    [ircChannel removeUserByName:nicknameString];
    [[ircChannel users] addObject:user];
    [ircChannel sortUserlist];
    
    free(nickname);
    free(username);
    free(hostname);
    free(channel);
}

+ (void)clientReceivedServerPasswordMismatchError:(IRCClient *)client
{
    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    dispatch_async(dispatch_get_main_queue(), ^{
        [controller displayPasswordEntryDialog:client];
    });
}

+ (void)clientReceivedModesForChannel:(const char*)modes inChannel:(char *)rchannel onClient:(IRCClient *)client
{
    NSString *channelString = [NSString stringWithCString:rchannel usingEncodingPreference:client.configuration];
    
    if ([channelString isEqualToString:[client currentUserOnConnection].nick])
        return;
    
    IRCChannel *channel = [IRCChannel fromString:channelString withClient:client];
    
    channel.channelModes = [[NSMutableArray alloc] init];
    
    while (*modes != '\0' && *modes != ' ') {
        NSString *mode = [NSString stringWithFormat:@"%c", *modes];
        [channel.channelModes addObject:mode];
    }
}

@end

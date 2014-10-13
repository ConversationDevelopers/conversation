//
//  Messages.m
//  conversation
//
//  Created by Alex Sørlie Glomsaas on 13/10/2014.
//  Copyright (c) 2014 conversation. All rights reserved.
//

#import "Messages.h"
#import "IRCClient.h"

@implementation Messages

+ (void)userReceivedMessage:(const char *)message onRecepient:(char *)recepient byUser:(char **)senderDict onClient:(IRCClient *)client
{
    /* Check if the message begins and ends with a 0x01 character, denoting this is a CTCP request. */
    if (*message == '\001' && message[strlen(message) -1] == '\001') {
        [self userReceivedCTCPMessage:message onRecepient:recepient byUser:senderDict onClient:client];
        return;
    }
    
    NSString *recipientString = [NSString stringWithCString:recepient encoding:NSUTF8StringEncoding];
    
    /* Check if this message is a channel message or a private message */
    if ([recipientString isValidChannelName:client]) {
        /* Get the channel object associated with this channel */
        IRCChannel *channel = [IRCChannel fromString:recipientString WithClient:client];
        if (channel == nil) {
        }
    } else {
        
    }
}

+ (void)userReceivedCTCPMessage:(const char *)message onRecepient:(char *)recepient byUser:(char **)senderDict onClient:(IRCClient *)client
{
    
    /* Consume the begining CTCP character (0x01) */
    message++;
    
    /* Make a copy of the string */
    char* messageCopy = malloc(strlen(message));
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
            [self userReceivedACTIONMessage:message onRecepient:recepient byUser:senderDict onClient:client];
            free(ctcpCommand);
            free(messageCopy);
            return;
        } else if (strcmp(ctcpCommand, "VERSION") == 0) {
            /* This is a CTCP VERSION, we will respond to it automatically by sending our IRC client version information.
             The current way of doing this is a placeholder. */
            [client sendData:[NSString stringWithFormat:@"NOTICE %s :\001VERSION Conversation IRC Client (https://github.com/ConversationDevelopers/conversation)\001", senderDict[1]]];
        }
        free(ctcpCommand);
    }
    free(messageCopy);
}

+ (void)userReceivedACTIONMessage:(const char *)message onRecepient:(char *)recepient byUser:(char **)senderDict onClient:(IRCClient *)client
{
    
}

@end

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
#import "IRCClient.h"

@implementation Messages

+ (void)userReceivedMessage:(const char *)message onRecepient:(char *)recepient byUser:(char **)senderDict onClient:(IRCClient *)client
{
    /* Check if the message begins and ends with a 0x01 character, denoting this is a CTCP request. */
    if (*message == '\001' && message[strlen(message) -1] == '\001') {
        [self userReceivedCTCPMessage:message onRecepient:recepient byUser:senderDict onClient:client];
        return;
    }
    
    NSString *recipientString = [NSString stringWithCString:recepient usingEncodingPreference:[client configuration]];
    
    /* Check if this message is a channel message or a private message */
    if ([recipientString isValidChannelName:client]) {
        /* Get the channel object associated with this channel */
        IRCChannel *channel = (IRCChannel *) [IRCChannel fromString:recipientString withClient:client];
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

+ (void)userReceivedJOIN:(const char **)senderDict onChannel:(char *)rchannel onClient:(IRCClient *)client
{
    
}

+ (void)userReceivedTOPIC:(const char *)topic onChannel:(char *)rchannel byUser:(char **)senderDict onClient:(IRCClient *)client
{
    NSString *topicString = [NSString stringWithCString:topic usingEncodingPreference:[client configuration]];
    NSString *channelString = [NSString stringWithCString:rchannel usingEncodingPreference:[client configuration]];
    
    IRCChannel *channel = (IRCChannel *) [IRCChannel fromString:channelString withClient:client];
    if (channel == nil) {
        return;
    }
    
    [channel setTopic:topicString];
}

@end

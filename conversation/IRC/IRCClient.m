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

#import "IRCClient.h"
#import "IRCConnection.h"
#import "IRCUser.h"
#import "IRCChannel.h"
#import "IRCConversation.h"
#import "IRCCommands.h"
#import "ConversationListViewController.h"

#define CONNECTION_RETRY_INTERVAL       30
#define CONNECTION_RETRY_ATTEMPTS       10
#define CONNECTION_IRC_PING_INTERVAL    280
#define CONNECTION_IRC_PONG_INTERVAL    30
#define CONNECTION_TIMEOUT_INTERVAL     300

@interface IRCClient ()

@property (nonatomic, assign) BOOL connectionIsBeingClosed;
@property (nonatomic, retain) NSMutableArray *channels;
@property (nonatomic, retain) NSMutableArray *queries;
@property (nonatomic, assign) NSInteger alternativeNickNameAttempts;
@property (nonatomic, assign) int connectionRetries;

@end

@implementation IRCClient

- (instancetype)initWithConfiguration:(IRCConnectionConfiguration *)config
{
    if ((self = [super init])) {
        /* Set the configuration associated with this connection */
        if (config) {
            self.configuration = config;
        } else {
            NSAssert(NO, @"Invalid Configuration");
        }
        
        
        /* Setup the client to a state where it is ready for a future connection attempt */
        self.connection = [[IRCConnection alloc] initWithClient:self];
        self.isConnected =                      NO;
        self.isAttemptingRegistration =         NO;
        self.isAttemptingConnection =           NO;
        self.hasSuccessfullyAuthenticated =     NO;
        self.isAwaitingAuthenticationResponse = NO;
        self.isBNCConnection =                  NO;
        self.isProcessingTermination =          NO;
        
        self.ownerUserModeCharacter    = "~";
        self.adminUserModeCharacter    = "&";
        self.operatorUserModeCharacter = "@";
        self.halfopUserModeCharacter   = "%";
        self.voiceUserModeCharacter    = "+";
        
        self.alternativeNickNameAttempts = 0;
        self.channels = [[NSMutableArray alloc] init];
        self.queries = [[NSMutableArray alloc] init];
        self.featuresSupportedByServer = [[NSMutableDictionary alloc] init];
        self.ircv3CapabilitiesSupportedByServer = [[NSMutableArray alloc] init];
        
        return self;
    }
    return nil;
}

- (void)connect
{
    if (self.isConnected || self.isAttemptingConnection) {
        /* For some reason multiple connection attempts on the same instance has fired, we will ignore these */
        return;
    }
    self.isAttemptingConnection = YES;
    
    NSLog(@"Connecting to %@ on %ld", self.configuration.serverAddress, (long)self.configuration.connectionPort);
    
    [self.connection connectToHost:self.configuration.serverAddress onPort:self.configuration.connectionPort useSSL:self.configuration.connectUsingSecureLayer];
    
}

- (void)clientDidConnect
{
    self.isConnected = YES;
    self.connectionRetries = 0;
    self.isAttemptingConnection = NO;
    self.isAttemptingRegistration = YES;
    
    self.currentUserOnConnection = [[IRCUser alloc] initWithNickname:self.configuration.primaryNickname
                                                         andUsername:self.configuration.usernameForRegistration
                                                         andHostname:@""
                                                            onClient:self];
    
    /* Send initial registration */
    if (self.configuration.serverPasswordReference) {
        NSString *password = [SSKeychain passwordForService:@"conversation" account:self.configuration.serverPasswordReference];
        if (password != nil && [password length] > 0) {
            [self.connection send:[NSString stringWithFormat:@"PASS %@", password]];
        } else {
            NSLog(@"A server password reference was found but no password: %@", self.configuration.serverPasswordReference);
        }
    }
    
    [self.connection send:@"CAP LS"];
    
    
    [IRCCommands changeNicknameToNick:self.configuration.primaryNickname onClient:self];
    [self.connection send:[NSString stringWithFormat:@"USER %@ 0 * :%@",
                    self.configuration.usernameForRegistration,
                    self.configuration.realNameForRegistration]];
}

- (void)clientDidReceiveData:(const char *)line
{
    NSLog(@"<< %s", line);
    BOOL isServerMessage = NO;
    
    const char* lineBeforeIteration;
    char* sender;
    char* nickname;
    char* username;
    char* hostname;
    
    
    /* Make a copy of the full message string */
    lineBeforeIteration = line;
    
    /* This message starts with a message tag ( http://ircv3.atheme.org/specification/message-tags-3.2 ) */
    NSMutableDictionary *tagsList = [[NSMutableDictionary alloc] init];
    if (*line == '@') {
        line++;
        lineBeforeIteration++;
        
        int tagsLength;
        while (*line != ' ' && *line != '\0') {
            line++;
            tagsLength++;
        }
        
        char* tags = malloc(tagsLength + 1);
        strncpy(tags, lineBeforeIteration, tagsLength);
        tags[tagsLength] = '\0';
        
        NSString *tagsString = [NSString stringWithCString:tags usingEncodingPreference:self.configuration];
        NSArray *seperatedTags = [tagsString componentsSeparatedByString:@";"];
        
        for (NSString *tag in seperatedTags) {
            if ([tag containsString:@"="]) {
                NSArray *components = [tag componentsSeparatedByString:@"="];
                [tagsList setObject:components[1] forKey:components[0]];
            } else {
                [tagsList setObject:@"1" forKey:tag];
            }
        }
        
        line++;
        lineBeforeIteration = line;
    }
    
    if (*line == ':') {
        /* Consume the : at the start of the message. */
        line++;
        lineBeforeIteration++;
        
        long senderLength   = 0;
        long nicknameLength = 0;
        long usernameLength = 0;
        
        
        /* Pass over the string until we either reach a space, end of message, or an exclamation mark (Part of a user's hostmask) */
        while (*line != '\0' && *line != ' ' && *line != '!') {
            nicknameLength++;
            line++;
            senderLength++;
        }
        /* If there was not an ! in this message and we have reached a space already, the sender was the server, which does not have a hostmask. */
        if (*line != ' ') {
            /* Pass over the string until we reach a space, end of message, or an @ sign (Part of the user's hostmask) */
            while (*line != '\0' && *line != ' ' && *line != '@') {
                usernameLength++;
                line++;
                senderLength++;
            }
            /* Pass over the rest of the string leading to a space, to get the position of the host address. */
            while (*line != '\0' && *line != ' ') {
                senderLength++;
                line++;
            }
        } else {
            isServerMessage = YES;
        }
        
        /* Copy the characters of the entire sender */
        if (senderLength > 0) {
            sender = malloc(senderLength+1);
            strncpy(sender, lineBeforeIteration, senderLength);
            sender[senderLength] = '\0';
        } else {
            sender = NULL;
        }
        
        /* Copy the characters of the nickname range we calculated earlier, and consume the same characters from the string as well as the following '!' */
        nickname = malloc(nicknameLength+1);
        strncpy(nickname, lineBeforeIteration, nicknameLength);
        nickname[nicknameLength] = '\0';
        lineBeforeIteration = lineBeforeIteration + nicknameLength + 1;
        
        /* Copy the characters from the username range we calculated earlier, and consume the same characters from the string as well as the following '@' */
        if (usernameLength > 0) {
            username = malloc(usernameLength);
            strncpy(username, lineBeforeIteration, usernameLength -1);
            username[usernameLength] = '\0';
            lineBeforeIteration = lineBeforeIteration + usernameLength;
        } else {
            username = NULL;
        }
        
        /* Copy the characters from the hostname range we calculated earlier */
        long hostnameLength = (senderLength - usernameLength - nicknameLength);
        if (hostnameLength > 0) {
            hostname = malloc(hostnameLength+1);
            strncpy(hostname, lineBeforeIteration, hostnameLength);
            hostname[hostnameLength] = '\0';
        } else {
            hostname = NULL;
        }
        
        lineBeforeIteration = lineBeforeIteration + hostnameLength;
        
        /* Consume the following space leading to the IRC command */
        line++;
        
    } else {
        sender   = NULL;
        username = NULL;
        hostname = NULL;
        nickname = NULL;
        lineBeforeIteration = line;
    }
    const char *senderDict[] = {
        nickname,
        username,
        hostname
    };
    
        /* Pass over the string to the next space or end of the line to get the range of the IRC command */
    int commandLength = 0;
    while (*line != '\0' && *line != ' ') {
        commandLength++;
        line++;
    }
    
    /* Copy the characters from the IRC command range we calculated earlier */
    char* command = malloc(commandLength + 1);
    strncpy(command, lineBeforeIteration, commandLength);
    command[commandLength] = '\0';
    lineBeforeIteration = lineBeforeIteration + commandLength;
    
    /* Consume the following space leading to the recepient */
    line++;
    lineBeforeIteration++;
    
    /* The message may start with a colon. We will trim this before continuing */
    if (*line == ':') {
        line++;
        lineBeforeIteration++;
    }
    
    char* recipient;
    
    /* Pass over the string to the next space or end of the line to get the range of the recipient. */
    const char *lineBeforeRecipient;
    lineBeforeRecipient = line;
    
    int recipientLength = 0;
    while (*line != '\0' && *line != ' ') {
        recipientLength++;
        line++;
    }
    
    /* Copy the characters from the recipient range we calculated earlier */
    recipient = malloc(recipientLength + 1);
    strncpy(recipient, lineBeforeIteration, recipientLength);
    recipient[recipientLength] = '\0';
    
    if (*line != '\0') {
        /* Consume the following space leading to the message */
        line++;
        
        /* The message may start with a colon. We will trim this before continuing */
        if (*line == ':') {
            line++;
        }
    } else {
        /* If we have reached the end of the message we will move the pointer back to before the "recipient"
         so that it will still be useful to commands without a recipient */
        if (*line == '\0') {
            line = lineBeforeRecipient;
        }
    }
    
    NSString *commandString = [NSString stringWithCString:command usingEncodingPreference:[self configuration]];
    MessageType commandIndexValue = [IRCMessageIndex indexValueFromString:commandString];
    
    switch (commandIndexValue) {
        case PING:
            [self.connection send:[NSString stringWithFormat:@"PONG :%s", line]];
            break;
        case ERROR:
            
            break;
            
        case AUTHENTICATE:
            [Messages clientReceivedAuthenticationMessage:line onClient:self];
            break;
            
        case CAP:
            [Messages clientReceivedCAPMessage:line onClient:self];
            break;
            
        case PRIVMSG:
            if (nickname) {
                [Messages userReceivedMessage:line onRecepient:recipient byUser:senderDict onClient:self withTags:tagsList];
            }
            break;
            
        case NOTICE:
            
            break;
            
        case JOIN:
            [Messages userReceivedJOIN:senderDict onChannel:recipient onClient:self withTags:tagsList];
            break;
            
        case PART:
            [Messages userReceivedPART:senderDict onChannel:recipient onClient:self withMessage:line withTags:tagsList];
            break;
            
        case QUIT:
            [Messages userReceivedQUIT:senderDict onClient:self withMessage:line withTags:tagsList];
            break;
            
        case TOPIC:
            [Messages userReceivedTOPIC:line onChannel:recipient byUser:senderDict onClient:self withTags:tagsList];
            break;
            
        case KICK:
            [Messages userReceivedKICK:senderDict onChannel:recipient onClient:self withMessage:line withTags:tagsList];
            break;
            
        case MODE:
            
            break;
            
        case NICK:
            [Messages userReceivedNickchange:senderDict toNick:line onClient:self withTags:tagsList];
            break;
            
        case RPL_WELCOME:
            self.isAttemptingRegistration = NO;
            [self validateQueryStatusOnAllItems];
            [self.connection enableFloodControl];
            
            if (self.configuration.useServerAuthenticationService == NO) {
                [self autojoin];
            }
            break;
            
        case RPL_ISUPPORT:
            [self updateServerSupportedFeatures:line];
            break;
            
        case RPL_ISON: {
            [Messages clientReceivedISONResponse:line onClient:self];
            break;
        }
            
        case RPL_TOPIC:
            [Messages userReceivedTOPIC:line onChannel:recipient byUser:nil onClient:self withTags:tagsList];
            break;
            
        case RPL_WHOREPLY:
            [Messages clientReceivedWHOReply:line onClient:self];
            break;
        
        case ERR_ERRONEUSNICKNAME:
        case ERR_NICKNAMEINUSE:
            /* The server did not accept our nick request, let's see if this happened during initial registration. */
            if ([self isAttemptingRegistration]) {
                /* The nick error did happen during initial registration, we will check if we have already tried the secondary nickname */
                if ([self.currentUserOnConnection.nick isEqualToString:self.configuration.primaryNickname]) {
                    /* This is the first occurance of this error, so we will try registration again with the secondary nickname. */
                    [IRCCommands changeNicknameToNick:self.configuration.secondaryNickname onClient:self];
                    self.currentUserOnConnection.nick = self.configuration.secondaryNickname;
                } else {
                    /* The secondary nickname has already been attempted, so we will append an underscore to the nick until
                     we find one that the server accepts. If we cannot find a nick within 25 characters, we will abort. */
                    if ([self.currentUserOnConnection.nick length] < 25) {
                        NSString *newNickName = [NSString stringWithFormat:@"%@_", self.currentUserOnConnection.nick];
                        [IRCCommands changeNicknameToNick:newNickName onClient:self];
                        self.currentUserOnConnection.nick = newNickName;
                    } else {
                        NSLog(@"Registration failed. Disconnecting..");
                        [self disconnect];
                    }
                }
            }
            break;
            
        case RPL_SASLSUCCESS:
            [Messages clientReceivedAuthenticationAccepted:line onClient:self];
            break;
            
        case ERR_SASLABORTED:
            [Messages clientreceivedAuthenticationAborted:line onClient:self];
            break;
            
        case ERR_NICKLOCKED:
        case ERR_SASLFAIL:
        case ERR_SASLTOOLONG:
            [Messages clientReceivedAuthenticationError:line onClient:self];
            break;
            
        default:
            break;
    }
    free(command);
    free(sender);
    free(recipient);
    free(nickname);
    free(username);
}

- (void)updateServerSupportedFeatures:(const char*)data
{
    /* Create a mutable copy of the data */
    char* mline = malloc(strlen(data) + 1);
    strcpy(mline, data);
    
    /* Split the string by spaces and iterate over the result. This will give us key value pairs seperated by '=' or
     just simply keys which we will translate to booleans */
    const char delimeter[2] = " ";
    char *token;
    token = strtok(mline, delimeter);
    
    /* Iterate over the key-value pair */
    while(token != NULL) {
        /* This is the end of the key-value list, we will break here.  */
        if (*token == ':') {
            break;
        }
        
        /* Make a pointer to the key-value pair that we will use to retrieve the key. */
        char* tokenBeforeIteration = token;
        char* keySearchToken = token;
        
        /* Iterate over the string until we reach either the end, or a '=' */
        long keyLength = 0;
        while (*keySearchToken != '\0' && *keySearchToken != '=' && *keySearchToken != ' ') {
            keyLength++;
            keySearchToken++;
        }
        
        /* Set the key to the result of our previous iteration */
        char* key;
        if (keyLength > 0) {
            key = malloc(keyLength);
            strncpy(key, tokenBeforeIteration, keyLength);
            key[keyLength] = '\0';
            
            NSString *keyString = [NSString stringWithCString:key usingEncodingPreference:[self configuration]];
            
            /* If the next character is an '=', this is a key-value pair, and we will continue iterating to get the value.
             If not, we will interpret it as a positive boolean. */
            if (*keySearchToken == '=') {
                keySearchToken++;
                NSString *valueString = [NSString stringWithCString:keySearchToken usingEncodingPreference:[self configuration]];
                
                /* Save key value pair to dictionary */
                [self.featuresSupportedByServer setObject:valueString forKey:keyString];
            } else {
                /* Save boolean to dictionary */
                [self.featuresSupportedByServer setObject:@YES forKey:keyString];
            }
        } else {
            key = NULL;
        }
        free(key);
        token = strtok(NULL, delimeter);
    }
    [self setUsermodePrefixes];
    
    free(mline);
}

- (void)setUsermodePrefixes
{
    NSString *prefixString = [[self featuresSupportedByServer] objectForKey:@"PREFIX"];
    if (prefixString) {
        const char* prefixes = [prefixString UTF8String];
        prefixes++;
        const char* prefixIdentifier = prefixes;
        while (*prefixes != ')' && *prefixes != '\0') {
            prefixes++;
        }
        prefixes++;
        
        while (*prefixIdentifier != ')' && *prefixIdentifier != '\0') {
            char* character = malloc(2);
            strncpy(character, prefixes, 1);
            character[1] = '\0';
            
            NSLog(@"%c => %c", *prefixIdentifier, *character);
            switch (*prefixIdentifier) {
                case 'q': {
                    self.ownerUserModeCharacter = character;
                    break;
                }
                    
                case 'a': {
                    self.adminUserModeCharacter = character;
                    break;
                }
                
                case 'o': {
                    self.operatorUserModeCharacter = character;
                    break;
                }
                    
                case 'h': {
                    self.halfopUserModeCharacter = character;
                    break;
                }
                    
                case 'v': {
                    self.voiceUserModeCharacter = character;
                    break;
                }
            }
            prefixIdentifier++;
            prefixes++;
        }
    }
}

- (void)clientDidSendData
{
}

- (void)disconnect
{
    if (self.isConnected) {
        self.isProcessingTermination = YES;
        [self.connection send:[NSString stringWithFormat:@"QUIT :%@", self.configuration.disconnectMessage]];
        [self.connection close];
    }
}

- (void)clientDidDisconnect {
    NSLog(@"Disconnected");
    [self clearStatus];
}


- (void)clientDidDisconnectWithError:(NSString *)error
{
    NSLog(@"Disconnected: %@", error);
    [self clearStatus];
    if ([self.configuration automaticallyReconnect]) {
        if (self.connectionRetries == CONNECTION_RETRY_ATTEMPTS) {
            NSLog(@"Connection attempt failed %i times. Connection aborted.", self.connectionRetries);
        } else {
            NSLog(@"Retrying in 5 seconds..");
            [NSTimer scheduledTimerWithTimeInterval:5.0
                                             target:self
                                           selector:@selector(attemptClientReconnect)
                                           userInfo:nil
                                            repeats:NO];
        }
    }
}

- (void)attemptClientReconnect
{
    self.connectionRetries++;
    [self connect];
}


- (void)clearStatus
{
    self.isConnected =                      NO;
    self.isAttemptingRegistration =         NO;
    self.isAttemptingConnection =           NO;
    self.hasSuccessfullyAuthenticated =     NO;
    self.isAwaitingAuthenticationResponse = NO;
    self.isBNCConnection =                  NO;
    self.isProcessingTermination =          NO;
    self.alternativeNickNameAttempts = 0;
    self.featuresSupportedByServer = [[NSMutableDictionary alloc] init];
    self.ircv3CapabilitiesSupportedByServer = [[NSMutableArray alloc] init];
    [self.connection disableFloodControl];
    
    for (IRCChannel *channel in self.channels) {
        channel.isJoinedByUser = NO;
    }
    
    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    [controller reloadClient:self];
    
    [self validateQueryStatusOnAllItems];
}

- (BOOL)isConnectedAndCompleted
{
    if (self.isAttemptingRegistration ||  self.isAwaitingAuthenticationResponse || self.isProcessingTermination) return NO;
    
    return self.isConnected;
}

- (void)validateQueryStatusOnAllItems
{
    if ([self.queries count] == 0) return;
    
    if (self.isConnected == NO) {
        for (IRCConversation *query in self.queries) {
            query.conversationPartnerIsOnline = NO;
        }
        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
        [controller reloadClient:self];
        return;
    }
    
    NSString *requestString = @"";
    for (IRCConversation *query in self.queries) {
        requestString = [requestString stringByAppendingString:[NSString stringWithFormat:@"%@ ", query.name]];
    }
    [self.connection send:[NSString stringWithFormat:@"ISON :%@", requestString]];
}

+ (NSString *)getChannelPrefixCharacters:(IRCClient *)client
{
    /* Get the channel prefix characters allowed by the server */
    NSString *acceptedChannelPrefixesByServer = nil;
    if (client) {
        acceptedChannelPrefixesByServer = [[client featuresSupportedByServer] objectForKey:@"CHANTYPES"];
    }
    if (acceptedChannelPrefixesByServer == nil) {
        /* The server does not provide this information or we are not connected to one, so we will use
         the standard characters defined by the RFC http://tools.ietf.org/html/rfc1459#section-1.3  */
        acceptedChannelPrefixesByServer = @"#&+!";
    }
    return acceptedChannelPrefixesByServer;
}

- (NSMutableArray *)getChannels
{
    return self.channels;
}

- (NSMutableArray *)getQueries
{
    return self.queries;
}

- (NSMutableArray *)sortChannelItems
{
    NSCharacterSet *prefixes = [NSCharacterSet characterSetWithCharactersInString:[IRCClient getChannelPrefixCharacters:self]];
    
    NSArray *sortedArray;
    sortedArray = [self.channels sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *channel1 = [(IRCChannel *)a name];
        NSString *channel2 = [(IRCChannel *)b name];
        channel1 = [[channel1 componentsSeparatedByCharactersInSet:prefixes] componentsJoinedByString:@""];
        channel2 = [[channel2 componentsSeparatedByCharactersInSet:prefixes] componentsJoinedByString:@""];
        return [channel1 compare:channel2];
    }];
    self.channels = [sortedArray mutableCopy];
    return self.channels;
}

- (NSMutableArray *)sortQueryItems
{
    NSArray *sortedArray;
    sortedArray = [self.queries sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *query1 = [(IRCConversation *)a name];
        NSString *query2 = [(IRCConversation *)b name];
        return [query1 compare:query2];
    }];
    self.queries = [sortedArray mutableCopy];
    return self.queries;
}

- (BOOL)addChannel:(IRCChannel *)channel
{
    IRCChannel *channelExists = [IRCChannel fromString:channel.name withClient:self];
    
    if (channelExists != nil) {
        return NO;
    }
    [self.channels addObject:channel];
    
    if ([self isConnectedAndCompleted]) {
        [self.connection send:[NSString stringWithFormat:@"JOIN %@", [channel name]]];
    }
    
    return YES;
}

- (BOOL)removeChannel:(IRCChannel *)channel
{
    IRCChannel *channelExists = [IRCChannel fromString:channel.name withClient:self];
    if (channelExists != nil) {
        if ([channel isJoinedByUser]) {
            [self.connection send:[NSString stringWithFormat:@"PART %@ :%@", [channel name], [channel.client.configuration channelDepartMessage]]];
        }
        [self.channels removeObject:channelExists];
        return YES;
    }
    return NO;
}

- (BOOL)addQuery:(IRCConversation *)query
{
    NSUInteger i = [self.queries indexOfObjectPassingTest:^BOOL(id element,NSUInteger idx,BOOL *stop) {
        return [[element name] isEqualToString:query.name];
    }];
    if (i != NSNotFound) {
        return NO;
    }
    [self.queries addObject:query];
    
    if ([self isConnectedAndCompleted]) {
        [self validateQueryStatusOnAllItems];
    }
    
    return YES;
}

- (BOOL)removeQuery:(IRCConversation *)query
{
    NSUInteger indexOfObject = [self.queries indexOfObject:query];
    if (indexOfObject != NSNotFound) {
        [self.queries removeObjectAtIndex:indexOfObject];
        return YES;
    }
    return NO;
}

- (void)autojoin
{
    for (IRCChannel *channel in self.channels) {
        if (channel.configuration.autoJoin) {
            [self.connection send:[NSString stringWithFormat:@"JOIN %@", channel.name]];
        }
    }
}

+ (NSDate *)getTimestampFromMessageTags:(NSMutableDictionary *)tags
{
    NSString *timeObjectISO = [tags objectForKey:@"time"];
    if (timeObjectISO) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
        NSLocale *posix = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        [formatter setLocale:posix];
        return [formatter dateFromString:timeObjectISO];
    }
    
    NSString *timeObjectEpochTime = [tags objectForKey:@"t"];
    if (timeObjectEpochTime) {
        NSTimeInterval epochTimeAsDouble = [timeObjectEpochTime doubleValue];
        return [NSDate dateWithTimeIntervalSince1970:epochTimeAsDouble];
    }
    return [NSDate date];
}

@end

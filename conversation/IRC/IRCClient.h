/*
 Copyright (c) 2014-2015, Tobias Pollmann.
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

#import <Foundation/Foundation.h>
#import "IRCConnectionConfiguration.h"
#import "IRCMessageIndex.h"
#import "Messages.h"
#import "NSString+Methods.h"
#import "SSKeychain.h"

#define IRC_CTCP        '\001'
#define IRC_BOLD        '\002'
#define IRC_COLOUR      '\003'
#define IRC_ITALICS     '\029'
#define IRC_UNDERLINE   '\031'

#define IRCv3CapabilityEnabled(x, y) [[x ircv3CapabilitiesSupportedByServer] indexOfObject:(y)] != NSNotFound

@class IRCConnection;
@class IRCChannel;
@class IRCUser;
@class IRCConversation;
@class ConversationListViewController;
@class ConsoleViewController;
@class IRCMessage;

@interface IRCClient : NSObject

@property (nonatomic, strong) IRCConnectionConfiguration *configuration;
@property (nonatomic, strong) IRCConnection *connection;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) BOOL isAttemptingConnection;
@property (nonatomic, assign) BOOL willReconnect;
@property (nonatomic, assign) BOOL hasSuccessfullyAuthenticated;
@property (nonatomic, assign) BOOL isAwaitingAuthenticationResponse;
@property (nonatomic, assign) BOOL isAttemptingRegistration;
@property (nonatomic, assign) BOOL isBNCConnection;
@property (nonatomic, assign) BOOL isProcessingTermination;
@property (nonatomic, assign) BOOL showConsole;
@property (nonatomic, strong) IRCUser *currentUserOnConnection;

@property (nonatomic) ConsoleViewController *console;

@property (nonatomic, strong) NSMutableDictionary *featuresSupportedByServer;
@property (nonatomic, strong) NSMutableArray *ircv3CapabilitiesSupportedByServer;
@property (nonatomic, strong) NSMutableDictionary *userModeCharacters;
@property (nonatomic, retain) NSMutableArray *channels;
@property (nonatomic, retain) NSMutableArray *queries;
@property (nonatomic, strong) NSMutableDictionary *whoisRequests;
@property (nonatomic, assign) SecTrustRef certificate;

+ (NSArray *) IRCv3CapabilitiesSupportedByApplication;

/*!
 *    @brief  Create an IRCClient based on a client configuration.
 *
 *    @param config A client configuration with the details to use for creating and maintaining an IRC connection.
 *
 *    @return An IRCClient object in a disconnected ready state.
 */
- (instancetype)initWithConfiguration:(IRCConnectionConfiguration *)config;

/*!
 *    @brief  Try to connect to the IRC server in the configuration.
 */
- (void)connect;

/*!
 *    @brief Called when a connection has been successfuly established to the server
 */
- (void)clientDidConnect;

/*!
 *    @brief  Called when a connection has been closed gracefully.
 */
- (void)clientDidDisconnect;

/*!
 *    @brief  Called when user stops connecting attempts.
 */
- (void)stopReconnectAttempts;

/*!
 *    @brief  Indicates whether the connection is established and has finished its initial exchange with the server.
 *
 *    @return Boolean indicating whether the connection is connected and ready.
 */
- (BOOL)isConnectedAndCompleted;

/*!
 *    @brief  Called when the connection has been closed due to an error.
 *
 *    @param error A human readable error string representing the reason the connection ended.
 */
- (void)clientDidDisconnectWithError:(NSString *)error;

/*!
 *    @brief  Parse a message from the server.
 *
 *    @param decodedData A string containing the decoded message from the server.
 *
 *    @return An IRCMessage object with the basic parsed details of the message.
 */
- (IRCMessage *)clientDidReceiveData:(const char *)decodedData;

/*!
 *    @brief  Called when the client has sent a message to the server.
 */
- (void)clientDidSendData;

/*!
 *    @brief  Get the channel prefix characters supported by the server.
 *
 *    @param client The IRCClient object to retrieve the server information from.
 *
 *    @return A string of the characters allowed by the server.
 */
+ (NSString *)getChannelPrefixCharacters:(IRCClient *)client;

/*!
 *    @brief  Get the connected status of the users associated with any open query windows and set the UI status accordingly.
 */
- (void)validateQueryStatusOnAllItems;

/*!
 *    @brief  Disconnect from the server, sending the standard pre-configured quit message.
 */
- (void)disconnect;

/*!
 *    @brief  Disconnect from the server with a custom quit message.
 *
 *    @param message The quit message to send to the server.
 */
- (void)disconnectWithMessage:(NSString *)message;

/*!
 *    @brief  Join all channels in our configuration with autojoin enabled.
 */
- (void)autojoin;

/*!
 *    @brief  Output a message to the "Console" window of the application.
 *
 *    @param output The message to output to the console window.
 */
- (void)outputToConsole:(NSString *)output;

/*!
 *    @brief  Add a channel to the channel list and join it on the server.
 *
 *    @param channel Channel object of the channel to add.
 *
 *    @return Boolean indicating whether adding the channel was successful.
 */
- (BOOL)addChannel:(IRCChannel *)channel;

/*!
 *    @brief  Remove a channel from the channel list and part form it on the server.
 *
 *    @param channel Channel object of the channel to remove.
 *
 *    @return Boolean indicating whether removing the channel was successful.
 */
- (BOOL)removeChannel:(IRCChannel *)channel;

/*!
 *    @brief  Add a query to the conversation list.
 *
 *    @param query Conversation object of the query to add.
 *
 *    @return Boolean indicating whether adding the query was successful.
 */
- (BOOL)addQuery:(IRCConversation *)query;

/*!
 *    @brief  Remove a query from the conversation list.
 *
 *    @param query Conversation object of the query to remove.
 *
 *    @return Boolean indicating whether removing the query was successful.
 */
- (BOOL)removeQuery:(IRCConversation *)query;

/*!
 *    @brief  Sort all channels in the conversation list alphabetically.
 *
 *    @return Sorted list of channels
 */
- (NSMutableArray *)sortChannelItems;

/*!
 *    @brief  Sort all queries in the conversation list alphabetically
 *
 *    @return Sorted list of queries.
 */
- (NSMutableArray *)sortQueryItems;

/*!
 *    @brief  Get the received time of a message.
 *
 *    @param tags An NSDictionary containing the tags that was sent with the message (if any)
 *
 *    @return The time from the timestamp sent with the message or the current time if none was found.
 */
+ (NSDate *)getTimestampFromMessageTags:(NSMutableDictionary *)tags;

@end

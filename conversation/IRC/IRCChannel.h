/*
 Copyright (c) 2014-2015, Tobias Pollmann, Alex Sørlie Glomsaas.
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
#import "IRCClient.h"
#import "IRCConversation.h"
#import "IRCChannelConfiguration.h"
#import "IRCUser.h"

@class IRCClient;

@interface IRCChannel : IRCConversation

@property (nonatomic) NSString *topic;
@property (nonatomic) NSMutableArray *users;
@property (nonatomic) NSMutableArray *channelModes;
@property (nonatomic, assign) BOOL isJoinedByUser;

/*!
 *    @brief  Create an instance of an IRC Channel based on a channel configuration.
 *
 *    @param config A channel configuration object to use for creating the channel.
 *    @param client An IRCClient object associated with this channel.
 *
 *    @return An IRCChannel in an inactive (parted) state.
 */
- (instancetype)initWithConfiguration:(IRCChannelConfiguration *)config withClient:(IRCClient *)client;

/*!
 *    @brief  Set the channel topic
 *
 *    @param topic A string containing the channel topic.
 */
- (void)setTopic:(NSString *)topic;

/*!
 *    @brief  Remove a user from the userlist.
 *
 *    @param nickname The nickname of the user to remove.
 */
- (void)removeUserByName:(NSString *)nickname;

/*!
 *    @brief  Give a specific channel privilegie to one or more users.
 *
 *    @param users   An array containing a list of users to give the privilegie to.
 *    @param status  The privilegie to give the users (as a ChannelPrivilegie) enumerated value.
 *    @param channel The channel to perform this action on.
 */
- (void)givePrivilegieToUsers:(NSArray *)users toStatus:(int)status onChannel:(IRCChannel *)channel;

/*!
 *    @brief  Revoke a specific channel privilegie from one or more users.
 *
 *    @param users   An array containing a list of users to revoke the privilegie from.
 *    @param status  The privilegie to revoke from the users (as a ChannelPrivilegie) enumerated value.
 *    @param channel The channel to perform this action on.
 */
- (void)revokePrivilegieFromUsers:(NSArray *)users toStatus:(int)status onChannel:(IRCChannel *)channel;

/*!
 *    @brief  Check if channel has user with specific nick
 *
 *    @param nick   A String of the user's nick.
 */
- (BOOL)hasUserWithNick:(NSString *)nick;

/*!
 *    @brief  Manually perform a sorting of the userlist.
 */
- (void)sortUserlist;

@end

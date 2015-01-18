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

#import "IRCChannel.h"
#import "IRCClient.h"
#import "IRCConnection.h"

@implementation IRCChannel

- (instancetype)initWithConfiguration:(IRCChannelConfiguration *)config withClient:(IRCClient *)client
{
    if ((self = [super init])) {
        /* Set the initial values for a channel before it receives necessary information from the server */
        self.name = config.name;
        self.client = client;
        self.topic = @"(No Topic)";
        self.users = [[NSMutableArray alloc] init];
        self.configuration = config;
        self.channelModes = [[NSMutableArray alloc] init];
        return self;
    }
    return nil;
}

- (BOOL)isActive
{
    return [self.client isConnected] && self.isJoinedByUser;
}

- (void)removeUserByName:(NSString *)nickname
{
    /* Shorthand method to remove a user from the userlist. */
    for (IRCUser *user in self.users) {
        if ([[user nick] isEqualToString:nickname]) {
            [self.users removeObject:user];
            break;
        }
    }
}

- (void)givePrivilegieToUsers:(NSArray *)users toStatus:(int)status onChannel:(IRCChannel *)channel
{
    /* This method takes an array of users and gives them the operator (+o) permission. 
     with multiple users it will build a string like "+oooo user1 user2 user3 user4" and run the mode command. */
    NSString *modeSymbol = [IRCUser statusToModeSymbol:status];
    if (modeSymbol) {
        NSString *modeString = @"+";
        int i = 1;
        while (i <= [users count]) {
            modeString = [modeString stringByAppendingString:modeSymbol];
        }
        [channel.client.connection send:[NSString stringWithFormat:@"MODE %@ %@", channel.name, modeString]];
    }
}

- (void)revokePrivilegieFromUsers:(NSArray *)users toStatus:(int)status onChannel:(IRCChannel *)channel
{
    /* This method takes an array of users and gives revokes operator permission (-o)
     with multiple users it will build a string like "-oooo user1 user2 user3 user4" and run the mode command. */
    NSString *modeSymbol = [IRCUser statusToModeSymbol:status];
    if (modeSymbol) {
        NSString *modeString = @"-";
        int i = 1;
        while (i <= [users count]) {
            modeString = [modeString stringByAppendingString:modeSymbol];
        }
        [channel.client.connection send:[NSString stringWithFormat:@"MODE %@ %@", channel.name, modeString]];
    }
}

- (void)sortUserlist
{
    /* Sort the userlist, first by privilegie, then by name. */
    NSSortDescriptor *nicknameSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"nick" ascending:YES];
    NSSortDescriptor *privilegiesSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"channelPrivilege" ascending:NO];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:privilegiesSortDescriptor,nicknameSortDescriptor,  nil];
    self.users = [[self.users sortedArrayUsingDescriptors:sortDescriptors] mutableCopy];
}

@end

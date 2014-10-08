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

#import "IRCConnectionConfiguration.h"

@implementation IRCConnectionConfiguration

- (id)init
{
    if ((self = [super init])) {
        /* Initialise default values for the configuration */
        self.uniqueIdentifier = [[NSUUID UUID] UUIDString];
        self.connectionName = @"Untitled Connection";
        self.realNameForRegistration = @"A Conversation IRC User";
        self.usernameForRegistration = @"user";
        self.primaryNickname = @"Guest";
        self.secondaryNickname = @"Guest_";
        self.serverAddress = @"";
        self.connectionPort = 6667;
        
        self.disconnectMessage = @"Conversation IRC Client for iOS (https://github.com/ConversationDevelopers/conversation)";
        self.channelDepartMessage = [self.disconnectMessage copy];
        
        self.automaticallyConnect =             NO;
        self.automaticallyReconnect =           NO;
        self.connectUsingSecureLayer =          NO;
        self.ignoreSSLVerificationErrors =      NO;
        self.useServerAuthenticationService =   NO;
        
        self.channels = [[NSDictionary alloc] init];
        return self;
    }
    return nil;
}

- (id)copyWithZone:(NSZone *)zone
{
    IRCConnectionConfiguration *config = [[IRCConnectionConfiguration allocWithZone:zone] init];
    return config;
}

@end

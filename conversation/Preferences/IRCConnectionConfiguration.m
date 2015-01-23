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
#import "IRCChannelConfiguration.h"
#import <objc/runtime.h>

@implementation IRCConnectionConfiguration

- (id)init
{
    if ((self = [super init])) {
        /* Initialise default values for the configuration */
        self.uniqueIdentifier = [[NSUUID UUID] UUIDString];
        self.connectionName = @"Untitled Connection";
        self.realNameForRegistration = [[NSUserDefaults standardUserDefaults] stringForKey:@"realname_preference"];
        self.usernameForRegistration = [[NSUserDefaults standardUserDefaults] stringForKey:@"username_preference"];
        self.primaryNickname = [[NSUserDefaults standardUserDefaults] stringForKey:@"nickname_preference"];
        self.secondaryNickname = @"Guest_";
        self.serverAddress = @"irc.example.net";
        self.connectionPort = 6667;
        self.serverPasswordReference = @"";
        self.socketEncodingType = NSUTF8StringEncoding;
        
        self.disconnectMessage = [[NSUserDefaults standardUserDefaults] stringForKey:@"quitmsg_preference"];
        self.channelDepartMessage = [[NSUserDefaults standardUserDefaults] stringForKey:@"partmsg_preference"];
        
        self.automaticallyConnect =             NO;
        self.connectUsingSecureLayer =          NO;
        self.useServerAuthenticationService =   NO;
        self.showConsoleOnConnect =             NO;
        self.automaticallyReconnect =           YES;
        
        self.lastMessageTime = 0;
        
        self.messageEncoding = (unsigned long) NSUTF8StringEncoding;

        self.channels = [[NSArray alloc] init];
        self.queries = [[NSArray alloc] init];
        self.ignores = [[NSArray alloc] init];
        self.connectCommands = [[NSArray alloc] init];
        
        self.trustedSSLSignatures = [[NSArray alloc] init];
        
        return self;
    }
    return nil;
}

- (id)initWithDictionary:(NSDictionary *)dict
{
    if ((self = [super init])) {
        self.uniqueIdentifier = dict[@"uniqueIdentifier"];
        self.connectionName = dict[@"connectionName"];
        self.realNameForRegistration = dict[@"realNameForRegistration"];
        self.usernameForRegistration = dict[@"usernameForRegistration"];
        self.primaryNickname = dict[@"primaryNickname"];
        self.secondaryNickname = dict[@"secondaryNickname"];
        self.serverAddress = dict[@"serverAddress"];
        self.connectionPort = [dict[@"connectionPort"] integerValue];
        self.serverPasswordReference = dict[@"serverPasswordReference"];
        self.authenticationPasswordReference = dict[@"authenticationPasswordReference"];
        
        self.socketEncodingType = [dict[@"socketEncodingType"] integerValue];
        
        self.disconnectMessage = dict[@"disconnectMessage"];
        self.channelDepartMessage = dict[@"channelDepartMessage"];
        
        self.automaticallyConnect = [dict[@"automaticallyConnect"] boolValue];
        self.automaticallyReconnect = [dict[@"automaticallyReconnect"] boolValue];
        self.connectUsingSecureLayer = [dict[@"connectUsingSecureLayer"] boolValue];
        self.useServerAuthenticationService = [dict[@"useServerAuthenticationService"] boolValue];
        self.showConsoleOnConnect = [dict[@"showConsoleOnConnect"] boolValue];
        
        self.messageEncoding = (unsigned long) [dict[@"messageEncoding"] integerValue];
        
        self.lastMessageTime = [dict[@"lastMessageTime"] longValue];
        
        NSMutableArray *channels = [[NSMutableArray alloc] init];
        for (NSDictionary *channel in dict[@"channels"]) {
            [channels addObject:[[IRCChannelConfiguration alloc] initWithDictionary:channel]];
        }
        
        self.channels = channels;

        NSMutableArray *queries = [[NSMutableArray alloc] init];
        for (NSDictionary *channel in dict[@"queries"]) {
            [queries addObject:[[IRCChannelConfiguration alloc] initWithDictionary:channel]];
        }
        
        self.queries = queries;
        
        NSMutableArray *trustedSSLSignatures = [[NSMutableArray alloc] init];
        for (NSString *signature in dict[@"trustedSSLSignatures"]) {
            [trustedSSLSignatures addObject:signature];
        }
        
        self.trustedSSLSignatures = trustedSSLSignatures;
        self.ignores = dict[@"ignores"];
        self.connectCommands = dict[@"connectCommands"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    IRCConnectionConfiguration *config = [[IRCConnectionConfiguration allocWithZone:zone] init];
    return config;
}

- (NSDictionary *)getDictionary
{
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    unsigned int numberOfProperties;
    objc_property_t *properties = class_copyPropertyList([self class], &numberOfProperties);
    for (int i = 0; i < numberOfProperties; i++) {
        objc_property_t property = properties[i];
        NSString *propertyName = [NSString stringWithUTF8String:property_getName(property)];
        if([propertyName isEqualToString:@"channels"]) {
            NSMutableArray *channels = [[NSMutableArray alloc] init];
            for (IRCChannelConfiguration *channel in self.channels) {
                [channels addObject:[channel getDictionary]];
            }
            dict[propertyName] = channels;
        } else if([propertyName isEqualToString:@"queries"]) {
            NSMutableArray *queries = [[NSMutableArray alloc] init];
            for (IRCChannelConfiguration *query in self.queries) {
                [queries addObject:[query getDictionary]];
            }
            dict[propertyName] = queries;
        } else if ([propertyName isEqualToString:@"trustedSSLSignatures"]) {
            NSMutableArray *trustedSSLSignatures = [[NSMutableArray alloc] init];
            for (NSString *signature in self.trustedSSLSignatures) {
                [trustedSSLSignatures addObject:signature];
            }
            dict[propertyName] = trustedSSLSignatures;
        } else {
            id valueForProperty = [self valueForKey:propertyName];
            if(valueForProperty != nil) {
                dict[propertyName] = valueForProperty;
            }
        }
    }
    free(properties);
    return dict;
    
}

@end

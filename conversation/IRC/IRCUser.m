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

#import "IRCUser.h"
#import "IRCChannel.h"

@implementation IRCUser

- (instancetype) initWithSenderDict:(const char **)senderDict onClient:(IRCClient *)client
{
    if ((self = [super init])) {
        /* senderDicts are C arrays of C strings returned by the parser that represents a sender.
         They contain the nickname, username, and hostname. */
        self.nick = [NSString stringWithCString:senderDict[0] usingEncodingPreference:[client configuration]];
        self.username = [NSString stringWithCString:senderDict[1] usingEncodingPreference:[client configuration]];
        self.hostname = [NSString stringWithCString:senderDict[2] usingEncodingPreference:[client configuration]];
        
        return [self initWithNickname:self.nick andUsername:self.username andHostname:self.hostname andRealname:nil onClient:client];
    }
    return nil;
}

- (instancetype) initWithNickname:(NSString *)nickname andUsername:(NSString *)username andHostname:(NSString *)hostname andRealname:(NSString *)realname onClient:(IRCClient *)client
{
    if ((self = [super init])) {
        self.nick = nickname;
        self.username = username;
        self.hostname = hostname;
        self.realname = realname;
        
        self.isAway = NO;
        
        self.ircop  = NO;
        self.owner  = NO;
        self.admin  = NO;
        self.op     = NO;
        self.halfop = NO;
        self.voice  = NO;
        
        return self;
    }
    return nil;
}

- (int) channelPrivilege
{
    if (self.ircop) {
        return IRCOP;
    } else if (self.owner) {
        return OWNER;
    } else if (self.admin) {
        return ADMIN;
    } else if (self.op) {
        return OPERATOR;
    } else if (self.halfop) {
        return HALFOP;
    } else if (self.voice) {
        return VOICE;
    }
    return NORMAL;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@!%@@%@", self.nick, self.username, self.hostname];
}

- (NSString *)fullhostmask
{
    return [NSString stringWithFormat:@"%@!%@@%@", self.nick, self.username, self.hostname];
}

- (BOOL)isIgnoredHostMask:(IRCClient *)client
{
    for (NSString *ignoreMaskString in [client.configuration ignores]) {
        if ([ignoreMaskString isValidWildcardIgnoreMask]) {
            NSString *hostmask = [self fullhostmask];
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF like %@", ignoreMaskString];
            if ([predicate evaluateWithObject:hostmask] == YES) {
                return YES;
            }
        } else {
            if ([ignoreMaskString isEqualToString:self.nick]) {
                return YES;
            }
        }
    }
    return NO;
}

+ (IRCUser *)fromNickname:(NSString *)sender onChannel:(IRCChannel *)channel
{
    /* Iterate through the userlist and return the first user with the same nickname as the sender. */
    IRCUser *userFromUserlist = nil;
    for (IRCUser *user in [channel users]) {
        if ([[user nick] isEqualToStringCaseInsensitive:sender]) {
            userFromUserlist = user;
            break;
        }
    }
    if (!userFromUserlist.username.length || !userFromUserlist.hostname.length)
        return nil;
    
    return userFromUserlist;
}

- (void)setPrivilegeMode:(const char *)mode granted:(BOOL)granted
{
    switch (*mode) {
        case 'q':
            self.owner = granted;
            break;
            
        case 'a':
            self.admin = granted;
            break;
            
        case 'o':
            self.op = granted;
            break;
            
        case 'h':
            self.halfop = granted;
            break;
            
        case 'v':
            self.voice = granted;
            break;
    }
}


+ (NSString *)statusToModeSymbol:(int)status
{
    switch (status) {
        case OWNER:
            return @"q";
        
        case ADMIN:
            return @"a";
            
        case OPERATOR:
            return @"o";
            
        case HALFOP:
            return @"h";
            
        case VOICE:
            return @"v";
            
        default:
            return nil;
    }
}

@end

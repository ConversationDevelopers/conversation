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

#import "WHOIS.h"
#import "IRCClient.h"

@implementation WHOIS

- (instancetype) initWithNickname:(NSString *)nickname
{
    if ((self = [super init])) {
        self.nickname          = nickname;
        self.username          = @"";
        self.hostname          = @"";
        self.realname          = @"";
        self.account           = @"";
        self.server            = @"";
        self.serverDescription = @"";
        self.channels = [[NSArray alloc] init];
        
        self.connectedUsingASecureConnection = NO;
        self.isAway = NO;
        
        self.idleSinceTime = nil;
        self.signedInAtTime = nil;
        
        return self;
    }
    return nil;
}

+ (WHOIS *)getOrCreateForName:(NSString *)name forClient:(IRCClient *)client
{
	WHOIS *whoisUser = [client.whoisRequests objectForKey:name];
	if (whoisUser == nil) {
		whoisUser = [[WHOIS alloc] initWithNickname:name];
	}
	return whoisUser;
}

@end

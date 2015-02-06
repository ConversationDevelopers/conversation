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

@interface IRCConnectionConfiguration : NSObject <NSCopying>

-(id)initWithDictionary:(NSDictionary *)dict;
-(NSDictionary *)getDictionary;

@property (nonatomic, copy) NSString *uniqueIdentifier;
@property (nonatomic, copy) NSString *connectionName;
@property (nonatomic, copy) NSString *authenticationPasswordReference;
@property (nonatomic, copy) NSString *serverPasswordReference;
@property (nonatomic, copy) NSString *realNameForRegistration;
@property (nonatomic, copy) NSString *usernameForRegistration;
@property (nonatomic, copy) NSString *primaryNickname;
@property (nonatomic, copy) NSString *secondaryNickname;
@property (nonatomic, copy) NSString *serverAddress;
@property (nonatomic, copy) NSString *disconnectMessage;
@property (nonatomic, copy) NSString *channelDepartMessage;

@property (nonatomic, assign) NSInteger socketEncodingType;
@property (nonatomic, assign) NSInteger connectionPort;
@property (nonatomic, assign) long lastMessageTime;

@property (nonatomic) unsigned long messageEncoding;

@property (nonatomic, assign) BOOL automaticallyReconnect;
@property (nonatomic, assign) BOOL automaticallyConnect;
@property (nonatomic, assign) BOOL connectUsingSecureLayer;
@property (nonatomic, assign) BOOL useServerAuthenticationService;
@property (nonatomic, assign) BOOL showConsoleOnConnect;
@property (nonatomic, assign) BOOL pushEnabled;

@property (nonatomic, copy) NSArray *autoJoinChannels;
@property (nonatomic, copy) NSArray *channels;
@property (nonatomic, copy) NSArray *queries;
@property (nonatomic, copy) NSArray *ignores;
@property (nonatomic, copy) NSArray *connectCommands;
@property (nonatomic, copy) NSArray *trustedSSLSignatures;

@end

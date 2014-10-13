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

#import <Foundation/Foundation.h>
#import "IRCConnectionConfiguration.h"
#import "IRCMessageIndex.h"

@class IRCConnection;

@interface IRCClient : NSObject

@property (nonatomic, strong) IRCConnectionConfiguration *configuration;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) BOOL isAttemptingConnection;
@property (nonatomic, assign) BOOL hasSuccessfullyAuthenticated;
@property (nonatomic, assign) BOOL isAwaitingAuthenticationResponse;
@property (nonatomic, assign) BOOL isAttemptingRegistration;
@property (nonatomic, assign) BOOL isBNCConnection;
@property (nonatomic, assign) BOOL isProcessingTermination;


@property (nonatomic, strong) NSMutableDictionary *featuresSupportedByServer;

- (instancetype)initWithConfiguration:(IRCConnectionConfiguration *)config;
- (void)connect;
- (void)clientDidConnect;
- (void)clientDidDisconnect;
- (void)clientDidDisconnectWithError:(NSString *)error;
- (void)clientDidReceiveData:(const char *)decodedData;
- (void)clientDidSendData;
- (void)disconnect;

- (NSMutableArray *)getChannels;
- (NSMutableArray *)getQueries;

@end

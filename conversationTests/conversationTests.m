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

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "AppPreferences.h"
#import "IRCClient.h"

@interface conversationTests : XCTestCase

@property IRCClient *testClient;
@property XCTestExpectation *didConnectToServerExpectation;

@end

@implementation conversationTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    IRCConnectionConfiguration *testConnection = [[IRCConnectionConfiguration alloc] init];
    testConnection.serverAddress = @"irc.freenode.net";
    testConnection.primaryNickname = [@"UnitTest" stringByAppendingString:[[NSUUID UUID] UUIDString]];
    
    IRCChannelConfiguration *testChannel = [[IRCChannelConfiguration alloc] init];
    testChannel.name = @"#conversation";
    
    NSArray *channels = [[NSMutableArray alloc] initWithObjects:testChannel, nil];
    testConnection.channels = channels;
    
    self.testClient = [[IRCClient alloc] initWithConfiguration:testConnection];
    
    [self.testClient connect];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testClientDidConnect {
    // This is an example of a functional test case.
    self.didConnectToServerExpectation = [self expectationForNotification:@"clientDidConnect" object:self.testClient handler:nil];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

@end

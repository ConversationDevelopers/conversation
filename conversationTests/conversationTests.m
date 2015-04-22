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

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "AppPreferences.h"
#import "IRCClient.h"
#import "IRCConversation.h"
#import "IRCChannel.h"
#import "IRCMessage.h"
#import "WHOIS.h"

@interface conversationTests : XCTestCase

@property IRCClient *testClient;
@property __weak XCTestExpectation *receivedCTCPRequestExpectation;
@property __weak XCTestExpectation *receivedActionExpectation;
@property __weak XCTestExpectation *receivedNoticeExpectation;
@property __weak XCTestExpectation *receivedCTCPReplyExpectation;
@property __weak XCTestExpectation *receivedJoinExpectation;
@property __weak XCTestExpectation *receivedExtendedJoinExpectation;
@property __weak XCTestExpectation *receivedJoinNGIRCDExpectation;
@property __weak XCTestExpectation *receivedPartExpectation;
@property __weak XCTestExpectation *receivedPartWithoutMessageExpectation;
@property __weak XCTestExpectation *receivedNickChangeExpectation;
@property __weak XCTestExpectation *receivedNickChangeNGIRCDExpectation;
@property __weak XCTestExpectation *receivedKickExpectation;
@property __weak XCTestExpectation *receivedQuitExpectation;
@property __weak XCTestExpectation *receivedChannelModesExpectation;
@property __weak XCTestExpectation *receivedTopicExpectation;
@property __weak XCTestExpectation *receivedISONExpectation;
@property __weak XCTestExpectation *receivedWHOISExpectation;

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
    IRCChannel *channel = [[IRCChannel alloc] initWithConfiguration:testChannel withClient:self.testClient];
    
    IRCUser *user = [[IRCUser alloc] initWithNickname:@"John" andUsername:@"jappleseed" andHostname:@"apple.com" andRealname:@"John AppleSeed" onClient:self.testClient];
    [channel.users addObject:user];
    IRCUser *kickUser = [[IRCUser alloc] initWithNickname:@"Clinteger" andUsername:@"~Clinteger" andHostname:@"unaffiliated/clinteger" andRealname:@"" onClient:self.testClient];
    [channel.users addObject:kickUser];
    
    [self.testClient addChannel:channel];
    
    self.testClient.currentUserOnConnection = [[IRCUser alloc] initWithNickname:testConnection.primaryNickname andUsername:testConnection.usernameForRegistration andHostname:@"test.com" andRealname:@"Unit Test" onClient:self.testClient];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testParserWithPRIVMSG {
    NSString *testMessage = @":John!jappleseed@apple.com PRIVMSG #conversation :Good day";
    IRCMessage *parserResult = [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    
    XCTAssertEqualObjects(parserResult.conversation.name, @"#conversation");
    XCTAssertEqualObjects(parserResult.sender.nick, @"John");
    XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
    XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
    XCTAssertEqualObjects(parserResult.message, @"Good day");
}

- (void)testParserWithCTCPRequest {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_CTCP) {
            XCTAssertEqualObjects(parserResult.conversation.name, @"John");
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            XCTAssertEqualObjects(parserResult.message, @"VERSION");
            
            [self.receivedCTCPRequestExpectation fulfill];
        }
    }];
    
    self.receivedCTCPRequestExpectation = [self expectationWithDescription:@"receivedCTCPRequest"];
    NSString *testMessage = [NSString stringWithFormat:@":John!jappleseed@apple.com PRIVMSG %@ :\001VERSION\001", self.testClient.configuration.primaryNickname];
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithACTION {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_ACTION) {
            XCTAssertEqualObjects(parserResult.conversation.name, @"#conversation");
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            XCTAssertEqualObjects(parserResult.message, @"hates unit tests");
            
            [self.receivedActionExpectation fulfill];
        }
    }];
    
    self.receivedActionExpectation = [self expectationWithDescription:@"receivedACTION"];
    NSString *testMessage = @":John!jappleseed@apple.com PRIVMSG #conversation :\001ACTION hates unit tests\001";
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithNOTICE {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_NOTICE) {
            XCTAssertEqualObjects(parserResult.conversation.name, @"John");
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            XCTAssertEqualObjects(parserResult.message, @"good day");
            
            [self.receivedNoticeExpectation fulfill];
        }
    }];
    
    self.receivedNoticeExpectation = [self expectationWithDescription:@"receivedNOTICE"];
    NSString *testMessage = [NSString stringWithFormat:@":John!jappleseed@apple.com NOTICE %@ :good day", self.testClient.configuration.primaryNickname];
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithCTCPReply {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_CTCPREPLY) {
            XCTAssertEqualObjects(parserResult.conversation.name, @"John");
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            XCTAssertEqualObjects(parserResult.message, @"TIME Saturday, 7 February 2015 09:42:49 Central Europe");
            
            [self.receivedCTCPReplyExpectation fulfill];
        }
    }];
    
    self.receivedCTCPReplyExpectation = [self expectationWithDescription:@"receivedCTCPReply"];
    NSString *testMessage = [NSString stringWithFormat:@":John!jappleseed@apple.com NOTICE %@ :\001TIME Saturday, 7 February 2015 09:42:49 Central Europe\001", self.testClient.configuration.primaryNickname];
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithJoin {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_JOIN) {
            XCTAssertEqualObjects(parserResult.conversation.name, @"#conversation");
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            
            [self.receivedJoinExpectation fulfill];
        }
    }];
    
    self.receivedJoinExpectation = [self expectationWithDescription:@"receivedJoin"];
    NSString *testMessage = @":John!jappleseed@apple.com JOIN #conversation";
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithJoinNGIRCD {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_JOIN) {
            XCTAssertEqualObjects(parserResult.conversation.name, @"#conversation");
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            
            [self.receivedJoinNGIRCDExpectation fulfill];
        }
    }];
    
    self.receivedJoinNGIRCDExpectation = [self expectationWithDescription:@"receivedJoinNGIRCD"];
    NSString *testMessage = @":John!jappleseed@apple.com JOIN :#conversation";
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithExtendedJoin {
    self.testClient.ircv3CapabilitiesSupportedByServer = @[@"extended-join"].mutableCopy;
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_JOIN) {
            XCTAssertEqualObjects(parserResult.conversation.name, @"#conversation");
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            XCTAssertEqualObjects(parserResult.sender.realname, @"John Appleseed");
            
            [self.receivedExtendedJoinExpectation fulfill];
        }
    }];
    
    self.receivedExtendedJoinExpectation = [self expectationWithDescription:@"receivedExtendedJoin"];
    NSString *testMessage = @":John!jappleseed@apple.com JOIN #conversation * :John Appleseed";
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithPartWithMessage {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_PART) {
            XCTAssertEqualObjects(parserResult.conversation.name, @"#conversation");
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            XCTAssertEqualObjects(parserResult.message, @"Good bye");
            
            [self.receivedPartExpectation fulfill];
        }
    }];
    
    self.receivedPartExpectation = [self expectationWithDescription:@"receivedPart"];
    NSString *testMessage = @":John!jappleseed@apple.com PART #conversation :Good bye";
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithPartWithoutMessage {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_PART) {
            XCTAssertEqualObjects(parserResult.conversation.name, @"#conversation");
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            
            [self.receivedPartWithoutMessageExpectation fulfill];
        }
    }];
    
    self.receivedPartWithoutMessageExpectation = [self expectationWithDescription:@"receivedPartNoMessage"];
    NSString *testMessage = @":John!jappleseed@apple.com PART :#conversation";
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithNickChange {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_NICK) {
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            XCTAssertEqualObjects(parserResult.message, @"John|Away");
            
            [self.receivedNickChangeExpectation fulfill];
        }
    }];
    
    self.receivedNickChangeExpectation = [self expectationWithDescription:@"receivedNickChange"];
    NSString *testMessage = @":John!jappleseed@apple.com NICK John|Away";
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithNickChangeNGIRCD {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_NICK) {
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            XCTAssertEqualObjects(parserResult.message, @"John|Away");
            
            [self.receivedNickChangeNGIRCDExpectation fulfill];
        }
    }];
    
    self.receivedNickChangeNGIRCDExpectation = [self expectationWithDescription:@"receivedNickChangeNGIRCD"];
    NSString *testMessage = @":John!jappleseed@apple.com NICK :John|Away";
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}


- (void)testParserWithKick {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_KICK) {
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            XCTAssertEqualObjects(parserResult.message, @"Your attitude is not conducive to the desired environment.");
            XCTAssertEqualObjects(parserResult.conversation.name, @"#conversation");
            XCTAssertEqualObjects(parserResult.kickedUser.nick, @"Clinteger");
            
            [self.receivedKickExpectation fulfill];
        }
    }];
    
    self.receivedKickExpectation = [self expectationWithDescription:@"receivedKick"];
    NSString *testMessage = @":John!jappleseed@apple.com KICK #conversation Clinteger :Your attitude is not conducive to the desired environment.";
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithQuitMessage {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_QUIT) {
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            XCTAssertEqualObjects(parserResult.message, @"Ping Timeout");
            
            [self.receivedQuitExpectation fulfill];
        }
    }];
    
    self.receivedQuitExpectation = [self expectationWithDescription:@"receivedQuitMessage"];
    NSString *testMessage = @":John!jappleseed@apple.com QUIT :Ping Timeout";
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithChannelModes {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_MODE) {
            IRCChannel *channel = (IRCChannel *)parserResult.conversation;
            
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            XCTAssertEqualObjects(parserResult.conversation.name, @"#conversation");
            XCTAssertEqualObjects(channel.channelModes, @[@"m"]);
            
            [self.receivedChannelModesExpectation fulfill];
        }
    }];
    
    self.receivedChannelModesExpectation = [self expectationWithDescription:@"receivedChannelModes"];
    NSString *testMessage = @":John!jappleseed@apple.com MODE #conversation :+m";
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithTopicMessage {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"messageReceived" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        IRCMessage *parserResult = notification.object;
        
        if (parserResult.messageType == ET_TOPIC) {
            IRCChannel *channel = (IRCChannel *)parserResult.conversation;
            
            XCTAssertEqualObjects(parserResult.sender.nick, @"John");
            XCTAssertEqualObjects(parserResult.sender.username, @"jappleseed");
            XCTAssertEqualObjects(parserResult.sender.hostname, @"apple.com");
            XCTAssertEqualObjects(parserResult.conversation.name, @"#conversation");
            XCTAssertEqualObjects(channel.topic, @"Channel for awesome people");
            
            [self.receivedTopicExpectation fulfill];
        }
    }];
    
    self.receivedTopicExpectation = [self expectationWithDescription:@"receivedChannelTopic"];
    NSString *testMessage = @":John!jappleseed@apple.com TOPIC #conversation :Channel for awesome people";
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithISONResponse {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"receivedISONResponse" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        NSArray *parserResult = notification.object;
        
        XCTAssertGreaterThan([parserResult count], 0);
        XCTAssertEqualObjects([parserResult objectAtIndex:0], @"John");
        [self.receivedISONExpectation fulfill];
    }];
    
    self.receivedISONExpectation = [self expectationWithDescription:@"receivedISON"];
    NSString *testMessage = @":holmes.freenode.net 303 UnitTest :John";
    [self.testClient clientDidReceiveData:[testMessage UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testParserWithWHOISResponse {
    [[NSNotificationCenter defaultCenter] addObserverForName:@"whois" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        WHOIS *parserResult = notification.object;
        
        XCTAssertEqualObjects(parserResult.nickname, @"John");
        XCTAssertEqualObjects(parserResult.username, @"jappleseed");
        XCTAssertEqualObjects(parserResult.hostname, @"apple.com");
        XCTAssertEqualObjects(parserResult.realname, @"John Appleseed");
        
        XCTAssertEqualObjects(parserResult.server, @"card.freenode.net");
        XCTAssertEqualObjects(parserResult.serverDescription, @"Washington DC, USA");
        
        XCTAssertEqual(parserResult.connectedUsingASecureConnection, YES);
        
        XCTAssertEqualObjects(parserResult.account, @"John");
        [self.receivedWHOISExpectation fulfill];
    }];
    
    self.receivedWHOISExpectation = [self expectationWithDescription:@"receivedWHOIS"];
    [self.testClient clientDidReceiveData:[@":holmes.freenode.net 311 UnitTest John jappleseed apple.com * :John Appleseed" UTF8String]];
    [self.testClient clientDidReceiveData:[@":holmes.freenode.net 319 UnitTest John :#conversation" UTF8String]];
    [self.testClient clientDidReceiveData:[@":holmes.freenode.net 312 UnitTest John card.freenode.net :Washington DC, USA" UTF8String]];
    [self.testClient clientDidReceiveData:[@":holmes.freenode.net 671 UnitTest John :is using a secure connection" UTF8String]];
    [self.testClient clientDidReceiveData:[@":holmes.freenode.net 317 UnitTest John 11265 1423320547 :seconds idle, signon time" UTF8String]];
    [self.testClient clientDidReceiveData:[@":holmes.freenode.net 330 UnitTest John John :is logged in as" UTF8String]];
    [self.testClient clientDidReceiveData:[@":holmes.freenode.net 318 UnitTest John :End of /WHOIS list." UTF8String]];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

@end

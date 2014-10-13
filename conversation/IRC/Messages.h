//
//  Messages.h
//  conversation
//
//  Created by Alex Sørlie Glomsaas on 13/10/2014.
//  Copyright (c) 2014 conversation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IRCChannel.h"
#import "NSString+Methods.h"

@class IRCClient;

@interface Messages : NSObject

+ (void)userReceivedMessage:(const char *)message onRecepient:(char *)recepient byUser:(char **)senderDict onClient:(IRCClient *)client;

+ (void)userReceivedCTCPMessage:(const char *)message onRecepient:(char *)recepient byUser:(char **)senderDict onClient:(IRCClient *)client;

+ (void)userReceivedACTIONMessage:(const char *)message onRecepient:(char *)recepient byUser:(char **)senderDict onClient:(IRCClient *)client;

@end

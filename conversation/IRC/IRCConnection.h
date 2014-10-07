//
//  IRCConnection.h
//  conversation
//
//  Created by Toby P on 05/10/14.
//  Copyright (c) 2014 conversation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AsyncSocket.h"

@interface IRCConnection : NSObject {
    AsyncSocket *asyncSocket;
}

- (id)init;
- (void)connectToHost:(NSString *)host onPort:(UInt16)port withPassword:(NSString *)password nick:(NSString *)nick ident:(NSString *)ident realName:(NSString *)realname;

@end

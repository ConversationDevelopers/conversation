//
//  UserListItemCell.h
//  Conversation
//
//  Created by Toby P on 11/11/14.
//  Copyright (c) 2014 conversation. All rights reserved.
//

#import <UIKit/UIKit.h>

@class UserStatusView;
@class IRCClient;
@class IRCUser;

@interface UserListItemCell : UITableViewCell {
    UserStatusView *_statusView;
    UILabel *_nickLabel;
}

@property (nonatomic) IRCClient *client;
@property (nonatomic) IRCUser *user;

@end

//
//  UserListItemCell.m
//  Conversation
//
//  Created by Toby P on 11/11/14.
//  Copyright (c) 2014 conversation. All rights reserved.
//

#import "UserListItemCell.h"
#import "IRCUser.h"
#import "UserStatusView.h"

@implementation UserListItemCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        return nil;
    }
    
    self.contentView.backgroundColor = [UIColor clearColor];
    self.backgroundColor = [UIColor clearColor];
    
    [self.textLabel removeFromSuperview];
    
    _nickLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nickLabel.backgroundColor = [UIColor clearColor];    
    _nickLabel.font = [UIFont systemFontOfSize:16.0];
    
    [self.contentView addSubview:_nickLabel];
    return self;
}

- (void)prepareForReuse
{
    _user = nil;
    _client = nil;
    _nickLabel.text = @"";
    _statusView.frame = CGRectZero;
    _nickLabel.frame = CGRectZero;
    
    [_statusView removeFromSuperview];
    _statusView = nil;
}

- (void)layoutSubviews
{
    _statusView = [[UserStatusView alloc] initWithFrame:CGRectZero];
    _statusView.backgroundColor = [UIColor clearColor];

    _statusView.frame = CGRectMake(10, 0, 30, self.contentView.bounds.size.height);
    _statusView.client = _client;
    _statusView.status = _user.channelPrivilege;

    _nickLabel.text = _user.nick;
    
    CGRect frame =
    [_nickLabel.text boundingRectWithSize:_nickLabel.frame.size
                                  options:NSStringDrawingUsesLineFragmentOrigin
                               attributes:@{ NSFontAttributeName:_nickLabel.font }
                                  context:nil];
    _nickLabel.frame = CGRectMake(45, 0, frame.size.width, self.contentView.bounds.size.height);
    
    [self.contentView addSubview:_statusView];
}

@end

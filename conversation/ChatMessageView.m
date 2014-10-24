//
//  ChatMessageView.m
//  Conversation
//
//  Created by Toby P on 24/10/14.
//  Copyright (c) 2014 conversation. All rights reserved.
//

#import "ChatMessageView.h"

@implementation ChatMessageView

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if(!self)
        return nil;
    
    [self.textLabel removeFromSuperview];

    _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.font = [UIFont boldSystemFontOfSize:18];
    _nameLabel.textColor = [UIColor darkGrayColor];
    
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _messageLabel.font = [UIFont systemFontOfSize:14.0];
    _messageLabel.textColor = [UIColor darkGrayColor];
    
    [self.contentView addSubview:_nameLabel];
    [self.contentView addSubview:_messageLabel];
    
    return self;
}

- (void) prepareForReuse
{
    [super prepareForReuse];
    
}

-(void)layoutSubviews
{
    
    [super layoutSubviews];
    
    CGSize size = [_nickname sizeWithAttributes:@{NSFontAttributeName: _nameLabel.font}];
    
    CGRect frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    frame.origin.y += 4;
    frame.origin.x = 10.0;
    frame.size = size;
    
    _nameLabel.text = _nickname;
    _nameLabel.frame = frame;
    
    frame.origin.y += 30;
    frame.size = _message.size;
    frame.size.width = self.frame.size.width - 10.0;

    _messageLabel.attributedText = _message;
    _messageLabel.frame = frame;
    
}


@end

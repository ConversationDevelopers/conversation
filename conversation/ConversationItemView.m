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

#import "ConversationItemView.h"

@implementation ConversationItemView

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if(!self)
        return nil;
    
    [self.textLabel removeFromSuperview];
    self.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    
    _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.font = [UIFont boldSystemFontOfSize:16];
    _nameLabel.textColor = [UIColor darkGrayColor];
    
    _firstDetailLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _firstDetailLabel.font = [UIFont fontWithName:@"Helvetica Neue" size:14.0];
    _firstDetailLabel.textColor = [UIColor lightGrayColor];

    _secondDetailLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _secondDetailLabel.font = [UIFont fontWithName:@"Helvetica Neue" size:14.0];
    _secondDetailLabel.textColor = [UIColor lightGrayColor];
    
    _unreadCountLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _unreadCountLabel.font = [UIFont fontWithName:@"Helvetica Neue" size:14.0];
    _unreadCountLabel.textColor = [UIColor lightGrayColor];

    [self.contentView addSubview:_nameLabel];
    [self.contentView addSubview:_firstDetailLabel];
    [self.contentView addSubview:_secondDetailLabel];
    [self.contentView addSubview:_unreadCountLabel];
    
    _isChannel = YES;
    _enabled = NO;
    
    self.imageView.image = [UIImage imageNamed:@"ChannelIcon"];

    
    return self;
}

- (void) prepareForReuse
{
    [super prepareForReuse];
    
}

-(void)layoutSubviews
{
    
    [super layoutSubviews];
    
    if (!_isChannel)
        self.imageView.image = [UIImage imageNamed:@"QueryIcon"];
    else
        self.imageView.image = [UIImage imageNamed:@"ChannelIcon"];
    
    if (!_enabled)
        self.alpha = 0.5;

    CGSize size = [_name sizeWithAttributes:@{NSFontAttributeName: _nameLabel.font}];
    
    CGRect frame = self.imageView.frame;
    frame.origin.y -= 6;
    frame.origin.x = frame.origin.x*2+frame.size.width;
    frame.size = size;
    
    _nameLabel.text = self.name;
    _nameLabel.frame = frame;
    
    
    NSArray *detail = [self.detail componentsSeparatedByString:@"\n"];
    NSString *firstdetail = detail[0];
    NSString *seconddetail = detail[1];
    
    frame.origin.y = round(self.imageView.frame.size.height / 2) + self.imageView.frame.origin.y - 5;
    size = [firstdetail sizeWithAttributes:@{NSFontAttributeName: _firstDetailLabel.font}];
    frame.origin.y -= 5;
    frame.size = size;
    frame.size.width = self.contentView.frame.size.width - self.imageView.frame.size.width;
    
    _firstDetailLabel.text = firstdetail;
    _firstDetailLabel.frame = frame;
    
    frame.origin.y += 15;
    
    _secondDetailLabel.text = seconddetail;
    _secondDetailLabel.frame = frame;
    
    
    if (self.accessoryType != UITableViewCellAccessoryNone) {
        NSArray *subviews;
        NSArray *vComp = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
        if ([[vComp objectAtIndex:0] intValue] >= 8) {
            // iOS 8 and newer
            subviews = self.subviews;
        } else {
            // iOS 7
            subviews = [self.subviews[0] subviews];
        }
        for (UIView *subview in subviews) {
            if([NSStringFromClass(subview.class) isEqualToString:@"UIButton"]) {
                // This subview should be the accessory view, change its frame
                CGRect frame = subview.frame;
                frame.origin.y -= 15;
                subview.frame = frame;
                
                if(_unreadCount > 0) {
                    
                    // Add unread count label
                    NSString *value = [NSString stringWithFormat:@"%li", (long)_unreadCount];
                    _unreadCountLabel.textColor = [UIColor lightGrayColor];
                    _unreadCountLabel.font = [UIFont fontWithName:@"Helvetica Neue" size:14.0];
                    _unreadCountLabel.text = value;
                    
                    // Calculate frame size
                    CGSize size = [value sizeWithAttributes:@{NSFontAttributeName: _unreadCountLabel.font }];
                    _unreadCountLabel.frame = CGRectMake(frame.origin.x-size.width-5, frame.origin.y-2, size.width, size.height);
                
                }
                
                break;
            }
        }
    }
    
}

@end

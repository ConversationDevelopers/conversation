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

#import "ConversationItemView.h"
#import "InterfaceLayoutDefinitions.h"

@implementation ConversationItemView

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if(!self)
        return nil;
    
    [self.textLabel removeFromSuperview];
    self.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    
    _nameLabel              = [[UILabel alloc] initWithFrame:CGRectZero];
    _nameLabel.font         = [InterfaceLayoutDefinitions largeLabelFont];
    _nameLabel.textColor    = [InterfaceLayoutDefinitions largeLabelTextColour];
    
    _firstDetailLabel           = [[UILabel alloc] initWithFrame:CGRectZero];
    _firstDetailLabel.font      = [InterfaceLayoutDefinitions standardLabelFont];
    _firstDetailLabel.textColor = [InterfaceLayoutDefinitions labelTextColour];

    _secondDetailLabel              = [[UILabel alloc] initWithFrame:CGRectZero];
    _secondDetailLabel.font         = [InterfaceLayoutDefinitions standardLabelFont];
    _secondDetailLabel.textColor    = [InterfaceLayoutDefinitions labelTextColour];
    
    _unreadCountLabel               = [[UILabel alloc] initWithFrame:CGRectZero];
    _unreadCountLabel.font          = [InterfaceLayoutDefinitions standardLabelFont];
    _unreadCountLabel.textColor     = [InterfaceLayoutDefinitions labelTextColour];
    
    _overlayView = [[UIView alloc] initWithFrame:CGRectZero];
    _overlayView.backgroundColor = self.backgroundColor;
    
    [self.contentView addSubview:_nameLabel];
    [self.contentView addSubview:_firstDetailLabel];
    [self.contentView addSubview:_secondDetailLabel];
    [self.contentView addSubview:_unreadCountLabel];
    [self.contentView addSubview:_overlayView];
    
    _isChannel = YES;
    _isConsole = NO;
    _enabled = NO;
    
    self.imageView.image = [UIImage imageNamed:@"ChannelIcon"];
    _previewMessages = [[NSMutableArray alloc] init];
    _unreadCount = 0;
    
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
    else if (_isConsole)
        self.imageView.image = [UIImage imageNamed:@"Console"];
    else
        self.imageView.image = [UIImage imageNamed:@"ChannelIcon"];
    
    _overlayView.frame = self.contentView.frame;
    
    if (!_enabled) {
        _overlayView.alpha = DISABLED_OPACITY_LEVEL;
        self.imageView.alpha = DISABLED_OPACITY_LEVEL;
    } else {
        _overlayView.alpha = HIDDEN_OPACITY_LEVEL;
        self.imageView.alpha = ENABLED_OPACITY_LEVEL;
    }

    CGSize size = [_name sizeWithAttributes:@{NSFontAttributeName: _nameLabel.font}];
    
    CGRect frame = self.imageView.frame;
    frame.origin.y -= 4;
    frame.origin.x = frame.origin.x*2+frame.size.width;
    frame.size = size;
    
    _nameLabel.text = self.name;
    _nameLabel.frame = frame;
    
    NSAttributedString *firstdetail;
    NSAttributedString *seconddetail;
    
    if(_previewMessages.count > 0)
        firstdetail = _previewMessages[0];

    if(_previewMessages.count > 1)
        seconddetail = _previewMessages[1];
    
    frame.origin.y = round(self.imageView.frame.size.height / 2) + self.imageView.frame.origin.y - 5;
    
    frame.size = firstdetail.size;
    frame.size.width = self.contentView.frame.size.width - self.imageView.frame.size.width;
    
    _firstDetailLabel.attributedText = firstdetail;
    _firstDetailLabel.frame = frame;
    
    frame.origin.y += 15;
    frame.size = seconddetail.size;
    frame.size.width = self.contentView.frame.size.width - self.imageView.frame.size.width;
    
    _secondDetailLabel.attributedText = seconddetail;
    _secondDetailLabel.frame = frame;
    
    NSArray *subviews;
    NSArray *vComp = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
    if ([[vComp objectAtIndex:0] intValue] >= 8) {
        // iOS 8 and newer
        subviews = self.subviews;
    } else {
        // iOS 7
        subviews = [self.subviews[0] subviews];
    }
    
    NSString *value = [NSString stringWithFormat:@"%li", (long)_unreadCount];
    
    if(_unreadCount > 0)
        _unreadCountLabel.text = value;
    else
        _unreadCountLabel.text = @"";
    
    for (UIView *subview in subviews) {
        if([NSStringFromClass(subview.class) isEqualToString:@"DisclosureView"]) {
            // This subview should be the accessory view, change its frame
            CGRect frame = subview.frame;
            frame.origin.y -= 15;
            subview.frame = frame;
            
                // Calculate frame size
            CGSize size = [value sizeWithAttributes:@{NSFontAttributeName: _unreadCountLabel.font }];
            _unreadCountLabel.frame = CGRectMake(frame.origin.x-size.width-5, frame.origin.y-2, size.width, size.height);
            
            break;
        }
    }
    
}

@end

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
    
    frame.origin.y += 25;
    frame.size = _message.size;
    frame.size.width = self.frame.size.width - 10.0;

    _messageLabel.attributedText = _message;
    _messageLabel.frame = frame;
    
}


@end

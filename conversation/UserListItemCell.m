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
    
    if (_user.isAway)
        _nickLabel.textColor = [UIColor colorWithRed:0.753 green:0.753 blue:0.753 alpha:1];
    else
        _nickLabel.textColor = [UIColor blackColor];
    
    CGRect frame =
    [_nickLabel.text boundingRectWithSize:_nickLabel.frame.size
                                  options:NSStringDrawingUsesLineFragmentOrigin
                               attributes:@{ NSFontAttributeName:_nickLabel.font }
                                  context:nil];
    _nickLabel.frame = CGRectMake(45, 0, frame.size.width, self.contentView.bounds.size.height);
    
    [self.contentView addSubview:_statusView];
}

@end

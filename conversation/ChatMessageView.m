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
    
    self.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    
    return self;
}

- (void) prepareForReuse
{
    [super prepareForReuse];
    
}

-(void)layoutSubviews
{
    
    [super layoutSubviews];
    
    NSString *time = @"";
    if (_timestamp) {
        NSDate *date = self.timestamp;
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDateComponents *components = [calendar components:(NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:date];
        time = [NSString stringWithFormat:@":%ld", [components minute]];
    }
    
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", self.nickname, self.message]];

    [string addAttribute:NSFontAttributeName
                  value:[UIFont boldSystemFontOfSize:16.0]
                  range:NSMakeRange(0, self.nickname.length)];
    
    [string addAttribute:NSFontAttributeName
                   value:[UIFont systemFontOfSize:12.0]
                   range:NSMakeRange(self.nickname.length+1, self.message.length)];
    
    NSMutableAttributedString *timestamp = [[NSMutableAttributedString alloc] initWithString:time];

    [timestamp addAttribute:NSFontAttributeName
                   value:[UIFont systemFontOfSize:12.0]
                   range:NSMakeRange(0, timestamp.length)];

    [timestamp addAttribute:NSForegroundColorAttributeName
                   value:[UIColor lightGrayColor]
                   range:NSMakeRange(0, timestamp.length)];
    
    CATextLayer *textLayer = [[CATextLayer alloc] init];
    textLayer.string = string;
    textLayer.backgroundColor = [UIColor clearColor].CGColor;
    [textLayer setForegroundColor:[[UIColor clearColor] CGColor]];
    [textLayer setContentsScale:[[UIScreen mainScreen] scale]];
    
    CGRect rect = [self calculateRect];
    
    textLayer.frame = CGRectMake(10, 0, self.bounds.size.width-20, rect.size.height);
    textLayer.wrapped = YES;
    
    [self.contentView.layer addSublayer:textLayer];
    textLayer = nil;
    
    textLayer = [[CATextLayer alloc] init];
    textLayer.string = timestamp;
    textLayer.backgroundColor = [UIColor clearColor].CGColor;
    [textLayer setForegroundColor:[[UIColor clearColor] CGColor]];
    [textLayer setContentsScale:[[UIScreen mainScreen] scale]];
    textLayer.wrapped = YES;
    
    textLayer.frame = CGRectMake(self.bounds.size.width-timestamp.size.width-5, 0, timestamp.size.width, timestamp.size.height);
    
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, rect.size.height);
    [self.contentView.layer addSublayer:textLayer];
    
}

- (CGRect)calculateRect
{
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", self.nickname, self.message]];
    
    [string addAttribute:NSFontAttributeName
                   value:[UIFont boldSystemFontOfSize:16.0]
                   range:NSMakeRange(0, self.nickname.length)];
    
    [string addAttribute:NSFontAttributeName
                   value:[UIFont systemFontOfSize:12.0]
                   range:NSMakeRange(self.nickname.length+1, self.message.length)];
    
    CGSize maxsize = CGSizeMake(300, CGFLOAT_MAX);
    return [string boundingRectWithSize:maxsize options:NSStringDrawingUsesLineFragmentOrigin context:nil];
}


@end

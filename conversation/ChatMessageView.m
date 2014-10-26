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
#import "IRCUser.h"
#import <CoreText/CoreText.h>

@implementation ChatMessageView

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if(!self)
        return nil;
    
    [self.textLabel removeFromSuperview];
    
    self.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    
    return self;
}

- (void) prepareForReuse
{
    [super prepareForReuse];
    self.frame = CGRectZero;
    NSArray *layers = [self.contentView.layer.sublayers copy];
    for (CATextLayer *layer in layers) {
        [layer removeFromSuperlayer];
    }
}

-(void)layoutSubviews
{
    
    [super layoutSubviews];

    
    NSString *time = @"";
    if (_message.timestamp) {
        NSDate *date = _message.timestamp;
        NSDateFormatter *format = [[NSDateFormatter alloc] init];
        [format setDateFormat:@"HH:mm:ss"];
        time = [format stringFromDate:date];
    }
    
    NSString *nick = _message.sender.nick;
    NSString *message = _message.message;
    
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", nick, message]];

    [string addAttribute:NSFontAttributeName
                  value:[UIFont boldSystemFontOfSize:16.0]
                  range:NSMakeRange(0, nick.length)];
    
    [string addAttribute:NSFontAttributeName
                   value:[UIFont systemFontOfSize:12.0]
                   range:NSMakeRange(nick.length+1, message.length)];
    
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
    [textLayer setRasterizationScale:[[UIScreen mainScreen] scale]];
    
    CGSize size = [self frameSizeForString:string];
    
    textLayer.frame = CGRectMake(10, 5, self.bounds.size.width-20, size.height);
    textLayer.wrapped = YES;
    
    [self.contentView.layer addSublayer:textLayer];
    textLayer = nil;
    
    textLayer = [[CATextLayer alloc] init];
    textLayer.string = timestamp;
    textLayer.backgroundColor = [UIColor clearColor].CGColor;
    [textLayer setForegroundColor:[[UIColor clearColor] CGColor]];
    [textLayer setContentsScale:[[UIScreen mainScreen] scale]];
    [textLayer setRasterizationScale:[[UIScreen mainScreen] scale]];
    
    textLayer.wrapped = YES;
    
    textLayer.frame = CGRectMake(self.bounds.size.width-timestamp.size.width-5, 5, timestamp.size.width, timestamp.size.height);
    
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, size.height+10);
    [self.contentView.layer addSublayer:textLayer];
    
}

- (CGSize)frameSizeForString:(NSAttributedString *)string
{
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString((CFAttributedStringRef)string);
    CGFloat width = self.bounds.size.width;
    
    CFIndex offset = 0, length;
    CGFloat y = 0;
    do {
        length = CTTypesetterSuggestLineBreak(typesetter, offset, width);
        CTLineRef line = CTTypesetterCreateLine(typesetter, CFRangeMake(offset, length));
        
        CGFloat ascent, descent, leading;
        CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
        
        CFRelease(line);
        
        offset += length;
        y += ascent + descent + leading;
    } while (offset < [string length]);
    
    CFRelease(typesetter);
    
    return CGSizeMake(width, ceil(y));
}

- (CGFloat)cellHeight
{
    NSString *nick = _message.sender.nick;
    NSString *message = _message.message;
    
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", nick, message]];
    
    [string addAttribute:NSFontAttributeName
                   value:[UIFont boldSystemFontOfSize:16.0]
                   range:NSMakeRange(0, nick.length)];
    
    [string addAttribute:NSFontAttributeName
                   value:[UIFont systemFontOfSize:12.0]
                   range:NSMakeRange(nick.length+1, message.length)];
    
    CGSize size = [self frameSizeForString:string];
    return size.height;
}

@end

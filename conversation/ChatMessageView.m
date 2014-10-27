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
#import <string.h>

#define FNV_PRIME_32 16777619
#define FNV_OFFSET_32 2166136261U

@implementation ChatMessageView

uint32_t FNV32(const char *s)
{
    uint32_t hash = FNV_OFFSET_32, i;
    for(i = 0; i < strlen(s); i++)
    {
        hash = hash ^ (s[i]); // xor next byte into the bottom of the hash
        hash = hash * FNV_PRIME_32; // Multiply by prime number found to work well
    }
    return hash;
}

- (NSArray *)userColors
{
    NSArray *colors = @[[UIColor colorWithRed:0 green:0.592 blue:0.863 alpha:1], /*#0097dc*/
                        [UIColor colorWithRed:0.929 green:0.004 blue:0.498 alpha:1], /*#ed017f*/
                        [UIColor colorWithRed:0.984 green:0.678 blue:0.094 alpha:1], /*#fbad18*/
                        [UIColor colorWithRed:0 green:0.678 blue:0.486 alpha:1], /*#00ad7c*/
                        [UIColor colorWithRed:0.541 green:0.588 blue:0.094 alpha:1], /*#8a9618*/
                        [UIColor colorWithRed:0.494 green:0.341 blue:0 alpha:1], /*#7e5700*/
                        [UIColor colorWithRed:0.153 green:0.349 blue:0.588 alpha:1], /*#275996*/
                        [UIColor colorWithRed:0.867 green:0.478 blue:0.486 alpha:1], /*#dd7a7c*/
                        [UIColor colorWithRed:0.463 green:0.282 blue:0.616 alpha:1], /*#76489d*/
                        [UIColor colorWithRed:0.953 green:0.443 blue:0.129 alpha:1], /*#f37121*/
                        [UIColor colorWithRed:0.808 green:0.596 blue:0.494 alpha:1], /*#ce987e*/
                        [UIColor colorWithRed:0.396 green:0.459 blue:0.522 alpha:1], /*#657585*/
                        [UIColor colorWithRed:0.435 green:0.761 blue:0.51 alpha:1], /*#6fc282*/
                        [UIColor colorWithRed:0.941 green:0.286 blue:0.243 alpha:1], /*#f0493e*/
                        [UIColor colorWithRed:0.725 green:0.369 blue:0.643 alpha:1], /*#b95ea4*/
                        [UIColor colorWithRed:0 green:0.365 blue:0.133 alpha:1], /*#005d22*/
                        [UIColor colorWithRed:0.749 green:0.286 blue:0.122 alpha:1], /*#bf491f*/
                        [UIColor colorWithRed:0.518 green:0.027 blue:0.082 alpha:1], /*#840715*/
                        [UIColor colorWithRed:0.02 green:0.141 blue:0.376 alpha:1], /*#052460*/
                        [UIColor colorWithRed:0.486 green:0.259 blue:0 alpha:1], /*#7c4200*/
                        [UIColor colorWithRed:0.761 green:0.529 blue:0.063 alpha:1], /*#c28710*/
                        [UIColor colorWithRed:0.353 green:0.333 blue:0.325 alpha:1], /*#5a5553*/
                        [UIColor colorWithRed:0.278 green:0 blue:0.329 alpha:1], /*#470054*/
                        [UIColor colorWithRed:0.843 green:0.702 blue:0.059 alpha:1], /*#d7b30f*/
                        [UIColor colorWithRed:0.573 green:0.784 blue:0.243 alpha:1], /*#92c83e*/
                        [UIColor colorWithRed:0.463 green:0.812 blue:0.906 alpha:1], /*#76cfe7*/
                        [UIColor colorWithRed:0.667 green:0.522 blue:0.647 alpha:1], /*#aa85a5*/
                        [UIColor colorWithRed:0.478 green:0.424 blue:0.325 alpha:1], /*#7a6c53*/
                        [UIColor colorWithRed:0.255 green:0.635 blue:0.682 alpha:1], /*#41a2ae*/
                        [UIColor colorWithRed:0.698 green:0.663 blue:0.655 alpha:1]]; /*#b2a9a7*/
    return colors;
}

- (UIColor *)colorForNick:(NSString *)nick
{
    return [self.userColors objectAtIndex:(int)floor(FNV32(nick.UTF8String) / 300000000)];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if(!self)
        return nil;
    
    [self.textLabel removeFromSuperview];
    
    self.backgroundColor = [UIColor clearColor];
    
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

- (NSAttributedString *)attributedString
{

    IRCUser *user = _message.sender;
    NSString *msg = _message.message;

    NSMutableAttributedString *string;
    
    switch(_message.messageType) {
        case ET_JOIN:
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ (%@@%@) %@",
                                                                        user.nick,
                                                                        user.username,
                                                                        user.hostname,
                                                                        NSLocalizedString(@"joined the channel", @"joined the channel")]];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:12.0]
                           range:NSMakeRange(0, user.nick.length)];
            break;
        case ET_PART:
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ (%@@%@) %@ (%@)",
                                                                        user.nick,
                                                                        user.username,
                                                                        user.hostname,
                                                                        NSLocalizedString(@"left the channel", @"joined the channel"),
                                                                        msg]];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:12.0]
                           range:NSMakeRange(0, user.nick.length)];
            break;
        case ET_ACTION:
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"*%@ %@",
                                                                        user.nick,
                                                                        msg]];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:12.0]
                           range:NSMakeRange(0, user.nick.length+2+msg.length)];
            break;
        case ET_PRIVMSG:
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", user.nick, msg]];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:16.0]
                           range:NSMakeRange(0,user.nick.length)];
            
            [string addAttribute:NSForegroundColorAttributeName
                           value:[self colorForNick:user.nick]
                           range:NSMakeRange(0, user.nick.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont systemFontOfSize:12.0]
                           range:NSMakeRange(user.nick.length+1, msg.length)];
            
            break;
            
    }
    return string;
}

- (void)layoutSubviews
{
    
    [super layoutSubviews];
    
    NSAttributedString *string = [self attributedString];
    
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
    
    
    if (_message.messageType == ET_PRIVMSG) {
        NSString *time = @"";
        if (_message.timestamp) {
            NSDate *date = _message.timestamp;
            NSDateFormatter *format = [[NSDateFormatter alloc] init];
            [format setDateFormat:@"HH:mm:ss"];
            time = [format stringFromDate:date];
        }
        
        NSMutableAttributedString *timestamp = [[NSMutableAttributedString alloc] initWithString:time];
        
        [timestamp addAttribute:NSFontAttributeName
                          value:[UIFont systemFontOfSize:12.0]
                          range:NSMakeRange(0, timestamp.length)];
        
        [timestamp addAttribute:NSForegroundColorAttributeName
                          value:[UIColor lightGrayColor]
                          range:NSMakeRange(0, timestamp.length)];
        
        textLayer = [[CATextLayer alloc] init];
        textLayer.string = timestamp;
        textLayer.backgroundColor = [UIColor clearColor].CGColor;
        [textLayer setForegroundColor:[[UIColor clearColor] CGColor]];
        [textLayer setContentsScale:[[UIScreen mainScreen] scale]];
        [textLayer setRasterizationScale:[[UIScreen mainScreen] scale]];
        textLayer.wrapped = YES;
        textLayer.frame = CGRectMake(self.bounds.size.width-timestamp.size.width-5, 5, timestamp.size.width, timestamp.size.height);
        [self.contentView.layer addSublayer:textLayer];
        
        self.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    }
    
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, size.height+10);
    
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
    NSAttributedString *string = [self attributedString];
    CGSize size = [self frameSizeForString:string];
    return size.height;
}

@end

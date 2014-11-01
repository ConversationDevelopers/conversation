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

#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "ChatMessageView.h"
#import <DLImageLoader/DLImageView.h>
#import <YLGIFImage/YLGIFImage.h>
#import <YLGIFImage/YLImageView.h>
#import "LinkTapView.h"
#import "NSString+Methods.h"

#define FNV_PRIME_32 16777619
#define FNV_OFFSET_32 2166136261U

@implementation ChatMessageView

- (id)initWithFrame:(CGRect)frame message:(IRCMessage *)message conversation:(IRCConversation *)conversation
{
    self = [super initWithFrame:frame];
    
    if(!self)
        return nil;
    
    _images = [[NSMutableArray alloc] init];
    _message = message;
    _conversation = conversation;
    
    self.backgroundColor = [UIColor clearColor];
    _attributedString = [self attributedString];
    _size = [self frameSize];
    
    _messageLayer = [CATextLayer layer];
    _messageLayer.backgroundColor = [UIColor clearColor].CGColor;
    _messageLayer.foregroundColor = [[UIColor clearColor] CGColor];
    _messageLayer.contentsScale = [[UIScreen mainScreen] scale];
    _messageLayer.rasterizationScale = [[UIScreen mainScreen] scale];
    _messageLayer.wrapped = YES;

    _timeLayer = [CATextLayer layer];
    _timeLayer.backgroundColor = [UIColor clearColor].CGColor;
    _timeLayer.foregroundColor = [[UIColor clearColor] CGColor];
    _timeLayer.contentsScale = [[UIScreen mainScreen] scale];
    _timeLayer.rasterizationScale = [[UIScreen mainScreen] scale];
    _timeLayer.wrapped = YES;
    
    [self.layer addSublayer:_messageLayer];
    [self.layer addSublayer:_timeLayer];
    
    int i=0;
    for (NSURL *url in _images) {
        DLImageView *imageView = [[DLImageView alloc] initWithFrame:CGRectMake(20, _size.height+10, 200, 120)];
        imageView.tag = i;
        imageView.layer.cornerRadius = 5;
        imageView.backgroundColor = [UIColor blackColor];
        imageView.userInteractionEnabled = YES;
        [imageView displayImageFromUrl:url.absoluteString];
        _size.height += 130;
        [self addSubview:imageView];

        UITapGestureRecognizer *singleTapRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showImage:)];
        [singleTapRecogniser setDelegate:self];
        singleTapRecogniser.numberOfTouchesRequired = 1;
        singleTapRecogniser.numberOfTapsRequired = 1;
        [imageView addGestureRecognizer:singleTapRecogniser];
        i++;
    }

    UITapGestureRecognizer *singleTapRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [singleTapRecogniser setDelegate:self];
    singleTapRecogniser.numberOfTouchesRequired = 1;
    singleTapRecogniser.numberOfTapsRequired = 1;
    [self addGestureRecognizer:singleTapRecogniser];
    
    return self;
}

- (NSURL *)getImageLink:(NSURL *)url
{
    if ([url.host isEqualToString:@"dropbox.com"] || [url.host isEqualToString:@"www.dropbox.com"]) {
        return [NSURL URLWithString:
                [[NSString stringWithFormat:@"%@://%@%@?dl=1", url.scheme, url.host, url.path] stringByAddingPercentEscapesUsingEncoding:NSASCIIStringEncoding]];
    }
    return url;
}

- (BOOL)isImageLink:(NSURL *)url
{
    if ([url.pathExtension isEqualToString:@"png"] ||
        [url.pathExtension isEqualToString:@"jpg"] ||
        [url.pathExtension isEqualToString:@"jpeg"] ||
        [url.pathExtension isEqualToString:@"tiff"] ||
        [url.pathExtension isEqualToString:@"gif"]) {
        return YES;
    }
    return NO;
}

- (void)layoutSubviews
{
    _messageLayer.string = _attributedString;
    
    _messageLayer.frame = CGRectMake(10, 5, self.bounds.size.width-20, _size.height);
    
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
        
        _timeLayer.string = timestamp;
        _timeLayer.frame = CGRectMake(self.bounds.size.width-timestamp.size.width-5, 5, timestamp.size.width, timestamp.size.height);
        self.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    }
    
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, _size.height+10);
    
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)_attributedString);
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL,
                  CGRectMake(0, 0,
                             self.bounds.size.width,
                             self.bounds.size.height));
    
    CTFrameRef frameref = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
    
    NSArray* lines = (NSArray*)CTFrameGetLines(frameref);
    CFIndex lineCount = [lines count];
    
    // Get the origin point of each of the lines
    CGPoint origins[lineCount];
    CTFrameGetLineOrigins(frameref, CFRangeMake(0, 0), origins);
    
    for(CFIndex idx = 0; idx < lineCount; idx++)
    {
        // For each line, get the bounds for the line
        CTLineRef line = CFArrayGetValueAtIndex((CFArrayRef)lines, idx);
        
        // Go through the glyph runs in the line
        CFArrayRef glyphRuns = CTLineGetGlyphRuns(line);
        CFIndex glyphCount = CFArrayGetCount(glyphRuns);
        for (int i = 0; i < glyphCount; ++i)    {
            CTRunRef run = CFArrayGetValueAtIndex(glyphRuns, i);
            
            NSDictionary *attributes = (NSDictionary*)CTRunGetAttributes(run);
            
            if ([attributes objectForKey:@"NSLink"]){
                CGRect runBounds;
                
                CGFloat ascent;//height above the baseline
                CGFloat descent;//height below the baseline
                runBounds.size.width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, NULL);
                runBounds.size.height = ascent + descent;
                
                // The bounds returned by the Core Text function are in the coordinate system used by Core Text.  Convert the values here into the coordinate system which our gesture recognizers will use.
                runBounds.origin.x = CTLineGetOffsetForStringIndex(line, CTRunGetStringRange(run).location, NULL) + 10.0;
                runBounds.origin.y = self.frame.size.height - origins[idx].y - runBounds.size.height + 10.0;
                
                // Create a view which will open up the URL when the user taps on it
                LinkTapView *linkTapView = [[LinkTapView alloc] initWithFrame:runBounds url:[attributes objectForKey:@"NSLink"]];
                linkTapView.backgroundColor = [UIColor clearColor];
                [self addSubview:linkTapView];
            }
        }
    }
}

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

- (char *)characterForStatus:(NSInteger)status
{
    switch(status) {
        case VOICE:
            return _conversation.client.voiceUserModeCharacter;
            break;
        case HALFOP:
            return _conversation.client.halfopUserModeCharacter;
            break;
        case OPERATOR:
            return _conversation.client.operatorUserModeCharacter;
            break;
        case ADMIN:
            return _conversation.client.adminUserModeCharacter;
            break;
        case OWNER:
            return _conversation.client.ownerUserModeCharacter;
            break;
        case IRCOP:
            return _conversation.client.ircopUserModeCharacter;
            break;
    }
    return "";
}

- (UIColor *)colorForNick:(NSString *)nick
{
    return [self.userColors objectAtIndex:(int)floor(FNV32(nick.UTF8String) / 300000000)];
}

- (NSAttributedString *)setLinks:(NSString *)string
{
    NSMutableArray *ranges = [[NSMutableArray alloc] init];
    NSMutableArray *offsets = [[NSMutableArray alloc] init];
    NSMutableArray *links = [[NSMutableArray alloc] init];
    NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
    NSArray *matches = [detector matchesInString:string options:0 range:NSMakeRange(0, [string length])];
    for (NSTextCheckingResult *match in matches) {
        NSRange matchRange = [match range];
        NSURL *url = [match URL];
        NSString *replace = [[NSString stringWithString:url.absoluteString] stringByTruncatingToWidth:250.0
                                                                                       withAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0]}];
        
        string = [string stringByReplacingOccurrencesOfString:url.absoluteString withString:replace];
        [ranges addObject:[NSValue valueWithRange:NSMakeRange(matchRange.location, replace.length)]];
        [offsets addObject:[NSNumber numberWithInteger:url.absoluteString.length-replace.length]];
        [links addObject:url];

        if ([self isImageLink:url])
            [_images addObject:[self getImageLink:url]];
    }

    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:string];

    int offset = 0;
    for (int i=0; i<ranges.count; i++) {
        NSRange range = [ranges[i] rangeValue];
        [attributedString addAttribute:NSLinkAttributeName value:links[i] range:NSMakeRange(range.location-offset, range.length)];
        [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:NSMakeRange(range.location-offset, range.length)];
        offset += [offsets[i] intValue];
    }

    return attributedString;
    
}

- (NSAttributedString *)attributedString
{

    IRCUser *user = _message.sender;
    NSString *msg = _message.message;

    NSMutableAttributedString *string;
    NSString *status = [NSString stringWithFormat:@"%s", [self characterForStatus:user.channelPrivileges]];
    
    switch(_message.messageType) {
        case ET_JOIN: {
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ (%@@%@) %@",
                                                                        user.nick,
                                                                        user.username,
                                                                        user.hostname,
                                                                        NSLocalizedString(@"joined the channel", @"joined the channel")]];
            
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:12.0]
                           range:NSMakeRange(0, user.nick.length)];

            break;
        }
        case ET_PART: {
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ (%@@%@) %@ (%@)",
                                                                        user.nick,
                                                                        user.username,
                                                                        user.hostname,
                                                                        NSLocalizedString(@"left the channel", @"left the channel"),
                                                                        msg]];

            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:12.0]
                           range:NSMakeRange(0, user.nick.length)];
            break;
        }
        case ET_QUIT: {
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ (%@@%@) %@ (%@)",
                                                                        user.nick,
                                                                        user.username,
                                                                        user.hostname,
                                                                        NSLocalizedString(@"left IRC", @"left IRC"),
                                                                        msg]];
            
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:12.0]
                           range:NSMakeRange(0, user.nick.length)];
            break;
        }
        case ET_NICK: {
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ %@ %@",
                                                                        user.nick,
                                                                        NSLocalizedString(@"is now known as", @"is now known as"),
                                                                        msg]];
            
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:12.0]
                           range:NSMakeRange(string.length-msg.length, msg.length)];
            break;
        }
        case ET_ACTION: {
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"*%@ %@",
                                                                        user.nick,
                                                                        msg]];

            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:12.0]
                           range:NSMakeRange(0, user.nick.length+2+msg.length)];
            break;
        }
        case ET_NOTICE: {
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n%@", user.nick, msg]];

            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:16.0]
                           range:NSMakeRange(0, user.nick.length)];
            
            [string addAttribute:NSForegroundColorAttributeName
                           value:[self colorForNick:user.nick]
                           range:NSMakeRange(0, user.nick.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont systemFontOfSize:12.0]
                           range:NSMakeRange(user.nick.length+1, msg.length)];
            break;
        }
        case ET_PRIVMSG: {
            
            string = [[NSMutableAttributedString alloc] initWithAttributedString:[self setLinks:[NSString stringWithFormat:@"%@%@\n%@", status, user.nick, msg]]];

            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:16.0]
                           range:NSMakeRange(0, status.length+user.nick.length)];
            
            [string addAttribute:NSForegroundColorAttributeName
                           value:[self colorForNick:user.nick]
                           range:NSMakeRange(0, status.length+user.nick.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont systemFontOfSize:12.0]
                           range:NSMakeRange(status.length+user.nick.length+1, string.length-status.length-user.nick.length-1)];

            break;
        }
        default: {
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"Message not handled yet"]];
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            [string addAttribute:NSFontAttributeName
                           value:[UIFont systemFontOfSize:12.0]
                           range:NSMakeRange(0, string.length)];
            break;
        }
    }
    return string;
}

- (CGSize)frameSize
{
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString((CFAttributedStringRef)_attributedString);
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
    } while (offset < [_attributedString length]);
    
    CFRelease(typesetter);
    
    return CGSizeMake(width, ceil(y));
}

- (CGFloat)frameHeight
{
    return _size.height;
}

- (void)adjustAnchorPointForGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        UIView *piece = gestureRecognizer.view;
        CGPoint locationInView = [gestureRecognizer locationInView:piece];
        CGPoint locationInSuperview = [gestureRecognizer locationInView:piece.superview];
        
        piece.layer.anchorPoint = CGPointMake(locationInView.x / piece.bounds.size.width, locationInView.y / piece.bounds.size.height);
        piece.center = locationInSuperview;
    }
}

- (void)scaleImage:(UIPinchGestureRecognizer *)recognizer
{
    [self adjustAnchorPointForGestureRecognizer:recognizer];
    
    if ([recognizer state] == UIGestureRecognizerStateBegan || [recognizer state] == UIGestureRecognizerStateChanged) {
        [recognizer view].transform = CGAffineTransformScale([[recognizer view] transform], [recognizer scale], [recognizer scale]);
        [recognizer setScale:1];
    }
    if ([recognizer state] == UIGestureRecognizerStateEnded) {
        if (recognizer.view.frame.size.width < [[UIScreen mainScreen] bounds].size.width) {
            CGRect frame = recognizer.view.superview.frame;
            [UIView animateWithDuration:0.3 animations:^{
                recognizer.view.frame = frame;
            }];
        }
    }
}

- (void)hideImage:(UITapGestureRecognizer *)recognizer
{
    // Get absolute frame of preview image
    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    CGRect frame;
    for (int i=0; i < self.subviews.count; i++) {
        if ([NSStringFromClass([self.subviews[i] class]) isEqualToString:@"DLImageView"] && i == (int)recognizer.view.tag) {
            frame = [self.subviews[i] convertRect:[self.subviews[i] bounds] toView:controller.navigationController.view];
        }
    }
    [UIView animateWithDuration:0.6 animations:^{
        [recognizer.view setFrame:frame];
        _containerView.alpha = 0.0;
    } completion:^(BOOL finished){
        [recognizer.view removeFromSuperview];
        [_containerView removeFromSuperview];
    }];
}

- (void)showImage:(UITapGestureRecognizer *)recognizer
{
    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    UIImageView *preview = (UIImageView*)recognizer.view;
    
    CGRect startFrame = [preview convertRect:preview.bounds toView:controller.navigationController.view];
    CGRect endFrame = [[UIScreen mainScreen] bounds];
    
    if (!_containerView)
        _containerView = [[UIView alloc] initWithFrame:endFrame];
    _containerView.backgroundColor = [UIColor blackColor];
    _containerView.alpha = 0.0;
    
    UIImageView *imageView;
    NSURL *url = _images[recognizer.view.tag];
    if ([url.pathExtension isEqualToString:@"gif"]) {
        imageView = [[YLImageView alloc] initWithFrame:startFrame];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.userInteractionEnabled = YES;
        imageView.image = [YLGIFImage imageWithData:[NSData dataWithContentsOfURL:url]];
    } else {
        imageView = [[UIImageView alloc] initWithFrame:startFrame];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.userInteractionEnabled = YES;
        imageView.image = preview.image;
    }
    imageView.tag = recognizer.view.tag;
    [controller.navigationController.view addSubview:_containerView];
    [controller.navigationController.view addSubview:imageView];

    UITapGestureRecognizer *singleTapRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideImage:)];
    [singleTapRecogniser setDelegate:self];
    singleTapRecogniser.numberOfTouchesRequired = 1;
    singleTapRecogniser.numberOfTapsRequired = 1;
    [imageView addGestureRecognizer:singleTapRecogniser];
    
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(scaleImage:)];
    [pinchGesture setDelegate:self];
    [imageView addGestureRecognizer:pinchGesture];
    
    [UIView animateWithDuration:0.6 animations:^{
        _containerView.alpha = 1.0;
        imageView.frame = endFrame;
    }];

}

- (void)handleTap:(UITapGestureRecognizer *)recognizer
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Message", @"Message")
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:NSLocalizedString(@"Copy", @"Copy"), nil];
    [sheet setTag:-1];
    [sheet showInView:self];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0 && self.message.messageType == ET_PRIVMSG) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSString *status = [NSString stringWithFormat:@"%s", [self characterForStatus:self.message.sender.channelPrivileges]];
        NSString *pasteString = [NSString stringWithFormat:@"<%@%@> %@", status, self.message.sender.nick, self.message.message];
        [pasteboard setValue:pasteString forPasteboardType:@"public.plain-text"];
    }
}
@end

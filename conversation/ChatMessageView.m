
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

#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "ChatMessageView.h"
#import <DLImageLoader/DLImageView.h>
#import <YLGIFImage/YLGIFImage.h>
#import <YLGIFImage/YLImageView.h>
#import "LinkTapView.h"
#import "NSString+Methods.h"
#import "AppPreferences.h"
#import "IRCKickMessage.h"

#define FNV_PRIME_32 16777619
#define FNV_OFFSET_32 2166136261U

#define hasHighlight() (_conversation.client.currentUserOnConnection && [_message.message.lowercaseString rangeOfString:_conversation.client.currentUserOnConnection.nick.lowercaseString].location != NSNotFound)

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
    
    _controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    
    int i=0;
    for (NSURL *url in _images) {
        DLImageView *imageView = [[DLImageView alloc] initWithFrame:CGRectMake(20, _size.height+10, 200, 120)];
        imageView.tag = i;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.layer.cornerRadius = 5;
        imageView.backgroundColor = [UIColor blackColor];
        imageView.userInteractionEnabled = YES;
        
        if ([_controller.currentConversation isEqual:message.conversation])
            [imageView displayImageFromUrl:url.absoluteString];
        else
            imageView.image = nil;
            
        _size.height += 130;
        [self addSubview:imageView];

        UITapGestureRecognizer *singleTapRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showImage:)];
        [singleTapRecogniser setDelegate:self];
        singleTapRecogniser.numberOfTouchesRequired = 1;
        singleTapRecogniser.numberOfTapsRequired = 1;
        [imageView addGestureRecognizer:singleTapRecogniser];
        
        UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(shareImage:)];
        [imageView addGestureRecognizer:longPressRecognizer];
        i++;
    }

    UITapGestureRecognizer *singleTapRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [singleTapRecogniser setDelegate:self];
    singleTapRecogniser.numberOfTouchesRequired = 1;
    singleTapRecogniser.numberOfTapsRequired = 1;
    [self addGestureRecognizer:singleTapRecogniser];
    
    if (_message.messageType != ET_PRIVMSG &&
        _message.messageType != ET_NOTICE &&
        _message.messageType != ET_CTCP &&
        _message.messageType != ET_ACTION)
        
        self.userInteractionEnabled = NO;
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"userlistWillToggle"
                                                  object:nil];
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
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, _size.height+10);
    
    if (_message.messageType == ET_PRIVMSG) {
        NSString *time = @"";
        if (_message.timestamp) {
            NSDate *date = _message.timestamp;
            NSDateFormatter *format = [[NSDateFormatter alloc] init];
            [format setLocale:[NSLocale systemLocale]];
            [format setTimeStyle:NSDateFormatterShortStyle];
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

        // Set background color if not already set because of highlight
        if ([self.backgroundColor isEqual:[UIColor clearColor]])
            self.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
        
    } else {
        _messageLayer.frame = CGRectMake(10, 0, self.bounds.size.width-20, _size.height);
        self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, _size.height);
    }
    
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
                
                if (_message.messageType == ET_PRIVMSG || _message.messageType == ET_NOTICE)
                    runBounds.origin.y = self.frame.size.height - origins[idx].y - runBounds.size.height + 9.0;
                else
                    runBounds.origin.y = self.frame.size.height - origins[idx].y - runBounds.size.height + 3.0;
                
                LinkTapView *linkTapView;
                // Create a view which will open up the URL when the user taps on it
                if ([[attributes objectForKey:@"NSLink"] isKindOfClass:NSURL.class])
                    linkTapView = [[LinkTapView alloc] initWithFrame:runBounds url:[attributes objectForKey:@"NSLink"]];
                else {
                    linkTapView = [[LinkTapView alloc] initWithFrame:runBounds nick:[attributes objectForKey:@"NSLink"]];
                    linkTapView.conversation = self.message.conversation;
                }
                
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

- (NSString *)characterForStatus:(NSInteger)status
{
    switch(status) {
        case VOICE:
            return [_conversation.client.userModeCharacters objectForKey:@"v"];
            break;
        case HALFOP:
            return [_conversation.client.userModeCharacters objectForKey:@"h"];
            break;
        case OPERATOR:
            return [_conversation.client.userModeCharacters objectForKey:@"o"];
            break;
        case ADMIN:
            return [_conversation.client.userModeCharacters objectForKey:@"a"];
            break;
        case OWNER:
            return [_conversation.client.userModeCharacters objectForKey:@"q"];
            break;
        case IRCOP:
            return [_conversation.client.userModeCharacters objectForKey:@"y"];
            break;
    }
    return @"";
}

- (UIColor *)colorForNick:(NSString *)nick
{
    return [self.userColors objectAtIndex:(int)floor(FNV32(nick.UTF8String) / 300000000)];
}

- (NSArray *)getMentions:(NSString *)string
{
    IRCChannel *channel = (IRCChannel*)_conversation;

    if (!channel.users.count)
        return nil;
    
    NSMutableArray *ranges = [[NSMutableArray alloc] init];
    NSCharacterSet *wordBoundries = [[NSCharacterSet letterCharacterSet] invertedSet];
    NSError *error = NULL;
    for (IRCUser *user in channel.users) {
        
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:user.nick
                                                  options:NSRegularExpressionCaseInsensitive
                                                    error:&error];
        
        NSArray *matches = [regex matchesInString:string
                                          options:0
                                            range:NSMakeRange(0, string.length)];
        
        for (NSTextCheckingResult *match in matches) {
            NSRange range = [match range];
            if ((range.location == 0 || [[string substringWithRange:NSMakeRange(range.location-1, 1)] rangeOfCharacterFromSet:wordBoundries].location != NSNotFound) &&
                (range.location+range.length+1 > string.length || [[string substringWithRange:NSMakeRange(range.location+range.length, 1)] rangeOfCharacterFromSet:wordBoundries].location != NSNotFound)) {
                [ranges addObject:[NSValue valueWithRange:range]];
            }
        }
        
    }
    
    // Highlight?
    if (hasHighlight()) {
        self.backgroundColor = [UIColor colorWithRed:0.714 green:0.882 blue:0.675 alpha:1];
    }
    return ranges;
}

- (NSString *)setEmoticons:(NSString *)string
{
    NSDictionary *emoticons = [[AppPreferences sharedPrefs] getEmoticons];
    NSCharacterSet *wordBoundries = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    for (NSString *key in emoticons.allKeys) {
        NSRange range = [string rangeOfString:key];
        if (range.location != NSNotFound &&
            (range.location == 0 || [[string substringWithRange:NSMakeRange(range.location-1, 1)] rangeOfCharacterFromSet:wordBoundries].location != NSNotFound) &&
            (range.location+range.length+1 > string.length || [[string substringWithRange:NSMakeRange(range.location+range.length, 1)] rangeOfCharacterFromSet:wordBoundries].location != NSNotFound)) {
            string = [string stringByReplacingOccurrencesOfString:key withString:emoticons[key]];
        }

    }
    return string;
}

- (NSAttributedString *)setLinks:(NSString *)string
{
    NSMutableArray *ranges = [[NSMutableArray alloc] init];
    NSMutableArray *offsets = [[NSMutableArray alloc] init];
    NSMutableArray *links = [[NSMutableArray alloc] init];
    NSDataDetector* detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
    NSArray *matches = [detector matchesInString:string options:0 range:NSMakeRange(0, [string length])];
    NSString *newString = string;

    for (NSTextCheckingResult *match in matches) {
        NSRange matchRange = [match range];
        NSString *urlString = [string substringWithRange:matchRange];
        NSString *replace = [[NSString stringWithFormat:@"%@", urlString] stringByTruncatingToWidth:250.0
                                                                                       withAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0]}];
        
        // Tricky solution to avoid line breaks
        replace = [replace stringByReplacingOccurrencesOfString:@"/" withString:@"\u2060/\u2060"];
        replace = [replace stringByReplacingOccurrencesOfString:@"." withString:@"\u2060.\u2060"];
        replace = [replace stringByReplacingOccurrencesOfString:@"…" withString:@"\u2060…\u2060"];
        replace = [replace stringByReplacingOccurrencesOfString:@"-" withString:@"\u2060-\u2060"];
        replace = [replace stringByReplacingOccurrencesOfString:@"?" withString:@"\u2060?\u2060"];
        
        newString = [newString stringByReplacingOccurrencesOfString:urlString withString:replace];
        [ranges addObject:[NSValue valueWithRange:NSMakeRange(matchRange.location, replace.length)]];
        [offsets addObject:[NSNumber numberWithInteger:urlString.length-replace.length]];
        [links addObject:match.URL];

        BOOL enableImages = [[NSUserDefaults standardUserDefaults] boolForKey:@"inline_preference"];
        if (enableImages && _message.messageType == ET_PRIVMSG && [self isImageLink:match.URL])
            [_images addObject:[self getImageLink:match.URL]];
    }


    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:newString];

    int offset = 0;
    for (int i=0; i<ranges.count; i++) {
        NSRange range = [ranges[i] rangeValue];
        [attributedString addAttribute:NSLinkAttributeName value:links[i] range:NSMakeRange(range.location-offset, range.length)];
        [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:NSMakeRange(range.location-offset, range.length)];
        
        offset += [offsets[i] intValue];
    }
    
    // Search for mentions of channel names
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?<!\\S)[#&]\\w+(?!\\S)" options:NSRegularExpressionCaseInsensitive error:&error];
    [regex enumerateMatchesInString:string
                            options:NSMatchingReportCompletion
                              range:NSMakeRange(0, string.length)
                         usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                             NSURL *link = [NSURL URLWithString:[NSString stringWithFormat:@"irc://%@", [string substringWithRange:result.range]]];
                             [attributedString addAttribute:NSLinkAttributeName value:link range:result.range];
                             [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:result.range];
                         }];

    return attributedString;
    
}

- (NSAttributedString *)attributedString
{

    IRCUser *user = _message.sender;
    
    NSString *msg;
    BOOL enableEmoji = [[NSUserDefaults standardUserDefaults] boolForKey:@"emoji_preference"];
    if (enableEmoji)
        msg = [self setEmoticons:_message.message];
    else
        msg = _message.message;

    NSMutableAttributedString *string;
    NSString *status = [self characterForStatus:user.channelPrivilege];
    
    switch(_message.messageType) {
        case ET_JOIN: {

            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"→ %@ (%@@%@) %@",
                                                                        user.nick,
                                                                        user.username,
                                                                        user.hostname,
                                                                        NSLocalizedString(@"joined the channel", @"joined the channel")]];
            
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByCharWrapping;
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont systemFontOfSize:10.0]
                           range:NSMakeRange(0, string.length)];

            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];

            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:10.0]
                           range:NSMakeRange(0, user.nick.length + 2)];
            break;
        }
        case ET_PART: {
            
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"← %@ (%@@%@) %@ (%@)",
                                                                        user.nick,
                                                                        user.username,
                                                                        user.hostname,
                                                                        NSLocalizedString(@"left the channel", @"left the channel"),
                                                                        msg]];

            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByCharWrapping;
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont systemFontOfSize:10.0]
                           range:NSMakeRange(0, string.length)];

            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:10.0]
                           range:NSMakeRange(0, user.nick.length + 2)];
            break;
        }
        case ET_QUIT: {
            
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"← %@ (%@@%@) %@ (%@)",
                                                                        user.nick,
                                                                        user.username,
                                                                        user.hostname,
                                                                        NSLocalizedString(@"left IRC", @"left IRC"),
                                                                        msg]];
            
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByCharWrapping;
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont systemFontOfSize:10.0]
                           range:NSMakeRange(0, string.length)];

            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:10.0]
                           range:NSMakeRange(0, user.nick.length + 2)];
            break;
        }
        case ET_NICK: {
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"· %@ %@ %@",
                                                                        user.nick,
                                                                        NSLocalizedString(@"is now known as", @"is now known as"),
                                                                        msg]];
            
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont systemFontOfSize:10.0]
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:10.0]
                           range:NSMakeRange(0, user.nick.length + 2)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:10.0]
                           range:NSMakeRange(string.length-msg.length, msg.length)];
            break;
        }
        case ET_MODE: {
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"· %@ %@ %@",
                                                                        user.nick,
                                                                        NSLocalizedString(@"sets mode", @"sets mode"),
                                                                        msg]];
            
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont systemFontOfSize:10.0]
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:10.0]
                           range:NSMakeRange(0, user.nick.length + 2)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:10.0]
                           range:NSMakeRange(string.length-msg.length, msg.length)];
            break;
        }
        case ET_KICK: {

            IRCKickMessage *kickmsg = (IRCKickMessage *)_message;
            msg = [NSString stringWithFormat:NSLocalizedString(@"kick message", nil), kickmsg.sender.nick, kickmsg.kickedUser.nick, kickmsg.message];
            
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"← %@", msg]];

            NSRange range = [[string.string substringFromIndex:kickmsg.sender.nick.length + 2] rangeOfString:kickmsg.kickedUser.nick];
            
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont systemFontOfSize:10.0]
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSForegroundColorAttributeName
                           value:[UIColor redColor]
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:10.0]
                           range:NSMakeRange(0, kickmsg.sender.nick.length + 2)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:10.0]
                           range:NSMakeRange(range.location + kickmsg.sender.nick.length + 2, range.location)];
            

            break;
        }
        case ET_TOPIC: {

            string = [[NSMutableAttributedString alloc] initWithAttributedString:[self setLinks:[NSString stringWithFormat:@"%@ %@ %@",
                                                                        user.nick,
                                                                        NSLocalizedString(@"changed the topic to", @"changed the topic to"),
                                                                        msg]]];
            
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:12.0]
                           range:NSMakeRange(0, user.nick.length)];
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:12.0]
                           range:NSMakeRange(string.length-msg.length, msg.length)];
            
            break;
        }
        case ET_ACTION: {
            
            string = [[NSMutableAttributedString alloc] initWithAttributedString:[self setLinks:[[NSString alloc] initWithFormat:@"· %@ %@", user.nick, msg]]];

            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;

            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
 
            [string addAttribute:NSFontAttributeName
                           value:[UIFont boldSystemFontOfSize:12.0]
                           range:NSMakeRange(0, string.length)];
            
            [string addAttribute:NSForegroundColorAttributeName
                           value:[self colorForNick:user.nick]
                           range:NSMakeRange(0, string.length)];
            
            if ([_conversation isKindOfClass:[IRCChannel class]])
                [self getMentions:msg];
            
            break;
        }
        case ET_NOTICE: {
            
            string = [[NSMutableAttributedString alloc] initWithAttributedString:[self setLinks:[[NSString alloc] initWithFormat:@"%@\n%@", user.nick, msg]]];

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
            
            // Mark sender's nick so we can respond to tap actions
            [string addAttribute:NSLinkAttributeName
                           value:user.nick
                           range:NSMakeRange(0, status.length+user.nick.length)];
            
            break;
        }
        case ET_PRIVMSG: {
            
            string = [[NSMutableAttributedString alloc] initWithAttributedString:[self setLinks:[[NSString alloc] initWithFormat:@"%@%@\n%@", status, user.nick, msg]]];
            msg = [string.string substringFromIndex:status.length+user.nick.length+1];
            
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
            
            // Mark sender's nick so we can respond to tap actions
            [string addAttribute:NSLinkAttributeName
                           value:user.nick
                           range:NSMakeRange(0, status.length+user.nick.length)];

            if ([_conversation isKindOfClass:[IRCChannel class]]) {
                NSArray *mentions = [self getMentions:msg];
                for (NSValue *range in mentions) {
                    [string addAttribute:NSFontAttributeName
                                   value:[UIFont boldSystemFontOfSize:12.0]
                                   range:NSMakeRange(range.rangeValue.location+status.length+user.nick.length+1, range.rangeValue.length)];
                }
            }
            break;
        }
        case ET_CTCP: {
            
            string = [[NSMutableAttributedString alloc] initWithAttributedString:[self setLinks:[[NSString alloc] initWithFormat:@"%@%@\n%@", status, user.nick, msg]]];
            msg = [string.string substringFromIndex:status.length+user.nick.length+1];
            
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
                           value:[UIFont boldSystemFontOfSize:12.0]
                           range:NSMakeRange(status.length+user.nick.length+1, string.length-status.length-user.nick.length-1)];
            
            self.backgroundColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:1];
            
            if ([_conversation isKindOfClass:[IRCChannel class]]) {
                NSArray *mentions = [self getMentions:msg];
                for (NSValue *range in mentions) {
                    [string addAttribute:NSFontAttributeName
                                   value:[UIFont boldSystemFontOfSize:12.0]
                                   range:NSMakeRange(range.rangeValue.location+status.length+user.nick.length+1, range.rangeValue.length)];
                }
            }
            break;
        }
        case ET_ERROR: {
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"⚠ %@", msg]];
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            [string addAttribute:NSFontAttributeName
                           value:[UIFont systemFontOfSize:12.0]
                           range:NSMakeRange(0, string.length)];
            
            self.backgroundColor = [UIColor colorWithRed:0.941 green:0.796 blue:0.796 alpha:1]; /*#f0cbcb*/
            
            break;
            
        }
        default: {
            string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"Message not handled yet"]];
            NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
            
            [string addAttribute:NSFontAttributeName
                           value:[UIFont systemFontOfSize:10.0]
                           range:NSMakeRange(0, string.length)];

            [string addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
            [string addAttribute:NSFontAttributeName
                           value:[UIFont systemFontOfSize:10.0]
                           range:NSMakeRange(0, string.length)];
            
            break;
        }
    }
    
    return string;
}

- (CGSize)frameSize
{
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString((CFAttributedStringRef)_attributedString);
    
    CGFloat width = self.bounds.size.width - 20.0;
    
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
        if (recognizer.view.frame.size.width < [[UIScreen mainScreen] bounds].size.width ||
            recognizer.view.frame.origin.x + recognizer.view.frame.size.width < _containerView.frame.size.width ||
            recognizer.view.frame.origin.y + recognizer.view.frame.size.height < _containerView.frame.size.height){
            
            CGRect frame = recognizer.view.superview.frame;
            [UIView animateWithDuration:0.3 animations:^{
                recognizer.view.frame = frame;
            }];
        }
    }

}

- (void)panImage:(UIPanGestureRecognizer *)recognizer
{
    CGPoint translation = [recognizer translationInView:_containerView];
    
    if (recognizer.view.frame.origin.x + translation.x > 0 ||
        recognizer.view.frame.origin.y + translation.y > 0 ||
        recognizer.view.frame.origin.x + recognizer.view.frame.size.width < _containerView.frame.size.width ||
        recognizer.view.frame.origin.y + recognizer.view.frame.size.height < _containerView.frame.size.height) {
        return;
    }
    
    recognizer.view.center = CGPointMake(recognizer.view.center.x + translation.x,
                                         recognizer.view.center.y + translation.y);
    [recognizer setTranslation:CGPointMake(0, 0) inView:_containerView];

}

- (void)shareImage:(UILongPressGestureRecognizer *)recognizer
{
    UIImageView *imageView = (UIImageView *)recognizer.view;
    NSData *data = [NSData dataWithContentsOfURL:[_images objectAtIndex:imageView.tag]];
    UIActivityViewController *sharer = [[UIActivityViewController alloc] initWithActivityItems:@[data] applicationActivities:nil];
    [self.chatViewController.navigationController presentViewController:sharer animated:YES completion:nil];

}

- (void)hideImage:(UITapGestureRecognizer *)recognizer
{
    // Get absolute frame of preview image
    CGRect frame;
    CGFloat aspect = 0.0;
    UIImageView *view;
    for (int i=0; i < self.subviews.count; i++) {
        if ([NSStringFromClass([self.subviews[i] class]) isEqualToString:@"DLImageView"] && i == (int)recognizer.view.tag) {
            view = self.subviews[i];
            frame = [self.subviews[i] convertRect:[self.subviews[i] bounds] toView:_controller.navigationController.view];
            aspect = view.image.size.height / view.image.size.width;
        }
    }
    
    if (aspect > 0) {
        frame.size.width = view.bounds.size.width;
        frame.size.height = view.bounds.size.width * aspect;
        frame.origin.y -= (frame.size.height - view.bounds.size.height) / 2;
    } else {
        frame.size.height = view.bounds.size.height;
        frame.size.width = view.bounds.size.height * aspect;
        frame.origin.x -= (frame.size.width - view.bounds.size.width) / 2;
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

    UIImageView *preview = (UIImageView*)recognizer.view;
    
    if (preview.image.size.width < 1)
        return;
    
    [_chatViewController hideAccessories:nil];
    
    CGRect frame = preview.bounds;
    
    CGFloat aspect = preview.image.size.height / preview.image.size.width;

    if (aspect > 0) {
        frame.size.width = preview.bounds.size.width;
        frame.size.height = preview.bounds.size.width * aspect;
        frame.origin.y -= (frame.size.height - preview.bounds.size.height) / 2;
    } else {
        frame.size.height = preview.bounds.size.height;
        frame.size.width = preview.bounds.size.height * aspect;
        frame.origin.x -= (frame.size.width - preview.bounds.size.width) / 2;
    }
    
    
    CGRect startFrame = [preview convertRect:frame toView:[self viewController].navigationController.view];
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
    
    [[[self viewController] navigationController].view addSubview:_containerView];
    [[[self viewController] navigationController].view addSubview:imageView];

    UITapGestureRecognizer *singleTapRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideImage:)];
    [singleTapRecogniser setDelegate:self];
    singleTapRecogniser.numberOfTouchesRequired = 1;
    singleTapRecogniser.numberOfTapsRequired = 1;
    [imageView addGestureRecognizer:singleTapRecogniser];
    
    UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(scaleImage:)];
    [pinchGesture setDelegate:self];
    [imageView addGestureRecognizer:pinchGesture];
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panImage:)];
    [panGesture setDelegate:self];
    [imageView addGestureRecognizer:panGesture];
    
    [UIView animateWithDuration:0.6 animations:^{
        _containerView.alpha = 1.0;
        imageView.frame = endFrame;
    }];

}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSString *status = [self characterForStatus:self.message.sender.channelPrivilege];
        NSString *pasteString;

        if (_message.messageType == ET_PRIVMSG)
            pasteString = [NSString stringWithFormat:@"<%@%@> %@", status, self.message.sender.nick, self.message.message];
        else
            pasteString = [NSString stringWithFormat:@"· %@ %@", self.message.sender.nick, self.message.message];
        
        [pasteboard setValue:pasteString forPasteboardType:@"public.plain-text"];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([gestureRecognizer.view isKindOfClass:self.class] && (_chatViewController.keyboardIsVisible || _chatViewController.userlistIsVisible)) {
        return NO;
    }
    return YES;
}

- (UIViewController *)viewController {
    Class vcc = [UIViewController class];
    UIResponder *responder = self;
    while ((responder = [responder nextResponder]))
        if ([responder isKindOfClass: vcc])
            return (UIViewController *)responder;
    
    return nil;
}


#pragma mark -
#pragma mark UITapGestureRecognizer delegate methods

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

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UIView *view = [[[event touchesForView:self] allObjects][0] view];
    view.backgroundColor = [UIColor lightGrayColor];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UIView *view = [[[event touchesForView:self] allObjects][0] view];
    
//    Highlight?
    if (hasHighlight()) {
        view.backgroundColor = [UIColor colorWithRed:0.714 green:0.882 blue:0.675 alpha:1];
        return;
    }
    
    if (_message.messageType == ET_ACTION) {
        view.backgroundColor = [UIColor clearColor];
        return;
    }
    
    view.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    UIView *view = [[[event touchesForView:self] allObjects][0] view];
    
//    Highlight?
    if (hasHighlight()) {
        view.backgroundColor = [UIColor colorWithRed:0.714 green:0.882 blue:0.675 alpha:1];
        return;
    }
    
    if (_message.messageType == ET_ACTION) {
        view.backgroundColor = [UIColor clearColor];
        return;
    }
    
    view.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
}
@end

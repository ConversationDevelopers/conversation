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

#import "UserStatusView.h"
#import "IRCUser.h"
#import "IRCClient.h"

@implementation UserStatusView

- (UIColor *)backgroundColor
{
    switch(self.status) {
        case VOICE:
            return [UIColor colorWithRed:0.867 green:0.773 blue:0.345 alpha:1]; /*#ddc558*/
        case HALFOP:
            return [UIColor colorWithRed:0.416 green:0.286 blue:0.471 alpha:1]; /*#6a4978*/
        case OPERATOR:
            return [UIColor colorWithRed:0.655 green:0.278 blue:0.278 alpha:1]; /*#a74747*/
        case ADMIN:
            return [UIColor colorWithRed:0.278 green:0.51 blue:0.655 alpha:1]; /*#4782a7*/
        case OWNER:
            return [UIColor colorWithRed:0.278 green:0.655 blue:0.51 alpha:1]; /*#47a782*/
        case IRCOP:
            return [UIColor colorWithRed:0.631 green:0.38 blue:0.588 alpha:1]; /*#a16196*/
    }
    return [UIColor clearColor];
}

- (char *)characterForStatus:(NSInteger)status
{
    switch(status) {
        case VOICE:
            return _client.voiceUserModeCharacter;
            break;
        case HALFOP:
            return _client.halfopUserModeCharacter;
            break;
        case OPERATOR:
            return _client.operatorUserModeCharacter;
            break;
        case ADMIN:
            return _client.adminUserModeCharacter;
            break;
        case OWNER:
            return _client.ownerUserModeCharacter;
            break;
        case IRCOP:
            return _client.ircopUserModeCharacter;
            break;
    }
    return "";
}

- (void)drawRect:(CGRect)rect
{
    CGPoint point;
    CGContextRef context = UIGraphicsGetCurrentContext();
    point.x = self.bounds.origin.x + self.bounds.size.width/2;
    point.y = self.bounds.origin.y + self.bounds.size.height/2;
    CGContextSetLineWidth(context, 5.0);
    [[self backgroundColor] setFill];
    UIGraphicsPushContext(context);
    CGContextBeginPath(context);
    CGContextAddArc(context, point.x, point.y, 12, 0, 2*M_PI, YES);
    CGContextFillPath(context);
    UIGraphicsPopContext();
}

- (void)layoutSubviews
{
    UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 1, self.bounds.size.width, self.bounds.size.height)];
    statusLabel.font = [UIFont fontWithName:@"Courier" size:18.0];
    statusLabel.textColor = [UIColor whiteColor];
    statusLabel.text = [NSString stringWithFormat:@"%s", [self characterForStatus:_status]];
    
    [self addSubview:statusLabel];
}


@end

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

#import "ConversationContentView.h"
#import "ChatMessageView.h"

@implementation ConversationContentView

- (void)addMessageView:(ChatMessageView *)messageView
{
    
    if(!_posY)
        _posY = 0.0;
    
    CGFloat height = messageView.frameHeight;
    messageView.frame = CGRectMake(0.0, _posY, messageView.frame.size.width, height);
    
    [self addSubview:messageView];
    [self layoutIfNeeded];
    
    if (messageView.message.messageType != ET_PRIVMSG && messageView.message.messageType != ET_ERROR)
        _posY += height + 5.0;
    else
        _posY += height + 15.0;
    
    // Increase content size if needed
    if (_posY > self.contentSize.height) {
        self.contentSize = CGSizeMake(self.frame.size.width, _posY);
    }
    
}

- (void)clear
{
    for (UIView *view in self.subviews) {
        if ([NSStringFromClass(view.class) isEqualToString:@"ChatMessageView"])
            [view removeFromSuperview];
    }
    _posY = 0.0;
}


@end

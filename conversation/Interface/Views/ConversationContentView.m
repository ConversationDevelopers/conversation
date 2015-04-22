/*
 Copyright (c) 2014-2015, Tobias Pollmann.
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

- (void)addMessage:(IRCMessage *)message
{

    if (message.messageType == ET_LIST || message.messageType == ET_LISTEND)
        return;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"hideevents_preference"] == YES &&
        (message.messageType == ET_JOIN || message.messageType == ET_PART || message.messageType == ET_QUIT ||
         message.messageType == ET_NICK || message.messageType == ET_KICK || message.messageType == ET_MODE)) {
            return;
        }
    
    ChatMessageView *messageView = [[ChatMessageView alloc] initWithFrame:CGRectMake(0, 0, message.conversation.contentView.frame.size.width, 15.0)
                                                                  message:message];
    messageView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    if(!_posY)
        _posY = 5.0;
    
    if (self.subviews.count > 500) {
        CGFloat posY = 0.0;
        for (ChatMessageView *view in self.subviews) {
            if ([NSStringFromClass(view.class) isEqualToString:@"ChatMessageView"]) {
                if (posY == 0.0) {
                    [view removeFromSuperview];
                    posY = 5.0;
                    continue;
                }
                CGFloat height = view.frameHeight;
                view.frame = CGRectMake(0.0, posY, messageView.frame.size.width, height);
                if (view.message.messageType != ET_PRIVMSG)
                    posY += height + 5.0;
                else
                    posY += height + 15.0;
            }
        }
        _posY = posY;
        self.contentSize = CGSizeMake(self.frame.size.width, _posY);
    }
    
    CGFloat height = messageView.frameHeight;
    messageView.frame = CGRectMake(0.0, _posY, messageView.frame.size.width, height);
    
    [self addSubview:messageView];
    [self layoutIfNeeded];
    
    if (messageView.message.messageType != ET_PRIVMSG)
        _posY += height + 5.0;
    else
        _posY += height + 15.0;
    
    // Increase content size if needed
    if (_posY > self.contentSize.height) {
        self.contentSize = CGSizeMake(self.frame.size.width, _posY);
    }
    
    // Scroll to bottom if content is bigger than view and user didnt scroll up
    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    if ([messageView.message.conversation isEqual:controller.currentConversation] &&
        self.contentSize.height > self.bounds.size.height) {
        
        CGFloat height = messageView.bounds.size.height;
        if (self.contentOffset.y + height + 100.0 > self.contentSize.height - self.bounds.size.height) {
            CGPoint bottomOffset = CGPointMake(0, _posY - self.frame.size.height);
            [self setContentOffset:bottomOffset animated:YES];
        }
    }
}

- (void)clear
{
    for (UIView *view in self.subviews) {
        if ([NSStringFromClass(view.class) isEqualToString:@"ChatMessageView"]) {
            ChatMessageView *messageView = (ChatMessageView*)view;
            [messageView removeFromSuperview];
        }
    }
    self.contentSize = self.frame.size;
    _posY = 0.0;

}


@end

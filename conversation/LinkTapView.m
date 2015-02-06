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

#import "LinkTapView.h"
#import "UserInfoViewController.h"
#import "InputCommands.h"
#import <UIActionSheet+Blocks/UIActionSheet+Blocks.h>

@implementation LinkTapView


- (id)initWithFrame:(CGRect)frame url:(NSURL *)url
{
    if (!(self = [super initWithFrame:frame]))
        return nil;
    self.url = url;
    self.alpha = 0.5;
    
    UITapGestureRecognizer *tapGesture =[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleLink:)];
    [self addGestureRecognizer:tapGesture];
    
    return self;
}

- (id)initWithFrame:(CGRect)frame nick:(NSString *)nick
{
    if (!(self = [super initWithFrame:frame]))
        return nil;
    self.nick = nick;
    self.alpha = 0.5;
    
    UITapGestureRecognizer *tapGesture =[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleNick:)];
    [self addGestureRecognizer:tapGesture];
    
    return self;
}

- (void)handleLink: (UITapGestureRecognizer*)sender  {
    
    [UIActionSheet showInView:self
                    withTitle:_url.absoluteString
            cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
       destructiveButtonTitle:nil
            otherButtonTitles:@[NSLocalizedString(@"Open", @"Open"), NSLocalizedString(@"Copy", @"Copy")]
                     tapBlock:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
                         if (buttonIndex == 0) {
                             UIApplication *application = [UIApplication sharedApplication];
                             if ([application canOpenURL:_url])   {
                                 [[UIApplication sharedApplication] openURL:_url];
                             } else {
                                 NSLog(@"Unable to open URL: %@", [_url absoluteString]);
                             }
                         } else if(buttonIndex == 1) {
                             UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                             [pasteboard setValue:_url.absoluteString forPasteboardType:@"public.plain-text"];
                         }
                         
                     }];
    

}

- (void)handleNick: (UITapGestureRecognizer*)sender  {

    __block ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    
    [UIActionSheet showInView:self.superview
                    withTitle:self.nick
            cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
       destructiveButtonTitle:nil
            otherButtonTitles:@[NSLocalizedString(@"Private Message (Query)", @"Query"),
                                NSLocalizedString(@"Get Info (Whois)", @"Whois"),
                                NSLocalizedString(@"Ignore", @"Ignore")]
     
                     tapBlock:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
                         switch (buttonIndex) {
                             case 0: {
                                 IRCConversation *conversation = [controller createConversationWithName:_nick onClient:_conversation.client];
                                 [controller.tableView reloadData];
                                 [controller.navigationController popToRootViewControllerAnimated:YES];
                                 [controller selectConversationWithIdentifier:conversation.configuration.uniqueIdentifier];
                                 break;
                             }
                             case 1: {
                                 UserInfoViewController *infoViewController = [[UserInfoViewController alloc] init];
                                 infoViewController.nickname = _nick;
                                 infoViewController.client = _conversation.client;
                                 UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:infoViewController];
                                 navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
                                 [controller.navigationController presentViewController:navigationController animated:YES completion:nil];
                                 break;
                             }
                             case 2:
                                 [InputCommands performCommand:[NSString stringWithFormat:@"IGNORE %@", _nick] inConversation:_conversation];
                                 break;
                             default:
                                 break;
                         }
                     }];


}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.backgroundColor = [UIColor darkGrayColor];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.backgroundColor = [UIColor clearColor];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.backgroundColor = [UIColor clearColor];
}

@end

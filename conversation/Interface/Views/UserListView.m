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

#import "UserListView.h"
#import "ILTranslucentView.h"
#import "../../Helpers/UITableView+Methods.m"
#import "IRCUser.h"
#import "UserListItemCell.h"
#import "UserInfoViewController.h"
#import <UIActionSheet+Blocks/UIActionSheet+Blocks.h>

@interface UserListView ()
@property (nonatomic) ILTranslucentView *translucentView;
@end

@implementation UserListView

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _translucentView = [[ILTranslucentView alloc] initWithFrame:self.bounds];
        _translucentView.translucentAlpha = 0.8;
        _translucentView.translucentStyle = UIBarStyleDefault;
        _translucentView.translucentTintColor = [UIColor whiteColor];
        _translucentView.backgroundColor = [UIColor clearColor];
        
        _tableview = [[UITableView alloc] initWithFrame:self.bounds style:UITableViewStylePlain];
        _tableview.backgroundColor = [UIColor clearColor];
        _tableview.delegate = self;
        _tableview.dataSource = self;
        
        [_translucentView addSubview:_tableview];
        [self addSubview:_translucentView];
        
    }
    
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _translucentView.frame = self.bounds;
    _tableview.frame = self.bounds;
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _channel.users.count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    NSString *identifier = [NSString stringWithFormat:@"%@%i", NSStringFromClass(UserListItemCell.class), (int)[_channel.users[indexPath.row] channelPrivilege]];
    UserListItemCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UserListItemCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
    }

    cell.user = _channel.users[indexPath.row];
    cell.client = _channel.client;
    
    return cell;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    IRCUser *user = _channel.users[indexPath.row];
    
    __block ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    
    [UIActionSheet showInView:self.superview
                    withTitle:user.nick
            cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
       destructiveButtonTitle:nil
            otherButtonTitles:@[NSLocalizedString(@"Private Message (Query)", @"Query"),
                                NSLocalizedString(@"Get Info (Whois)", @"Whois"),
                                NSLocalizedString(@"Ignore", @"Ignore")]
     
                     tapBlock:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
                         [self removeFromSuperview];
                         switch (buttonIndex) {
                             case 0: {
                                 IRCConversation *conversation = [controller createConversationWithName:[_channel.users[indexPath.row] nick] onClient:_channel.client];

                                 if(!actionSheet.isHidden)
                                     [controller dismissViewControllerAnimated:NO completion:nil];
                                 
                                 [controller.navigationController popToRootViewControllerAnimated:NO];
                                 [controller selectConversationWithIdentifier:conversation.configuration.uniqueIdentifier];
                                 break;
                             }
                             case 1: {
                                 UserInfoViewController *infoViewController = [[UserInfoViewController alloc] init];
                                 infoViewController.nickname = user.nick;
                                 infoViewController.client = _channel.client;
                                 UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:infoViewController];
                                 navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
                                 
                                 if(!controller.navigationController.presentedViewController.isBeingDismissed) {
                                     [controller dismissViewControllerAnimated:NO completion:nil];
                                 }
                                 
                                 [controller.navigationController presentViewController:navigationController animated:YES completion:nil];
                                 break;
                             }
                             case 2:
                                 [InputCommands performCommand:[NSString stringWithFormat:@"IGNORE %@", user.nick] inConversation:_channel];
                                 break;
                             default:
                                 break;
                         }
                     }];
}

@end

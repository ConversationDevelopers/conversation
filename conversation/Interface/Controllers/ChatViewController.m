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

#import "ChatViewController.h"
#import "ChatMessageView.h"
#import "IRCMessage.h"
#import "UserListView.h"
#import "InputCommands.h"
#import "ChannelInfoViewController.h"
#import "AppPreferences.h"
#import "ChannelListViewController.h"
#import "UserInfoViewController.h"
#import <UIActionSheet+Blocks/UIActionSheet+Blocks.h>
#import <ImgurAnonymousAPIClient/ImgurAnonymousAPIClient.h>
#import <DLImageLoader/DLImageView.h>
#import <MCNotificationManager/MCNotificationManager.h>

@interface ChatViewController ()
@property (readonly, nonatomic) PHFComposeBarView *composeBarView;
@property (readonly, nonatomic) UserListView *userListView;
@property (readonly, nonatomic) UIBarButtonItem *backButton;
@property (readonly, nonatomic) UIBarButtonItem *joinButton;
@property (readonly, nonatomic) UIBarButtonItem *userlistButton;
@property (nonatomic) NSMutableArray *suggestions;
@property (nonatomic) MenuPopOverView *popOver;

@end

CGRect kInitialViewFrame = { 0.0f, 0.0f, 320.0f, 480.0f };
BOOL popoverDidDismiss = NO;

#define IPAD UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad

@implementation ChatViewController

- (id)init
{
    if (!(self = [super init]))
        return nil;
    
    kInitialViewFrame = [[UIScreen mainScreen] bounds];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageReceived:)
                                                 name:@"messageReceived"
                                               object:nil];
    
    _backButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"ChannelIcon_Light"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack:)];
    
    _joinButton = [[UIBarButtonItem alloc] initWithTitle:@"Join" style:UIBarButtonItemStylePlain target:self action:@selector(join:)];
    
    _userlistButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Userlist"]
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(showUserList:)];

    self.navigationItem.leftBarButtonItem = _backButton;
    
    return self;
}

- (void)dealloc
{
 
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"messageReceived"
                                                  object:nil];
    
}

- (enum UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (void)loadView
{

    [super loadView];
    
    UIView *view = [[UIView alloc] initWithFrame:kInitialViewFrame];
    [view setBackgroundColor:[UIColor whiteColor]];

    UIView *container = [self container];
    [container addSubview:[self composeBarView]];
    
    [view addSubview:container];
    self.view = view;
    
    [self setEdgesForExtendedLayout:UIRectEdgeNone];
    
    [self setView:view];
    
    UITapGestureRecognizer *singleTapRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideAccessories:)];
    [singleTapRecogniser setDelegate:self];
    singleTapRecogniser.numberOfTouchesRequired = 1;
    singleTapRecogniser.numberOfTapsRequired = 1;
    [_container addGestureRecognizer:singleTapRecogniser];
    
    UIScreenEdgePanGestureRecognizer *swipeLeftRecognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(swipeToShowUserlist:)];
    [swipeLeftRecognizer setEdges:UIRectEdgeRight];
    [swipeLeftRecognizer setDelegate:self];
    [_container addGestureRecognizer:swipeLeftRecognizer];
    
    UISwipeGestureRecognizer *recognizer;
    recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeft:)];
    [recognizer setDirection:(UISwipeGestureRecognizerDirectionLeft)];
    [_container addGestureRecognizer:recognizer];
    
    recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRight:)];
    [recognizer setDirection:(UISwipeGestureRecognizerDirectionRight)];
    [_container addGestureRecognizer:recognizer];
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_isChannel && [(IRCChannel*)_conversation isJoinedByUser])
        self.navigationItem.rightBarButtonItem = _userlistButton;
    else if (_isChannel == NO) {
        self.navigationItem.rightBarButtonItem = nil;
    } else {
        self.navigationItem.rightBarButtonItem = _joinButton;
    }
    
    self.title = _conversation.name;
    
    // Clear container
    for (UIView *view in _container.subviews) {
        if ([NSStringFromClass(view.class) isEqualToString:@"ConversationContentView"]) {
            [view removeFromSuperview];
        }
    }
    
    // Not sure why but sometimes the view is higher as expected
    CGRect frame = CGRectMake(self.container.frame.origin.x,
                              self.container.frame.origin.y,
                              self.container.frame.size.width,
                              self.container.frame.size.height - _composeBarView.bounds.size.height);
    
    _conversation.contentView.frame = frame;
    [self.container addSubview:_conversation.contentView];
    [self.container sendSubviewToBack:_conversation.contentView];
    
    [self scrollToBottom:NO];

    // Load images
    int i=0;
    ChatMessageView *messageView;
    DLImageView *imageView;
    for (UIView *view in _conversation.contentView.subviews) {
        if ([NSStringFromClass(view.class) isEqualToString:@"ChatMessageView"]) {
            messageView = (ChatMessageView*)view;
            i=0;
            for (UIView *view2 in messageView.subviews) {
                if ([NSStringFromClass(view2.class) isEqualToString:@"DLImageView"]) {
                    imageView = (DLImageView*)view2;
                    [imageView displayImageFromUrl:[messageView.images[i] absoluteString]];
                    i++;
                }
            }
        }
    }

}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.navigationController.view layoutSubviews];
    
    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    controller.currentConversation = _conversation;
    
    double delayInSeconds = 2.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
        //[self.navigationController performSegueWithIdentifier:@"modal" sender:nil];
    });
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillToggle:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillToggle:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self hideUserList];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    // Unload images
    int i=0;
    ChatMessageView *messageView;
    DLImageView *imageView;
    for (UIView *view in _conversation.contentView.subviews) {
        if ([NSStringFromClass(view.class) isEqualToString:@"ChatMessageView"]) {
            messageView = (ChatMessageView*)view;
            i=0;
            for (UIView *view2 in messageView.subviews) {
                if ([NSStringFromClass(view2.class) isEqualToString:@"DLImageView"]) {
                    imageView = (DLImageView*)view2;
                    imageView.image = nil;
                    i++;
                }
            }
        }
    }
}

- (void)scrollToBottom:(BOOL)animated
{
    if (_conversation.contentView.contentSize.height > _conversation.contentView.bounds.size.height) {
        CGPoint bottomOffset = CGPointMake(0, _conversation.contentView.posY - _conversation.contentView.frame.size.height);
        [_conversation.contentView setContentOffset:bottomOffset animated:animated];
    }
}

- (void)join:(id)sender
{
    // Connect client if it isn't already connected
    if (_conversation.client.isConnected == NO) {
        [_conversation.client connect];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(join:)
                                                     name:@"clientDidConnect"
                                                   object:nil];
    } else {
        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
        [controller joinChannelWithName:_conversation.name onClient:_conversation.client];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:@"clientDidConnect"
                                                      object:nil];
    }

}

- (void)keyboardWillToggle:(NSNotification *)notification
{
    if (_userlistIsVisible)
        [_userListView removeFromSuperview];

    NSDictionary* userInfo = [notification userInfo];
    NSTimeInterval duration;
    UIViewAnimationCurve animationCurve;
    CGRect startFrame;
    CGRect endFrame;
    [[userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&duration];
    [[userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey]    getValue:&animationCurve];
    [[userInfo objectForKey:UIKeyboardFrameBeginUserInfoKey]        getValue:&startFrame];
    [[userInfo objectForKey:UIKeyboardFrameEndUserInfoKey]          getValue:&endFrame];
    
    NSInteger signCorrection = 1;
    if (startFrame.origin.y < 0 || startFrame.origin.x < 0 || endFrame.origin.y < 0 || endFrame.origin.x < 0)
        signCorrection = -1;
    
    CGFloat widthChange  = (endFrame.origin.x - startFrame.origin.x) * signCorrection;
    CGFloat heightChange = (endFrame.origin.y - startFrame.origin.y) * signCorrection;
    
    if (duration > 0.01) {
        if (heightChange < 0)
            _keyboardIsVisible = YES;
        else
            _keyboardIsVisible = NO;
    }
    
    CGFloat sizeChange = UIInterfaceOrientationIsLandscape([self interfaceOrientation]) ? widthChange : heightChange;
    
    // iOS 8
    if (sizeChange == 0.0)
        sizeChange = heightChange;
    

    CGRect newContainerFrame = [[self container] frame];
    newContainerFrame.size.height += sizeChange;
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];

    NSArray *vComp = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
    if ([[vComp objectAtIndex:0] intValue] >= 9) {
        // iOS9 or higher
        if (_keyboardIsVisible && self.container.frame.size.height < screenRect.size.height - (sizeChange*-1)) {
            return;
        }
    } else {
        if (_keyboardIsVisible && self.container.frame.size.height < screenRect.size.height - (sizeChange*-1) && endFrame.size.height == (sizeChange*-1)) {
            return;
        }
    }
    
    [UIView animateWithDuration:duration
                          delay:0
                        options:(animationCurve << 16)|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         [[self container] setFrame:newContainerFrame];
                     }
                     completion:NULL];
    [self scrollToBottom:NO];
}

- (void)goBack:(id)sender
{
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)showUserList:(id)sender
{
    _userlistIsVisible = YES;
    
    [_composeBarView resignFirstResponder];
    
    _userListView = [self userListView];
    
    _userListView.channel = (IRCChannel*)_conversation;
    [_userListView.tableview reloadData];

    CGRect frame = _userListView.frame;

    if (UIInterfaceOrientationIsLandscape([self interfaceOrientation])) {
        frame.size.height = self.view.bounds.size.height - 10.0;
        frame.origin.y = 5.0;
    } else {
        frame.size.height = _conversation.contentView.frame.size.height + 30.0;
        frame.origin.y = 30.0;
    }

    _userListView.frame = frame;

    [self.navigationController.view addSubview:_userListView];

    frame = _userListView.frame;
    frame.origin.x = _container.frame.size.width - 205.0f;
    
    [UIView animateWithDuration:0.5
                          delay:0.0
         usingSpringWithDamping:0.5
          initialSpringVelocity:0.3
                        options:0 animations:^{
                            _userListView.frame = frame;
                            //Animations
                        }
                     completion:nil];
    

}

- (void)composeBarViewDidPressButton:(PHFComposeBarView *)composeBarView
{
    UINavigationController *navigationController;
    
    if (self.isChannel) {
        ChannelInfoViewController *infoViewController = [[ChannelInfoViewController alloc] init];
        infoViewController.channel = (IRCChannel *)_conversation;
    
        navigationController = [[UINavigationController alloc]
                                                    initWithRootViewController:infoViewController];
    
    } else {
        UserInfoViewController *infoViewController = [[UserInfoViewController alloc] init];
        infoViewController.nickname = _conversation.name;
        infoViewController.client = _conversation.client;
        navigationController = [[UINavigationController alloc]
                                                        initWithRootViewController:infoViewController];
    }
    
    navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:navigationController animated:YES completion:^(void){
        [self hideAccessories:nil];
    }];
}

- (void)composeBarViewDidPressUtilityButton:(PHFComposeBarView *)composeBarView
{
    
    [self hideAccessories:nil];
    [UIActionSheet showInView:self.view
                    withTitle:NSLocalizedString(@"Photo Source", @"Photo Source")
            cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
       destructiveButtonTitle:nil
            otherButtonTitles:@[NSLocalizedString(@"Camera", @"Camera"), NSLocalizedString(@"Photo Library", @"Photo Library")]
                     tapBlock:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
                         if (buttonIndex == 0) {
                             UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
                             imagePicker.navigationBar.translucent = NO;
                             [imagePicker.view setFrame:CGRectMake(0, 80, 320, 350)];
                             [imagePicker setSourceType:UIImagePickerControllerSourceTypeCamera];
                             [imagePicker setDelegate:(id)self];
                             if(!self.navigationController.presentedViewController.isBeingDismissed) {
                                 [self dismissViewControllerAnimated:NO completion:nil];
                             }
                             [self presentViewController:imagePicker animated:YES completion:nil];
                         } else if(buttonIndex == 1) {
                             UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
                             imagePicker.navigationBar.translucent = NO;                             
                             [imagePicker.view setFrame:CGRectMake(0, 80, 320, 350)];
                             [imagePicker setSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
                             [imagePicker setDelegate:(id)self];
                             if(!self.navigationController.presentedViewController.isBeingDismissed) {
                                 [self dismissViewControllerAnimated:NO completion:nil];
                             }
                             [self presentViewController:imagePicker animated:YES completion:nil];
                         }

                     }];
    
}

- (void)sendMessage:(NSString *)message
{
    if ([message hasPrefix:@"/"])
        [InputCommands performCommand:[message substringFromIndex:1] inConversation:_conversation];
    else
        [InputCommands sendMessage:message toRecipient:_conversation.name onClient:_conversation.client];
    
    [_popOver removeFromSuperview];
    [_composeBarView setText:@"" animated:YES];

}

- (void)textViewDidChange:(UITextView *)textView
{
    if (textView.text.length == 0) {
        [_popOver removeFromSuperview];
        _popOver = nil;
        popoverDidDismiss = NO;
        return;
    }
    
    if ([[textView.text substringFromIndex:textView.text.length-1] isEqualToString:@" "])
        // Last character was a space so reset popover state
        popoverDidDismiss = NO;
    
    if (popoverDidDismiss)
        return;

    [_popOver removeFromSuperview];
    _popOver = [[MenuPopOverView alloc] init];
    _popOver.delegate = self;
    
    // Initialise suggestions array
    if (!_suggestions)
        _suggestions = [[NSMutableArray alloc] init];
    else
        [_suggestions removeAllObjects];
    
    // Commands
    if ([[textView.text substringToIndex:1] isEqualToString:@"/"] && [textView.text rangeOfString:@" "].location == NSNotFound) {
        NSString *searchString = [textView.text substringFromIndex:1];
        for (NSString *command in [InputCommands inputCommandReference]) {
            if ([[command lowercaseString] hasPrefix:[searchString lowercaseString]]) {
                [_suggestions addObject:[command lowercaseString]];
            }
        }
        
        if (_suggestions.count > 0) {
            float offset = 10.0;
            if(self.container.frame.size.height - self.composeBarView.frame.origin.y > 10.0 || UIInterfaceOrientationIsLandscape([self interfaceOrientation]))
                offset = -20.0;
            CGRect frame = CGRectMake(60.0, self.composeBarView.frame.origin.y + offset, 0.0, 0.0);
            [_popOver presentPopoverFromRect:frame inView:self.view withStrings:_suggestions];
        }
        return;
    }
    
    NSArray *args = [textView.text componentsSeparatedByString:@" "];
    NSString *string = args[args.count-1];
    
    if (string.length > 0) {
        // Channels
        if ([string hasPrefix:@"#"]) {
            IRCClient *client = _conversation.client;
            for (IRCChannel *channel in [client.channels copy])
                if([[channel.name lowercaseString] hasPrefix:[string lowercaseString]])
                    [_suggestions addObject:channel.name];
            
        } else {
            // Users
            if (_isChannel && _conversation.client.isConnectedAndCompleted) {
                IRCChannel *channel = (IRCChannel *)_conversation;
                for (IRCUser *user in [channel.users copy])
                    if([[user.nick lowercaseString] hasPrefix:[string lowercaseString]]) {
                        if (args.count == 1)
                            [_suggestions addObject:[NSString stringWithFormat:@"%@:", user.nick]];
                        else
                            [_suggestions addObject:user.nick];
                    }
            }
        }
        
        if (_suggestions.count > 0) {
            float offset = 10.0;
            if(self.container.frame.size.height - self.composeBarView.frame.origin.y > 10.0 || UIInterfaceOrientationIsLandscape([self interfaceOrientation]))
                offset = -20.0;
            CGRect frame = CGRectMake(60.0, self.composeBarView.frame.origin.y + offset, 0.0, 0.0);
            [_popOver presentPopoverFromRect:frame inView:self.view withStrings:_suggestions];
            return;
        }
    }
    
    if (_popOver.superview) {
        [_popOver removeFromSuperview];
        _popOver = nil;
    }

}

- (BOOL) textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    
    if([text isEqualToString:@"\n"]){
        [self sendMessage:textView.text];
        return NO;
    }else{
        return YES;
    }
}

- (BOOL)hideUserList
{
    if (_userlistIsVisible) {
        
        _userlistIsVisible = NO;
        
        CGRect frame = _userListView.frame;
        frame.origin.x = _container.frame.size.width;
        _userListView.frame = frame;
        
        [_userListView removeFromSuperview];
        
        return YES;
    }
    return NO;
}

- (void)hideAccessories:(UIGestureRecognizer*)sender
{
    if ([self hideUserList])
        return;
    [_composeBarView resignFirstResponder];
}

- (void)messageReceived:(NSNotification *)notification
{
    IRCMessage *message = notification.object;
    if ([message.conversation.configuration.uniqueIdentifier isEqualToString:_conversation.configuration.uniqueIdentifier] == NO)
        return;
    
    if (_isChannel &&
        [(IRCChannel*)_conversation isJoinedByUser] &&
        message.messageType == ET_JOIN &&
        [message.sender.nick isEqualToString:_conversation.client.currentUserOnConnection.nick]) {
        
        UIBarButtonItem *userlistButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Userlist"]
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(showUserList:)];
        self.navigationItem.rightBarButtonItem = userlistButton;
        
    }
    
    if (_userlistIsVisible && (message.messageType == ET_JOIN ||
                               message.messageType == ET_PART ||
                               message.messageType == ET_NICK ||
                               message.messageType == ET_QUIT ||
                               message.messageType == ET_KICK ||
                               message.messageType == ET_KICK)) {

        [self.userListView.tableview reloadData];
    }
    
    if (message.messageType == ET_AWAY)
        [self.userListView.tableview reloadData];
    
}

- (void)swipeLeft:(UISwipeGestureRecognizer *)recognizer
{
    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    IRCConversation *conversation;

    _isChannel = YES;
    
    int i=0;
    for (IRCConversation *convo in _conversation.client.channels) {
        if ([convo isEqual:_conversation]) {
            if (_conversation.client.channels.count-1 > i)
                conversation = _conversation.client.channels[i+1];
            
            if (_conversation.client.channels.count-1 == i) {
                
                if (_conversation.client.queries.count > 0) {
                    conversation = _conversation.client.queries[0];
                    _isChannel = NO;
                } else {
                    conversation = _conversation.client.channels[0];
                }
            }
            
            break;
        }
        i++;
    }
    
    i = 0;
    if (conversation == nil) {
        for (IRCConversation *convo in _conversation.client.queries) {
            if ([convo isEqual:_conversation]) {
                if (_conversation.client.queries.count-1 > i) {
                    conversation = _conversation.client.queries[i+1];
                    _isChannel = NO;
                }
                
                if (i == _conversation.client.queries.count-1) {
                    if (_conversation.client.channels.count > 0) {
                        conversation = _conversation.client.channels[0];
                    } else {
                        _isChannel = NO;
                        conversation = _conversation.client.queries[_conversation.client.channels.count-1];
                    }
                }
                
                break;
            }
            i++;
        }
    }
    
    if (_isChannel) {
        self.conversation = (IRCChannel*)conversation;
        controller.currentConversation = (IRCChannel*)conversation;
    } else {
        self.conversation = conversation;
        controller.currentConversation = conversation;
    }
    
    [self viewWillDisappear:NO];
    [self viewWillAppear:NO];
    [self viewDidAppear:NO];
    
}

- (void)swipeRight:(UISwipeGestureRecognizer *)recognizer
{
    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    IRCConversation *conversation;
    
    _isChannel = YES;
    
    int i=0;
    for (IRCConversation *convo in _conversation.client.channels) {
        if ([convo isEqual:_conversation]) {

            if (i > 0 && _conversation.client.channels.count > 1)
                conversation = _conversation.client.channels[i-1];
            
            if (i == 0) {
                if (_conversation.client.queries.count > 0) {
                    _isChannel = NO;
                    conversation = _conversation.client.queries[_conversation.client.queries.count-1];
                } else  {
                    conversation = _conversation.client.channels[_conversation.client.channels.count-1];
                }
            }
            
            break;
        }
        i++;
    }
    
    i = 0;
    if (conversation == nil) {
        for (IRCConversation *convo in _conversation.client.queries) {
            if ([convo isEqual:_conversation]) {

                if (i > 0 && _conversation.client.queries.count > 1) {
                    _isChannel = NO;
                    conversation = _conversation.client.queries[i-1];
                }

                if (i == 0) {
                    if (_conversation.client.channels.count > 0) {
                        conversation = _conversation.client.channels[_conversation.client.channels.count-1];
                    } else {
                        _isChannel = NO;
                        conversation = _conversation.client.queries[_conversation.client.channels.count-1];
                    }
                }
                
                break;
            }
            i++;
        }
    }
    
    if (_isChannel) {
        self.conversation = (IRCChannel*)conversation;
        controller.currentConversation = (IRCChannel*)conversation;
    } else {
        self.conversation = conversation;
        controller.currentConversation = conversation;
    }
    
    [self viewWillDisappear:NO];    
    [self viewWillAppear:NO];
    [self viewDidAppear:NO];
}

- (void)swipeToShowUserlist:(UIScreenEdgePanGestureRecognizer *)recognizer
{
    
    if ([_conversation isKindOfClass:[IRCChannel class]] == NO) {
        return;
    }
    
    UserListView *userlist = [self userListView];
    userlist.channel = (IRCChannel*)_conversation;
    [userlist.tableview reloadData];
    
    [_composeBarView resignFirstResponder];
    
    CGFloat progress = [recognizer translationInView:_conversation.contentView].x;

    __block CGRect frame = userlist.frame;
    
    if (UIInterfaceOrientationIsLandscape([self interfaceOrientation])) {
        frame.size.height = self.view.bounds.size.height - 10.0;
        frame.origin.y = 5.0;
    } else {
        frame.size.height = _conversation.contentView.frame.size.height + 30.0;
        frame.origin.y = 30.0;
    }
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [self.navigationController.view addSubview:userlist];
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        if (frame.origin.x >= _container.frame.size.width - 205.0)
            frame.origin.x = _container.frame.size.width + progress;
    } else if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
        // Finish or cancel the interactive transition
        if (frame.origin.x < _container.frame.size.width - 100) {
            [UIView animateWithDuration:0.5 animations:^{
                frame.origin.x = _container.frame.size.width - 205.0;
            } completion:^(BOOL finished) {
                _userlistIsVisible = YES;
            }];
        }
        else {
            [UIView animateWithDuration:0.5 animations:^{
                frame.origin.x = _container.frame.size.width;
            } completion:^(BOOL finished) {
                [userlist removeFromSuperview];
            }];
        }
    }
    userlist.frame = frame;
        
}

- (void)updateJoinStatus
{
    if ([(IRCChannel*)_conversation isJoinedByUser]) {
        self.navigationItem.rightBarButtonItem = _userlistButton;
    } else {
        self.navigationItem.rightBarButtonItem = _joinButton;
    }
}

@synthesize container = _container;
- (UIView *)container {
    if (!_container) {
        _container = [[UIScrollView alloc] initWithFrame:kInitialViewFrame];
        _container.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    }
    
    return _container;
}

@synthesize composeBarView = _composeBarView;
- (PHFComposeBarView *)composeBarView {
    
    if (!_composeBarView) {
        CGRect frame = CGRectMake(0.0f,
                                  kInitialViewFrame.size.height - PHFComposeBarViewInitialHeight,
                                  kInitialViewFrame.size.width,
                                  PHFComposeBarViewInitialHeight);
        
        _composeBarView = [[PHFComposeBarView alloc] initWithFrame:frame];
        [_composeBarView setButtonTitle:nil];
        [_composeBarView setButtonTintColor:[UIColor blackColor]];
        [_composeBarView setMaxLinesCount:5];
        [_composeBarView setPlaceholder:@"Type something..."];
        [_composeBarView setUtilityButtonImage:[UIImage imageNamed:@"Camera"]];
        [_composeBarView setDelegate:self];
        [_composeBarView setEnabled:YES];
        [[_composeBarView textView] setReturnKeyType:UIReturnKeySend];
    }
    return _composeBarView;
}

@synthesize userListView = _userListView;
- (UserListView *)userListView {
    
    if (!_userListView) {
        CGFloat width = 200.0f;
        CGRect frame = CGRectMake(_container.frame.size.width,
                                  30.0f,
                                  width,
                                  _conversation.contentView.frame.size.height + 30.0);
        
        _userListView = [[UserListView alloc] initWithFrame:frame];
        _userListView.backgroundColor = [UIColor clearColor];
    }
    return _userListView;
}


#pragma mark - Delegate Methods

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:^{
        [_composeBarView becomeFirstResponder];        
    }];
    
    UIButton *cameraButton = [_composeBarView utilityButton];
    cameraButton.hidden = YES;
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    indicator.frame = _composeBarView.utilityButton.frame;
    [indicator setHidesWhenStopped:YES];
    [indicator startAnimating];
    [_composeBarView addSubview:indicator];

    if (picker.sourceType == UIImagePickerControllerSourceTypeCamera) {
        [[ImgurAnonymousAPIClient client] uploadImage:info[UIImagePickerControllerOriginalImage] withFilename:nil completionHandler:^(NSURL *imgurURL, NSError *error) {
            if(error)
                NSLog(@"Error while uploading image: %@", error.description);
            NSString *string;
            if ([_composeBarView.text isEqualToString:@""] == NO)
                string = [[_composeBarView text] stringByAppendingFormat:@" %@", imgurURL.absoluteString];
            else
                string = imgurURL.absoluteString;
            [_composeBarView setText:string];
            [indicator stopAnimating];
            [indicator removeFromSuperview];
            cameraButton.hidden = NO;
        }];
        return;
    }
 
    [[ImgurAnonymousAPIClient client] uploadAssetWithURL:info[UIImagePickerControllerReferenceURL] filename:nil completionHandler:^(NSURL *imgurURL, NSError *error) {
        if(error)
            NSLog(@"Error while uploading image: %@", error.description);
        NSString *string;
        if ([_composeBarView.text isEqualToString:@""] == NO)
            string = [[_composeBarView text] stringByAppendingFormat:@" %@", imgurURL.absoluteString];
        else
            string = imgurURL.absoluteString;
        [_composeBarView setText:string];
        [indicator stopAnimating];
        [indicator removeFromSuperview];
        cameraButton.hidden = NO;
    }];

}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:^{
        [_composeBarView becomeFirstResponder];
    }];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
}

- (void)popoverView:(MenuPopOverView *)popoverView didSelectItemAtIndex:(NSInteger)index
{
    
    UITextView *textView = _composeBarView.textView;
    NSString *string = [textView.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSArray *args = [string componentsSeparatedByString:@" "];
    string = args[args.count-1];
    NSString *replace = _suggestions[index];
    
    if (args.count == 1) {
        if ([[string substringToIndex:1] isEqualToString:@"/"])
            replace = [NSString stringWithFormat:@"/%@", replace];

    }

    textView.text = [textView.text stringByReplacingCharactersInRange:NSMakeRange(textView.text.length-string.length, string.length)
                                                           withString:[replace stringByAppendingString:@" "]];
    
    [_composeBarView layoutSubviews];
}

- (void)popoverViewDidDismiss:(MenuPopOverView *)popoverView
{
    UITextView *textView = _composeBarView.textView;
    if ([[textView.text substringFromIndex:textView.text.length-1] isEqualToString:@" "] == NO)
       popoverDidDismiss = YES;
    
    _popOver = nil;
}

- (void)composeBarView:(PHFComposeBarView *)composeBarView didChangeFromFrame:(CGRect)startFrame toFrame:(CGRect)endFrame
{
    CGRect frame = CGRectMake(self.container.frame.origin.x,
                              self.container.frame.origin.y,
                              self.container.frame.size.width,
                              self.container.frame.size.height - endFrame.size.height);
    
    _conversation.contentView.frame = frame;
    [self scrollToBottom:NO];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [[MCNotificationManager sharedInstance] hideNotification];
    
    if (_popOver)
        [_popOver removeFromSuperview];
    [self hideUserList];
    [_conversation.contentView removeFromSuperview];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [_container addSubview:_conversation.contentView];
    [_conversation.contentView layoutIfNeeded];
    [self viewWillAppear:NO];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if ([NSStringFromClass([gestureRecognizer class]) isEqualToString:@"UITapGestureRecognizer"] &&
        [NSStringFromClass([otherGestureRecognizer class]) isEqualToString:@"UISwipeGestureRecognizer"]) {
        return YES;
    }
    return NO;
}

@end

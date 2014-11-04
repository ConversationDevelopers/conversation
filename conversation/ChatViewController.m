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

#import "ChatViewController.h"
#import "ChatMessageView.h"
#import "IRCMessage.h"
#import "UserListView.h"
#import "InputCommands.h"
#import <UIActionSheet+Blocks/UIActionSheet+Blocks.h>
#import <ImgurAnonymousAPIClient/ImgurAnonymousAPIClient.h>

@interface ChatViewController ()
@property (nonatomic) BOOL userlistIsVisible;
@property (readonly, nonatomic) UIView *container;
@property (readonly, nonatomic) UIScrollView *contentView;
@property (readonly, nonatomic) PHFComposeBarView *composeBarView;
@property (readonly, nonatomic) UserListView *userListView;
@end

CGRect const kInitialViewFrame = { 0.0f, 0.0f, 320.0f, 480.0f };

@implementation ChatViewController

- (id)init
{
    if (!(self = [super init]))
        return nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillToggle:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillToggle:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageReceived:)
                                                 name:@"messageReceived"
                                               object:nil];
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
                                                    name:@"receivedMessage"
                                                  object:nil];
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (void)loadView
{
    
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"ChannelIcon_Light"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack:)];
    
    self.navigationItem.leftBarButtonItem = backButton;
    
    UIView *view = [[UIView alloc] initWithFrame:kInitialViewFrame];
    [view setBackgroundColor:[UIColor whiteColor]];

    UIView *container = [self container];
    [container addSubview:[self contentView]];
    [container addSubview:[self composeBarView]];
    
    [view addSubview:container];
    
    [self setEdgesForExtendedLayout:UIRectEdgeNone];
    
    [self setView:view];
}

- (void)viewWillAppear:(BOOL)animated
{
    UIBarButtonItem *joinButton = [[UIBarButtonItem alloc] initWithTitle:@"Join" style:UIBarButtonItemStylePlain target:self action:@selector(join:)];
    
    UIBarButtonItem *userlistButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Userlist"]
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(showUserList:)];
    if (!_isChannel || [(IRCChannel*)_conversation isJoinedByUser])
        self.navigationItem.rightBarButtonItem = userlistButton;
    else
        self.navigationItem.rightBarButtonItem = joinButton;
    
    self.title = _conversation.name;
    
    [self clearContent];
    
    // Add initial messages
    for (IRCMessage *message in _conversation.messages) {
        [self addMessage:message];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    if (_contentView.contentSize.height > _contentView.bounds.size.height) {
        [self scrollToBottom:NO];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [self hideAccessories:nil];
}

- (void)clearContent
{
    for (UIView *view in _contentView.subviews) {
        [view removeFromSuperview];
    }
    _messageEntryHeight = 0.0;
}

- (void)scrollToBottom:(BOOL)animated
{
    CGPoint bottomOffset = CGPointMake(0, _contentView.contentSize.height - _contentView.bounds.size.height);
    [_contentView setContentOffset:bottomOffset animated:animated];
}

- (void)addMessage:(IRCMessage *)message
{
    ChatMessageView *messageView = [[ChatMessageView alloc] initWithFrame:CGRectMake(0, _messageEntryHeight, _contentView.bounds.size.width, 15.0)
                                                                  message:message
                                                             conversation:_conversation];
    messageView.chatViewController = self;
    
    if (message.messageType == ET_PRIVMSG)
        _messageEntryHeight += [messageView frameHeight] + 15.0;
    else
        _messageEntryHeight += [messageView frameHeight];
    
    messageView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_contentView addSubview:messageView];
    _contentView.contentSize = CGSizeMake(_container.bounds.size.width, _messageEntryHeight);
    
    // Scroll to bottom if content is bigger than view and user didnt scroll up
    if (_contentView.contentSize.height > _contentView.bounds.size.height &&
        (_contentView.contentOffset.y == 0.0 || _contentView.contentOffset.y > _contentView.contentSize.height - _contentView.bounds.size.height - 65)) {
        
        [self scrollToBottom:YES];
    }
}

- (void)join:(id)sender
{
    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    [controller joinChannelWithName:_conversation.name onClient:_conversation.client];
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
    
    CGFloat sizeChange = UIInterfaceOrientationIsLandscape([self interfaceOrientation]) ? widthChange : heightChange;
    
    CGRect newContainerFrame = [[self container] frame];
    newContainerFrame.size.height += sizeChange;
    
    [UIView animateWithDuration:duration
                          delay:0
                        options:(animationCurve << 16)|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         [[self container] setFrame:newContainerFrame];
                     }
                     completion:NULL];
}

- (void)goBack:(id)sender
{
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)showUserList:(id)sender
{
    _userlistIsVisible = YES;
    [_composeBarView resignFirstResponder];    
    UserListView *userlist = [self userListView];
    
    userlist.channel = (IRCChannel*)_conversation;

    [self.navigationController.view addSubview:userlist];

    CGRect frame = userlist.frame;
    frame.origin.x = _container.frame.size.width - 205.0f;
    
    [UIView animateWithDuration:0.5
                          delay:0.0
         usingSpringWithDamping:0.5
          initialSpringVelocity:0.3
                        options:0 animations:^{
                            userlist.frame = frame;
                            //Animations
                        }
                     completion:nil];
    

}

- (void)composeBarViewDidPressButton:(PHFComposeBarView *)composeBarView
{
    NSLog(@"Info button clicked");
}

- (void)composeBarViewDidPressUtilityButton:(PHFComposeBarView *)composeBarView
{
    NSLog(@"Utility button pressed");

    [self hideAccessories:nil];
    [UIActionSheet showInView:self.view
                    withTitle:NSLocalizedString(@"Photo Source", @"Photo Source")
            cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
       destructiveButtonTitle:nil
            otherButtonTitles:@[NSLocalizedString(@"Camera", @"Camera"), NSLocalizedString(@"Photo Library", @"Photo Library")]
                     tapBlock:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
                         if (buttonIndex == 0) {
                             UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
                             [imagePicker.view setFrame:CGRectMake(0, 80, 320, 350)];
                             [imagePicker setSourceType:UIImagePickerControllerSourceTypeCamera];
                             [imagePicker setDelegate:(id)self];
                             [self presentViewController:imagePicker animated:YES completion:nil];
                         } else if(buttonIndex == 1) {
                             UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
                             [imagePicker.view setFrame:CGRectMake(0, 80, 320, 350)];
                             [imagePicker setSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
                             [imagePicker setDelegate:(id)self];
                             [self presentViewController:imagePicker animated:YES completion:nil];
                         }

                     }];
    
}

- (void)sendMessage:(NSString *)message
{
    if ([message hasPrefix:@"/"])
        [InputCommands performCommand:[message substringFromIndex:1] inConversation:_conversation];
    else {
        [InputCommands sendMessage:message toRecipient:_conversation.name onClient:_conversation.client];
        
        IRCMessage *ircmsg = [[IRCMessage alloc] initWithMessage:message
                                                          OfType:ET_PRIVMSG
                                                  inConversation:_conversation
                                                        bySender:_conversation.client.currentUserOnConnection
                                                          atTime:[NSDate date]];
        [self addMessage:ircmsg];
        [_conversation.messages addObject:ircmsg];
    }
    
    [_composeBarView setText:@"" animated:YES];

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
        
        CGRect frame = _userListView.frame;
        frame.origin.x = _container.frame.size.width;
        _userListView.frame = frame;
        
        [_userListView removeFromSuperview];
        _userlistIsVisible = NO;
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
    if (_isChannel &&
        [(IRCChannel*)_conversation isJoinedByUser] &&
        message.messageType == ET_JOIN &&
        [message.sender.nick isEqualToString:_conversation.client.currentUserOnConnection.nick] &&
        [message.conversation.configuration.uniqueIdentifier isEqualToString:_conversation.configuration.uniqueIdentifier]) {
        
        UIBarButtonItem *userlistButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Userlist"]
                                                                           style:UIBarButtonItemStylePlain
                                                                          target:self
                                                                          action:@selector(showUserList:)];
        self.navigationItem.rightBarButtonItem = userlistButton;
        
    }
    
    if([message.conversation.configuration.uniqueIdentifier isEqualToString:_conversation.configuration.uniqueIdentifier]) {
        [self addMessage:message];
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
//        [_composeBarView setMaxCharCount:160];
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
                                  _container.frame.size.height+30.0f);
        
        _userListView = [[UserListView alloc] initWithFrame:frame];
    }
    return _userListView;
}

@synthesize contentView = _contentView;
- (UIScrollView *)contentView {
    
    if(!_contentView) {
        CGRect frame = CGRectMake(0.0,
                                  0.0,
                                  kInitialViewFrame.size.width,
                                  kInitialViewFrame.size.height - PHFComposeBarViewInitialHeight);
        
        _contentView = [[UIScrollView alloc] initWithFrame:frame];
        _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        
        UITapGestureRecognizer *singleTapRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideAccessories:)];
        [singleTapRecogniser setDelegate:self];
        singleTapRecogniser.numberOfTouchesRequired = 1;
        singleTapRecogniser.numberOfTapsRequired = 1;
        [_contentView addGestureRecognizer:singleTapRecogniser];
        
    }
    return _contentView;
}

#pragma mark -
#pragma mark UIImagePickerController Delegate Methods

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    UIButton *cameraButton = [_composeBarView utilityButton];
    cameraButton.hidden = YES;
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    indicator.frame = _composeBarView.utilityButton.frame;
    [indicator setHidesWhenStopped:YES];
    [indicator startAnimating];
    [_composeBarView addSubview:indicator];
    
    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [[ImgurAnonymousAPIClient client] uploadImage:image withFilename:nil completionHandler:^(NSURL *imgurURL, NSError *error) {
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
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
}

@end

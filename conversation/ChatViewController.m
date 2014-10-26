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
#import "IRCCommands.h"
#import "UserListView.h"

@interface ChatViewController ()
@property (nonatomic) BOOL userlistIsVisible;
@property (readonly, nonatomic) ChatMessageView *dummyCell;
@property (readonly, nonatomic) UITableView *tableView;
@property (readonly, nonatomic) UIView *container;
@property (readonly, nonatomic) PHFComposeBarView *composeBarView;
@property (readonly, nonatomic) UserListView *userListView;
@end

CGRect const kInitialViewFrame = { 0.0f, 0.0f, 320.0f, 480.0f };

@implementation ChatViewController

- (id)init
{
    if (!(self = [super init]))
        return nil;
    
    _messages = [[NSMutableArray alloc] init];
    
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
    self.title = _channel.configuration.name;
    UIBarButtonItem *userlistButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Userlist"]
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(showUserList:)];
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"ChannelIcon_Light"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack:)];
    self.navigationItem.rightBarButtonItem = userlistButton;
    self.navigationItem.leftBarButtonItem = backButton;
    
    UIView *view = [[UIView alloc] initWithFrame:kInitialViewFrame];
    [view setBackgroundColor:[UIColor whiteColor]];

    UIView *container = [self container];
    [container addSubview:[self tableView]];
    [container addSubview:[self composeBarView]];
    
    [view addSubview:container];
    
    [self setEdgesForExtendedLayout:UIRectEdgeNone];
    
    [self setView:view];
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
    
    userlist.users = _channel.users;

    [self.navigationController.view addSubview:userlist];

    CGRect frame = userlist.frame;
    frame.origin.x = _tableView.frame.size.width - 205.0f;
    
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
}

- (void)sendMessage:(NSString *)message
{
    [IRCCommands sendMessage:message toRecipient:_channel.name onClient:_channel.client];
    IRCMessage *ircmsg = [[IRCMessage alloc] initWithMessage:message
                                                       OfType:ET_PRIVMSG
                                               inConversation:_channel
                                                     bySender:_channel.client.currentUserOnConnection
                                                       atTime:[NSDate date]];
    [_messages addObject:ircmsg];
    [_composeBarView setText:@"" animated:YES];
    [_tableView reloadData];
    
    [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_messages.count-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

#pragma mark - Table View

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ( !_dummyCell ) _dummyCell = [[ChatMessageView alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    
    _dummyCell.message = _messages[indexPath.row];
    
    CGFloat height;
    CGRect rect = [_dummyCell calculateRect];
    height = rect.size.height;
    if ( height == 0 ) height = 50;
    return height+10.0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    static NSString *CellIdentifier = @"cell";
    
    ChatMessageView *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[ChatMessageView alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    cell.message = _messages[indexPath.row];
    
    return cell;
}

- (BOOL) textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if([text isEqualToString:@"\n"]){
        [self sendMessage:textView.text];
        return NO;
    }else{
        return YES;
    }
}

- (void)hideAccessories:(UIGestureRecognizer*)sender
{
    if (_userlistIsVisible) {
        
        CGRect frame = _userListView.frame;
        frame.origin.x = _tableView.frame.size.width;
        _userListView.frame = frame;
        
        [UIView commitAnimations];
        
        [_userListView removeFromSuperview];
        _userlistIsVisible = NO;
        return;
    }
    [_composeBarView resignFirstResponder];
}

- (void)messageReceived:(NSNotification *)notification
{
    
    IRCMessage *message = notification.object;
    
    // Handle actions and normal messages for now
    if (message.messageType != ET_PRIVMSG && message.messageType != ET_ACTION)
        return;
    
    // Handle only suitable messages
    if ([message.conversation.configuration.uniqueIdentifier isEqualToString:_channel.configuration.uniqueIdentifier] == NO)
        return;
    
    [_messages addObject:message];
    [_tableView reloadData];

    [_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_messages.count-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

@synthesize container = _container;
- (UIView *)container {
    if (!_container) {
        _container = [[UIView alloc] initWithFrame:kInitialViewFrame];
        _container.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    }
    
    return _container;
}

@synthesize tableView = _tableView;
- (UITableView *)tableView {
    
    if(!_tableView) {
        CGRect frame = CGRectMake(0.0,
                                  0.0,
                                  kInitialViewFrame.size.width,
                                  kInitialViewFrame.size.height - PHFComposeBarViewInitialHeight);
        
        _tableView = [[UITableView alloc] initWithFrame:frame];
        _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.dataSource = self;
        _tableView.delegate = self;
        
        UITapGestureRecognizer *singleTapRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideAccessories:)];
        [singleTapRecogniser setDelegate:self];
        singleTapRecogniser.numberOfTouchesRequired = 1;
        singleTapRecogniser.numberOfTapsRequired = 1;
        [_tableView addGestureRecognizer:singleTapRecogniser];
        
    }
    return _tableView;
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
        CGRect frame = CGRectMake(_tableView.frame.size.width,
                                  30.0f,
                                  width,
                                  _tableView.frame.size.height+30.0f);
        
        _userListView = [[UserListView alloc] initWithFrame:frame];
    }
    return _userListView;
}

@end

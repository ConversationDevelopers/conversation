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
#import "IRCUser.h"
#import "IRCCommands.h"

@interface ChatViewController ()
@property (readonly, nonatomic) UITableView *tableView;
@property (readonly, nonatomic) UIView *container;
@property (readonly, nonatomic) PHFComposeBarView *composeBarView;
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
    
    UIView *view = [[UIView alloc] initWithFrame:kInitialViewFrame];
    [view setBackgroundColor:[UIColor whiteColor]];

    
    UIView *container = [self container];

//    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - PHFComposeBarViewInitialHeight)];
    
    [container addSubview:[self tableView]];

    [container addSubview:[self composeBarView]];
    
    
    [view addSubview:container];
    [self setEdgesForExtendedLayout:UIRectEdgeNone];
    
    [self setView:view];
}

- (void)keyboardWillToggle:(NSNotification *)notification
{
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

- (void)composeBarViewDidPressButton:(PHFComposeBarView *)composeBarView
{
    NSString *msg = [composeBarView text];
    [IRCCommands sendMessage:msg toRecipient:_channel.name onClient:_channel.client];
    IRCMessage *message = [[IRCMessage alloc] initWithMessage:msg
                                                       OfType:ET_PRIVMSG
                                               inConversation:_channel
                                                     bySender:_channel.client.currentUserOnConnection
                                                       atTime:[NSDate date]];
    [_messages addObject:message];
    [composeBarView setText:@"" animated:YES];
    [composeBarView resignFirstResponder];
    [_tableView reloadData];
}

- (void)composeBarViewDidPressUtilityButton:(PHFComposeBarView *)composeBarView
{
    NSLog(@"Utility button pressed");
}

#pragma mark - Table View

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
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
        cell = [[ChatMessageView alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    IRCMessage *message = _messages[indexPath.row];
    IRCUser *user = message.sender;
    
    cell.nickname = user.nick;
    cell.message = [[NSAttributedString alloc] initWithString:message.message attributes:@{}];
    
    return cell;
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
}

@synthesize container = _container;
- (UIView *)container {
    if (!_container) {
        _container = [[UIView alloc] initWithFrame:kInitialViewFrame];
        [_container setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight];
    }
    
    return _container;
}

@synthesize tableView = _tableView;
- (UITableView *)tableView {
    
    if(!_tableView) {
        CGRect frame = CGRectMake(0.0f,
                                  20.0f,
                                  kInitialViewFrame.size.width,
                                  kInitialViewFrame.size.height - 20.0f);
        
        _tableView = [[UITableView alloc] initWithFrame:frame];
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.dataSource = self;
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
        [_composeBarView setMaxCharCount:160];
        [_composeBarView setMaxLinesCount:5];
        [_composeBarView setPlaceholder:@"Type something..."];
        [_composeBarView setUtilityButtonImage:[UIImage imageNamed:@"Camera"]];
        [_composeBarView setDelegate:self];
    }
    return _composeBarView;
}

@end

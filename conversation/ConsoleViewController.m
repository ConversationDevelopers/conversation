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


#import "ConsoleViewController.h"
#import "IRCMessage.h"

@interface ConsoleViewController ()
@property (readonly, nonatomic) UIView *container;
@property (readonly, nonatomic) UITextView *contentView;
@property (nonatomic) UIBarButtonItem *backButton;
@end

@implementation ConsoleViewController

- (id)init
{
    if (!(self = [super init]))
        return nil;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageReceived:)
                                                 name:@"messageReceived"
                                               object:nil];
    
    _backButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"ChannelIcon_Light"] style:UIBarButtonItemStylePlain target:self action:@selector(goBack:)];
    
    self.navigationItem.leftBarButtonItem = _backButton;
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"messageReceived"
                                                  object:nil];
}

- (void)loadView
{
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 480.0f)];
    [view setBackgroundColor:[UIColor whiteColor]];
    
    UIView *container = [self container];
    [container addSubview:[self contentView]];
    
    [view addSubview:container];
    self.view = view;
    
    [self setEdgesForExtendedLayout:UIRectEdgeNone];
    
    [self setView:view];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)messageReceived:(NSNotification *)notification
{
    IRCMessage *message = notification.object;
    if (message.messageType == ET_RAW) {
        _contentView.text = [_contentView.text stringByAppendingFormat:@"%@\n", message.message];
    }
}

- (void)goBack:(id)sender
{
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    [_contentView resignFirstResponder];
}

@synthesize container = _container;
- (UIView *)container {
    if (!_container) {
        _container = [[UIScrollView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 480.0f)];
        _container.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    }
    
    return _container;
}

@synthesize contentView = _contentView;
- (UITextView *)contentView {
    
    if(!_contentView) {
        CGRect frame = CGRectMake(0.0,
                                  0.0,
                                  _container.bounds.size.width,
                                  _container.bounds.size.height);
        _contentView = [[UITextView alloc] initWithFrame:frame];
        _contentView.editable = NO;        
        _contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;

    }
    return _contentView;
}


@end

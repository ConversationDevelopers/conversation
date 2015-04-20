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


#import "UITableView+Methods.h"
#import "ChannelListViewController.h"
#import "DisclosureView.h"
#import "ConversationItemView.h"
#import "IRCCommands.h"
#import "NSArray+Methods.h"


@interface ChannelListViewController ()
@property (nonatomic) NSMutableArray *channels;
@property (strong, nonatomic) NSTimer *timer;
@end

BOOL _isAwaitingListResponse;

@implementation ChannelListViewController

double timerInterval = 2.0f;

- (id)init
{
    if (!(self = [super initWithStyle:UITableViewStylePlain]))
        return nil;
 
    _channels = [[NSMutableArray alloc] init];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Channel List", @"Channel List");
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageReceived:)
                                                 name:@"messageReceived"
                                               object:nil];
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStylePlain target:self action:@selector(close:)];
    
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh:)];
    
    self.navigationItem.leftBarButtonItem = closeButton;
    self.navigationItem.rightBarButtonItem = refreshButton;
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    _isAwaitingListResponse = YES;
    [_client.connection send:@"LIST"];
    
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    
}

- (void)refreshTableView:(NSTimer*)timer
{
    NSSortDescriptor *nameSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)];
    _channels = [[_channels sortedArrayUsingDescriptors:@[nameSortDescriptor]] mutableCopy];
    
    [self.tableView reloadData];
    if (_isAwaitingListResponse == NO) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _channels.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"cell";
    ConversationItemView *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[ConversationItemView alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    

    DisclosureView *disclosure = [[DisclosureView alloc] initWithFrame:CGRectMake(-5, -10, 15, 15)];
    disclosure.color = [UIColor whiteColor];

    cell.backgroundColor = [UIColor whiteColor];
    cell.nameLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1];
    cell.unreadCountLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1];
    cell.isConsole = NO;
    cell.isChannel = YES;
    cell.enabled = YES;
    cell.accessoryView = disclosure;

    NSDictionary *entry = _channels[indexPath.row];
    NSAttributedString *modes = [[NSAttributedString alloc] initWithString:entry[@"modes"] attributes:nil];
    NSAttributedString *topic = [[NSAttributedString alloc] initWithString:entry[@"topic"] attributes:nil];
    
    cell.name = entry[@"name"];
    cell.previewMessages = [@[modes, topic] mutableCopy];
    cell.unreadCount = [entry[@"users"] integerValue];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    IRCChannel *channel = [controller joinChannelWithName:_channels[indexPath.row][@"name"] onClient:_client];
    [controller selectConversationWithIdentifier:channel.configuration.uniqueIdentifier];
}

- (void)close:(id)sender
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)refresh:(id)sender
{
    [_channels removeAllObjects];
    _isAwaitingListResponse = YES;
    [_client.connection send:@"LIST"];
    [self.tableView reloadData];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"messageReceived"
                                                  object:nil];
}

- (void)messageReceived:(NSNotification *)notification
{
    IRCMessage *message = notification.object;    
    if ([message.client isEqual:_client] == NO || _isAwaitingListResponse == NO)
        return;
    
    if (message.messageType == ET_LISTEND) {
        _isAwaitingListResponse = NO;
        return;
    }

    if (message.messageType != ET_LIST)
        return;
    
    NSArray *components = [message.message componentsSeparatedByString:@" "];
    if ([components count] < 2)
        // TODO: Determine what this means
        return;
    NSString *users = components[0];
    NSString *topic = [components componentsJoinedByString:@" " fromIndex:2];

    if ([topic hasPrefix:@":"])
        topic = [topic substringFromIndex:1];
    
    NSString *modes = @"";
    if ([topic hasPrefix:@"["]) {
        NSRange range = [topic rangeOfString:@"]"];
        modes = [topic substringToIndex:range.location+range.length];
        topic = [topic substringFromIndex:range.location+range.length+1];
    }
    
    NSDictionary *entry = @{
                        @"name": message.conversation.name,
                        @"users": users,
                        @"modes": modes,
                        @"topic": topic
                        };
    
    [_channels addObject:entry];
    
}

- (NSTimer *) timer {
    if (!_timer) {
        _timer = [NSTimer timerWithTimeInterval:timerInterval target:self selector:@selector(refreshTableView:) userInfo:nil repeats:YES];
    }
    return _timer;
}




@end

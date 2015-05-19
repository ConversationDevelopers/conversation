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


#import "UserInfoViewController.h"
#import "WHOIS.h"
#import "PreferencesTextCell.h"
#import "UITableView+Methods.h"

@interface UserInfoViewController ()
@property (nonatomic) WHOIS *user;
@property (nonatomic) NSDate *refDate;
@property (nonatomic) NSTimer *timer;
@end


BOOL _isAwaitingWhoisResponse;

@implementation UserInfoViewController

- (id)init
{
    if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
        return nil;
    
    self.refDate = nil;
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
 
    self.navigationController.navigationBar.tintColor = [UIColor lightGrayColor];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
    self.navigationController.navigationBar.translucent = NO;
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh:)];
    
    [refreshButton setTintColor:[UIColor lightGrayColor]];
    
    self.navigationItem.rightBarButtonItem = refreshButton;
    
    self.title = _nickname;

}

- (void)viewWillAppear:(BOOL)animated
{
    _isAwaitingWhoisResponse = YES;
    _refDate = [NSDate date];
    [_client.connection send:[NSString stringWithFormat:@"WHOIS %@ %@", _nickname, _nickname]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageReceived:) name:@"whois" object:nil];
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                              target:self
                                            selector:@selector(update:)
                                            userInfo:nil
                                             repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"messageReceived"
                                                  object:nil];
    [_timer invalidate];
    _timer = nil;
    _user = nil;
}

-(void)update:(NSTimer *)timer
{
    [self.tableView reloadData];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section
{
    switch (section) {
        case 0:
            return NSLocalizedString(@"User Info", @"User Info");
            break;
        case 1: {
            if ([_user.channels count] > 0)
                return NSLocalizedString(@"Channels", @"Channels");
            else
                return @"";
            break;
        }
        case 2:
            return NSLocalizedString(@"Connection", @"Conenction");
            break;
    }
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0)
        return 4;
    else if (section == 1) {
        if ([_user.channels count] > 0)
            return [_user.channels count];
        else
            return 0;
    }
    
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
    cell.textField.userInteractionEnabled = NO;
    cell.textLabel.textColor = [UIColor darkGrayColor];
    
    if (indexPath.section == 0) {

        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = NSLocalizedString(@"Nick Name", @"Nick Name");
                cell.textField.text = _user.nickname;
                break;
            case 1:
                cell.textLabel.text = NSLocalizedString(@"User Name", @"Nick Name");
                cell.textField.text = _user.username;
                break;
            case 2:
                cell.textLabel.text = NSLocalizedString(@"Host Name", @"Host Name");
                cell.textField.text = _user.hostname;
                break;
            case 3:
                cell.textLabel.text = NSLocalizedString(@"Real Name", @"Real Name");
                cell.textField.text = _user.realname;
                break;
        }
    } else if (indexPath.section == 1) {
        
        cell.textLabel.text = _user.channels[indexPath.row];

    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedString(@"Server", @"Server");
            cell.textField.text = _user.server;
        } else if (indexPath.row == 1) {
            cell.textLabel.text = NSLocalizedString(@"Connected", @"Connected");
            
            NSDateFormatter* df = [[NSDateFormatter alloc] init];
            [df setLocale:[NSLocale currentLocale]];
            [df setDateStyle:NSDateFormatterMediumStyle];
            [df setTimeStyle:NSDateFormatterMediumStyle];
            cell.textField.text = [df stringFromDate:_user.signedInAtTime];
            
        } else {
            cell.textLabel.text = NSLocalizedString(@"Idle", @"Idle");
            cell.textField.text = [self formattedTimeSinceEvent:_user.idleSinceTime];
        }
    }

    // Configure the cell...
    
    return cell;
}

- (NSString *)formattedTimeSinceEvent:(NSDate *)date {
    double interval = [[NSDate date] timeIntervalSinceDate:date];
    
    NSArray *formats = @[
        [NSNumber numberWithInt:31556900],
        [NSNumber numberWithInt:2629740],
        [NSNumber numberWithInt:604800],
        [NSNumber numberWithInt:86400],
        [NSNumber numberWithInt:3600],
        [NSNumber numberWithInt:60]
    ];
    
    NSArray *formatStrings = @[
                         @"Year",
                         @"Month",
                         @"Week",
                         @"Day",
                         @"Hour",
                         @"Minute"
    ];
    
    for (NSString *format in formatStrings) {
        float count = interval / [[formats objectAtIndex:[formatStrings indexOfObject:format]] intValue];
        if (count >= 1) {
            NSString *suffix = [NSString stringWithFormat:@"%@%@", format, count > 1 ? @"s" : @""];
            return [NSString stringWithFormat:@"%d %@", (int)count, suffix];
        }
    }
    
    if (interval > 0) {
        return [NSString stringWithFormat:@"%d Second%@", (int)interval, interval > 1 ? @"s" : @""];
    } else {
        return @"";
    }
}

- (void)messageReceived:(NSNotification *)notification
{
    if (!_isAwaitingWhoisResponse)
        return;
    
    WHOIS *whoisMessage = notification.object;
    _user = whoisMessage;
    
    _isAwaitingWhoisResponse = NO;
    [self.tableView reloadData];
}

- (void)cancel:(id)sender
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)refresh:(id)sender
{
    _isAwaitingWhoisResponse = YES;
    _refDate = [NSDate date];
    [_client.connection send:[NSString stringWithFormat:@"WHOIS %@ %@", _nickname, _nickname]];
}

@end

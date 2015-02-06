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


#import "UserInfoViewController.h"
#import "IRCMessage.h"
#import "PreferencesTextCell.h"
#import "UITableView+Methods.h"

@interface UserInfoViewController ()
@property (nonatomic) NSMutableDictionary *infoDict;
@property (nonatomic) NSDate *refDate;
@end

BOOL _isAwaitingWhoisResponse;

@implementation UserInfoViewController

- (id)init
{
    if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
        return nil;
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationController.navigationBar.tintColor = [UIColor lightGrayColor];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
    self.navigationController.navigationBar.translucent = NO;
    
    self.title = _nickname;
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    UIBarButtonItem *refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh:)];

    [refreshButton setTintColor:[UIColor lightGrayColor]];
    
    self.navigationItem.rightBarButtonItem = refreshButton;
    
    _infoDict = [[NSMutableDictionary alloc] init];
    _refDate = [NSDate date];

}

- (void)viewWillAppear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageReceived:) name:@"messageReceived" object:nil];
    _isAwaitingWhoisResponse = YES;
    [_client.connection send:[NSString stringWithFormat:@"WHOIS %@", _nickname]];

    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     target:self
                                   selector:@selector(update:)
                                   userInfo:nil
                                    repeats:YES];
}

-(void)update:(NSTimer *)timer
{
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"messageReceived"
                                                  object:nil];
    [_infoDict removeAllObjects];
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
            if ([_infoDict[@"channels"] count] > 0)
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
        if ([_infoDict[@"channels"] count] > 0)
            return [_infoDict[@"channels"] count];
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
                cell.textField.text = _infoDict[@"user"][0];
                break;
            case 1:
                cell.textLabel.text = NSLocalizedString(@"User Name", @"Nick Name");
                cell.textField.text = _infoDict[@"user"][1];
                break;
            case 2:
                cell.textLabel.text = NSLocalizedString(@"Host Name", @"Host Name");
                cell.textField.text = _infoDict[@"user"][2];
                break;
            case 3:
                cell.textLabel.text = NSLocalizedString(@"Real Name", @"Real Name");
                cell.textField.text = _infoDict[@"user"][3];
                break;
        }
    } else if (indexPath.section == 1) {
        
        cell.textLabel.text = _infoDict[@"channels"][indexPath.row];

    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            cell.textLabel.text = NSLocalizedString(@"Server", @"Server");
            cell.textField.text = _infoDict[@"server"][0];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = NSLocalizedString(@"Connected", @"Connected");
            
            NSDate *date = [NSDate date];
            if (_infoDict[@"idle"][1])
                date = [NSDate dateWithTimeIntervalSince1970:[_infoDict[@"idle"][1] longLongValue]];
            
            NSDateFormatter *dateFormatter = [NSDateFormatter new];
            dateFormatter.timeZone = [NSTimeZone localTimeZone];
            dateFormatter.dateFormat = @"dd MMM yyyy HH:mm:ss zzz";
            cell.textField.text = [dateFormatter stringFromDate:date];
            
        } else {
            cell.textLabel.text = NSLocalizedString(@"Idle", @"Idle");
            double seconds = 0.0;
                if (_infoDict[@"idle"][0])
                    seconds = [_infoDict[@"idle"][0] longLongValue];
            
            NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:_refDate];
            cell.textField.text = [NSString stringWithFormat:@"%.f seconds", seconds + interval];
        }
    }

    // Configure the cell...
    
    return cell;
}

- (void)messageReceived:(NSNotification *)notification
{
    if (!_isAwaitingWhoisResponse)
        return;

    IRCMessage *message = notification.object;
    if (message.messageType == ET_WHOIS) {
        NSMutableArray *components = [[message.message componentsSeparatedByString:@" "] mutableCopy];
        [components removeObjectAtIndex:0];
        
        NSString *command = components[0];
        [components removeObjectAtIndex:0];
        
        NSMutableArray *infoArray = [[NSMutableArray alloc] init];
        
        if ([command isEqualToString:@"311"]) {
            [components removeObjectAtIndex:0];
            for (NSString *info in components) {
                if ([info hasPrefix:@":"]) {
                    [infoArray addObject:[info substringFromIndex:1]];
                    continue;
                }
                [infoArray addObject:info];
                
            }
            [infoArray removeObjectAtIndex:3];
            _infoDict[@"user"] = [infoArray copy];
            
        } else if ([command isEqualToString:@"319"]) {
            NSString *channels = [message.message componentsSeparatedByString:@":"][2];
            for (NSString *info in [channels componentsSeparatedByString:@" "]) {
                if (info.length > 0)
                    [infoArray addObject:info];
            }
            _infoDict[@"channels"] = [infoArray copy];
        } else if ([command isEqualToString:@"312"]) {
            [components removeObjectAtIndex:0];
            [components removeObjectAtIndex:0];
            [infoArray addObject:components[0]];
            _infoDict[@"server"] = [infoArray copy];
        } else if ([command isEqualToString:@"317"]) {
            [components removeObjectAtIndex:0];
            [components removeObjectAtIndex:0];
            [infoArray addObject:components[0]];
            [infoArray addObject:components[1]];
            _infoDict[@"idle"] = [infoArray copy];
        }
    }
    
    if (message.messageType == ET_WHOISEND) {
        _isAwaitingWhoisResponse = NO;
        [self.tableView reloadData];
    }
}

- (void)cancel:(id)sender
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)refresh:(id)sender
{
    _isAwaitingWhoisResponse = YES;
    _refDate = [NSDate date];
    [_client.connection send:[NSString stringWithFormat:@"WHOIS %@", _nickname]];
}

@end

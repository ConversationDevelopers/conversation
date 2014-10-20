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


#import "AddConversationViewController.h"
#import "PreferencesListViewController.h"
#import "PreferencesTextCell.h"
#import "UITableView+Methods.h"
#import "IRCClient.h"
#import "SSKeychain.h"

@implementation AddConversationViewController

static unsigned short ConnectionTableSection = 0;
static unsigned short ConversationTableSection = 1;

- (id) init {
    if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
        return nil;
    
    _addChannel = YES;
    _connections = nil;
    _client = nil;
    _saveButtonTitle = NSLocalizedString(@"Chat", @"Right button in add conversation view");
    
    return self;
}

- (void) viewDidLoad {
    [super viewDidLoad];

    if (!self.title) {
        if(self.addChannel)
            self.title = NSLocalizedString(@"Join a Channel", @"Join a Channel");
        else
            self.title = NSLocalizedString(@"Message a User", @"Message a User");
    }
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    UIBarButtonItem *chatButton = [[UIBarButtonItem alloc] initWithTitle:_saveButtonTitle
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(chat:)];
    [chatButton setTintColor:[UIColor lightGrayColor]];
    chatButton.enabled = NO;
    _badInput = NO;
    self.navigationItem.rightBarButtonItem = chatButton;

    ConnectionTableSection = 0;
    
    // There is only one client, lets use that
    if(!_connections || _connections.count == 1) {
        _client = _connections[0];
        ConnectionTableSection = -1;
        chatButton.enabled = YES;
    }
       
    _configuration = [[IRCChannelConfiguration alloc] init];
    _configuration.autoJoin = YES;
    
}

- (void) cancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) chat:(id)sender
{
    // Add conversation to client
    if(_badInput) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Please check input values", @"Please check input values")
                                                        message:nil
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    if ([[UIApplication sharedApplication] sendAction:_action to:_target from:self forEvent:nil]) {
        if(_client)
            [self dismissViewControllerAnimated:YES completion:nil];
        else
            [self.navigationController popViewControllerAnimated:YES];
    }

}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView
{
    NSInteger count = 7;
    if(_connections && _connections.count > 1)
        count = 8;
    return count;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
    if (section == ConnectionTableSection) {
        return 1;
    } else if (section == ConversationTableSection) {
        if(self.addChannel)
            return 2;
        else
            return 1;
    }
    return 0;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
    if (indexPath.section == ConnectionTableSection && indexPath.row == 0)
        return indexPath;
    return nil;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath
{
    if (indexPath.section == ConnectionTableSection) {
        
        PreferencesListViewController *connectionListViewController = [[PreferencesListViewController alloc] init];
        
        NSMutableArray *connections = [[NSMutableArray alloc] init];

        for (IRCClient *client in _connections) {
            [connections addObject:client.configuration.connectionName];
        }

        connectionListViewController.title = NSLocalizedString(@"Connections", @"Connection");
        connectionListViewController.items = [connections copy];
        connectionListViewController.itemImage = [UIImage imageNamed:@"NetworkIcon"];
        connectionListViewController.target = self;
        connectionListViewController.action = @selector(connectionDidChanged:);
        
        [self.navigationController pushViewController:connectionListViewController animated:YES];
        
        return;
    }
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
    if (section == ConnectionTableSection) {
        return NSLocalizedString(@"Connection", @"Connection");
    } else if (section == ConversationTableSection) {
        if(self.addChannel)
            return NSLocalizedString(@"Channel Information", @"Channel Information");
        else
            return NSLocalizedString(@"User Identify", @"User Identify");
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == ConnectionTableSection && _connections.count > 1) {

        // Connection Picker
        UITableViewCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([UITableViewCell class]) andStyle:UITableViewCellStyleValue1];
        
        cell.textLabel.text = NSLocalizedString(@"Connection", @"Connection");
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.detailTextLabel.text = _client.configuration.connectionName;
        
        return cell;
        
    } else if (indexPath.section == ConversationTableSection) {
        if (indexPath.row == 0) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            if(self.addChannel) {
                cell.textLabel.text = NSLocalizedString(@"Channel Name", @"Channel Name");
                cell.textField.placeholder = @"#lobby";
            } else {
                cell.textLabel.text = NSLocalizedString(@"Nick Name", @"Nick Name");
            }
            cell.textField.text = _configuration.name;
            if(_configuration.name)
                cell.textField.text = _configuration.name;
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textEditAction = @selector(nameChanged:);
            return cell;
        } else if (indexPath.row == 1 && self.addChannel) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Password", @"Channel Password");
            cell.textField.text = @"";
            if(_configuration.passwordReference)
                cell.textField.text = _configuration.passwordReference;
            cell.textField.placeholder = @"Optional";
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textEditAction = @selector(passwordChanged:);
            return cell;
        }
    }
    return nil;
}

- (void) connectionDidChanged:(PreferencesListViewController *)sender
{
    _client = [_connections objectAtIndex:sender.selectedItem];
    [self.tableView reloadData];
    if(_client != nil && _configuration.name) {
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
}

- (void) nameChanged:(PreferencesTextCell *)sender
{
    sender.accessoryType = UITableViewCellAccessoryNone;
    
    _badInput = YES;
    
    if ([sender.textField.text isValidChannelName:_client]) {
        _configuration.name = sender.textField.text;
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        _badInput = NO;
    }
    
    if(_client && _configuration.name) {
        self.navigationItem.rightBarButtonItem.enabled = YES;        
    }

}

- (void) passwordChanged:(PreferencesTextCell *)sender
{
    sender.accessoryType = UITableViewCellAccessoryNone;
    _badInput = YES;
    
    if(sender.textField.text.length == 0) {
        _configuration.passwordReference = @"";
        _badInput = NO;
    }
    
    if(sender.textField.text.length > 1) {
        _configuration.passwordReference = sender.textField.text;
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        _badInput = NO;
    }
}
@end

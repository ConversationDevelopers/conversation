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

@implementation AddConversationViewController

static unsigned short ConnectionTableSection = 0;
static unsigned short ConversationTableSection = 1;

- (id) init {
    if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
        return nil;
    self.addChannel = YES;

    return self;
}

- (void) viewDidLoad {
    [super viewDidLoad];

    if(self.addChannel)
        self.title = NSLocalizedString(@"Join a Channel", @"Join a Channel");
    else
        self.title = NSLocalizedString(@"Message a User", @"Message a User");        
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    UIBarButtonItem *chatButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Chat", @"Right button in add conversation view")
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(chat:)];
    [chatButton setTintColor:[UIColor lightGrayColor]];
    chatButton.enabled = NO;
    badInput = NO;
    self.navigationItem.rightBarButtonItem = chatButton;
    _conversation = [[IRCChannel alloc] init];
    
}

- (void) viewWillAppear:(BOOL) animated {
    [super viewWillAppear:animated];
}

- (void) cancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) chat:(id)sender
{
    // Add conversation to client
    if(badInput) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Please check input values", @"Please check input values")
                                                        message:nil
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }
    NSMutableArray *connections = [_conversationsController.connections mutableCopy];
    
    IRCClient *client;
    int i;
    for (i=0; i<_conversationsController.connections.count; i++) {
        client = [_conversationsController.connections objectAtIndex:i];
        if([client.configuration.uniqueIdentifier isEqualToString:_conversation.client.configuration.uniqueIdentifier])
            break;
    }
    
    if(_addChannel) {
        [client addChannel:_conversation];
    } else {
        [client removeChannel:_conversation];
    }
    
    [connections setObject:client atIndexedSubscript:i];
    
    _conversationsController.connections = connections;
    [_conversationsController reloadData];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView
{
    NSInteger count = 8;
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
    if (indexPath.section == ConnectionTableSection && indexPath.row == 0) {
        
        PreferencesListViewController *connectionListViewController = [[PreferencesListViewController alloc] initWithStyle:UITableViewStyleGrouped];
        
        NSMutableArray *connections = [[NSMutableArray alloc] init];

        for (IRCClient *client in self.conversationsController.connections) {
            [connections addObject:client.configuration.connectionName];
        }

        connectionListViewController.title = NSLocalizedString(@"Connections", @"Connection");
        connectionListViewController.items = [connections copy];
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
    if (indexPath.section == ConnectionTableSection) {

        // Connection Picker
        UITableViewCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([UITableViewCell class]) andStyle:UITableViewCellStyleValue1];
        
        cell.textLabel.text = NSLocalizedString(@"Connection", @"Connection");
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.detailTextLabel.text = _conversation.client.configuration.connectionName;
        
        return cell;
        
    } else if (indexPath.section == ConversationTableSection) {
        if (indexPath.row == 0) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            if(self.addChannel)
                cell.textLabel.text = NSLocalizedString(@"Channel Name", @"Channel Name");
            else
                cell.textLabel.text = NSLocalizedString(@"Nick Name", @"Nick Name");
            cell.textField.text = @"";
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textEditAction = @selector(nameChanged:);
            return cell;
        } else if (indexPath.row == 1 && self.addChannel) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Password", @"Channel Password");
            cell.textField.text = @"";
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
    _conversation.client = [_conversationsController.connections objectAtIndex:sender.selectedItem];
    [self.tableView reloadData];
    if(_conversation.client != nil && _conversation.name) {
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
}

- (void) nameChanged:(PreferencesTextCell *)sender
{
    _conversation.name = sender.textField.text;
    
    if(sender.textField.text.length == 0) {
        sender.accessoryType = UITableViewCellAccessoryNone;
        self.navigationItem.rightBarButtonItem.enabled = NO;
        badInput = YES;
    } else if(sender.textField.text.length > 1) {
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
        if(_conversation.client != nil) {
            self.navigationItem.rightBarButtonItem.enabled = YES;
        }
    } else {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = YES;
    }
}

- (void) passwordChanged:(PreferencesTextCell *)sender
{
    //_conversation.password = sender.textField.text;
    if(sender.textField.text.length == 0) {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = NO;
        if(_conversation.client != nil) {
            self.navigationItem.rightBarButtonItem.enabled = YES;
        }
    } else if(sender.textField.text.length > 1) {
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    } else {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = YES;
    }
}
@end

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
#import "PreferencesTextCell.h"
#import "UITableView+Methods.h"

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
    self.navigationItem.rightBarButtonItem = chatButton;

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
        UITableViewController *connectionsViewController = [[UITableViewController alloc] initWithStyle:UITableViewStyleGrouped];
        
        connectionsViewController.title = NSLocalizedString(@"Connections", @"Connection");
        
        [self.navigationController pushViewController:connectionsViewController animated:YES];
        
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
        UITableViewCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([UITableViewCell class])];
        
        cell.textLabel.text = NSLocalizedString(@"Connection", @"Connection");
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        cell.detailTextLabel.text = @"";
        
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
    
- (void) nameChanged:(id)sender
{
    NSLog(@"name changed");
}

- (void) passwordChanged:(id)sender
{
    NSLog(@"password changed");    
}
@end

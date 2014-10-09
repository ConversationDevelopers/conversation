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


#import "EditConnectionViewController.h"
#import "PreferencesSwitchCell.h"
#import "PreferencesTextCell.h"
#import "IRCClient.h"

static unsigned short ServerTableSection = 0;
static unsigned short IdentityTableSection = 1;
static unsigned short AutomaticTableSection = 2;

@implementation EditConnectionViewController
- (id) init {
    if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
        return nil;
    return self;
}

- (void) viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"New Connection";
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    UIBarButtonItem *connectButton = [[UIBarButtonItem alloc] initWithTitle:@"Connect" style:UIBarButtonItemStylePlain target:self action:@selector(connect:)];
    [connectButton setTintColor:[UIColor lightGrayColor]];
    connectButton.enabled = NO;
    self.navigationItem.rightBarButtonItem = connectButton;
    
    _configuration = [[IRCConnectionConfiguration alloc] init];
}

- (void) viewWillAppear:(BOOL) animated {
    [super viewWillAppear:animated];
}

- (void) cancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) connect:(id)sender
{
    NSLog(@"Connect");
    NSMutableArray *connections = [self.connectionController.connections mutableCopy];
    [connections addObject:_configuration];
    self.connectionController.connections = [connections copy];
    [self.connectionController reloadData];
    IRCClient *client = [[IRCClient alloc] initWithConfiguration:_configuration];    
    [client connect];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (id) reuseCellWithClassName:(NSString *)identifier inTableView:(UITableView*)tableView
{
    id cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if(!cell)
        cell = [[NSClassFromString(identifier) alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    return cell;
}


#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView
{
    NSInteger count = 8;
    return count;
}
     
- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
    if (section == ServerTableSection)
        return 5;
    if (section == IdentityTableSection)
        return 5;
    if (section == AutomaticTableSection)
        return 3;
    return 0;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
    if (indexPath.section == AutomaticTableSection && indexPath.row == 2)
        return indexPath;
    return nil;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath
{
	if (indexPath.section == AutomaticTableSection && indexPath.row == 2) {
        UITableViewController *autoJoinViewController = [[UITableViewController alloc] init];
        
        autoJoinViewController.title = @"Join Rooms";
        
        [self.navigationController pushViewController:autoJoinViewController animated:YES];
        
        return;
    }
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
    if (section == ServerTableSection)
        return @"Server Details";
    if (section == IdentityTableSection)
        return @"Identity";
    if (section == AutomaticTableSection)
        return @"Automatic Actions";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == ServerTableSection) {
        if (indexPath.row == 0) {
            PreferencesTextCell *cell = [self reuseCellWithClassName:NSStringFromClass([PreferencesTextCell class]) inTableView:tableView];
            cell.textLabel.text = @"Description";
            cell.textField.text = @"";
            cell.textField.placeholder = @"Optional";
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textEditAction = @selector(descriptionChanged:);
            return cell;
        } else if (indexPath.row == 1) {
            PreferencesTextCell *cell = [self reuseCellWithClassName:NSStringFromClass([PreferencesTextCell class]) inTableView:tableView];
            cell.textLabel.text = @"Address";
            cell.textField.text = @"";
            cell.textField.placeholder = @"irc.example.com";
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textField.keyboardType = UIKeyboardTypeURL;            
            cell.textEditAction = @selector(serverChanged:);
            return cell;
        } else if (indexPath.row == 2) {
            PreferencesTextCell *cell = [self reuseCellWithClassName:NSStringFromClass([PreferencesTextCell class]) inTableView:tableView];
            cell.textLabel.text = @"Port";
            cell.textField.text = @"";
            cell.textField.placeholder = @"6667";
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            cell.textEditAction = @selector(portChanged:);
            return cell;
        } else if (indexPath.row == 3) {
            PreferencesTextCell *cell = [self reuseCellWithClassName:NSStringFromClass([PreferencesTextCell class]) inTableView:tableView];
            cell.textLabel.text = @"Password";
            cell.textField.text = @"";
            cell.textField.placeholder = @"Optional";
			cell.textField.secureTextEntry = YES;
            cell.textEditAction = @selector(passwordChanged:);
            return cell;
        } else if (indexPath.row == 4) {
            PreferencesSwitchCell *cell = [self reuseCellWithClassName:NSStringFromClass([PreferencesSwitchCell class]) inTableView:tableView];
            cell.switchAction = @selector(secureChanged:);
            cell.textLabel.text = @"Use SSL";
            return cell;
        }
    } else if (indexPath.section == IdentityTableSection) {
        if (indexPath.row == 0) {
            PreferencesTextCell *cell = [self reuseCellWithClassName:NSStringFromClass([PreferencesTextCell class]) inTableView:tableView];
            cell.textLabel.text = @"Nick Name";
            cell.textField.text = @"";
            cell.textField.placeholder = @"Guest";
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
			cell.textEditAction = @selector(nicknameChanged:);
            return cell;
        } else if (indexPath.row == 1) {
            PreferencesTextCell *cell = [self reuseCellWithClassName:NSStringFromClass([PreferencesTextCell class]) inTableView:tableView];
            cell.textLabel.text = @"Alt. Nick";
            cell.textField.text = @"";
            cell.textField.placeholder = @"Guest_";
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            cell.textEditAction = @selector(altnickChanged:);
            return cell;
        } else if (indexPath.row == 2) {
            PreferencesTextCell *cell = [self reuseCellWithClassName:NSStringFromClass([PreferencesTextCell class]) inTableView:tableView];
            cell.textLabel.text = @"User Name";
            cell.textField.text = @"";
            cell.textField.placeholder = @"Guest";
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            cell.textEditAction = @selector(realnameChanged:);
            return cell;
        } else if (indexPath.row == 3) {
            PreferencesTextCell *cell = [self reuseCellWithClassName:NSStringFromClass([PreferencesTextCell class]) inTableView:tableView];
            cell.textLabel.text = @"Real Name";
            cell.textField.text = @"";
            cell.textField.placeholder = @"Guest";
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            cell.textEditAction = @selector(realnameChanged:);
            return cell;
        } else if (indexPath.row == 4) {
            PreferencesTextCell *cell = [self reuseCellWithClassName:NSStringFromClass([PreferencesTextCell class]) inTableView:tableView];
            cell.textLabel.text = @"Nick Password";
            cell.textField.text = @"";
            cell.textField.placeholder = @"Optional";
			cell.textField.secureTextEntry = YES;
            cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textEditAction = @selector(nickpassChanged:);
            return cell;
        }
    } else if (indexPath.section == AutomaticTableSection) {
        if (indexPath.row == 0) {
            PreferencesSwitchCell *cell = [self reuseCellWithClassName:NSStringFromClass([PreferencesSwitchCell class]) inTableView:tableView];
            cell.switchAction = @selector(autoconnectChanged:);
            cell.textLabel.text = @"Connect at Launch";
            return cell;
        } else if (indexPath.row == 1) {
            PreferencesSwitchCell *cell = [self reuseCellWithClassName:NSStringFromClass([PreferencesSwitchCell class]) inTableView:tableView];
            cell.switchAction = @selector(showconsoleChanged:);
            cell.textLabel.text = @"Show Console";
            return cell;
        } else if (indexPath.row == 2) {
            UITableViewCell *cell = [self reuseCellWithClassName:NSStringFromClass([UITableViewCell class]) inTableView:tableView];
            
            cell.textLabel.text = @"Join Rooms";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
            cell.detailTextLabel.text = @"None";
            
            return cell;
        }
    }
    NSLog(@"Ooooops...");
    return nil;
}

- (void) descriptionChanged:(PreferencesTextCell*)sender
{
    NSLog(@"Description changed");
    _configuration.connectionName = sender.textField.text;
}

- (void) serverChanged:(PreferencesTextCell *)sender
{
    NSLog(@"Server changed");
    _configuration.serverAddress = sender.textField.text;
    // TODO: validate user input
    if([_configuration.serverAddress isEqualToString:@""] == NO && _configuration.connectionPort > 0) {
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
}

- (void) portChanged:(PreferencesTextCell *)sender
{
    NSLog(@"Port changed");
    _configuration.connectionPort = [sender.textField.text integerValue];
}

- (void) passwordChanged:(PreferencesTextCell *)sender
{
    NSLog(@"Password changed");
    _configuration.serverPasswordReference = sender.textField.text;
}

- (void) secureChanged:(PreferencesSwitchCell *)sender
{
    NSLog(@"Secure changed");
    _configuration.connectUsingSecureLayer = sender.on;
}

- (void) nicknameChanged:(PreferencesTextCell *)sender
{
    NSLog(@"Nickname changed");
    _configuration.primaryNickname = sender.textField.text;
}

- (void) altnickChanged:(PreferencesTextCell *)sender
{
    NSLog(@"Alt Nick changed");
    _configuration.secondaryNickname = sender.textField.text;
}

- (void) realnameChanged:(PreferencesTextCell *)sender
{
    NSLog(@"Realname changed");
    _configuration.realNameForRegistration = sender.textField.text;
}

- (void) nickpassChanged:(PreferencesTextCell *)sender
{
    NSLog(@"Nickpass changed");
    _configuration.authenticationPasswordReference = sender.textField.text;
}

- (void) autoconnectChanged:(PreferencesTextCell *)sender
{
    NSLog(@"Auto Connect changed");
    _configuration.automaticallyConnect = sender.textField.text;
}

- (void) showconsoleChanged:(PreferencesSwitchCell *)sender
{
    NSLog(@"Show Console changed");
    _configuration.showConsoleOnConnect = sender.on;

}
@end

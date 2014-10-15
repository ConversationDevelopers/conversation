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
#import "PreferencesListViewController.h"
#import "PreferencesSwitchCell.h"
#import "PreferencesTextCell.h"
#import "IRCClient.h"
#import "AppPreferences.h"
#import "NSString+Methods.h"
#import "UITableView+Methods.h"

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
    
    self.title = NSLocalizedString(@"New Connection", @"Title of edit connection view");
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    UIBarButtonItem *connectButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Connect", @"Left button in edit connection view")
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(connect:)];
    [connectButton setTintColor:[UIColor lightGrayColor]];
    connectButton.enabled = NO;
    badInput = NO;
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
    if(badInput) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Please check input values", @"Please check input values")
                                                        message:nil
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
        
    }
    IRCClient *client = [[IRCClient alloc] initWithConfiguration:_configuration];
    [[AppPreferences sharedPrefs] addConnectionConfiguration:_configuration];
    
    [self.conversationsController.connections addObject:client];
    [self.conversationsController reloadData];
    
    [client connect];
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark -

- (void) tableView:(UITableView *) tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *) indexPath {
    if (indexPath.section == ServerTableSection && indexPath.row == 1) {
        if (!_networks)
            _networks = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"networks" ofType:@"plist"]];
        
        PreferencesListViewController *listViewController = [[PreferencesListViewController alloc] initWithStyle:UITableViewStyleGrouped];

        NSMutableArray *networks = [[NSMutableArray alloc] init];
        NSUInteger selectedIndex = NSNotFound;
        for (NSDictionary *serverInfo in _networks) {
            NSString *name = serverInfo[@"Name"];
            NSAssert(name.length, @"Server name required.");
            [networks addObject:name];
        }
        
        listViewController.title = NSLocalizedString(@"Servers", @"Servers view title");
        listViewController.items = networks;
        listViewController.selectedItem = selectedIndex;
        listViewController.itemImage = [UIImage imageNamed:@"NetworkIcon"];
        listViewController.target = self;
        listViewController.action = @selector(defaultNetworkPicked:);
        
        [self.navigationController pushViewController:listViewController animated:YES];
    }

}

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
        
        autoJoinViewController.title = NSLocalizedString(@"Join Rooms", @"Title of auto join channels view");
        
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
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Description", @"Custom server name");
            cell.textField.text = _configuration.connectionName;
            cell.textField.placeholder = NSLocalizedString(@"Optional", @"User input is optional");
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textEditAction = @selector(descriptionChanged:);
            return cell;
        } else if (indexPath.row == 1) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Address", @"Server address");
            cell.textField.text = _configuration.serverAddress;
            cell.textField.placeholder = @"irc.example.com";
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textField.keyboardType = UIKeyboardTypeURL;
            cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
            cell.textEditAction = @selector(serverChanged:);
            return cell;
        } else if (indexPath.row == 2) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Port", @"Server port to connect to");
            cell.textField.text = @"";
            cell.textField.placeholder = @"6667";
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            cell.textEditAction = @selector(portChanged:);
            return cell;
        } else if (indexPath.row == 3) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Password", @"Server password");
            cell.textField.text = @"";
            cell.textField.placeholder = NSLocalizedString(@"Optional", @"User input is optional");
			cell.textField.secureTextEntry = YES;
            cell.textEditAction = @selector(passwordChanged:);
            return cell;
        } else if (indexPath.row == 4) {
            PreferencesSwitchCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesSwitchCell class])];
            cell.switchAction = @selector(secureChanged:);
            cell.textLabel.text = NSLocalizedString(@"Use SSL", @"Use ssl encrypted connection");
            return cell;
        }
    } else if (indexPath.section == IdentityTableSection) {
        if (indexPath.row == 0) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Nick Name", @"Nick name to use on IRC");
            cell.textField.text = @"";
            cell.textField.placeholder = @"Guest";
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
			cell.textEditAction = @selector(nicknameChanged:);
            return cell;
        } else if (indexPath.row == 1) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Alt. Nick", @"Alternative nick to use on IRC");
            cell.textField.text = @"";
            cell.textField.placeholder = @"Guest_";
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            cell.textEditAction = @selector(altnickChanged:);
            return cell;
        } else if (indexPath.row == 2) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"User Name", @"User name to use on IRC");
            cell.textField.text = @"";
            cell.textField.placeholder = @"Guest";
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            cell.textEditAction = @selector(usernameChanged:);
            return cell;
        } else if (indexPath.row == 3) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Real Name", @"Real name to use on IRC");
            cell.textField.text = @"";
            cell.textField.placeholder = @"Guest";
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            cell.textEditAction = @selector(realnameChanged:);
            return cell;
        } else if (indexPath.row == 4) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Nick Password", @"Nick authentication password");
            cell.textField.text = @"";
            cell.textField.placeholder = NSLocalizedString(@"Optional", @"User input is optional");
			cell.textField.secureTextEntry = YES;
            cell.textField.keyboardType = UIKeyboardTypeASCIICapable;
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textEditAction = @selector(nickpassChanged:);
            return cell;
        }
    } else if (indexPath.section == AutomaticTableSection) {
        if (indexPath.row == 0) {
            PreferencesSwitchCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesSwitchCell class])];
            cell.switchAction = @selector(autoconnectChanged:);
            cell.textLabel.text = NSLocalizedString(@"Connect at Launch", @"Connect on app launch");
            return cell;
        } else if (indexPath.row == 1) {
            PreferencesSwitchCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesSwitchCell class])];
            cell.switchAction = @selector(showconsoleChanged:);
            cell.textLabel.text = NSLocalizedString(@"Show Console", @"Show debug console on connect");
            return cell;
        } else if (indexPath.row == 2) {
            UITableViewCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([UITableViewCell class])];
            
            cell.textLabel.text = NSLocalizedString(@"Join Rooms", @"Title of auto join channels view");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            
            cell.detailTextLabel.text = NSLocalizedString(@"None", @"No entries");
            
            return cell;
        }
    }
    NSLog(@"Ooooops...");
    return nil;
}

- (void)defaultNetworkPicked:(PreferencesListViewController *)sender
{
    if (sender.selectedItem == NSNotFound)
        return;
    
    NSDictionary *serverInfo = _networks[sender.selectedItem];
    _configuration.connectionName = serverInfo[@"Name"];
    _configuration.serverAddress = serverInfo[@"Address"];
    

    self.navigationItem.rightBarButtonItem.enabled = YES;
    
    [self.tableView reloadData];
}

- (void) descriptionChanged:(PreferencesTextCell*)sender
{
    NSLog(@"Description changed");
    _configuration.connectionName = sender.textField.text;    
    if(sender.textField.text.length == 0) {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = NO;
    } else if(sender.textField.text.length > 2) {
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    } else {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = YES;
    }
}

- (void) serverChanged:(PreferencesTextCell *)sender
{
    NSLog(@"Server changed");

    // Check if the user input is a valid server address
    _configuration.serverAddress = sender.textField.text;
    if(sender.textField.text.length == 0) {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = NO;
    } else if([sender.textField.text isValidServerAddress]) {
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        self.navigationItem.rightBarButtonItem.enabled = YES;
        badInput = NO;
    } else {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = YES;
    }
}

- (void) portChanged:(PreferencesTextCell *)sender
{
    NSLog(@"Port changed");
    _configuration.connectionPort = 6667;
    if(sender.textField.text.length == 0) {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = NO;
    } else if(sender.textField.text.length > 1) {
        _configuration.connectionPort = [sender.textField.text integerValue];
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    } else {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = YES;
    }
    
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
    
    // Check if user input is a valid nickname
    _configuration.primaryNickname = sender.textField.text;
    if(sender.textField.text.length == 0) {
        sender.accessoryType = UITableViewCellAccessoryNone;
    } else if([sender.textField.text isValidNickname]) {
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    } else {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = YES;
    }
}

- (void) usernameChanged:(PreferencesTextCell *)sender
{
    NSLog(@"User Name changed");
    _configuration.usernameForRegistration = sender.textField.text;
    sender.accessoryType = UITableViewCellAccessoryNone;
    badInput = YES;
    
    if([sender.textField.text isValidUsername]) {
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    }
}

- (void) altnickChanged:(PreferencesTextCell *)sender
{
    NSLog(@"Alt Nick changed");
    _configuration.secondaryNickname = sender.textField.text;
    if(sender.textField.text.length == 0) {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = NO;
    } else if([sender.textField.text isValidNickname]) {
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    } else {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = YES;
    }
}

- (void) realnameChanged:(PreferencesTextCell *)sender
{
    NSLog(@"Realname changed");
    _configuration.realNameForRegistration = sender.textField.text;
    if(sender.textField.text.length == 0) {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = NO;
    } else if(sender.textField.text.length > 1) {
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    } else {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = YES;
    }

}

- (void) nickpassChanged:(PreferencesTextCell *)sender
{
    NSLog(@"Nickpass changed");
    _configuration.authenticationPasswordReference = sender.textField.text;
    if(sender.textField.text.length == 0) {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = NO;
    } else if(sender.textField.text.length > 1) {
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    } else {
        sender.accessoryType = UITableViewCellAccessoryNone;
        badInput = YES;
    }
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

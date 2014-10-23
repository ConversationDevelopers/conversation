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
#import "SSKeychain.h"

static unsigned short ServerTableSection = 0;
static unsigned short IdentityTableSection = 1;
static unsigned short AutomaticTableSection = 2;
static unsigned short EncodingTableSection = 3;

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
    
    NSString *buttonTitle = NSLocalizedString(@"Connect", @"Connect");

    
    if(_edit) {
        _configuration = _connection;
        buttonTitle = NSLocalizedString(@"Save", @"Save");
    } else {
        _connection = [[IRCConnectionConfiguration alloc] init];
        _configuration = [[IRCConnectionConfiguration alloc] init];
    }

    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:buttonTitle
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(save:)];
    [saveButton setTintColor:[UIColor lightGrayColor]];
    
    badInput = NO;
    self.navigationItem.rightBarButtonItem = saveButton;
    
}

- (void) viewWillAppear:(BOOL) animated {
    [super viewWillAppear:animated];
}

- (void) cancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) save:(id)sender
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
    
    // Store passwords in keychain
    NSString *identifier = [[NSUUID UUID] UUIDString];
    if(_configuration.serverPasswordReference) {
        [SSKeychain setPassword:_configuration.serverPasswordReference forService:@"conversation" account:identifier];
        _configuration.serverPasswordReference = identifier;
    }
    if(_configuration.authenticationPasswordReference) {
        [SSKeychain setPassword:_configuration.authenticationPasswordReference forService:@"conversation" account:identifier];
        _configuration.authenticationPasswordReference = identifier;
    }
    
    IRCClient *client = [[IRCClient alloc] initWithConfiguration:_configuration];

    // Does the connection already exist?
    if ([[AppPreferences sharedPrefs] hasConnectionWithIdentifier:_configuration.uniqueIdentifier]) {
        
        int x=0;
        NSArray *connections = self.conversationsController.connections;
        for (IRCClient *cl in connections) {
            if([cl.configuration.uniqueIdentifier isEqualToString:client.configuration.uniqueIdentifier]) {
                [self.conversationsController.connections setObject:client atIndexedSubscript:x];
                [[AppPreferences sharedPrefs] setConnectionConfiguration:_configuration atIndex:x];
                break;
            }
            x++;
        }
    } else {
        [self.conversationsController.connections addObject:client];
        [[AppPreferences sharedPrefs] addConnectionConfiguration:_configuration];        
        [client connect];
    }
    
    [self.conversationsController reloadData];
    [[AppPreferences sharedPrefs] save];
    [self dismissViewControllerAnimated:YES completion:nil];
}


#pragma mark -

- (void) tableView:(UITableView *) tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *) indexPath {
    if (indexPath.section == ServerTableSection && indexPath.row == 1) {
        if (!_networks)
            _networks = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"networks" ofType:@"plist"]];
        
        PreferencesListViewController *listViewController = [[PreferencesListViewController alloc] init];

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
    if (section == EncodingTableSection)
        return 1;
    return 0;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
    if (indexPath.section == AutomaticTableSection && indexPath.row == 2)
        return indexPath;
    if (indexPath.section == EncodingTableSection && indexPath.row == 0)
        return indexPath;
    return nil;
}

- (NSArray *) encodingList
{
    return @[@(NSUTF8StringEncoding),
             @(NSASCIIStringEncoding),
             @(NSISOLatin1StringEncoding),
             @(NSMacOSRomanStringEncoding),
             @(NSWindowsCP1252StringEncoding),
             @(NSISOLatin2StringEncoding),
             @(NSWindowsCP1250StringEncoding),
             @(NSWindowsCP1251StringEncoding),
             @(NSWindowsCP1253StringEncoding),
             @(NSISO2022JPStringEncoding),
             @(NSJapaneseEUCStringEncoding),
             @(NSShiftJISStringEncoding)];
}

static NSString *localizedNameOfStringEncoding(NSStringEncoding encoding)
{
    NSString *result = [NSString localizedNameOfStringEncoding:encoding];
    if (result.length)
        return result;
    
    switch (encoding) {
        case NSUTF8StringEncoding:
            return NSLocalizedString(@"Unicode (UTF-8)", "Encoding name");
        case NSASCIIStringEncoding:
            return NSLocalizedString(@"Western (ASCII)", "Encoding name");
        case NSISOLatin1StringEncoding:
            return NSLocalizedString(@"Western (ISO Latin 1)", "Encoding name");
        case NSMacOSRomanStringEncoding:
            return NSLocalizedString(@"Western (Mac OS Roman)", "Encoding name");
        case NSWindowsCP1252StringEncoding:
            return NSLocalizedString(@"Western (Windows Latin 1)", "Encoding name");
        case NSISOLatin2StringEncoding:
            return NSLocalizedString(@"Central European (ISO Latin 2)", "Encoding name");
        case NSWindowsCP1250StringEncoding:
            return NSLocalizedString(@"Central European (Windows Latin 2)", "Encoding name");
        case NSWindowsCP1251StringEncoding:
            return NSLocalizedString(@"Cyrillic (Windows)", "Encoding name");
        case NSWindowsCP1253StringEncoding:
            return NSLocalizedString(@"Greek (Windows)", "Encoding name");
        case NSISO2022JPStringEncoding:
            return NSLocalizedString(@"Japanese (ISO 2022-JP)", "Encoding name");
        case NSJapaneseEUCStringEncoding:
            return NSLocalizedString(@"Japanese (EUC)", "Encoding name");
        case NSShiftJISStringEncoding:
            return NSLocalizedString(@"Japanese (Windows, DOS)", "Encoding name");
    }
    
    NSCAssert(NO, @"Should not reach this point.");
    return @"";
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath
{
	if (indexPath.section == AutomaticTableSection && indexPath.row == 2) {
        PreferencesListViewController *listViewController = [[PreferencesListViewController alloc] init];
    
        NSMutableArray *items = [[NSMutableArray alloc] init];
        
        for (IRCChannel *channel in _configuration.channels) {
            [items addObject:channel];
        }
        
        listViewController.title = NSLocalizedString(@"Join Channels", @"Title of auto join channels view");
        listViewController.addItemText = NSLocalizedString(@"Add Channel", @"Title of add item label");
        listViewController.saveButtonTitle = NSLocalizedString(@"Save", @"Save");
        listViewController.noItemsText = NSLocalizedString(@"No Channels", @"No Channels");
        listViewController.itemImage = [UIImage imageNamed:@"ChannelIcon_small"];
        
        listViewController.items = items;
        listViewController.allowEditing = YES;
        listViewController.target = self;
        listViewController.action = @selector(autoJoinChannelsChanged:);
        
        [self.navigationController pushViewController:listViewController animated:YES];
        
        return;
    }
	if (indexPath.section == EncodingTableSection && indexPath.row == 0) {
        PreferencesListViewController *listViewController = [[PreferencesListViewController alloc] init];
        
        NSUInteger selectedEncodingIndex = NSNotFound;
        NSMutableArray *encodings = [[NSMutableArray alloc] init];
    
        for (NSNumber *encoding in [self encodingList]) {
            [encodings addObject:localizedNameOfStringEncoding(encoding.intValue)];
        }
        
        listViewController.title = NSLocalizedString(@"Encoding", @"Encoding view title");
        listViewController.items = encodings;
        listViewController.selectedItem = selectedEncodingIndex;
        
        listViewController.target = self;
        listViewController.action = @selector(encodingChanged:);
        
        [self.navigationController pushViewController:listViewController animated:YES];
        
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
    if (section == EncodingTableSection)
        return @"Encoding";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == ServerTableSection) {
        if (indexPath.row == 0) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Description", @"Custom server name");
            cell.textField.text = _configuration.connectionName;

            // Display default values as placeholder
            if(!_edit && [_connection.connectionName isEqualToString:_configuration.connectionName]) {
                cell.textField.text = @"";
                cell.textField.placeholder = _configuration.connectionName;
            }
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textEditAction = @selector(descriptionChanged:);
            return cell;
        } else if (indexPath.row == 1) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Address", @"Server address");
            cell.textField.text = _configuration.serverAddress;

            // Display default values as placeholder
            if(!_edit && [_connection.serverAddress isEqualToString:_configuration.serverAddress]) {
                cell.textField.text = @"";
                cell.textField.placeholder = _configuration.serverAddress;
            }
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textField.keyboardType = UIKeyboardTypeURL;
            cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
            cell.textEditAction = @selector(serverChanged:);
            return cell;
        } else if (indexPath.row == 2) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Port", @"Server port to connect to");
            cell.textField.text = [NSString stringWithFormat:@"%i", (int)_configuration.connectionPort];
            
            // Display default values as placeholder
            if(!_edit && _connection.connectionPort == _configuration.connectionPort) {
                cell.textField.text = @"";
                cell.textField.placeholder = [NSString stringWithFormat:@"%i", (int)_configuration.connectionPort];
            }
            cell.textField.keyboardType = UIKeyboardTypeNumberPad;
            cell.textEditAction = @selector(portChanged:);
            return cell;
        } else if (indexPath.row == 3) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Password", @"Server password");
            cell.textField.text = [SSKeychain passwordForService:@"conversation" account:_configuration.serverPasswordReference];
            cell.textField.placeholder = NSLocalizedString(@"Optional", @"User input is optional");
			cell.textField.secureTextEntry = YES;
            cell.textEditAction = @selector(passwordChanged:);
            return cell;
        } else if (indexPath.row == 4) {
            PreferencesSwitchCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesSwitchCell class])];
            cell.switchAction = @selector(secureChanged:);
            cell.switchControl.on = _configuration.connectUsingSecureLayer;
            cell.textLabel.text = NSLocalizedString(@"Use SSL", @"Use ssl encrypted connection");
            return cell;
        }
    } else if (indexPath.section == IdentityTableSection) {
        if (indexPath.row == 0) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Nick Name", @"Nick name to use on IRC");
            cell.textField.text = _configuration.primaryNickname;
            
            // Display default values as placeholder
            if(!_edit && [_connection.primaryNickname isEqualToString:_configuration.primaryNickname]) {
                cell.textField.text = @"";
                cell.textField.placeholder = _configuration.primaryNickname;
            }
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
			cell.textEditAction = @selector(nicknameChanged:);
            return cell;
        } else if (indexPath.row == 1) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Alt. Nick", @"Alternative nick to use on IRC");
            cell.textField.text = _configuration.secondaryNickname;
            
            // Display default values as placeholder
            if(!_edit && [_connection.secondaryNickname isEqualToString:_configuration.secondaryNickname]) {
                cell.textField.text = @"";
                cell.textField.placeholder = _configuration.secondaryNickname;
            }
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            cell.textEditAction = @selector(altnickChanged:);
            return cell;
        } else if (indexPath.row == 2) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"User Name", @"User name to use on IRC");
            cell.textField.text = _configuration.usernameForRegistration;
            
            // Display default values as placeholder
            if(!_edit && [_connection.usernameForRegistration isEqualToString:_configuration.usernameForRegistration]) {
                cell.textField.text = @"";
                cell.textField.placeholder = _configuration.usernameForRegistration;
            }
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            cell.textEditAction = @selector(usernameChanged:);
            return cell;
        } else if (indexPath.row == 3) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Real Name", @"Real name to use on IRC");
            cell.textField.text = _configuration.realNameForRegistration;
            
            // Display default values as placeholder
            if(!_edit && [_connection.realNameForRegistration isEqualToString:_configuration.realNameForRegistration]) {
                cell.textField.text = @"";
                cell.textField.placeholder = _configuration.realNameForRegistration;
            }
            cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            cell.textEditAction = @selector(realnameChanged:);
            return cell;
        } else if (indexPath.row == 4) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textLabel.text = NSLocalizedString(@"Nick Password", @"Nick authentication password");
            cell.textField.text = [SSKeychain passwordForService:@"conversation" account:_configuration.authenticationPasswordReference];
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
            if(_configuration.automaticallyConnect)
                cell.on = YES;
            cell.switchAction = @selector(autoconnectChanged:);
            cell.textLabel.text = NSLocalizedString(@"Connect at Launch", @"Connect on app launch");
            return cell;
        } else if (indexPath.row == 1) {
            PreferencesSwitchCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesSwitchCell class])];
            if(_configuration.showConsoleOnConnect)
                cell.on = YES;
            cell.switchAction = @selector(showconsoleChanged:);
            cell.textLabel.text = NSLocalizedString(@"Show Console", @"Show debug console on connect");
            return cell;
        } else if (indexPath.row == 2) {
            UITableViewCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([UITableViewCell class]) andStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = NSLocalizedString(@"Join Channels", @"Title of auto join channels view");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            if(_configuration.channels.count) {
                // Count channels with auto join turned on
                int i=0;
                for (IRCChannelConfiguration *channel in _configuration.channels) {
                    if(channel.autoJoin)
                        i++;
                }
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%i", i];
            } else {
                cell.detailTextLabel.text = NSLocalizedString(@"None", @"No entries");
            }
            return cell;
        }
    } else if (indexPath.section == EncodingTableSection) {
        if (indexPath.row == 0) {
            UITableViewCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([UITableViewCell class]) andStyle:UITableViewCellStyleValue1];
            cell.textLabel.text = NSLocalizedString(@"Encoding", @"Encoding");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.detailTextLabel.text = localizedNameOfStringEncoding(_configuration.socketEncodingType);
            return cell;
        }
    }
    NSCAssert(NO, @"Should not reach this point.");
    return nil;
}

- (void)defaultNetworkPicked:(PreferencesListViewController *)sender
{
    if (sender.selectedItem == NSNotFound)
        return;
    
    NSDictionary *serverInfo = _networks[sender.selectedItem];
    _configuration.connectionName = serverInfo[@"Name"];
    _configuration.serverAddress = serverInfo[@"Address"];
    
    [self.tableView reloadData];
}

- (void) descriptionChanged:(PreferencesTextCell*)sender
{
    sender.accessoryType = UITableViewCellAccessoryNone;
    badInput = YES;
    
    if(sender.textField.text.length == 0) {
        _configuration.connectionName = _connection.connectionName;
        badInput = NO;
    }
    
    if (sender.textField.text.length > 2) {
        _configuration.connectionName = sender.textField.text;
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    }
}

- (void) serverChanged:(PreferencesTextCell *)sender
{
    sender.accessoryType = UITableViewCellAccessoryNone;
    badInput = YES;
    
    if(sender.textField.text.length == 0) {
        _configuration.serverAddress = _connection.serverAddress;
        badInput = NO;
    }
    
    // Check if the user input is a valid server address
    if ([sender.textField.text isValidServerAddress]) {
        _configuration.serverAddress = sender.textField.text;
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    }
}

- (void) portChanged:(PreferencesTextCell *)sender
{
    sender.accessoryType = UITableViewCellAccessoryNone;
    badInput = YES;
    
    if(sender.textField.text.length == 0) {
        _configuration.connectionPort = _connection.connectionPort;
        badInput = NO;
    }
    
    if (sender.textField.text.length > 1) {
        _configuration.connectionPort = [sender.textField.text integerValue];
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    }
}

- (void) passwordChanged:(PreferencesTextCell *)sender
{
    _configuration.serverPasswordReference = sender.textField.text;
}

- (void) secureChanged:(PreferencesSwitchCell *)sender
{
    _configuration.connectUsingSecureLayer = sender.on;
}

- (void) nicknameChanged:(PreferencesTextCell *)sender
{
    
    sender.accessoryType = UITableViewCellAccessoryNone;
    badInput = YES;
    
    if(sender.textField.text.length == 0) {
        _configuration.primaryNickname = _connection.primaryNickname;
        badInput = NO;
    }
    
    if ([sender.textField.text isValidNickname:nil]) {
        _configuration.primaryNickname = sender.textField.text;
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    }
}

- (void) usernameChanged:(PreferencesTextCell *)sender
{
    sender.accessoryType = UITableViewCellAccessoryNone;
    badInput = YES;
    
    if(sender.textField.text.length == 0) {
        _configuration.usernameForRegistration = _connection.usernameForRegistration;
        badInput = NO;
    }

    if ([sender.textField.text isValidUsername]) {
        _configuration.usernameForRegistration = sender.textField.text;
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    }
}

- (void) altnickChanged:(PreferencesTextCell *)sender
{
    sender.accessoryType = UITableViewCellAccessoryNone;
    badInput = YES;
    
    if(sender.textField.text.length == 0) {
        _configuration.secondaryNickname = _connection.secondaryNickname;
        badInput = NO;
    }
    
    if ([sender.textField.text isValidNickname:nil]) {
        _configuration.secondaryNickname = sender.textField.text;
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    }
}

- (void) realnameChanged:(PreferencesTextCell *)sender
{
    sender.accessoryType = UITableViewCellAccessoryNone;
    badInput = YES;
    
    if(sender.textField.text.length == 0) {
        _configuration.realNameForRegistration = _connection.realNameForRegistration;
        badInput = NO;
    }
    
    if (sender.textField.text.length > 1) {
        _configuration.realNameForRegistration = sender.textField.text;
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    }
}

- (void) nickpassChanged:(PreferencesTextCell *)sender
{
    sender.accessoryType = UITableViewCellAccessoryNone;
    badInput = YES;
    
    if(sender.textField.text.length == 0) {
        _configuration.authenticationPasswordReference = _connection.authenticationPasswordReference;
        badInput = NO;
    }
    
    if (sender.textField.text.length > 1) {
        _configuration.authenticationPasswordReference = sender.textField.text;
        sender.accessoryType = UITableViewCellAccessoryCheckmark;
        badInput = NO;
    }
}

- (void) autoconnectChanged:(PreferencesSwitchCell *)sender
{
    _configuration.automaticallyConnect = sender.on;
}

- (void) showconsoleChanged:(PreferencesSwitchCell *)sender
{
    _configuration.showConsoleOnConnect = sender.on;

}

- (void)autoJoinChannelsChanged:(PreferencesListViewController *)sender
{
    _configuration.channels = sender.items;
    [self.tableView reloadData];
}

- (void)encodingChanged:(PreferencesListViewController *)sender
{
    if (sender.selectedItem == NSNotFound)
        return;
    
    _configuration.socketEncodingType = [[[self encodingList] objectAtIndex:sender.selectedItem] integerValue];
    
    [self.tableView reloadData];
}
@end

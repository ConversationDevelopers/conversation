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
#import "ChannelInfoViewController.h"
#import "IRCMessage.h"
#import "InputCommands.h"
#import "UITableView+Methods.h"
#import "PreferencesSwitchCell.h"
#import "PreferencesTextCell.h"


static unsigned short TopicTableSection = 0;
static unsigned short ModesTableSection = 1;

@implementation ChannelInfoViewController

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
    
    self.title = _channel.name;

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Save", @"Save")
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(save:)];
    [saveButton setTintColor:[UIColor lightGrayColor]];
    
    self.navigationItem.rightBarButtonItem = saveButton;
    
    _modeString = [[NSMutableString alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageReceived:) name:@"messageReceived" object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)save:(id)sender
{
    NSRange p = [_modeString rangeOfString:@"+p"];
    NSRange l = [_modeString rangeOfString:@"+l"];
    
    if (p.location != NSNotFound && l.location != NSNotFound) {
        if (p.location < l.location) {
            [_modeString appendFormat:@" %@", _password];
            [_modeString appendFormat:@" %@", _limit];
        } else if (p.location > l.location) {
            [_modeString appendFormat:@" %@", _limit];
            [_modeString appendFormat:@" %@", _password];
        }
    } else {
        if (_password)
            [_modeString appendFormat:@" %@", _password];
        if (_limit)
            [_modeString appendFormat:@" %@", _limit];
    }

    // Set Topic
    if (_topic.length)
        [InputCommands performCommand:[NSString stringWithFormat:@"TOPIC %@ :%@", _channel.name, _topic] inConversation:_channel];
    
    // Set Modes
    if (_modeString.length)
        [InputCommands performCommand:[NSString stringWithFormat:@"MODE %@ :%@", _channel.name, _modeString] inConversation:_channel];

    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)cancel:(id)sender
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)messageReceived:(NSNotification *)notification
{
    IRCMessage *message = notification.object;
    if ([message.conversation.configuration.uniqueIdentifier isEqualToString:_channel.configuration.uniqueIdentifier] &&
        message.messageType == ET_MODE)
        [self.tableView reloadData];
        
}
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == TopicTableSection)
        return NSLocalizedString(@"Topic", @"Topic");
    if (section == ModesTableSection)
        return NSLocalizedString(@"Modes", @"Modes");
    return nil;
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == TopicTableSection)
        return 1;
    if (section == ModesTableSection)
        return 8;
    return 0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == TopicTableSection) {
        UITableViewCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([UITableViewCell class]) andStyle:UITableViewCellStyleDefault];
        UITextView *textView = [[UITextView alloc] initWithFrame:cell.bounds];
        if ([_channel.topic isEqualToString:@"(No Topic)"] == NO)
            textView.text = _channel.topic;
        textView.delegate = self;
        [cell.contentView addSubview:textView];
        return cell;
    } else {
        if (indexPath.row == 0) {
            PreferencesSwitchCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesSwitchCell class])];
            cell.switchAction = @selector(sChanged:);
            cell.switchControl.on = [_channel.channelModes containsObject:@"s"];
            cell.textLabel.text = NSLocalizedString(@"Secret channel (+s)", @"Secret channel (+s)");
            return cell;
        } else if (indexPath.row == 1) {
            PreferencesSwitchCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesSwitchCell class])];
            cell.switchAction = @selector(pChanged:);
            cell.switchControl.on = [_channel.channelModes containsObject:@"p"];
            cell.textLabel.text = NSLocalizedString(@"Private channel (+p)", @"Private channel (+s)");
            return cell;
        } else if (indexPath.row == 2) {
            PreferencesSwitchCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesSwitchCell class])];
            cell.switchAction = @selector(nChanged:);
            cell.switchControl.on = [_channel.channelModes containsObject:@"n"];
            cell.textLabel.text = NSLocalizedString(@"No external messages (+n)", @"No external messages (+n)");
            return cell;
        } else if (indexPath.row == 3) {
            PreferencesSwitchCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesSwitchCell class])];
            cell.switchAction = @selector(tChanged:);
            cell.switchControl.on = [_channel.channelModes containsObject:@"t"];
            cell.textLabel.text = NSLocalizedString(@"Only operators can change topic (+t)", @"Only operators can change topic (+t)");
            return cell;
        } else if (indexPath.row == 4) {
            PreferencesSwitchCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesSwitchCell class])];
            cell.switchAction = @selector(iChanged:);
            cell.switchControl.on = [_channel.channelModes containsObject:@"i"];
            cell.textLabel.text = NSLocalizedString(@"Invite only (+i)", @"Invite only (+i)");
            return cell;
        } else if (indexPath.row == 5) {
            PreferencesSwitchCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesSwitchCell class])];
            cell.switchAction = @selector(mChanged:);
            cell.switchControl.on = [_channel.channelModes containsObject:@"m"];
            cell.textLabel.text = NSLocalizedString(@"Moderated channel (+m)", @"Moderated channel (+m)");
            return cell;
        } else if (indexPath.row == 6) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textEditAction = @selector(kChanged:);
            cell.textField.placeholder = NSLocalizedString(@"Enter Password", @"Enter Password");
            cell.textLabel.text = NSLocalizedString(@"Password (+k)", @"Password (+k)");
            return cell;
        } else if (indexPath.row == 7) {
            PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
            cell.textEditAction = @selector(lChanged:);
            cell.textField.placeholder = NSLocalizedString(@"Enter Limit", @"Enter Limit");            
            cell.textLabel.text = NSLocalizedString(@"Limit number of users (+l)", @"Limit number of users (+l)");
            return cell;
        }
        UITableViewCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([UITableViewCell class]) andStyle:UITableViewCellStyleDefault];
        return cell;
    }
    return nil;
}

- (BOOL) textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    _topic = textView.text;
    return YES;
}

- (void)sChanged:(PreferencesSwitchCell *)sender
{
    if (sender.on) {
        [_modeString appendString:@"+s"];
    } else {
        NSRange range = [_modeString rangeOfString:@"+s"];
        if (range.location != NSNotFound)
            [_modeString replaceCharactersInRange:range withString:@""];
        else
            [_modeString appendString:@"-s"];
    }
}

- (void)pChanged:(PreferencesSwitchCell *)sender
{
    if (sender.on) {
        [_modeString appendString:@"+p"];
    } else {
        NSRange range = [_modeString rangeOfString:@"+p"];
        if (range.location != NSNotFound)
            [_modeString replaceCharactersInRange:range withString:@""];
        else
            [_modeString appendString:@"-p"];
    }
}

- (void)nChanged:(PreferencesSwitchCell *)sender
{
    if (sender.on) {
        [_modeString appendString:@"+n"];
    } else {
        NSRange range = [_modeString rangeOfString:@"+n"];
        if (range.location != NSNotFound)
            [_modeString replaceCharactersInRange:range withString:@""];
        else
            [_modeString appendString:@"-n"];
    }
}

- (void)tChanged:(PreferencesSwitchCell *)sender
{
    if (sender.on) {
        [_modeString appendString:@"+t"];
    } else {
        NSRange range = [_modeString rangeOfString:@"+t"];
        if (range.location != NSNotFound)
            [_modeString replaceCharactersInRange:range withString:@""];
        else
            [_modeString appendString:@"-t"];
    }
}

- (void)iChanged:(PreferencesSwitchCell *)sender
{
    if (sender.on) {
        [_modeString appendString:@"+i"];
    } else {
        NSRange range = [_modeString rangeOfString:@"+i"];
        if (range.location != NSNotFound)
            [_modeString replaceCharactersInRange:range withString:@""];
        else
            [_modeString appendString:@"-i"];
    }
}

- (void)mChanged:(PreferencesSwitchCell *)sender
{
    if (sender.on) {
        [_modeString appendString:@"+m"];
    } else {
        NSRange range = [_modeString rangeOfString:@"+m"];
        if (range.location != NSNotFound)
            [_modeString replaceCharactersInRange:range withString:@""];
        else
            [_modeString appendString:@"-p"];
    }
}

- (void)kChanged:(PreferencesTextCell *)sender
{
    if (sender.textField.text.length) {
        [_modeString appendString:@"+k"];
        _password = sender.textField.text;
    } else {
        NSRange range = [_modeString rangeOfString:@"+k"];
        if (range.location != NSNotFound)
            [_modeString replaceCharactersInRange:range withString:@""];
        else
            [_modeString appendString:@"-k"];
        _password = @"";
    }
}

- (void)lChanged:(PreferencesTextCell *)sender
{
    if (sender.textField.text.length) {
        [_modeString appendString:@"+l"];
        _limit = sender.textField.text;
    } else {
        NSRange range = [_modeString rangeOfString:@"+l"];
        if (range.location != NSNotFound)
            [_modeString replaceCharactersInRange:range withString:@""];
        else
            [_modeString appendString:@"-l"];
        _limit = @"";
    }
}
@end

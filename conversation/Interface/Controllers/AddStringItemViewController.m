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


#import "AddStringItemViewController.h"
#import "PreferencesTextCell.h"
#import "UITableView+Methods.h"
#import "NSString+Methods.h"

@implementation AddStringItemViewController

- (id) init {
    if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
        return nil;
    
    _saveButtonTitle = NSLocalizedString(@"Save", @"Save");
    _textFieldLabelTitle = @"";
    
    return self;
}

- (void) viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.navigationBar.tintColor = [UIColor lightGrayColor];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
    self.navigationController.navigationBar.translucent = NO;
    
    if (!self.title) {
        self.title = NSLocalizedString(@"Add Item", @"Add Item");
    }
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithTitle:_saveButtonTitle
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(save:)];
    [saveButton setTintColor:[UIColor lightGrayColor]];
    self.navigationItem.rightBarButtonItem = saveButton;
    
}

- (void) cancel:(id)sender
{
    id obj = [self.navigationController popViewControllerAnimated:YES];
    if (!obj) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void) save:(id)sender
{
    if (_badInput) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Please check input values", @"Please check input values")
                                                        message:nil
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }
    if ([[UIApplication sharedApplication] sendAction:_action to:_target from:self forEvent:nil]) {
        [self.navigationController popViewControllerAnimated:YES];
    }
    
}

#pragma mark -

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView
{
    return 1;
}

- (NSInteger) tableView:(UITableView *) tableView numberOfRowsInSection:(NSInteger) section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    PreferencesTextCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([PreferencesTextCell class])];
    cell.textLabel.text = _textFieldLabelTitle;
    cell.textField.placeholder = @"Required";
    cell.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    cell.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    cell.textEditAction = @selector(valueChanged:);
    return cell;
}

- (void)valueChanged:(PreferencesTextCell *)sender
{
    if ([self.title rangeOfString:@"Ignore"].location != NSNotFound) {
        _badInput = YES;
        sender.accessoryType = UITableViewCellAccessoryNone;
        if ([sender.textField.text isValidWildcardIgnoreMask] || [sender.textField.text isValidNickname:nil]) {
            _badInput = NO;
            sender.accessoryType = UITableViewCellAccessoryCheckmark;
            _stringValue = sender.textField.text;
        }

        return;
    }
    if(sender.textField.text.length > 1) {
        _stringValue = sender.textField.text;
        self.navigationItem.rightBarButtonItem.enabled = YES;
    }
}
@end

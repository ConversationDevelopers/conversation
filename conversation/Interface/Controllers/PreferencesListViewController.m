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
#import "PreferencesListViewController.h"
#import "UITableView+Methods.h"
#import "AddConversationViewController.h"
#import "AddStringItemViewController.h"

@implementation PreferencesListViewController

- (id) init {
    if (!(self = [super initWithStyle:UITableViewStyleGrouped]))
        return nil;
    
    _items = [[NSMutableArray alloc] init];
    _allowEditing = NO;
    _allowSelection = YES;
    _allowReorder = YES;
    _selectedItem = NSNotFound;
    _addItemText = NSLocalizedString(@"Add Item", @"Add Item");
    _saveButtonTitle = NSLocalizedString(@"Save", @"Save");
    _noItemsText = NSLocalizedString(@"No Items", @"No Items");
    _addViewTitle = NSLocalizedString(@"Add Channel", @"Title of add channel item label");
    _addViewTextFieldLabelTitle = @"";
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    return self;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] sendAction:_action to:_target from:self forEvent:nil];
}

- (void) setAllowEditing:(BOOL) allowEditing
{
    _allowEditing = allowEditing;
    
    if (allowEditing) {
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
        _selectedItem = NSNotFound;
    } else {
        self.navigationItem.rightBarButtonItem = nil;
        self.editing = NO;
    }
}

- (void) setSelectedItem:(NSInteger) index
{
    _selectedItem = (_allowEditing ? NSNotFound : index);
}

- (void) setItemImage:(UIImage *) image
{
    _itemImage = image;
    
    [self.tableView reloadData];
}

- (void) setItems:(NSArray *) items
{
    _pendingChanges = NO;
    _items = [items mutableCopy];
    
    [self.tableView reloadData];
}

- (void) setEditing:(BOOL) editing animated:(BOOL) animated
{
    [super setEditing:editing animated:animated];
    
    if (_items.count) {
        NSArray *indexPaths = @[[NSIndexPath indexPathForRow:_items.count inSection:0]];
        if (editing) [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
        else [self.tableView deleteRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
    } else {
        [self.tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.25];
    }
    
    if (!editing && _pendingChanges && _action && (!_target || [_target respondsToSelector:_action]))
        if ([[UIApplication sharedApplication] sendAction:_action to:_target from:self forEvent:nil])
            _pendingChanges = NO;
}

- (void) editItemAtIndex:(NSUInteger)index
{
    if (_type == Channels) {
        AddConversationViewController *editViewController = [[AddConversationViewController alloc] init];
        editViewController.navigationItem.leftBarButtonItem.enabled = YES;
        editViewController.title = _addViewTitle;
        editViewController.saveButtonTitle = _saveButtonTitle;
        editViewController.target = self;
        editViewController.action = @selector(conversationAdded:);
        [self.navigationController pushViewController:editViewController animated:YES];
    } else if (_type == Strings) {
        AddStringItemViewController *editViewController = [[AddStringItemViewController alloc] init];
        editViewController.title = _addViewTitle;
        editViewController.saveButtonTitle = _saveButtonTitle;
        editViewController.textFieldLabelTitle = _addViewTextFieldLabelTitle;
        editViewController.target = self;
        editViewController.action = @selector(stringAdded:);
        [self.navigationController pushViewController:editViewController animated:YES];        
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.editing)
        return (_items.count + 1);
    if (!_items.count)
        return 1;
    return _items.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView reuseCellWithIdentifier:NSStringFromClass([UITableViewCell class])];
	
    if (indexPath.row < (NSInteger)_items.count) {
        id item = _items[indexPath.row];
        if ([item isKindOfClass:[NSString class]]) {
            cell.textLabel.text = item;
        } else if ([item isKindOfClass:[IRCChannelConfiguration class]]) {
            cell.textLabel.text = [item name];
            if([item autoJoin])
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            else
                cell.accessoryType = UITableViewCellAccessoryNone;
        }
        cell.imageView.image = self.itemImage;
    } else if (self.editing) {
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.text = _addItemText;
        cell.imageView.image = nil;
    } else {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textColor = [UIColor lightGrayColor];
        cell.textLabel.text = _noItemsText;
        cell.imageView.image = nil;
    }
    return cell;
}

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath
{
    if (_allowSelection)
        return indexPath;
    else
        return nil;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_allowEditing && indexPath.row < _items.count && !self.editing) {
        id item = _items[indexPath.row];
        if([item isKindOfClass:[IRCChannelConfiguration class]]) {
            BOOL selected = [item autoJoin];
            if (selected) {
                [item setAutoJoin:NO];
                [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryNone];
            } else {
                [item setAutoJoin:YES];
                [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
            }
            [_items setObject:item atIndexedSubscript:indexPath.row];
        }
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else {
        _selectedItem = indexPath.row;

        if (!_target || [_target respondsToSelector:_action])
            if ([[UIApplication sharedApplication] sendAction:_action to:_target from:self forEvent:nil])
                [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

- (UITableViewCellEditingStyle) tableView:(UITableView *) tableView editingStyleForRowAtIndexPath:(NSIndexPath *) indexPath
{
    if (!self.editing)
        return UITableViewCellEditingStyleInsert;
    
    if (indexPath.row >= (NSInteger)_items.count)
        return UITableViewCellEditingStyleInsert;
    
    return UITableViewCellEditingStyleDelete;
}

- (BOOL) tableView:(UITableView *) tableView canEditRowAtIndexPath:(NSIndexPath *) indexPath
{
    return _allowEditing;
}

- (void) tableView:(UITableView *) tableView commitEditingStyle:(UITableViewCellEditingStyle) editingStyle forRowAtIndexPath:(NSIndexPath *) indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_items removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:YES];
        _pendingChanges = YES;
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        [self editItemAtIndex:indexPath.row];
    }
}

- (BOOL) tableView:(UITableView *) tableView canMoveRowAtIndexPath:(NSIndexPath *) indexPath
{
    if (_allowReorder)
        return (indexPath.row < (NSInteger)_items.count);
    else
        return NO;
}

- (NSIndexPath *) tableView:(UITableView *) tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *) sourceIndexPath toProposedIndexPath:(NSIndexPath *) proposedDestinationIndexPath
{
    if (proposedDestinationIndexPath.row >= (NSInteger)_items.count)
        return [NSIndexPath indexPathForRow:(_items.count - 1) inSection:0];
    return proposedDestinationIndexPath;
}

- (void) tableView:(UITableView *) tableView moveRowAtIndexPath:(NSIndexPath *) fromIndexPath toIndexPath:(NSIndexPath *) toIndexPath
{
    if (toIndexPath.row >= (NSInteger)_items.count)
        return;
    
    id item = _items[fromIndexPath.row];
    [_items removeObject:item];
    [_items insertObject:item atIndex:toIndexPath.row];
    
    _pendingChanges = YES;
}

- (void)stringAdded:(AddStringItemViewController *)sender
{
    if (!sender.stringValue)
        return;
    
    [_items addObject:sender.stringValue];
    [self.tableView reloadData];
}

- (void)conversationAdded:(AddConversationViewController *)sender
{
    [_items addObject:sender.configuration];
    [self.tableView reloadData];
}

@end

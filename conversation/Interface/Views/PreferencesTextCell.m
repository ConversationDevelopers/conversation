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


#import "PreferencesTextCell.h"
#import "InterfaceLayoutDefinitions.h"

static PreferencesTextCell *currentEditingCell;

@implementation PreferencesTextCell
+ (PreferencesTextCell *) currentEditingCell {
    return currentEditingCell;
}

- (id) initWithStyle:(UITableViewCellStyle) style reuseIdentifier:(NSString *) reuseIdentifier
{
    if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
        return nil;
    
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    
    _textField = [[UITextField alloc] initWithFrame:CGRectZero];
    
    _textField.delegate                         = self;
    _textField.textAlignment                    = NSTextAlignmentLeft;
    _textField.contentVerticalAlignment         = UIControlContentVerticalAlignmentTop;
    _textField.font                             = [UIFont systemFontOfSize:LABEL_FONT_SIZE];
    _textField.adjustsFontSizeToFitWidth        = YES;
    _textField.minimumFontSize                  = LABEL_MIN_FONT_SIZE;
    _textField.textColor                        = [InterfaceLayoutDefinitions preferenceLabelTextColour];
    _textField.enablesReturnKeyAutomatically    = NO;
    _textField.returnKeyType                    = UIReturnKeyDone;
    
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter addObserver:self selector:@selector(textFieldDidChange:) name:UITextFieldTextDidChangeNotification object:nil];
    
    CGRect subviewFrame = _textField.frame;
    subviewFrame.size.height = [_textField sizeThatFits:_textField.bounds.size].height;
    _textField.frame = subviewFrame;
    
    _enabled = YES;
    
    [self.contentView addSubview:_textField];
    
    return self;
}

- (void) dealloc
{
    [_textField resignFirstResponder];
    _textField.delegate = nil;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    if (self.selectionStyle == UITableViewCellSelectionStyleNone)
        return;
    
    if (selected)
        _textField.textColor = [InterfaceLayoutDefinitions textFieldSelectedColour];
    if (_enabled)
        _textField.textColor = [InterfaceLayoutDefinitions textFieldDisabledColour];
    else
        _textField.textColor = [InterfaceLayoutDefinitions textFieldColour];
}

- (void) prepareForReuse {
    [super prepareForReuse];
    
    _enabled = YES;
    _textEditAction = NULL;
    
    _textField.text                     = @"";
    _textField.placeholder              = @"";
    _textField.keyboardType             = UIKeyboardTypeDefault;
    _textField.autocapitalizationType   = UITextAutocapitalizationTypeSentences;
    _textField.autocorrectionType       = UITextAutocorrectionTypeDefault;
    _textField.textColor                = [InterfaceLayoutDefinitions textFieldColour];
    _textField.clearButtonMode          = UITextFieldViewModeNever;
    _textField.enabled                  = YES;
    _textField.secureTextEntry          = NO;
    
    [_textField endEditing:YES];
    [_textField resignFirstResponder];
    
    self.textLabel.text = @"";
    self.accessoryType = UITableViewCellAccessoryNone;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    
    _textField.textColor = [InterfaceLayoutDefinitions descriptionLabelColour];
    
    CGRect contentRect = self.contentView.frame;
    
    UILabel *label = self.textLabel;
    
    BOOL showingLabel = (label.text.length > 0);
    
    if (showingLabel) {
        label.hidden = NO;
        
        CGRect frame = label.frame;
        frame.size.width = [label sizeThatFits:label.bounds.size].width;
        label.frame = frame;
    } else {
        label.hidden = YES;
    }
    
    _textField.hidden = NO;
    
    const CGFloat leftMargin = PREFERENCE_CELL_MARGIN_SIDE;
    CGFloat rightMargin      = PREFERENCE_CELL_MARGIN_SIDE;
    
    if (_textField.clearButtonMode == UITextFieldViewModeAlways)
        rightMargin = 0.;
    else if (self.accessoryType == UITableViewCellAccessoryDisclosureIndicator)
        rightMargin = 4.;
    
    CGRect frame = _textField.frame;
    NSAssert(frame.size.height > 0., @"A height is assumed to be set in initWithFrame:.");
    frame.origin.x = (showingLabel ? MAX(CGRectGetMaxX(label.frame) + leftMargin, 125.) : leftMargin);
    frame.origin.y = round((contentRect.size.height / 2.) - (frame.size.height / 2.));
    frame.size.width = (contentRect.size.width - frame.origin.x - rightMargin);
    _textField.frame = frame;
}

- (void) setEnabled:(BOOL) enabled {
    _textField.enabled = enabled;
    
    _enabled = enabled;
    
    if (!_enabled) _textField.textColor = [InterfaceLayoutDefinitions textFieldDisabledColour];
    else _textField.textColor           = [InterfaceLayoutDefinitions textFieldColour];
}

#pragma mark -

- (void)textFieldDidChange:(id)sender
{
    if (self.textEditAction && currentEditingCell == self)
        [[UIApplication sharedApplication] sendAction:self.textEditAction to:nil from:self forEvent:nil];
}

- (BOOL) textFieldShouldBeginEditing:(UITextField *) textField {
    return _enabled;
}

- (BOOL) textFieldShouldReturn:(UITextField *) textField {
    [textField resignFirstResponder];
    return YES;
}

- (void) textFieldDidBeginEditing:(UITextField *) textField {
    currentEditingCell = self;
}

- (void) textFieldDidEndEditing:(UITextField *) textField {
    if (self.textFieldBlock)
        self.textFieldBlock(textField);
    
    if (currentEditingCell == self) {
        currentEditingCell = nil;
    }
}


@end

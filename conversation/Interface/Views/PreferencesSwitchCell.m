/*
 Copyright (c) 2014-2015, Tobias Pollmann, Alex Sørlie Glomsaas.
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

#import "PreferencesSwitchCell.h"
#import "InterfaceLayoutDefinitions.h"

@implementation PreferencesSwitchCell
- (id) initWithStyle:(UITableViewCellStyle) style reuseIdentifier:(NSString *) reuseIdentifier
{
    if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
        return nil;
    
    // Workaround the font showing up larger in edit vs new. Not sure why...
    self.textLabel.font = [UIFont systemFontOfSize:LABEL_FONT_SIZE];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _switchControl = [[UISwitch alloc] initWithFrame:CGRectZero];
    [self.contentView addSubview:_switchControl];
    [_switchControl addTarget:self action:@selector(valueChanged:) forControlEvents:UIControlEventValueChanged];
    
    return self;
}

#pragma mark -

- (void) valueChanged:(id) sender
{
    if (self.switchControlBlock)
        self.switchControlBlock(sender);
}

- (SEL) switchAction
{
    NSArray *actions = [_switchControl actionsForTarget:nil forControlEvent:UIControlEventValueChanged];
    if (!actions.count) return NULL;
    return NSSelectorFromString(actions[0]);
}

- (void) setSwitchAction:(SEL) action
{
    [_switchControl removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
    [_switchControl addTarget:nil action:action forControlEvents:UIControlEventValueChanged];
}

- (BOOL) isOn
{
    return _switchControl.on;
}

- (void) setOn:(BOOL) on
{
    _switchControl.on = on;
}

- (void) prepareForReuse
{
    [super prepareForReuse];
    
    self.textLabel.text = @"";
    self.on = NO;
}

- (void) layoutSubviews
{
    [super layoutSubviews];
    
    CGSize switchSize = _switchControl.frame.size;
    CGRect contentRect = self.contentView.frame;
    
    UILabel *label = self.textLabel;
    
    CGRect frame = label.frame;
    frame.size.width = contentRect.size.width - switchSize.width - 30.;
    label.frame = frame;
    
    frame = _switchControl.frame;
    frame.origin.y = round((contentRect.size.height / 2.) - (switchSize.height / 2.));
    frame.origin.x = contentRect.size.width - switchSize.width - 10.;
    _switchControl.frame = frame;
}
@end

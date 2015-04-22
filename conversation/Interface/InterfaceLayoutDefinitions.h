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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface InterfaceLayoutDefinitions : NSObject

#define LABEL_FONT_SIZE                 17.0
#define LABEL_MIN_FONT_SIZE             14.0
#define LABEL_SMALL_SIZE                10.0

#define PREFERENCE_CELL_MARGIN_SIDE     10.0

#define DISABLED_OPACITY_LEVEL          0.5
#define ENABLED_OPACITY_LEVEL           1.0
#define HIDDEN_OPACITY_LEVEL            0.0

+ (UIColor *) labelTextColour;
+ (UIColor *) largeLabelTextColour;
+ (UIColor *) preferenceLabelTextColour;
+ (UIColor *) textFieldColour;
+ (UIColor *) textFieldDisabledColour;
+ (UIColor *) textFieldSelectedColour;
+ (UIColor *) descriptionLabelColour;
+ (UIColor *) highlightedMessageBackgroundColour;

+ (UIFont *) standardLabelFont;
+ (UIFont *) largeLabelFont;
+ (UIFont *) eventMessageFont;
+ (UIFont *) eventMessageNicknameFont;

@end

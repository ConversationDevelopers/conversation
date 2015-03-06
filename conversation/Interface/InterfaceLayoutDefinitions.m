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

#import "InterfaceLayoutDefinitions.h"

@implementation InterfaceLayoutDefinitions

+ (UIColor *) labelTextColour
{
    return [UIColor lightGrayColor];
}

+ (UIColor *) largeLabelTextColour
{
    return [UIColor darkGrayColor];
}

+ (UIColor *) preferenceLabelTextColour
{
    return [UIColor colorWithRed:0.11 green:0.129 blue:0.188 alpha:ENABLED_OPACITY_LEVEL];
}

+ (UIColor *) textFieldColour
{
    return [UIColor colorWithRed:(64. / 255.) green:(118. / 255.) blue:(251. / 255.) alpha:ENABLED_OPACITY_LEVEL];
}

+ (UIColor *) textFieldDisabledColour
{
    return [UIColor colorWithRed:(64. / 255.) green:(118. / 255.) blue:(251. / 255.) alpha:DISABLED_OPACITY_LEVEL];
}

+ (UIColor *) textFieldSelectedColour
{
    return [UIColor whiteColor];
}

+ (UIColor *) descriptionLabelColour
{
    return [UIColor colorWithRed:0.11 green:0.129 blue:0.188 alpha:ENABLED_OPACITY_LEVEL];
}

+ (UIColor *) highlightedMessageBackgroundColour
{
    return [UIColor colorWithRed:0.714 green:0.882 blue:0.675 alpha:1];
}

+ (UIFont *) standardLabelFont
{
    return [UIFont fontWithName:@"Helvetica Neue" size:LABEL_MIN_FONT_SIZE];
}

+ (UIFont *) largeLabelFont
{
    return [UIFont boldSystemFontOfSize:LABEL_FONT_SIZE];
}

+ (UIFont *) eventMessageFont
{
    return [UIFont systemFontOfSize:LABEL_SMALL_SIZE];
}

+ (UIFont *) eventMessageNicknameFont
{
    return [UIFont boldSystemFontOfSize:LABEL_SMALL_SIZE];
}

@end

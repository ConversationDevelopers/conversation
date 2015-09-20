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

#import <sys/utsname.h>
#import <UIKit/UIKit.h>
#import "DeviceInformation.h"


@implementation DeviceInformation

+ (NSString*) deviceName
{
    struct utsname systemInfo;
    
    uname(&systemInfo);
    
    NSString* code = [NSString stringWithCString:systemInfo.machine
                                        encoding:NSUTF8StringEncoding];
    
    static NSDictionary* deviceNamesByCode = nil;
    
    if (!deviceNamesByCode) {
        
        deviceNamesByCode = @{  @"i386"         :@"Simulator",
                                @"x86_64"       :@"Simulator",
                                @"iPhone3,1"    :@"iPhone 4",        //
                                @"iPhone4,1"    :@"iPhone 4S",       //
                                @"iPhone5,1"    :@"iPhone 5",        // (model A1428, AT&T/Canada)
                                @"iPhone5,2"    :@"iPhone 5",        // (model A1429, everything else)
                                @"iPhone5,3"    :@"iPhone 5c",       // (model A1456, A1532 | GSM)
                                @"iPhone5,4"    :@"iPhone 5c",       // (model A1507, A1516, A1526 (China), A1529 | Global)
                                @"iPhone6,1"    :@"iPhone 5s",       // (model A1433, A1533 | GSM)
                                @"iPhone6,2"    :@"iPhone 5s",       // (model A1457, A1518, A1528 (China), A1530 | Global)
                                @"iPhone7,1"    :@"iPhone 6 Plus",   //
                                @"iPhone7,2"    :@"iPhone 6",        //
                                @"iPhone8,1"    :@"iPhone 6S",   //
                                @"iPhone8,2"    :@"iPhone 6S Plus",        //
                                @"iPod5,1"      :@"iPod Touch (5th Generation)",      // (5th Generation iPod Tocuh)
                                @"iPod7,1"      :@"iPod Touch (6th Generation)",        // (6th Generation iPod Touch)
                                @"iPad2,1"      :@"iPad 2",          //
                                @"iPad3,1"      :@"iPad (3rd Generation)",            // (3rd Generation)
                                @"iPad3,4"      :@"iPad (4th Generation)",            // (4th Generation)
                                @"iPad2,5"      :@"iPad Mini",       // (Original)
                                @"iPad4,1"      :@"iPad Air",        // 5th Generation iPad (iPad Air) - Wifi
                                @"iPad4,2"      :@"iPad Air",        // 5th Generation iPad (iPad Air) - Cellular
                                @"iPad4,4"      :@"iPad Mini (2nd Generation)",       // (2nd Generation iPad Mini - Wifi)
                                @"iPad4,5"      :@"iPad Mini (2nd Generation)",        // (2nd Generation iPad Mini - Cellular)
                                @"iPad4,6"      :@"iPad Mini (2nd Generation)",        // (2nd Generation iPad Mini - China)
                                @"iPad4,7"      :@"iPad Mini (3rd Generation)",        // (3nd Generation iPad Mini - Wifi)
                                @"iPad4,8"      :@"iPad Mini (3rd Generation)",        // (3nd Generation iPad Mini - Cellular)
                                @"iPad4,9"      :@"iPad Mini (3rd Generation)",         // (3nd Generation iPad Mini - China)
                                @"iPad5,1"      :@"iPad Mini (4th Generation)",         // (3nd Generation iPad Mini - Wifi)
                                @"iPad5,2"      :@"iPad Mini (4th Generation)",         // (3nd Generation iPad Mini - Cellular)
                                @"iPad5,3"      :@"iPad Air (2nd Generation)",        // (2nd Generation iPad Air - Wifi)
                                @"iPad5,4"      :@"iPad Air (2nd Generation)"        // (2nd Generation iPad Air - Cellular)
                              };
    }
    
    NSString* deviceName = [deviceNamesByCode objectForKey:code];
    
    if (!deviceName) {
        // Not found on database. At least guess main device type from string contents:
        
        if ([code rangeOfString:@"iPod"].location != NSNotFound) {
            deviceName = @"iPod Touch";
        }
        else if([code rangeOfString:@"iPad"].location != NSNotFound) {
            deviceName = @"iPad";
        }
        else if([code rangeOfString:@"iPhone"].location != NSNotFound){
            deviceName = @"iPhone";
        }
    }
    
    return deviceName;
}

+ (NSString *)firmwareVersion
{
    return [[UIDevice currentDevice] systemVersion];
}

+ (NSString *)orientation
{
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
        return @"Landscape";
    
    return @"Portrait";
}

+ (NSString *)batteryLevel
{
    UIDevice *device = [UIDevice currentDevice];
    device.batteryMonitoringEnabled = YES;
    
    float batteryLevel = [[UIDevice currentDevice] batteryLevel];

    return [[NSString stringWithFormat:@"%.f", batteryLevel*100] stringByAppendingString:@"%"];
    
}

@end

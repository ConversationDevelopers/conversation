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


#import "AppPreferences.h"

@implementation AppPreferences

#pragma mark Singleton Methods

+ (id)sharedPrefs
{
    // Create singleton object
    static AppPreferences *prefs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        prefs = [[self alloc] init];
    });
    return prefs;
}

- (id)init
{
    if (self = [super init]) {
        self.preferences = [[NSUserDefaults standardUserDefaults] objectForKey:@"preferences"];
        if(!self.preferences) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            self.preferences = dict;
        }
    }
    return self;
}

- (void)addConnectionConfiguration:(IRCConnectionConfiguration *)configuration
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    NSMutableArray *configurations;
    if([self.preferences objectForKey:@"configurations"] != nil) {
        configurations = [[self.preferences objectForKey:@"configurations"] mutableCopy];
    } else {
        configurations = [[NSMutableArray alloc] init];
    }
    
    [configurations addObject:[configuration getDictionary]];
    dict[@"configurations"] = configurations;
    self.preferences = dict;
}

- (void)deleteConnectionWithIdentifier:(NSString *)identifier
{
    NSMutableDictionary *dict = [self.preferences mutableCopy];
    NSArray *connections = [self.preferences objectForKey:@"configurations"];
    NSMutableArray *newcons = [[NSMutableArray alloc] init];
    for (NSDictionary *config in connections) {
        if([config[@"uniqueIdentifier"] isEqualToString:identifier] == NO) {
            [newcons addObject:config];
        }
    }
    dict[@"configurations"] = newcons;
    self.preferences = [dict copy];
}

- (void)save
{
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    [userDefault setObject:self.preferences forKey:@"preferences"];
    [userDefault synchronize];
}

- (NSArray *)getConnectionConfigurations
{
    return [self.preferences objectForKey:@"configurations"];
}

- (void)dealloc {
    // Should never be called, but just here for clarity really.
}


@end

//
//  AppPreferences.m
//  conversation
//
//  Created by Toby P on 09/10/14.
//  Copyright (c) 2014 conversation. All rights reserved.
//

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

- (id)init {
    if (self = [super init]) {
        self.preferences = [[NSUserDefaults standardUserDefaults] objectForKey:@"preferences"];
        if(!self.preferences) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            self.preferences = dict;
        }
    }
    return self;
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

//
//  AppPreferences.h
//  conversation
//
//  Created by Toby P on 09/10/14.
//  Copyright (c) 2014 conversation. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IRCConnectionConfiguration.h"

@interface AppPreferences : NSObject {
    NSString *_preferencesPath;
}

+ (id)sharedPrefs;
- (void)addConnectionConfiguration:(IRCConnectionConfiguration *)configuration;
- (NSArray *)getConnectionConfigurations;
- (void)save;

@property (nonatomic, retain) NSDictionary *preferences;


@end

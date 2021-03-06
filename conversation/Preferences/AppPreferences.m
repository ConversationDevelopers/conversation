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


#import "AppPreferences.h"
#import "IRCChannel.h"

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
        [self loadEmoticons];
    }
    return self;
}

- (BOOL)hasConnectionWithIdentifier:(NSString *)identifier
{
    for (NSDictionary *con in self.preferences[@"configurations"]) {
        if ([con[@"uniqueIdentifier"] isEqualToString:identifier])
            return YES;
    }
    
    return NO;
}

- (void)loadEmoticons
{
    NSMutableDictionary *prefs = [self.preferences mutableCopy];
    NSDictionary *emoticons = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"emoticons" ofType:@"plist"]];
    prefs[@"emoticons"] = emoticons;
    self.preferences = prefs;
}

- (NSDictionary *)getEmoticons
{
    return self.preferences[@"emoticons"];
}

- (void)setConnectionConfiguration:(IRCConnectionConfiguration *)configuration atIndex:(NSInteger)index
{
    NSMutableDictionary *prefs = [self.preferences mutableCopy];
    NSMutableArray *configurations = [self.preferences[@"configurations"] mutableCopy];
    [configurations setObject:configuration.getDictionary atIndexedSubscript:index];
    prefs[@"configurations"] = configurations;
    self.preferences = prefs;
}

- (void)setChannels:(NSArray *)channels andQueries:(NSArray *)queries forConnectionConfiguration:(IRCConnectionConfiguration *)connection
{
    NSMutableDictionary *prefs = [self.preferences mutableCopy];
    NSMutableArray *configurations;
    if([self.preferences objectForKey:@"configurations"] != nil) {
        configurations = [[self.preferences objectForKey:@"configurations"] mutableCopy];
    } else {
        configurations = [[NSMutableArray alloc] init];
    }
    
    int i=0;
    for (NSDictionary *d in configurations) {
        if([d[@"uniqueIdentifier"] isEqualToString:connection.uniqueIdentifier]) {
            NSMutableDictionary *dict = [d mutableCopy];
            NSMutableArray *c = [[NSMutableArray alloc] init];
            for (IRCChannel *channel in channels) {
                [c addObject:channel.configuration.getDictionary];
            }
            dict[@"channels"] = c;
            NSMutableArray *q = [[NSMutableArray alloc] init];
            for (IRCConversation *query in queries) {
                [q addObject:query.configuration.getDictionary];
            }
            dict[@"queries"] = q;
            configurations[i] = dict;
            break;
        }
        i++;
    }
    prefs[@"configurations"] = configurations;
    self.preferences = prefs;
}

- (void)addQueryConfiguration:(IRCChannelConfiguration *)configuration forConnectionConfiguration:(IRCConnectionConfiguration *)connection
{
    NSMutableDictionary *prefs = [self.preferences mutableCopy];
    NSMutableArray *configurations;
    if([self.preferences objectForKey:@"configurations"] != nil) {
        configurations = [[self.preferences objectForKey:@"configurations"] mutableCopy];
    } else {
        configurations = [[NSMutableArray alloc] init];
    }
    
    NSMutableArray *queries = connection.queries.mutableCopy;
    [queries addObject:configuration];
    connection.queries = queries;
    
    int i=0;
    for (NSDictionary *d in configurations) {
        if([d[@"uniqueIdentifier"] isEqualToString:connection.uniqueIdentifier]) {
            NSMutableDictionary *dict = [d mutableCopy];
            NSMutableArray *channels = [dict[@"queries"] mutableCopy];
            [channels addObject:[configuration getDictionary]];
            dict[@"queries"] = channels;
            configurations[i] = dict;
            break;
        }
        i++;
    }
    
    prefs[@"configurations"] = configurations;
    self.preferences = prefs;
}

- (void)addChannelConfiguration:(IRCChannelConfiguration *)configuration forConnectionConfiguration:(IRCConnectionConfiguration *)connection
{
    NSMutableDictionary *prefs = [self.preferences mutableCopy];
    NSMutableArray *configurations;
    if([self.preferences objectForKey:@"configurations"] != nil) {
        configurations = [[self.preferences objectForKey:@"configurations"] mutableCopy];
    } else {
        configurations = [[NSMutableArray alloc] init];
    }
    
    NSMutableArray *channels = connection.channels.mutableCopy;
    [channels addObject:configuration];
    connection.channels = channels;
    
    int i=0;
    for (NSDictionary *d in configurations) {
        if([d[@"uniqueIdentifier"] isEqualToString:connection.uniqueIdentifier]) {
            NSMutableDictionary *dict = [d mutableCopy];
            NSMutableArray *channels = [dict[@"channels"] mutableCopy];
            [channels addObject:[configuration getDictionary]];
            dict[@"channels"] = channels;
            configurations[i] = dict;
            break;
        }
        i++;
    }
    
    prefs[@"configurations"] = configurations;
    self.preferences = prefs;
}

- (void)deleteChannelWithName:(NSString *)channelName forConnectionConfiguration:(IRCConnectionConfiguration *)connection
{
    NSMutableDictionary *prefs = [self.preferences mutableCopy];
    NSMutableArray *configurations = [[self.preferences objectForKey:@"configurations"] mutableCopy];
    
    int i=0;
    NSMutableDictionary *dict;
    NSMutableArray *channels;
    for (NSDictionary *d in configurations) {
        if([d[@"uniqueIdentifier"] isEqualToString:connection.uniqueIdentifier]) {
            dict = [d mutableCopy];
            channels = [[NSMutableArray alloc] init];
            for (NSDictionary *channel in d[@"channels"]) {
                if([channel[@"name"] isEqualToString:channelName] == NO) {
                    [channels addObject:channel];
                }
            }
            dict[@"channels"] = channels;
            configurations[i] = dict;
            break;
        }
        i++;
    }
    prefs[@"configurations"] = configurations;
    self.preferences = prefs;
}

- (void)deleteQueryWithName:(NSString *)queryName forConnectionConfiguration:(IRCConnectionConfiguration *)connection
{
    NSMutableDictionary *prefs = [self.preferences mutableCopy];
    NSMutableArray *configurations = [[self.preferences objectForKey:@"configurations"] mutableCopy];
    
    int i=0;
    NSMutableDictionary *dict;
    NSMutableArray *queries;
    for (NSDictionary *d in self.preferences[@"configurations"]) {
        if([d[@"uniqueIdentifier"] isEqualToString:connection.uniqueIdentifier]) {
            dict = [d mutableCopy];
            queries = [[NSMutableArray alloc] init];
            for (NSDictionary *query in d[@"queries"]) {
                if([query[@"name"] isEqualToString:queryName] == NO) {
                    [queries addObject:query];
                }
            }
            dict[@"queries"] = queries;
            configurations[i] = dict;
            break;
        }
        i++;
    }
    prefs[@"configurations"] = configurations;
    self.preferences = prefs;

}

- (void)addConnectionConfiguration:(IRCConnectionConfiguration *)configuration
{
    NSMutableDictionary *dict = [self.preferences mutableCopy];
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

- (NSString *)getLastConversation
{
    return [self.preferences objectForKey:@"lastConversation"];
}

- (void)setLastConversation:(NSString *)identifier
{
    NSMutableDictionary *dict = [self.preferences mutableCopy];
    dict[@"lastConversation"] = identifier;
    self.preferences = [dict copy];
}

- (void)deleteLastConversation
{
    NSMutableDictionary *dict = [self.preferences mutableCopy];
    [dict removeObjectForKey:@"lastConversation"];
    self.preferences = [dict copy];
}

- (void)savePrefs
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

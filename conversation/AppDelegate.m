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

#import "AppDelegate.h"
#import "ChatViewController.h"
#import "Preferences/AppPreferences.h"
#import "ChatMessageView.h"
#import "IRCConnection.h"
#import "IRCConversation.h"
#import <FCModel/FCModel.h>
#import <DLImageLoader/DLImageView.h>

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Customize Statusbar and navigation bar application wide
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    [[UINavigationBar appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
    [[UINavigationBar appearance] setBarTintColor:[UIColor colorWithRed:0.11 green:0.129 blue:0.188 alpha:1]];
    [[UINavigationBar appearance] setTintColor:[UIColor lightGrayColor]];
    [[UINavigationBar appearance] setBackgroundColor:[UIColor colorWithRed:0.11 green:0.129 blue:0.188 alpha:1]];
    [[UIBarButtonItem appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor lightGrayColor]} forState:UIControlStateNormal];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    self.ircCharacterSets = [[IRCCharacterSets alloc] init];

    _conversationsController = [[ConversationListViewController alloc] init];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:_conversationsController];
    
    [nav setViewControllers:@[_conversationsController] animated:NO];
    
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    
/*
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
    navigationController.topViewController.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem;
    splitViewController.delegate = self;
*/

    // Load default defaults
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]]];
    
    
    // other setup tasks here....
    UIUserNotificationType types = UIUserNotificationTypeBadge |
    UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    
    UIUserNotificationSettings *mySettings =
    [UIUserNotificationSettings settingsForTypes:types categories:nil];
    
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]){
        [[UIApplication sharedApplication] registerUserNotificationSettings:mySettings];
        [application registerForRemoteNotifications];
    } else {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:
         (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    }

    
    UILocalNotification *notify;
    notify = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];

    if (!notify)
        notify = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    
    
    if (notify) {
        NSString *identifier = [notify.userInfo objectForKey:@"conversation"];
        [_conversationsController selectConversationWithIdentifier:identifier];
    }
    
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    
    
    // Database stuff

    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *dbPath = [documentsPath stringByAppendingPathComponent:@"messages.sqlite3"];
    
    [FCModel openDatabaseAtPath:dbPath withSchemaBuilder:^(FMDatabase *db, int *schemaVersion) {
        [db beginTransaction];
        
        // My custom failure handling. Yours may vary.
        void (^failedAt)(int statement) = ^(int statement){
            [db rollback];
            NSAssert3(0, @"Migration statement %d failed, code %d: %@", statement, db.lastErrorCode, db.lastErrorMessage);
        };
        
        if (*schemaVersion < 1) {
            if (! [db executeUpdate:
                   @"CREATE TABLE IRCMessage ("
                   @"    id                     INTEGER PRIMARY KEY,"
                   @"    client                 TEXT NOT NULL DEFAULT '',"
                   @"    sender                 TEXT NOT NULL DEFAULT '',"
                   @"    kickedUser             TEXT NULL,"
                   @"    message                TEXT NOT NULL DEFAULT '',"
                   @"    timestamp              REAL NOT NULL,"
                   @"    conversation           TEXT NOT NULL,"
                   @"    messageType            INTEGER NOT NULL DEFAULT 0,"
                   @"    tags                   TEXT NOT NULL DEFAULT '',"
                   @"    isServerMessage        NUMERIC NOT NULL DEFAULT 0,"
                   @"    isConversationHistory  NUMERIC NOT NULL DEFAULT 1"
                   @");"
                   ]) failedAt(1);
            
            if (! [db executeUpdate:@"CREATE INDEX IF NOT EXISTS IDX_1 ON IRCMessage (timestamp, sender, message);"]) failedAt(2);
            
            *schemaVersion = 1;
        }
    
        [db commit];
    }];
    
    return YES;
}


- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken
{
    const unsigned *tokenData = devToken.bytes;
    
    _tokenString = [NSString stringWithFormat:@"%08x%08x%08x%08x%08x%08x%08x%08x", ntohl(tokenData[0]), ntohl(tokenData[1]), ntohl(tokenData[2]), ntohl(tokenData[3]), ntohl(tokenData[4]), ntohl(tokenData[5]), ntohl(tokenData[6]), ntohl(tokenData[7])];
    
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err
{
    NSLog(@"Error in registration. Error: %@", err);
}

- (void)application:(UIApplication *)app didReceiveLocalNotification:(UILocalNotification *)notify
{
    if ([app applicationState] != UIApplicationStateActive) {
        NSString *identifier = [notify.userInfo objectForKey:@"conversation"];
        [_conversationsController selectConversationWithIdentifier:identifier];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

    [self.conversationsController.chatViewController hideAccessories:nil];
    
    // Unload images
    if (self.conversationsController.currentConversation) {
        ChatMessageView *messageView;
        DLImageView *imageView;
        for (UIView *view in self.conversationsController.currentConversation.contentView.subviews) {
            if ([NSStringFromClass(view.class) isEqualToString:@"ChatMessageView"]) {
                messageView = (ChatMessageView*)view;
                for (UIView *view2 in messageView.subviews) {
                    if ([NSStringFromClass(view2.class) isEqualToString:@"DLImageView"]) {
                        imageView = (DLImageView*)view2;
                        imageView.image = nil;
                    }
                }
            }
        }
    }

    [self.conversationsController setAway];
    NSArray *connections = [_conversationsController connections];
    IRCClient *client;
    for (int x=0; x<connections.count; x++) {
        client = connections[x];
        [[AppPreferences sharedPrefs] setConnectionConfiguration:client.configuration atIndex:x];
    }
    
    if (_conversationsController.currentConversation)
        [[AppPreferences sharedPrefs] setLastConversation:_conversationsController.currentConversation.configuration.uniqueIdentifier];
    else
        [[AppPreferences sharedPrefs] deleteLastConversation];
    
    _conversationsController.currentConversation = nil;
    [[AppPreferences sharedPrefs] savePrefs];
    
    [_conversationsController saveHistoricMessages];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [self.conversationsController setBack];
    [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    
    // Set current conversation
    NSString *identifier = [[AppPreferences sharedPrefs] getLastConversation];
    if (!identifier)
        return;
    
    IRCClient *client;
    IRCConversation *conversation;
    for (client in self.conversationsController.connections) {
        for (IRCConversation *convo in [client.channels arrayByAddingObjectsFromArray:client.queries]) {
            if ([convo.configuration.uniqueIdentifier isEqualToString:identifier]) {
                conversation = convo;
                break;
            }
        }
    }
    
    if (conversation) {
        if (conversation && _conversationsController.chatViewController.isChannel)
            [_conversationsController.chatViewController updateJoinStatus];
        
        conversation.isHighlighted = NO;
        conversation.unreadCount = 0;
        
        self.conversationsController.currentConversation = conversation;
    }
    
    // Load images
    int i=0;
    ChatMessageView *messageView;
    DLImageView *imageView;
    for (UIView *view in self.conversationsController.currentConversation.contentView.subviews) {
        if ([NSStringFromClass(view.class) isEqualToString:@"ChatMessageView"]) {
            messageView = (ChatMessageView*)view;
            i=0;
            for (UIView *view2 in messageView.subviews) {
                if ([NSStringFromClass(view2.class) isEqualToString:@"DLImageView"]) {
                    imageView = (DLImageView*)view2;
                    [imageView displayImageFromUrl:[messageView.images[i] absoluteString]];
                    i++;
                }
            }
        }
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:
    [_conversationsController disconnect];
    
    [_conversationsController saveHistoricMessages];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    
    /* Check if we are inside our app and URL contains only a channel name */
    if ([sourceApplication isEqualToString:[[NSBundle mainBundle] bundleIdentifier]]) {
        IRCClient *client = self.conversationsController.chatViewController.conversation.client;
        if (client && [url.resourceSpecifier isValidChannelName:client]) {
            IRCChannel *channel = [self.conversationsController joinChannelWithName:url.resourceSpecifier onClient:client];
            [self.conversationsController selectConversationWithIdentifier:channel.configuration.uniqueIdentifier];
            return YES;
        }
    }

    /* Check if this is an SSL irc link or not */
    BOOL isSSLConnection = NO;
    if ([[url scheme] isEqualToStringCaseInsensitive:@"ircs"]) {
        isSSLConnection = YES;
    }
    
    /* Retrive the host and make sure it is valid. If it is NULL or invalid there is not much we can do, so we will return false
     and send the user back to the application they came from. */
    NSString *address = [url host];
    if ([address isValidServerAddress] == NO) {
        return NO;
    }
    
    /* Retrieve the port from the link. This parameter is optional and if none is provided we will default to 6697 for SSL, and 6667 otherwise */
    NSUInteger port = [[url port] longValue];
    if (port == 0) {
        port = isSSLConnection ? 6697 : 6667;
    }
    
    /* Check if the user already has a connection to this server, and if so; use it and add the channels in the link to the existing item */
    IRCClient *client = nil;
    for (IRCClient *connection in self.conversationsController.connections) {
        if ([connection.configuration.serverAddress isEqualToStringCaseInsensitive:address] && connection.configuration.connectUsingSecureLayer == isSSLConnection) {
            client = connection;
        }
    }
    
    if (client == nil) {
        /* The user didn't already have a connection to this server so we will create a new one. */
        IRCConnectionConfiguration *configuration = [[IRCConnectionConfiguration alloc] init];
        configuration.serverAddress = address;
        configuration.connectionPort = port;
        configuration.connectUsingSecureLayer = isSSLConnection;
        [[AppPreferences sharedPrefs] addConnectionConfiguration:configuration];
        
        
        client = [[IRCClient alloc] initWithConfiguration:configuration];
        [self.conversationsController.connections addObject:client];
    }
    
    /* NSRL mangles IRC channel names with its native methods so we will get the full URL out as a string and parse it
     to retrieve the list of channels to join */
    NSString *path = [url absoluteString];
    NSArray *pathComponents = [path componentsSeparatedByString:@"/"];
    
    if ([pathComponents count] >= 4) {
        NSString *channelListString = [pathComponents[3] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        /* Get the channels delimited by commas from the link path and add them to the channel list */
        NSArray *channelStrings = [channelListString componentsSeparatedByString:@","];
        for (NSString *channelString in channelStrings) {
            if ([channelString isValidChannelName:client]) {
                IRCChannel *channel = [self.conversationsController joinChannelWithName:channelString onClient:client];
                [self.conversationsController selectConversationWithIdentifier:channel.configuration.uniqueIdentifier];
            }
        }
    }
    
    [self.conversationsController.tableView reloadData];
    [[AppPreferences sharedPrefs] savePrefs];
    
    /* Connect automatically if this is a new or disconnected connection */
    if ([client isConnected] == NO) {
        [client connect];
    }
    return YES;
}


#pragma mark - Split view

- (BOOL)splitViewController:(UISplitViewController *)splitViewController collapseSecondaryViewController:(UIViewController *)secondaryViewController ontoPrimaryViewController:(UIViewController *)primaryViewController
{
    if ([secondaryViewController isKindOfClass:[UINavigationController class]] && [[(UINavigationController *)secondaryViewController topViewController] isKindOfClass:[ChatViewController class]]) {
        // Return YES to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
        return YES;
    } else {
        return NO;
    }
}

@end

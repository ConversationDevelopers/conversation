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

#import "ConversationListViewController.h"
#import "ChatViewController.h"
#import "ChatMessageView.h"
#import "ConsoleViewController.h"
#import "EditConnectionViewController.h"
#import "AddConversationViewController.h"
#import "IRCConversation.h"
#import "IRCChannel.h"
#import "IRCClient.h"
#import "IRCConnection.h"
#import "IRCUser.h"
#import "IRCMessage.h"
#import "AppPreferences.h"
#import "ConversationItemView.h"
#import "DisclosureView.h"
#import "UITableView+Methods.h"
#import "AppPreferences.h"
#import "SSKeychain.h"
#import "IRCCertificateTrust.h"
#import "UIAlertView+Methods.h"
#import "UIBarButtonItem+Methods.h"
#import "CertificateInfoViewController.h"
#import "CertificateItemRow.h"
#import "IRCCommands.h"
#import "ChannelListViewController.h"
#import <SHTransitionBlocks.h>
#import <UIViewController+SHTransitionBlocks.h>
#import <SHNavigationControllerBlocks.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MCNotificationManager/MCNotificationManager.h>
#import <MCNotificationManager/MCNotification.h>
#import <UIActionSheet+Blocks/UIActionSheet+Blocks.h>
#import "UIAlertView+Methods.h"

#define IPAD UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad

@implementation ConversationListViewController

- (id)init
{
    if (!(self = [super init]))
        return nil;
    
    self.connections = [[NSMutableArray alloc] init];
    self.chatViewController = [[ChatViewController alloc] init];
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationController.navigationBar.tintColor = [UIColor lightGrayColor];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
    self.navigationController.navigationBar.translucent = NO;
    
    self.title = NSLocalizedString(@"Conversations", @"Conversations");
    
    self.currentConversation = nil;
    
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"Settings"]
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(showSettings:)];
    
    self.navigationItem.leftBarButtonItem = settingsButton;
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addConversation:)];
    [addButton setTintColor:[UIColor lightGrayColor]];
    self.navigationItem.rightBarButtonItem = addButton;
    
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    
    NSArray *configurations = [[AppPreferences sharedPrefs] getConnectionConfigurations];
    for (NSDictionary *dict in configurations) {
        IRCConnectionConfiguration *configuration = [[IRCConnectionConfiguration alloc] initWithDictionary:dict];
        IRCClient *client = [[IRCClient alloc] initWithConfiguration:configuration];
        
        // Load channels
        for (IRCChannelConfiguration *config in configuration.channels) {
            IRCChannel *channel = [[IRCChannel alloc] initWithConfiguration:config withClient:client];
            [client addChannel:channel];
            [self createContentViewForConversation:(IRCConversation *)channel];
        }
        
        // Load queries
        for (IRCChannelConfiguration *config in configuration.queries) {
            IRCConversation *query = [[IRCConversation alloc] initWithConfiguration:config withClient:client];
            [client addQuery:query];
            [self createContentViewForConversation:query];
        }
             
        [self.connections addObject:client];
        if (client.configuration.automaticallyConnect) {
            [client connect];
            if (client.configuration.showConsoleOnConnect) {
                client.console = [[ConsoleViewController alloc] init];
                client.showConsole = YES;
                [self.tableView reloadData];
            }
        }
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(messageReceived:) name:@"messageReceived" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateClientState:) name:@"clientDidConnect" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateClientState:) name:@"clientDidDisconnect" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clientWillConnect:) name:@"clientWillConnect" object:nil];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadHistoricMessages];
    });
    
    _backgroundTask = UIBackgroundTaskInvalid;

    [self.navigationController SH_setAnimationDuration:0.5 withPreparedTransitionBlock:^(UIView *containerView, UIViewController *fromVC, UIViewController *toVC, NSTimeInterval duration, id<SHViewControllerAnimatedTransitioning> transitionObject, SHTransitionAnimationCompletionBlock transitionDidComplete) {
        
        if (transitionObject.isReversed == NO) {
            toVC.view.layer.affineTransform = CGAffineTransformMakeTranslation(CGRectGetWidth(toVC.view.frame), 0);
        }
        else {
            toVC.view.layer.affineTransform = CGAffineTransformMakeTranslation(-CGRectGetWidth(toVC.view.frame), 0);
        }
        
        [UIView animateWithDuration:duration delay:0 options:kNilOptions  animations:^{
            toVC.view.layer.affineTransform = CGAffineTransformIdentity;
            
            if(transitionObject.isReversed) {
                CGAffineTransform t = CGAffineTransformIdentity;
                t = CGAffineTransformMakeTranslation(CGRectGetWidth(fromVC.view.frame), 0);
                //      fromView.layer.affineTransform = CGAffineTransformScale(t, 0.5, 0.5);
                fromVC.view.layer.affineTransform = t;
                
                
            }
            else {
                CGAffineTransform t = CGAffineTransformIdentity;
                t = CGAffineTransformMakeTranslation(-CGRectGetWidth(fromVC.view.frame), 0);
                fromVC.view.layer.affineTransform = t;
                
            }
            
            
        } completion:^(BOOL finished) {
            toVC.view.layer.affineTransform = CGAffineTransformIdentity;
            fromVC.view.layer.affineTransform = CGAffineTransformIdentity;
            transitionDidComplete();
        }];
        
    }];
    
    [self.navigationController SH_setInteractiveTransitionWithGestureBlock:^UIGestureRecognizer *(UIScreenEdgePanGestureRecognizer *edgeRecognizer) {
        edgeRecognizer.edges = UIRectEdgeLeft;
        return edgeRecognizer;
    } onGestureCallbackBlock:^void(UIViewController * controller, UIGestureRecognizer *sender, UIGestureRecognizerState state, CGPoint location) {
        UIScreenEdgePanGestureRecognizer * recognizer = (UIScreenEdgePanGestureRecognizer*)sender;
        CGFloat progress = [recognizer translationInView:sender.view].x / (recognizer.view.bounds.size.width * 1.0);
        progress = MIN(1.0, MAX(0.0, progress));
        
        if (state == UIGestureRecognizerStateBegan) {
            // Create a interactive transition and pop the view controller
            controller.SH_interactiveTransition = [[UIPercentDrivenInteractiveTransition alloc] init];
            [(UINavigationController *)controller popViewControllerAnimated:YES];
        }
        else if (state == UIGestureRecognizerStateChanged) {
            // Update the interactive transition's progress
            [controller.SH_interactiveTransition updateInteractiveTransition:progress];
        }
        else if (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled) {
            // Finish or cancel the interactive transition
            if (progress > 0.5) {
                [controller.SH_interactiveTransition finishInteractiveTransition];
            }
            else {
                [controller.SH_interactiveTransition cancelInteractiveTransition];
            }
            
            controller.SH_interactiveTransition = nil;
        }
        
    }];
    
    [self.navigationController SH_setAnimatedControllerBlock:^id<UIViewControllerAnimatedTransitioning>(UINavigationController *navigationController, UINavigationControllerOperation operation, UIViewController *fromVC, UIViewController *toVC) {
        navigationController.SH_animatedTransition.reversed = operation == UINavigationControllerOperationPop;
        return navigationController.SH_animatedTransition;
    }];
    
    [self.navigationController SH_setInteractiveControllerBlock:^id<UIViewControllerInteractiveTransitioning>(UINavigationController *navigationController, id<UIViewControllerAnimatedTransitioning> animationController) {
        return navigationController.SH_interactiveTransition;
    }];
    
    // Select last used conversation
    NSString *lastConversationId = [[AppPreferences sharedPrefs] getLastConversation];
    if (lastConversationId) {
        [self selectConversationWithIdentifier:lastConversationId];
    }
    
    // Show "Add connection" dialog if we have no saved connections
    if (_connections.count == 0) {
        [self performSelector:@selector(editConnection:) withObject:nil afterDelay:1.0];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    double delayInSeconds = 1.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        //[self.navigationController performSegueWithIdentifier:@"modal" sender:nil];
    });

}

- (void)viewDidUnload
{
    [super viewDidUnload];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reloadClient:(IRCClient *)client
{
    int i=0;
    for (IRCClient *cl in self.connections) {
        if([cl.configuration.uniqueIdentifier isEqualToString:client.configuration.uniqueIdentifier]) {
            [self.tableView reloadData];
            break;
        }
        i++;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)showSettings:(id)sender
{
    IASKAppSettingsViewController *settingsController = [[IASKAppSettingsViewController alloc] init];
    settingsController.showCreditsFooter = NO;
    settingsController.delegate = self;
    
    UINavigationController *navigationController = [[UINavigationController alloc]
                                                    initWithRootViewController:settingsController];
    
    navigationController.modalPresentationStyle = UIModalPresentationFormSheet;    
    navigationController.navigationBar.tintColor = [UIColor lightGrayColor];
    navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
    navigationController.navigationBar.translucent = NO;
    
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)addConversation:(id)sender
{
    if(self.connections.count == 0) {
        [self editConnection:nil];
    } else {
        [UIActionSheet showInView:self.view
                        withTitle:NSLocalizedString(@"Add Conversation", @"Add Conversation")
                cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
           destructiveButtonTitle:nil
                otherButtonTitles:@[NSLocalizedString(@"Join a Channel", @"Join a Channel"),
                                    NSLocalizedString(@"Message a User", @"Message a User"),
                                    NSLocalizedString(@"Add Connection", @"Add Connection")]
                         tapBlock:^(UIActionSheet *actionSheet, NSInteger buttonIndex) {
                             switch (buttonIndex) {
                                 case 0:
                                     // Join a Channel
                                     [self addItemWithTag:buttonIndex];
                                     break;
                                 case 1:
                                     // Message a User
                                     [self addItemWithTag:buttonIndex];
                                     break;
                                 case 2:
                                     // Add Connection
                                     [self editConnection:nil];
                                     break;
                                 default:
                                     break;
                             }
                         }];
    }
}

- (void)updateClientState:(id)sender
{
    [self.tableView reloadData];
}

- (void)editConnection:(IRCConnectionConfiguration *)connection
{
        
    EditConnectionViewController *editController = [[EditConnectionViewController alloc] init];
    
    if (connection) {
        editController.connection = connection;
        editController.edit = YES;
    }
    
    editController.conversationsController = self;
    
    UINavigationController *navigationController = [[UINavigationController alloc]
                                                    initWithRootViewController:editController];
    
    navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    
    if(!self.navigationController.presentedViewController.isBeingDismissed) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }

    [self.navigationController presentViewController:navigationController animated:YES completion: nil];
    
}

- (void)addItemWithTag:(NSInteger)tag
{
    AddConversationViewController *addController = [[AddConversationViewController alloc] init];
    addController.target = self;
    addController.action = @selector(conversationAdded:);
    addController.connections = _connections;

    // add Query
    if(tag == 1)
        addController.addChannel = NO;
        
    UINavigationController *navigationController = [[UINavigationController alloc]
                                                    initWithRootViewController:addController];
    
    navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    
    if(!self.navigationController.presentedViewController.isBeingDismissed) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
    
    [self presentViewController:navigationController animated:YES completion: nil];
}

- (void)sortConversationsForClientAtIndex:(NSInteger)index
{
    IRCClient *client = _connections[index];
    if(client != nil) {
        [client sortChannelItems];
        [client sortQueryItems];
        [[AppPreferences sharedPrefs] setChannels:client.channels andQueries:client.queries forConnectionConfiguration:client.configuration];
        [self.tableView reloadData];        
    }
}

- (void)selectConversationWithIdentifier:(NSString *)identifier
{
    IRCClient *client;
    IRCConversation *conversation;
    for (client in _connections) {
        for (IRCConversation *convo in client.queries) {
            if ([convo.configuration.uniqueIdentifier isEqualToString:identifier]) {
                _chatViewController.isChannel = NO;
                _chatViewController.conversation = convo;
                conversation = convo;
                break;
            }
        }
        if (conversation == nil) {
            for (IRCConversation *convo in client.channels) {
                if ([convo.configuration.uniqueIdentifier isEqualToString:identifier]) {
                    _chatViewController.isChannel = YES;
                    _chatViewController.conversation = convo;
                    conversation = convo;
                    break;
                }
            }
        }
    }

    conversation.isHighlighted = NO;
    conversation.unreadCount = 0;
    _currentConversation = conversation;
    
    [self.navigationController popToRootViewControllerAnimated:YES];
    [self.navigationController pushViewController:_chatViewController animated:YES];
}

- (void)clientWillConnect:(NSNotification *)notification
{
    [UIApplication sharedApplication].idleTimerDisabled = [self shouldDisableIdleTimer];

    if (_backgroundTask == UIBackgroundTaskInvalid)
        _backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{ [self _backgroundTaskExpired]; }];

}

#pragma mark - Table View

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
    return indexPath;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath
{
    IRCClient *client = [self.connections objectAtIndex:indexPath.section];
    
    int offset = 0;
    if (client.showConsole)
        offset = 1;
    
    IRCConversation *conversation;
    if ((int)indexPath.row > (int)client.channels.count-1+offset) {
        NSInteger index = indexPath.row - client.channels.count - offset;
        conversation = client.queries[index];
        _chatViewController.isChannel = NO;
    } else if (client.showConsole && indexPath.row == 0) {
        client.console.title = client.configuration.connectionName;
        [self.navigationController pushViewController:client.console animated:YES];
        return;
    } else {
        conversation = client.channels[indexPath.row - offset];
        _chatViewController.isChannel = YES;
    }
    
    conversation.isHighlighted = NO;
    conversation.unreadCount = 0;

    [self.tableView reloadData];
    
    _chatViewController.conversation = conversation;
    [self.navigationController pushViewController:_chatViewController animated:YES];

    _currentConversation = conversation;
    
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    IRCClient *client = [self.connections objectAtIndex:section];
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, screenRect.size.width, 35.0)];
    header.tag = section;
    header.backgroundColor = [UIColor whiteColor];
    
    // Set image
    CGSize size = CGSizeMake(25.0, 25.0);
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(15, 5, size.width, size.height)];
    UIImage *image = [UIImage imageNamed:@"NetworkIcon"];
    UIGraphicsBeginImageContext(size);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    imageView.image = scaledImage;
    [header addSubview:imageView];
    
    // Set Label
    UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(55.0, 0.0, screenRect.size.width-60.0, 35.0)];
    textLabel.font = [UIFont systemFontOfSize:18.0];
    textLabel.textColor = [UIColor darkGrayColor];
    textLabel.text = client.configuration.connectionName;
    [header addSubview:textLabel];
    
    if (client.isAttemptingConnection || client.isAttemptingRegistration) {
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        spinner.frame = CGRectMake(screenRect.size.width-50.0, 0, header.frame.size.height, header.frame.size.height);
        [header addSubview:spinner];
        [spinner startAnimating];
    }
    
    if (client.isConnectedAndCompleted) {
        UIButton *checkmark = [UIButton buttonWithType:UIButtonTypeCustom];
        
        // Define unicode character
        unichar *code = malloc(sizeof(unichar) * 1);
        code[0] = (unichar)0x2713;
        
        checkmark.frame = CGRectMake(screenRect.size.width-50, 0, header.frame.size.height, header.frame.size.height);
        checkmark.titleLabel.font = [UIFont fontWithName:@"Symbola" size:16.0];
        [checkmark setTitle:[NSString stringWithCharacters:code length:1] forState:UIControlStateNormal];
        [checkmark setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [header addSubview:checkmark];
        free(code);
    }
    
    // Add Tap Event
    UITapGestureRecognizer *singleTapRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerViewSelected:)];
    [singleTapRecogniser setDelegate:self];
    singleTapRecogniser.numberOfTouchesRequired = 1;
    singleTapRecogniser.numberOfTapsRequired = 1;
    [header addGestureRecognizer:singleTapRecogniser];
    
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    
    return 35.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _connections.count;
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    IRCClient *client = [_connections objectAtIndex:section];
    NSInteger number = client.channels.count + client.queries.count;
    if (client.showConsole)
        return number + 1;
    return number;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"cell";
    ConversationItemView *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[ConversationItemView alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    
    IRCClient *client = [_connections objectAtIndex:indexPath.section];
    NSArray *channels = client.channels;
    DisclosureView *disclosure = [[DisclosureView alloc] initWithFrame:CGRectMake(-5, -10, 15, 15)];
    disclosure.color = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1];
    
    cell.nameLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1];
    cell.unreadCountLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1];
    cell.isConsole = NO;
    
    int offset = 0;
    if (client.showConsole)
        offset = 1;
    
    if ((int)indexPath.row > (int)channels.count-1+offset) {
        NSInteger index;
        index = indexPath.row - client.channels.count - offset;
        IRCConversation *query = [client.queries objectAtIndex:index];
        cell.accessoryView = disclosure;
        cell.enabled = query.conversationPartnerIsOnline;
        cell.name = query.name;
        cell.isChannel = NO;
        cell.previewMessages = query.previewMessages;
        cell.unreadCount = query.unreadCount;
        if (query.isHighlighted) {
            cell.nameLabel.textColor = [UIColor colorWithRed:0.5 green:0 blue:0 alpha:1];
            cell.unreadCountLabel.textColor = [UIColor colorWithRed:0.5 green:0 blue:0 alpha:1];
            disclosure.color = [UIColor colorWithRed:0.5 green:0 blue:0 alpha:1];
        }
    } else if (client.showConsole && indexPath.row == 0) {
        cell.enabled = YES;
        cell.name = NSLocalizedString(@"Console", @"Console");
        cell.isConsole = YES;
        cell.unreadCount = 0;
        cell.previewMessages = nil;
    } else {
        IRCChannel *channel = [client.channels objectAtIndex:(int)indexPath.row - offset];
        cell.accessoryView = disclosure;
        cell.enabled = channel.isJoinedByUser;
        cell.name = channel.name;
        cell.isChannel = YES;
        cell.unreadCount = channel.unreadCount;
        cell.previewMessages = channel.previewMessages;
        if (channel.isHighlighted) {
            cell.nameLabel.textColor = [UIColor colorWithRed:0 green:0.502 blue:0 alpha:1];
            cell.unreadCountLabel.textColor = [UIColor colorWithRed:0 green:0.502 blue:0 alpha:1];
            disclosure.color = [UIColor colorWithRed:0 green:0.502 blue:0 alpha:1];
        }
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // We have the menu item to remove the console, so don't make it editable
    IRCClient *client = [_connections objectAtIndex:indexPath.section];
    if (client.showConsole && indexPath.row == 0)
        return NO;
    
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    IRCClient *client = _connections[indexPath.section];

    int offset = 0;
    if (client.showConsole)
        offset = 1;
    
    int index = (int)indexPath.row;
    
    if ((int)indexPath.row > (int)client.channels.count-1 + offset) {
        index = index - (int)client.channels.count;
        IRCConversation *query = client.queries[index - offset];
        [self deleteConversationWithIdentifier:query.configuration.uniqueIdentifier];
    } else {
        IRCChannel *channel = client.channels[index - offset];

        if (channel.isJoinedByUser) {
            [IRCCommands leaveChannel:channel.name withMessage:[[NSUserDefaults standardUserDefaults] stringForKey:@"partmsg_preference"] onClient:client];
            channel.isJoinedByUser = NO;
            [tableView reloadData];
            return;
        } else {
            [self deleteConversationWithIdentifier:channel.configuration.uniqueIdentifier];
        }
    }
    
    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    IRCClient *client = _connections[indexPath.section];
    
    int offset = 0;
    if (client.showConsole)
        offset = 1;
    
    int index = (int)indexPath.row;
    if ((int)indexPath.row <= (int)client.channels.count-1 + offset) {
        IRCChannel *channel = client.channels[index - offset];
        if (channel.isJoinedByUser)
            return @"Leave";

    }
    
    return @"Close";
}

- (void)headerViewSelected:(UIGestureRecognizer *)sender
{
    // Get relevant client
    IRCClient *client = [self.connections objectAtIndex:sender.view.tag];
    
    NSMutableArray *buttonTitles = [[NSMutableArray alloc] initWithArray:@[client.isConnected ? NSLocalizedString(@"Disconnect", @"Disconnect server") : NSLocalizedString(@"Connect", @"Connect server"),
                                                                          NSLocalizedString(@"Sort Conversations", "Sort Conversations"),
                                                                          client.showConsole ? NSLocalizedString(@"Hide Console", "Hide Console") : NSLocalizedString(@"Show Console", "Show Console"),
                                                                          NSLocalizedString(@"Edit", @"Edit Connection"),
                                                                           NSLocalizedString(@"Channel List", @"Channel List")]];
    
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:client.configuration.connectionName
                                                             delegate:nil
                                                    cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                               destructiveButtonTitle:nil
                                                    otherButtonTitles:nil];
    
    if (client.isConnected) {
        actionSheet.destructiveButtonIndex = 1;
    } else {
        actionSheet.destructiveButtonIndex = 5;
        [buttonTitles removeLastObject];
        [buttonTitles addObject:NSLocalizedString(@"Delete", @"Delete")];
    }
    
    for (NSString *button in buttonTitles) {
        [actionSheet addButtonWithTitle:button];
    }
    
    actionSheet.tapBlock = ^(UIActionSheet *actionSheet, NSInteger buttonIndex){
        UIAlertView *alertView;
        switch (buttonIndex) {
            case 1:
                // Connect or disconnect
                if(client.isConnected) {
                    NSString *quitMsg = [[NSUserDefaults standardUserDefaults] stringForKey:@"quitmsg_preference"];
                    [client disconnectWithMessage:quitMsg];
                } else {
                    [client connect];
                    if (client.configuration.showConsoleOnConnect) {
                        client.showConsole = YES;
                        client.console = [[ConsoleViewController alloc] init];
                    }
                    [self.tableView reloadData];
                }
                break;
            case 2:
                // Sort Conversations
                [self sortConversationsForClientAtIndex:actionSheet.tag];
                break;
            case 3:
                // Show Console
                if (client.showConsole) {
                    client.showConsole = NO;
                    client.console = nil;
                } else {
                    client.showConsole = YES;
                    client.console = [[ConsoleViewController alloc] init];
                }
                [self.tableView reloadData];
                break;
            case 4:
                // Edit
                [self editConnection:client.configuration];
                break;
            case 5:
                // Delete
                if(!client.isConnected) {
                    alertView = [[UIAlertView alloc] initWithTitle:client.configuration.connectionName
                                                           message:NSLocalizedString(@"Do you really want to delete this connection?", @"Delete connection confirmation")
                                                          delegate:self
                                                 cancelButtonTitle:NSLocalizedString(@"No", @"no")
                                                 otherButtonTitles:NSLocalizedString(@"Yes", @"yes"), nil];
                    [alertView showWithCompletion:^(UIAlertView *alertView, NSInteger buttonIndex) {
                        if(buttonIndex == 1) {
                            IRCClient *client = [self.connections objectAtIndex:alertView.tag];
                            if(client.isConnected)
                                [client disconnect];
                            [[AppPreferences sharedPrefs] deleteConnectionWithIdentifier:client.configuration.uniqueIdentifier];
                            [self.connections removeObjectAtIndex:alertView.tag];
                            [self.tableView reloadData];
                        }
                    }];
                } else {
                    ChannelListViewController *channelList = [[ChannelListViewController alloc] init];
                    channelList.client = client;
                    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:channelList];
                    navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
                    navigationController.navigationBar.tintColor = [UIColor lightGrayColor];
                    navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
                    navigationController.navigationBar.translucent = NO;
                    [self.navigationController presentViewController:navigationController animated:YES completion:nil];
                }
                break;
            default:
                break;
        }

    };
    
    [actionSheet showInView:self.view];

}

- (void)conversationAdded:(AddConversationViewController *)sender
{
    
    IRCClient *client;
    int i;
    for (i=0; i<_connections.count; i++) {
        client = [_connections objectAtIndex:i];
        if([client.configuration.uniqueIdentifier isEqualToString:sender.client.configuration.uniqueIdentifier])
            break;
    }
    if(client != nil) {
        if(sender.addChannel) {
            IRCChannel *channel = [[IRCChannel alloc] initWithConfiguration:sender.configuration withClient:sender.client];
            [client addChannel:channel];
            
            // Save config
            if([sender.configuration.passwordReference isEqualToString:@""] == NO) {
                NSString *identifier = [[NSUUID UUID] UUIDString];
                [SSKeychain setPassword:sender.configuration.passwordReference forService:@"conversation" account:identifier];
                sender.configuration.passwordReference = identifier;
            }
            [self createContentViewForConversation:channel];
            [[AppPreferences sharedPrefs] addChannelConfiguration:sender.configuration forConnectionConfiguration:sender.client.configuration];
            
        } else {
            IRCConversation *query = [[IRCConversation alloc] initWithConfiguration:sender.configuration withClient:sender.client];
            [client addQuery:query];
            
            // Save config
            [self createContentViewForConversation:query];
            [[AppPreferences sharedPrefs] addQueryConfiguration:sender.configuration forConnectionConfiguration:sender.client.configuration];
            
        }
        
    }
    IRCConnectionConfiguration *config = [[IRCConnectionConfiguration alloc] initWithDictionary:[[[AppPreferences sharedPrefs] getConnectionConfigurations] objectAtIndex:i]];
    client.configuration = config;
    
    [self.tableView reloadData];
    
}

- (void)createContentViewForConversation:(IRCConversation *)conversation
{
    if (!conversation.contentView) {
        CGRect screenRect = [[UIScreen mainScreen] bounds];

        CGRect frame = CGRectMake(0.0,
                           0.0,
                           screenRect.size.width,
                           480.0 - PHFComposeBarViewInitialHeight);

        conversation.contentView = [[ConversationContentView alloc] initWithFrame:frame];
        conversation.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        conversation.contentView.delegate = self;
    }

}

- (IRCChannel *)joinChannelWithName:(NSString *)name onClient:(IRCClient *)client
{
    for (IRCChannel *ch in client.channels) {
        if ([ch.name.lowercaseString isEqualToString:name.lowercaseString]) {
            if (ch.isJoinedByUser == NO) {
                [IRCCommands joinChannel:ch.name onClient:client];
            }
            return ch;
        }
    }
    
    IRCChannelConfiguration *configuration = [[IRCChannelConfiguration alloc] init];
    configuration.name = name;
    IRCChannel *channel = [[IRCChannel alloc] initWithConfiguration:configuration withClient:client];
    
    [client addChannel:channel];
    
    [self createContentViewForConversation:(IRCConversation*)channel];
    
    if (self.tableView.isEditing == NO)
        [self.tableView reloadData];
    
    [[AppPreferences sharedPrefs] addChannelConfiguration:configuration forConnectionConfiguration:client.configuration];

    return channel;
}

- (IRCConversation *)createConversationWithName:(NSString *)name onClient:(IRCClient *)client
{
    for (IRCConversation *query in client.queries) {
        if ([query.name isEqualToStringCaseInsensitive:name]) {
            return query;
        }
    }
    IRCChannelConfiguration *configuration = [[IRCChannelConfiguration alloc] init];
    configuration.name = name;
    IRCConversation *query = [[IRCConversation alloc] initWithConfiguration:configuration withClient:client];
    [client addQuery:query];

    [self createContentViewForConversation:query];

    if (self.tableView.isEditing == NO)
        [self.tableView reloadData];
    
    [[AppPreferences sharedPrefs] addQueryConfiguration:configuration forConnectionConfiguration:client.configuration];

    return query;
}

- (void)deleteConversationWithIdentifier:(NSString *)identifier
{
    int i=0;
    for (IRCClient *client in [_connections copy]) {
        for (IRCConversation *conversation in [client.queries copy]) {
            if ([conversation.configuration.uniqueIdentifier isEqualToString:identifier]) {
                [client removeQuery:conversation];
                [[AppPreferences sharedPrefs] deleteQueryWithName:conversation.name forConnectionConfiguration:client.configuration];                
            }
        }
        for (IRCChannel *channel in [client.channels copy]) {
            if ([channel.configuration.uniqueIdentifier isEqualToString:identifier]) {
                [client removeChannel:channel];
                [[AppPreferences sharedPrefs] deleteChannelWithName:channel.name forConnectionConfiguration:client.configuration];
            }
        }
        [_connections setObject:client atIndexedSubscript:i];
        i++;
    }
    
    if ([_currentConversation.configuration.uniqueIdentifier isEqualToString:identifier])
        [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)messageReceived:(NSNotification *) notification
{
    IRCMessage *message = notification.object;
    
    // Don't handle raw messages
    if (message.messageType == ET_LIST || message.messageType == ET_LISTEND)
        return;
    
    if (message.messageType == ET_RAW) {
        if (message.client.showConsole)
            message.client.console.contentView.text = [message.client.console.contentView.text stringByAppendingFormat:@"%@\n", message.message];
        return;
    }
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"hideevents_preference"] == YES &&
        (message.messageType == ET_JOIN || message.messageType == ET_PART || message.messageType == ET_QUIT ||
         message.messageType == ET_NICK || message.messageType == ET_KICK || message.messageType == ET_MODE)) {
            return;
        }
    
    if (message.messageType == ET_INVITE) {
        if ([[NSUserDefaults standardUserDefaults] integerForKey:@"invite_preference"] == 1) {
            [self joinChannelWithName:message.conversation.name onClient:message.conversation.client];
        } else if ([[NSUserDefaults standardUserDefaults] integerForKey:@"invite_preference"] == 2) {
            NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"got invitation", nil), message.sender.nick, message.message];
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Channel Invite", nil)
                                                                message:msg
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"NO", nil)
                                                      otherButtonTitles:NSLocalizedString(@"YES", nil), nil];
            [alertView setCancelButtonIndex:0];
            [alertView showWithCompletion:^(UIAlertView *alertView, NSInteger buttonIndex) {
                if (buttonIndex == 1) {
                    IRCChannel *channel = [self joinChannelWithName:message.conversation.name onClient:message.conversation.client];
                    [self selectConversationWithIdentifier:channel.configuration.uniqueIdentifier];
                }
            }];
        }
        return;
    }
    
    ChatMessageView *messageView = [[ChatMessageView alloc] initWithFrame:CGRectMake(0, 0, message.conversation.contentView.frame.size.width, 15.0)
                                                                  message:message
                                                             conversation:message.conversation];

    messageView.chatViewController = self.chatViewController;
    [message.conversation.contentView addMessageView:messageView];
    
    messageView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    // The stuff below is only for the preview
    if ((message.messageType != ET_PRIVMSG && message.messageType != ET_ACTION && message.messageType != ET_NOTICE) ||
        [message.sender.nick isEqualToString:message.client.currentUserOnConnection.nick])
        return;
    
    // Make sender's nick bold
    NSMutableAttributedString *string;
    UIFont *font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
    if (message.messageType == ET_ACTION) {
        string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"· %@ %@", message.sender.nick, message.message]];
        [string addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, message.sender.nick.length+message.message.length+3)];
    } else {
        string = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@: %@", message.sender.nick, message.message]];
        [string addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, message.sender.nick.length+1)];
    }
    
    if (message.isConversationHistory) {
        [self.tableView reloadData];
        return;
    }
    
    [message.conversation addPreviewMessage:string];
    
    // Dont set highlight if source conversation is currently visible
    if ([message.conversation isEqual:_currentConversation] == NO) {
        
        if ([message.conversation isKindOfClass:IRCChannel.class] == NO) {
            message.conversation.unreadCount++;
            if (message.conversation.isHighlighted == NO) {
                message.conversation.isHighlighted = YES;
                AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
                
                // Show notification
                MCNotification *notification = [MCNotification notification];
                notification.backgroundColor = [UIColor colorWithRed:0.11 green:0.129 blue:0.188 alpha:1];
                notification.tintColor = [UIColor whiteColor];
                notification.text = message.sender.nick;
                notification.detailText = message.message;
                notification.image = [UIImage imageNamed:@"Userlist"];
                notification.userInfo = @{@"conversation": message.conversation.configuration.uniqueIdentifier};
                [notification addTarget:self action:@selector(notificationTap:) forControlEvents:UIControlEventTouchUpInside];
                
                [[MCNotificationManager sharedInstance] showNotification:notification];
                
                if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)
                    [self showNotificationWithMessage:message];
            }
            
        } else {
            
            message.conversation.unreadCount++;
            
            // Check for highlight
            NSString *msg = message.message;
            NSString *nick = [[message.conversation.client currentUserOnConnection] nick];
            NSCharacterSet *wordBoundries = [[NSCharacterSet letterCharacterSet] invertedSet];
            NSRange range = [msg rangeOfString:nick];
            if (range.location != NSNotFound &&
                (range.location == 0 || [[msg substringWithRange:NSMakeRange(range.location-1, 1)] rangeOfCharacterFromSet:wordBoundries].location != NSNotFound) &&
                (range.location+range.length+1 > msg.length || [[msg substringWithRange:NSMakeRange(range.location+range.length, 1)] rangeOfCharacterFromSet:wordBoundries].location != NSNotFound)) {
                if (message.conversation.isHighlighted == NO) {
                    message.conversation.isHighlighted = YES;
                    AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
                    
                    // Show notification
                    MCNotification *notification = [MCNotification notification];
                    notification.backgroundColor = [UIColor colorWithRed:0.11 green:0.129 blue:0.188 alpha:1];
                    notification.tintColor = [UIColor whiteColor];
                    notification.text = message.sender.nick;
                    notification.detailText = message.message;
                    notification.image = [UIImage imageNamed:@"ChannelIcon_Light"];
                    notification.userInfo = @{@"conversation": message.conversation.configuration.uniqueIdentifier};
                    [notification addTarget:self action:@selector(notificationTap:) forControlEvents:UIControlEventTouchUpInside];
                    
                    [[MCNotificationManager sharedInstance] showNotification:notification];

                    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive)
                        [self showNotificationWithMessage:message];
                }
            }
            
        }
        
    }
    
    if (self.tableView.isEditing == NO)
        [self.tableView reloadData];
    
}

- (void)notificationTap:(id)sender
{
    NSDictionary *userInfo = [[sender notification] userInfo];
    [self selectConversationWithIdentifier:[userInfo objectForKey:@"conversation"]];
}

- (void)displayPasswordEntryDialog:(IRCClient *)client
{
    
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:NSLocalizedString(@"Please enter a password", @"Please enter a password")
                          message:NSLocalizedString(@"You haven't specified a password or the entered password did not match", @"You haven't specified a password or the entered password did not match")
                          delegate:self
                          cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
                          otherButtonTitles:NSLocalizedString(@"Retry", @"Retry"), nil ];
    
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField* answerField = [alert textFieldAtIndex:0];
    answerField.keyboardType = UIKeyboardTypeNumberPad;
    answerField.placeholder = @"Password";
    
    __block ConversationListViewController *blockself = self;
    [alert showWithCompletion:^(UIAlertView *alertView, NSInteger buttonIndex) {
        if (buttonIndex == 1) {
            if (answerField.text.length) {
                if (client.configuration.serverPasswordReference.length) {
                    NSString *password = [SSKeychain passwordForService:@"conversation" account:client.configuration.serverPasswordReference];
                    if (password.length)
                        [SSKeychain deletePasswordForService:@"conversation" account:client.configuration.serverPasswordReference];
                }
                NSString *identifier = [[NSUUID UUID] UUIDString];
                [SSKeychain setPassword:answerField.text forService:@"conversation" account:identifier];
                client.configuration.serverPasswordReference = identifier;
                IRCClient *cl;
                int i;
                for (i=0; i<blockself.connections.count; i++) {
                    cl = [blockself.connections objectAtIndex:i];
                    if([client.configuration.uniqueIdentifier isEqualToString:cl.configuration.uniqueIdentifier])
                        break;
                }
                [blockself.connections setObject:client atIndexedSubscript:i];
                if ([client isConnected]) {
                    [IRCCommands sendServerPasswordForClient:client];
                } else {
                    [client connect];
                }
            }
        }
    }];
}

- (void)showInivitationRequiredAlertForChannel:(NSString *)channelName
{
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Channel requires invitation", nil), channelName];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Invite required", nil)
                                                        message:message
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                              otherButtonTitles:nil];
    [alertView setCancelButtonIndex:0];
    [alertView show];
    
}

- (void)requestUserTrustForCertificate:(IRCCertificateTrust *)trustRequest
{
    CertificateItemRow *commonName =  [trustRequest.issuerInformation objectAtIndex:5];
    NSString *message = [NSString stringWithFormat:@"%@ %@ %@", NSLocalizedString(@"Conversation cannot verify the identity of", @"Conversation cannot verify the identity of"), [commonName itemDescription], NSLocalizedString(@"Would you like to continue anyway?", @"Would you like to continue anyway?")];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot verify Server Identity", @"Cannot verify Server Identity")
                                                            message:message
                                                           delegate:self
                                                  cancelButtonTitle:nil
                                                  otherButtonTitles:NSLocalizedString(@"Cancel", @"Cancel"),
                                                                    NSLocalizedString(@"Continue", @"Continue"),
                                                                    NSLocalizedString(@"Details", @"Details"), nil];
    [alertView setCancelButtonIndex:1];

    [alertView showWithCompletion:^(UIAlertView *alertView, NSInteger buttonIndex) {
        if (buttonIndex == 0) {
            [trustRequest receivedTrustFromUser:NO];
        } else if (buttonIndex == 1) {
            [trustRequest receivedTrustFromUser:YES];
        } else if (buttonIndex == 2) {
            
            CertificateInfoViewController *certificateInfoController = [[CertificateInfoViewController alloc] initWithStyle:UITableViewStyleGrouped];
            certificateInfoController.title = NSLocalizedString(@"Certificate Details", @"Certificate Details");
            
            __block id blockself = self;
            UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                           block:^(__strong id object){
                                                                                               [trustRequest receivedTrustFromUser:NO];
                                                                                               [blockself dismissViewControllerAnimated:YES completion:nil];
                                                                                           }];
            
            UIBarButtonItem *trustButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Trust", @"Trust")
                                                                            style:UIBarButtonItemStylePlain
                                                                            block:^(__strong id object){
                                                                                [trustRequest receivedTrustFromUser:YES];
                                                                                [blockself dismissViewControllerAnimated:YES completion:nil];
                                                                            }];
            
            certificateInfoController.subjectInformation = trustRequest.subjectInformation;
            certificateInfoController.issuerInformation = trustRequest.issuerInformation;
            certificateInfoController.certificateInformation = trustRequest.certificateInformation;

            certificateInfoController.navigationItem.rightBarButtonItem = trustButton;
            certificateInfoController.navigationItem.leftBarButtonItem = cancelButton;
            
            UINavigationController *navigationController = [[UINavigationController alloc]
                                                            initWithRootViewController:certificateInfoController];
            
            [self presentViewController:navigationController animated:YES completion:nil];

        }
        
    }];
}


- (void)displayInformationForCertificate:(IRCCertificateTrust *)trustRequest
{
	CertificateInfoViewController *certificateInfoController = [[CertificateInfoViewController alloc] initWithStyle:UITableViewStyleGrouped];
	certificateInfoController.title = NSLocalizedString(@"Certificate Details", @"Certificate Details");
	
	__block id blockself = self;
	
	UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Close", @"Close")
																	style:UIBarButtonItemStylePlain
																	block:^(__strong id object){
																		[blockself dismissViewControllerAnimated:YES completion:nil];
																	}];
	
	certificateInfoController.subjectInformation = trustRequest.subjectInformation;
	certificateInfoController.issuerInformation = trustRequest.issuerInformation;
	certificateInfoController.certificateInformation = trustRequest.certificateInformation;
	
	certificateInfoController.navigationItem.rightBarButtonItem = closeButton;
	
	UINavigationController *navigationController = [[UINavigationController alloc]
													initWithRootViewController:certificateInfoController];
	
	[self presentViewController:navigationController animated:YES completion:nil];
}

- (BOOL)shouldDisableIdleTimer
{
    if ([UIDevice currentDevice].batteryState >= UIDeviceBatteryStateCharging)
        return YES;
    return [self anyConnectedOrConnectingConnections];
}

- (BOOL)anyConnectedOrConnectingConnections
{
    for (IRCClient *connection in _connections)
        if (connection.isConnected || connection.isAttemptingConnection || connection.isAttemptingRegistration)
            return YES;
    return NO;
}

- (void) _backgroundTaskExpired {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self saveHistoricMessages];
    });
	
    [self disconnect];
    [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
    _backgroundTask = UIBackgroundTaskInvalid;
	
}

- (void)setAway
{
    BOOL autoaway = [[NSUserDefaults standardUserDefaults] boolForKey:@"autoaway_preference"];
    if (!autoaway)
        return;
    
    NSString *awaymsg = [[NSUserDefaults standardUserDefaults] stringForKey:@"awaymsg_preference"];
    for (IRCClient *client in self.connections) {
        if (client.isConnected)
            [client.connection send:[NSString stringWithFormat:@"AWAY :%@", awaymsg]];
    }
    
}

- (void)setBack
{
    BOOL autoaway = [[NSUserDefaults standardUserDefaults] boolForKey:@"autoaway_preference"];
    if (!autoaway)
        return;
    
    for (IRCClient *client in self.connections) {
        if (client.isConnected)
            [client.connection send:@"AWAY"];
    }
}

- (void)disconnect
{
    for (IRCClient *client in _connections) {
        NSString *quitMsg = [[NSUserDefaults standardUserDefaults] stringForKey:@"quitmsg_preference"];
        [client disconnectWithMessage:quitMsg];
    }
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForSpecifier:(IASKSpecifier*)specifier
{
    if ([specifier.key isEqualToString:@"support_preference"]) {
        [self dismissViewControllerAnimated:YES completion:nil];        
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"irc://chat.freenode.com:6667/#conversation"]];
    } else if ([specifier.key isEqualToString:@"twitter_preference"]) {
        [self dismissViewControllerAnimated:YES completion:nil];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://twitter.com/ConversationIRC"]];
    }
}

- (void)showNotificationWithMessage:(IRCMessage *)message
{
    UILocalNotification *localNotif = [[UILocalNotification alloc] init];
    if (localNotif == nil)
        return;
    
    localNotif.alertBody = [NSString stringWithFormat:NSLocalizedString(@"[%@] %@", nil),
                            message.sender.nick, message.message];
    
    localNotif.alertAction = NSLocalizedString(@"View Details", nil);
    
    localNotif.soundName = UILocalNotificationDefaultSoundName;
    localNotif.applicationIconBadgeNumber = (int)[[UIApplication sharedApplication] applicationIconBadgeNumber] + 1;
    
    NSDictionary *infoDict = [NSDictionary dictionaryWithObject:message.conversation.configuration.uniqueIdentifier forKey:@"conversation"];
    localNotif.userInfo = infoDict;
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:localNotif];
}

- (void)loadHistoricMessages
{

    NSMutableArray *messages = [[IRCMessage instancesOrderedBy:@"timestamp"] mutableCopy];
    ChatMessageView *messageView;
    BOOL found = NO;
    for (IRCMessage *message in messages) {
        found = NO;
        for (IRCClient *client in _connections) {
            for (IRCChannel *channel in client.channels) {
                if ([channel.configuration.uniqueIdentifier isEqualToString:message.conversation.configuration.uniqueIdentifier]) {
                    message.conversation = channel;
                    found = YES;
                    break;
                }
            }
            for (IRCConversation *query in client.queries) {
                if ([query.configuration.uniqueIdentifier isEqualToString:message.conversation.configuration.uniqueIdentifier]) {
                    message.conversation = query;
                    found = YES;
                    break;
                }
            }
        }
        
        if (!found) {
            [message delete];
            continue;
        }
        
        messageView = [[ChatMessageView alloc] initWithFrame:CGRectMake(0, 0, message.conversation.contentView.frame.size.width, 15.0)
                                                                      message:message
                                                                 conversation:message.conversation];
        
        messageView.chatViewController = self.chatViewController;
        [message.conversation.contentView addMessageView:messageView];
        messageView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
    }
}

- (void)saveHistoricMessages
{
    
    int limit = 50;
    if (IPAD)
        limit = 100;
    
    int i=0;
    for (IRCClient *client in _connections) {
        for (IRCChannel *conversation in client.channels) {
            i=0;
            for (UIView *view in conversation.contentView.subviews) {
                if ([NSStringFromClass(view.class) isEqualToString:@"ChatMessageView"]) {
                    ChatMessageView *messageView = (ChatMessageView *)view;
                    IRCMessage *message = messageView.message;
                    i++;
                    if (i > limit) {
                        [message delete];
                        continue;
                    }
                    message.isConversationHistory = YES;
                    [message save];
                }
            }
        }
        
        for (IRCConversation *conversation in client.queries) {
            i=0;
            for (UIView *view in conversation.contentView.subviews) {
                if ([NSStringFromClass(view.class) isEqualToString:@"ChatMessageView"]) {
                    ChatMessageView *messageView = (ChatMessageView *)view;
                    IRCMessage *message = messageView.message;
                    i++;
                    if (i > limit) {
                        [message delete];
                        continue;
                    }
                    message.isConversationHistory = YES;
                    [message save];
                }
            }
        }
        
    }

}

@end

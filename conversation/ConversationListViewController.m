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

#import "ConversationListViewController.h"
#import "DetailViewController.h"
#import "EditConnectionViewController.h"
#import "AddConversationViewController.h"
#import "IRCConversation.h"
#import "IRCChannel.h"
#import "IRCClient.h"
#import "AppPreferences.h"
#import "ConversationItemView.h"
#import "UITableView+Methods.h"
#import "AppPreferences.h"
#import "SSKeychain.h"

@implementation ConversationListViewController

- (id)init
{
    if (!(self = [super init]))
        return nil;
    self.connections = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"Conversations", @"Conversations");
    
    // Do any additional setup after loading the view, typically from a nib.
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Settings", @"Left navigation button in the conversation list")
                                                                       style:UIBarButtonItemStylePlain
                                                                      target:self
                                                                      action:@selector(showSettings:)];
    [settingsButton setTintColor:[UIColor lightGrayColor]];
    self.navigationItem.leftBarButtonItem = settingsButton;
    
    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addConversation:)];
    [addButton setTintColor:[UIColor lightGrayColor]];
    self.navigationItem.rightBarButtonItem = addButton;
    
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    
    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    
    NSArray *configurations = [[AppPreferences sharedPrefs] getConnectionConfigurations];
    for (NSDictionary *dict in configurations) {
        IRCConnectionConfiguration *configuration = [[IRCConnectionConfiguration alloc] initWithDictionary:dict];
        IRCClient *client = [[IRCClient alloc] initWithConfiguration:configuration];
        
        // Load channels
        for (IRCChannelConfiguration *config in configuration.channels)
            [client addChannel:[[IRCChannel alloc] initWithConfiguration:config withClient:client]];
        
        // Load queries
        for (IRCChannelConfiguration *config in configuration.queries)
            [client addQuery:[[IRCConversation alloc] initWithConfiguration:config withClient:client]];
             
        [self.connections addObject:client];
        if (client.configuration.automaticallyConnect) {
            [client connect];
        }
    }
}

- (void)enableItemAtIndex:(NSInteger)index forClient:(IRCClient *)client
{
    NSLog(@"ENABLE ITEM: %i", (int)index);
    int i=0;
    for (IRCClient *cl in self.connections) {
        if([cl.configuration.uniqueIdentifier isEqualToString:client.configuration.uniqueIdentifier]) {
            if(index < client.getChannels.count) {
                IRCChannel *channel = [client.getChannels objectAtIndex:index];
                channel.joined = YES;
                [client.getChannels setObject:channel atIndexedSubscript:index];
                [self.connections setObject:client atIndexedSubscript:i];
            } else {
                IRCConversation *query = [client.getQueries objectAtIndex:index-client.getChannels.count];
                query.conversationPartnerIsOnline = YES;
                [client.getChannels setObject:query atIndexedSubscript:index-client.getChannels.count];
                [self.connections setObject:client atIndexedSubscript:i];
            }
            break;
        }
        i++;
    }
}

- (void)disableItemAtIndex:(NSInteger)index forClient:(IRCClient *)client
{
    NSLog(@"DISABLE ITEM: %i", (int)index);
    int i=0;
    for (IRCClient *cl in self.connections) {
        if([cl.configuration.uniqueIdentifier isEqualToString:client.configuration.uniqueIdentifier]) {
            if(index < client.getChannels.count) {
                IRCChannel *channel = [client.getChannels objectAtIndex:index];
                channel.joined = NO;
                [client.getChannels setObject:channel atIndexedSubscript:index];
                [self.connections setObject:client atIndexedSubscript:i];
            } else {
                IRCConversation *query = [client.getQueries objectAtIndex:index-client.getChannels.count];
                query.conversationPartnerIsOnline = NO;
                [client.getChannels setObject:query atIndexedSubscript:index-client.getChannels.count];
                [self.connections setObject:client atIndexedSubscript:i];
            }
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
    NSLog(@"Show Settings");
}

- (void)addConversation:(id)sender
{
    if(self.connections.count == 0) {
        [self editConnection:nil];
    } else {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Add Conversation", @"Add Conversation")
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:NSLocalizedString(@"Join a Channel", @"Join a Channel"), NSLocalizedString(@"Message a User", @"Message a User"), NSLocalizedString(@"Add Connection", @"Add Connection"), nil];
        [sheet setTag:-1];
        [sheet showInView:self.view];
    }
}

- (void)reloadData
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
    
    [self presentViewController:navigationController animated:YES completion: nil];
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
    
    [self presentViewController:navigationController animated:YES completion: nil];
}

- (void)sortConversationsForClientAtIndex:(NSInteger)index
{
    IRCClient *client = _connections[index];
    if(client != nil) {
        [client sortChannelItems];
        [client sortQueryItems];
        [_connections setObject:client atIndexedSubscript:index];
        [[AppPreferences sharedPrefs] setChannels:client.getChannels andQueries:client.getQueries forConnectionConfiguration:client.configuration];
        [self.tableView reloadData];        
    }
}

#pragma mark - Table View

- (NSIndexPath *) tableView:(UITableView *) tableView willSelectRowAtIndexPath:(NSIndexPath *) indexPath {
    return indexPath;
}

- (void) tableView:(UITableView *) tableView didSelectRowAtIndexPath:(NSIndexPath *) indexPath
{
    IRCClient *client = [self.connections objectAtIndex:indexPath.section];
    IRCChannel *channel = [client.getChannels objectAtIndex:indexPath.row];
    
    DetailViewController *controller = [[DetailViewController alloc] initWithStyle:UITableViewStyleGrouped];
    controller.title = channel.name;
    [self.navigationController pushViewController:controller animated:YES];

}


- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    if(self.connections.count > 0) {
        UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
        
        // Set colors
        [header.textLabel setTextColor:[UIColor darkGrayColor]];
        header.contentView.backgroundColor = [UIColor whiteColor];
        
        // Set Label
        IRCClient *client = [self.connections objectAtIndex:section];
        header.textLabel.text = client.configuration.connectionName;
        header.tag = section;
        
        // Add Tap Event
        UITapGestureRecognizer *singleTapRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerViewSelected:)];
        [singleTapRecogniser setDelegate:self];
        singleTapRecogniser.numberOfTouchesRequired = 1;
        singleTapRecogniser.numberOfTapsRequired = 1;
        [header addGestureRecognizer:singleTapRecogniser];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    
    return 20.0;
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
    return client.getChannels.count + client.getQueries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    static NSString *CellIdentifier = @"cell";
    ConversationItemView *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[ConversationItemView alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    
    IRCClient *client = [_connections objectAtIndex:indexPath.section];
    NSArray *channels = client.getChannels;
    if((int)indexPath.row > (int)channels.count-1) {
        NSInteger index;
        index = indexPath.row - client.getChannels.count;
        IRCConversation *query = [client.getQueries objectAtIndex:index];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.enabled = query.conversationPartnerIsOnline;
        cell.name = query.name;
        cell.isChannel = NO;
        cell.unreadCount = 350;
        cell.detail = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec a diam lectus.\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Donec a diam lectus. ";
        
    } else {
        IRCChannel *channel = [client.getChannels objectAtIndex:indexPath.row];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.enabled = channel.joined;
        cell.name = channel.name;
        cell.isChannel = YES;
        cell.unreadCount = 350;
        cell.detail = @"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec a diam lectus.\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Donec a diam lectus. ";
        
    }

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    IRCClient *client = _connections[indexPath.section];
    NSInteger index = indexPath.row;
    if ((int)indexPath.row > (int)client.getChannels.count-1) {
        index = indexPath.row - client.getChannels.count;
        IRCConversation *query = client.getQueries[index];
        [client removeQuery:query];
        
        // Remove from prefs
        [[AppPreferences sharedPrefs] deleteQueryWithName:query.name forConnectionConfiguration:client.configuration];
    } else {
        IRCChannel *channel = client.getChannels[index];
        [client removeChannel:channel];
        
        // Remove from prefs
        [[AppPreferences sharedPrefs] deleteChannelWithName:channel.name forConnectionConfiguration:client.configuration];
    }
    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)headerViewSelected:(UIGestureRecognizer *)sender
{
    // Get relevant client
    IRCClient *client = [self.connections objectAtIndex:sender.view.tag];

    UIActionSheet *sheet;
    
    if([client isConnected]) {
        sheet = [[UIActionSheet alloc] initWithTitle:client.configuration.connectionName
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:NSLocalizedString(@"Disconnect", @"Disconnect server"),
                 NSLocalizedString(@"Sort Conversations", "Sort Conversations"),
                 NSLocalizedString(@"Edit", @"Edit Connection"), nil];
        [sheet setDestructiveButtonIndex:0];
    } else {
        sheet = [[UIActionSheet alloc] initWithTitle:client.configuration.connectionName
                                        delegate:self
                               cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
                          destructiveButtonTitle:nil
                               otherButtonTitles:NSLocalizedString(@"Connect", @"Connect server"),
                 NSLocalizedString(@"Sort Conversations", "Sort Conversations"),
                 NSLocalizedString(@"Edit", @"Edit Connection"),
                 NSLocalizedString(@"Delete", @"Delete connection"), nil];
        [sheet setDestructiveButtonIndex:3];
    }
    
    [sheet setTag:sender.view.tag];
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (actionSheet.tag == -1) {
        // Conversations action sheet
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
    } else {
        // Connections action sheet
        IRCClient *client = [self.connections objectAtIndex:actionSheet.tag];
        UIAlertView *alertView;
        
        switch (buttonIndex) {
            case 0:
                // Connect or disconnect
                if(client.isConnected)
                   [client disconnect];
                else
                    [client connect];
                break;
            case 1:
                // Sort Conversations
                [self sortConversationsForClientAtIndex:actionSheet.tag];
                break;
            case 2:
                // Edit
                [self editConnection:client.configuration];
                break;
            case 3:
                // Delete
                if(!client.isConnected) {
                    alertView = [[UIAlertView alloc] initWithTitle:client.configuration.connectionName
                                                           message:NSLocalizedString(@"Do you really want to delete this connection?", @"Delete connection confirmation")
                                                          delegate:self
                                                 cancelButtonTitle:NSLocalizedString(@"No", @"no")
                                                 otherButtonTitles:NSLocalizedString(@"Yes", @"yes"), nil];
                    alertView.tag = actionSheet.tag;
                    [alertView show];
                }
                break;
            default:
                break;
        }
    }
}

- (void)conversationAdded:(AddConversationViewController *)sender
{

    NSMutableArray *connections = [sender.connections mutableCopy];
    
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
            [[AppPreferences sharedPrefs] addChannelConfiguration:sender.configuration forConnectionConfiguration:sender.client.configuration];
            
        } else {
            IRCConversation *query = [[IRCConversation alloc] initWithConfiguration:sender.configuration withClient:sender.client];
            [client addQuery:query];
            
            // Save config
            [[AppPreferences sharedPrefs] addQueryConfiguration:sender.configuration forConnectionConfiguration:sender.client.configuration];
            
        }
        
        [connections setObject:client atIndexedSubscript:i];
    }
    _connections = connections;
    
    
    
    [self.tableView reloadData];
    [[AppPreferences sharedPrefs] save];
    
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // Delete connection
    if(buttonIndex == YES) {
        IRCClient *client = [self.connections objectAtIndex:alertView.tag];
        if(client.isConnected)
            [client disconnect];
        [[AppPreferences sharedPrefs] deleteConnectionWithIdentifier:client.configuration.uniqueIdentifier];
        [self.connections removeObjectAtIndex:alertView.tag];
        [self.tableView reloadData];
    }
}

- (void)joinChannelWithName:(NSString *)name onClient:(IRCClient *)client
{
    IRCChannelConfiguration *configuration = [[IRCChannelConfiguration alloc] init];
    configuration.name = name;
    IRCChannel *channel = [[IRCChannel alloc] initWithConfiguration:configuration withClient:client];
    [client addChannel:channel];
    
    int i=0;
    for (IRCClient *cl in _connections) {
        if([cl.configuration.uniqueIdentifier isEqualToString:client.configuration.uniqueIdentifier]) {
            break;
        }
        i++;
    }
    [_connections setObject:client atIndexedSubscript:i];
    [self.tableView reloadData];
    [[AppPreferences sharedPrefs] addChannelConfiguration:configuration forConnectionConfiguration:client.configuration];
    [[AppPreferences sharedPrefs] save];
}

@end

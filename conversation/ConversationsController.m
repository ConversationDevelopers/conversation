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

#import "ConversationsController.h"
#import "DetailViewController.h"
#import "EditConnectionViewController.h"
#import "IRCClient.h"
#import "AppPreferences.h"

@interface ConversationsController ()

@property NSMutableArray *objects;
@end

@implementation ConversationsController

- (void)awakeFromNib
{
    [super awakeFromNib];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
    if (!self.connections) {
        self.connections = [[NSMutableArray alloc] init];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
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
    
    self.detailViewController = (DetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    
    NSArray *configurations = [[AppPreferences sharedPrefs] getConnectionConfigurations];
    for (NSDictionary *dict in configurations) {
        IRCConnectionConfiguration *configuration = [[IRCConnectionConfiguration alloc] initWithDictionary:dict];
        IRCClient *client = [[IRCClient alloc] initWithConfiguration:configuration];
        [self.connections addObject:client];
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
    EditConnectionViewController *editController = [[EditConnectionViewController alloc] init];

    editController.conversationsController = self;
    
    UINavigationController *navigationController = [[UINavigationController alloc]
                                                    
                                                    initWithRootViewController:editController];
    
    [self presentViewController:navigationController animated:YES completion: nil];
    
/*
    if (!self.objects) {
        self.objects = [[NSMutableArray alloc] init];
    }
    [self.objects insertObject:[NSDate date] atIndex:0];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
*/
}

- (void)reloadData
{
    [self.tableView reloadData];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        NSDate *object = self.objects[indexPath.row];
        DetailViewController *controller = (DetailViewController *)[[segue destinationViewController] topViewController];
        [controller setDetailItem:object];
        controller.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
        controller.navigationItem.leftItemsSupplementBackButton = YES;
    }
}

#pragma mark - Table View

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

- (double)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    
    return  20.0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.objects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

    NSDate *object = self.objects[indexPath.row];
    cell.textLabel.text = [object description];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [self.objects removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }
}

- (void)headerViewSelected:(UIGestureRecognizer *)sender
{
    // Get relevant client
    IRCClient *client = [self.connections objectAtIndex:sender.view.tag];
    
    // Connect or disconnect
    NSString *firstAction;
    if([client isConnected])
        firstAction = NSLocalizedString(@"Disconnect", @"Disconnect server");
    else
        firstAction = NSLocalizedString(@"Connect", @"Connect server");
    
    // Define action sheet
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:client.configuration.connectionName
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:firstAction, NSLocalizedString(@"Edit", @"Edit Connection"), NSLocalizedString(@"Delete", @"Delete connection"), nil];
    [sheet setTag:sender.view.tag];
    [sheet setDestructiveButtonIndex:2];
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
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
            // Edit
            break;
        case 2:
            // Delete
            alertView = [[UIAlertView alloc] initWithTitle:client.configuration.connectionName
                                                   message:NSLocalizedString(@"Do you really want to delete this connection?", @"Delete connection confirmation")
                                                  delegate:self
                                         cancelButtonTitle:NSLocalizedString(@"no", @"no")
                                         otherButtonTitles:NSLocalizedString(@"yes", @"yes"), nil];
            alertView.tag = actionSheet.tag;
            [alertView show];
            break;
        default:
            break;
    }
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

@end

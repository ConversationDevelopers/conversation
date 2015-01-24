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

#import <UIKit/UIKit.h>
#import <InAppSettingsKit/IASKAppSettingsViewController.h>

@class ChatViewController;
@class IRCClient;
@class IRCConversation;
@class IRCChannel;
@class IRCCertificateTrust;

@interface ConversationListViewController : UITableViewController <UIGestureRecognizerDelegate, UIActionSheetDelegate, UIAlertViewDelegate, IASKSettingsDelegate> {
    UIBackgroundTaskIdentifier _backgroundTask;
}

@property (nonatomic) IRCConversation *currentConversation;
@property (nonatomic, retain) NSMutableArray *connections;
@property (nonatomic) ChatViewController *chatViewController;

- (void)reloadClient:(IRCClient *)client;
- (IRCChannel *)joinChannelWithName:(NSString *)name onClient:(IRCClient *)client;
- (void)selectConversationWithIdentifier:(NSString *)identifier;
- (IRCConversation *)createConversationWithName:(NSString *)name onClient:(IRCClient *)client;
- (void)showInivitationRequiredAlertForChannel:(NSString *)channelName;
- (void)requestUserTrustForCertificate:(IRCCertificateTrust *)trustRequest;
- (void)displayPasswordEntryDialog:(IRCClient *)client;
- (void)setAway;
- (void)setBack;
- (void)disconnect;

@end


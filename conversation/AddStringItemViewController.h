//
//  AddStringItemViewController.h
//  Conversation
//
//  Created by Toby P on 03/11/14.
//  Copyright (c) 2014 conversation. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AddStringItemViewController : UITableViewController <UITableViewDataSource> {
    BOOL _badInput;
}

@property (nonatomic, weak) id target;
@property (nonatomic) SEL action;
@property (nonatomic) NSString *stringValue;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic) NSString *saveButtonTitle;
@property (nonatomic) NSString *textFieldLabelTitle;
@end

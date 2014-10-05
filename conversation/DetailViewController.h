//
//  DetailViewController.h
//  conversation
//
//  Created by Toby P on 05/10/14.
//  Copyright (c) 2014 conversation. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController

@property (strong, nonatomic) id detailItem;
@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

@end


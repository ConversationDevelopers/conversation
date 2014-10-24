//
//  ChatMessageView.h
//  Conversation
//
//  Created by Toby P on 24/10/14.
//  Copyright (c) 2014 conversation. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ChatMessageView : UITableViewCell {
    UILabel *_nameLabel;
    UILabel *_messageLabel;
}

@property (nonatomic) NSString *nickname;
@property (nonatomic) NSAttributedString *message;

@end

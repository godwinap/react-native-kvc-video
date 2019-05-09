//
//  UIView+FindUIViewController.h
//  RNFullscreenClient
//
//  Created by Godwin Vinny Carole on 07/05/19.
//  Copyright © 2019 Godwin Vinny Carole. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (FindUIViewController)
- (UIViewController *) firstAvailableUIViewController;
- (id) traverseResponderChainForUIViewController;
@end


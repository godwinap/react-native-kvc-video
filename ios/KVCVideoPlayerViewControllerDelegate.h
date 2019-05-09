//
//  Header.h
//  RNFullscreenClient
//
//  Created by Godwin Vinny Carole on 07/05/19.
//  Copyright © 2019 Godwin Vinny Carole. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AVKit/AVKit.h"

@protocol KVCVideoPlayerViewControllerDelegate <NSObject>
- (void)videoPlayerViewControllerWillDismiss:(AVPlayerViewController *)playerViewController;
- (void)videoPlayerViewControllerDidDismiss:(AVPlayerViewController *)playerViewController;
@end

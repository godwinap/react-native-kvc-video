//
//  KVCVideoPlayerViewController.h
//  RNFullscreenClient
//
//  Created by Godwin Vinny Carole on 07/05/19.
//  Copyright © 2019 Godwin Vinny Carole. All rights reserved.
//

#import <AVKit/AVKit.h>
#import "KVCVideo.h"
#import "KVCVideoPlayerViewControllerDelegate.h"

@interface KVCVideoPlayerViewController : AVPlayerViewController
@property (nonatomic, weak) id<KVCVideoPlayerViewControllerDelegate> rctDelegate;

// Optional paramters
@property (nonatomic, weak) NSString* preferredOrientation;
@property (nonatomic) BOOL autorotate;

@end

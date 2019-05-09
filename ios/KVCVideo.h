//
//  KVCVideo.h
//  RNFullscreenClient
//
//  Created by Godwin Vinny Carole on 07/05/19.
//  Copyright © 2019 Godwin Vinny Carole. All rights reserved.
//

#import <React/RCTViewManager.h>
#import <AVFoundation/AVFoundation.h>
#import "AVKit/AVKit.h"
#import "KVCVideoPlayerViewControllerDelegate.h"
#import "UIView+FindUIViewController.h"
#import "KVCVideoPlayerViewController.h"
#import <React/RCTComponent.h>
#import <React/RCTBridgeModule.h>

@class RCTEventDispatcher;

@interface KVCVideo : UIView <KVCVideoPlayerViewControllerDelegate, AVPictureInPictureControllerDelegate>

@property (nonatomic, copy) RCTBubblingEventBlock onVideoLoadStart;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoLoad;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoBuffer;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoError;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoProgress;
@property (nonatomic, copy) RCTBubblingEventBlock onBandwidthUpdate;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoSeek;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoEnd;
@property (nonatomic, copy) RCTBubblingEventBlock onTimedMetadata;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoAudioBecomingNoisy;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoFullscreenPlayerWillPresent;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoFullscreenPlayerDidPresent;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoFullscreenPlayerWillDismiss;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoFullscreenPlayerDidDismiss;
@property (nonatomic, copy) RCTBubblingEventBlock onReadyForDisplay;
@property (nonatomic, copy) RCTBubblingEventBlock onPlaybackStalled;
@property (nonatomic, copy) RCTBubblingEventBlock onPlaybackResume;
@property (nonatomic, copy) RCTBubblingEventBlock onPlaybackRateChange;
@property (nonatomic, copy) RCTBubblingEventBlock onVideoExternalPlaybackChange;
@property (nonatomic, copy) RCTBubblingEventBlock onPictureInPictureStatusChanged;
@property (nonatomic, copy) RCTBubblingEventBlock onRestoreUserInterfaceForPictureInPictureStop;
@property (nonatomic, assign) NSString *exampleProp;

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher NS_DESIGNATED_INITIALIZER;

- (AVPlayerViewController*)createPlayerViewController:(AVPlayer*)player withPlayerItem:(AVPlayerItem*)playerItem;

- (void)save:(NSDictionary *)options resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject;

@end

@interface KVCVideoManager : RCTViewManager

@end


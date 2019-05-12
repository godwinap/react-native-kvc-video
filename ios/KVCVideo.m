#import "KVCVideo.h"
#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <React/RCTConvert.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>
#import <React/UIView+React.h>
#include <MediaAccessibility/MediaAccessibility.h>
#include <AVFoundation/AVFoundation.h>

static NSString *const statusKeyPath = @"status";
static NSString *const playbackLikelyToKeepUpKeyPath = @"playbackLikelyToKeepUp";
static NSString *const playbackBufferEmptyKeyPath = @"playbackBufferEmpty";
static NSString *const readyForDisplayKeyPath = @"readyForDisplay";
static NSString *const playbackRate = @"rate";
static NSString *const timedMetadata = @"timedMetadata";
static NSString *const externalPlaybackActive = @"externalPlaybackActive";

static int const RCTVideoUnset = -1;

#ifdef DEBUG
#define DebugLog(...) NSLog(__VA_ARGS__)
#else
#define DebugLog(...) (void)0
#endif

@implementation KVCVideo
{
  AVPlayer *_player;
  AVPlayerItem *_playerItem;
  NSDictionary *_source;
  BOOL _playerItemObserversSet;
  BOOL _playerBufferEmpty;
  AVPlayerLayer *_playerLayer;
  BOOL _playerLayerObserverSet;
  KVCVideoPlayerViewController *_playerViewController;
  NSURL *_videoURL;
  
  /* Vars defined by 👑Godwin*/
  UIView *controlsOverlay;
  UIView *detailsContainer;
  UIView *controlsContainer;
  UIView *ReactSubView;
  UITapGestureRecognizer  *toggleControlsOnTap;
  BOOL showingControls;
  NSDictionary * _playBtnImg;
  NSDictionary * _pauseBtnImg;
  UIImage *PlayBtnImg;
  UIImage *PauseBtnImg;
  UIButton *PlayPauseButton;
  NSDictionary * _rewindBtnImg;
  NSDictionary * _forwardBtnImg;
  UIImage *RewindBtnImg;
  UIImage *ForwardBtnImg;
  UIButton *RewindButton;
  UIButton *ForwardButton;
  float _rewindAndForwardInterval;
  UISlider *Seekbar;
  NSDictionary * _seekbarCursorImg;
  NSDictionary * _seekbarCursorActiveImg;
  UIImage *SeekbarCursorImg;
  UIImage *SeekbarCursorActiveImg;
  NSNumber *_seekbarMaxTint;
  NSNumber *_seekbarMinTint;
  UITextView *CurrentTimeTextView;
  UITextView *DurationTextView;
  NSDictionary *_fullscreenImg;
  UIImage *FullscreenImg;
  UIButton *FullscreenButton;
  NSInteger currentOrientation;
  
  /**************/
  
  /* Required to publish events */
  RCTEventDispatcher *_eventDispatcher;
  BOOL _playbackRateObserverRegistered;
  BOOL _isExternalPlaybackActiveObserverRegistered;
  BOOL _videoLoadStarted;
  
  bool _pendingSeek;
  float _pendingSeekTime;
  float _lastSeekTime;
  
  /* For sending videoProgress events */
  Float64 _progressUpdateInterval;
  BOOL _controls;
  id _timeObserver;
  
  /* Keep track of any modifiers, need to be applied after each play */
  float _volume;
  float _rate;
  float _maxBitRate;
  
  BOOL _muted;
  BOOL _paused;
  BOOL _repeat;
  BOOL _allowsExternalPlayback;
  NSArray * _textTracks;
  NSDictionary * _selectedTextTrack;
  NSDictionary * _selectedAudioTrack;
  BOOL _playbackStalled;
  BOOL _playInBackground;
  BOOL _playWhenInactive;
  BOOL _pictureInPicture;
  NSString * _ignoreSilentSwitch;
  NSString * _resizeMode;
  BOOL _fullscreen;
  BOOL _fullscreenAutorotate;
  NSString * _fullscreenOrientation;
  BOOL _fullscreenPlayerPresented;
  NSString *_filterName;
  BOOL _filterEnabled;
  UIViewController * _presentingViewController;
#if __has_include(<react-native-video/RCTVideoCache.h>)
  RCTVideoCache * _videoCache;
#endif
#if TARGET_OS_IOS
  void (^__strong _Nonnull _restoreUserInterfaceForPIPStopCompletionHandler)(BOOL);
  AVPictureInPictureController *_pipController;
#endif
}

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher
{
  if ((self = [super init])) {
    NSLog(@"godwin: KVC Video initilized");
    _eventDispatcher = eventDispatcher;
    
    _playbackRateObserverRegistered = NO;
    _isExternalPlaybackActiveObserverRegistered = NO;
    _playbackStalled = NO;
    _rate = 1.0;
    _volume = 1.0;
    _resizeMode = @"AVLayerVideoGravityResizeAspectFill";
    _fullscreenAutorotate = YES;
    _fullscreenOrientation = @"all";
    _pendingSeek = false;
    _pendingSeekTime = 0.0f;
    _lastSeekTime = 0.0f;
    _progressUpdateInterval = 250;
    _controls = NO;
    _playerBufferEmpty = YES;
    _playInBackground = false;
    _allowsExternalPlayback = YES;
    _playWhenInactive = false;
    _pictureInPicture = false;
    _ignoreSilentSwitch = @"ignore"; // inherit, ignore, obey
    
    
    /* 👑Godwin's Var inits*/
    showingControls = false;
    _rewindAndForwardInterval = 10;
    currentOrientation = 0;
    /********/
#if TARGET_OS_IOS
    _restoreUserInterfaceForPIPStopCompletionHandler = NULL;
#endif
#if __has_include(<react-native-video/RCTVideoCache.h>)
    _videoCache = [RCTVideoCache sharedInstance];
#endif
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioRouteChanged:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter]
     addObserver:self selector:@selector(orientationChanged:)
     name:UIDeviceOrientationDidChangeNotification
     object:[UIDevice currentDevice]];
  }
  
  return self;
}

- (KVCVideoPlayerViewController*)createPlayerViewController:(AVPlayer*)player
                                             withPlayerItem:(AVPlayerItem*)playerItem {
  KVCVideoPlayerViewController* viewController = [[KVCVideoPlayerViewController alloc] init];
  viewController.showsPlaybackControls = YES;
  viewController.rctDelegate = self;
  viewController.preferredOrientation = _fullscreenOrientation;
  
  viewController.view.frame = self.bounds;
  viewController.player = player;
  return viewController;
}

/* ---------------------------------------------------------
 **  Get the duration for a AVPlayerItem.
 ** ------------------------------------------------------- */

- (CMTime)playerItemDuration
{
  AVPlayerItem *playerItem = [_player currentItem];
  if (playerItem.status == AVPlayerItemStatusReadyToPlay)
  {
    return([playerItem duration]);
  }
  
  return(kCMTimeInvalid);
}

- (CMTimeRange)playerItemSeekableTimeRange
{
  AVPlayerItem *playerItem = [_player currentItem];
  if (playerItem.status == AVPlayerItemStatusReadyToPlay)
  {
    return [playerItem seekableTimeRanges].firstObject.CMTimeRangeValue;
  }
  
  return (kCMTimeRangeZero);
}

-(void)addPlayerTimeObserver
{
  const Float64 progressUpdateIntervalMS = _progressUpdateInterval / 1000;
  // @see endScrubbing in AVPlayerDemoPlaybackViewController.m
  // of https://developer.apple.com/library/ios/samplecode/AVPlayerDemo/Introduction/Intro.html
  __weak KVCVideo *weakSelf = self;
  _timeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(progressUpdateIntervalMS, NSEC_PER_SEC)
                                                        queue:NULL
                                                   usingBlock:^(CMTime time) { [weakSelf sendProgressUpdate]; }
                   ];
}

/* Cancels the previously registered time observer. */
-(void)removePlayerTimeObserver
{
  if (_timeObserver)
  {
    [_player removeTimeObserver:_timeObserver];
    _timeObserver = nil;
  }
}

#pragma mark - Progress

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self removePlayerLayer];
  [self removePlayerItemObservers];
  [_player removeObserver:self forKeyPath:playbackRate context:nil];
  [_player removeObserver:self forKeyPath:externalPlaybackActive context: nil];
}

#pragma mark - App lifecycle handlers

- (void)applicationWillResignActive:(NSNotification *)notification
{
  if (_playInBackground || _playWhenInactive || _paused) return;
  
  [_player pause];
  [_player setRate:0.0];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
  if (_playInBackground) {
    // Needed to play sound in background. See https://developer.apple.com/library/ios/qa/qa1668/_index.html
    [_playerLayer setPlayer:nil];
  }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
  [self applyModifiers];
  if (_playInBackground) {
    [_playerLayer setPlayer:_player];
  }
}

#pragma mark - Audio events

- (void)audioRouteChanged:(NSNotification *)notification
{
  NSNumber *reason = [[notification userInfo] objectForKey:AVAudioSessionRouteChangeReasonKey];
  NSNumber *previousRoute = [[notification userInfo] objectForKey:AVAudioSessionRouteChangePreviousRouteKey];
  if (reason.unsignedIntValue == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
    self.onVideoAudioBecomingNoisy(@{@"target": self.reactTag});
  }
}

#pragma mark - Progress

- (void)sendProgressUpdate
{
  AVPlayerItem *video = [_player currentItem];
  if (video == nil || video.status != AVPlayerItemStatusReadyToPlay) {
    return;
  }
  
  CMTime playerDuration = [self playerItemDuration];
  if (CMTIME_IS_INVALID(playerDuration)) {
    return;
  }
  
  CMTime currentTime = _player.currentTime;
  const Float64 duration = CMTimeGetSeconds(playerDuration);
  const Float64 currentTimeSecs = CMTimeGetSeconds(currentTime);
  [[NSNotificationCenter defaultCenter] postNotificationName:@"RCTVideo_progress" object:nil userInfo:@{@"progress": [NSNumber numberWithDouble: currentTimeSecs / duration]}];
  
  if( currentTimeSecs >= 0 && self.onVideoProgress) {
    
    /* update 👑Godwin's Video Seekbar progress over here 👇🏻 */
    [self syncSeekbar];
    [CurrentTimeTextView setText:[self timeFormatted:CMTimeGetSeconds(currentTime)]];
    /*******/
    
    self.onVideoProgress(@{
                           @"currentTime": [NSNumber numberWithFloat:CMTimeGetSeconds(currentTime)],
                           @"playableDuration": [self calculatePlayableDuration],
                           @"atValue": [NSNumber numberWithLongLong:currentTime.value],
                           @"atTimescale": [NSNumber numberWithInt:currentTime.timescale],
                           @"target": self.reactTag,
                           @"seekableDuration": [self calculateSeekableDuration],
                           });
  }
}

/*!
 * Calculates and returns the playable duration of the current player item using its loaded time ranges.
 *
 * \returns The playable duration of the current player item in seconds.
 */
- (NSNumber *)calculatePlayableDuration
{
  AVPlayerItem *video = _player.currentItem;
  if (video.status == AVPlayerItemStatusReadyToPlay) {
    __block CMTimeRange effectiveTimeRange;
    [video.loadedTimeRanges enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
      CMTimeRange timeRange = [obj CMTimeRangeValue];
      if (CMTimeRangeContainsTime(timeRange, video.currentTime)) {
        effectiveTimeRange = timeRange;
        *stop = YES;
      }
    }];
    Float64 playableDuration = CMTimeGetSeconds(CMTimeRangeGetEnd(effectiveTimeRange));
    if (playableDuration > 0) {
      return [NSNumber numberWithFloat:playableDuration];
    }
  }
  return [NSNumber numberWithInteger:0];
}

- (NSNumber *)calculateSeekableDuration
{
  CMTimeRange timeRange = [self playerItemSeekableTimeRange];
  if (CMTIME_IS_NUMERIC(timeRange.duration))
  {
    // Setting the Time dutaion for `DurationTextView` of 👑Godwin's Vidoe controls.
    [DurationTextView setText:[self timeFormatted:CMTimeGetSeconds(timeRange.duration)]];
    return [NSNumber numberWithFloat:CMTimeGetSeconds(timeRange.duration)];
  }
  return [NSNumber numberWithInteger:0];
}

- (void)addPlayerItemObservers
{
  [_playerItem addObserver:self forKeyPath:statusKeyPath options:0 context:nil];
  [_playerItem addObserver:self forKeyPath:playbackBufferEmptyKeyPath options:0 context:nil];
  [_playerItem addObserver:self forKeyPath:playbackLikelyToKeepUpKeyPath options:0 context:nil];
  [_playerItem addObserver:self forKeyPath:timedMetadata options:NSKeyValueObservingOptionNew context:nil];
  _playerItemObserversSet = YES;
}

/* Fixes https://github.com/brentvatne/react-native-video/issues/43
 * Crashes caused when trying to remove the observer when there is no
 * observer set */
- (void)removePlayerItemObservers
{
  if (_playerItemObserversSet) {
    [_playerItem removeObserver:self forKeyPath:statusKeyPath];
    [_playerItem removeObserver:self forKeyPath:playbackBufferEmptyKeyPath];
    [_playerItem removeObserver:self forKeyPath:playbackLikelyToKeepUpKeyPath];
    [_playerItem removeObserver:self forKeyPath:timedMetadata];
    _playerItemObserversSet = NO;
  }
}

#pragma mark - Player and source

- (void)setSrc:(NSDictionary *)source
{
  _source = source;
  [self removePlayerLayer];
  [self removePlayerTimeObserver];
  [self removePlayerItemObservers];
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) 0), dispatch_get_main_queue(), ^{
    
    // perform on next run loop, otherwise other passed react-props may not be set
    [self playerItemForSource:source withCallback:^(AVPlayerItem * playerItem) {
      _playerItem = playerItem;
      [self addPlayerItemObservers];
      [self setFilter:_filterName];
      [self setMaxBitRate:_maxBitRate];
      
      [_player pause];
      [_playerViewController.view removeFromSuperview];
      _playerViewController = nil;
      
      if (_playbackRateObserverRegistered) {
        [_player removeObserver:self forKeyPath:playbackRate context:nil];
        _playbackRateObserverRegistered = NO;
      }
      if (_isExternalPlaybackActiveObserverRegistered) {
        [_player removeObserver:self forKeyPath:externalPlaybackActive context:nil];
        _isExternalPlaybackActiveObserverRegistered = NO;
      }
      
      _player = [AVPlayer playerWithPlayerItem:_playerItem];
      _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
      
      [_player addObserver:self forKeyPath:playbackRate options:0 context:nil];
      _playbackRateObserverRegistered = YES;
      
      [_player addObserver:self forKeyPath:externalPlaybackActive options:0 context:nil];
      _isExternalPlaybackActiveObserverRegistered = YES;
      
      [self addPlayerTimeObserver];
      
      //Perform on next run loop, otherwise onVideoLoadStart is nil
      if (self.onVideoLoadStart) {
        id uri = [source objectForKey:@"uri"];
        id type = [source objectForKey:@"type"];
        self.onVideoLoadStart(@{@"src": @{
                                    @"uri": uri ? uri : [NSNull null],
                                    @"type": type ? type : [NSNull null],
                                    @"isNetwork": [NSNumber numberWithBool:(bool)[source objectForKey:@"isNetwork"]]},
                                @"target": self.reactTag
                                });
      }
    }];
  });
  _videoLoadStarted = YES;
}

- (NSURL*) urlFilePath:(NSString*) filepath {
  if ([filepath containsString:@"file://"]) {
    return [NSURL URLWithString:filepath];
  }
  
  // if no file found, check if the file exists in the Document directory
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString* relativeFilePath = [filepath lastPathComponent];
  // the file may be multiple levels below the documents directory
  NSArray* fileComponents = [filepath componentsSeparatedByString:@"Documents/"];
  if (fileComponents.count > 1) {
    relativeFilePath = [fileComponents objectAtIndex:1];
  }
  
  NSString *path = [paths.firstObject stringByAppendingPathComponent:relativeFilePath];
  if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
    return [NSURL fileURLWithPath:path];
  }
  return nil;
}

- (void)playerItemPrepareText:(AVAsset *)asset assetOptions:(NSDictionary * __nullable)assetOptions withCallback:(void(^)(AVPlayerItem *))handler
{
  if (!_textTracks || _textTracks.count==0) {
    handler([AVPlayerItem playerItemWithAsset:asset]);
    return;
  }
  
  // AVPlayer can't airplay AVMutableCompositions
  _allowsExternalPlayback = NO;
  
  // sideload text tracks
  AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];
  
  AVAssetTrack *videoAsset = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
  AVMutableCompositionTrack *videoCompTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
  [videoCompTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.timeRange.duration)
                          ofTrack:videoAsset
                           atTime:kCMTimeZero
                            error:nil];
  
  AVAssetTrack *audioAsset = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
  AVMutableCompositionTrack *audioCompTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
  [audioCompTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.timeRange.duration)
                          ofTrack:audioAsset
                           atTime:kCMTimeZero
                            error:nil];
  
  NSMutableArray* validTextTracks = [NSMutableArray array];
  for (int i = 0; i < _textTracks.count; ++i) {
    AVURLAsset *textURLAsset;
    NSString *textUri = [_textTracks objectAtIndex:i][@"uri"];
    if ([[textUri lowercaseString] hasPrefix:@"http"]) {
      textURLAsset = [AVURLAsset URLAssetWithURL:[NSURL URLWithString:textUri] options:assetOptions];
    } else {
      textURLAsset = [AVURLAsset URLAssetWithURL:[self urlFilePath:textUri] options:nil];
    }
    AVAssetTrack *textTrackAsset = [textURLAsset tracksWithMediaType:AVMediaTypeText].firstObject;
    if (!textTrackAsset) continue; // fix when there's no textTrackAsset
    [validTextTracks addObject:[_textTracks objectAtIndex:i]];
    AVMutableCompositionTrack *textCompTrack = [mixComposition
                                                addMutableTrackWithMediaType:AVMediaTypeText
                                                preferredTrackID:kCMPersistentTrackID_Invalid];
    [textCompTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAsset.timeRange.duration)
                           ofTrack:textTrackAsset
                            atTime:kCMTimeZero
                             error:nil];
  }
  if (validTextTracks.count != _textTracks.count) {
    [self setTextTracks:validTextTracks];
  }
  
  handler([AVPlayerItem playerItemWithAsset:mixComposition]);
}

- (void)playerItemForSource:(NSDictionary *)source withCallback:(void(^)(AVPlayerItem *))handler
{
  
  NSLog(@"%@", [NSString stringWithFormat:@"godwin:🥳 KVC Video Started %@", [self convertToString:source]]);
  bool isNetwork = [RCTConvert BOOL:[source objectForKey:@"isNetwork"]];
  bool isAsset = [RCTConvert BOOL:[source objectForKey:@"isAsset"]];
//  bool shouldCache = [RCTConvert BOOL:[source objectForKey:@"shouldCache"]];
  NSString *uri = [source objectForKey:@"uri"];
  NSString *type = [source objectForKey:@"type"];
  if (!uri || [uri isEqualToString:@""]) {
    NSLog(@"Could not find video URL in source '%@'", source);
    return;
  }
  
  NSURL *url = isNetwork || isAsset
  ? [NSURL URLWithString:uri]
  : [[NSURL alloc] initFileURLWithPath:[[NSBundle mainBundle] pathForResource:uri ofType:type]];
  NSMutableDictionary *assetOptions = [[NSMutableDictionary alloc] init];
  
  if (isNetwork) {
    /* Per #1091, this is not a public API.
     * We need to either get approval from Apple to use this  or use a different approach.
     NSDictionary *headers = [source objectForKey:@"requestHeaders"];
     if ([headers count] > 0) {
     [assetOptions setObject:headers forKey:@"AVURLAssetHTTPHeaderFieldsKey"];
     }
     */
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    [assetOptions setObject:cookies forKey:AVURLAssetHTTPCookiesKey];
    
#if __has_include(<react-native-video/RCTVideoCache.h>)
    if (shouldCache && (!_textTracks || !_textTracks.count)) {
      /* The DVURLAsset created by cache doesn't have a tracksWithMediaType property, so trying
       * to bring in the text track code will crash. I suspect this is because the asset hasn't fully loaded.
       * Until this is fixed, we need to bypass caching when text tracks are specified.
       */
      DebugLog(@"Caching is not supported for uri '%@' because text tracks are not compatible with the cache. Checkout https://github.com/react-native-community/react-native-video/blob/master/docs/caching.md", uri);
      [self playerItemForSourceUsingCache:uri assetOptions:assetOptions withCallback:handler];
      return;
    }
#endif
    
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:assetOptions];
    [self playerItemPrepareText:asset assetOptions:assetOptions withCallback:handler];
    return;
  } else if (isAsset) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    [self playerItemPrepareText:asset assetOptions:assetOptions withCallback:handler];
    return;
  }
  
  AVURLAsset *asset = [AVURLAsset URLAssetWithURL:[[NSURL alloc] initFileURLWithPath:[[NSBundle mainBundle] pathForResource:uri ofType:type]] options:nil];
  [self playerItemPrepareText:asset assetOptions:assetOptions withCallback:handler];
}

#if __has_include(<react-native-video/RCTVideoCache.h>)

- (void)playerItemForSourceUsingCache:(NSString *)uri assetOptions:(NSDictionary *)options withCallback:(void(^)(AVPlayerItem *))handler {
  NSURL *url = [NSURL URLWithString:uri];
  [_videoCache getItemForUri:uri withCallback:^(RCTVideoCacheStatus videoCacheStatus, AVAsset * _Nullable cachedAsset) {
    switch (videoCacheStatus) {
      case RCTVideoCacheStatusMissingFileExtension: {
        DebugLog(@"Could not generate cache key for uri '%@'. It is currently not supported to cache urls that do not include a file extension. The video file will not be cached. Checkout https://github.com/react-native-community/react-native-video/blob/master/docs/caching.md", uri);
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:options];
        [self playerItemPrepareText:asset assetOptions:options withCallback:handler];
        return;
      }
      case RCTVideoCacheStatusUnsupportedFileExtension: {
        DebugLog(@"Could not generate cache key for uri '%@'. The file extension of that uri is currently not supported. The video file will not be cached. Checkout https://github.com/react-native-community/react-native-video/blob/master/docs/caching.md", uri);
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:options];
        [self playerItemPrepareText:asset assetOptions:options withCallback:handler];
        return;
      }
      default:
        if (cachedAsset) {
          DebugLog(@"Playing back uri '%@' from cache", uri);
          // See note in playerItemForSource about not being able to support text tracks & caching
          handler([AVPlayerItem playerItemWithAsset:cachedAsset]);
          return;
        }
    }
    
    DVURLAsset *asset = [[DVURLAsset alloc] initWithURL:url options:options networkTimeout:10000];
    asset.loaderDelegate = self;
    
    /* More granular code to have control over the DVURLAsset
     DVAssetLoaderDelegate *resourceLoaderDelegate = [[DVAssetLoaderDelegate alloc] initWithURL:url];
     resourceLoaderDelegate.delegate = self;
     NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:NO];
     components.scheme = [DVAssetLoaderDelegate scheme];
     AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[components URL] options:options];
     [asset.resourceLoader setDelegate:resourceLoaderDelegate queue:dispatch_get_main_queue()];
     */
    
    handler([AVPlayerItem playerItemWithAsset:asset]);
  }];
}

#pragma mark - DVAssetLoaderDelegate

- (void)dvAssetLoaderDelegate:(DVAssetLoaderDelegate *)loaderDelegate
                  didLoadData:(NSData *)data
                       forURL:(NSURL *)url {
  [_videoCache storeItem:data forUri:[url absoluteString] withCallback:^(BOOL success) {
    DebugLog(@"Cache data stored successfully 🎉");
  }];
}

#endif

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  // when controls==true, this is a hack to reset the rootview when rotation happens in fullscreen
  if (object == _playerViewController.contentOverlayView) {
    if ([keyPath isEqualToString:@"frame"]) {
      
      CGRect oldRect = [change[NSKeyValueChangeOldKey] CGRectValue];
      CGRect newRect = [change[NSKeyValueChangeNewKey] CGRectValue];
      
      if (!CGRectEqualToRect(oldRect, newRect)) {
        if (CGRectEqualToRect(newRect, [UIScreen mainScreen].bounds)) {
          NSLog(@"in fullscreen");
        } else NSLog(@"not fullscreen");
        
        [self.reactViewController.view setFrame:[UIScreen mainScreen].bounds];
        [self.reactViewController.view setNeedsLayout];
      }
      
      return;
    } else
      return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
  
  if (object == _playerItem) {
    // When timeMetadata is read the event onTimedMetadata is triggered
    if ([keyPath isEqualToString:timedMetadata]) {
      NSArray<AVMetadataItem *> *items = [change objectForKey:@"new"];
      if (items && ![items isEqual:[NSNull null]] && items.count > 0) {
        NSMutableArray *array = [NSMutableArray new];
        for (AVMetadataItem *item in items) {
          NSString *value = (NSString *)item.value;
          NSString *identifier = item.identifier;
          
          if (![value isEqual: [NSNull null]]) {
            NSDictionary *dictionary = [[NSDictionary alloc] initWithObjects:@[value, identifier] forKeys:@[@"value", @"identifier"]];
            
            [array addObject:dictionary];
          }
        }
        
        self.onTimedMetadata(@{
                               @"target": self.reactTag,
                               @"metadata": array
                               });
      }
    }
    
    if ([keyPath isEqualToString:statusKeyPath]) {
      // Handle player item status change.
      if (_playerItem.status == AVPlayerItemStatusReadyToPlay) {
        float duration = CMTimeGetSeconds(_playerItem.asset.duration);
        
        if (isnan(duration)) {
          duration = 0.0;
        }
        
        NSObject *width = @"undefined";
        NSObject *height = @"undefined";
        NSString *orientation = @"undefined";
        
        if ([_playerItem.asset tracksWithMediaType:AVMediaTypeVideo].count > 0) {
          AVAssetTrack *videoTrack = [[_playerItem.asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
          width = [NSNumber numberWithFloat:videoTrack.naturalSize.width];
          height = [NSNumber numberWithFloat:videoTrack.naturalSize.height];
          CGAffineTransform preferredTransform = [videoTrack preferredTransform];
          
          if ((videoTrack.naturalSize.width == preferredTransform.tx
               && videoTrack.naturalSize.height == preferredTransform.ty)
              || (preferredTransform.tx == 0 && preferredTransform.ty == 0))
          {
            orientation = @"landscape";
          } else {
            orientation = @"portrait";
          }
        }
        
        if (self.onVideoLoad && _videoLoadStarted) {
          self.onVideoLoad(@{@"duration": [NSNumber numberWithFloat:duration],
                             @"currentTime": [NSNumber numberWithFloat:CMTimeGetSeconds(_playerItem.currentTime)],
                             @"canPlayReverse": [NSNumber numberWithBool:_playerItem.canPlayReverse],
                             @"canPlayFastForward": [NSNumber numberWithBool:_playerItem.canPlayFastForward],
                             @"canPlaySlowForward": [NSNumber numberWithBool:_playerItem.canPlaySlowForward],
                             @"canPlaySlowReverse": [NSNumber numberWithBool:_playerItem.canPlaySlowReverse],
                             @"canStepBackward": [NSNumber numberWithBool:_playerItem.canStepBackward],
                             @"canStepForward": [NSNumber numberWithBool:_playerItem.canStepForward],
                             @"naturalSize": @{
                                 @"width": width,
                                 @"height": height,
                                 @"orientation": orientation
                                 },
                             @"audioTracks": [self getAudioTrackInfo],
                             @"textTracks": [self getTextTrackInfo],
                             @"target": self.reactTag});
          
          // Start drawing 👑Godwin's Player Controls over here. 👇🏻
          [self drawGodwinzVideoControls];
        
        }
        _videoLoadStarted = NO;
        
        [self attachListeners];
        [self applyModifiers];
      } else if (_playerItem.status == AVPlayerItemStatusFailed && self.onVideoError) {
        self.onVideoError(@{@"error": @{@"code": [NSNumber numberWithInteger: _playerItem.error.code],
                                        @"domain": _playerItem.error.domain},
                            @"target": self.reactTag});
      }
    } else if ([keyPath isEqualToString:playbackBufferEmptyKeyPath]) {
      _playerBufferEmpty = YES;
      self.onVideoBuffer(@{@"isBuffering": @(YES), @"target": self.reactTag});
    } else if ([keyPath isEqualToString:playbackLikelyToKeepUpKeyPath]) {
      // Continue playing (or not if paused) after being paused due to hitting an unbuffered zone.
      if ((!(_controls || _fullscreenPlayerPresented) || _playerBufferEmpty) && _playerItem.playbackLikelyToKeepUp) {
        [self setPaused:_paused];
      }
      _playerBufferEmpty = NO;
      self.onVideoBuffer(@{@"isBuffering": @(NO), @"target": self.reactTag});
    }
  } else if (object == _playerLayer) {
    if([keyPath isEqualToString:readyForDisplayKeyPath] && [change objectForKey:NSKeyValueChangeNewKey]) {
      if([change objectForKey:NSKeyValueChangeNewKey] && self.onReadyForDisplay) {
        self.onReadyForDisplay(@{@"target": self.reactTag});
      }
    }
  } else if (object == _player) {
    if([keyPath isEqualToString:playbackRate]) {
      if(self.onPlaybackRateChange) {
        self.onPlaybackRateChange(@{@"playbackRate": [NSNumber numberWithFloat:_player.rate],
                                    @"target": self.reactTag});
      }
      if(_playbackStalled && _player.rate > 0) {
        if(self.onPlaybackResume) {
          self.onPlaybackResume(@{@"playbackRate": [NSNumber numberWithFloat:_player.rate],
                                  @"target": self.reactTag});
        }
        _playbackStalled = NO;
      }
    }
    else if([keyPath isEqualToString:externalPlaybackActive]) {
      if(self.onVideoExternalPlaybackChange) {
        self.onVideoExternalPlaybackChange(@{@"isExternalPlaybackActive": [NSNumber numberWithBool:_player.isExternalPlaybackActive],
                                             @"target": self.reactTag});
      }
    }
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
}

- (void)attachListeners
{
  // listen for end of file
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:AVPlayerItemDidPlayToEndTimeNotification
                                                object:[_player currentItem]];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(playerItemDidReachEnd:)
                                               name:AVPlayerItemDidPlayToEndTimeNotification
                                             object:[_player currentItem]];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:AVPlayerItemPlaybackStalledNotification
                                                object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(playbackStalled:)
                                               name:AVPlayerItemPlaybackStalledNotification
                                             object:nil];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:AVPlayerItemNewAccessLogEntryNotification
                                                object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleAVPlayerAccess:)
                                               name:AVPlayerItemNewAccessLogEntryNotification
                                             object:nil];
  
}

- (void)handleAVPlayerAccess:(NSNotification *)notification {
  AVPlayerItemAccessLog *accessLog = [((AVPlayerItem *)notification.object) accessLog];
  AVPlayerItemAccessLogEvent *lastEvent = accessLog.events.lastObject;
  
  /* TODO: get this working
   if (self.onBandwidthUpdate) {
   self.onBandwidthUpdate(@{@"bitrate": [NSNumber numberWithFloat:lastEvent.observedBitrate]});
   }
   */
}

- (void)playbackStalled:(NSNotification *)notification
{
  if(self.onPlaybackStalled) {
    self.onPlaybackStalled(@{@"target": self.reactTag});
  }
  _playbackStalled = YES;
}

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
  if(self.onVideoEnd) {
    self.onVideoEnd(@{@"target": self.reactTag});
  }
  
  if (_repeat) {
    AVPlayerItem *item = [notification object];
    [item seekToTime:kCMTimeZero];
    [self applyModifiers];
  } else {
    [self removePlayerTimeObserver];
  }
}

#pragma mark - Prop setters

- (void)setResizeMode:(NSString*)mode
{
  if( _controls )
  {
    _playerViewController.videoGravity = mode;
  }
  else
  {
    _playerLayer.videoGravity = mode;
  }
  _resizeMode = mode;
}

- (void)setPlayInBackground:(BOOL)playInBackground
{
  _playInBackground = playInBackground;
}

- (void)setAllowsExternalPlayback:(BOOL)allowsExternalPlayback
{
  _allowsExternalPlayback = allowsExternalPlayback;
  _player.allowsExternalPlayback = _allowsExternalPlayback;
}

- (void)setPlayWhenInactive:(BOOL)playWhenInactive
{
  _playWhenInactive = playWhenInactive;
}

- (void)setPictureInPicture:(BOOL)pictureInPicture
{
#if TARGET_OS_IOS
  if (_pictureInPicture == pictureInPicture) {
    return;
  }
  
  _pictureInPicture = pictureInPicture;
  if (_pipController && _pictureInPicture && ![_pipController isPictureInPictureActive]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [_pipController startPictureInPicture];
    });
  } else if (_pipController && !_pictureInPicture && [_pipController isPictureInPictureActive]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [_pipController stopPictureInPicture];
    });
  }
#endif
}

#if TARGET_OS_IOS
- (void)setRestoreUserInterfaceForPIPStopCompletionHandler:(BOOL)restore
{
  if (_restoreUserInterfaceForPIPStopCompletionHandler != NULL) {
    _restoreUserInterfaceForPIPStopCompletionHandler(restore);
    _restoreUserInterfaceForPIPStopCompletionHandler = NULL;
  }
}

- (void)setupPipController {
  if (!_pipController && _playerLayer && [AVPictureInPictureController isPictureInPictureSupported]) {
    // Create new controller passing reference to the AVPlayerLayer
    _pipController = [[AVPictureInPictureController alloc] initWithPlayerLayer:_playerLayer];
    _pipController.delegate = self;
  }
}
#endif

- (void)setIgnoreSilentSwitch:(NSString *)ignoreSilentSwitch
{
  _ignoreSilentSwitch = ignoreSilentSwitch;
  [self applyModifiers];
}

- (void)setPaused:(BOOL)paused
{
  if (paused) {
    [_player pause];
    [_player setRate:0.0];
  } else {
    if([_ignoreSilentSwitch isEqualToString:@"ignore"]) {
      [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    } else if([_ignoreSilentSwitch isEqualToString:@"obey"]) {
      [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];
    }
    [_player play];
    [_player setRate:_rate];
  }
  
  _paused = paused;
}

- (float)getCurrentTime
{
  return _playerItem != NULL ? CMTimeGetSeconds(_playerItem.currentTime) : 0;
}

- (void)setCurrentTime:(float)currentTime
{
  NSDictionary *info = @{
                         @"time": [NSNumber numberWithFloat:currentTime],
                         @"tolerance": [NSNumber numberWithInt:100]
                         };
  [self setSeek:info];
}

- (void)setSeek:(NSDictionary *)info
{
  NSNumber *seekTime = info[@"time"];
  NSNumber *seekTolerance = info[@"tolerance"];
  
  int timeScale = 1000;
  
  AVPlayerItem *item = _player.currentItem;
  if (item && item.status == AVPlayerItemStatusReadyToPlay) {
    // TODO check loadedTimeRanges
    
    CMTime cmSeekTime = CMTimeMakeWithSeconds([seekTime floatValue], timeScale);
    CMTime current = item.currentTime;
    // TODO figure out a good tolerance level
    CMTime tolerance = CMTimeMake([seekTolerance floatValue], timeScale);
    BOOL wasPaused = _paused;
    
    if (CMTimeCompare(current, cmSeekTime) != 0) {
      if (!wasPaused) [_player pause];
      [_player seekToTime:cmSeekTime toleranceBefore:tolerance toleranceAfter:tolerance completionHandler:^(BOOL finished) {
        if (!_timeObserver) {
          [self addPlayerTimeObserver];
        }
        if (!wasPaused) {
          [self setPaused:false];
        }
        if(self.onVideoSeek) {
          self.onVideoSeek(@{@"currentTime": [NSNumber numberWithFloat:CMTimeGetSeconds(item.currentTime)],
                             @"seekTime": seekTime,
                             @"target": self.reactTag});
        }
      }];
      
      _pendingSeek = false;
    }
    
  } else {
    // TODO: See if this makes sense and if so, actually implement it
    _pendingSeek = true;
    _pendingSeekTime = [seekTime floatValue];
  }
}

- (void)setRate:(float)rate
{
  _rate = rate;
  [self applyModifiers];
}

- (void)setMuted:(BOOL)muted
{
  _muted = muted;
  [self applyModifiers];
}

- (void)setVolume:(float)volume
{
  _volume = volume;
  [self applyModifiers];
}

- (void)setMaxBitRate:(float) maxBitRate {
  _maxBitRate = maxBitRate;
  _playerItem.preferredPeakBitRate = maxBitRate;
}


- (void)applyModifiers
{
  if (_muted) {
    [_player setVolume:0];
    [_player setMuted:YES];
  } else {
    [_player setVolume:_volume];
    [_player setMuted:NO];
  }
  
  [self setMaxBitRate:_maxBitRate];
  [self setSelectedAudioTrack:_selectedAudioTrack];
  [self setSelectedTextTrack:_selectedTextTrack];
  [self setResizeMode:_resizeMode];
  [self setRepeat:_repeat];
  [self setPaused:_paused];
  [self setControls:_controls];
  [self setAllowsExternalPlayback:_allowsExternalPlayback];
}

- (void)setRepeat:(BOOL)repeat {
  _repeat = repeat;
}

- (void)setMediaSelectionTrackForCharacteristic:(AVMediaCharacteristic)characteristic
                                   withCriteria:(NSDictionary *)criteria
{
  NSString *type = criteria[@"type"];
  AVMediaSelectionGroup *group = [_player.currentItem.asset
                                  mediaSelectionGroupForMediaCharacteristic:characteristic];
  AVMediaSelectionOption *mediaOption;
  
  if ([type isEqualToString:@"disabled"]) {
    // Do nothing. We want to ensure option is nil
  } else if ([type isEqualToString:@"language"] || [type isEqualToString:@"title"]) {
    NSString *value = criteria[@"value"];
    for (int i = 0; i < group.options.count; ++i) {
      AVMediaSelectionOption *currentOption = [group.options objectAtIndex:i];
      NSString *optionValue;
      if ([type isEqualToString:@"language"]) {
        optionValue = [currentOption extendedLanguageTag];
      } else {
        optionValue = [[[currentOption commonMetadata]
                        valueForKey:@"value"]
                       objectAtIndex:0];
      }
      if ([value isEqualToString:optionValue]) {
        mediaOption = currentOption;
        break;
      }
    }
    //} else if ([type isEqualToString:@"default"]) {
    //  option = group.defaultOption; */
  } else if ([type isEqualToString:@"index"]) {
    if ([criteria[@"value"] isKindOfClass:[NSNumber class]]) {
      int index = [criteria[@"value"] intValue];
      if (group.options.count > index) {
        mediaOption = [group.options objectAtIndex:index];
      }
    }
  } else { // default. invalid type or "system"
    [_player.currentItem selectMediaOptionAutomaticallyInMediaSelectionGroup:group];
    return;
  }
  
  // If a match isn't found, option will be nil and text tracks will be disabled
  [_player.currentItem selectMediaOption:mediaOption inMediaSelectionGroup:group];
}

- (void)setSelectedAudioTrack:(NSDictionary *)selectedAudioTrack {
  _selectedAudioTrack = selectedAudioTrack;
  [self setMediaSelectionTrackForCharacteristic:AVMediaCharacteristicAudible
                                   withCriteria:_selectedAudioTrack];
}

- (void)setSelectedTextTrack:(NSDictionary *)selectedTextTrack {
  _selectedTextTrack = selectedTextTrack;
  if (_textTracks) { // sideloaded text tracks
    [self setSideloadedText];
  } else { // text tracks included in the HLS playlist
    [self setMediaSelectionTrackForCharacteristic:AVMediaCharacteristicLegible
                                     withCriteria:_selectedTextTrack];
  }
}

- (void) setSideloadedText {
  NSString *type = _selectedTextTrack[@"type"];
  NSArray *textTracks = [self getTextTrackInfo];
  
  // The first few tracks will be audio & video track
  int firstTextIndex = 0;
  for (firstTextIndex = 0; firstTextIndex < _player.currentItem.tracks.count; ++firstTextIndex) {
    if ([_player.currentItem.tracks[firstTextIndex].assetTrack hasMediaCharacteristic:AVMediaCharacteristicLegible]) {
      break;
    }
  }
  
  int selectedTrackIndex = RCTVideoUnset;
  
  if ([type isEqualToString:@"disabled"]) {
    // Do nothing. We want to ensure option is nil
  } else if ([type isEqualToString:@"language"]) {
    NSString *selectedValue = _selectedTextTrack[@"value"];
    for (int i = 0; i < textTracks.count; ++i) {
      NSDictionary *currentTextTrack = [textTracks objectAtIndex:i];
      if ([selectedValue isEqualToString:currentTextTrack[@"language"]]) {
        selectedTrackIndex = i;
        break;
      }
    }
  } else if ([type isEqualToString:@"title"]) {
    NSString *selectedValue = _selectedTextTrack[@"value"];
    for (int i = 0; i < textTracks.count; ++i) {
      NSDictionary *currentTextTrack = [textTracks objectAtIndex:i];
      if ([selectedValue isEqualToString:currentTextTrack[@"title"]]) {
        selectedTrackIndex = i;
        break;
      }
    }
  } else if ([type isEqualToString:@"index"]) {
    if ([_selectedTextTrack[@"value"] isKindOfClass:[NSNumber class]]) {
      int index = [_selectedTextTrack[@"value"] intValue];
      if (textTracks.count > index) {
        selectedTrackIndex = index;
      }
    }
  }
  
  // in the situation that a selected text track is not available (eg. specifies a textTrack not available)
  if (![type isEqualToString:@"disabled"] && selectedTrackIndex == RCTVideoUnset) {
    CFArrayRef captioningMediaCharacteristics = MACaptionAppearanceCopyPreferredCaptioningMediaCharacteristics(kMACaptionAppearanceDomainUser);
    NSArray *captionSettings = (__bridge NSArray*)captioningMediaCharacteristics;
    if ([captionSettings containsObject:AVMediaCharacteristicTranscribesSpokenDialogForAccessibility]) {
      selectedTrackIndex = 0; // If we can't find a match, use the first available track
      NSString *systemLanguage = [[NSLocale preferredLanguages] firstObject];
      for (int i = 0; i < textTracks.count; ++i) {
        NSDictionary *currentTextTrack = [textTracks objectAtIndex:i];
        if ([systemLanguage isEqualToString:currentTextTrack[@"language"]]) {
          selectedTrackIndex = i;
          break;
        }
      }
    }
  }
  
  for (int i = firstTextIndex; i < _player.currentItem.tracks.count; ++i) {
    BOOL isEnabled = NO;
    if (selectedTrackIndex != RCTVideoUnset) {
      isEnabled = i == selectedTrackIndex + firstTextIndex;
    }
    [_player.currentItem.tracks[i] setEnabled:isEnabled];
  }
}

-(void) setStreamingText {
  NSString *type = _selectedTextTrack[@"type"];
  AVMediaSelectionGroup *group = [_player.currentItem.asset
                                  mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicLegible];
  AVMediaSelectionOption *mediaOption;
  
  if ([type isEqualToString:@"disabled"]) {
    // Do nothing. We want to ensure option is nil
  } else if ([type isEqualToString:@"language"] || [type isEqualToString:@"title"]) {
    NSString *value = _selectedTextTrack[@"value"];
    for (int i = 0; i < group.options.count; ++i) {
      AVMediaSelectionOption *currentOption = [group.options objectAtIndex:i];
      NSString *optionValue;
      if ([type isEqualToString:@"language"]) {
        optionValue = [currentOption extendedLanguageTag];
      } else {
        optionValue = [[[currentOption commonMetadata]
                        valueForKey:@"value"]
                       objectAtIndex:0];
      }
      if ([value isEqualToString:optionValue]) {
        mediaOption = currentOption;
        break;
      }
    }
    //} else if ([type isEqualToString:@"default"]) {
    //  option = group.defaultOption; */
  } else if ([type isEqualToString:@"index"]) {
    if ([_selectedTextTrack[@"value"] isKindOfClass:[NSNumber class]]) {
      int index = [_selectedTextTrack[@"value"] intValue];
      if (group.options.count > index) {
        mediaOption = [group.options objectAtIndex:index];
      }
    }
  } else { // default. invalid type or "system"
    [_player.currentItem selectMediaOptionAutomaticallyInMediaSelectionGroup:group];
    return;
  }
  
  // If a match isn't found, option will be nil and text tracks will be disabled
  [_player.currentItem selectMediaOption:mediaOption inMediaSelectionGroup:group];
}

- (void)setTextTracks:(NSArray*) textTracks;
{
  _textTracks = textTracks;
  
  // in case textTracks was set after selectedTextTrack
  if (_selectedTextTrack) [self setSelectedTextTrack:_selectedTextTrack];
}

- (NSArray *)getAudioTrackInfo
{
  NSMutableArray *audioTracks = [[NSMutableArray alloc] init];
  AVMediaSelectionGroup *group = [_player.currentItem.asset
                                  mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicAudible];
  for (int i = 0; i < group.options.count; ++i) {
    AVMediaSelectionOption *currentOption = [group.options objectAtIndex:i];
    NSString *title = @"";
    NSArray *values = [[currentOption commonMetadata] valueForKey:@"value"];
    if (values.count > 0) {
      title = [values objectAtIndex:0];
    }
    NSString *language = [currentOption extendedLanguageTag] ? [currentOption extendedLanguageTag] : @"";
    NSDictionary *audioTrack = @{
                                 @"index": [NSNumber numberWithInt:i],
                                 @"title": title,
                                 @"language": language
                                 };
    [audioTracks addObject:audioTrack];
  }
  return audioTracks;
}

- (NSArray *)getTextTrackInfo
{
  // if sideloaded, textTracks will already be set
  if (_textTracks) return _textTracks;
  
  // if streaming video, we extract the text tracks
  NSMutableArray *textTracks = [[NSMutableArray alloc] init];
  AVMediaSelectionGroup *group = [_player.currentItem.asset
                                  mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicLegible];
  for (int i = 0; i < group.options.count; ++i) {
    AVMediaSelectionOption *currentOption = [group.options objectAtIndex:i];
    NSString *title = @"";
    NSArray *values = [[currentOption commonMetadata] valueForKey:@"value"];
    if (values.count > 0) {
      title = [values objectAtIndex:0];
    }
    NSString *language = [currentOption extendedLanguageTag] ? [currentOption extendedLanguageTag] : @"";
    NSDictionary *textTrack = @{
                                @"index": [NSNumber numberWithInt:i],
                                @"title": title,
                                @"language": language
                                };
    [textTracks addObject:textTrack];
  }
  return textTracks;
}

- (BOOL)getFullscreen
{
  return _fullscreenPlayerPresented;
}

- (void)setFullscreen:(BOOL) fullscreen {
  if( fullscreen && !_fullscreenPlayerPresented && _player )
  {
    // Ensure player view controller is not null
    if( !_playerViewController )
    {
      [self usePlayerViewController];
    }
    // Set presentation style to fullscreen
    [_playerViewController setModalPresentationStyle:UIModalPresentationFullScreen];
    
    // Find the nearest view controller
    UIViewController *viewController = [self firstAvailableUIViewController];
    if( !viewController )
    {
      UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
      viewController = keyWindow.rootViewController;
      if( viewController.childViewControllers.count > 0 )
      {
        viewController = viewController.childViewControllers.lastObject;
      }
    }
    if( viewController )
    {
      _presentingViewController = viewController;
      if(self.onVideoFullscreenPlayerWillPresent) {
        self.onVideoFullscreenPlayerWillPresent(@{@"target": self.reactTag});
      }
      [viewController presentViewController:_playerViewController animated:true completion:^{
        _playerViewController.showsPlaybackControls = YES;
        _fullscreenPlayerPresented = fullscreen;
        _playerViewController.autorotate = _fullscreenAutorotate;
        if(self.onVideoFullscreenPlayerDidPresent) {
          self.onVideoFullscreenPlayerDidPresent(@{@"target": self.reactTag});
        }
      }];
    }
  }
  else if ( !fullscreen && _fullscreenPlayerPresented )
  {
    [self videoPlayerViewControllerWillDismiss:_playerViewController];
    [_presentingViewController dismissViewControllerAnimated:true completion:^{
      [self videoPlayerViewControllerDidDismiss:_playerViewController];
    }];
  }
}

- (void)setFullscreenAutorotate:(BOOL)autorotate {
  _fullscreenAutorotate = autorotate;
  if (_fullscreenPlayerPresented) {
    _playerViewController.autorotate = autorotate;
  }
}

- (void)setFullscreenOrientation:(NSString *)orientation {
  _fullscreenOrientation = orientation;
  if (_fullscreenPlayerPresented) {
    _playerViewController.preferredOrientation = orientation;
  }
}

- (void)usePlayerViewController
{
  if( _player )
  {
    _playerViewController = [self createPlayerViewController:_player withPlayerItem:_playerItem];
    // to prevent video from being animated when resizeMode is 'cover'
    // resize mode must be set before subview is added
    [self setResizeMode:_resizeMode];
    
    if (_controls) {
      UIViewController *viewController = [self reactViewController];
      [viewController addChildViewController:_playerViewController];
      [self addSubview:_playerViewController.view];
    }
    
    [_playerViewController.contentOverlayView addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];
  }
}

- (void)usePlayerLayer
{
  if( _player )
  {
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    [_playerLayer setFrame:CGRectMake(0, 0, self.frame.size.width, (self.frame.size.width * 9) / 16 )];
    _playerLayer.needsDisplayOnBoundsChange = YES;
    
    // to prevent video from being animated when resizeMode is 'cover'
    // resize mode must be set before layer is added
    [self setResizeMode:_resizeMode];
    [_playerLayer addObserver:self forKeyPath:readyForDisplayKeyPath options:NSKeyValueObservingOptionNew context:nil];
    _playerLayerObserverSet = YES;
    
    [self.layer addSublayer:_playerLayer];
    self.layer.needsDisplayOnBoundsChange = YES;
#if TARGET_OS_IOS
    [self setupPipController];
#endif
  }
}

- (void)setControls:(BOOL)controls
{
  if( _controls != controls || (!_playerLayer && !_playerViewController) )
  {
    _controls = controls;
    if( _controls )
    {
      [self removePlayerLayer];
      [self usePlayerViewController];
      
    }
    else
    {
      [_playerViewController.view removeFromSuperview];
      _playerViewController = nil;
      [self usePlayerLayer];
    }
  }
}

- (void)setProgressUpdateInterval:(float)progressUpdateInterval
{
  _progressUpdateInterval = progressUpdateInterval;
  
  if (_timeObserver) {
    [self removePlayerTimeObserver];
    [self addPlayerTimeObserver];
  }
}

- (void)removePlayerLayer
{
  [_playerLayer removeFromSuperlayer];
  if (_playerLayerObserverSet) {
    [_playerLayer removeObserver:self forKeyPath:readyForDisplayKeyPath];
    _playerLayerObserverSet = NO;
  }
  _playerLayer = nil;
}

#pragma mark - RCTVideoPlayerViewControllerDelegate

- (void)videoPlayerViewControllerWillDismiss:(AVPlayerViewController *)playerViewController
{
  if (_playerViewController == playerViewController && _fullscreenPlayerPresented && self.onVideoFullscreenPlayerWillDismiss)
  {
    self.onVideoFullscreenPlayerWillDismiss(@{@"target": self.reactTag});
  }
}

- (void)videoPlayerViewControllerDidDismiss:(AVPlayerViewController *)playerViewController
{
  if (_playerViewController == playerViewController && _fullscreenPlayerPresented)
  {
    _fullscreenPlayerPresented = false;
    _presentingViewController = nil;
    _playerViewController = nil;
    [self applyModifiers];
    if(self.onVideoFullscreenPlayerDidDismiss) {
      self.onVideoFullscreenPlayerDidDismiss(@{@"target": self.reactTag});
    }
  }
}

- (void)setFilter:(NSString *)filterName {
  _filterName = filterName;
  
  if (!_filterEnabled) {
    return;
  } else if ([[_source objectForKey:@"uri"] rangeOfString:@"m3u8"].location != NSNotFound) {
    return; // filters don't work for HLS... return
  } else if (!_playerItem.asset) {
    return;
  }
  
  CIFilter *filter = [CIFilter filterWithName:filterName];
  _playerItem.videoComposition = [AVVideoComposition
                                  videoCompositionWithAsset:_playerItem.asset
                                  applyingCIFiltersWithHandler:^(AVAsynchronousCIImageFilteringRequest *_Nonnull request) {
                                    if (filter == nil) {
                                      [request finishWithImage:request.sourceImage context:nil];
                                    } else {
                                      CIImage *image = request.sourceImage.imageByClampingToExtent;
                                      [filter setValue:image forKey:kCIInputImageKey];
                                      CIImage *output = [filter.outputImage imageByCroppingToRect:request.sourceImage.extent];
                                      [request finishWithImage:output context:nil];
                                    }
                                  }];
}

- (void)setFilterEnabled:(BOOL)filterEnabled {
  _filterEnabled = filterEnabled;
}

#pragma mark - React View Management

- (void)insertReactSubview:(UIView *)view atIndex:(NSInteger)atIndex
{
  // We are early in the game and somebody wants to set a subview.
  // That can only be in the context of playerViewController.
  if( !_controls && !_playerLayer && !_playerViewController )
  {
//    [self setControls:true];
      ReactSubView = view;
  }
  
  if( _controls )
  {
    view.frame = self.bounds;
    [_playerViewController.contentOverlayView insertSubview:view atIndex:atIndex];
  }
  return;
}

- (void)removeReactSubview:(UIView *)subview
{
  if( _controls )
  {
    [subview removeFromSuperview];
  }
  else
  {
    RCTLogError(@"video cannot have any subviews");
  }
  return;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  if( _controls )
  {
    _playerViewController.view.frame = self.bounds;

    // also adjust all subviews of contentOverlayView
    for (UIView* subview in _playerViewController.contentOverlayView.subviews) {
      subview.frame = self.bounds;
    }
  }
  else
  {
    [CATransaction begin];
    [CATransaction setAnimationDuration:0];
    [CATransaction commit];
  }
}

#pragma mark - Lifecycle

- (void)removeFromSuperview
{
  [_player pause];
  if (_playbackRateObserverRegistered) {
    [_player removeObserver:self forKeyPath:playbackRate context:nil];
    _playbackRateObserverRegistered = NO;
  }
  if (_isExternalPlaybackActiveObserverRegistered) {
    [_player removeObserver:self forKeyPath:externalPlaybackActive context:nil];
    _isExternalPlaybackActiveObserverRegistered = NO;
  }
  _player = nil;
  
  [self removePlayerLayer];
  
  [_playerViewController.contentOverlayView removeObserver:self forKeyPath:@"frame"];
  [_playerViewController.view removeFromSuperview];
  _playerViewController = nil;
  
  [self removePlayerTimeObserver];
  [self removePlayerItemObservers];
  
  _eventDispatcher = nil;
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  [super removeFromSuperview];
}

#pragma mark - Export

- (void)save:(NSDictionary *)options resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject {
  
  AVAsset *asset = _playerItem.asset;
  
  if (asset != nil) {
    
    AVAssetExportSession *exportSession = [AVAssetExportSession
                                           exportSessionWithAsset:asset presetName:AVAssetExportPresetHighestQuality];
    
    if (exportSession != nil) {
      NSString *path = nil;
      NSArray *array = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
      path = [self generatePathInDirectory:[[self cacheDirectoryPath] stringByAppendingPathComponent:@"Videos"]
                             withExtension:@".mp4"];
      NSURL *url = [NSURL fileURLWithPath:path];
      exportSession.outputFileType = AVFileTypeMPEG4;
      exportSession.outputURL = url;
      exportSession.videoComposition = _playerItem.videoComposition;
      exportSession.shouldOptimizeForNetworkUse = true;
      [exportSession exportAsynchronouslyWithCompletionHandler:^{
        
        switch ([exportSession status]) {
          case AVAssetExportSessionStatusFailed:
            reject(@"ERROR_COULD_NOT_EXPORT_VIDEO", @"Could not export video", exportSession.error);
            break;
          case AVAssetExportSessionStatusCancelled:
            reject(@"ERROR_EXPORT_SESSION_CANCELLED", @"Export session was cancelled", exportSession.error);
            break;
          default:
            resolve(@{@"uri": url.absoluteString});
            break;
        }
        
      }];
      
    } else {
      
      reject(@"ERROR_COULD_NOT_CREATE_EXPORT_SESSION", @"Could not create export session", nil);
      
    }
    
  } else {
    
    reject(@"ERROR_ASSET_NIL", @"Asset is nil", nil);
    
  }
}

- (BOOL)ensureDirExistsWithPath:(NSString *)path {
  BOOL isDir = NO;
  NSError *error;
  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir];
  if (!(exists && isDir)) {
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) {
      return NO;
    }
  }
  return YES;
}

- (NSString *)generatePathInDirectory:(NSString *)directory withExtension:(NSString *)extension {
  NSString *fileName = [[[NSUUID UUID] UUIDString] stringByAppendingString:extension];
  [self ensureDirExistsWithPath:directory];
  return [directory stringByAppendingPathComponent:fileName];
}

- (NSString *)cacheDirectoryPath {
  NSArray *array = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
  return array[0];
}

/*👑Godwin's Prop set methods*/

- (void)setPlayBtnImg:(NSDictionary *)playBtnImg
{
  _playBtnImg = playBtnImg;
  [self applyModifiers];
}

- (void)setPauseBtnImg:(NSDictionary *)pauseBtnImg
{
  _pauseBtnImg = pauseBtnImg;
  [self applyModifiers];
}

- (void)setRewindAndForwardInterval:(float)rewindAndForwardInterval
{
  _rewindAndForwardInterval = rewindAndForwardInterval;
  [self applyModifiers];
}

- (void)setRewindBtnImg:(NSDictionary *)rewindBtnImg
{
  _rewindBtnImg = rewindBtnImg;
  [self applyModifiers];
}

- (void)setForwardBtnImg:(NSDictionary *)forwardBtnImg
{
  _forwardBtnImg  = forwardBtnImg;
  [self applyModifiers];
}

- (void)setSeekbarCursorImg:(NSDictionary *)seekbarCursorImg
{
  _seekbarCursorImg  = seekbarCursorImg;
  [self applyModifiers];
}
- (void)setSeekbarCursorActiveImg:(NSDictionary *)seekbarCursorActiveImg
{
  _seekbarCursorActiveImg  = seekbarCursorActiveImg;
  [self applyModifiers];
}

- (void)setSeekbarMaxTint:(NSNumber *)seekbarMaxTint
{
  _seekbarMaxTint  = seekbarMaxTint;
  [self applyModifiers];
}

- (void)setSeekbarMinTint:(NSNumber *)seekbarMinTint
{
  _seekbarMinTint  = seekbarMinTint;
  [self applyModifiers];
}

- (void)setFullscreenImg:(NSDictionary *)fullscreenImg
{
  _fullscreenImg  = fullscreenImg;
  [self applyModifiers];
}

/*********/

/*👑Godwin's player helper methods*/

-(NSString *)convertToString:(NSDictionary *) dictionary{
  //* Converts Source dictionary to json String
  NSError * err;
  NSData *gSoruce = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&err];
  NSString *sourceStr = [[NSString alloc] initWithData:gSoruce encoding:NSUTF8StringEncoding];
  return sourceStr;
}

-(Float64 *)getCurrentTime:(Float64 *)currentTime{
  return currentTime;
}

- (NSString *)timeFormatted:(int)totalSeconds
{
  
  int seconds = totalSeconds % 60;
  int minutes = (totalSeconds / 60) % 60;
  int hours = totalSeconds / 3600;
  
  return [NSString stringWithFormat:@"%02d:%02d:%02d",hours, minutes, seconds];
}


/**********/

/*
 * 👑Godwin's Video Controls Begin....
 */
-(void)drawGodwinzVideoControls{
  NSLog(@"godwin:✍🏻 Drawing Godwin's Video Controls...");
  
  // Drawing Overlay
  controlsOverlay = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, (self.frame.size.width * 9) / 16 )];
  controlsOverlay.backgroundColor = [UIColor colorWithRed:0.0f/255.0f
                                                    green:0.0f/255.0f
                                                     blue:0.0f/255.0f
                                                    alpha:0.0f];
  toggleControlsOnTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleControlsOnTap:)];
  [controlsOverlay addGestureRecognizer:toggleControlsOnTap];
  
  // Drawing detailsContainer
  detailsContainer = [[UIView alloc] initWithFrame:CGRectMake(0, (self.frame.size.width * 9) / 16 , self.frame.size.width, self.frame.size.height - (self.frame.size.width * 9) / 16 )];
  
  // Drawing controls container
  controlsContainer = [[UIView alloc] initWithFrame:self.bounds];
  [controlsContainer setHidden:true];
  
  
  // Drawing Play/Pause Button
  PlayBtnImg = [RCTConvert UIImage:_playBtnImg];
  PauseBtnImg = [RCTConvert UIImage:_pauseBtnImg];
  PlayPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
  PlayPauseButton.backgroundColor = [UIColor clearColor];
  PlayPauseButton.frame = CGRectMake((controlsOverlay.frame.size.width / 2) - 25, (controlsOverlay.frame.size.height / 2) - 25, 50, 50);
  [PlayPauseButton setImage:PauseBtnImg forState:UIControlStateNormal];
  [PlayPauseButton addTarget:self action:@selector(playPauseTapEvent) forControlEvents:UIControlEventTouchUpInside];
  
  // Drawing Rewind Button
  RewindBtnImg =[RCTConvert UIImage:_rewindBtnImg];
  RewindButton = [UIButton buttonWithType:UIButtonTypeCustom];
  RewindButton.backgroundColor = [UIColor clearColor];
  RewindButton.frame = CGRectMake((controlsOverlay.frame.size.width / 8) - 25, (controlsOverlay.frame.size.height / 2) - 25 , 50, 50);
  [RewindButton setImage:RewindBtnImg forState:UIControlStateNormal];
  [RewindButton addTarget:self action:@selector(rewindVideo) forControlEvents:UIControlEventTouchUpInside];
  
  // Drawing Forward Button
  ForwardBtnImg =[RCTConvert UIImage:_forwardBtnImg];
  ForwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
  ForwardButton.backgroundColor = [UIColor clearColor];
  ForwardButton.frame = CGRectMake((controlsOverlay.frame.size.width / 1.3333333333333333) + 25, (controlsOverlay.frame.size.height / 2) - 25 , 50, 50);
  [ForwardButton setImage:ForwardBtnImg forState:UIControlStateNormal];
  [ForwardButton addTarget:self action:@selector(forwardVideo) forControlEvents:UIControlEventTouchUpInside];
  
  // Drawing Seekbar
  Seekbar = [[UISlider alloc] initWithFrame:CGRectMake(60, controlsOverlay.frame.size.height - 50, (controlsOverlay.frame.size.width - 120) - 50, 50)];
  SeekbarCursorImg = [RCTConvert UIImage:_seekbarCursorImg];
  SeekbarCursorActiveImg = [RCTConvert UIImage:_seekbarCursorActiveImg];
  [Seekbar setMaximumTrackTintColor:[RCTConvert UIColor:_seekbarMaxTint]];
  [Seekbar setMinimumTrackTintColor:[RCTConvert UIColor:_seekbarMinTint]];
  [Seekbar setThumbImage:SeekbarCursorImg forState:UIControlStateNormal];
  [Seekbar setThumbImage:SeekbarCursorActiveImg forState:UIControlStateHighlighted];
    /* Adding on drag event*/
  [Seekbar addTarget:self action:@selector(beginSeek) forControlEvents:UIControlEventTouchDragInside];
    /* Adding on drag end and the slider value has changed event*/
  [Seekbar addTarget:self action:@selector(endSeek:) forControlEvents:UIControlEventValueChanged];
  
  //Drawing current time UITextView
  CurrentTimeTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, controlsOverlay.frame.size.height - 40, 60, 50)];
  [CurrentTimeTextView setTextColor:[UIColor whiteColor]];
  [CurrentTimeTextView setBackgroundColor:[UIColor colorWithRed:0.0f/255.0f
                                                          green:0.0f/255.0f
                                                           blue:0.0f/255.0f
                                                          alpha:0.0f]];
  [CurrentTimeTextView setText:@"00:00:00"];
  [CurrentTimeTextView setTextAlignment:NSTextAlignmentCenter];
  
  //Drawing duration time UITextView
  DurationTextView = [[UITextView alloc] initWithFrame:CGRectMake(controlsOverlay.frame.size.width - (60 + 50), controlsOverlay.frame.size.height - 40, 60, 50)];
  [DurationTextView setTextColor:[UIColor whiteColor]];
  [DurationTextView setText:@"00:00:00"];
  [DurationTextView setTextAlignment:NSTextAlignmentCenter];
  [DurationTextView setBackgroundColor:[UIColor colorWithRed:0.0f/255.0f
                                                          green:0.0f/255.0f
                                                           blue:0.0f/255.0f
                                                       alpha:0.0f]];
  
  // Drawing fullscreen button
  FullscreenImg =[RCTConvert UIImage:_fullscreenImg];
  FullscreenButton = [UIButton buttonWithType:UIButtonTypeCustom];
  FullscreenButton.backgroundColor = [UIColor clearColor];
  FullscreenButton.frame = CGRectMake(controlsOverlay.frame.size.width - 50, controlsOverlay.frame.size.height - 50, 50, 50);
  [FullscreenButton setImage:FullscreenImg forState:UIControlStateNormal];
  [FullscreenButton addTarget:self action:@selector(videoTakeover) forControlEvents:UIControlEventTouchUpInside];
  
  // Appending all controls to `controls container` subview
  [self addSubview:controlsOverlay];
  [self addSubview:detailsContainer];
  [controlsOverlay addSubview:controlsContainer];
  [controlsContainer addSubview:PlayPauseButton];
  [controlsContainer addSubview:RewindButton];
  [controlsContainer addSubview:ForwardButton];
  [controlsContainer addSubview:Seekbar];
  [controlsContainer addSubview:CurrentTimeTextView];
  [controlsContainer addSubview:DurationTextView];
  [controlsContainer addSubview:FullscreenButton];
  
  // Apending all react children passed to 👑Godwin's KVCVideo Tag to the details container subview.
  [detailsContainer addSubview:ReactSubView];
}

-(void)toggleControlsOnTap:(UITapGestureRecognizer *)event {
  NSLog(@"godwin:💋 User kissed the player.");
  [self bringSubviewToFront:controlsOverlay];
  showingControls = !showingControls;
  if(showingControls){
    controlsOverlay.backgroundColor = [UIColor colorWithRed:0.0f/255.0f
                                                      green:0.0f/255.0f
                                                       blue:0.0f/255.0f
                                                      alpha:0.5f];
    [controlsContainer setHidden:false];
  }else{
    controlsOverlay.backgroundColor = [UIColor colorWithRed:0.0f/255.0f
                                                      green:0.0f/255.0f
                                                       blue:0.0f/255.0f
                                                      alpha:0.0f];
    [controlsContainer setHidden:true];
  }
}

-(void)playPauseTapEvent{
  _paused = !_paused;
  if(_paused){
    NSLog(@"godwin:⏸ Attempting to pause the video");
    [PlayPauseButton setImage:PlayBtnImg forState:UIControlStateNormal];
  }else{
    NSLog(@"godwin:▶️ Attempting to play the video");
    [PlayPauseButton setImage:PauseBtnImg forState:UIControlStateNormal];
  }
  [self setPaused: _paused];
}

-(void)rewindVideo{
  NSLog(@"godwin: current time: %f", [self getCurrentTime]);
  [self getCurrentTime] > _rewindAndForwardInterval ? [self setCurrentTime:[self getCurrentTime] - _rewindAndForwardInterval] : [self setCurrentTime:0];
}

-(void)forwardVideo{
  float totalDuration = CMTimeGetSeconds([self playerItemDuration]);
  totalDuration > [self getCurrentTime] + _rewindAndForwardInterval ? [self setCurrentTime:[self getCurrentTime] + _rewindAndForwardInterval] : [self setCurrentTime:totalDuration];
}

// Set the seekbar based on the player current time.
- (void)syncSeekbar
{
  CMTime playerDuration = [self playerItemDuration];
  if (CMTIME_IS_INVALID(playerDuration))
  {
    [Seekbar setMinimumValue:0.0];
    return;
  }
  
  double duration = CMTimeGetSeconds(playerDuration);
  if (isfinite(duration) && (duration > 0))
  {
    float minValue = [Seekbar minimumValue];
    float maxValue = [Seekbar maximumValue];
    double time = CMTimeGetSeconds([_player currentTime]);
    [Seekbar setValue:(maxValue - minValue) * time / duration + minValue];
  }
}

// The user is dragging 👑Godwin's seekbar controller thumb to scrub through the video.
-(void)beginSeek{
  NSLog(@"godwin:💨 Trying to scrub through the video");
  /* Remove the seeksyn observer */
  [self removePlayerTimeObserver];
}
// The user has finished dragging 👑Godwin's seekbar controller thumb, must update the video to the new seek time.
-(void)endSeek:(UISlider *)slider{
  NSLog(@"godwin:🔃 Seeking finished, must update the video current time");
  CMTime playerDuration = [self playerItemDuration];
  if (CMTIME_IS_INVALID(playerDuration))
  {
    return;
  }
  double duration = CMTimeGetSeconds(playerDuration);
  if (isfinite(duration))
  {
    CGFloat width = CGRectGetWidth([Seekbar bounds]);
    double tolerance = 0.5f * duration / width;
    double seekTime = duration * slider.value;
    [self setSeek:@{@"time":@(seekTime), @"tolerance": @(tolerance)}];
  }
}

-(void)videoTakeover{
  NSLog(@"godwin:🖥 Video going to full screen");
  UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
  if(orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight){
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInt:UIInterfaceOrientationPortrait] forKey:@"orientation"];
  }else{
    [[UIDevice currentDevice] setValue:[NSNumber numberWithInt:UIInterfaceOrientationLandscapeRight] forKey:@"orientation"];
  }
}

-(void)setFramesForLandscape{
  CGRect LandscapeFrame = CGRectMake(0, 0, self.frame.size.height, self.frame.size.width);
  [_playerLayer setFrame:LandscapeFrame];
  [controlsOverlay setFrame:LandscapeFrame];
  [controlsContainer setFrame:LandscapeFrame];
  [PlayPauseButton setFrame:CGRectMake((controlsOverlay.frame.size.width / 2) - 25, (controlsOverlay.frame.size.height / 2) - 25, 50, 50)];
  [RewindButton setFrame:CGRectMake((controlsOverlay.frame.size.width / 8) - 25, (controlsOverlay.frame.size.height / 2) - 25 , 50, 50)];
  [ForwardButton setFrame:CGRectMake((controlsOverlay.frame.size.width / 1.3333333333333333) + 25, (controlsOverlay.frame.size.height / 2) - 25 , 50, 50)];
  [Seekbar setFrame:CGRectMake(60, controlsOverlay.frame.size.height - 50, (controlsOverlay.frame.size.width - 120) - 50, 50)];
  [CurrentTimeTextView setFrame:CGRectMake(0, controlsOverlay.frame.size.height - 40, 60, 50)];
  [DurationTextView setFrame:CGRectMake(controlsOverlay.frame.size.width - (60 + 50), controlsOverlay.frame.size.height - 40, 60, 50)];
  [FullscreenButton setFrame:CGRectMake(controlsOverlay.frame.size.width - 50, controlsOverlay.frame.size.height - 50, 50, 50)];
}

-(void)setFramesForPotrait{
  CGRect PotraitFrame = CGRectMake(0, 0, self.frame.size.height, (self.frame.size.height * 9) / 16 );
  [_playerLayer setFrame:PotraitFrame];
  [controlsOverlay setFrame:PotraitFrame];
  [controlsContainer setFrame:PotraitFrame];
  [PlayPauseButton setFrame:CGRectMake((controlsOverlay.frame.size.width / 2) - 25, (controlsOverlay.frame.size.height / 2) - 25, 50, 50)];
  [RewindButton setFrame:CGRectMake((controlsOverlay.frame.size.width / 8) - 25, (controlsOverlay.frame.size.height / 2) - 25 , 50, 50)];
  [ForwardButton setFrame:CGRectMake((controlsOverlay.frame.size.width / 1.3333333333333333) + 25, (controlsOverlay.frame.size.height / 2) - 25 , 50, 50)];
  [Seekbar setFrame:CGRectMake(60, controlsOverlay.frame.size.height - 50, (controlsOverlay.frame.size.width - 120) - 50, 50)];
  [CurrentTimeTextView setFrame:CGRectMake(0, controlsOverlay.frame.size.height - 40, 60, 50)];
  [DurationTextView setFrame:CGRectMake(controlsOverlay.frame.size.width - (60 + 50), controlsOverlay.frame.size.height - 40, 60, 50)];
  [FullscreenButton setFrame:CGRectMake(controlsOverlay.frame.size.width - 50, controlsOverlay.frame.size.height - 50, 50, 50)];
}

- (void) orientationChanged:(NSNotification *)note
{
  UIDevice * device = note.object;
  currentOrientation == 0 ? currentOrientation = device.orientation : false;
  if (currentOrientation != device.orientation) {
    switch(device.orientation)
    {
        case UIDeviceOrientationPortrait:
          NSLog(@"godwin: 🎊 Screen changed to UIDeviceOrientationPortrait");
          [self setFramesForPotrait];
          currentOrientation = UIDeviceOrientationPortrait;
        break;
        
        case UIDeviceOrientationPortraitUpsideDown:
          NSLog(@"godwin: 🎊 Screen changed to UIDeviceOrientationPortraitUpsideDown");
          currentOrientation = UIDeviceOrientationPortraitUpsideDown;
        break;
        
        case UIDeviceOrientationLandscapeLeft:
          NSLog(@"godwin: 🎊 Screen changed to UIDeviceOrientationLandscapeLeft");
          [self setFramesForLandscape];
          currentOrientation = UIDeviceOrientationLandscapeLeft;
        break;
        
        case UIDeviceOrientationLandscapeRight:
          NSLog(@"godwin: 🎊 Screen changed to UIDeviceOrientationLandscapeRight");
          [self setFramesForLandscape];
          currentOrientation = UIDeviceOrientationLandscapeRight;
        break;
        
      default:
        break;
    };
  }
}

 /**************/

@end


@implementation KVCVideoManager

RCT_EXPORT_MODULE();

- (UIView *)view
{
  return [[KVCVideo alloc] initWithEventDispatcher:self.bridge.eventDispatcher];
}

- (dispatch_queue_t)methodQueue
{
  return self.bridge.uiManager.methodQueue;
}

RCT_EXPORT_VIEW_PROPERTY(src, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(maxBitRate, float);
RCT_EXPORT_VIEW_PROPERTY(resizeMode, NSString);
RCT_EXPORT_VIEW_PROPERTY(repeat, BOOL);
RCT_EXPORT_VIEW_PROPERTY(allowsExternalPlayback, BOOL);
RCT_EXPORT_VIEW_PROPERTY(textTracks, NSArray);
RCT_EXPORT_VIEW_PROPERTY(selectedTextTrack, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(selectedAudioTrack, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(paused, BOOL);
RCT_EXPORT_VIEW_PROPERTY(muted, BOOL);
RCT_EXPORT_VIEW_PROPERTY(controls, BOOL);
RCT_EXPORT_VIEW_PROPERTY(volume, float);
RCT_EXPORT_VIEW_PROPERTY(playInBackground, BOOL);
RCT_EXPORT_VIEW_PROPERTY(playWhenInactive, BOOL);
RCT_EXPORT_VIEW_PROPERTY(pictureInPicture, BOOL);
RCT_EXPORT_VIEW_PROPERTY(ignoreSilentSwitch, NSString);
RCT_EXPORT_VIEW_PROPERTY(rate, float);
RCT_EXPORT_VIEW_PROPERTY(seek, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(currentTime, float);
RCT_EXPORT_VIEW_PROPERTY(fullscreen, BOOL);
RCT_EXPORT_VIEW_PROPERTY(fullscreenAutorotate, BOOL);
RCT_EXPORT_VIEW_PROPERTY(fullscreenOrientation, NSString);
RCT_EXPORT_VIEW_PROPERTY(filter, NSString);
RCT_EXPORT_VIEW_PROPERTY(filterEnabled, BOOL);
RCT_EXPORT_VIEW_PROPERTY(progressUpdateInterval, float);
RCT_EXPORT_VIEW_PROPERTY(restoreUserInterfaceForPIPStopCompletionHandler, BOOL);
/* Should support: onLoadStart, onLoad, and onError to stay consistent with Image */
RCT_EXPORT_VIEW_PROPERTY(onVideoLoadStart, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoLoad, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoBuffer, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoError, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoProgress, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onBandwidthUpdate, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoSeek, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoEnd, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onTimedMetadata, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoAudioBecomingNoisy, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoFullscreenPlayerWillPresent, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoFullscreenPlayerDidPresent, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoFullscreenPlayerWillDismiss, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoFullscreenPlayerDidDismiss, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onReadyForDisplay, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onPlaybackStalled, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onPlaybackResume, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onPlaybackRateChange, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onVideoExternalPlaybackChange, RCTBubblingEventBlock);

/*Props Added by 👑Godwin*/

RCT_EXPORT_VIEW_PROPERTY(playBtnImg, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(pauseBtnImg, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(rewindBtnImg, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(forwardBtnImg, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(rewindAndForwardInterval, float);
RCT_EXPORT_VIEW_PROPERTY(seekbarCursorImg, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(seekbarCursorActiveImg, NSDictionary);
RCT_EXPORT_VIEW_PROPERTY(seekbarMaxTint, NSNumber);
RCT_EXPORT_VIEW_PROPERTY(seekbarMinTint, NSNumber);
RCT_EXPORT_VIEW_PROPERTY(fullscreenImg, NSDictionary);


/*********/
RCT_REMAP_METHOD(save,
                 options:(NSDictionary *)options
                 reactTag:(nonnull NSNumber *)reactTag
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  [self.bridge.uiManager prependUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, KVCVideo *> *viewRegistry) {
    KVCVideo *view = viewRegistry[reactTag];
    if (![view isKindOfClass:[KVCVideo class]]) {
      RCTLogError(@"Invalid view returned from registry, expecting RCTVideo, got: %@", view);
    } else {
      [view save:options resolve:resolve reject:reject];
    }
  }];
}
RCT_EXPORT_VIEW_PROPERTY(onPictureInPictureStatusChanged, RCTBubblingEventBlock);
RCT_EXPORT_VIEW_PROPERTY(onRestoreUserInterfaceForPictureInPictureStop, RCTBubblingEventBlock);

- (NSDictionary *)constantsToExport
{
  return @{
           @"ScaleNone": AVLayerVideoGravityResizeAspect,
           @"ScaleToFill": AVLayerVideoGravityResize,
           @"ScaleAspectFit": AVLayerVideoGravityResizeAspect,
           @"ScaleAspectFill": AVLayerVideoGravityResizeAspectFill
           };
}

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

@end

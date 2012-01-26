
#import <UIKit/UIKit.h>
#import <MessageUI/MFMailComposeViewController.h>
#import <AVFoundation/AVFoundation.h>

@class WebViewController;
@class AppDelegate;
@class XMLNode;
@class XMLTracklist;
@class XMLTrack;
@class CachedAd;
@class MPMoviePlayerController;
@class FlyProgressView;
@class BusyView;
@class AppConfig;
@class AppMobiDelegate;

@interface PlayingView : UIView <MFMailComposeViewControllerDelegate, UIWebViewDelegate, UIAlertViewDelegate, AVAudioPlayerDelegate>//, UIActionSheetDelegate>
{
	NSMutableArray *myNodeQueue;
	NSLock *iconLock;
	NSLock *myLock;
	NSLock *uiLock;
	NSMutableArray *myWebViewArray;
	NSMutableDictionary *mySoundPool;
	XMLNode *currentNode;
	XMLTracklist *currentTracklist;
	XMLTracklist *oldTracklist;
	FlyProgressView *myProgress;
	MPMoviePlayerController *videoPlayer;
	BusyView *busyView;
	int currentIndex;
	int shareindex;
	int adindex;
	int iResume;
	int mMaxSeconds;
	int mCurSeconds;
	float fVolume;
	BOOL bDoubleClick;
	BOOL bAsking;
	BOOL bJunk;
	BOOL bWarnBuffering;
	BOOL bShowUpgrade;
	int polyMaxMode;
	
	NSMutableArray *allTracklists;
	NSMutableArray *allTracks;
	NSMutableArray *arrAdCache;
	NSMutableArray *arrImageCache;
	
	UIButton *adView;
	NSDictionary *attributes;
	AVAudioPlayer *adPlayer;

	UIScrollView *myScroller;
	UILabel *myMetadata;
	UIAlertView *warning;
	UIAlertView *asking;

	UIImageView *myBackground;
	//UISlider *myVolume;
	//UIImageView *myCoverLeft1;
	//UIImageView *myCoverLeft2;
	//UIImageView *myCoverLeft3;
	//UIImageView *myCoverLeft4;
	//UIImageView *myCoverLeft5;
	UIImageView *myCoverLeft6;
	UIImageView *myCoverLeftMirror;
	UIImageView *myCoverMirror;
	UIButton *myCoverCenter;
	UIButton *myCoverCurrent;
	//UIImageView *myCoverRight1;
	UIImageView *myCoverRight2;
	UIImageView *myCoverRightMirror;
	UIImageView *myLive;
	UIImage *myUnknown;
	UIImage *myUnavailable;
	UIImage *myLoading;
	UIImage *myFlyBack;
	UIImage *myFlyLive;
	UIImage *myBackPort;
	UIImage *myBackLand;
	UIImage *myPrevImage;
	UIImage *myNextImage;
	UIImage *myPlayImage;
	UIImage *myStopImage;
	//UIImage *myShareImage;
	UIImage *mySleepImage;
	UIImage *mySleepOnImage;
	UIImage *myPauseImage;
	UIImage *myLiveImage;
	UIImage *myCurrentImage;
	UIImage *myBackImage;

	UIButton *myPrev;
	UIButton *myNext;
	UIButton *myPlay;
	UIButton *myStop;
	UIButton *myRecord;
	UIButton *myFavorite;
	//UIButton *myThumbsup;
	//UIButton *myThumbsdown;
	//UIButton *myDelete;
	//UIButton *myShuffle;
	//UIButton *myShare;
	UIButton *mySleep;
	UIButton *myBack;
	CGPoint dragStart;

	int bitrate;
	int length;
	int song;

	NSString *lastPlaying;
	NSString *tracksReported;
	NSString *closeURL;
	NSString *podcastName;
	NSString *soundName;
	double myStartupTimeout;
	int loopingIndex;
	BOOL loopingOn;
	BOOL bRecording;
	BOOL bPlaying;
	BOOL bRotated;
	BOOL bSleeping;
	BOOL bInter;
	BOOL bPopup;
	BOOL bOffline;
	BOOL bWarnPause;
	BOOL bWarnClick;
	BOOL bWarnSkip;
	BOOL bResumeMode;
	BOOL bStarting;
	int sleeptimer;
	CachedAd *audioad;
	
	CGPoint portraitPosition;
	CGPoint landscapePosition;
	
	AppMobiDelegate *myDelegate;
	
	float audioCurrentTime;
}

//@property (nonatomic, assign) AppDelegate *myApp;
@property (nonatomic, copy) NSString *closeURL;
@property (nonatomic) BOOL bRecording;
@property (nonatomic) BOOL bPlaying;
@property (nonatomic) BOOL bInter;
@property (nonatomic) BOOL bPopup;
@property (nonatomic) BOOL bOffline;
@property (nonatomic) BOOL bResumeMode;
@property (nonatomic) int iResume;
@property (nonatomic, retain) XMLTracklist *currentTracklist;
@property (nonatomic, retain) BusyView *busyView;
@property (readonly) MPMoviePlayerController *videoPlayer;
@property (readonly) AVAudioPlayer *adPlayer;
@property (readonly) BOOL bStarting;
@property (nonatomic, retain) NSString *lastPlaying;
@property (nonatomic) int polyMaxMode;

+ (id)currentPlayingView;
- (void)clearResume;
- (void)setBackColor:(NSString *)strBackColor fillColor:(NSString *)strFillColor doneColor:(NSString *)strDoneColor playColor:(NSString *)strPlayColor;
- (void)playVideo:(NSURL *)url;
- (void)playSound:(NSString *)file;
- (void)loadSound:(NSString *)file;
- (void)loadSound:(NSString *)file withPolyphony:(int)count;
- (void)unloadSound:(NSString *)file;
- (void)unloadAllSounds;
- (void)startAudio:(NSString *)file withLooping:(BOOL)doesLoop;
- (void)toggleAudio;
- (void)stopAudio;
- (void)setAudioCurrentTime:(float)time;
- (void)getBackgrounds:(id)sender;
- (void)createViews:(id)sender;
- (void)showBusy:(BOOL)show withAd:(BOOL)ad;
//- (id)initWithApp:(AppDelegate *)app;
- (void)queueNextNode:(XMLNode *)node;
- (void)podcastComplete:(id)sender;
- (void)processEvent:(int)event forIndex:(int)index;
- (void)resetView:(id)sender;
- (void)refresh:(id)sender;
- (void)repaint:(id)sender;
- (UIImage *)getMirrorImage:(UIImage *)image forSize:(int)size;
- (int)getPlayingIndex;
- (void)onPlay:(id)sender;
- (void)onStop:(id)sender;
- (void)onPrev:(id)sender;
- (void)onNext:(id)sender;
- (CachedAd *)checkPreroll:(XMLTracklist *)tracklist;
- (void)checkPopup:(NSTimer *)timer;
- (void)checkInterstitial:(NSTimer *)timer;
- (void)prerollDone:(id)sender;
- (void)prerollError:(id)sender;
- (void)popupDone:(id)sender;
- (void)interDone:(id)sender;
- (void)onStop:(id)sender;
- (void)adjustVolume:(int)incr;
- (void)onSkipDone:(id)sender;
- (void)onStarving:(id)sender;
- (void)onBuffered:(id)sender;
- (void)onCantConnect:(id)sender;
- (void)onUnsupported:(id)sender;
- (void)onFail:(id)sender;
- (void)stationComplete:(id)sender;
- (void)shoutcastComplete:(id)sender;
- (BOOL)isHiding;
- (void)setOrientation:(int)degrees;
- (void)handleStop:(id)sender;
- (void)saveTracklists;
- (void)readTracklists;
- (void)deleteLogs;
- (void)readLogs;
- (void)logTrack:(NSString *)station forSong:(NSString *)song;
- (BOOL)verifyTrack:(XMLTrack *)track;
- (XMLTracklist *)persistTracklist:(XMLTracklist *)tracklist;
- (NSString *)getLengthName:(XMLTracklist *)tracklist;
- (void)deleteTracklist:(XMLTracklist *)tracklist;
- (void)deleteTrack:(XMLTrack *)track;
- (void)addNewTrack:(XMLTrack *)track;
- (void)setPositionsPortrait:(CGPoint)portrait AndLandscape:(CGPoint)landscape;
- (void)getAllCovers:(id)sender;
@end


#import "PlayingView.h"
#import "AppMobiDelegate.h"
#import "AppMobiViewController.h"
#import "AppMobiWebView.h"
#import "FlyProgressView.h"
#import "XMLDirectoryReader.h"
#import "XMLDirectory.h"
#import "XMLNode.h"
#import "XMLTracklist.h"
#import "XMLTrack.h"
#import "Player.h"
#import "CachedAd.h"
#import "BusyView.h"
#import "Version.h"
#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>
#import <CoreFoundation/CoreFoundation.h>
#import "AppConfig.h"
#import <AudioToolbox/AudioServices.h>
#import <AudioToolbox/AudioServices.h>
#import <AVFoundation/AVFoundation.h>
#import "TargetConditionals.h"
#import "DirectCanvas.h"

@implementation PlayingView

@synthesize lastPlaying;
@synthesize closeURL;
@synthesize bRecording;
@synthesize bPlaying;
@synthesize bPopup;
@synthesize bInter;
@synthesize	bResumeMode;
@synthesize iResume;
@synthesize bOffline;
@synthesize currentTracklist;
@synthesize busyView;
@synthesize adPlayer;
@synthesize videoPlayer;
@synthesize bStarting;
@synthesize polyMaxMode;

#define radians(degrees) (degrees * M_PI/180)

PlayingView *singletonPlayingView = nil;

NSString *strBase = nil;
NSString *strUID = nil;
NSString *strServer = nil;
NSString *strWhite = nil;
NSString *strCommand = nil;
NSString *strSpeed = nil;
NSString *strVers = nil;

+ (id)currentPlayingView
{
	return singletonPlayingView;
}

- (NSString *)urlencode:(NSString *)url
{
    NSArray *escapeChars  = [NSArray arrayWithObjects:@"%", @";", @"/", @"\\", @"?", @":", @"@", @"&", @"=", @"+", @"$", @",", @"[", @"]", @"#", @"!", @"'", @"(",	@")", @"*", @" ", nil];
    NSArray *replaceChars = [NSArray arrayWithObjects:@"%25", @"%3B", @"%2F", @"%5C", @"%3F", @"%3A", @"%40", @"%26", @"%3D", @"%2B", @"%24", @"%2C", @"%5B", @"%5D", @"%23", @"%21", @"%27", @"%28", @"%29", @"%2A", @"%20", nil];
	
    int len = [escapeChars count];
	
    NSMutableString *temp = [url mutableCopy];
	
    for(int i = 0; i < len; i++ )
    {
        [temp replaceOccurrencesOfString:[escapeChars objectAtIndex:i] withString:[replaceChars objectAtIndex:i] options:NSLiteralSearch range:NSMakeRange(0, [temp length])];
    }
	
    NSString *out = [[temp copy] autorelease];
	[temp release];
	
    return out;
}

- (NSString *)urldecode:(NSString *)url
{
    NSArray *replaceChars  = [NSArray arrayWithObjects:@";", @"/", @"\\", @"?", @":", @"@", @"&", @"=", @"+", @"$", @",", @"[", @"]", @"#", @"!", @"'", @"(", @")", @"*", @" ", @"%", nil];
    NSArray *unescapeChars = [NSArray arrayWithObjects:@"%3B", @"%2F", @"%5C", @"%3F", @"%3A", @"%40", @"%26", @"%3D", @"%2B", @"%24", @"%2C", @"%5B", @"%5D", @"%23", @"%21", @"%27", @"%28", @"%29", @"%2A", @"%20", @"%25", nil];
	
    int len = [unescapeChars count];
	
    NSMutableString *temp = [url mutableCopy];
	
    for( int i = 0; i < len; i++ )
    {
        [temp replaceOccurrencesOfString:[unescapeChars objectAtIndex:i] withString:[replaceChars objectAtIndex:i] options:NSLiteralSearch range:NSMakeRange(0, [temp length])];
    }
	
    NSString *out = [[temp copy] autorelease];
	[temp release];
	
    return out;
}

- (void)getBackgrounds:(id)sender
{
	AppConfig *config = (AppConfig *)sender;
	
	if( myLiveImage == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/live.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"live" ofType:@"png"];	
		}
		myLiveImage = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( myBackPort == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/player_bg_port.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"player_bg_port" ofType:@"png"];	
		}
		myBackPort = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( myBackLand == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/player_bg_ls.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"player_bg_ls" ofType:@"png"];	
		}
		myBackLand = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( myLoading == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/loading.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"loading" ofType:@"png"];	
		}
		myLoading = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( myUnknown == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/retrieving_data.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"retrieving_data" ofType:@"png"];	
		}
		myUnknown = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( myUnavailable == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/artwork_unavailable.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"artwork_unavailable" ofType:@"png"];	
		}
		myUnavailable = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( myFlyBack == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/go_back.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"go_back" ofType:@"png"];	
		}
		myFlyBack = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( myFlyLive == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/go_live.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"go_live" ofType:@"png"];	
		}
		myFlyLive = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( myPrevImage == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/prev_button.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"prev_button" ofType:@"png"];	
		}
		myPrevImage = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( myNextImage == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/next_button.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"next_button" ofType:@"png"];	
		}
		myNextImage = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( myPlayImage == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/play_button.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"play_button" ofType:@"png"];	
		}
		myPlayImage = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( myStopImage == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/stop_button.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"stop_button" ofType:@"png"];	
		}
		myStopImage = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	/*
	if( myShareImage == nil )
	{
		NSString *path = [AppMobiDelegate pathForResource:@"_appMobi/share_button.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"share_button" ofType:@"png"];	
		}
		myShareImage = [[UIImage alloc] initWithContentsOfFile:path];
	}
	//*/
	
	if( mySleepImage == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/timer_button.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"timer_button" ofType:@"png"];	
		}
		mySleepImage = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( myCurrentImage == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/snap_current_button.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"snap_current_button" ofType:@"png"];	
		}
		myCurrentImage = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( myBackImage == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/player_back_button.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"player_back_button" ofType:@"png"];	
		}
		myBackImage = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( mySleepOnImage == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/timer_button_on.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"timer_button_on" ofType:@"png"];	
		}
		mySleepOnImage = [[UIImage alloc] initWithContentsOfFile:path];
	}
	
	if( myPauseImage == nil )
	{
		NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/pause_button.png"];
		if(![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			path = [[NSBundle mainBundle] pathForResource:@"pause_button" ofType:@"png"];	
		}
		myPauseImage = [[UIImage alloc] initWithContentsOfFile:path];
	}
}

//- (id)initWithApp:(AppDelegate *)app
- (id)init
{
	CGRect frame = [[UIScreen mainScreen] applicationFrame];
	myDelegate = (AppMobiDelegate *)[[UIApplication sharedApplication] delegate];
	if (self = [super initWithFrame:CGRectMake(0,0,frame.size.width,frame.size.height)])
	{
		allTracklists = [[[NSMutableArray alloc] init] retain];		
		arrImageCache = [[[NSMutableArray alloc] init] retain];		
		mySoundPool = [[NSMutableDictionary alloc] init];
		singletonPlayingView = self;
		busyView = [[BusyView alloc] initWithView:self];
		iconLock = [[NSLock alloc] init];
		myNodeQueue = [[NSMutableArray alloc] init];
		myLock = [[NSLock alloc] init];
		uiLock = [[NSLock alloc] init];
		myWebViewArray = [[NSMutableArray alloc] init];
		myDelegate.myPlayer = nil;
		fVolume = 0.7;
		myStartupTimeout = 30.0;
		myDelegate.nextPlayer = nil;
		currentNode = nil;
		closeURL = @"";
		videoPlayer = nil;
		oldTracklist = nil;
		loopingOn = NO;
		loopingIndex = -1;
		adindex = 0;
		bRotated = NO;
		bPopup = NO;
		bInter = NO;
		bWarnPause = YES;
		bWarnClick = NO;
		bWarnSkip = NO;
		bResumeMode = NO;		
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		bWarnClick = [defaults boolForKey:@"Click"];
		bWarnSkip = [defaults boolForKey:@"Skip"];
		
		warning = nil;
		dragStart = CGPointMake(-1.0, -1.0);
		if ([AppMobiDelegate isIPad]) {
			//iPad
			portraitPosition = CGPointMake(768-320, 0);
			landscapePosition = CGPointMake(1024-480, 0);
		} else {
			//iPhone
			portraitPosition = CGPointMake(0, 0);
			landscapePosition = CGPointMake(0, 0);
		}

		//[self loadView];
		[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refresh:) userInfo:nil repeats:YES];
	}
	
	if( strUID == nil )
	{
		[self readTracklists];
		NSArray *arr = NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES );
		strBase = [[arr objectAtIndex:0] retain];
		strUID = @"00000000-0000-0000-0000-000000000000";
		strCommand = @"/external/ClientServices.aspx";
		strServer = @"services.flycast.fm";
		strVers = @"1.0";
		strWhite = myDelegate.whiteLabel;
		strSpeed = @"&SPEED=UNK";
	}

	return self;
}

//- (void)loadView
- (void)createViews:(id)sender
{
	UIView *contentView = self;
	self.backgroundColor = [UIColor clearColor];
	[self getBackgrounds:nil];

	self.clipsToBounds = YES;	
	
	myBackground = [[UIImageView alloc] initWithImage:myBackPort];
	myBackground.frame = CGRectMake(0, 0, 320, 460);
	myBackground.contentMode = UIViewContentModeTopLeft;
	[contentView addSubview:myBackground];
	
	myScroller = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 378, 320, 26)];
	myScroller.showsHorizontalScrollIndicator = NO;
	myScroller.showsVerticalScrollIndicator = NO;
	myScroller.backgroundColor = [UIColor clearColor];
	myScroller.userInteractionEnabled = NO;
	[contentView addSubview:myScroller];

	myMetadata = [[UILabel alloc] initWithFrame:CGRectMake(0, 3, 320, 20)];
	myMetadata.text = @"";
	myMetadata.textColor = [UIColor whiteColor];
	myMetadata.backgroundColor = [UIColor clearColor];
	myMetadata.textAlignment = UITextAlignmentCenter;
	myMetadata.font = [UIFont boldSystemFontOfSize:16.0];
	[myScroller addSubview:myMetadata];

	CATransform3D leftPerspectiveTransform = CATransform3DScale(CATransform3DIdentity, 0.75, 0.75, 1.0);
	leftPerspectiveTransform.m34 = 1.0 / -500;
	leftPerspectiveTransform = CATransform3DRotate(leftPerspectiveTransform, 60.0f * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
	
	CATransform3D leftPerspectiveTransform2 = CATransform3DScale(CATransform3DIdentity, 0.75, 0.75, 1.0);
	leftPerspectiveTransform2.m34 = 1.0 / -500;
	leftPerspectiveTransform2 = CATransform3DRotate(leftPerspectiveTransform2, 60.0f * M_PI / 180.0f, -0.07f, 1.0f, -0.18f);

	CATransform3D rightPerspectiveTransform = CATransform3DScale(CATransform3DIdentity, 0.75, 0.75, 1.0);
	rightPerspectiveTransform.m34 = 1.0 / -500;
	rightPerspectiveTransform = CATransform3DRotate(rightPerspectiveTransform, -60.0f * M_PI / 180.0f, 0.0f, 1.0f, 0.0f);
	
	CATransform3D rightPerspectiveTransform2 = CATransform3DScale(CATransform3DIdentity, 0.75, 0.75, 1.0);
	rightPerspectiveTransform2.m34 = 1.0 / -500;
	rightPerspectiveTransform2 = CATransform3DRotate(rightPerspectiveTransform2, -60.0f * M_PI / 180.0f, -0.05f, 1.0f, -0.24f);
	
	/*
	myCoverLeft1 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"noartwork.png"] ];
	myCoverLeft1.frame = CGRectMake(-200, 40, 160, 160);
	myCoverLeft1.layer.transform = rightPerspectiveTransform;
	myCoverLeft1.hidden = YES;
	[myBackground addSubview:myCoverLeft1];

	myCoverLeft2 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"noartwork2.png"] ];
	myCoverLeft2.frame = CGRectMake(-160, 40, 160, 160);
	myCoverLeft2.layer.transform = rightPerspectiveTransform;
	myCoverLeft2.hidden = YES;
	[myBackground addSubview:myCoverLeft2];

	myCoverLeft3 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"noartwork2.png"] ];
	myCoverLeft3.frame = CGRectMake(-120, 40, 160, 160);
	myCoverLeft3.layer.transform = rightPerspectiveTransform;
	myCoverLeft3.hidden = YES;
	[myBackground addSubview:myCoverLeft3];

	myCoverLeft4 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"noartwork2.png"] ];
	myCoverLeft4.frame = CGRectMake(-80, 40, 160, 160);
	myCoverLeft4.layer.transform = rightPerspectiveTransform;
	myCoverLeft4.hidden = YES;
	[myBackground addSubview:myCoverLeft4];

	myCoverLeft5 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"noartwork2.png"] ];
	myCoverLeft5.frame = CGRectMake(-40, 40, 160, 160);
	myCoverLeft5.layer.transform = rightPerspectiveTransform;
	myCoverLeft5.hidden = YES;
	[myBackground addSubview:myCoverLeft5];
	 //*/
	
	myCoverLeftMirror = [[UIImageView alloc] initWithImage:nil];
	myCoverLeftMirror.frame = CGRectMake(0, 200, 160, 40);
	myCoverLeftMirror.layer.transform = rightPerspectiveTransform2;
	myCoverLeftMirror.alpha = 0.33;
	myCoverLeftMirror.hidden = YES;
	[myBackground addSubview:myCoverLeftMirror];

	myCoverLeft6 = [[UIImageView alloc] initWithImage:myUnknown];
	myCoverLeft6.frame = CGRectMake(0, 40, 160, 160);
	myCoverLeft6.layer.transform = rightPerspectiveTransform;
	myCoverLeft6.alpha = 0.33;
	myCoverLeft6.hidden = YES;
	[myBackground addSubview:myCoverLeft6];
	
	myCoverRightMirror = [[UIImageView alloc] initWithImage:nil];
	myCoverRightMirror.frame = CGRectMake(160, 200, 160, 40);
	myCoverRightMirror.layer.transform = leftPerspectiveTransform2;
	myCoverRightMirror.alpha = 0.33;
	myCoverRightMirror.hidden = YES;
	[myBackground addSubview:myCoverRightMirror];

	myCoverRight2 = [[UIImageView alloc] initWithImage:myUnknown];
	myCoverRight2.frame = CGRectMake(160, 40, 160, 160);
	myCoverRight2.layer.transform = leftPerspectiveTransform;
	myCoverRight2.alpha = 0.33;
	myCoverRight2.hidden = YES;
	[myBackground addSubview:myCoverRight2];

	/*
	myCoverRight1 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"noartwork4.png"] ];
	myCoverRight1.frame = CGRectMake(200, 40, 160, 160);
	myCoverRight1.layer.transform = leftPerspectiveTransform;
	myCoverRight1.hidden = YES;
	[myBackground addSubview:myCoverRight1];
	 //*/
	
	myCoverMirror = [[UIImageView alloc] initWithImage:nil];
	myCoverMirror.frame = CGRectMake(80, 166, 160, 40);
	//myCoverMirror.contentMode = UIViewContentModeTopLeft;
	//myCoverMirror.hidden = YES;
	[contentView addSubview:myCoverMirror];

	myCoverCenter = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	myCoverCenter.frame = CGRectMake(80, 100, 160, 160);
	[myCoverCenter setTitle:@"" forState:UIControlStateNormal];
	[myCoverCenter addTarget:self action:@selector(onClick:) forControlEvents:UIControlEventTouchUpInside];
	[myCoverCenter setImage:myUnknown forState:UIControlStateNormal];
	[contentView addSubview:myCoverCenter];

	myLive = [[UIImageView alloc] initWithImage:myLiveImage];
	myLive.frame = CGRectMake(240, 178, 47, 160);
	myLive.hidden = YES;
	[contentView addSubview:myLive];
	
	myCoverCurrent = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	myCoverCurrent.frame = CGRectMake(0, 30, 100, 48);
	[myCoverCurrent setTitle:@"" forState:UIControlStateNormal];
	[myCoverCurrent addTarget:self action:@selector(onCurrent:) forControlEvents:UIControlEventTouchUpInside];
	[myCoverCurrent setImage:myCurrentImage forState:UIControlStateNormal];
	myCoverCurrent.enabled = NO;
	[contentView addSubview:myCoverCurrent];

	/*
	myRecord = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	myRecord.frame = CGRectMake(5, 320, 41, 39);
	[myRecord setTitle:@"" forState:UIControlStateNormal];
	[myRecord addTarget:self action:@selector(onRecord:) forControlEvents:UIControlEventTouchUpInside];
	[myRecord setImage:[UIImage imageNamed:@"new_recordon.png"] forState:UIControlStateNormal];
	[contentView addSubview:myRecord];
	//*/

	/*
	myFavorite = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	myFavorite.frame = CGRectMake(216, 303, 41, 39);
	[myFavorite setTitle:@"" forState:UIControlStateNormal];
	[myFavorite addTarget:self action:@selector(onFavorite:) forControlEvents:UIControlEventTouchUpInside];
	[myFavorite setImage:[UIImage imageNamed:@"new_favoff.png"] forState:UIControlStateNormal];
	[contentView addSubview:myFavorite];
	//*/
	
	myPrev = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	myPrev.frame = CGRectMake(21, 303, 41, 39);
	[myPrev setTitle:@"" forState:UIControlStateNormal];
	[myPrev addTarget:self action:@selector(onPrev:) forControlEvents:UIControlEventTouchUpInside];
	[myPrev setImage:myPrevImage forState:UIControlStateNormal];
	myPrev.enabled = NO;
	[contentView addSubview:myPrev];

	myPlay = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	myPlay.frame = CGRectMake(60, 303, 41, 39);
	[myPlay setTitle:@"" forState:UIControlStateNormal];
	[myPlay addTarget:self action:@selector(onPlay:) forControlEvents:UIControlEventTouchUpInside];
	[myPlay setImage:myPauseImage forState:UIControlStateNormal];
	myPlay.enabled = NO;
	[contentView addSubview:myPlay];

	myStop = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	myStop.frame = CGRectMake(138, 303, 41, 39);
	[myStop setTitle:@"" forState:UIControlStateNormal];
	[myStop addTarget:self action:@selector(onStop:) forControlEvents:UIControlEventTouchUpInside];
	[myStop setImage:myStopImage forState:UIControlStateNormal];
	myStop.enabled = NO;
	[contentView addSubview:myStop];

	myNext = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	myNext.frame = CGRectMake(99, 303, 41, 39);
	[myNext setTitle:@"" forState:UIControlStateNormal];
	[myNext addTarget:self action:@selector(onNext:) forControlEvents:UIControlEventTouchUpInside];
	[myNext setImage:myNextImage forState:UIControlStateNormal];
	myNext.enabled = NO;
	[contentView addSubview:myNext];
	
	/*
	myShare = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	myShare.frame = CGRectMake(177, 303, 41, 39);
	[myShare setTitle:@"" forState:UIControlStateNormal];
	[myShare addTarget:self action:@selector(onShare:) forControlEvents:UIControlEventTouchUpInside];
	[myShare setImage:myShareImage forState:UIControlStateNormal];
	myShare.enabled = NO;
	[contentView addSubview:myShare];
	//*/
	
	mySleep = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	mySleep.frame = CGRectMake(255, 303, 41, 39);
	[mySleep setTitle:@"" forState:UIControlStateNormal];
	[mySleep addTarget:self action:@selector(onSleep:) forControlEvents:UIControlEventTouchUpInside];
	[mySleep setImage:mySleepImage forState:UIControlStateNormal];
	mySleep.enabled = NO;
	[contentView addSubview:mySleep];
	
	myBack = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	myBack.frame = CGRectMake(0, 127, 44, 34);
	[myBack setTitle:@"" forState:UIControlStateNormal];
	[myBack addTarget:self action:@selector(onBack:) forControlEvents:UIControlEventTouchUpInside];
	[myBack setImage:myBackImage forState:UIControlStateNormal];
	[contentView addSubview:myBack];

	/*
	myThumbsup = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	myThumbsup.frame = CGRectMake(230, 320, 41, 39);
	[myThumbsup setTitle:@"" forState:UIControlStateNormal];
	[myThumbsup addTarget:self action:@selector(onLove:) forControlEvents:UIControlEventTouchUpInside];
	[myThumbsup setImage:[UIImage imageNamed:@"new_thumbsup.png"] forState:UIControlStateNormal];
	[contentView addSubview:myThumbsup];

	myThumbsdown = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	myThumbsdown.frame = CGRectMake(275, 320, 41, 39);
	[myThumbsdown setTitle:@"" forState:UIControlStateNormal];
	[myThumbsdown addTarget:self action:@selector(onHate:) forControlEvents:UIControlEventTouchUpInside];
	[myThumbsdown setImage:[UIImage imageNamed:@"new_thumbsdown.png"] forState:UIControlStateNormal];
	[contentView addSubview:myThumbsdown];

	myDelete = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	myDelete.frame = CGRectMake(230, 320, 41, 39);
	[myDelete setTitle:@"" forState:UIControlStateNormal];
	[myDelete addTarget:self action:@selector(onDelete:) forControlEvents:UIControlEventTouchUpInside];
	[myDelete setImage:[UIImage imageNamed:@"new_del.png"] forState:UIControlStateNormal];
	myDelete.hidden = YES;
	[contentView addSubview:myDelete];

	myShuffle = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	myShuffle.frame = CGRectMake(275, 320, 41, 39);
	[myShuffle setTitle:@"" forState:UIControlStateNormal];
	[myShuffle addTarget:self action:@selector(onShuffle:) forControlEvents:UIControlEventTouchUpInside];
	[myShuffle setImage:[UIImage imageNamed:@"new_shuffle.png"] forState:UIControlStateNormal];
	myShuffle.hidden = YES;
	[contentView addSubview:myShuffle];

	myVolume = [[UISlider alloc] initWithFrame:CGRectMake(10,296,300,24)];
	[myVolume addTarget:self action:@selector(onVolume:) forControlEvents:UIControlEventValueChanged];
	[myVolume setThumbImage: [UIImage imageNamed:@"ball.png"] forState:UIControlStateNormal];
	[myVolume setMinimumTrackImage:[[UIImage imageNamed:@"slideon.png"] stretchableImageWithLeftCapWidth:10.0 topCapHeight:0.0] forState:UIControlStateNormal];
	[myVolume setMaximumTrackImage:[[UIImage imageNamed:@"slideoff.png"] stretchableImageWithLeftCapWidth:10.0 topCapHeight:0.0] forState:UIControlStateNormal];
	myVolume.backgroundColor = [UIColor clearColor];
	myVolume.minimumValue = 0.0;
	myVolume.maximumValue = 1.0;
	myVolume.continuous = YES;
	myVolume.value = 1.0;
	[contentView addSubview:myVolume];
	//*/

	myProgress = [[FlyProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
	myProgress.frame = CGRectMake(0, 378, 320, 1);
	[contentView addSubview:myProgress];
}

- (UIImage *)getImageForTrack:(XMLTrack *)ptrack
{
	if( ptrack.flylive == YES )
	{
		return myFlyLive;
	}
	else if( ptrack.flyback == YES )
	{
		return myFlyBack;
	}
	else if( ptrack.delayed == YES || ptrack.listened == NO )
	{
		double fraction = ptrack.timecode - (long) ptrack.timecode;
		unsigned long index = (long) (fraction * 10000);
		index = index % 5;
		return myUnknown;
	}
	else if( ptrack.original != nil )
	{
		return ptrack.original;
	}
	else if( ( currentTracklist.podcasting == YES || currentTracklist.video == YES ) && currentTracklist.original != nil )
	{
		return currentTracklist.original;
	}
	else if( ( currentTracklist.podcasting == YES || currentTracklist.video == YES ) && currentTracklist.imageurl != nil )
	{
		return myLoading;
	}
	else if( ptrack.imageurl == nil )
	{
		double fraction = ptrack.timecode - (long) ptrack.timecode;
		unsigned long index = (long) (fraction * 10000);
		index = index % 5;
		return myUnavailable;
	}
	else
	{
		return myLoading;
	}
}

- (void)refresh:(id)sender
{
	if(((AppMobiDelegate *)[[UIApplication sharedApplication] delegate]).bInBackground) return;
	
	int count = 0;
	if( currentTracklist != nil ) count = [currentTracklist.children count];

	if( currentIndex >= 0 && currentIndex < count && count > 0 )
	{
		XMLTrack *temp = (XMLTrack *) [currentTracklist.children objectAtIndex:currentIndex];
		int tlength = temp.length;
		if( tlength == 999999999 ) tlength = temp.bitrate * 128 * 60 * 15;
		if( tlength > 0 )
		{
			[myProgress setDone:temp.cached];
			myProgress.progress = (float)(temp.current-temp.offset)/(float)tlength;
			//printf( "-- PROGRESSING [%f]\n", myProgress.progress );
		}
		else
		{
			myProgress.progress = 0.0;
		}

		if( currentIndex == [myDelegate.myPlayer getPlayingIndex] )
		{
			myProgress.position = (float)temp.readoff / (float)tlength;
			myCoverCurrent.enabled = NO;
		}
		else
		{
			myProgress.position = -1.0;
			myCoverCurrent.enabled = YES;
		}
		
		if( temp.cached == YES )
		{
			[myProgress setDone:YES];
			myProgress.progress = 1.0;
		}
		
		if( myDelegate.myPlayer != nil && [myDelegate.myPlayer getPlayingIndex] < [currentTracklist.children count] )
			[[AppMobiViewController masterViewController] updateTrackInfo:[currentTracklist.children objectAtIndex:[myDelegate.myPlayer getPlayingIndex]]];
	}
	else
	{
		[myProgress setDone:NO];
		myProgress.progress = 0.0;
		myProgress.position = -1.0;
		//myCoverLeft1.hidden = YES;
		//myCoverLeft2.hidden = YES;
		//myCoverLeft3.hidden = YES;
		//myCoverLeft4.hidden = YES;
		//myCoverLeft5.hidden = YES;
		myCoverLeft6.hidden = YES;
		//myCoverRight1.hidden = YES;
		myCoverRight2.hidden = YES;
		myLive.hidden = YES;
		[myCoverCenter setImage:myUnknown forState:UIControlStateNormal];
		//myMetadata.text = @"";
		
		[[AppMobiViewController masterViewController] updateTrackInfo:nil];
	}
}

- (NSString *)addTimeline:(XMLTrack *)temp
{
	NSString *title = temp.title;

	if( temp != nil && temp.cached == YES && temp.bitrate != 99999 && temp.bitrate != 0 && temp.title != nil )
	{
		int time = temp.length / temp.bitrate / 128;
		time = time * 1.023;
		int mins = (int)(time / 60);
		int secs = time - (mins * 60);
		title = [NSString stringWithFormat:@"%@ (%d:%02d)", title, mins, secs];
	}

	return title;
}

- (void)resetMirror:(id)sender
{
	if(((AppMobiDelegate *)[[UIApplication sharedApplication] delegate]).bInBackground) return;
	
	if( currentTracklist == nil || 	currentIndex >= [currentTracklist.children count] ) return;
	int size = 12;
	UIInterfaceOrientation neworient = [AppMobiViewController masterViewController].interfaceOrientation;
	if( neworient == UIInterfaceOrientationPortrait || neworient == UIInterfaceOrientationPortraitUpsideDown )
		size = 26;

	XMLTrack *temp = (XMLTrack *) [currentTracklist.children objectAtIndex:(currentIndex)];
	//printf(" C Image --- %s\r\n", [temp.title cStringUsingEncoding:NSASCIIStringEncoding]);
	UIImage *timage = [self getImageForTrack:temp];
	[myCoverCenter setImage:timage forState:UIControlStateNormal];
	myCoverMirror.image = [self getMirrorImage:timage forSize:size];
	
	myCoverLeftMirror.hidden = YES;
	if( currentIndex > 0 )
	{
		temp = (XMLTrack *) [currentTracklist.children objectAtIndex:(currentIndex-1)];
		//printf(" L Image --- %s\r\n", [temp.title cStringUsingEncoding:NSASCIIStringEncoding]);
		UIImage *timage = [self getImageForTrack:temp];
		myCoverLeftMirror.image = [self getMirrorImage:timage forSize:size];
		myCoverLeftMirror.hidden = NO;
	}
	
	myCoverRightMirror.hidden = YES;
	if( currentIndex + 1 < [currentTracklist.children count] )
	{
		temp = (XMLTrack *) [currentTracklist.children objectAtIndex:(currentIndex+1)];
		//printf(" R Image --- %s\r\n", [temp.title cStringUsingEncoding:NSASCIIStringEncoding]);
		UIImage *timage = [self getImageForTrack:temp];
		myCoverRightMirror.image = [self getMirrorImage:timage forSize:size];
		myCoverRightMirror.hidden = NO;
	}
}

- (void)repaint:(id)sender
{
	if(((AppMobiDelegate *)[[UIApplication sharedApplication] delegate]).bInBackground) return;
	
	XMLTrack *temp = nil;
	int count = [currentTracklist.children count];
	[uiLock lock];

	if( currentIndex >= 0 && currentIndex < count )
	{
		//printf("do repainting\r\n");

		int index = [myDelegate.myPlayer getPlayingIndex];
		if( NO && index >= 0  && index < count && myDelegate.myPlayer != nil )
		{
			//temp = (XMLTrack *) [currentTracklist.children objectAtIndex:(index)];
			//myCurrentCover.hidden = NO;
			//myCurrentCover.image = [self getImageForTrack:temp];
			//[myBackground.layer display];
		}

		BOOL landscape = ([AppMobiViewController masterViewController].interfaceOrientation == UIInterfaceOrientationLandscapeLeft || [AppMobiViewController masterViewController].interfaceOrientation == UIInterfaceOrientationLandscapeRight );
		/*
		if( landscape == YES && currentIndex > 5 )
		{
			temp = (XMLTrack *) [currentTracklist.children objectAtIndex:(currentIndex-6)];
			myCoverLeft1.image = [self getImageForTrack:temp];
			myCoverLeft1.hidden = NO;
		}
		else
			myCoverLeft1.hidden = YES;
		if( landscape == YES  && currentIndex > 4 )
		{
			temp = (XMLTrack *) [currentTracklist.children objectAtIndex:(currentIndex-5)];
			myCoverLeft2.image = [self getImageForTrack:temp];
			myCoverLeft2.hidden = NO;
		}
		else
			myCoverLeft2.hidden = YES;
		if( landscape == YES  && currentIndex > 3 )
		{
			temp = (XMLTrack *) [currentTracklist.children objectAtIndex:(currentIndex-4)];
			myCoverLeft3.image = [self getImageForTrack:temp];
			myCoverLeft3.hidden = NO;
		}
		else
			myCoverLeft3.hidden = YES;
		if( landscape == YES  && currentIndex > 2 )
		{
			temp = (XMLTrack *) [currentTracklist.children objectAtIndex:(currentIndex-3)];
			myCoverLeft4.image = [self getImageForTrack:temp];
			myCoverLeft4.hidden = NO;
		}
		else
			myCoverLeft4.hidden = YES;
		if( currentIndex > 1 )
		{
			temp = (XMLTrack *) [currentTracklist.children objectAtIndex:(currentIndex-2)];
			//printf("LL Image --- %s\r\n", [temp.title cStringUsingEncoding:NSASCIIStringEncoding]);
			myCoverLeft5.image = [self getImageForTrack:temp];
			myCoverLeft5.hidden = NO;
		}
		else
			myCoverLeft5.hidden = YES;
		//*/
		if( currentIndex > 0 )
		{
			temp = (XMLTrack *) [currentTracklist.children objectAtIndex:(currentIndex-1)];
			//printf(" L Image --- %s\r\n", [temp.title cStringUsingEncoding:NSASCIIStringEncoding]);
			myCoverLeft6.image = [self getImageForTrack:temp];
			myCoverLeft6.hidden = NO;
		}
		else
			myCoverLeft6.hidden = YES;
		if( currentIndex < count )
		{
			[self resetMirror:nil];
			temp = (XMLTrack *) [currentTracklist.children objectAtIndex:(currentIndex)];
			//printf(" C Image --- %s\r\n", [temp.title cStringUsingEncoding:NSASCIIStringEncoding]);
			UIImage *timage = [self getImageForTrack:temp];
			[myCoverCenter setImage:timage forState:UIControlStateNormal];
			//myCoverMirror.image = [self getMirrorImage:timage];
			
			myLive.hidden = ( (temp.length == 999999999 ) ? NO : YES );
			if( currentTracklist.shoutcasting == YES ) myLive.hidden = NO;
			//myShare.enabled = NO;//( temp.flyback != YES && temp.flylive != YES && temp.listened != NO );
			if( bOffline == YES ) 
			{
				myLive.hidden = YES;
				//myShare.enabled = NO;
				myFavorite.enabled = NO;
			}
			if( currentIndex <= count - 2 )
			{
				myLive.hidden = YES;
			}
			
			//myThumbsup.enabled = ( temp.flyback == YES || temp.listened == NO );
			//myThumbsdown.hidden = ( temp.flyback == YES || temp.listened == NO );
			
			//*
			NSString *meta = nil;
			if( ( temp.delayed == YES || temp.listened == NO || temp.artist == nil ) && temp.flyback == NO )
			{
				if( temp.artist == nil )
					meta = @"";
				else
					meta = @"Tracks become available as you listen.";
			}			
			else
			{
				NSString *title = [self addTimeline:temp];
				if( temp.artist != nil && title != nil && temp.album != nil )
					meta = [[[NSString alloc] initWithFormat:@"%@ - %@ - %@", temp.artist, title, temp.album] autorelease];
				else if( temp.artist != nil && title != nil )
					meta = [[[NSString alloc] initWithFormat:@"%@ - %@", temp.artist, title] autorelease];
				else if( temp.artist != nil && temp.album != nil )
					meta = [[[NSString alloc] initWithFormat:@"%@ - %@", temp.artist, temp.album] autorelease];
				else
					meta = temp.artist;
			}

			if( ( meta != nil && [meta compare:myMetadata.text options:NSCaseInsensitiveSearch] != NSOrderedSame ) || bRotated == YES )
			{
				bRotated = NO;
				myMetadata.font = [UIFont boldSystemFontOfSize:16.0];
				myMetadata.text = meta;
				[myScroller.layer removeAllAnimations];

				myScroller.contentOffset = CGPointMake(0,0);
				[myMetadata sizeToFit];
				myScroller.contentSize = myMetadata.frame.size;
				myMetadata.text = [[meta copy] autorelease];

				if( landscape == NO )
				{
					if( myMetadata.frame.size.width > 320 && myMetadata.frame.size.width < 350 )
					{
						myMetadata.font = [UIFont boldSystemFontOfSize:15.0];
						[myMetadata sizeToFit];
						myScroller.contentSize = myMetadata.frame.size;
						myMetadata.text = [[meta copy] autorelease];
					}

					if( myMetadata.frame.size.width > 320 )
					{
						myMetadata.textAlignment = UITextAlignmentLeft;
						[UIView beginAnimations:@"pan" context:nil];
						[UIView setAnimationsEnabled:YES];
						[UIView setAnimationRepeatAutoreverses:YES];
						[UIView setAnimationDuration:5.0];
						[UIView setAnimationRepeatCount:500000];
						myScroller.contentOffset = CGPointMake(myMetadata.frame.size.width-320,0);
						[UIView commitAnimations];
					}
					else
					{
						myMetadata.frame = CGRectMake(0, 3, 320, 20);
						myMetadata.textAlignment = UITextAlignmentCenter;
					}
				}
				else
				{
					if( myMetadata.frame.size.width > 480 && myMetadata.frame.size.width < 510 )
					{
						myMetadata.font = [UIFont boldSystemFontOfSize:15.0];
						[myMetadata sizeToFit];
						myScroller.contentSize = myMetadata.frame.size;
						myMetadata.text = [[meta copy] autorelease];
					}

					if( myMetadata.frame.size.width > 480 )
					{
						myMetadata.textAlignment = UITextAlignmentLeft;
						[UIView beginAnimations:@"pan" context:nil];
						[UIView setAnimationsEnabled:YES];
						[UIView setAnimationRepeatAutoreverses:YES];
						[UIView setAnimationDuration:5.0];
						[UIView setAnimationRepeatCount:500000];
						myScroller.contentOffset = CGPointMake(myMetadata.frame.size.width-480,0);
						[UIView commitAnimations];
					}
					else
					{
						myMetadata.frame = CGRectMake(0, 3, 480, 20);
						myMetadata.textAlignment = UITextAlignmentCenter;
					}
				}
			}
			//*/
		}
		if( currentIndex + 1 < count )
		{
			temp = (XMLTrack *) [currentTracklist.children objectAtIndex:(currentIndex+1)];
			//printf(" R Image (%d) --- (%d) -- %s\r\n", temp.delayed, temp.listened, [temp.title cStringUsingEncoding:NSASCIIStringEncoding]);
			UIImage *timage = [self getImageForTrack:temp];
			myCoverRight2.image = timage;
			myCoverRight2.hidden = NO;
		}
		else
			myCoverRight2.hidden = YES;
		/*
		if( currentIndex + 2 < count )
		{
			temp = (XMLTrack *) [currentTracklist.children objectAtIndex:(currentIndex+2)];
			//printf("RR Image --- %s\r\n", [temp.title cStringUsingEncoding:NSASCIIStringEncoding]);
			UIImage *timage = [self getImageForTrack:temp];
			myCoverRight1.image = timage;
			myCoverRight1.hidden = NO;
		}
		else
			myCoverRight1.hidden = YES;
		//*/
	}
	[uiLock unlock];
}

- (void)processEvent:(int)event forIndex:(int)index
{
	XMLTrack *temp = nil;
	int count = [currentTracklist.children count];

	/*
	switch( event )
	{
		case EVENT_TRACKBUFFERED:
			printf(" *** EVENT_TRACKBUFFERED\n");
			break;
		case EVENT_TRACKCACHED:
			printf(" *** EVENT_TRACKCACHED\n");
			break;
		case EVENT_TRACKCOVERED:
			printf(" *** EVENT_TRACKCOVERED\n");
			break;
		case EVENT_TRACKADDED:
			printf(" *** EVENT_TRACKADDED\n");
			break;
		case EVENT_TRACKPLAYING:
			printf(" *** EVENT_TRACKPLAYING\n");
			break;
		case EVENT_TRACKLISTRECORDED:
			printf(" *** EVENT_TRACKLISTRECORDED\n");
			break;
		case EVENT_SCREENUPDATE:
			printf(" *** EVENT_SCREENUPDATE\n");
			break;
		case EVENT_TRACKUPDATED:
			printf(" *** EVENT_TRACKUPDATED\n");
			break;
	}
	//*/

	if( event == EVENT_TRACKBUFFERED && index >= 0 && index < count && !((AppMobiDelegate *)[[UIApplication sharedApplication] delegate]).bInBackground )
	{
		temp = (XMLTrack *) [currentTracklist.children objectAtIndex:index];
		[NSThread detachNewThreadSelector:@selector(coverWorker:) toTarget:self withObject:temp];
	}
	
	if( event == EVENT_TRACKCACHED && index >= 0 && index < count && !((AppMobiDelegate *)[[UIApplication sharedApplication] delegate]).bInBackground )
	{
		temp = (XMLTrack *) [currentTracklist.children objectAtIndex:index];
		if( temp.original == nil ) [NSThread detachNewThreadSelector:@selector(coverWorker:) toTarget:self withObject:temp];
	}

	if( event == EVENT_TRACKPLAYING && currentIndex < count)
	{
		if( index > 0 && index < [currentTracklist.children count] )
		{
			temp = (XMLTrack *) [currentTracklist.children objectAtIndex:index - 1];
			temp.resuming = NO;
		}
		myCoverCenter.enabled = YES;
		if( currentIndex + 1 == index )
		{
			currentIndex = index;
		}
		if( index > 0 && index < [currentTracklist.children count] )
		{
			temp = (XMLTrack *) [currentTracklist.children objectAtIndex:index];
			currentTracklist.startindex = index;
			temp.resuming = YES;
		}
	}
	
	if( event == EVENT_TRACKADDED && currentIndex > index )
	{
		currentIndex++;
	}
	
	if( event == EVENT_TRACKUPDATED && currentTracklist.shoutcasting == YES )
	{
		temp = (XMLTrack *) [currentTracklist.children objectAtIndex:index];
		[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(updateShoutcastInfo:) withObject:temp waitUntilDone:NO];
	}

	//printf("\r\ncalling repaint message(%d) for index (%d)\r\n", event, index);
	[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(repaint:) userInfo:nil repeats:NO];
	//[self performSelectorOnMainThread:@selector(repaint:) withObject:nil waitUntilDone:NO];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [[touches allObjects] objectAtIndex:0];
	dragStart = [touch locationInView:nil];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if( dragStart.x < 0.0 && dragStart.y < 0.0 ) return;

	UITouch *touch = [[touches allObjects] objectAtIndex:0];
	CGPoint dragEnd = [touch locationInView:nil];
	int count = 0;
	if( currentTracklist != nil ) count = [currentTracklist.children count];
	if( count == 0 ) return;

	UIInterfaceOrientation orient = [AppMobiViewController masterViewController].interfaceOrientation;
	if( orient == UIInterfaceOrientationLandscapeLeft )
	{
		if( (dragStart.y - dragEnd.y) > 50 && currentIndex > 0 )
		{
			currentIndex--;
			[self processEvent:EVENT_SCREENUPDATE forIndex:-1];
			[self refresh:nil];
		}
		if( (dragStart.y - dragEnd.y) < -50 && currentIndex + 1 < count )
		{
			currentIndex++;
			[self processEvent:EVENT_SCREENUPDATE forIndex:-1];
			[self refresh:nil];
		}
	}
	else if( orient == UIInterfaceOrientationLandscapeRight )
	{
		if( (dragStart.y - dragEnd.y) < -50 && currentIndex > 0 )
		{
			currentIndex--;
			[self processEvent:EVENT_SCREENUPDATE forIndex:-1];
			[self refresh:nil];
		}
		if( (dragStart.y - dragEnd.y) > 50 && currentIndex + 1 < count )
		{
			currentIndex++;
			[self processEvent:EVENT_SCREENUPDATE forIndex:-1];
			[self refresh:nil];
		}
	}
	else if( orient == UIInterfaceOrientationPortrait )
	{
		if( (dragStart.x - dragEnd.x) < -50 && count > 0 && currentIndex > 0 )
		{
			currentIndex--;
			[self processEvent:EVENT_SCREENUPDATE forIndex:-1];
			[self refresh:nil];
		}
		if( (dragStart.x - dragEnd.x) > 50 && count > 0 && currentIndex + 1 < count )
		{
			currentIndex++;
			[self processEvent:EVENT_SCREENUPDATE forIndex:-1];
			[self refresh:nil];
		}
	}
	else if( orient == UIInterfaceOrientationPortraitUpsideDown )
	{
		if( (dragStart.x - dragEnd.x) > 50 && count > 0 && currentIndex > 0 )
		{
			currentIndex--;
			[self processEvent:EVENT_SCREENUPDATE forIndex:-1];
			[self refresh:nil];
		}
		if( (dragStart.x - dragEnd.x) < -50 && count > 0 && currentIndex + 1 < count )
		{
			currentIndex++;
			[self processEvent:EVENT_SCREENUPDATE forIndex:-1];
			[self refresh:nil];
		}
	}
	dragStart = CGPointMake(-1.0, -1.0);
}

- (void)onDone:(id)sender
{
	//[self dismissModalViewControllerAnimated:YES];
}

- (void)onCurrent:(id)sender
{
	currentIndex = [myDelegate.myPlayer getPlayingIndex];
	[self processEvent:EVENT_SCREENUPDATE forIndex:-1];
	[self refresh:nil];	
}

- (void)onClick:(id)sender
{
	if( bWarnClick == NO )
	{
		bWarnClick = YES;
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setBool:bWarnClick forKey:@"Click"];
		[defaults synchronize];
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Switch Track" message:@"Double tapping a track will play it." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
		[alert show];
		[alert release];
		return;
	}
	
	if( bDoubleClick == YES )
	{
		[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onCenter:) userInfo:nil repeats:NO];
		bDoubleClick = NO;
	}
	else
	{
		bDoubleClick = YES;
		[NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(onCancel:) userInfo:nil repeats:NO];
	}
}

- (void)onCancel:(id)sender
{
	bDoubleClick = NO;
}

- (void)onCenter:(id)sender
{
	int count = 0;
	bDoubleClick = NO;
	if( currentTracklist != nil ) count = [currentTracklist.children count];
	if( currentTracklist.shoutcasting == YES ) return;
	
	if( currentTracklist.video == YES )
	{
		XMLTrack *temp = (XMLTrack *) [currentTracklist.children objectAtIndex:currentIndex];
		if( videoPlayer != nil )
		{
			[videoPlayer stop];
			if ([myDelegate.viewController respondsToSelector:@selector(dismissMoviePlayerViewControllerAnimated)]) {
				[myDelegate.viewController dismissMoviePlayerViewControllerAnimated];
			} else {
				[videoPlayer release];
			}
			videoPlayer = nil;
		}
		
		NSURL *url = [NSURL fileURLWithPath:temp.filename];
		if([myDelegate.viewController respondsToSelector:@selector(presentMoviePlayerViewControllerAnimated:)]){
			MPMoviePlayerViewController *mpvc = [[MPMoviePlayerViewController alloc] initWithContentURL:url];
			videoPlayer = mpvc.moviePlayer;
			[myDelegate.viewController presentMoviePlayerViewControllerAnimated:mpvc];
			[mpvc release];
		} else {
			videoPlayer = [[MPMoviePlayerController alloc] initWithContentURL:url];
		}
		[videoPlayer play];
		iResume = 0;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(movieFinishedCallback:) name:MPMoviePlayerPlaybackDidFinishNotification object:videoPlayer];
	}
	else if( currentIndex >= 0 && currentIndex < count && count > 0 && myDelegate.myPlayer != nil )
	{
		XMLTrack *temp = (XMLTrack *) [currentTracklist.children objectAtIndex:currentIndex];
		if( temp.delayed == NO && temp.listened == YES && currentTracklist.video == NO )
		{
			if( temp.flyback == YES )
			{
				temp.flyback = NO;
				temp.title = nil;
				temp.artist = nil;
				temp.guidSong = nil;
				for( int i = currentIndex + 1; i < [currentTracklist.children count]; i++ )
				{
					XMLTrack *stemp = (XMLTrack *) [currentTracklist.children objectAtIndex:i];
					if( stemp.flyback == YES )
					{
						[currentTracklist.children removeObjectAtIndex:i];
						i--;
					}
					else
						break;
				}

				currentTracklist.flybacking = YES;
				currentTracklist.startindex = currentIndex;
				currentTracklist.recording = YES;
			}
			
			if( temp.flylive == YES )
			{
				currentNode.nodeisJumping = YES;
				if( currentTracklist.cached == YES || currentTracklist.saved == YES )
				{
					myCoverCenter.enabled = NO;
					[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onGoLive:) userInfo:nil repeats:NO];
					return;
				}
				else
				{
					myCoverCenter.enabled = NO;
					[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onFlyLive:) userInfo:nil repeats:NO];
					return;
				}
			}
			
			myPrev.enabled = NO;
			myNext.enabled = NO;
			myPlay.enabled = NO;
			[myPlay setImage:myPauseImage forState:UIControlStateNormal];

			if (myDelegate.myPlayer.bPaused) {
				[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.station.play" waitUntilDone:NO];
			}
			
			myCoverCenter.enabled = NO;
			[myDelegate.myPlayer switchtrack:currentIndex];
			//[myBusy startAnimating];
			[self processEvent:EVENT_SCREENUPDATE forIndex:-1];
		}
	}
}

- (void)onFlyLive:(id)sender
{
	XMLTrack *temp = (XMLTrack *) [currentTracklist.children objectAtIndex:currentIndex];
	currentTracklist.startindex = currentIndex;
	temp.flylive = NO;
	temp.artist = nil;
	temp.guidSong = nil;	
	
	XMLDirectoryReader *xmlParser = [[[XMLDirectoryReader alloc] init] autorelease];
	NSString *url = [[[NSString alloc] initWithFormat:@"http://%@%@?%@%@&FEED=PLAY&ID=%d&UID=%@", strServer, strCommand, strWhite, strSpeed, temp.stationid, strUID] autorelease];
	//printf(" CLIENT SERVICES URL --- %s\r\n", [url cStringUsingEncoding:NSASCIIStringEncoding]);
	[xmlParser parseXMLURL:url andKeepData:NO];
	if( xmlParser.directory == nil || [xmlParser.directory.children count] == 0 )
	{		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Problem Connecting" message:@"We're sorry but we were unable to Go Live. Please try again later or another station." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
		[alert show];
		[alert release];
		[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onStop:) userInfo:nil repeats:NO];
		return;
	}
	
	XMLNode *tempnode = (XMLNode *) [xmlParser.directory.children objectAtIndex:0];
	temp.mediaurl = tempnode.nodeurl;
	
	myPrev.enabled = NO;
	myNext.enabled = NO;
	myPlay.enabled = NO;
	[myPlay setImage:myPauseImage forState:UIControlStateNormal];
	
	[myDelegate.myPlayer switchtrack:currentIndex];
	//[myBusy startAnimating];
	[self processEvent:EVENT_SCREENUPDATE forIndex:-1];
}

- (void)onGoLive:(id)sender
{
	if( currentNode == nil ) return;
	
	[myLock tryLock];
	[myLock unlock];
	
	oldTracklist = currentTracklist;
	currentNode.tracklist = nil;
	
	[self queueNextNode:currentNode];
}

- (void)getPodcastName:(NSURL *)url
{
	NSString *surl = [url absoluteString];
	podcastName = nil;
	NSRange range = NSMakeRange(0, [surl length]);
	int last = 0;
	while( range.length > 0 )
	{
		last = range.location;
		range.location++;
		range.length = [surl length] - range.location;
		range = [surl rangeOfString:@"/" options:NSCaseInsensitiveSearch range:range];
	}
	if( last > 0 )
	{
		podcastName = [surl substringFromIndex:last+1];
		range = [podcastName rangeOfString:@"."];
		if( range.length > 0 )
		{
			podcastName = [podcastName substringToIndex:range.location];
		}
	}
	
	[podcastName retain];
}

- (void)playVideo:(NSURL *)url
{
	if( adPlayer!=nil || videoPlayer != nil || ( myDelegate.myPlayer != nil && myDelegate.myPlayer.bPlaying == YES ) )
	{
		[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.podcast.busy" waitUntilDone:NO];
		return;
	}
	
	[self getPodcastName:url];
#if	!(TARGET_IPHONE_SIMULATOR)
	/*
	AppMobiDelegate *delegate = (AppMobiDelegate *) [[UIApplication sharedApplication] delegate];
	BOOL hasAnalytics = ([delegate hasAnalytics] && delegate._config.hasAnalytics);
	if( podcastName != nil && hasAnalytics == YES )
	{
		NSError *gerror;
		NSString *strLog = [NSString stringWithFormat:@"/appMobi.podcast.%@.start", podcastName];
		[[GANTracker sharedTracker] trackPageview:strLog withError:&gerror];
	}
	//*/
#endif
	
	if([myDelegate.viewController respondsToSelector:@selector(presentMoviePlayerViewControllerAnimated:)]){
		//3.2+
		MPMoviePlayerViewController *mpvc = [[[MPMoviePlayerViewController alloc] initWithContentURL:url] autorelease];
		videoPlayer = mpvc.moviePlayer;
		[myDelegate.viewController presentMoviePlayerViewControllerAnimated:mpvc];
	} else {
		//<3.2
		videoPlayer = [[MPMoviePlayerController alloc] initWithContentURL:url];
	}
	[videoPlayer play];
	// iResume = 0; -- erase previous cache for appMobi
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoFinishedCallback:) name:MPMoviePlayerPlaybackDidFinishNotification object:videoPlayer];
	[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.podcast.start" waitUntilDone:NO];
}

- (void)videoFinishedCallback:(NSNotification *)notification;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name: MPMoviePlayerPlaybackDidFinishNotification object:[notification object]];

	[videoPlayer stop];
	if ([myDelegate.viewController respondsToSelector:@selector(dismissMoviePlayerViewControllerAnimated)]) {
		//3.2+
		[myDelegate.viewController dismissMoviePlayerViewControllerAnimated];
	} else {
		//<3.2
		[videoPlayer release];
	}
	videoPlayer = nil;
	
#if	!(TARGET_IPHONE_SIMULATOR)
	/*
	AppMobiDelegate *delegate = (AppMobiDelegate *) [[UIApplication sharedApplication] delegate];
	BOOL hasAnalytics = ([delegate hasAnalytics] && delegate._config.hasAnalytics);
	if( podcastName != nil && hasAnalytics == YES )
	{
		NSError *gerror;
		NSString *strLog = [NSString stringWithFormat:@"/appMobi.podcast.%@.stop", podcastName];
		[[GANTracker sharedTracker] trackPageview:strLog withError:&gerror];
		[podcastName release];
		podcastName = nil;
	}
	//*/
#endif
	
	[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.podcast.stop" waitUntilDone:NO];
}

- (void)stationComplete:(id)sender
{
	[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.station.stop" waitUntilDone:NO];
}

- (void)shoutcastComplete:(id)sender
{
	[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.shoutcast.stop" waitUntilDone:NO];
}

- (AVAudioPlayer *)getPlayerFromPool:(NSString *)file {
    //get array of players
    NSMutableArray * players = [mySoundPool objectForKey:file];
    if (players == nil) {
        //create and add if needed
        players = [NSMutableArray arrayWithCapacity:1];
        [mySoundPool setObject:players forKey:file];
		
        //create, prepare and add player
        AppMobiWebView *webview = [[AppMobiViewController masterViewController] getActiveWebView];
		NSString *fullPath = [NSString stringWithFormat:@"%@/%@", webview.config.appDirectory, file];
        if( [[NSFileManager defaultManager] fileExistsAtPath:fullPath] == NO && [DirectCanvas instance].remotePath != nil )
        {
            fullPath = [NSString stringWithFormat:@"%@/%@", [DirectCanvas instance].remotePath, file];
        }
        
		NSData *data = [fullPath hasPrefix:@"http"] ? [NSData dataWithContentsOfURL:[NSURL URLWithString:fullPath]] : [NSData dataWithContentsOfFile:fullPath];
        
        if( data == nil || [data length] == 0 )
		{
			[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.sound.error" waitUntilDone:NO];
			return nil;
		}
		
        AVAudioPlayer *player = [[[AVAudioPlayer alloc] initWithData:data error:nil] autorelease];
        [player prepareToPlay];
        [players addObject:player];
    }
    
    //try get a player that isnt already playing
    AVAudioPlayer *player = nil;
    for(int i=0;i<[players count];i++) {
		player = [players objectAtIndex:i];
        if (player.playing == NO) {
            break;
        }
    }
	
    return player;
}

- (void)preloadPlayersIntoPool:(NSString *)file withCount:(int)count{
    //create array of players
    NSMutableArray * players = [NSMutableArray arrayWithCapacity:count];
	[mySoundPool setObject:players forKey:file];

	//create, prepare and add 
	//note that this overwrites any dynamically or previously created players in the pool
	AppMobiWebView *webview = [[AppMobiViewController masterViewController] getActiveWebView];
	NSString *fullPath = [NSString stringWithFormat:@"%@/%@", webview.config.appDirectory, file];
	if( [[NSFileManager defaultManager] fileExistsAtPath:fullPath] == NO && [DirectCanvas instance].remotePath != nil )
	{
		fullPath = [NSString stringWithFormat:@"%@/%@", [DirectCanvas instance].remotePath, file];
	}
	
	NSData *data = [fullPath hasPrefix:@"http"] ? [NSData dataWithContentsOfURL:[NSURL URLWithString:fullPath]] : [NSData dataWithContentsOfFile:fullPath];
	
	if( data == nil || [data length] == 0 )
	{
		[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.sound.error" waitUntilDone:NO];
	}

	for(int i=0;i<count;i++) {
		AVAudioPlayer *player = [[[AVAudioPlayer alloc] initWithData:data error:nil] autorelease];
		[player prepareToPlay];
		[players addObject:player];
	}
}

- (void)loadSound:(NSString *)file
{
    [self preloadPlayersIntoPool:file withCount:1];
}

- (void)loadSound:(NSString *)file withPolyphony:(int)count
{
    [self preloadPlayersIntoPool:file withCount:count];
}

- (void)unloadSound:(NSString *)file
{
    [mySoundPool removeObjectForKey:file];
}

- (void)unloadAllSounds
{
    [mySoundPool removeAllObjects];
}

- (void)playSound:(NSString *)file
{
	AVAudioPlayer *player = [self getPlayerFromPool:file];
	
	if( player != nil )
	{
		//we could add mode behavior here to add another player, restart or drop this request - for now we default to restart
		if( player.playing == NO )
		{
			[player play];
		}
		else
		{
			if(polyMaxMode == 0) {
				AMLog(@"all players busy for %@", file);
			} else {
				[player stop];
				[player play];
			}
		}
	}
}

- (void)startAudio:(NSString *)file withLooping:(BOOL)doesLoop
{
	if( videoPlayer != nil || ( myDelegate.myPlayer != nil && myDelegate.myPlayer.bPlaying == YES ) )
	{
		[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.audio.busy" waitUntilDone:NO];
		return;
	}
	
	if(adPlayer != nil) [self stopAudio];
	
	soundName = [file copy];
#if	!(TARGET_IPHONE_SIMULATOR)
	/*
	AppMobiDelegate *delegate = (AppMobiDelegate *) [[UIApplication sharedApplication] delegate];
	BOOL hasAnalytics = ([delegate hasAnalytics] && delegate._config.hasAnalytics);
	if( soundName != nil && hasAnalytics == YES )
	{
		NSError *gerror;
		NSString *strLog = [NSString stringWithFormat:@"/appMobi.audio.%@.start", soundName];
		[[GANTracker sharedTracker] trackPageview:strLog withError:&gerror];
	}
	//*/
#endif
	
    AppMobiWebView *webview = [[AppMobiViewController masterViewController] getActiveWebView];
	NSString *fullPath = [webview.config.appDirectory stringByAppendingPathComponent:file];
	NSData *data = [NSData dataWithContentsOfFile:fullPath];
	
	if( data == nil || [data length] == 0 )
	{
		[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.audio.error" waitUntilDone:NO];
		return;
	}
	
	NSError *aderr = nil;
	adPlayer = [[AVAudioPlayer alloc] initWithData:data error:&aderr];
	adPlayer.delegate = self;
	adPlayer.currentTime = audioCurrentTime;
	
	if(doesLoop)
	{
		adPlayer.numberOfLoops = -1;
	}
	
	[adPlayer play];
	
	[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.audio.start" waitUntilDone:NO];
}

- (void)setAudioCurrentTime:(float) time
{
	audioCurrentTime = time;
	if(adPlayer != nil) {
		adPlayer.currentTime = time;
	}
	
}

-(void)toggleAudio {
	if(adPlayer != nil) {
		adPlayer.playing?[adPlayer pause]:[adPlayer play];
	}
}

- (void)soundComplete
{	
#if	!(TARGET_IPHONE_SIMULATOR)
	/*
	AppMobiDelegate *delegate = (AppMobiDelegate *) [[UIApplication sharedApplication] delegate];
	BOOL hasAnalytics = ([delegate hasAnalytics] && delegate._config.hasAnalytics);
	if( soundName != nil && hasAnalytics == YES )
	{
		NSError *gerror;
		NSString *strLog = [NSString stringWithFormat:@"/appMobi.audio.%@.stop", soundName];
		[[GANTracker sharedTracker] trackPageview:strLog withError:&gerror];
		[soundName release];
		soundName = nil;
	}
	//*/
#endif
	
	[adPlayer release];
	adPlayer = nil;
	
	[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.audio.stop" waitUntilDone:NO];
}

-(void)stopAudio {
	if(adPlayer != nil) {
        [adPlayer stop];
		[self soundComplete];
	}
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
	[self soundComplete];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
	[self soundComplete];
}

- (void)audioPlayerEndInterruption:(AVAudioPlayer *)player
{
	[self soundComplete];
}

- (void)onSkipDone:(id)sender
{
	myPrev.enabled = YES;
	myNext.enabled = YES;
}

- (void)onWarning:(id)sender
{
	if( warning != nil ) [warning dismissWithClickedButtonIndex:0 animated:YES];
	warning = nil;
}

- (void)onAsking:(id)sender
{
	bAsking = NO;
	if( asking != nil ) [asking dismissWithClickedButtonIndex:0 animated:YES];
	asking = nil;
}

- (void)onFail:(id)sender
{
	if( myDelegate.myPlayer == nil ) return;
	[myLock tryLock];
	[myLock unlock];
	NSString *emessage = (NSString *)sender;
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Station Error" message:emessage delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
	[alert show];
	[alert release];
	[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onStop:) userInfo:nil repeats:NO];
}

- (void)onUnsupported:(id)sender
{
	if( myDelegate.myPlayer == nil ) return;
	[myLock tryLock];
	[myLock unlock];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Station Unavailable" message:@"Oops - the network cut out on you. Please try again later." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
	[alert show];
	[alert release];
}

- (void)onCantConnect:(id)sender
{
	if( myDelegate.myPlayer == nil ) return;
	[myLock tryLock];
	[myLock unlock];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connection Lost" message:@"Oops - the network cut out on you. Please try again later." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
	[alert show];
	[alert release];
	[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onStop:) userInfo:nil repeats:NO];
}

- (void)onStarving:(id)sender
{
	[myPlay setImage:myPlayImage forState:UIControlStateNormal];
	myPrev.enabled = NO;
	myNext.enabled = NO;
	myPlay.enabled = NO;
	
	if( ( warning == nil || bWarnPause == NO ) && bWarnBuffering == NO )
	{
		bWarnBuffering = YES;
		bWarnPause = YES;
		warning = [[UIAlertView alloc] initWithTitle:@"Audio Buffering" message:@"We have run out of buffered audio. Station will resume automatically." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[warning show];
		[NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(onWarning:) userInfo:nil repeats:NO];
	}
}

- (void)onBuffered:(id)sender
{
	if( warning != nil ) [warning dismissWithClickedButtonIndex:0 animated:YES];
	warning = nil;
	[myPlay setImage:myPauseImage forState:UIControlStateNormal];
	myPrev.enabled = YES;
	myNext.enabled = YES;
	myPlay.enabled = YES;
}

- (void)onPrev:(id)sender
{
	if( bWarnSkip == NO )
	{
		bWarnSkip = YES;
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setBool:bWarnSkip forKey:@"Skip"];
		[defaults synchronize];
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Skipping in Track" message:@"Rewinds/Advances 30 seconds inside the currently playing track." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
		[alert show];
		[alert release];
		return;
	}
	
	int count = 0;
	if( currentTracklist != nil ) count = [currentTracklist.children count];

	if( currentIndex >= 0 && currentIndex < count && count > 0 && myDelegate.myPlayer != nil )
	{
		myPrev.enabled = NO;
		myNext.enabled = NO;
		[myDelegate.myPlayer adjusttrack:-30];
	}
}

- (void)onNext:(id)sender
{
	if( bWarnSkip == NO )
	{
		bWarnSkip = YES;
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setBool:bWarnSkip forKey:@"Skip"];
		[defaults synchronize];
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Skipping in Track" message:@"Rewinds/Advances 30 seconds inside the currently playing track." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
		[alert show];
		[alert release];
		return;
	}
	
	int count = 0;
	if( currentTracklist != nil ) count = [currentTracklist.children count];

	if( currentIndex >= 0 && currentIndex < count && count > 0 && myDelegate.myPlayer != nil )
	{
		myPrev.enabled = NO;
		myNext.enabled = NO;
		[myDelegate.myPlayer adjusttrack:30];
	}
}

/*
- (void)onRecord:(id)sender
{
	if( bRecording == YES )
	{
		[myRecord setImage:[UIImage imageNamed:@"new_recordoff.png"] forState:UIControlStateNormal];
		bRecording = NO;
	}
	else
	{
		[myRecord setImage:[UIImage imageNamed:@"new_recordon.png"] forState:UIControlStateNormal];
		bRecording = YES;
	}
}
//*/

/*
- (void)onFavorite:(id)sender
{
	if( [currentNode.nodefav intValue] )
	{
		XMLNode *node = (XMLNode*) currentNode;
		XMLDirectoryReader *xmlParser = [[[XMLDirectoryReader alloc] init] autorelease];
		NSString *url = @"";
		
		if( node.nodeshout != nil )
			url = [[[NSString alloc] initWithFormat:@"http://%@%@?%@%@&FEED=DLFAV&SHOUT=%@&UID=%@", strServer, strCommand, strWhite, strSpeed, node.nodeshout, strUID] autorelease];
		else if( node.nodeid != nil && [node.nodeid length] == 6)
			url = [[[NSString alloc] initWithFormat:@"http://%@%@?%@%@&FEED=DLFAV&ID=%@&UID=%@", strServer, strCommand, strWhite, strSpeed, node.nodeid, strUID] autorelease];
		else if( node.nodeurl != nil )
			url = [[[NSString alloc] initWithFormat:@"http://%@%@?%@%@&FEED=DLFAV&URL=%@&UID=%@", strServer, strCommand, strWhite, strSpeed, node.nodeurl, strUID] autorelease];
		else if( node.nodename != nil )
			url = [[[NSString alloc] initWithFormat:@"http://%@%@?%@%@&FEED=DLFAV&TITLE=%@&UID=%@", strServer, strCommand, strWhite, strSpeed, [self urlencode:node.nodename], strUID] autorelease];
		[xmlParser parseXMLURL:url andKeepData:NO];
		currentNode.nodefav = @"0";
	}
	else
	{
		XMLNode *node = (XMLNode*) currentNode;
		XMLDirectoryReader *xmlParser = [[[XMLDirectoryReader alloc] init] autorelease];
		NSString *url = @"";
		
		if( node.nodeshout != nil )
			url = [[[NSString alloc] initWithFormat:@"http://%@%@?%@%@&FEED=ADFAV&SHOUT=%@&UID=%@", strServer, strCommand, strWhite, strSpeed, node.nodeshout, strUID] autorelease];
		else if( node.nodeid != nil && [node.nodeid length] == 6)
			url = [[[NSString alloc] initWithFormat:@"http://%@%@?%@%@&FEED=ADFAV&ID=%@&UID=%@", strServer, strCommand, strWhite, strSpeed, node.nodeid, strUID] autorelease];
		else if( node.nodeurl != nil )
			url = [[[NSString alloc] initWithFormat:@"http://%@%@?%@%@&FEED=ADFAV&URL=%@&UID=%@", strServer, strCommand, strWhite, strSpeed, node.nodeurl, strUID] autorelease];
		else if( node.nodename != nil )
			url = [[[NSString alloc] initWithFormat:@"http://%@%@?%@%@&FEED=ADFAV&TITLE=%@&UID=%@", strServer, strCommand, strWhite, strSpeed, [self urlencode:node.nodename], strUID] autorelease];
		[xmlParser parseXMLURL:url andKeepData:NO];
		currentNode.nodefav = @"1";
	}
	
	if( bShowFavorites ) favoritesViewController.bReload = YES;
	[myFavorite setImage:([currentNode.nodefav intValue]?[UIImage imageNamed:@"new_favon.png"]:[UIImage imageNamed:@"new_favoff.png"]) forState:UIControlStateNormal];
}
//*/

- (void)onStop:(id)sender
{
	if( bStarting == YES ) return;
	
	[myScroller.layer removeAllAnimations];
	myMetadata.text = @"";
	[myMetadata sizeToFit];
	currentNode.tracklist = nil;
	currentNode.nodeisJumping = NO;
	currentTracklist.cached = NO;
	adindex++;
	myCoverLeft6.image = nil;
	myCoverLeftMirror.image = nil;
	myCoverRight2.image = nil;
	myCoverRightMirror.image = nil;
	myCoverMirror.image = nil;
	[myCoverCenter setImage:nil forState:UIControlStateNormal];
	myPrev.enabled = NO;
	myNext.enabled = NO;
	myPlay.enabled = NO;
	mySleep.enabled = NO;
	//myShare.enabled = NO;
	myStop.enabled = NO;
	[busyView handleStop:nil];
	[self showBusy:NO withAd:NO];
	if( myDelegate.myPlayer != nil ) [myDelegate.myPlayer stopStream:self];
	do
	{
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
	} while ( myDelegate.myPlayer != nil && myDelegate.myPlayer.bPlaying && !myDelegate.myPlayer.bLingering );
	
#if	!(TARGET_IPHONE_SIMULATOR)
	/*
	AppMobiDelegate *delegate = (AppMobiDelegate *) [[UIApplication sharedApplication] delegate];
	BOOL hasAnalytics = ([delegate hasAnalytics] && delegate._config.hasAnalytics);
	if( hasAnalytics == YES && currentNode.nodeid != nil )
	{
		NSError *gerror;
		NSString *strLog = [NSString stringWithFormat:@"/appMobi.station.%d.stop", currentTracklist.stationid];
		[[GANTracker sharedTracker] trackPageview:strLog withError:&gerror];
	}
	if( hasAnalytics == YES && currentNode.nodeshout != nil )
	{
		NSError *gerror;
		NSString *strLog = [NSString stringWithFormat:@"/appMobi.shoutcast.%@.stop", currentNode.nodeshout];
		[[GANTracker sharedTracker] trackPageview:strLog withError:&gerror];
	}
	//*/
#endif
	[myDelegate.myPlayer release];
	myDelegate.myPlayer = nil;
	
	if( [currentTracklist.children count] > 0 )
	{
		XMLTrack *ttemp = (XMLTrack *) [currentTracklist.children objectAtIndex:[currentTracklist.children count]-1];
		if( ttemp.flylive == YES )
		{
			[currentTracklist.children removeLastObject];
		}
	}	
	
	if( bResumeMode == YES && bJunk == NO ) [self handleStop:currentTracklist];
	else [self deleteTracklist:currentTracklist];
	[currentTracklist release];
	currentTracklist = nil;
	[lastPlaying release];
	lastPlaying = nil;
	
	[[AppMobiViewController masterViewController] popPlayerView];
	[[AppMobiViewController masterViewController] pushWebView];
	//[[self navigationController] popViewControllerAnimated:YES];
	AudioSessionSetActive(NO);
}

- (void)onEmail:(id)sender
{
	XMLTrack *track = (XMLTrack *) [currentTracklist.children objectAtIndex:currentIndex];
	NSString *mediaurl = track.mediaurl;
	NSRange range = [mediaurl rangeOfString:@"//" options:NSCaseInsensitiveSearch];
	if( range.length > 0 )
	{
		mediaurl = [mediaurl substringFromIndex:range.location+2];
		range = [mediaurl rangeOfString:@"/" options:NSCaseInsensitiveSearch];
		if( range.length > 0 )
		{
			mediaurl = [mediaurl substringToIndex:range.location];
		}
	}
	
	XMLDirectoryReader *xmlParser = [[[XMLDirectoryReader alloc] init] autorelease];
	NSString *url = [NSString stringWithFormat:@"http://%@%@?%@%@&FEED=DEDICATE&UID=%@&ID=%d&PROXY=%@&SERVERUTC=%@",
					 strServer, strCommand, strWhite, strSpeed, strUID,
					 track.stationid, mediaurl, [self urlencode:track.starttime]];
	
	NSString *trackdesc = @"";
	if( track.artist != nil )
	{
		NSString *temp = [NSString stringWithFormat:@"&ARTIST=%@", [self urlencode:track.artist]];
		url = [url stringByAppendingString:temp];
		trackdesc = [trackdesc stringByAppendingString:track.artist];
	}
	if( track.title != nil )
	{
		NSString *temp = [NSString stringWithFormat:@"&SONG=%@", [self urlencode:track.title]];
		url = [url stringByAppendingString:temp];
		trackdesc = [trackdesc stringByAppendingString:@" - "];
		trackdesc = [trackdesc stringByAppendingString:track.title];
	}
	if( track.album != nil )
	{
		NSString *temp = [NSString stringWithFormat:@"&ALBUM=%@", [self urlencode:track.album]];
		url = [url stringByAppendingString:temp];
		trackdesc = [trackdesc stringByAppendingString:@" - "];
		trackdesc = [trackdesc stringByAppendingString:track.title];
	}
	
	//printf("EMAIL --- %s\r\n", [url cStringUsingEncoding:NSASCIIStringEncoding]);
	[xmlParser parseXMLURL:url andKeepData:NO];
	if( xmlParser.directory != nil && [xmlParser.directory.children count] == 1 )
	{
		XMLNode *node = (XMLNode *) [xmlParser.directory.children objectAtIndex:0];
		NSString *body = [NSString stringWithFormat:@"I was just listening to FlyCast Select and heard '%@'.\nJust click below in the next 6 hours and you can listen to it as well.\n%@", trackdesc, node.nodeurl];
		printf("BODY --- %s\r\n", [node.nodeurl cStringUsingEncoding:NSASCIIStringEncoding]);
		printf("BODY --- %s\r\n", [body cStringUsingEncoding:NSASCIIStringEncoding]);
		
		MFMailComposeViewController *controller = [[[MFMailComposeViewController alloc] init] autorelease];
		controller.mailComposeDelegate = self;
		[controller setSubject:@"Check out FlyCast Select!!"];
		[controller setMessageBody:body isHTML:NO];
		[[AppMobiViewController masterViewController] presentModalViewController:controller animated:YES];
	}
	else
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Email Failed" message:@"Please verify your connection." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
		[alert show];
		[alert release];
	}
}

/*
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if( buttonIndex == 0 )
	{
		XMLTrack *track = (XMLTrack *) [currentTracklist.children objectAtIndex:currentIndex];
		myShareView.mode = 1;
		myShareView.track = track;
		[[self navigationController] pushViewController:myShareView animated:YES];
	}
	else if( buttonIndex == 1 )
	{
		[self performSelectorOnMainThread:@selector(onEmail:) withObject:nil waitUntilDone:NO];
		//[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onEmail:) userInfo:nil repeats:NO];		
	}
	else if( buttonIndex == 2 )
	{
		[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onLove:) userInfo:nil repeats:NO];		
	}
	else if( buttonIndex == 3 )
	{
		[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onHate:) userInfo:nil repeats:NO];		
	}
}
//*/

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
	[[AppMobiViewController masterViewController] becomeFirstResponder];
	[[AppMobiViewController masterViewController] dismissModalViewControllerAnimated:YES];
}

- (void)onShare:(id)sender
{
	/*
	shareindex = currentIndex;
	UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Share This Track" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil
													otherButtonTitles:@"Tweet This Track", @"Email This Track", @"Love This Track", @"Hate This Track", nil];
	actionSheet.actionSheetStyle = UIActionSheetStyleDefault;
	[actionSheet showInView:[[UIApplication sharedApplication] keyWindow]];
	[actionSheet release];
	//*/
}

- (void)onTimer:(id)sender
{
	if( bSleeping == NO ) return;
	
	sleeptimer--;
	
	if( sleeptimer == 0 )
	{
		[mySleep setImage:mySleepImage forState:UIControlStateNormal];
		[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onStop:) userInfo:nil repeats:NO];		
	}
	else
	{	
		[NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(onTimer:) userInfo:nil repeats:NO];
	}
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if( bAsking == YES )
	{
		currentNode.nodeisJumping = YES;
		bAsking = NO;
		myCoverCenter.enabled = NO;
		[NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(onGoLive:) userInfo:nil repeats:NO];
		return;
	}
	
	if( bSleeping == YES && buttonIndex == 1 )
	{
		bSleeping = NO;
		sleeptimer = 0;
		[mySleep setImage:mySleepImage forState:UIControlStateNormal];
		return;
	}
	else if( bSleeping == NO && buttonIndex > 0 )
	{
		bSleeping = YES;
		if( buttonIndex == 3 )
			sleeptimer = 45;
		else if( buttonIndex == 2 )
			sleeptimer = 30;
		else if( buttonIndex == 1 )
			sleeptimer = 15;
		[mySleep setImage:mySleepOnImage forState:UIControlStateNormal];
		[NSTimer scheduledTimerWithTimeInterval:60.0 target:self selector:@selector(onTimer:) userInfo:nil repeats:NO];
	}
}

- (void)onBack:(id)sender
{
	[[AppMobiViewController masterViewController] popPlayerView];
	[[AppMobiViewController masterViewController] pushWebView];	
}

- (void)onSleep:(id)sender
{
	if( bSleeping == YES )
	{
		NSString *amessage = [NSString stringWithFormat:@"%d minutes until shutoff. Hit Stop to stop timer.", sleeptimer];
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Stop Sleep Timer" message:amessage delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Stop", nil];
		[alert show];
		[alert release];		
	}
	else
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Start Sleep Timer" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"15 minutes", @"30 minutes", @"45 minutes", nil];
		[alert show];
		[alert release];		
	}	
}

- (void)onDelete:(id)sender
{}

- (void)onShuffle:(id)sender
{
}

- (NSMutableArray *)parsePlaylist:(NSString *)playlist
{
	NSMutableArray *mirrors = [[[NSMutableArray alloc] init] autorelease];
	NSArray *listItems = [playlist componentsSeparatedByString:@"\n"];
	int index = 1;
	for( int i = 0; i < listItems.count; i++ )
	{
		NSString *strtemp = [listItems objectAtIndex:i];
		NSString *searcher = [[[NSString alloc] initWithFormat:@"File%d=", index] autorelease];
		NSRange range = [strtemp rangeOfString:searcher options:NSCaseInsensitiveSearch];
		if( range.length == [searcher length] )
		{
			index++;
			[mirrors addObject:[strtemp  substringFromIndex:range.location+range.length]];
		}
	}

	return mirrors;
}

- (void)podcastComplete:(id)sender
{
	if( loopingOn == NO )
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Podcast Complete" message:@"The podcast you were listening to has finished." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
		[alert show];
		[alert release];
	}
}

- (void)onTooLong:(id)sender
{
	bAsking = YES;
	asking = [[UIAlertView alloc] initWithTitle:@"Go Live Now?" message:@"It's been too long and we are no longer able to resume this station. We will play what you already have cached. Click below to move playback to live." delegate:self cancelButtonTitle:nil otherButtonTitles:@"Go Live Now", nil];
	[asking show];
	[NSTimer scheduledTimerWithTimeInterval:7.0 target:self selector:@selector(onAsking:) userInfo:nil repeats:NO];
}

- (void)addGoLive:(id)sender
{
	XMLTrack *temp = [[[XMLTrack alloc] init] autorelease];
	temp.listened = YES;
	temp.artist = currentTracklist.station;
	temp.title = @"Jump back to Live";
	temp.stationid = currentTracklist.stationid;
	temp.bitrate = currentTracklist.bitrate;
	temp.timecode = CFAbsoluteTimeGetCurrent();
	temp.flylive = YES;
	temp.expdays = currentTracklist.expdays;
	temp.expplays = currentTracklist.expplays;
	temp.guidSong = [[[NSString alloc] initWithFormat:@"%f", temp.timecode] autorelease];
	[currentTracklist.children addObject:temp];
}

- (void)showBusy:(BOOL)show withAd:(BOOL)ad
{
	if( show == YES )
	{
		[[AppMobiViewController masterViewController].view addSubview:busyView];
		UIInterfaceOrientation orient = [AppMobiViewController masterViewController].interfaceOrientation;
		[busyView resetView:(orient == UIInterfaceOrientationLandscapeLeft || orient == UIInterfaceOrientationLandscapeRight )];
	}
	else
	{
		busyView.adView.hidden = YES;
		[busyView removeFromSuperview];
	}
}

- (void)clearResume
{
	while( allTracklists != nil && [allTracklists count] > 0 )
	{
		XMLTracklist *tltemp = (XMLTracklist *) [allTracklists objectAtIndex:0];
		[tltemp retain];
		[allTracklists removeObjectAtIndex:0];
		[self deleteTracklist:tltemp];
		[tltemp release];
	}
	iResume = 0;
}

- (void)queueNextNode:(XMLNode *)node
{
	if( myBackground == nil ) [self createViews:nil];
	//node.nodeid = @"224812";
	bStarting = YES;
	adindex++;
	bWarnBuffering = NO;
	myPrev.enabled = NO;
	myNext.enabled = NO;
	myPlay.enabled = NO;	
	myCoverCenter.enabled = YES;
	mySleep.enabled = YES;
	//myShare.enabled = YES;
	myRecord.enabled = YES;
	myStop.enabled = YES;
	myCoverCurrent.enabled = NO;
	myCoverMirror.image = nil;
	myCoverLeftMirror.image = nil;
	myCoverRightMirror.image = nil;
	[myPlay setImage:myPauseImage forState:UIControlStateNormal];
	if( node.tracklist != nil ) myRecord.enabled = (node.tracklist.offline == NO);
	if( node.nodeid != nil && node.nodeisJumping == NO && myDelegate.myPlayer != nil && myDelegate.myPlayer.bPlaying && ( iResume == [node.nodeid intValue] ) )
	{
		bStarting = NO;
		return;
	}
	
	if( node.tracklist != nil && ( node.tracklist.podcasting == YES || node.tracklist.video == YES ) )
	{
		currentTracklist = node.tracklist;
		currentIndex = node.tracklist.startindex;
		//[self performSelectorOnMainThread:@selector(repaint:) withObject:nil waitUntilDone:NO];
		//[NSThread detachNewThreadSelector:@selector(podcastWorker:) toTarget:self withObject:node.tracklist];
	}	
	else if( iResume > 0 && bResumeMode == YES && node.nodeid != nil && allTracklists != nil && [allTracklists count] > 0 && [node.nodeid intValue] == iResume )
	{
		XMLTracklist *tltemp = (XMLTracklist *) [allTracklists objectAtIndex:0];
		XMLTrack *tttemp = nil;
		[tltemp retain];
		[allTracklists removeObjectAtIndex:0];
		node.tracklist = tltemp;

		double timecode = CFAbsoluteTimeGetCurrent();
		double lasttime = tltemp.timecode;
		if( [tltemp.children count] > 0 )
		{
			tttemp = (XMLTrack *) [tltemp.children objectAtIndex:[tltemp.children count]-1];
			lasttime = tttemp.timecode;
		}
		long seconds = timecode - lasttime;
		if( bOffline == NO && seconds > ( 5 * 60 * 60 ) ) // 5 hours
		{
			node.tracklist = tltemp;
			currentTracklist = node.tracklist;
			currentIndex = node.tracklist.startindex;
			
			tltemp.cached = YES;
			[self addGoLive:nil];
			[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onTooLong:) userInfo:nil repeats:NO];
		}
		else
		{
			node.tracklist = tltemp;
			currentTracklist = node.tracklist;
			currentIndex = node.tracklist.startindex;
			
			if( bOffline == NO && currentTracklist.autoshuffle == NO && seconds > ( 35 * 60 ) ) // 35 minutes
			{
				[self addGoLive:nil];
			}
			else if( bOffline == NO && currentTracklist.saved == YES )
			{
				[self addGoLive:nil];
			}
		}
	}
	else if( bOffline == NO && [allTracklists count] > 0 )
	{
		while( [allTracklists count] > 0 )
		{
			XMLTracklist *tltemp = (XMLTracklist *) [allTracklists objectAtIndex:0];
			[tltemp retain];
			[allTracklists removeObjectAtIndex:0];
			[self deleteTracklist:tltemp];
			[tltemp release];
		}
	}
	
	bAsking = NO;
	//[self showBusy:YES withAd:NO];
	[myNodeQueue addObject:node];
	
	myMetadata.text = @"... Connecting to Station ...";
	[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(resolveNextNode:) userInfo:nil repeats:NO];
}

- (int)getBitrate:(NSString* )url
{
	int gbitrate = 128;

	NSRange range = [url rangeOfString:@"BITRATE=" options:NSCaseInsensitiveSearch];
	if( range.length == 8 )
	{
		gbitrate = [[url substringFromIndex:range.location + range.length] intValue];
	}

	return gbitrate;
}

- (XMLTracklist *)shuffleTracklist:(XMLTracklist *)tracklist withShuffle:(BOOL)shuffle andHide:(BOOL)hide
{
	if( tracklist == nil ) return nil;
	
	XMLTracklist *shuffledTracks = [[XMLTracklist alloc] init];
	[shuffledTracks copy:tracklist];
	shuffledTracks.shuffled = YES;
	
	for( int i = 0; i < [tracklist.children count]; i++ )
	{
		XMLTrack *temp = (XMLTrack *) [tracklist.children objectAtIndex:i];
		if( hide == YES ) temp.listened = NO;
		if( hide == YES ) temp.played = NO;
		[shuffledTracks.children addObject:temp];
	}
	
	if( shuffle == NO ) return shuffledTracks;
	
	int size = [shuffledTracks.children count];
	for( int j = 0; j < 3; j++ )
	{
		for( int i = 0; i < size-1; i++ )
		{
			int xabs  = abs(rand());
			int mod  = xabs % (size - i);
			int swap = i + mod;
			
			XMLTrack *temp1 = (XMLTrack *) [shuffledTracks.children objectAtIndex:i];
			XMLTrack *temp2 = (XMLTrack* ) [shuffledTracks.children objectAtIndex:swap];
			[shuffledTracks.children removeObjectAtIndex:i];
			[shuffledTracks.children insertObject:temp2 atIndex:i];
			[shuffledTracks.children removeObjectAtIndex:swap];
			[shuffledTracks.children insertObject:temp1 atIndex:swap];
		}
	}
	
	return shuffledTracks;
}

- (void)prerollError:(id)sender
{
	/*
	if( NO && sender != nil )
	{
		myWebBrowser.openURL = audioad.strClickURL;
		[[self navigationController] pushViewController:myWebBrowser animated:YES];
	}
	//*/
	
	[self showBusy:NO withAd:NO];
	if( audioad != nil && [audioad retainCount] == 1 ) [audioad release];
	audioad = nil;
}

- (void)prerollDone:(id)sender
{
	/*
	printf("pvc prerollDone\n");
	CachedAd *ad = (CachedAd *)sender;
	if( ad.clicked == YES )
	{
		myWebBrowser.openURL = audioad.strClickURL;
		[[self navigationController] pushViewController:myWebBrowser animated:YES];
		[myApp showBusy:NO withAd:NO];
	}
	//*/
	
	if( audioad != nil && [audioad retainCount] == 1 ) [audioad release];
	audioad = nil;
}

- (void)popupDone:(id)sender
{
	printf("pvc popupDone\n");
	CachedAd *ad = (CachedAd *)sender;
	/*
	if( ad.clicked == YES )
	{
		myWebBrowser.openURL = ad.strClickURL;
		[[self navigationController] pushViewController:myWebBrowser animated:YES];
	}
	//*/
	
	if( currentTracklist != nil && currentTracklist.adpopupzone != nil )
	{
		Version *vers = [[Version alloc] init];
		vers.number = ad.number;
		int freq = [currentTracklist.adpopupfreq intValue];
		[NSTimer scheduledTimerWithTimeInterval:freq target:self selector:@selector(checkPopup:) userInfo:vers repeats:NO];
	}

	[self showBusy:NO withAd:NO];
	bPopup = NO;
}

- (void)adjustVolume:(int)incr
{
	if( myDelegate.myPlayer == nil ) return;
	
	fVolume = ((float) incr / 100.0);
	if( fVolume > 1.0 ) fVolume = 1.0;
	if( fVolume < 0.0 ) fVolume = 0.0;
	[myDelegate.myPlayer adjustVolume:fVolume];
}

- (BOOL)isHiding
{
	return self.hidden;
}

- (void)interDone:(id)sender
{
	printf("pvc interDone\n");
	CachedAd *ad = (CachedAd *)sender;
	/*
	if( ad.clicked == YES )
	{
		myWebBrowser.openURL = ad.strClickURL;
		[[self navigationController] pushViewController:myWebBrowser animated:YES];
	}
	//*/
	
	if( currentTracklist != nil && currentTracklist.adinterzone != nil )
	{
		Version *vers = [[Version alloc] init];
		vers.number = ad.number;
		int freq = [currentTracklist.adinterfreq intValue];
		[NSTimer scheduledTimerWithTimeInterval:freq target:self selector:@selector(checkInterstitial:) userInfo:vers repeats:NO];
	}
	
	[self showBusy:NO withAd:NO];
	bInter = NO;
}

- (void)fillAdZones:(XMLTracklist *)tracklist fromNode:(XMLNode *)node
{	
	tracklist.adbannerzone = node.adbannerzone;
	tracklist.adbannerwidth = node.adbannerwidth; 
	tracklist.adbannerheight = node.adbannerheight;
	tracklist.adbannerfreq = node.adbannerfreq;
	tracklist.adprerollzone = node.adprerollzone; 
	tracklist.adprerollwidth = node.adprerollwidth;
	tracklist.adprerollheight = node.adprerollheight; 
	tracklist.adprerollfreq = node.adprerollfreq; 
	tracklist.adpopupzone = node.adpopupzone;
	tracklist.adpopupwidth = node.adpopupwidth;
	tracklist.adpopupheight = node.adpopupheight; 
	tracklist.adpopupfreq = node.adpopupfreq;
	tracklist.adinterzone = node.adinterzone;
	tracklist.adinterwidth = node.adinterwidth;
	tracklist.adinterheight = node.adinterheight; 
	tracklist.adinterfreq = node.adinterfreq;
	tracklist.adsignupzone = node.adsignupzone;
	tracklist.adsignupwidth = node.adsignupwidth;
	tracklist.adsignupheight = node.adsignupheight; 
	tracklist.adsignupfreq = node.adsignupfreq;
}

- (void)resolveNextNode:(id)sender
{
	if( [myNodeQueue count] == 0 ) return;
	XMLNode *curnode = (XMLNode *) [myNodeQueue objectAtIndex:0];
	[myNodeQueue removeObjectAtIndex:0];
	[myLock lock];

	NSMutableArray *mirrors = nil;
	XMLTracklist *tracklist = nil;
	NSDate *ref = [NSDate date];
	BOOL bShoutcast = NO;
	BOOL bDone = NO;
	BOOL bTime = NO;
	BOOL bError = NO;
	bJunk = NO;
	audioad = nil;

	do
	{
		loopingOn = NO;
		loopingIndex = -1;
		if( curnode.tracklist != nil )
		{
			currentNode = curnode;
			tracklist = curnode.tracklist;
			if( NO && ( tracklist.autohide == YES || tracklist.autoshuffle == YES ) )
			{
				tracklist = [self shuffleTracklist:tracklist withShuffle:tracklist.autoshuffle andHide:tracklist.autohide];
			}
			if( tracklist.offline == NO )
			{
				for( int i = [tracklist.children count] - 1; i >= 0; i-- )
				{
					XMLTrack *temp = (XMLTrack *) [tracklist.children objectAtIndex:i];
					if( ( temp.albumfile != nil || temp.imageurl != nil ) && temp.original == nil )
						[NSThread detachNewThreadSelector:@selector(coverWorker:) toTarget:self withObject:temp];
					if( bOffline == YES || tracklist.cached == YES )
					{
						if( temp.flyback == YES )
						{
							tracklist.startindex--;
							[tracklist.children removeObjectAtIndex:i];
						}
						else if( temp.current == temp.offset && temp.flylive == NO )
						{
							[tracklist.children removeObjectAtIndex:i];
							if( tracklist.startindex >= i ) tracklist.startindex--;
						}
						else if( temp.flylive == NO )
						{
							temp.length = temp.current - temp.offset;
							temp.buffered = YES;
							temp.cached = YES;
						} 
					}
				}
			}
			if( bOffline == YES || tracklist.cached == YES )
			{
				tracklist.saved = YES;
				tracklist.timecode = CFAbsoluteTimeGetCurrent() - ( 60 * 60 * 24 );
				
				if( tracklist.startindex <= [tracklist.children count] )
				{
					XMLTrack *temp = (XMLTrack *) [tracklist.children objectAtIndex:tracklist.startindex];
					if( temp.roffset == temp.length )
					{
						temp.roffset -= ( tracklist.bitrate * 128 * 8 ); // back up 8 seconds
						
						if( temp.roffset < 0 )
						{
							temp.roffset = 0;
						}
					}
				}
			}
			
			//strID = [NSString stringWithFormat:@"%d", tracklist.stationid];
			iResume = tracklist.stationid;
			//strSID = @"";
			//strRate = [NSString stringWithFormat:@"%d", tracklist.bitrate];
			//strURL = @"";
			//strTitle = [myApp urlencode:tracklist.station];
		}
		else if( curnode.nodeshout != nil )
		{
			NSRange range = [curnode.nodeshout rangeOfString:@".pls"];
			bShoutcast = YES;
			currentNode = curnode;
			
			if( range.length == 0 )
			{
				mirrors = [[[NSMutableArray alloc] init] autorelease];
				[mirrors addObject:curnode.nodeshout];
			}
			else
			{					
				NSURLResponse *response;
				NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:curnode.nodeshout] cachePolicy:NSURLCacheStorageNotAllowed timeoutInterval:5];
				[urlRequest setValue:@"WinampMPEG/5.35" forHTTPHeaderField:@"User-Agent"];
				NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:nil];
				mirrors = nil;
				if( data != nil )
				{
					NSString *servers = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
					mirrors = [self parsePlaylist:servers];
				}
			}
			
			if( mirrors == nil || [mirrors count] == 0 )
			{
				bError = YES;
				continue;
			}

			tracklist = [[XMLTracklist alloc] init];
			double timecode = CFAbsoluteTimeGetCurrent();
			tracklist.children = [[[NSMutableArray alloc] init] autorelease];
			tracklist.startindex = 0;
			tracklist.shoutcasting = YES;
			tracklist.continuing = YES;
			tracklist.station = curnode.nodename;
			tracklist.stationid = 0;
			tracklist.timecode = timecode;
			tracklist.shuffleable = NO;
			for( int i = 0; i < [mirrors count]; i++ )
			{
				XMLTrack *temp = [[[XMLTrack alloc] init] autorelease];
				temp.stationid = 0;
				temp.bitrate = 128;
				temp.mediaurl = (NSString *) [mirrors objectAtIndex:i];
				temp.mediatype = @"audio/mpeg";
				temp.timecode = timecode + ((float)rand()/10000.0);
				temp.guidIndex = [NSString stringWithFormat:@"%f", timecode];
				temp.guidSong = temp.guidIndex;
				temp.artist = curnode.nodename;
				temp.length = temp.bitrate * 128 * 60 * 30;
				temp.listened = YES;
				//temp.album = [NSString stringWithFormat:@"Proxy %d",(i + 1)];
				[tracklist.children addObject:temp];
		   }

			//strID = @"";
			iResume = 0;
			//strSID = @"";
			//strRate = @"128";
			//strURL = [myApp urlencode:curnode.nodeshout];
			//strTitle = [myApp urlencode:curnode.nodename];
		}
		else if( curnode.nodeid != nil )
		{
			XMLDirectoryReader *xmlParser = [[[XMLDirectoryReader alloc] init] autorelease];
			NSString *url = [[[NSString alloc] initWithFormat:@"http://%@%@?%@%@&FEED=PLAY&ID=%@&UID=%@", strServer, strCommand, strWhite, strSpeed, curnode.nodeid, strUID] autorelease];
			printf(" CLIENT SERVICES URL --- %s\r\n", [url cStringUsingEncoding:NSASCIIStringEncoding]);
			[xmlParser parseXMLURL:url andKeepData:NO];
			if( xmlParser.directory == nil || [xmlParser.directory.children count] == 0 )
			{
				bError = YES;
				/*
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Problem Connecting" message:@"We're sorry but we were unable to connect to this station. Please try another station or verify your connection in Settings." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
				[alert show];
				[alert release];
				//*/
				continue;
			}

			currentNode = (XMLNode *) [xmlParser.directory.children objectAtIndex:0];
			currentNode.nodeadindex = adindex;
			tracklist = [[XMLTracklist alloc] init];
			double timecode = CFAbsoluteTimeGetCurrent();
			int tbitrate = [self getBitrate:currentNode.nodeurl];
			tracklist.children = [[[NSMutableArray alloc] init] autorelease];
			tracklist.startindex = [xmlParser.directory.children count] - 1;
			tracklist.flycasting = YES;
			tracklist.continuing = YES;
			tracklist.station = currentNode.nodename;
			tracklist.session = currentNode.nodesid;
			tracklist.banner = currentNode.nodebanner;
			tracklist.stationid = [[currentNode.nodeid substringToIndex:6] intValue];
			tracklist.timecode = timecode;
			tracklist.bitrate = tbitrate;
			tracklist.expdays = currentNode.nodeexpdays;
			tracklist.expplays = currentNode.nodeexpplays;
			tracklist.bannerfreq = currentNode.nodebannerfreq;
			tracklist.interfreq = currentNode.nodeinterfreq;
			tracklist.shuffleable = ( currentNode.nodeallowshuffle == 1 );
			tracklist.deleteable = ( currentNode.nodeallowdelete == 1 );
			tracklist.autoshuffle = ( currentNode.nodeautoshuffle == 1 );
			tracklist.autohide = ( currentNode.nodeautohide == 1 );
			tracklist.imageurl = currentNode.nodeicon;			

			for( int i = 0; i < [xmlParser.directory.children count]; i++ )
			{
				XMLNode *node = (XMLNode *) [xmlParser.directory.children objectAtIndex:i];
				if( i == 0 ) [self fillAdZones:tracklist fromNode:node];
				XMLTrack *temp = [[[XMLTrack alloc] init] autorelease];
				temp.stationid = tracklist.stationid;
				temp.bitrate = tbitrate;
				temp.mediaurl = node.nodeurl;
				temp.timecode = timecode;
				temp.flyback = node.nodeisFlyBack;
				temp.expdays = tracklist.expdays;
				temp.expplays = tracklist.expplays;
				temp.guidSong = [[[NSString alloc] initWithFormat:@"%f", timecode] autorelease];
				if( temp.flyback == YES )
				{
					temp.listened = YES;
					temp.artist = tracklist.station;
					temp.title = node.nodename;
				}
				[tracklist.children insertObject:temp atIndex:0];
			}

			//strID = [NSString stringWithString:curnode.nodeid];
			iResume = [curnode.nodeid intValue];
			//strSID = [myApp getKey:@"SID" fromURL:currentNode.nodeurl];
			//strRate = [myApp getKey:@"BITRATE" fromURL:currentNode.nodeurl];
			//strURL = @"";
			//strTitle = [myApp urlencode:currentNode.nodename];
		}
		else if( curnode.nodeurl != nil )
		{
			currentNode = curnode;			
			mirrors = [[[NSMutableArray alloc] init] autorelease];
			[mirrors addObject:currentNode.nodeurl];
			
			tracklist = [[XMLTracklist alloc] init];
			double timecode = CFAbsoluteTimeGetCurrent();
			tracklist.children = [[[NSMutableArray alloc] init] autorelease];
			tracklist.startindex = 0;
			tracklist.podcasting = YES;
			tracklist.continuing = YES;
			tracklist.station = curnode.nodename;
			tracklist.stationid = 0;
			tracklist.timecode = timecode;
			tracklist.shuffleable = NO;
			for( int i = 0; i < [mirrors count]; i++ )
			{
				XMLTrack *temp = [[[XMLTrack alloc] init] autorelease];				
				temp.stationid = 0;
				temp.bitrate = 128;
				temp.imageurl = currentNode.nodeimg;
				temp.mediaurl = (NSString *) [mirrors objectAtIndex:i];
				temp.mediatype = @"audio/mpeg";
				temp.timecode = timecode + ((float)rand()/10000.0);
				temp.guidIndex = [NSString stringWithFormat:@"%f", timecode];
				temp.guidSong = temp.guidIndex;
				temp.artist = curnode.nodename;
				temp.length = 117964800;
				temp.listened = YES;
				temp.title = [currentNode.nodename copy];
				[tracklist.children addObject:temp];
			}

			//strID = @"";
			iResume = 0;
			//strSID = [myApp getKey:@"SID" fromURL:currentNode.nodeurl];
			//strRate = [myApp getKey:@"BITRATE" fromURL:currentNode.nodeurl];
			//strURL = [myApp urlencode:currentNode.nodeurl];
			//strTitle = [myApp urlencode:currentNode.nodename];
			//if( currentNode.nodeurlid != nil )
			//	strID = currentNode.nodeurlid;
		}
		
		AppMobiDelegate *delegate = (AppMobiDelegate *) [[UIApplication sharedApplication] delegate];
#if	!(TARGET_IPHONE_SIMULATOR)
		/*
		BOOL hasAnalytics = ([delegate hasAnalytics] && delegate._config.hasAnalytics);
		if( hasAnalytics == YES && currentNode.nodeid != nil )
		{
			NSError *gerror;
			NSString *strLog = [NSString stringWithFormat:@"/appMobi.station.%d.play", tracklist.stationid];
			[[GANTracker sharedTracker] trackPageview:strLog withError:&gerror];
		}
		if( hasAnalytics == YES && currentNode.nodeshout != nil )
		{
			NSError *gerror;
			NSString *strLog = [NSString stringWithFormat:@"/appMobi.shoutcast.%@.play", currentNode.nodeshout];
			[[GANTracker sharedTracker] trackPageview:strLog withError:&gerror];
		}
		//*/
#endif
		tracklist.adindex = adindex;	
		currentTracklist = tracklist;
		currentIndex = tracklist.startindex;
		if( delegate.bShowAds == YES && tracklist.adpopupzone != nil && [tracklist.adpopupzone length] > 0 )
		{
			Version *vers = [[Version alloc] init];
			vers.number = adindex;
			int freq = [tracklist.adpopupfreq intValue];
			[NSTimer scheduledTimerWithTimeInterval:freq target:self selector:@selector(checkPopup:) userInfo:vers repeats:NO];
		}
		if( delegate.bShowAds == YES && tracklist.adinterzone != nil && [tracklist.adinterzone length] > 0 )
		{
			Version *vers = [[Version alloc] init];
			vers.number = adindex;
			int freq = [tracklist.adinterfreq intValue];
			[NSTimer scheduledTimerWithTimeInterval:freq target:self selector:@selector(checkInterstitial:) userInfo:vers repeats:NO];
		}
		if( NO && audioad == nil && tracklist.adprerollzone != nil && [tracklist.adprerollzone length] > 0 )
		{
			audioad = [self checkPreroll:tracklist];
		}
		if( audioad != nil )
		{		
			if( myDelegate.myPlayer != nil && myDelegate.myPlayer.bPlaying == YES )
			{
				myDelegate.myPlayer.bLinger = NO;
				[myDelegate.myPlayer stopStream:self];
			}
			
			do
			{
				CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
			} while ( myDelegate.myPlayer != nil && myDelegate.myPlayer.bPlaying && !myDelegate.myPlayer.bLingering );
			[myDelegate.myPlayer release];
			myDelegate.myPlayer = nil;
			
			if( audioad.googleaudio == NO )
				[busyView preroll:audioad];
			else
				[busyView performSelectorOnMainThread:@selector(googleaudio:) withObject:audioad waitUntilDone:NO];
				//[NSTimer scheduledTimerWithTimeInterval:0.0 target:busyView selector:@selector(googleaudio:) userInfo:nil repeats:NO];
		}

		if( [[NSDate date] timeIntervalSinceDate:ref] > myStartupTimeout ) bTime = YES;
		if( bTime ) continue;

		if( myDelegate.myPlayer != nil && myDelegate.myPlayer.bPlaying == YES )
		{
			myDelegate.myPlayer.bLinger = YES;
			[myDelegate.myPlayer stopStream:self];
		}

		do
		{
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
			if( [[NSDate date] timeIntervalSinceDate:ref] > myStartupTimeout ) bTime = YES;
		} while ( myDelegate.myPlayer != nil && myDelegate.myPlayer.bPlaying && !myDelegate.myPlayer.bLingering && !bTime );
		if( bTime ) continue;
		
		do
		{
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
		} while ( audioad != nil );	
		if( bTime ) continue;

		myDelegate.nextPlayer = [[Player alloc] init];
		myDelegate.nextPlayer.node = currentNode;
		myDelegate.nextPlayer.bPaused = YES;
		if( myDelegate.myPlayer != nil ) myDelegate.nextPlayer.fVolume = myDelegate.myPlayer.fVolume;
		else myDelegate.nextPlayer.fVolume = fVolume;
		[myDelegate.nextPlayer startStream:[tracklist retain] withType:bShoutcast];
		myPrev.enabled = YES;
		myNext.enabled = YES;
		myPlay.enabled = YES;

		do
		{
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
			if( [[NSDate date] timeIntervalSinceDate:ref] > myStartupTimeout ) bTime = YES;
			bError = myDelegate.nextPlayer.bError;
		} while ( !myDelegate.nextPlayer.bReady && !bTime && !bError );
		if( bTime || bError ) continue;

		if( myDelegate.myPlayer != nil )
		{
			myDelegate.myPlayer.bLinger = NO;
		}

		do
		{
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
			if( [[NSDate date] timeIntervalSinceDate:ref] > myStartupTimeout ) bTime = YES;
		} while ( myDelegate.myPlayer != nil && myDelegate.myPlayer.bPlaying == YES  && !bTime );
		if( bTime ) continue;

		myDelegate.nextPlayer.bPaused = NO;
		[myDelegate.myPlayer release];
		myDelegate.myPlayer = myDelegate.nextPlayer;
		myDelegate.nextPlayer = nil;
		bDone = YES;
	} while( !bDone && !bTime && !bError );
	
	if( oldTracklist != nil )
	{
		[oldTracklist release];
		oldTracklist = nil;
	}

	if( bTime || bError )
	{
		currentNode = nil;
		if( myDelegate.nextPlayer != nil )
		{
			myDelegate.nextPlayer.bLinger = NO;
			[myDelegate.nextPlayer stopStream:self];

			bTime = NO;
			ref = [NSDate date];
			do
			{
				CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
				if( [[NSDate date] timeIntervalSinceDate:ref] > 5.0 ) bTime = YES;
			} while ( myDelegate.nextPlayer != nil && myDelegate.nextPlayer.bPlaying == YES && !bTime );
			[myDelegate.nextPlayer release];
			myDelegate.nextPlayer = nil;
		}
		if( myDelegate.myPlayer != nil && myDelegate.myPlayer.bStopping )
		{
			myDelegate.myPlayer.bLinger = NO;

			bTime = NO;
			ref = [NSDate date];
			do
			{
				CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
				if( [[NSDate date] timeIntervalSinceDate:ref] > 5.0 ) bTime = YES;
			} while ( myDelegate.myPlayer != nil && myDelegate.myPlayer.bPlaying == YES && !bTime );
			[myDelegate.myPlayer release];
			myDelegate.myPlayer = nil;
		}

		if( bError || bTime )
		{
			bJunk = YES;
			UIAlertView *alert = nil;
			if( bShoutcast == YES )
				alert = [[UIAlertView alloc] initWithTitle:@"Problem Connecting" message:@"This Shoutcast station is temporarily not available. Please verify your internet connection and try again later." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
			else
				alert = [[UIAlertView alloc] initWithTitle:@"Problem Connecting" message:@"This station is temporarily not available. Please verify your internet connection and try again later." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
			[alert show];
			[alert release];
			bStarting = NO;
			[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onStop:) userInfo:nil repeats:NO];
		}
		if( curnode.nodeid != nil ) [[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.station.error" waitUntilDone:NO];
		if( curnode.nodeshout != nil ) [[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.shoutcast.error" waitUntilDone:NO];
	}
	else
	{
		if( curnode.nodeid != nil ) [[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.station.start" waitUntilDone:NO];
		if( curnode.nodeshout != nil ) [[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.shoutcast.start" waitUntilDone:NO];
	}
	
	//myThumbsup.hidden = (tracklist.offline == YES);
	//myThumbsdown.hidden = (tracklist.offline == YES);
	//myDelete.hidden = (tracklist.offline == NO);		
	//myShuffle.hidden = (tracklist.offline == NO);
	//myDelete.enabled = (tracklist.deleteable == YES);
	//myShuffle.enabled = (tracklist.shuffleable == YES);
	myCoverCurrent.enabled = NO;

	[myLock tryLock];
	[myLock unlock];
	[self showBusy:NO withAd:NO];
	bStarting = NO;
}

CGImageRef AEViewCreateGradientImageA(int pixelsWide, int pixelsHigh)
{
	CGImageRef theCGImage = NULL;
	CGContextRef gradientBitmapContext = NULL;
	CGColorSpaceRef colorSpace;
	CGGradientRef grayScaleGradient;
	CGPoint gradientStartPoint, gradientEndPoint;

	// Our gradient is always black-white and the mask must be in the gray colorspace
	colorSpace = CGColorSpaceCreateDeviceGray();

	// create the bitmap context
	gradientBitmapContext = CGBitmapContextCreate(NULL, pixelsWide, pixelsHigh, 8, 0, colorSpace, kCGImageAlphaNone);

	if(gradientBitmapContext != NULL)
	{
		// define the start and end grayscale values (with the alpha, even though
		// our bitmap context doesn't support alpha the gradient requires it)
		CGFloat colors[] = {0.0, 1.0, 1.0, 1.0,};

		// create the CGGradient and then release the gray color space
		grayScaleGradient = CGGradientCreateWithColorComponents(colorSpace, colors, NULL, 2);

		// create the start and end points for the gradient vector (straight down)
		gradientStartPoint = CGPointMake(0,0);//CGPointZero;
		gradientEndPoint = CGPointMake(0,pixelsHigh);

		// draw the gradient into the gray bitmap context
		CGContextDrawLinearGradient(gradientBitmapContext, grayScaleGradient, gradientStartPoint, gradientEndPoint, kCGGradientDrawsBeforeStartLocation|kCGGradientDrawsAfterEndLocation);

		// clean up the gradient
		CGGradientRelease(grayScaleGradient);

		// convert the context into a CGImageRef and release the context
		theCGImage=CGBitmapContextCreateImage(gradientBitmapContext);
		CGContextRelease(gradientBitmapContext);
	}

	// clean up the colorspace
	CGColorSpaceRelease(colorSpace);

	// return the imageref containing the gradient
	return theCGImage;
}

- (UIImage *)getMirrorImage:(UIImage *)image forSize:(int)size;
{
	int height = size;
	
	UIImage *theImage = nil;
	CGSize isize = image.size;
	
	UIGraphicsBeginImageContext(CGSizeMake(isize.width, height));	
	CGContextRef currentContext = UIGraphicsGetCurrentContext();
	
	CGImageRef imageref = CGImageCreateWithImageInRect(image.CGImage, CGRectMake(0, isize.height - height, isize.width, height) );
	CGContextDrawImage(currentContext, CGRectMake(0, 0, isize.width, height), imageref);
	
	CGImageRef mainViewContentBitmapContext = CGBitmapContextCreateImage(currentContext);

	UIGraphicsEndImageContext();
	
	CGImageRef gradientMaskImage = AEViewCreateGradientImageA(1, height);
	CGImageRef reflectionImage = CGImageCreateWithMask(mainViewContentBitmapContext,gradientMaskImage);
	CGImageRelease(mainViewContentBitmapContext);
	CGImageRelease(gradientMaskImage);
	
	theImage = [UIImage imageWithCGImage:reflectionImage];
	//CGImageRelease(reflectionImage);
	CGImageRelease(imageref);
	
	return theImage;
}

- (void)viewWillAppear:(BOOL)animated
{
	[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(resetView:) userInfo:nil repeats:NO];
	[mySleep setImage:mySleepImage forState:UIControlStateNormal];

	if( videoPlayer != nil )
	{
		[videoPlayer stop];
		[videoPlayer stop];
		if ([myDelegate.viewController respondsToSelector:@selector(dismissMoviePlayerViewControllerAnimated)]) {
			//3.2+
			[myDelegate.viewController dismissMoviePlayerViewControllerAnimated];
		} else {
			//<3.2
			[videoPlayer release];
		}
		videoPlayer = nil;
	}
	
	bRotated = YES;
	bDoubleClick = NO;
	[self refresh:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)setPositionsPortrait:(CGPoint)portrait AndLandscape:(CGPoint)landscape {
	if([AppMobiDelegate isIPad]) {
		//iPad
		portraitPosition = portrait;
		landscapePosition = landscape;
		[self resetView:self];
	} else {
		//iPhone
		//do nothing
	}
}

- (void)resetView:(id)sender
{
	UIInterfaceOrientation neworient = [AppMobiViewController masterViewController].interfaceOrientation;
	if( neworient == UIInterfaceOrientationPortrait || neworient == UIInterfaceOrientationPortraitUpsideDown )
	{
		self.frame = CGRectMake(portraitPosition.x, portraitPosition.y, 320, 460);
		myScroller.frame = CGRectMake(0, 378, 320, 26);
		//myMetadata.frame = CGRectMake(0, 3, 320, 20);
		myBackground.frame = CGRectMake(0, 0, 320, 460);
		myBackground.image = myBackPort;

		//myCoverLeft1.frame = CGRectMake(-200, 40, 160, 160);
		//myCoverLeft2.frame = CGRectMake(-160, 40, 160, 160);
		//myCoverLeft3.frame = CGRectMake(-120, 40, 160, 160);
		//myCoverLeft4.frame = CGRectMake(-80, 40, 160, 160);
		//myCoverLeft5.frame = CGRectMake(-40, 40, 160, 160);
		myCoverLeft6.frame = CGRectMake(-50, 114, 180, 180);
		myCoverLeftMirror.frame = CGRectMake(-51, 267, 180, 30);
		myCoverRight2.frame = CGRectMake(190, 114, 180, 180);
		myCoverRightMirror.frame = CGRectMake(190, 267, 180, 30);
		//myCoverRight1.frame = CGRectMake(200, 40, 160, 160);
		myCoverCenter.frame = CGRectMake(80, 124, 160, 160);
		myCoverMirror.frame = CGRectMake(80, 284, 160, 26);
		myCoverCurrent.frame = CGRectMake(135, 310, 46, 28);

		myLive.frame = CGRectMake(248, 124, 47, 160);
		myBack.frame = CGRectMake(0, 72, 44, 34);
		myPrev.frame = CGRectMake(17, 340, 41, 39);
		myPlay.frame = CGRectMake(75, 340, 41, 39);
		myNext.frame = CGRectMake(133, 340, 41, 39);
		myStop.frame = CGRectMake(191, 340, 41, 39);
		//myThumbsup.frame = CGRectMake(80, 226, 41, 39);
		//myThumbsdown.frame = CGRectMake(200, 226, 41, 39);
		//myShare.frame = CGRectMake(215, 340, 41, 39);
		//myFavorite.frame = CGRectMake(216, 343, 41, 39);
		mySleep.frame = CGRectMake(249, 340, 41, 39);
		//myDelete.frame = CGRectMake(230, 320, 41, 39);
		//myShuffle.frame = CGRectMake(275, 320, 41, 39);
		//myVolume.frame = CGRectMake(10, 296, 300, 24);
		myProgress.frame = CGRectMake(0, 342, 320, 1);
	}
	else
	{
		self.frame = CGRectMake(landscapePosition.x, landscapePosition.y, 480, 300);
		myScroller.frame = CGRectMake(0, 270, 480, 26);
		//myMetadata.frame = CGRectMake(0, 3, 480, 20);
		myBackground.frame = CGRectMake(-45, 0, 525, 300);
		myBackground.image = myBackLand;

		//myCoverLeft1.frame = CGRectMake(-40, 14, 160, 160);
		//myCoverLeft2.frame = CGRectMake(0, 14, 160, 160);
		//myCoverLeft3.frame = CGRectMake(40, 14, 160, 160);
		//myCoverLeft4.frame = CGRectMake(80, 14, 160, 160);
		//myCoverLeft5.frame = CGRectMake(120, 14, 160, 160);
		myCoverLeft6.frame = CGRectMake(75, 48, 180, 180);
		myCoverLeftMirror.frame = CGRectMake(76, 203, 180, 16);
		myCoverRight2.frame = CGRectMake(315, 48, 180, 180);
		myCoverRightMirror.frame = CGRectMake(315, 203, 180, 16);
		//myCoverRight1.frame = CGRectMake(360, 14, 160, 160);
		myCoverCenter.frame = CGRectMake(160, 58, 160, 160);
		myCoverMirror.frame = CGRectMake(160, 218, 160, 12);
		myCoverCurrent.frame = CGRectMake(12, 237, 46, 28);

		myLive.frame = CGRectMake(333, 58, 47, 160);
		myBack.frame = CGRectMake(0, 127, 44, 34);
		myPrev.frame = CGRectMake(109, 232, 41, 39);
		myPlay.frame = CGRectMake(179, 232, 41, 39);
		myNext.frame = CGRectMake(249, 232, 41, 39);
		myStop.frame = CGRectMake(319, 232, 41, 39);
		//myThumbsup.frame = CGRectMake(240, 230, 41, 39);
		//myThumbsdown.frame = CGRectMake(360, 230, 41, 39);
		//myShare.frame = CGRectMake(357, 232, 41, 39);
		//myFavorite.frame = CGRectMake(318, 223, 41, 39);
		mySleep.frame = CGRectMake(389, 232, 41, 39);
		//myDelete.frame = CGRectMake(230, 230, 41, 39);
		//myShuffle.frame = CGRectMake(275, 230, 41, 39);
		//myVolume.frame = CGRectMake(330, 228, 145, 24);
		myProgress.frame = CGRectMake(0, 231, 480, 1);
	}

	[self resetMirror:nil];
	//self.hidesBottomBarWhenPushed = (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft || self.interfaceOrientation == UIInterfaceOrientationLandscapeRight );
	//[NSTimer scheduledTimerWithTimeInterval:0.0 target:myApp selector:@selector(reloadPlaying:) userInfo:nil repeats:NO];
}

- (UIColor *)makeColor:(NSString *)hexColor
{
	hexColor = [[hexColor stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];  
	
	// String should be 6 or 7 characters if it includes '#'
	if ([hexColor length] < 6) 
		return [UIColor blackColor];  
	
	// strip # if it appears  
	if ([hexColor hasPrefix:@"#"]) 
		hexColor = [hexColor substringFromIndex:1];  
	
	// if the value isn't 6 characters at this point return 
	// the color black	
	if ([hexColor length] != 6) 
		return [UIColor blackColor];  
	
	// Separate into r, g, b substrings  
	NSRange range;  
	range.location = 0;  
	range.length = 2; 
	
	NSString *rString = [hexColor substringWithRange:range];  
	
	range.location = 2;  
	NSString *gString = [hexColor substringWithRange:range];  
	
	range.location = 4;  
	NSString *bString = [hexColor substringWithRange:range];  
	
	// Scan values  
	unsigned int r, g, b;  
	[[NSScanner scannerWithString:rString] scanHexInt:&r];  
	[[NSScanner scannerWithString:gString] scanHexInt:&g];  
	[[NSScanner scannerWithString:bString] scanHexInt:&b];  
	
	return [UIColor colorWithRed:((float) r / 255.0f) green:((float) g / 255.0f) blue:((float) b / 255.0f) alpha:1.0f];		
}

- (void)setBackColor:(NSString *)strBackColor fillColor:(NSString *)strFillColor doneColor:(NSString *)strDoneColor playColor:(NSString *)strPlayColor
{
	if( strBackColor != nil && [strBackColor length] > 0 )
	{
		UIColor *color = [self makeColor:strBackColor];
		[myProgress setBackColor:color];
	}
	
	if( strFillColor != nil && [strFillColor length] > 0 )
	{
		UIColor *color = [self makeColor:strFillColor];
		[myProgress setTintColor:color];
	}
	
	if( strDoneColor != nil && [strDoneColor length] > 0 )
	{
		UIColor *color = [self makeColor:strDoneColor];
		[myProgress setDoneColor:color];
	}
	
	if( strPlayColor != nil && [strPlayColor length] > 0 )
	{
		UIColor *color = [self makeColor:strPlayColor];
		[myProgress setMarkColor:color];
	}
}

- (void)setOrientation:(int)degrees
{
	bRotated = YES;
	[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(resetView:) userInfo:nil repeats:NO];
	[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(repaint:) userInfo:nil repeats:NO];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	bRotated = YES;
	[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(resetView:) userInfo:nil repeats:NO];
}

- (int)getPlayingIndex
{
	// -- RDS get index from Player
	return 0;
}

- (void)onPlay:(id)sender
{
	if( myDelegate.myPlayer.bPaused == NO && myDelegate.myPlayer.bStopping == NO )
	{
		myNext.enabled = NO;
		myPrev.enabled = NO;
		[myDelegate.myPlayer togglePause];
		[myPlay setImage:myPlayImage forState:UIControlStateNormal];
		if( currentNode != nil && currentNode.nodeid != nil ) [[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.station.pause" waitUntilDone:NO];
		if( currentNode != nil && currentNode.nodeshout != nil ) [[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.shoutcast.pause" waitUntilDone:NO];
	}
	else if( myDelegate.myPlayer.bPaused == YES && myDelegate.myPlayer.bStopping == NO )
	{
		myNext.enabled = YES;
		myPrev.enabled = YES;
		[myDelegate.myPlayer togglePause];
		[myPlay setImage:myPauseImage forState:UIControlStateNormal];
		if( currentNode != nil && currentNode.nodeid != nil ) [[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.station.play" waitUntilDone:NO];
		if( currentNode != nil && currentNode.nodeshout != nil ) [[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.shoutcast.play" waitUntilDone:NO];
	}
}

- (void)onMute:(id)sender
{
	[myDelegate.myPlayer toggleMute];
}

- (void)dealloc
{
	[mySoundPool release];
	[myBackground release];
	[myNodeQueue release];
	[myLock release];
	[myWebViewArray release];
	[super dealloc];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	//NSString *urlstr = [[request URL] absoluteString];
	//printf("BCOM --- %s\r\n", [urlstr cStringUsingEncoding:NSASCIIStringEncoding]);
	return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
}

- (UIImage *)scaleImage:(UIImage *)image
{
	[iconLock lock];
	UIGraphicsBeginImageContext(CGSizeMake(160.0, 160.0));	
	CGContextRef currentContext = UIGraphicsGetCurrentContext();
	CGContextTranslateCTM(currentContext, 0.0, 160.0);
	CGContextScaleCTM(currentContext, 1.0, -1.0);
	CGContextDrawImage(currentContext, CGRectMake(0, 0, 160, 160), image.CGImage);
	UIImage *imageCopy = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	[iconLock unlock];

	return imageCopy;
}

- (UIImage *)scaleIcon:(UIImage *)image
{
	[iconLock lock];
	UIGraphicsBeginImageContext(CGSizeMake(60.0, 60.0));
	CGContextRef currentContext = UIGraphicsGetCurrentContext();
	CGContextTranslateCTM(currentContext, 0.0, 60.0);
	CGContextScaleCTM(currentContext, 1.0, -1.0);
	CGContextDrawImage(currentContext, CGRectMake(0, 0, 60, 60), image.CGImage);
	UIImage *imageCopy = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	[iconLock unlock];
	
	return imageCopy;
}

- (void)predelayScaler:(id)sender
{
	XMLTrack *track = (XMLTrack *)sender;
	[NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(delayScaler:) userInfo:track repeats:NO];
}

- (void)delayScaler:(NSTimer *)timer
{
	XMLTrack *track = (XMLTrack *)[timer userInfo];

	//printf(" !!! scaling cover -- used to crash here\n");
	NSString *ofilename = [[[NSString alloc] initWithFormat:@"%@/%@/%d/%@.x", strBase, strUID, track.stationid, track.guidSong] autorelease];
	track.original = [self scaleImage:track.original];
	[UIImagePNGRepresentation(track.original) writeToFile:ofilename atomically:YES];
			
	[self processEvent:EVENT_TRACKCOVERED forIndex:-1];
}

- (void)coverWorker:(id)anObject
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	XMLTrack *track = (XMLTrack *) anObject;
	//printf("``` COVER --- %s\r\n", [track.imageurl cStringUsingEncoding:NSASCIIStringEncoding]);
	//printf("``` COVER --- %s\r\n", [track.title cStringUsingEncoding:NSASCIIStringEncoding]);
	if( track != nil && track.imageurl != nil )
	{
		BOOL checkdir = YES;

		NSString *ofilename = [[[NSString alloc] initWithFormat:@"%@/%@/", strBase, strUID] autorelease];
		if( NO == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
		{
			[[NSFileManager defaultManager] createDirectoryAtPath:ofilename withIntermediateDirectories:YES attributes:nil error:nil];
		}

		ofilename = [[[NSString alloc] initWithFormat:@"%@/%@/%d/", strBase, strUID, track.stationid] autorelease];
		if( NO == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
		{
			[[NSFileManager defaultManager] createDirectoryAtPath:ofilename	withIntermediateDirectories:YES attributes:nil error:nil];
		}

		ofilename = [[[NSString alloc] initWithFormat:@"%@/%@/%d/%@.x", strBase, strUID, track.stationid, track.guidSong] autorelease];
		if( NO == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
		{
			//printf("``` COVER --- %s\r\n", [track.imageurl cStringUsingEncoding:NSASCIIStringEncoding]);
			//printf("``` COVER --- %s\r\n", [track.title cStringUsingEncoding:NSASCIIStringEncoding]);

			NSData *imgdata = [NSData dataWithContentsOfURL:[NSURL URLWithString:track.imageurl]];
			if( imgdata != nil && [imgdata length] > 0 )
			{
				[[NSFileManager defaultManager] createFileAtPath:ofilename contents:nil attributes:nil];
				track.basealbum = [[[NSString alloc] initWithFormat:@"/%@/%d/%@.x", strUID, track.stationid, track.guidSong] retain];
				track.albumfile = [[[NSString alloc] initWithFormat:@"%@/%@", strBase, track.basealbum] retain];
				[imgdata writeToFile:ofilename atomically:YES];
				track.original = [[UIImage alloc] initWithData:imgdata];
				//printf("``` IMAGESIZE --- %f %f\r\n", track.original.size.width, track.original.size.height);
				if( track.original.size.width != 160 || track.original.size.height != 160 )
				{
					[self performSelectorOnMainThread:@selector(predelayScaler:) withObject:track waitUntilDone:YES];
					//track.original = [self scaleImage:track.original];
					//[UIImagePNGRepresentation(track.original) writeToFile:ofilename atomically:YES];
				}

				[self processEvent:EVENT_TRACKCOVERED forIndex:-1];
			}
			else
			{
				track.imageurl = nil;
			}
		}
		else
		{
			NSData *imgdata = [NSData dataWithContentsOfFile:ofilename];
			track.original = [[[UIImage alloc] initWithData:imgdata] autorelease];			
			[self processEvent:EVENT_TRACKCOVERED forIndex:-1];
		}
	}

	[pool release];
}

- (void)podcastWorker:(id)anObject
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	XMLTracklist *tracklist = (XMLTracklist *) anObject;
	if( tracklist != nil )
	{
		BOOL checkdir = YES;
		
		NSString *ofilename = [[[NSString alloc] initWithFormat:@"%@/%@/", strBase, strUID] autorelease];
		if( NO == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
		{
			[[NSFileManager defaultManager] createDirectoryAtPath:ofilename	withIntermediateDirectories:YES attributes:nil error:nil];
		}
		
		ofilename = [[[NSString alloc] initWithFormat:@"%@/%@/%d/", strBase, strUID, tracklist.stationid] autorelease];
		if( NO == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
		{
			[[NSFileManager defaultManager] createDirectoryAtPath:ofilename	withIntermediateDirectories:YES attributes:nil error:nil];
		}
		
		if( tracklist.imageurl != nil )
		{
			ofilename = [[[NSString alloc] initWithFormat:@"%@/%@/%d/%d.img", strBase, strUID, tracklist.stationid, tracklist.stationid] autorelease];
			if( NO == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
			{
				NSData *imgdata = [NSData dataWithContentsOfURL:[NSURL URLWithString:tracklist.imageurl]];
				if( imgdata != nil && [imgdata length] > 0 )
				{
					[[NSFileManager defaultManager] createFileAtPath:ofilename contents:nil attributes:nil];
					tracklist.original = [[[UIImage alloc] initWithData:imgdata] autorelease];
									
					[imgdata writeToFile:ofilename atomically:YES];
					if( tracklist.original.size.width != 160 || tracklist.original.size.height != 160 )
					{
						tracklist.original = [self scaleImage:tracklist.original];
						[UIImagePNGRepresentation(tracklist.original) writeToFile:ofilename atomically:YES];
					}

					ofilename = [[[NSString alloc] initWithFormat:@"%@/stations/%d.img", strBase, tracklist.stationid] autorelease];
					UIImage *temp = [self scaleIcon:tracklist.original];
					[UIImagePNGRepresentation(temp) writeToFile:ofilename atomically:YES];
					
					[self performSelectorOnMainThread:@selector(repaint:) withObject:nil waitUntilDone:NO];
				}
			}
			else
			{
				NSData *imgdata = [NSData dataWithContentsOfFile:ofilename];
				tracklist.original = [[[UIImage alloc] initWithData:imgdata] autorelease];			
				
				[self performSelectorOnMainThread:@selector(repaint:) withObject:nil waitUntilDone:NO];
			}
		}
		
		if( tracklist.startindex < [tracklist.children count] )
		{
			XMLTrack *track = (XMLTrack *) [tracklist.children objectAtIndex:tracklist.startindex];
			if( track.cached == NO && track.mediaurl != nil )
			{
				[NSThread detachNewThreadSelector:@selector(podcastWorker:) toTarget:self withObject:track];
			}
		}
	}
	
	[pool release];
}

- (void)episodeWorker:(id)anObject
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	XMLTrack *track = (XMLTrack *) anObject;
	if( track != nil )
	{
		BOOL checkdir = YES;
		
		NSString *ofilename = [NSString stringWithFormat:@"%@/%@/%d/%f.mp4", strBase, strUID, track.stationid, track.timecode];
		if( NO == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
		{
			if( track.cached == NO && track.mediaurl != nil )
			{
				NSData *imgdata = [NSData dataWithContentsOfURL:[NSURL URLWithString:track.mediaurl]];
				if( imgdata != nil && [imgdata length] > 0 )
				{
					track.basefile = [NSString stringWithFormat:@"/%@/%d/%f.mp4", strUID, track.stationid, track.timecode];
					track.filename = [NSString stringWithFormat:@"%@/%@", strBase, track.basefile];
					track.cached = YES;
					[imgdata writeToFile:track.filename atomically:YES];
					[self processEvent:EVENT_TRACKCOVERED forIndex:-1];
				}
			}
		}
	}
	
	[self showBusy:NO withAd:NO];
	
	[pool release];
}

- (void)adcacheWorker:(id)anObject
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	CachedAd *temp = (CachedAd *) anObject;
	float curtime = CFAbsoluteTimeGetCurrent();
	
	NSData *audiodata = nil;
	if( temp.strAudioURL != nil ) audiodata = [NSData dataWithContentsOfURL:[NSURL URLWithString:temp.strAudioURL]];
	if( audiodata != nil && [audiodata length] > 0 )
	{
		temp.strBaseAudio = [[[NSString alloc] initWithFormat:@"%f.mp3", curtime] autorelease];
		BOOL checkdir;
		temp.strAudioPath = [[[NSString alloc] initWithFormat:@"%@/%@", strBase, temp.strBaseAudio] autorelease];
		if( NO == [[NSFileManager defaultManager] fileExistsAtPath:temp.strAudioPath isDirectory:&checkdir] )
		{
			[[NSFileManager defaultManager] createFileAtPath:temp.strAudioPath contents:nil attributes:nil];
		}
		temp.audio = [audiodata retain];
		[audiodata writeToFile:temp.strAudioPath atomically:YES];				
	}
	
	NSData *imagedata = [NSData dataWithContentsOfURL:[NSURL URLWithString:temp.strImageURL]];
	if( imagedata != nil && [imagedata length] > 0 )
	{
		temp.strBaseImage = [[[NSString alloc] initWithFormat:@"%f.img", curtime] autorelease];
		BOOL checkdir;
		temp.strImagePath = [[[NSString alloc] initWithFormat:@"%@/%@", strBase, temp.strBaseImage] autorelease];
		if( NO == [[NSFileManager defaultManager] fileExistsAtPath:temp.strImagePath isDirectory:&checkdir] )
		{
			[[NSFileManager defaultManager] createFileAtPath:temp.strImagePath contents:nil attributes:nil];
		}
		temp.image = [UIImage imageWithData:imagedata];
		[imagedata writeToFile:temp.strImagePath atomically:YES];					
	}
	
	temp.cached = YES;
	[arrAdCache addObject:temp];
	
	[pool release];
}

- (void)imageWorker:(id)anObject
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *url = (NSString *)anObject;
	//printf("imageWorker --- %s (%d)\r\n", [url cStringUsingEncoding:NSASCIIStringEncoding], [url retainCount]);
	[NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
	
	[pool release];
}

- (CachedAd *)checkPreroll:(XMLTracklist *)tracklist
{
	BOOL google = NO;
	CachedAd *temp = nil;
	NSString *adtarget = nil;
	NSString *adimage = nil;
	NSString *adaudio = nil;
	NSString *adadimg = nil;
	NSString *adgoogle = nil;
	NSRange range1;
	NSRange range2;
	NSRange range3;
	NSRange range4;
	NSString *adurl = [[[NSString alloc] initWithFormat:@"%@ord=%f", tracklist.adprerollzone, CFAbsoluteTimeGetCurrent()] autorelease];
	NSString *addata = [NSString stringWithContentsOfURL:[NSURL URLWithString:adurl] encoding:NSUTF8StringEncoding error:NULL];
	//NSString *addata = @"<googleaudio channel=\"rock_music\"/>";
	if( addata != nil && [addata length] > 0 )
	{
		range1 = [addata rangeOfString:@"<a "];
		if( range1.length > 0 )
		{
			range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 3 - range1.location)];
			if( range2.length > 0 )
			{
				range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+1, [addata length] - 1 - range2.location)];
				if( range3.length > 0 )
				{
					adtarget = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
				}
			}
		}
		
		range1 = [addata rangeOfString:@"<img "];
		if( range1.length > 0 )
		{
			range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
			if( range2.length > 0 )
			{
				range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+1, [addata length] - 1 - range2.location)];
				if( range3.length > 0 )
				{
					range4 = [addata rangeOfString:@"ADIMAGE=\"true" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
					if( range4.length > 0 )
						adimage = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
					else
						adadimg = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
				}
			}
		}
		
		if( adimage != nil || adadimg != nil )
		{
			range1 = [addata rangeOfString:@"<img " options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
			if( range1.length > 0 )
			{
				range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
				if( range2.length > 0 )
				{
					range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+1, [addata length] - 1 - range2.location)];
					if( range3.length > 0 )
					{
						range4 = [addata rangeOfString:@"ADIMAGE=\"true" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
						if( range4.length > 0 )
							adimage = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
						else
							adadimg = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
					}
				}
			}
		}
		
		//printf("adtarget --- %s\r\n", [adtarget cStringUsingEncoding:NSASCIIStringEncoding]);		
		//printf("adimage --- %s\r\n", [adimage cStringUsingEncoding:NSASCIIStringEncoding]);
		//printf("adadimg --- %s\r\n", [adadimg cStringUsingEncoding:NSASCIIStringEncoding]);
		
		range1 = [addata rangeOfString:@"<audio "];
		if( range1.length > 0 )
		{
			range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+range1.length+1, [addata length]-range1.length-range1.location-1)];
			if( range2.length > 0 )
			{
				range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+range2.length+1, [addata length]-range2.length-range2.location-1)];
				if( range3.length > 0 )
				{
					adaudio = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
				}
			}
		}
		
		range1 = [addata rangeOfString:@"<googleaudio"];
		if( range1.length > 0 )
		{
			google = YES;
			range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+range1.length+1, [addata length]-range1.length-range1.location-1)];
			if( range2.length > 0 )
			{
				range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+range2.length+1, [addata length]-range2.length-range2.location-1)];
				if( range3.length > 0 )
				{
					adgoogle = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
				}
			}
		}
		
		if( google == YES )
		{
			temp = [[CachedAd alloc] init];
			temp.googleaudio = YES;
			temp.preroll = YES;
			temp.strGoogleID = adgoogle;
		}
		else if( adtarget != nil && adimage != nil && adaudio != nil )
		{
			BOOL found = NO;
			for( int i = 0; i < [arrAdCache count]; i++ )
			{
				temp = (CachedAd *) [arrAdCache objectAtIndex:i];
				temp.strAdImgURL = [adadimg retain];
				temp.strClickURL = [adtarget retain];
				temp.preroll = YES;
				temp.signup = NO;
				temp.cached = YES;
				//BOOL check1 = ( temp.strClickURL != nil && adtarget != nil && [adtarget compare:temp.strClickURL] == NSOrderedSame );
				BOOL check2 = ( temp.strImageURL != nil && adimage != nil && [adimage compare:temp.strImageURL] == NSOrderedSame );
				BOOL check3 = ( temp.strAudioURL != nil && adaudio != nil && [adaudio compare:temp.strAudioURL] == NSOrderedSame );
				if( /*check1 == YES &&*/ check2 == YES && check3 == YES )
				{
					found = YES;
					[NSThread detachNewThreadSelector:@selector(imageWorker:) toTarget:self withObject:temp.strAdImgURL];
					break;
				}
			}
			
			if( found == NO )
			{				
				temp = [[CachedAd alloc] init];
				temp.strAudioURL = adaudio;
				temp.strImageURL = adimage;
				temp.strAdImgURL = adadimg;
				temp.strClickURL = adtarget;
				temp.preroll = YES;
				temp.signup = NO;
				
				[NSThread detachNewThreadSelector:@selector(adcacheWorker:) toTarget:self withObject:temp];
				[NSThread detachNewThreadSelector:@selector(imageWorker:) toTarget:self withObject:temp.strAdImgURL];
			}
		}		
	}
	
	return temp;
}

- (void)checkPopup:(NSTimer *)timer
{
	Version *vers = (Version *)[timer userInfo];
	if( currentTracklist == nil ) return;
	if( vers.number != adindex ) return;
	BOOL google = NO;
	CachedAd *temp = nil;
	int duration = 15;
	NSString *adtarget = nil;
	NSString *adimage = nil;
	NSString *adadimg = nil;
	NSString *adgoogle = nil;
	NSRange range1;
	NSRange range2;
	NSRange range3;
	NSRange range4;
	NSString *addata = nil;
	
	printf("--- inside checkPopup\n");
	AppMobiDelegate *delegate = (AppMobiDelegate *) [[UIApplication sharedApplication] delegate];
	if( delegate.bForceGoogle == NO )
	{
		NSString *adurl = [[[NSString alloc] initWithFormat:@"%@ord=%f", currentTracklist.adpopupzone, CFAbsoluteTimeGetCurrent()] autorelease];
		addata = [NSString stringWithContentsOfURL:[NSURL URLWithString:adurl] encoding:NSUTF8StringEncoding error:NULL];
	}
	else
	{
		addata = @"<googledisplay channel=\"rock_music\"/> <duration sec=\"15\"/>";	
	}
	if( addata != nil && [addata length] > 0 )
	{
		range1 = [addata rangeOfString:@"<a "];
		if( range1.length > 0 )
		{
			range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 3 - range1.location)];
			if( range2.length > 0 )
			{
				range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+1, [addata length] - 1 - range2.location)];
				if( range3.length > 0 )
				{
					adtarget = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
				}
			}
		}
		
		range1 = [addata rangeOfString:@"<img "];
		if( range1.length > 0 )
		{
			range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
			if( range2.length > 0 )
			{
				range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+1, [addata length] - 1 - range2.location)];
				if( range3.length > 0 )
				{
					range4 = [addata rangeOfString:@"ADIMAGE=\"true" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
					if( range4.length > 0 )
						adimage = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
					else
						adadimg = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
				}
			}
		}
		
		if( adimage != nil || adadimg != nil )
		{
			range1 = [addata rangeOfString:@"<img " options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
			if( range1.length > 0 )
			{
				range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
				if( range2.length > 0 )
				{
					range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+1, [addata length] - 1 - range2.location)];
					if( range3.length > 0 )
					{
						range4 = [addata rangeOfString:@"ADIMAGE=\"true" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
						if( range4.length > 0 )
							adimage = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
						else
							adadimg = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
					}
				}
			}
		}
		
		range1 = [addata rangeOfString:@"<duration"];
		if( range1.length > 0 )
		{
			range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+range1.length+1, [addata length]-range1.length-range1.location-1)];
			if( range2.length > 0 )
			{
				range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+range2.length+1, [addata length]-range2.length-range2.location-1)];
				if( range3.length > 0 )
				{
					duration = [[addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)] intValue];
				}
			}
		}
		
		//printf("adtarget --- %s\r\n", [adtarget cStringUsingEncoding:NSASCIIStringEncoding]);		
		//printf("adimage --- %s\r\n", [adimage cStringUsingEncoding:NSASCIIStringEncoding]);
		//printf("adadimg --- %s\r\n", [adadimg cStringUsingEncoding:NSASCIIStringEncoding]);
		
		range1 = [addata rangeOfString:@"<googledisplay"];
		if( range1.length > 0 )
		{
			google = YES;
			range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+range1.length+1, [addata length]-range1.length-range1.location-1)];
			if( range2.length > 0 )
			{
				range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+range2.length+1, [addata length]-range2.length-range2.location-1)];
				if( range3.length > 0 )
				{
					adgoogle = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
				}
			}
		}
		
		if( google == YES )
		{
			temp = [[CachedAd alloc] init];
			temp.googledisplay = YES;
			temp.preroll = NO;
			temp.strGoogleID = adgoogle;
			temp.duration = duration;
		}
		else if( adtarget != nil && adimage != nil )
		{
			BOOL found = NO;
			for( int i = 0; i < [arrAdCache count]; i++ )
			{
				temp = (CachedAd *) [arrAdCache objectAtIndex:i];
				temp.strAdImgURL = [adadimg retain];
				temp.strClickURL = [adtarget retain];
				temp.preroll = NO;
				temp.signup = NO;
				temp.cached = YES;
				//BOOL check1 = ( temp.strClickURL != nil && adtarget != nil && [adtarget compare:temp.strClickURL] == NSOrderedSame );
				BOOL check2 = ( temp.strImageURL != nil && adimage != nil && [adimage compare:temp.strImageURL] == NSOrderedSame );
				if( /*check1 == YES &&*/ check2 == YES )
				{					
					found = YES;
					temp.duration = duration;
					[NSThread detachNewThreadSelector:@selector(imageWorker:) toTarget:self withObject:temp.strAdImgURL];
					break;
				}				
			}
			
			if( found == NO )
			{				
				temp = [[CachedAd alloc] init];
				temp.strImageURL = adimage;
				temp.strClickURL = adtarget;
				temp.strAdImgURL = adadimg;
				temp.duration = duration;
				temp.preroll = NO;
				temp.signup = NO;
				
				[NSThread detachNewThreadSelector:@selector(adcacheWorker:) toTarget:self withObject:temp];
				[NSThread detachNewThreadSelector:@selector(imageWorker:) toTarget:self withObject:temp.strAdImgURL];
			}
		}
	}
	
	BOOL hidden = NO;	
	UIView *top = (UIView *) [[[self superview] subviews] objectAtIndex:0];
	if( top != self )
	{
		hidden = YES;
	}
	hidden = self.hidden;
	
	if( temp != nil && bInter == NO && hidden == NO )
	{
		temp.number = vers.number;
		[vers release];
		bPopup = YES;
		[self showBusy:YES withAd:NO];
		[busyView popup:temp];
	}
	else
	{
		int freq = [currentTracklist.adpopupfreq intValue];
		[NSTimer scheduledTimerWithTimeInterval:freq target:self selector:@selector(checkPopup:) userInfo:vers repeats:NO];
	}
}

- (void)checkInterstitial:(NSTimer *)timer
{
	Version *vers = (Version *)[timer userInfo];
	if( currentTracklist == nil ) return;
	if( vers.number != adindex ) return;
	BOOL google = NO;
	CachedAd *temp = nil;
	NSString *adtarget = nil;
	NSString *adimage = nil;
	NSString *adaudio = nil;
	NSString *adadimg = nil;
	NSString *adgoogle = nil;
	NSRange range1;
	NSRange range2;
	NSRange range3;
	NSRange range4;
	NSString *addata = nil;
	
	printf("--- inside checkInterstitial\n");
	AppMobiDelegate *delegate = (AppMobiDelegate *) [[UIApplication sharedApplication] delegate];
	if( delegate.bForceGoogle == NO )
	{
		NSString *adurl = [[[NSString alloc] initWithFormat:@"%@ord=%f", currentTracklist.adinterzone, CFAbsoluteTimeGetCurrent()] autorelease];
		addata = [NSString stringWithContentsOfURL:[NSURL URLWithString:adurl] encoding:NSUTF8StringEncoding error:NULL];
	}
	else
	{
		addata = @"<googleaudio channel=\"rock_music\"/>";		
	}
	if( addata != nil && [addata length] > 0 )
	{
		range1 = [addata rangeOfString:@"<a "];
		if( range1.length > 0 )
		{
			range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 3 - range1.location)];
			if( range2.length > 0 )
			{
				range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+1, [addata length] - 1 - range2.location)];
				if( range3.length > 0 )
				{
					adtarget = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
				}
			}
		}
		
		range1 = [addata rangeOfString:@"<img "];
		if( range1.length > 0 )
		{
			range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
			if( range2.length > 0 )
			{
				range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+1, [addata length] - 1 - range2.location)];
				if( range3.length > 0 )
				{
					range4 = [addata rangeOfString:@"ADIMAGE=\"true" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
					if( range4.length > 0 )
						adimage = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
					else
						adadimg = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
				}
			}
		}
		
		if( adimage != nil || adadimg != nil )
		{
			range1 = [addata rangeOfString:@"<img " options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
			if( range1.length > 0 )
			{
				range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
				if( range2.length > 0 )
				{
					range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+1, [addata length] - 1 - range2.location)];
					if( range3.length > 0 )
					{
						range4 = [addata rangeOfString:@"ADIMAGE=\"true" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+1, [addata length] - 5 - range1.location)];
						if( range4.length > 0 )
							adimage = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
						else
							adadimg = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
					}
				}
			}
		}
		
		range1 = [addata rangeOfString:@"<audio "];
		if( range1.length > 0 )
		{
			range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+range1.length+1, [addata length]-range1.length-range1.location-1)];
			if( range2.length > 0 )
			{
				range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+range2.length+1, [addata length]-range2.length-range2.location-1)];
				if( range3.length > 0 )
				{
					adaudio = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
				}
			}
		}
		
		range1 = [addata rangeOfString:@"<googleaudio"];
		if( range1.length > 0 )
		{
			google = YES;
			range2 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range1.location+range1.length+1, [addata length]-range1.length-range1.location-1)];
			if( range2.length > 0 )
			{
				range3 = [addata rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(range2.location+range2.length+1, [addata length]-range2.length-range2.location-1)];
				if( range3.length > 0 )
				{
					adgoogle = [addata substringWithRange:NSMakeRange(range2.location+1, range3.location-range2.location-1)];
				}
			}
		}
		
		if( google == YES )
		{
			temp = [[CachedAd alloc] init];
			temp.googleaudio = YES;
			temp.preroll = NO;
			temp.strGoogleID = adgoogle;
		}
		else if( adtarget != nil && adimage != nil && adaudio != nil )
		{
			BOOL found = NO;
			for( int i = 0; i < [arrAdCache count]; i++ )
			{
				temp = (CachedAd *) [arrAdCache objectAtIndex:i];
				temp.strAdImgURL = [adadimg retain];
				temp.strClickURL = [adtarget retain];
				temp.preroll = NO;
				temp.signup = NO;
				temp.cached = YES;
				//BOOL check1 = ( temp.strClickURL != nil && adtarget != nil && [adtarget compare:temp.strClickURL] == NSOrderedSame );
				BOOL check2 = ( temp.strImageURL != nil && adimage != nil && [adimage compare:temp.strImageURL] == NSOrderedSame );
				BOOL check3 = ( temp.strAudioURL != nil && adaudio != nil && [adaudio compare:temp.strAudioURL] == NSOrderedSame );
				if( /*check1 == YES &&*/ check2 == YES && check3 == YES )
				{
					found = YES;
					[NSThread detachNewThreadSelector:@selector(imageWorker:) toTarget:self withObject:temp.strAdImgURL];
					break;
				}				
			}
			
			if( found == NO )
			{				
				temp = [[CachedAd alloc] init];
				temp.strAudioURL = adaudio;
				temp.strImageURL = adimage;
				temp.strClickURL = adtarget;
				temp.preroll = NO;
				temp.signup = NO;
				
				[NSThread detachNewThreadSelector:@selector(adcacheWorker:) toTarget:self withObject:temp];
				[NSThread detachNewThreadSelector:@selector(imageWorker:) toTarget:self withObject:temp.strAdImgURL];
			}
		}
	}
	
	if( temp != nil && bPopup == NO )
	{
		temp.number = vers.number;
		[vers release];
		bInter = YES;
		//printf("checkInterstitial\n");
		[busyView pregoogleaudio:temp];
		[myDelegate.myPlayer setIntersitial:temp];
	}
	else
	{
		int freq = [currentTracklist.adinterfreq intValue];
		[NSTimer scheduledTimerWithTimeInterval:freq target:self selector:@selector(checkInterstitial:) userInfo:vers repeats:NO];
	}
}


int tracksorta( id obj1, id obj2, void *context )
{
	XMLTrack *t1 = (XMLTrack *) obj1;
	XMLTrack *t2 = (XMLTrack *) obj2;
	
    if( t1.timecode < t2.timecode )
		return -1;
	else if( t1.timecode > t2.timecode )
		return 1;
	else
		return 0;
}

int tracklistsorta( id obj1, id obj2, void *context )
{
	XMLTracklist *t1 = (XMLTracklist *) obj1;
	XMLTracklist *t2 = (XMLTracklist *) obj2;
	
    if( t1.timecode < t2.timecode )
		return -1;
	else if( t1.timecode > t2.timecode )
		return 1;
	else
		return 0;
}

- (void)handleStop:(id)sender
{
	XMLTracklist *tracklist = (XMLTracklist *)sender;
	if( tracklist != nil ) tracklist.recording = NO;
	tracklist = [self persistTracklist:tracklist];
	[self saveTracklists];
	[allTracklists sortUsingFunction:tracklistsorta context:nil];
	[self performSelectorOnMainThread:@selector(repaint:) withObject:nil waitUntilDone:NO];
}

- (void)saveTracklists
{
	if( allTracklists == nil || [allTracklists count] == 0 ) return;
	
	BOOL checkdir = YES;
	NSString *ofilename = [[[NSString alloc] initWithFormat:@"%@/recordings.dat", strBase] autorelease];
	if( NO == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
	{
		[[NSFileManager defaultManager] createFileAtPath:ofilename contents:nil attributes:nil];
	}
	//[myApp.allTracklists writeToFile:ofilename atomically:YES];
	[NSKeyedArchiver archiveRootObject:allTracklists toFile:ofilename];
}

- (void)readTracklists
{
	BOOL checkdir = YES;
	NSString *ofilename = [[[NSString alloc] initWithFormat:@"%@/recordings.dat", strBase] autorelease];
	if( YES == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
	{
		//myApp.allTracklists = [[NSArray arrayWithContentsOfFile:ofilename] retain];
		allTracklists = [NSKeyedUnarchiver unarchiveObjectWithFile:ofilename];
		
		if( allTracklists == nil || [allTracklists count] == 0 )
		{
			allTracklists = [[[NSMutableArray alloc] init] retain];
			return;
		}
		
		for( int i = 0; i < [allTracklists count]; i++ )
		{
			XMLTracklist *tltemp = (XMLTracklist *) [allTracklists objectAtIndex:i];
			tltemp.offline = NO;
			for( int j = [tltemp.children count] - 1; j >= 0; j-- )
			{
				XMLTrack *ttemp = (XMLTrack *) [tltemp.children objectAtIndex:j];
				ttemp.resuming = (j == tltemp.startindex);
				if( ttemp.basefile != nil )
					ttemp.filename = [[[NSString alloc] initWithFormat:@"%@/%@", strBase, ttemp.basefile] retain];
				if( ttemp.basealbum != nil )
					ttemp.albumfile = [[[NSString alloc] initWithFormat:@"%@/%@", strBase, ttemp.basealbum] retain];
				if( tltemp.video == YES ) continue;
				if( [self verifyTrack:ttemp] == YES || YES )
				{
					[self addNewTrack:ttemp];
				}
				else
				{
					NSError *error = nil;
					if( ttemp.albumfile != nil )
						[[NSFileManager defaultManager] removeItemAtPath:ttemp.albumfile error:&error];
					if( ttemp.filename != nil )
						[[NSFileManager defaultManager] removeItemAtPath:ttemp.filename error:&error];
					[tltemp.children removeObjectAtIndex:j];
				}
			}
		}
	}
}

- (void)deleteLogs
{
	NSError *error = nil;
	BOOL checkdir = YES;
	NSString *ofilename = [[[NSString alloc] initWithFormat:@"%@/favorite.dat", strBase] autorelease];
	if( YES == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
	{
		[[NSFileManager defaultManager] removeItemAtPath:ofilename error:&error];
	}
}

- (void)readLogs
{
	NSError *error = nil;
	BOOL checkdir = YES;
	NSString *ofilename = [[[NSString alloc] initWithFormat:@"%@/favorite.dat", strBase] autorelease];
	if( YES == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
	{
		tracksReported = [[NSString stringWithContentsOfFile:ofilename encoding:NSUTF8StringEncoding error:&error] retain];
		if( tracksReported == nil ) tracksReported = @"";
	}
}

- (void)logTrack:(NSString *)station forSong:(NSString *)lsong
{
	if( station == nil || lsong == nil ) return;
	
	NSError *error = nil;
	BOOL checkdir = YES;
	NSString *ofilename = [[[NSString alloc] initWithFormat:@"%@/favorite.dat", strBase] autorelease];
	if( NO == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
	{
		[[NSFileManager defaultManager] createFileAtPath:ofilename contents:nil attributes:nil];
	}
	
	double timecode = (kCFAbsoluteTimeIntervalSince1970 + CFAbsoluteTimeGetCurrent()) * 1000;
	long seconds = (long) timecode;
	tracksReported = [[[NSString alloc] initWithFormat:@"%@%@|%@|%ld\n", tracksReported, station, seconds, lsong] retain];
	
	[tracksReported writeToFile:ofilename atomically:YES encoding:NSUTF8StringEncoding error:&error];
}

- (void)deleteTracklist:(XMLTracklist *)tracklist
{
	if( tracklist == nil || [tracklist.children count] == 0 ) return;
	
	for( int i = [tracklist.children count]-1; i >= 0; i-- )
	{
		XMLTrack *temp = (XMLTrack *) [tracklist.children objectAtIndex:i];
		[self deleteTrack:temp];
	}
	
	NSString *dirname = [[[NSString alloc] initWithFormat:@"%@/%@/%d/", strBase, strUID, tracklist.stationid] autorelease];
	NSError *error;
	[[NSFileManager defaultManager] removeItemAtPath:dirname error:&error];	
	
	if( [allTracklists count] == 0 )
	{
		NSString *ofilename = [[[NSString alloc] initWithFormat:@"%@/recordings.dat", strBase] autorelease];
		[[NSFileManager defaultManager] removeItemAtPath:ofilename error:&error];	
	}
}

- (void)deleteTrack:(XMLTrack *)track
{
	XMLTracklist *cachedTracklist = nil;
	XMLTracklist *realTracklist = nil;
	int trackidx = -1;
	[track retain];
	for( int i = 0; i < [allTracklists count]; i++ )
	{
		XMLTracklist *temp = (XMLTracklist *) [allTracklists objectAtIndex:i];
		if( temp.stationid == track.stationid )
		{
			trackidx = i;
			cachedTracklist = temp;
			break;
		}
	}
	
	if( cachedTracklist == nil && currentTracklist != nil )
	{
		cachedTracklist = currentTracklist;
	}
	
	if( currentTracklist != nil && currentTracklist.shuffled == YES )
	{
		realTracklist = cachedTracklist;
		cachedTracklist = currentTracklist;
	}
	
	BOOL duplicate = NO;
	int index = -1;
	for( int i = 0; cachedTracklist != nil && i < [cachedTracklist.children count]; i++ )
	{
		XMLTrack *ttemp = (XMLTrack *) [cachedTracklist.children objectAtIndex:i];
		if( ttemp != track && ttemp.guidIndex != nil && track.guidIndex != nil && [ttemp.guidIndex compare:track.guidIndex] == NSOrderedSame )
		{
			duplicate = YES;
		}
		if( ttemp == track )
		{
			index = i;
		}
	}
	
	for( int j = 0; realTracklist != nil && j < [realTracklist.children count]; j++ )
	{
		XMLTrack *ttemp = (XMLTrack *) [realTracklist.children objectAtIndex:j];
		if( ttemp == track )
		{
			[realTracklist.children removeObjectAtIndex:j];
			break;
		}
	}
	
	if( bPlaying == YES && cachedTracklist == currentTracklist && index != -1 && index == [self getPlayingIndex] )
	{
		// -- RDS skip player to next track
		//FlyCastPLManager.playnexttrack();
	}
	
	if( index != -1 )
	{
		[cachedTracklist.children removeObjectAtIndex:index];
		if( [cachedTracklist.children count] == 0 && trackidx != -1 )
		{
			if( cachedTracklist == currentTracklist )
				[self performSelectorOnMainThread:@selector(onStop:) withObject:nil waitUntilDone:NO];
			[allTracklists removeObjectAtIndex:trackidx];
			[self deleteTracklist:cachedTracklist];
			
			NSString *dirname = [[[NSString alloc] initWithFormat:@"%@/%@/%d/", strBase, strUID, cachedTracklist.stationid] autorelease];
			NSError *error;
			[[NSFileManager defaultManager] removeItemAtPath:dirname error:&error];
			// -- RDS if( m_favorites != null ) updateRecordings(m_favorites);
		}
	}
	
	if( cachedTracklist == currentTracklist && index != -1 && index <= [self getPlayingIndex] )
	{
		// notify playingViewController and Player that a track is removed
		/* -- RDS
		 if( rotator != null ) rotator.trackRemoved();
		 downloader.trackRemoved();
		 FlyCastPLManager.trackRemoved();
		 controls.setTracklist(m_currentList, getCurrentPlayingIndex());
		 //*/
	}
	
	if( track.cached == YES )
	{
		mCurSeconds -= track.seconds;
	}
	
	if( duplicate == NO )
	{
		NSError *error = nil;
		if( track.albumfile != nil )
			[[NSFileManager defaultManager] removeItemAtPath:track.albumfile error:&error];
		if( track.filename != nil )
			[[NSFileManager defaultManager] removeItemAtPath:track.filename error:&error];
	}
}

- (void)addNewTrack:(XMLTrack *)track
{
	if( mMaxSeconds == 0 ) return;
	
	mCurSeconds += track.seconds;
	[allTracks addObject:track];
	while( mCurSeconds > mMaxSeconds )
	{
		XMLTrack *temp = (XMLTrack *) [allTracks objectAtIndex:0];
		[allTracks removeObjectAtIndex:0];
		[self deleteTrack:temp];
	}
}


- (BOOL)verifyTrack:(XMLTrack *)track
{
	if( [[NSFileManager defaultManager] fileExistsAtPath:track.filename] )
	{
		if( track.expplays != -1 && track.numplay >= track.expplays ) return NO;
		double current =  CFAbsoluteTimeGetCurrent();
		long elapsed = (long)(current - track.timecode) / 60 / 60 / 24; // Number of elapsed days
		if( track.expdays != -1 && elapsed >= track.expdays ) return NO;
		return YES;
	}
	
	return NO;
}

- (XMLTracklist *)persistTracklist:(XMLTracklist *)tracklist
{
	if( tracklist != nil && ( tracklist.podcasting == YES || tracklist.video == YES ) )
	{
		if( tracklist.offline == YES ) return nil;
		[allTracklists addObject:tracklist];
		tracklist.offline = YES;
		return tracklist;
	}
	
	if( tracklist != nil && tracklist.offline == YES )
	{
		for( int i = [tracklist.children count] -1; i >= 0; i-- )
		{
			XMLTrack *temp = (XMLTrack *) [tracklist.children objectAtIndex:i];
			if( [self verifyTrack:temp] == NO )
			{
				[self deleteTrack:temp];
			}
		}
		return tracklist;
	}
	
	if( tracklist == nil || tracklist.shuffled == YES || tracklist.users == YES ) return nil;
	
	if( mMaxSeconds == 0 && bShowUpgrade == YES && tracklist.throwaway == NO )
	{
		bShowUpgrade = NO;
		// launch upgrade choice -- RDS
		return nil;
	}
	if( mMaxSeconds == 0 )
	{
		XMLTracklist *oldlist = nil;
		if( allTracklists != nil && [allTracklists count] > 0 ) oldlist = (XMLTracklist *) [allTracklists objectAtIndex:0];
		if( oldlist != nil && oldlist != tracklist )
		{
			[oldlist retain];
			[allTracklists removeAllObjects];
			[self deleteTracklist:oldlist];
			[allTracklists addObject:tracklist];
		}
		else if( oldlist != tracklist )
		{			
			[allTracklists addObject:tracklist];
		}
		
		return tracklist;
	}
	
	for( int i = [tracklist.children count] -1; i >= 0; i-- )
	{
		XMLTrack *temp = (XMLTrack *) [tracklist.children objectAtIndex:i];
		if( temp.cached == NO || tracklist.throwaway == YES )
		{
			//[tracklist.children removeObjectAtIndex:i];
			[self deleteTrack:temp];
		}
	}
	if( [tracklist.children count] == 0 ) return nil;
	
	for( int i = 0; i < [tracklist.children count]; i++ )
	{
		XMLTrack *temp = (XMLTrack *) [tracklist.children objectAtIndex:i];
		//[temp.original release];
		//temp.original = nil;
		if( tracklist.offline == NO )
			[self addNewTrack:temp];
	}
	
	XMLTracklist *cachedTracklist = nil;
	for( int i = 0; i < [allTracklists count]; i++ )
	{
		XMLTracklist *temp = (XMLTracklist *) [allTracklists objectAtIndex:i];
		if( temp.stationid == tracklist.stationid )
		{
			cachedTracklist = temp;
			break;
		}
	}
	
	if( cachedTracklist == tracklist )
	{
		cachedTracklist.startindex = 0;
		cachedTracklist.offline = YES;
		return tracklist;
	}
	else if( cachedTracklist == nil )
	{
		cachedTracklist = tracklist;
		cachedTracklist.startindex = 0;
		cachedTracklist.offline = YES;
		[allTracklists addObject:tracklist];
	}
	else
	{
		cachedTracklist.shuffleable = tracklist.shuffleable;
		cachedTracklist.deleteable = tracklist.deleteable;
		cachedTracklist.autoshuffle = tracklist.autoshuffle;
		cachedTracklist.autohide = tracklist.autohide;
		
		for( int i = 0; i < [tracklist.children count]; i++ )
		{
			XMLTrack *temp = (XMLTrack *) [tracklist.children objectAtIndex:i];
			[cachedTracklist.children addObject:temp];
		}
	}
	
	cachedTracklist.offline = YES;
	return cachedTracklist;
}

- (NSString *)getLengthName:(XMLTracklist *)tracklist
{
	if( tracklist.video == YES ) return nil;
	
	int tlength = 0;
	for( int i = 0; i < [tracklist.children count]; i++ )
	{
		XMLTrack *temp = (XMLTrack *) [tracklist.children objectAtIndex:i];
		tlength += temp.seconds;
	}
	
	int hours = tlength / 60 / 60;
	int minutes = (tlength - (hours * 60 * 60)) / 60;
	int seconds = (tlength - (hours * 60 * 60) - (minutes* 60));
	
	NSString *duration = [[[NSString alloc] initWithFormat:@"%02d:%02d:%02d", hours, minutes, seconds] retain];
	return duration;
}

- (void)getAllCovers:(id)sender
{
	if( currentTracklist != nil && currentTracklist.offline == NO )
	{    
		for( int i = [currentTracklist.children count] - 1; i >= 0; i-- )
		{
			XMLTrack *temp = (XMLTrack*)  [currentTracklist.children objectAtIndex:i];
			if( ( temp.albumfile != nil || temp.imageurl != nil ) && temp.original == nil ) {
				[NSThread detachNewThreadSelector:@selector(coverWorker:) toTarget:self withObject:temp];
			}
		}
	}
}
@end

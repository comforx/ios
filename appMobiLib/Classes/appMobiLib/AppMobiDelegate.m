#import "AppMobiDelegate.h"
#import "AppMobiViewController.h"
#import "AppMobiSplashController.h"
#import "PlayingView.h"
#import "Player.h"
#import <UIKit/UIKit.h>
#import "InvokedCommand.h"
#import "AppConfig.h"
#import "ZipArchive.h" 
#import "HTTPServer.h"
#import "LocalRequestConnection.h"
#import "Bookmark.h"
#import "BookmarkConfigParser.h"
#import "AppConfigParser.h"
#import "AppMobiDevice.h"
#import "AppMobiPlayer.h"
#import "AppMobiStats.h"
#import "AppMobiNotification.h"
#import "Player.h"
#import "TargetConditionals.h"
#import "TVOutManager.h"
#import "AppMobiPushViewController.h"
#import "AppMobiModule.h"
#import "AppMobiWebView.h"
#import "AppMobiOAuth.h"
#import "AMSResponse.h"
#import "AMSNotification.h"
#import "AppMobiCanvas.h"

@implementation AMApplication

- (void)remoteControlReceivedWithEvent:(UIEvent*)theEvent {
	if (theEvent.type == UIEventTypeRemoteControl) {
		AppMobiDelegate *appdelegate = (AppMobiDelegate*)[self delegate];
		PlayingView *playingView = [appdelegate.viewController getPlayerView];
		if(appdelegate!=nil && playingView!=nil){
			switch(theEvent.subtype) {
				case UIEventSubtypeRemoteControlPlay:
					[playingView onPlay:nil];
					break;
				case UIEventSubtypeRemoteControlPause:
					[playingView onPlay:nil];
					break;
				case UIEventSubtypeRemoteControlStop:
					[playingView onStop:nil];
					break;
				case UIEventSubtypeRemoteControlTogglePlayPause:
					[playingView onPlay:nil];
					break;
				case UIEventSubtypeRemoteControlNextTrack:
					[playingView onNext:nil];
					break;
				case UIEventSubtypeRemoteControlPreviousTrack:
					[playingView onPrev:nil];
					break;
				default:
					return;
			}
		}
	}
}

@end

@implementation AMURLCache

-(void)setMemoryCapacity:(NSUInteger)memCap
{
    if( memCap == 0 )
        return;
    [super setMemoryCapacity:memCap];
}

@end

@implementation DownloadDelegate

@synthesize bDone, bSuccess, lastUpdateTime, bookmark, strBundle;

- (id)init
{
	self = [super init];
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	AMLog(@"%@",[error localizedDescription]);
    bSuccess = NO;
	bDone = YES;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	if( myHandle == nil )
	{
		[[NSFileManager defaultManager] createFileAtPath:strBundle contents:nil attributes:nil];
        
		myHandle = [[NSFileHandle fileHandleForUpdatingAtPath:strBundle] retain];
		[myHandle seekToEndOfFile];
	}
	
	current += [data length];
	[myHandle writeData:data];
	
	NSTimeInterval recent = [[NSDate date] timeIntervalSince1970];
	if( recent - lastUpdateTime > 1.0 )
	{
        double percent = (double)current/(double)length;
        [[AppMobiViewController masterViewController] updateInstall:bookmark withPercent:percent];
		lastUpdateTime = recent;
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	length = response.expectedContentLength;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[myHandle closeFile];
    bSuccess = YES;
	bDone = YES;
}

@end

AppMobiDelegate *sharedDelegate = nil;
const unsigned char SpeechKitApplicationKey[] = {0xd9, 0x24, 0xd1, 0xf8, 0x37, 0x17, 0x39, 0x8e, 0x3f, 0x8e, 0xad, 0xe1, 0x9d, 0x97, 0xda, 0xd1, 0xb4, 0x3b, 0x30, 0x89, 0xec, 0x24, 0xcf, 0x79, 0x58, 0x18, 0x73, 0xdf, 0x14, 0xda, 0x4e, 0xed, 0xfe, 0x1f, 0xe5, 0x35, 0x36, 0x1f, 0xc4, 0x76, 0xad, 0x71, 0x57, 0x4a, 0x08, 0x31, 0x1b, 0xbc, 0x6d, 0x4c, 0x45, 0x59, 0x70, 0x14, 0xd2, 0xc8, 0x2c, 0x45, 0xa8, 0x40, 0x20, 0xf6, 0x2e, 0x1e};
BOOL bDebug = NO;

void AMLog( NSString *format, ... )
{
	if( bDebug == YES )
	{
		va_list args;
		va_start(args,format);
		NSLogv(format, args);
		va_end(args);
	}
}

@implementation AppMobiDelegate

@synthesize window;
@synthesize webView;
@synthesize viewController;
@synthesize activityView;
@synthesize invokedURL;
@synthesize urlId;
@synthesize urlPay;
@synthesize urlCmd;
@synthesize urlUrl;
@synthesize urlRtn;
@synthesize appName;
@synthesize relName;
@synthesize pkgName;
@synthesize lastApp;
@synthesize lastRel;
@synthesize lastPkg;
@synthesize urlQuery;
@synthesize strDeviceToken;
@synthesize bShowAds;
@synthesize bForceGoogle;
@synthesize isWebContainer;
@synthesize isTestContainer;
@synthesize isProtocolHandler;
@synthesize isMobiusInstall;
@synthesize _config;
@synthesize _payconfig;
@synthesize _bookconfig;
@synthesize bInBackground;
@synthesize bStartup;
@synthesize myPlayer;
@synthesize nextPlayer;
@synthesize whiteLabel;
@synthesize galleryURL;
@synthesize onetouchURL;
@synthesize adSenseApplicationAppleID;
@synthesize adSenseAppName;
@synthesize adSenseCompanyName;
@synthesize adSenseAppWebContentURL;
@synthesize adSenseChannelID;

BOOL bIsIPad = NO;
BOOL bIsAudioInitialized = NO;
BOOL bIsSpeechInitialized = NO;
BOOL bShouldFireJSEventWithUpdateToken = YES;

- (id)init
{
	self = [super init];
	bShowAds = NO;
	bForceGoogle = NO;
	whiteLabel = @"WL=APPMOBI";
	adSenseApplicationAppleID = @"358004585";
	adSenseAppName = @"appMobi";
	adSenseCompanyName = @"appMobi";
	adSenseAppWebContentURL = @"www.appmobi.fm";
	adSenseChannelID = @"9919579637";
	
	galleryURL = @"http://www.appmobi.com/mobiusdemos";
	updateURL = @"http://itunes.apple.com/us/app/mobius/id453823727?ls=1&mt=8";
	onetouchURL = @"https://services.appmobi.com/paymobi/1touch/default.aspx?isnative=1&edit=true";
	importURL = @"https://services.appmobi.com/paymobi/1touch/default.aspx?isnative=1&importkey=";

#ifdef DEBUG
	bDebug = YES;
#endif

	if (self != nil) {
		sharedDelegate = self;
		splashLock = [[NSLock alloc] init];
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		appName = [defaults objectForKey:@"appName"];
		relName = [defaults objectForKey:@"relName"];
		pkgName = [defaults objectForKey:@"pkgName"];
		
		if( appName == nil ) appName = @"";
		if( relName == nil ) relName = @"";
		if( pkgName == nil ) pkgName = @"";
		
		lastApp = [defaults objectForKey:@"lastApp"];
		lastRel = [defaults objectForKey:@"lastRel"];
		lastPkg = [defaults objectForKey:@"lastPkg"];
		
		if( lastApp == nil ) lastApp = @"";
		if( lastRel == nil ) lastRel = @"";
		if( lastPkg == nil ) lastPkg = @"";
		
		payApp = @"1touch.app";
		payRel = @"3.4.0";
		
		bookSequence = [defaults integerForKey:@"bookSequence"];
	}

	//check if we are on iPhone or iPad
	[TVOutManager sharedInstance];
	UIDevice *device = [UIDevice currentDevice];
	if ([device respondsToSelector:@selector(userInterfaceIdiom)]) {
		if ([device userInterfaceIdiom] == UIUserInterfaceIdiomPad ) {
			bIsIPad = YES;
		}
	}

	return self; 
}

+ (NSString*)baseDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

+ (NSString*)appDirectory
{
	return [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:@"AppMobiCache"];
}

+ (AppMobiDelegate*)sharedDelegate
{
	return sharedDelegate;
}

+ (BOOL)isIPad
{
	return bIsIPad;
}

- (void)testMemory:(id)sender
{
	UInt8 *buck0 = nil;
	UInt8 *buck1 = nil;
	UInt8 *buck2 = nil;
	UInt8 *buck3 = nil;
	UInt8 *buck4 = nil;
	UInt8 *buck5 = nil;
	UInt8 *buck6 = nil;
	UInt8 *buck7 = nil;
	UInt8 *buck8 = nil;
	UInt8 *buck9 = nil;
	UInt8 *buckA = nil;
	UInt8 *buckB = nil;
	UInt8 *buckC = nil;
	UInt8 *buckD = nil;
	UInt8 *buckE = nil;
	UInt8 *buckF = nil;
	UInt8 *buckG = nil;
	UInt8 *buckH = nil;
	UInt8 *buckI = nil;
	UInt8 *buckJ = nil;	
	UInt8 *buckK = nil;
	UInt8 *buckL = nil;
	UInt8 *buckM = nil;
	UInt8 *buckN = nil;
	
	@try
	{
		buck0 = malloc( sizeof(UInt8) * 1048576);
		buck1 = malloc( sizeof(UInt8) * 1048576);
		buck2 = malloc( sizeof(UInt8) * 1048576);
		buck3 = malloc( sizeof(UInt8) * 1048576);
		buck4 = malloc( sizeof(UInt8) * 1048576);
		buck5 = malloc( sizeof(UInt8) * 1048576);
		buck6 = malloc( sizeof(UInt8) * 1048576);
		buck7 = malloc( sizeof(UInt8) * 1048576);
		buck8 = malloc( sizeof(UInt8) * 1048576);
		buck9 = malloc( sizeof(UInt8) * 1048576);
		buckA = malloc( sizeof(UInt8) * 1048576);
		buckB = malloc( sizeof(UInt8) * 1048576);
		buckC = malloc( sizeof(UInt8) * 1048576);
		buckD = malloc( sizeof(UInt8) * 1048576);
		buckE = malloc( sizeof(UInt8) * 1048576);
		buckF = malloc( sizeof(UInt8) * 1048576);
		buckG = malloc( sizeof(UInt8) * 1048576);
		buckH = malloc( sizeof(UInt8) * 1048576);
		buckI = malloc( sizeof(UInt8) * 1048576);
		buckJ = malloc( sizeof(UInt8) * 1048576);
		buckK = malloc( sizeof(UInt8) * 1048576);
		buckL = malloc( sizeof(UInt8) * 1048576);
		buckM = malloc( sizeof(UInt8) * 1048576);
		buckN = malloc( sizeof(UInt8) * 1048576);
	}
	@catch (NSException * e)
	{
	}
	
	free( buck0 );
	free( buck1 );
	free( buck2 );
	free( buck3 );
	free( buck4 );
	free( buck5 );
	free( buck6 );
	free( buck7 );
	free( buck8 );
	free( buck9 );
	free( buckA );
	free( buckB );
	free( buckC );
	free( buckD );
	free( buckE );
	free( buckF );
	free( buckG );
	free( buckH );
	free( buckI );
	free( buckJ );
	free( buckK );
	free( buckL );
	free( buckM );
	free( buckN );
}

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
	AMLog(@"applicationDidFinishLaunching");
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	AMLog(@"didFinishLaunchingWithOptions");
	AMLog(@"%@", launchOptions);
    
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
	
	CGRect screenBounds = [[UIScreen mainScreen ]bounds];
	self.window = [[[UIWindow alloc] initWithFrame:screenBounds] autorelease];
	bFirstTime = YES;
	
	NSURL *launchURL = nil;
	if( launchOptions != nil ) launchURL = [launchOptions objectForKey:UIApplicationLaunchOptionsURLKey];
	if( launchURL != nil )
	{
		AMLog(@"%@", [launchURL description]);
		[self application:application handleOpenURL:launchURL];
	}
	
	NSDictionary* options = nil;
	if( launchOptions != nil ) options = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
	if( options != nil )
	{
        NSString *target = [options objectForKey:@"target"];
        BOOL hidden = [[options objectForKey:@"hidden"] boolValue];        
		userKey = [[[options objectForKey:@"userkey"] copy] retain];
        if( target != nil )
        {
            NSString *msgappName = [NSString stringWithString:target];
            NSString *msgrelName = nil;
            
            NSString *path = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:msgappName];
            NSArray *dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:(NSString *)path error:nil];
            for( int i = 0; dirs != nil && i < [dirs count]; i++ )
            {
                NSString *dir = [dirs objectAtIndex:i];
                NSString *configpath = [path stringByAppendingFormat:@"/%@/appconfig.xml", dir];
                if( [[NSFileManager defaultManager] fileExistsAtPath:configpath] == YES )
                {
                    msgrelName = dir;
                }
            }
        
            if( msgrelName != nil )
            {
                if( isWebContainer == YES )
                {
                    bHiddenPush = hidden;
                    isPushStart = YES;
                    isProtocolHandler = YES;
                    urlCmd = @"RUNAPP";
                    urlApp = [[msgappName copy] retain];
                    urlRel = [[msgrelName copy] retain];
                }
                else
                {
                    if( userKey == nil || [userKey length] == 0 ) userKey = @"-";
                    isProtocolHandler = YES;
                    appName = [[msgappName copy] retain];
                    relName = [[msgrelName copy] retain];
                    pkgName = @"PRODUCTION";
                }
            }
        }
	}
	
	/* Mobius app testing
	isMobiusInstall = YES;
	isProtocolHandler = YES;
	urlApp = @"marc.jellyblox";
	urlRel = @"3.4.0";
	urlCmd = @"RUNAPP";
	//*/
	
	
	[self testMemory:nil];
	if( isWebContainer == NO || isMobiusInstall == YES )
	{
		[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onLaunch:) userInfo:nil repeats:NO];
	}
	else
	{
		[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onStartup:) userInfo:nil repeats:NO];
	}
	
	return YES;
}

- (void)hideSplashTimer:(id)sender
{
	[NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(hideSplashScreen:) userInfo:nil repeats:NO];
}

- (void)hideSplashScreen:(id)sender
{
	[splashLock lock];
	
	if( splashController.view.superview != nil )
	{
		[splashController.view removeFromSuperview];
		bStartup = NO;
	}
	
	[splashLock unlock];
}

- (UIImage *)updateSplash:(id)sender
{
	NSString *file;
	NSString *path;
	
	BOOL ipad = bIsIPad;
	
	if( isProtocolHandler == YES )
	{
		if( isMobiusInstall == YES )
		{
			path = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"mobius_configure%@", (ipad?@"_ipad":@"")] ofType:@"png"];
		}
		else
		{
			path = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"test_container_splash_screen%@", (ipad?@"_ipad":@"")] ofType:@"png"];
		}
	}
	else
	{
		// new splash style but skinned in appMobi app
		file = [NSString stringWithFormat:@"splash_screen%@", (ipad?@"_ipad":@"")];
		path = [[AppMobiDelegate appDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/_appMobi/%@.png", appName, relName, file]];
		
		if( NO == [[NSFileManager defaultManager] fileExistsAtPath:path] )
		{
			// new splash style but in app binary
			path = [[NSBundle mainBundle] pathForResource:file ofType:@"png"];
		}	
	
		if( NO == [[NSFileManager defaultManager] fileExistsAtPath:path] )
		{
			// old splash style but skinned in appMobi app
			file = [NSString stringWithFormat:@"splash_screen%@", (ipad?@"_ipad":@"")];
			path = [[AppMobiDelegate appDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/_appMobi/%@.png", appName, relName, file]];
		}
		
		if( NO == [[NSFileManager defaultManager] fileExistsAtPath:path] )
		{
			// old splash style but in app binary
			path = [[NSBundle mainBundle] pathForResource:file ofType:@"png"];
		}
	}
	
	return [UIImage imageWithContentsOfFile:path];
}

- (void)onLaunch:(id)sender
{
	bStartup = YES;
	splashController = [[AppMobiSplashController alloc] init];
	[window insertSubview:splashController.view atIndex:0];
	splashController.window = window;
	
	[window makeKeyAndVisible];
	
	[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onStartup:) userInfo:nil repeats:NO];
}

- (void)onStartup:(id)sender
{
	viewController = [[AppMobiViewController alloc] init];
	[window insertSubview:viewController.view atIndex:0];
	viewController.window = window;
	
	if( window.keyWindow == NO ) [window makeKeyAndVisible];
	
	webView = [viewController getWebView];
	pushView = [viewController getPushView];

	UIDevice *device = [UIDevice currentDevice];
	BOOL backgroundSupported = NO;
	if ([device respondsToSelector:@selector(isMultitaskingSupported)]) {
		backgroundSupported = device.multitaskingSupported;
		[[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
	}

	httpServer = [HTTPServer new];
	[httpServer setType:@"_http._tcp."];
	[httpServer setConnectionClass:[LocalRequestConnection class]];
	[httpServer setDocumentRoot:[NSURL fileURLWithPath:[[AppMobiDelegate appDirectory] stringByAppendingString:@"/"]]];
	[httpServer setPort:58888];
	
	NSError *error = nil;
	if( ![httpServer start:&error] )
	{
		AMLog(@"Error starting HTTP Server: %@", error);
	}

	if( isWebContainer == NO )
	{
		if( isTestContainer == NO )
		{
			if( isProtocolHandler == YES )
			{
				NSString *configFile = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/appconfig.xml", appName, relName]];
				if( NO == [[NSFileManager defaultManager] fileExistsAtPath:configFile] )
				{
					BOOL success = [self downloadInitialApp:appName andRel:relName andPkg:pkgName];
					if( success == NO )
					{
						UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Missing Application" message:@"Unable to retrieve application from the cloud. Verify that you pressed Test Anywhere in the XDK." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
						[alert show];
						[alert release];
					}
				}
			}
			else
			{
				if( [appName length] == 0 )
				{
					[self extractInitialApp];
				}
				else
				{
					NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
					NSString *versionCode = [defaults objectForKey:@"versionCode"];
					NSString *bundleCode = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"versionCode"];
					
					if( versionCode != nil && [bundleCode intValue] > [versionCode intValue] )
					{
						[self updateInitialApp];
						[defaults setObject:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"versionCode"] forKey:@"versionCode"];
						[defaults synchronize];
					}					
				}
				
				if( [appName compare:@"samp.appLab"] == NSOrderedSame || [appName compare:@"applab.app"] == NSOrderedSame )
				{
					[UIApplication sharedApplication].statusBarOrientation = UIInterfaceOrientationPortrait;
				}
			}
			
			[NSThread detachNewThreadSelector:@selector(updateWorker:) toTarget:self withObject:nil];
		}
		else
		{
			NSString *configFile = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/appconfig.xml", lastApp, lastRel]];
			BOOL haveConfig = [[NSFileManager defaultManager] fileExistsAtPath:configFile];
			[self handleLogin:haveConfig];
		}
	}
	else
	{
		[viewController setAutoRotate:NO];
		[viewController setRotateOrientation:@"portrait"];
		[NSThread detachNewThreadSelector:@selector(mobiusWorker:) toTarget:self withObject:nil];
	}
}

- (void)updateWorker:(id)sender
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Make sure payments is ready for we start them up
	NSString *payConfig = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/appconfig.xml", payApp, payRel]];
	if( NO == [[NSFileManager defaultManager] fileExistsAtPath:payConfig] )
	{
		[self installPayments];
	}
	else
	{
		self._payconfig = [self parseAppConfig:payConfig];
		[self installUpdate:_payconfig];
	}
		
	NSString *appConfig = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/appconfig.xml", appName, relName]];
	if( _config == nil )
	{
		self._config = [self parseAppConfig:appConfig];
	}
	
	if( webView.config == nil )
	{ // if we are autorunning a site use the real config not mobius.app
		webView.config = _config;
	}
	if( webView != nil && bFirstTime == YES )
	{
		[webView autoLogEvent:@"/device/start.event" withQuery:nil];
		if( userKey != nil )
		{
			[webView autoLogEvent:@"/notification/push/interact.event" withQuery:userKey];
		}
	}
	bFirstTime = NO;

	if( isWebContainer == NO )
	{
		if( ( _config.updateType == 1 || _config.updateType == 2 ) && [self updateAvailable:_config] == YES )
		{
			// setup update messaging UI and installation
			[self performSelectorOnMainThread:@selector(notifyUserAndInstall:) withObject:_config waitUntilDone:NO];
		}
		else
		{
			_config.updateType = 4;
			if( bWasBackground == NO )
			{
				[webView performSelectorOnMainThread:@selector(runApp:) withObject:nil waitUntilDone:NO];
				[self performSelectorOnMainThread:@selector(hideSplashTimer:) withObject:nil waitUntilDone:NO];
			}
			bWasBackground = NO;
		}
	}
	
	// Check for update of payments
	[self downloadUpdate:_payconfig];
	self._payconfig = [self parseAppConfig:payConfig];
	
	// Check for update of running app
	BOOL bUpdate = [self downloadUpdate:_config];
	self._config = [self parseAppConfig:appConfig];
	if( isWebContainer == NO )
	{
		webView.config = _config;
	}

	if( bUpdate == YES && _config.hasUpdates == YES )
	{
		NSString *appConfig = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/newappconfig.xml", appName, relName]];
		self._config = [self parseAppConfig:appConfig];
		webView.config = _config;

		if( isWebContainer == YES )
		{
			[self installUpdate:_config];
		}
		else if( _config.updateType == 1 )
		{
			// auto update now but notify user
			[self performSelectorOnMainThread:@selector(notifyUserAndInstall:) withObject:_config waitUntilDone:NO];
		}
		else if( _config.updateType == 2 )
		{
			// auto update on restart/resume
		}
		else if( _config.updateType == 3 )
		{
			// prompt user unless they have opted out
			NSString *optstr = [NSString stringWithFormat:@"%@.optout", appName];
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			BOOL optout = [defaults boolForKey:optstr];
			
			if( optout == YES )
				[self performSelectorOnMainThread:@selector(notifyAppForInstall:) withObject:_config waitUntilDone:NO];
			else
				[self performSelectorOnMainThread:@selector(promptUserForInstall:) withObject:_config waitUntilDone:NO];
		}
		else if( _config.updateType == 4 )
		{
			// notify application of update
			[self performSelectorOnMainThread:@selector(notifyAppForInstall:) withObject:_config waitUntilDone:NO];
		}
	}
	
	if( _config.hasPush == YES && isWebContainer == NO )
	{
		[NSThread sleepForTimeInterval:2.0];
		[NSThread detachNewThreadSelector:@selector(setupPushWorker:) toTarget:self withObject:_config];
	}
	
	if( _config.hasOAuth == YES && _config.servicesURL != nil && _config.servicesVersion > 0 && isWebContainer == NO )
	{
		[NSThread sleepForTimeInterval:2.0];
		AppMobiOAuth *oauth = (AppMobiOAuth *) [webView getCommandInstance:@"AppMobiOAuth"];

		UInt64 timestamp = ( (UInt64) [[NSDate date] timeIntervalSince1970] * 1000 );
		timestamp -= (timestamp % 262); // magic number
		NSString *url = [NSString stringWithFormat:@"http://services.appmobi.com/external/clientservices.aspx?feed=OA&appname=%@&timestamp=%qu", _config.appName, timestamp];
		NSString *keycode = [NSString stringWithContentsOfURL:[NSURL URLWithString:url] encoding:NSUTF8StringEncoding error:nil];
		if( keycode != nil && [keycode length] > 0 )
		{
			NSRange range = [keycode rangeOfString:@"<OA return=\"OK\" key=\""];
			if( range.location != NSNotFound )
			{
				NSString *key = [keycode substringFromIndex:range.location + range.length];
				range = [key rangeOfString:@"\" />"];
				key = [key substringToIndex:range.location];
				[oauth initializeServiceData:key];
			}
		}
	}

	[pool release];
}

- (void)installWorker:(id)sender
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[webView performSelectorOnMainThread:@selector(clearApp:) withObject:nil waitUntilDone:NO];

	[NSThread sleepForTimeInterval:2.0];
	[self installUpdate:_config];
	
	[viewController performSelectorOnMainThread:@selector(hideUpdate:) withObject:nil waitUntilDone:NO];
	
	[webView performSelectorOnMainThread:@selector(runApp:) withObject:nil waitUntilDone:NO];
	[self performSelectorOnMainThread:@selector(hideSplashTimer:) withObject:nil waitUntilDone:NO];

	[pool release];
}

- (void)startInstallation:(id)sender
{
	[NSThread detachNewThreadSelector:@selector(installWorker:) toTarget:self withObject:nil];	
}

- (void)notifyUserAndInstall:(AppConfig *)appconfig
{
	if( appconfig.updateType != 3 )
	{
		NSString *update = nil;
		if( appconfig.updateType == 1 )
			update = [NSString stringWithFormat:@"Description of update:\n%@\n\nThe update will now be installed.", appconfig.updateMessage];
		else if( appconfig.updateType == 2 )
			update = [NSString stringWithFormat:@"Description of update:\n%@\n\nThe update was just installed.", appconfig.updateMessage];
		else if( appconfig.updateType == 4 )
			update = [NSString stringWithFormat:@"The update will now be installed."];
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Application Update" message:update delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];
	}

	[viewController showUpdate:self];
	
	[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(startInstallation:) userInfo:appconfig repeats:NO];
}

- (void)promptUserForInstall:(AppConfig *)appconfig
{
	NSString *update = [NSString stringWithFormat:@"Description of update:\n%@\n\nWould you like to install now?", appconfig.updateMessage];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Application Update" message:update delegate:self cancelButtonTitle:@"YES" otherButtonTitles:@"No", nil];
	[alert show];
	[alert release];
}

- (void)notifyAppForInstall:(AppConfig *)appconfig
{
	NSString *js = [NSString stringWithFormat:@"var e = document.createEvent('Events');e.initEvent('appMobi.device.update.available',true,true);e.message='%@';document.dispatchEvent(e);", appconfig.updateMessage];
	AMLog(@"%@",js);
	[webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:js waitUntilDone:NO];	
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if( bAutoPush == YES )
	{
		bAutoPush = NO;
		if( buttonIndex == 1 )
		{
			Bookmark *appmark = nil;
			for( int i = 0; i < [_bookconfig.bookmarks count]; i++ )
			{
				Bookmark *book = (Bookmark *) [_bookconfig.bookmarks objectAtIndex:i];
				if( book.appconfig != nil && [book.appconfig.appName compare:urlApp] == NSOrderedSame )
				{
					appmark = book;
					break;
				}
			}
			
			BOOL isHidden = NO;
			if( lastPushID != nil && [lastPushID length] > 0 )
			{
				AppMobiNotification *notification = (AppMobiNotification *) [pushView getCommandInstance:@"AppMobiNotification"];
				AMSNotification *note = [notification getNoteForID:lastPushID];
				isHidden = note.hidden;
				[lastPushID release];
				lastPushID = nil;
			}
            
            isHidden = isHidden || bHiddenPush;
			if( appmark != nil )
			{
				AppMobiViewController *vc = [AppMobiViewController masterViewController];				
				if( vc._runBmk != nil && [vc._runBmk.appconfig.appName compare:urlApp] != NSOrderedSame )
				{
					if( vc._runBmk != nil ) [vc onCloseApp:nil];
					if( vc.bPushShowing == YES ) [vc dismissModalViewControllerAnimated:YES];

					[AppMobiViewController masterViewController]._runBmk = appmark;
					if( [appmark.appconfig.appType compare:@"SITE"] == NSOrderedSame )
						[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(onRunSite:) withObject:nil waitUntilDone:NO];
					else
						[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(onRunApp:) withObject:nil waitUntilDone:NO];
					
					AppMobiNotification *notification = (AppMobiNotification *) [pushView getCommandInstance:@"AppMobiNotification"];
					if( isHidden == NO ) [[AppMobiViewController masterViewController] showPushViewer:appmark.appconfig forNotification:notification];
				}
				else if( [vc getWebView].config != nil && [[vc getWebView].config.appName compare:urlApp] != NSOrderedSame )
				{
					if( vc.bPushShowing == YES ) [vc dismissModalViewControllerAnimated:YES];		
					
					[AppMobiViewController masterViewController]._runBmk = appmark;
					if( [appmark.appconfig.appType compare:@"SITE"] == NSOrderedSame )
						[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(onRunSite:) withObject:nil waitUntilDone:NO];
					else
						[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(onRunApp:) withObject:nil waitUntilDone:NO];
					
					AppMobiNotification *notification = (AppMobiNotification *) [pushView getCommandInstance:@"AppMobiNotification"];
					if( isHidden == NO ) [[AppMobiViewController masterViewController] showPushViewer:appmark.appconfig forNotification:notification];					
				}
				
				if( vc.bPushShowing == NO )
				{
					AppMobiNotification *notification = (AppMobiNotification *) [pushView getCommandInstance:@"AppMobiNotification"];
					if( isHidden == NO ) [[AppMobiViewController masterViewController] showPushViewer:appmark.appconfig forNotification:notification];
				}
				else
				{
					if( vc.modalViewController != nil )
					{
						UINavigationController *navc = (UINavigationController *) vc.modalViewController;
						AppMobiPushViewController *pushvc = (AppMobiPushViewController *) [navc topViewController];
						if( isHidden == NO ) [pushvc performSelectorOnMainThread:@selector(reload:) withObject:nil waitUntilDone:NO];
					}
				}
                bHiddenPush = NO;
			}
		}
	}
	else if( bMobiusUpdate == YES )
	{
		bMobiusUpdate = NO;		
		if( buttonIndex == 1 )
		{
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:updateURL]];
		}
	}
	else if( isWebContainer == NO )
	{
		if( buttonIndex == 0 )
		{
			[self performSelectorOnMainThread:@selector(notifyUserAndInstall:) withObject:_config waitUntilDone:NO];
		}
		else if( buttonIndex == 1 )
		{
			_config.updateType = 4;
			[self performSelectorOnMainThread:@selector(notifyAppForInstall:) withObject:_config waitUntilDone:NO];
		}
	}
}

void phonecallListener(void *inUserData, UInt32 interruptionState)
{
	PlayingView *playerView = (PlayingView *) [[AppMobiViewController masterViewController] getPlayerView];
	if( playerView == nil || playerView == nil ) return;
	
	if(interruptionState == kAudioSessionBeginInterruption)
	{
		[playerView onPlay:nil];	
	}
	else if(interruptionState == kAudioSessionEndInterruption)
	{
		AudioSessionSetActive(YES);
		[playerView onPlay:nil];
	}
}

- (void)processBookmark:(Bookmark *)bookmark
{
	NSString *baseDir = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@", bookmark.appname, bookmark.relname]];
	NSString *appDir = [[AppMobiDelegate appDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@", bookmark.appname, bookmark.relname]];
	NSString *payDir = [appDir stringByAppendingPathComponent:@"_payments"];
	if( NO == [[NSFileManager defaultManager] fileExistsAtPath:baseDir] ) [[NSFileManager defaultManager] createDirectoryAtPath:baseDir withIntermediateDirectories:YES attributes:nil error:nil];
	if( NO == [[NSFileManager defaultManager] fileExistsAtPath:appDir] ) [[NSFileManager defaultManager] createDirectoryAtPath:appDir withIntermediateDirectories:YES attributes:nil error:nil];
	if( NO == [[NSFileManager defaultManager] fileExistsAtPath:payDir] ) [[NSFileManager defaultManager] createDirectoryAtPath:payDir withIntermediateDirectories:YES attributes:nil error:nil];
	
	NSString *image1File = [baseDir stringByAppendingPathComponent:[NSString stringWithFormat:@"merchant.png"]];
	NSString *image2File = [payDir stringByAppendingPathComponent:[NSString stringWithFormat:@"merchant.png"]];
    if( bookmark.imageurl == nil && bookmark.appconfig.siteIcon != nil )
    {
        bookmark.imageurl = [bookmark.appconfig.siteIcon copy];
    }
	if( bookmark.imageurl != nil && [[NSFileManager defaultManager] fileExistsAtPath:image1File] == NO )
	{
		NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:bookmark.imageurl]];
		// Needs revisited to hanlde retries
		if( data == nil )
		{
			data = [NSData dataWithContentsOfURL:[NSURL URLWithString:bookmark.imageurl]];
		}
		if( data == nil )
		{
			data = [NSData dataWithContentsOfURL:[NSURL URLWithString:bookmark.imageurl]];
		}
		if( data != nil && [data length] > 0 )
		{
			[[NSFileManager defaultManager] createFileAtPath:image1File contents:data attributes:nil];
			[[NSFileManager defaultManager] createFileAtPath:image2File contents:data attributes:nil];
		}
	}
}

- (void)parseBookmarks:(id)sender
{
	BookmarkConfig *currentConfig = (BookmarkConfig *) sender;
	BookmarkConfigParser *parser = [[BookmarkConfigParser alloc] init];
	NSString *bookConfigPath = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:@"bookmarks.xml"];
	NSXMLParser *xmlParser = [NSXMLParser alloc];
	NSURL *bookConfigUrl = [NSURL fileURLWithPath: bookConfigPath];
	
	//parse config
	parser.configBeingParsed = currentConfig;
	[xmlParser initWithContentsOfURL:bookConfigUrl];
	[xmlParser setDelegate:parser];
	[xmlParser parse];
	
	// Cache images locally
	for( int i = 0; i < [currentConfig.bookmarks count]; i++ )
	{
		Bookmark *bookmark = (Bookmark *) [currentConfig.bookmarks objectAtIndex:i];
		bookmark.isFeatured = YES;
		[self processBookmark:bookmark];
		
		NSString *baseDir = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@", bookmark.appname, bookmark.relname]];
		NSString *configFile = [baseDir stringByAppendingPathComponent:[NSString stringWithFormat:@"appconfig.xml"]];
		if( bookmark.appconfigurl != nil && [[NSFileManager defaultManager] fileExistsAtPath:configFile] == NO )
		{
			NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:bookmark.appconfigurl]];
			if( data != nil && [data length] > 0 )
			{
				[[NSFileManager defaultManager] createFileAtPath:configFile contents:data attributes:nil];
			}
		}

		if( YES == [[NSFileManager defaultManager] fileExistsAtPath:configFile] )
		{
			AppConfig *config = [self parseAppConfig:configFile];
			if( config.bParsed == YES )
			{
				bookmark.appconfig = config;
			}
		}
	}
}

- (void)reupdateBookmarks:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *bmarksfile = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:@"bookmarks.dat"];
	NSString *bmarksxml = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:@"bookmarks.xml"];
	
	NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"https://services.appmobi.com/external/clientservices.aspx?feed=getbrowserbookmarks&featured=1"]];
	if( NO && data != nil && [data length] > 0 )
	{ // temporarily turn off updates
		NSError *error;
		[[NSFileManager defaultManager] removeItemAtPath:bmarksxml error:&error];
		[[NSFileManager defaultManager] createFileAtPath:bmarksxml contents:data attributes:nil];
		
		BookmarkConfig *newbmarks = [[BookmarkConfig alloc] init];
		[self parseBookmarks:newbmarks];
		[[NSFileManager defaultManager] removeItemAtPath:bmarksxml error:nil];

		if( newbmarks.sequence > bookSequence )
		{
			bookSequence = newbmarks.sequence;
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			[defaults setInteger:bookSequence forKey:@"bookSequence"];
			[defaults synchronize];
			
			NSMutableDictionary *dictMarks = [[[NSMutableDictionary alloc] initWithCapacity:[newbmarks.bookmarks count]] autorelease];
			for( int i = 0; i < [_bookconfig.bookmarks count]; i++ )
			{
				Bookmark *bookmark = [_bookconfig.bookmarks objectAtIndex:i];
				bookmark.isFeatured = YES;
				[dictMarks setObject:bookmark forKey:bookmark.appname];
			}
			
			for( int i = 0; i < [newbmarks.bookmarks count]; i++ )
			{
				Bookmark *bookmark = [newbmarks.bookmarks objectAtIndex:i];
				Bookmark *oldmark = [dictMarks objectForKey:bookmark.appname];
				if( oldmark == nil )
				{
					[_bookconfig.bookmarks addObject:bookmark];
				}
			}
			
			[[NSFileManager defaultManager] removeItemAtPath:bmarksfile error:nil];
			[NSKeyedArchiver archiveRootObject:_bookconfig.bookmarks toFile:bmarksfile];
			
			[viewController performSelectorOnMainThread:@selector(refreshBookmarks:) withObject:nil waitUntilDone:NO];
		}
	}
	
	// add stuff here to force a block and instant update of featured bookmarks
	
	[pool release];
}

- (void)bookmarkWorker:(id)sender
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	int count = 0;
	while( strDeviceToken == nil && count < 24 )
	{
        [NSThread sleepForTimeInterval:0.25];
		count++;
	}
	
	BOOL refresh = NO;
	AppMobiNotification *notification = (AppMobiNotification *) [pushView getCommandInstance:@"AppMobiNotification"];
	NSMutableArray *bookmarks = _bookconfig.bookmarks;
	for( int i = 0; i < [bookmarks count]; i++ )
	{
		Bookmark *bookmark = (Bookmark *) [bookmarks objectAtIndex:i];
		if( bookmark.isUserFav == NO && bookmark.appconfig.siteIcon != nil )
		{
			NSString *iconFile = [bookmark.appconfig.baseDirectory stringByAppendingPathComponent:@"merchant.png"];
			if( NO == [[NSFileManager defaultManager] fileExistsAtPath:iconFile] )
			{
				NSData *iconData = [NSData dataWithContentsOfURL:[NSURL URLWithString:bookmark.appconfig.siteIcon]];
				if( iconData != nil && [iconData length] > 0 )
				{
					refresh = YES;
					[[NSFileManager defaultManager] createFileAtPath:iconFile contents:iconData attributes:nil];
				}
			}
		}
		if( bookmark.hasPushOn == YES && bookmark.isInstalled == YES && strDeviceToken != nil )
		{
			NSString *userID = [NSString stringWithFormat:@"mobius.%@", [[UIDevice currentDevice] uniqueIdentifier]];
			NSString *password = @"m4rc1s4w3f41l";
			NSString *email = [NSString stringWithFormat:@"%@@appmobi.com", userID];
			NSMutableArray *arguments = [NSMutableArray arrayWithObjects:userID, password, email, nil];
			
			[arguments addObject:bookmark.appconfig.appName];
			AMSResponse *response = [notification addPushUserInternal:arguments withDict:nil];
			if( response != nil && [response.result isEqualToString:@"ok"] == NO )
			{
				response = [notification checkPushUserInternal:arguments withDict:nil];
			}
			[notification registerDevice:strDeviceToken withJSEvent:NO forApp:bookmark.appconfig.appName];
		}
	}
	
	if( refresh == YES ) [viewController performSelectorOnMainThread:@selector(redrawBookmarks:) withObject:nil waitUntilDone:NO];
	
	[pool release];
}

- (void)runMobiusApplication:(NSString *)appname andRelease:(NSString *)relname
{	
	Bookmark *appmark;
	NSString *configFile = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/appconfig.xml", urlApp, urlRel]];
	if( [[NSFileManager defaultManager] fileExistsAtPath:configFile] == NO )
	{
		[self downloadAppConfig:urlApp andRel:urlRel andPkg:@"PRODUCTION"];
		
		AppConfig *newConfig = [self parseAppConfig:configFile];
        BOOL hasSiteConfig = ( newConfig != nil && newConfig.siteIcon != nil && newConfig.siteName != nil && newConfig.siteBook != nil );
		if( newConfig == nil || newConfig.bParsed == NO || hasSiteConfig == NO )
		{
			isMobiusInstall = NO;
			isProtocolHandler = NO;
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"mobiUs Error" message:@"The specified config could not be found. Please contact your vendor." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
			[alert show];
			[alert release];			
			return;
		}
		
		appmark = [[Bookmark alloc] init];
		appmark.url = newConfig.siteURL;
		appmark.name = newConfig.siteName;
		appmark.appconfig = newConfig;
		appmark.appname = newConfig.appName;
		appmark.relname = newConfig.relName;
		appmark.isApplication = YES;
		appmark.isInstalled = YES;
		appmark.hasPushOn = YES;
		[_bookconfig.bookmarks addObject:appmark];
        [self processBookmark:appmark];
        [self installJavascript:newConfig];
		
		NSString *bmarksfile = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:@"bookmarks.dat"];
		[NSKeyedArchiver archiveRootObject:_bookconfig.bookmarks toFile:bmarksfile];
		
		[viewController performSelectorOnMainThread:@selector(refreshBookmarks:) withObject:nil waitUntilDone:NO];
	}
	else
	{
		for( int i = 0; i < [_bookconfig.bookmarks count]; i++ )
		{
			Bookmark *book = (Bookmark *) [_bookconfig.bookmarks objectAtIndex:i];
			if( book.appname != nil && [book.appname compare:urlApp] == NSOrderedSame && [book.relname compare:urlRel] == NSOrderedSame )
			{
				appmark = book;
				break;
			}
		}
	}
	
	[AppMobiViewController masterViewController]._runBmk = appmark;
	if( [appmark.appconfig.appType compare:@"SITE"] == NSOrderedSame )
		[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(onRunSite:) withObject:nil waitUntilDone:NO];
	else
		[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(onRunApp:) withObject:nil waitUntilDone:NO];
	
	if( isPushStart == YES && bHiddenPush == NO )
	{
		AppMobiViewController *vc = [AppMobiViewController masterViewController];
		AppMobiNotification *notification = (AppMobiNotification *) [pushView getCommandInstance:@"AppMobiNotification"];
		[vc showPushViewer:appmark.appconfig forNotification:notification];
		
		if( vc.modalViewController != nil )
		{
			UINavigationController *navc = (UINavigationController *) vc.modalViewController;
			AppMobiPushViewController *pushvc = (AppMobiPushViewController *) [navc topViewController];
			pushvc.bLoading = YES;
			[pushvc performSelectorOnMainThread:@selector(reload:) withObject:nil waitUntilDone:NO];
		}
		isPushStart = NO;
	}
    bHiddenPush = NO;
}

- (void)mobiusWorker:(id)sender
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Extract "mobius.app" if needed
	bStartup = NO;
	if( [appName length] == 0 )
	{
		[self extractInitialApp];
	}
	else
	{
		NSString *appConfig = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/appconfig.xml", appName, relName]];
		if( _config == nil )
		{
			self._config = [self parseAppConfig:appConfig];
		}
	}
	
	// Make sure payments is extracted
	NSString *payConfig = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/appconfig.xml", payApp, payRel]];
	if( NO == [[NSFileManager defaultManager] fileExistsAtPath:payConfig] )
	{
		[self installPayments];
	}
	
	NSString *bmarksfile = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:@"bookmarks.dat"];
	if( [[NSFileManager defaultManager] fileExistsAtPath:bmarksfile] == NO )
	{
		NSString *bundleXML = [[NSBundle mainBundle] pathForResource:@"bookmarks" ofType:@"xml"];
		NSString *moduleXML = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:@"bookmarks.xml"];
		
		[[NSFileManager defaultManager] copyItemAtPath:bundleXML toPath:moduleXML error:nil];

		_bookconfig = [[BookmarkConfig alloc] init];
		[self parseBookmarks:_bookconfig];
		bookSequence = _bookconfig.sequence;
		[NSKeyedArchiver archiveRootObject:_bookconfig.bookmarks toFile:bmarksfile];
		[[NSFileManager defaultManager] removeItemAtPath:moduleXML error:nil];
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setInteger:bookSequence forKey:@"bookSequence"];
		[defaults synchronize];
	}
	else
	{
		_bookconfig = [[BookmarkConfig alloc] init];
		_bookconfig.bookmarks = [[NSKeyedUnarchiver unarchiveObjectWithFile:bmarksfile] retain];
	}
	
	// [NSThread detachNewThreadSelector:@selector(reupdateBookmarks:) toTarget:self withObject:nil];
	[viewController performSelectorOnMainThread:@selector(refreshBookmarks:) withObject:nil waitUntilDone:NO];

	[NSThread detachNewThreadSelector:@selector(updateWorker:) toTarget:self withObject:nil];
	[NSThread detachNewThreadSelector:@selector(setupPushWorker:) toTarget:self withObject:_config];	
		
	if( isProtocolHandler == YES )
	{
		if( [[urlCmd uppercaseString] compare:@"RUNAPP"] == NSOrderedSame )
		{
			[self runMobiusApplication:urlApp andRelease:urlRel];
		}
		
		if( [[urlCmd uppercaseString] compare:@"RUNSITE"] == NSOrderedSame )
		{
			[AppMobiViewController masterViewController].runUrl = [urlUrl copy];
			[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(onRunSite:) withObject:nil waitUntilDone:NO];
		}
	}
	
	[self performSelectorOnMainThread:@selector(hideSplashScreen:) withObject:nil waitUntilDone:NO];
	[NSThread detachNewThreadSelector:@selector(configWorker:) toTarget:self withObject:nil];
	
	[pool release];
}

- (AppConfig *)parseAppConfig:(NSString *)configPath
{
	if( [[NSFileManager defaultManager] fileExistsAtPath:configPath] == NO ) return nil;

	AppConfig *config = [[AppConfig alloc] init];
	NSXMLParser *xmlParser = [NSXMLParser alloc];
	NSURL *appConfigUrl = [NSURL fileURLWithPath:configPath];
	AppConfigParser *parser = [[AppConfigParser alloc] init];

	//parse config
	parser.configBeingParsed = config;
	[xmlParser initWithContentsOfURL:appConfigUrl];
	[xmlParser setDelegate:parser];
	config.bParsed = [xmlParser parse];
	[parser release];
	if(config.bParsed) {
		//check that minimum set of values is present
		config.bParsed = (config.appName!=nil && config.relName!=nil && config.bundleURL!=nil);
	}
	
	return config;
}

- (void)downloadBundleWithProgress:(Bookmark *)bookmark
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *url = bookmark.appconfig.bundleURL;
    
	NSMutableURLRequest *urlRequest = nil;
	
    urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLCacheStorageNotAllowed timeoutInterval:60];
    
    DownloadDelegate *del = [[DownloadDelegate alloc] init];
	NSString *bundleFile = [bookmark.appconfig.baseDirectory stringByAppendingPathComponent:@"newbundle.zip"];
    del.bookmark = bookmark;
    del.strBundle = bundleFile;
    del.lastUpdateTime = [[NSDate date] timeIntervalSince1970] - 0.8;
    [[NSURLConnection connectionWithRequest:urlRequest delegate:del] retain];
    while( !del.bDone )
    {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
    }
    
    BOOL ok = [self installUpdate:bookmark.appconfig];
    ok = ok & del.bSuccess;
    [[AppMobiViewController masterViewController] statusInstall:bookmark withSuccess:ok];
	
	[pool release];
}

- (BOOL)downloadBundle:(AppConfig *)appconfig
{
	if( appconfig.bundleURL == nil ) return NO;
	
	NSURLResponse *response;
	NSError *error = nil;
	NSMutableData *receivedData = [[NSMutableData alloc] initWithLength:0];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:appconfig.bundleURL] cachePolicy:NSURLCacheStorageNotAllowed timeoutInterval:20];
	NSData *result = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	
	if( result == nil || [result length] == 0 ) return NO;
	[receivedData appendData:result];

	NSString *bundleFile = [appconfig.baseDirectory stringByAppendingPathComponent:@"newbundle.zip"];
	BOOL ok = [[NSFileManager defaultManager] createFileAtPath:bundleFile contents:receivedData attributes:nil];
	if( ok == NO ) return NO;
	
	return YES;
}

- (BOOL)downloadUpdate:(AppConfig *)appconfig
{
	int servicesVersion = appconfig.servicesVersion;
	int paymentsVersion = appconfig.paymentsVersion;
	NSData *configData = [NSData dataWithContentsOfURL:[NSURL URLWithString:appconfig.configURL]];
	if( configData == nil || [configData length] == 0 ) return NO;
	
	NSError *error = nil;
	NSString *configFile = [appconfig.baseDirectory stringByAppendingPathComponent:@"newappconfig.xml"];
	if( [[NSFileManager defaultManager] fileExistsAtPath:configFile] == YES ) [[NSFileManager defaultManager] removeItemAtPath:configFile error:&error];
	BOOL ok = [[NSFileManager defaultManager] createFileAtPath:configFile contents:configData attributes:nil];
	if( ok == NO ) return NO;
	
	AppConfig *newConfig = [self parseAppConfig:configFile];
	
	if( newConfig.bParsed == NO )
	{
		[[NSFileManager defaultManager] removeItemAtPath:configFile error:&error];
		return NO;
	}
	
	if( newConfig.hasOAuth == YES && newConfig.servicesURL != nil )
	{
		NSString *servicesFile = [newConfig.baseDirectory stringByAppendingPathComponent:@"services.xml"];
		if( [[NSFileManager defaultManager] fileExistsAtPath:servicesFile] == NO || newConfig.servicesVersion > servicesVersion )
		{		
			NSData *servicesData = [NSData dataWithContentsOfURL:[NSURL URLWithString:appconfig.servicesURL]];
			if( [[NSFileManager defaultManager] fileExistsAtPath:servicesFile] == YES ) [[NSFileManager defaultManager] removeItemAtPath:servicesFile error:&error];
			if( servicesData != nil || [servicesData length] > 0 )
			{
				BOOL ok = [[NSFileManager defaultManager] createFileAtPath:servicesFile contents:servicesData attributes:nil];
				if( ok == NO ) return NO;
			}
		}
	}
	
	if( newConfig.hasPayments == YES && newConfig.paymentsURL != nil )
	{
		NSString *paymentsFile = [newConfig.baseDirectory stringByAppendingPathComponent:@"payments.xml"];
		if( [[NSFileManager defaultManager] fileExistsAtPath:paymentsFile] == NO || newConfig.paymentsVersion > paymentsVersion )
		{		
			NSData *paymentsData = [NSData dataWithContentsOfURL:[NSURL URLWithString:appconfig.paymentsURL]];
			if( [[NSFileManager defaultManager] fileExistsAtPath:paymentsFile] == YES ) [[NSFileManager defaultManager] removeItemAtPath:paymentsFile error:&error];
			if( paymentsData != nil || [paymentsData length] > 0 )
			{
				BOOL ok = [[NSFileManager defaultManager] createFileAtPath:paymentsFile contents:paymentsData attributes:nil];
				if( ok == NO ) return NO;
			}
		}
	}
	
	BOOL isNewVersionAvailable = newConfig.appVersion > appconfig.appVersion;
	if( isNewVersionAvailable == NO )
	{
		configFile = [appconfig.baseDirectory stringByAppendingPathComponent:@"newappconfig.xml"];
		if( [[NSFileManager defaultManager] fileExistsAtPath:configFile] == YES ) [[NSFileManager defaultManager] removeItemAtPath:configFile error:&error];
		
		configFile = [appconfig.baseDirectory stringByAppendingPathComponent:@"appconfig.xml"];
		if( [[NSFileManager defaultManager] fileExistsAtPath:configFile] == YES ) [[NSFileManager defaultManager] removeItemAtPath:configFile error:&error];
		ok = [[NSFileManager defaultManager] createFileAtPath:configFile contents:configData attributes:nil];
		if( ok == NO ) return NO;
		
		return NO;
	}
	if( webView != nil ) [webView autoLogEvent:@"/device/update/available.event" withQuery:nil];

	ok = [self downloadBundle:newConfig];
	if( ok == NO )
	{
		configFile = [appconfig.baseDirectory stringByAppendingPathComponent:@"newappconfig.xml"];
		[[NSFileManager defaultManager] removeItemAtPath:configFile error:&error];
		return NO;
	}
	if( webView != nil ) [webView autoLogEvent:@"/device/update/download.event" withQuery:nil];

	return YES;
}

- (BOOL)updateAvailable:(AppConfig *)appconfig
{
	NSString *configFile = [appconfig.baseDirectory stringByAppendingPathComponent:@"newappconfig.xml"];
	NSString *bundleFile = [appconfig.baseDirectory stringByAppendingPathComponent:@"newbundle.zip"];

	return ( [[NSFileManager defaultManager] fileExistsAtPath:configFile] && [[NSFileManager defaultManager] fileExistsAtPath:bundleFile] );
}

- (BOOL)installJavascript:(AppConfig *)appconfig
{
	NSError *error = nil;
	NSString *appMobiDir = [appconfig.appDirectory stringByAppendingPathComponent:@"_appMobi"];
	if( NO == [[NSFileManager defaultManager] fileExistsAtPath:appMobiDir] )
		[[NSFileManager defaultManager] createDirectoryAtPath:appMobiDir withIntermediateDirectories:YES attributes:nil error:&error];
	
	BOOL isDebug = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"BundledJavascript"] boolValue];
	
	BOOL ok = NO;
	NSString *jsFile = [appMobiDir stringByAppendingPathComponent:@"appmobi.js"];
	if( appconfig.jsURL != nil && !isDebug ) //if debugging, always use local js
	{
		NSData *jsData = [NSData dataWithContentsOfURL:[NSURL URLWithString:appconfig.jsURL]];
		if( jsData != nil && [jsData length] > 0 )
		{
			ok = [[NSFileManager defaultManager] createFileAtPath:jsFile contents:jsData attributes:nil];
			if( ok == NO ) return NO;
		}
		else
		{
			AMLog(@"unable to retrieve appmobi.js from server config");
			return NO;
		}
	}
	else
	{
		NSString *jsBundle = [[NSBundle mainBundle] pathForResource:@"appmobi_iphone" ofType:@"js"];
		
		if( YES == [[NSFileManager defaultManager] fileExistsAtPath:jsFile] ) [[NSFileManager defaultManager] removeItemAtPath:jsFile error:&error];
		if( jsBundle == nil || [[NSFileManager defaultManager] copyItemAtPath:jsBundle toPath:jsFile error:&error] != YES )
		{
			AMLog(@"Unable to move file: %@", [error localizedDescription]);
			return NO;
		}
	}
	
	//module support: extract module javascripts listed in info.plist from bundle
	NSArray* jsToCopy = [NSMutableArray arrayWithArray:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"javascripts"]];
	for (NSString* js in jsToCopy) {
		
		NSString *bundleJS = [[NSBundle mainBundle] pathForResource:js ofType:@"js"];
		NSString *moduleJS = [appMobiDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.js",js]];
		
		if( YES == [[NSFileManager defaultManager] fileExistsAtPath:moduleJS] ) [[NSFileManager defaultManager] removeItemAtPath:moduleJS error:&error];
		if( bundleJS == nil || [[NSFileManager defaultManager] copyItemAtPath:bundleJS toPath:moduleJS error:&error] != YES )
		{
			AMLog(@"Unable to move file '%@.js': %@", js, [error localizedDescription]);
			return NO;
		}
	}
	
    //
    //direct canvas support - copy contents of directcanvassupport into Impact plugins directory
    //
	NSString *impactPluginsDirDest = [appconfig.appDirectory stringByAppendingPathComponent:@"lib/plugins"];
    //create @appDir/lib/plugins if it is missing
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:impactPluginsDirDest]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:impactPluginsDirDest withIntermediateDirectories:YES attributes:nil error:nil];
    }
	NSString *impactPluginsDirSrc = [[NSBundle mainBundle] pathForResource:@"directcanvassupport/impactplugins" ofType:nil];
	//get list of files to copy
	NSDirectoryEnumerator *eToCopy = [[NSFileManager defaultManager] enumeratorAtPath:impactPluginsDirSrc];
	NSString* file;
	while((file = [eToCopy nextObject])) {
		NSString * fileWithPath = [impactPluginsDirDest stringByAppendingPathComponent:file]; 
		//if the file already exists, delete it
		if ([[NSFileManager defaultManager] fileExistsAtPath:fileWithPath]) {
			[[NSFileManager defaultManager] removeItemAtPath:fileWithPath error:nil];
		}
		//copy the file from the bundle to the appDir
		[[NSFileManager defaultManager] copyItemAtPath:[impactPluginsDirSrc stringByAppendingPathComponent:file] toPath:fileWithPath error:&error];
    }    
	
    //check for skinnable assets
	NSString *adLoadingBundle = [[NSBundle mainBundle] pathForResource:@"ad_loading" ofType:@"gif"];
	NSString *adLoadingTarget = [appMobiDir stringByAppendingPathComponent:@"ad_loading.gif"];
	if( [[NSFileManager defaultManager] fileExistsAtPath:adLoadingBundle] && ![[NSFileManager defaultManager] fileExistsAtPath:adLoadingTarget] )
	{
		ok = [[NSFileManager defaultManager] copyItemAtPath:adLoadingBundle toPath:adLoadingTarget error:&error];
		if( ok == NO ) return NO;
	}
	
	NSString *iconFile = [appconfig.baseDirectory stringByAppendingPathComponent:@"merchant.png"];
	if( appconfig.hasPayments == YES && [[NSFileManager defaultManager] fileExistsAtPath:iconFile] == NO )
	{
		NSString *bundleIcon = [[NSBundle mainBundle] pathForResource:@"icon_ipad" ofType:@"png"];
		if( bundleIcon == nil || [[NSFileManager defaultManager] copyItemAtPath:bundleIcon toPath:iconFile error:&error] != YES )
		{
			AMLog(@"Unable to move file 'icon_ipad.png': %@", [error localizedDescription]);
			return NO;
		}	
	}
	
	if( appconfig.hasPayments == YES && [[NSFileManager defaultManager] fileExistsAtPath:iconFile] == YES )
	{
		NSString *paymentsDir = [appconfig.appDirectory stringByAppendingPathComponent:@"_payments"];
		NSString *merchantFile = [paymentsDir stringByAppendingPathComponent:@"merchant.png"];
		if( NO == [[NSFileManager defaultManager] fileExistsAtPath:paymentsDir] )
			[[NSFileManager defaultManager] createDirectoryAtPath:paymentsDir withIntermediateDirectories:YES attributes:nil error:&error];

		if( YES == [[NSFileManager defaultManager] fileExistsAtPath:merchantFile] ) [[NSFileManager defaultManager] removeItemAtPath:merchantFile error:&error];
		ok = [[NSFileManager defaultManager] copyItemAtPath:iconFile toPath:merchantFile error:&error];
		if( ok == NO ) return NO;
	}	
	
	return YES;
}

- (BOOL)installUpdate:(AppConfig *)appconfig
{
	NSError *error = nil;
	NSString *appDir = [appconfig.baseDirectory copy];
	NSString *bundleFile = [appDir stringByAppendingPathComponent:@"newbundle.zip"];
	NSString *configFile = [appDir stringByAppendingPathComponent:@"newappconfig.xml"];
	NSString *oldconfigFile = [appDir stringByAppendingPathComponent:@"appconfig.xml"];
	
	if( [[NSFileManager defaultManager] fileExistsAtPath:bundleFile] == NO ) return NO;

	NSString *appcacheDir = [appconfig.appDirectory copy];
	NSString *adcacheDir = [appcacheDir stringByAppendingPathComponent:@"_adcache"];
	NSString *adcacheTemp = [appDir stringByAppendingPathComponent:@"_adcachetemp"];
	NSString *mediacacheDir = [appcacheDir stringByAppendingPathComponent:@"_mediacache"];
	NSString *mediacacheTemp = [appDir stringByAppendingPathComponent:@"_mediacachetemp"];
	NSString *picturesDir = [appcacheDir stringByAppendingPathComponent:@"_pictures"];
	NSString *picturesTemp = [appDir stringByAppendingPathComponent:@"_picturestemp"];
	NSString *recordingsDir = [appcacheDir stringByAppendingPathComponent:@"_recordings"];
	NSString *recordingsTemp = [appDir stringByAppendingPathComponent:@"_recordingstemp"];
	NSString *paymentsDir = [appcacheDir stringByAppendingPathComponent:@"_payments"];
	NSString *paymentsTemp = [appDir stringByAppendingPathComponent:@"_paymentstemp"];
	
	if( [[NSFileManager defaultManager] fileExistsAtPath:adcacheDir] == YES ) [[NSFileManager defaultManager] moveItemAtPath:adcacheDir toPath:adcacheTemp error:&error];
	if( [[NSFileManager defaultManager] fileExistsAtPath:mediacacheDir] == YES ) [[NSFileManager defaultManager] moveItemAtPath:mediacacheDir toPath:mediacacheTemp error:&error];
	if( [[NSFileManager defaultManager] fileExistsAtPath:picturesDir] == YES ) [[NSFileManager defaultManager] moveItemAtPath:picturesDir toPath:picturesTemp error:&error];
	if( [[NSFileManager defaultManager] fileExistsAtPath:recordingsDir] == YES ) [[NSFileManager defaultManager] moveItemAtPath:recordingsDir toPath:recordingsTemp error:&error];
	if( [[NSFileManager defaultManager] fileExistsAtPath:paymentsDir] == YES ) [[NSFileManager defaultManager] moveItemAtPath:paymentsDir toPath:paymentsTemp error:&error];
	
	if( [[NSFileManager defaultManager] fileExistsAtPath:appcacheDir] == YES ) [[NSFileManager defaultManager] removeItemAtPath:appcacheDir error:&error];
	[[NSFileManager defaultManager] createDirectoryAtPath:appcacheDir withIntermediateDirectories:YES attributes:nil error:&error];
	
	ZipArchive *za = [[ZipArchive alloc] init];
	if ([za UnzipOpenFile:bundleFile]) {
		BOOL ret = [za UnzipFileTo:appcacheDir overWrite:YES];
		if (NO == ret){} [za UnzipCloseFile];
	}
	[za release];

	if( [[NSFileManager defaultManager] fileExistsAtPath:adcacheTemp] == YES ) [[NSFileManager defaultManager] moveItemAtPath:adcacheTemp toPath:adcacheDir error:&error];
	if( [[NSFileManager defaultManager] fileExistsAtPath:mediacacheTemp] == YES ) [[NSFileManager defaultManager] moveItemAtPath:mediacacheTemp toPath:mediacacheDir error:&error];
	if( [[NSFileManager defaultManager] fileExistsAtPath:picturesTemp] == YES ) [[NSFileManager defaultManager] moveItemAtPath:picturesTemp toPath:picturesDir error:&error];
	if( [[NSFileManager defaultManager] fileExistsAtPath:recordingsTemp] == YES ) [[NSFileManager defaultManager] moveItemAtPath:recordingsTemp toPath:recordingsDir error:&error];
	if( [[NSFileManager defaultManager] fileExistsAtPath:paymentsTemp] == YES ) [[NSFileManager defaultManager] moveItemAtPath:paymentsTemp toPath:paymentsDir error:&error];
	
	//validate bundle contents
	if ([[NSFileManager defaultManager] fileExistsAtPath:[appcacheDir stringByAppendingPathComponent:@"index.html"]] == NO) {
		//check if bundle contents are inside a top-level directory -- if so, move top-level directory contents into root
		//get list of contents in appMobiCache
		NSArray *array = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appcacheDir error:&error];
		NSArray *ignoreList = [NSArray arrayWithObjects:@"_adcache", @"_pictures", @"_recordings", @"_payments", @"_mediacache", @"_appMobi", @"__MACOSX", nil];
		
		int dirCount = 0;
		NSString *path;
		for(int i=0;i<[array count];i++) {
			if(![ignoreList containsObject:[array objectAtIndex:i]]) {
				path = [appcacheDir stringByAppendingPathComponent:[array objectAtIndex:i]];
				dirCount++;
			}
		}
		BOOL isDir;
		//is it a directory with an index.html inside?
		if(dirCount==1 && [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir && [[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:@"index.html"]]) {
			//move to a temp folder, delete top-level directory, then move contents into root
			//create temp folder
			NSString *tempPath = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:@"temp"];
			[[NSFileManager defaultManager] createDirectoryAtPath:tempPath withIntermediateDirectories:YES attributes:nil error:&error];
			//get list of files to move
			array = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
			//move files to temp folder
			for(int i=0;i<[array count];i++) {
				NSString *file = [array objectAtIndex:i];
				[[NSFileManager defaultManager] moveItemAtPath:[path stringByAppendingPathComponent:file] toPath:[tempPath stringByAppendingPathComponent:file] error:&error];
			}
			//delete top-level directory
			[[NSFileManager defaultManager] removeItemAtPath:path error:&error];
			//move content into root
			array = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:tempPath error:&error];
			//move files to temp folder
			for(int i=0;i<[array count];i++) {
				NSString *file = [array objectAtIndex:i];
				[[NSFileManager defaultManager] copyItemAtPath:[tempPath stringByAppendingPathComponent:file] toPath:[appcacheDir stringByAppendingPathComponent:file] error:&error];
			}
			//delete temporary directory
			[[NSFileManager defaultManager] removeItemAtPath:tempPath error:&error];
		} else {
			AMLog(@"missing index.html -- can't be moved up");
			return NO;
		}
	}

	//delete bundle
	[[NSFileManager defaultManager] removeItemAtPath:bundleFile error:&error];
	[[NSFileManager defaultManager] removeItemAtPath:oldconfigFile error:&error];
	[[NSFileManager defaultManager] moveItemAtPath:configFile toPath:oldconfigFile error:&error];
	
	BOOL ok = [self installJavascript:appconfig];
	if( ok == NO ) return NO;
	
	if( webView != nil ) [webView autoLogEvent:@"/device/update/install.event" withQuery:nil];

	//check for errors
	return YES;
}

- (BOOL)updateInitialApp
{
	NSError *error = nil;
	NSString *configBinary = [[NSBundle mainBundle] pathForResource:@"appconfig" ofType:@"xml"];
	if( configBinary != nil && [[NSFileManager defaultManager] fileExistsAtPath:configBinary] )
	{
		AppConfig *config = [self parseAppConfig:configBinary];
		if( config.bParsed == NO ) return NO;
		self._config = config;
		
		NSString *configFile = [_config.baseDirectory stringByAppendingPathComponent:@"newappconfig.xml"];
		[[NSFileManager defaultManager] copyItemAtPath:configBinary toPath:configFile error:&error];
		if( error != nil ) return NO;
	}
	else return NO;
	
	NSString *bundleBinary = [[NSBundle mainBundle] pathForResource:@"bundle" ofType:@"zip"];
	if( bundleBinary != nil && [[NSFileManager defaultManager] fileExistsAtPath:bundleBinary] )
	{
		NSString *bundleFile = [_config.baseDirectory stringByAppendingPathComponent:@"newbundle.zip"];		
		[[NSFileManager defaultManager] copyItemAtPath:bundleBinary toPath:bundleFile error:&error];
		if( error != nil ) return NO;
	}
	else return NO;
	
	return [self installUpdate:_config];
}

- (BOOL)extractInitialApp
{
	NSError *error = nil;
	NSString *configBinary = [[NSBundle mainBundle] pathForResource:@"appconfig" ofType:@"xml"];
	if( configBinary != nil && [[NSFileManager defaultManager] fileExistsAtPath:configBinary] )
	{
		AppConfig *config = [self parseAppConfig:configBinary];
		if( config.bParsed == NO ) return NO;
		self._config = config;
		
		self.appName = [_config.appName copy];
		self.relName = [_config.relName copy];
		self.pkgName = [_config.pkgName copy];
		
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setObject:appName forKey:@"appName"];
		[defaults setObject:relName forKey:@"relName"];
		[defaults setObject:pkgName forKey:@"pkgName"];
		[defaults setObject:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"versionCode"] forKey:@"versionCode"];
		[defaults synchronize];
		
		[[NSFileManager defaultManager] createDirectoryAtPath:_config.baseDirectory withIntermediateDirectories:YES attributes:nil error:&error];

		NSString *configFile = [_config.baseDirectory stringByAppendingPathComponent:@"appconfig.xml"];
		[[NSFileManager defaultManager] copyItemAtPath:configBinary toPath:configFile error:&error];
		if( error != nil ) return NO;
		
		configFile = [_config.baseDirectory stringByAppendingPathComponent:@"newappconfig.xml"];
		[[NSFileManager defaultManager] copyItemAtPath:configBinary toPath:configFile error:&error];
		if( error != nil ) return NO;
	}
	else return NO;
	
	NSString *bundleBinary = [[NSBundle mainBundle] pathForResource:@"bundle" ofType:@"zip"];
	if( bundleBinary != nil && [[NSFileManager defaultManager] fileExistsAtPath:bundleBinary] )
	{
		NSString *bundleFile = [_config.baseDirectory stringByAppendingPathComponent:@"newbundle.zip"];		
		[[NSFileManager defaultManager] copyItemAtPath:bundleBinary toPath:bundleFile error:&error];
		if( error != nil ) return NO;
	}
	else return NO;
	
	return [self installUpdate:_config];
}

- (BOOL)downloadAppConfig:(NSString *)appname andRel:(NSString *)relname andPkg:(NSString *)pkgname
{	
	NSString *baseDirectory = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@", appname, relname]];
	NSString *baseURL = @"https://services.appmobi.com/external/clientservices.aspx?feed=getappconfig&pw=";
	NSString *configURL = [baseURL stringByAppendingFormat:@"&app=%@&pkg=%@&rel=%@&redirect=1&platform=ios&deviceid=%@", appname, pkgname, relname, [[UIDevice currentDevice] uniqueIdentifier]];
	AMLog(@"%@",configURL);
	
	NSError *error = nil;
	NSData *configData = [NSData dataWithContentsOfURL:[NSURL URLWithString:configURL]];
	if( configData != nil && [configData length] > 0 )
	{
		[[NSFileManager defaultManager] removeItemAtPath:baseDirectory error:&error];
		[[NSFileManager defaultManager] createDirectoryAtPath:baseDirectory withIntermediateDirectories:YES attributes:nil error:&error];
		NSString *configFile = [baseDirectory stringByAppendingPathComponent:@"appconfig.xml"];
		BOOL ok = [[NSFileManager defaultManager] createFileAtPath:configFile contents:configData attributes:nil];
		if( ok == NO ) return NO;
		
		AppConfig *config = [self parseAppConfig:configFile];
		if( config.bParsed == NO ) return NO;
		self._config = config;
	}
	else return NO;
	
	return YES;
}

- (BOOL)downloadInitialApp:(NSString *)appname andRel:(NSString *)relname andPkg:(NSString *)pkgname
{	
	NSString *baseDirectory = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@", appname, relname]];
	NSString *baseURL = @"https://services.appmobi.com/external/clientservices.aspx?feed=getappconfig&pw=";
	NSString *configURL = [baseURL stringByAppendingFormat:@"&app=%@&pkg=%@&rel=%@&redirect=1&platform=ios&deviceid=%@", appname, pkgname, relname, [[UIDevice currentDevice] uniqueIdentifier]];
	AMLog(@"%@",configURL);

	NSError *error = nil;
	NSData *configData = [NSData dataWithContentsOfURL:[NSURL URLWithString:configURL]];
	if( configData != nil && [configData length] > 0 )
	{
		[[NSFileManager defaultManager] removeItemAtPath:baseDirectory error:&error];
		[[NSFileManager defaultManager] createDirectoryAtPath:baseDirectory withIntermediateDirectories:YES attributes:nil error:&error];
		NSString *configFile = [baseDirectory stringByAppendingPathComponent:@"appconfig.xml"];
		BOOL ok = [[NSFileManager defaultManager] createFileAtPath:configFile contents:configData attributes:nil];
		if( ok == NO ) return NO;
		
		AppConfig *config = [self parseAppConfig:configFile];
		if( config.bParsed == NO ) return NO;
		self._config = config;
		
		configFile = [_config.baseDirectory stringByAppendingPathComponent:@"newappconfig.xml"];
		ok = [[NSFileManager defaultManager] createFileAtPath:configFile contents:configData attributes:nil];
		if( ok == NO ) return NO;
	}
	else return NO;
	
	BOOL ok = [self downloadBundle:_config];
	if( ok == NO ) return NO;
	
	if( _config.hasPayments == YES && _config.paymentIcon != nil )
	{
		NSData *iconData = [NSData dataWithContentsOfURL:[NSURL URLWithString:_config.paymentIcon]];
		if( iconData != nil && [iconData length] > 0 )
		{
			NSString *iconFile = [_config.baseDirectory stringByAppendingPathComponent:@"merchant.png"];
			BOOL ok = [[NSFileManager defaultManager] createFileAtPath:iconFile contents:iconData attributes:nil];
			if( ok == NO ) return NO;
		}
	}
	
	if( _config.hasOAuth == YES && _config.servicesURL != nil && _config.servicesVersion > 0 )
	{
		NSData *servicesData = [NSData dataWithContentsOfURL:[NSURL URLWithString:_config.servicesURL]];
		NSString *servicesFile = [_config.baseDirectory stringByAppendingPathComponent:@"services.xml"];
		if( [[NSFileManager defaultManager] fileExistsAtPath:servicesFile] == YES ) [[NSFileManager defaultManager] removeItemAtPath:servicesFile error:&error];
		if( servicesData != nil || [servicesData length] > 0 )
		{
			BOOL ok = [[NSFileManager defaultManager] createFileAtPath:servicesFile contents:servicesData attributes:nil];
			if( ok == NO ) return NO;
		}
	}
	
	if( _config.hasPayments == YES && _config.paymentsURL != nil && _config.paymentsVersion > 0 )
	{
		NSData *paymentsData = [NSData dataWithContentsOfURL:[NSURL URLWithString:_config.paymentsURL]];
		NSString *paymentsFile = [_config.baseDirectory stringByAppendingPathComponent:@"payments.xml"];
		if( [[NSFileManager defaultManager] fileExistsAtPath:paymentsFile] == YES ) [[NSFileManager defaultManager] removeItemAtPath:paymentsFile error:&error];
		if( paymentsData != nil || [paymentsData length] > 0 )
		{
			BOOL ok = [[NSFileManager defaultManager] createFileAtPath:paymentsFile contents:paymentsData attributes:nil];
			if( ok == NO ) return NO;
		}
	}
	
	return [self installUpdate:_config];
}

- (BOOL)downloadCachedApp:(Bookmark *)bookmark
{
	NSError *error = nil;
    NSString *configFile = [bookmark.appconfig.baseDirectory stringByAppendingPathComponent:@"appconfig.xml"];
    NSString *newconfigFile = [bookmark.appconfig.baseDirectory stringByAppendingPathComponent:@"newappconfig.xml"];

    BOOL ok = [[NSFileManager defaultManager] copyItemAtPath:configFile toPath:newconfigFile error:&error];
    if( ok == NO ) return NO;
    
    // thread off downloading of the app
    [NSThread detachNewThreadSelector:@selector(downloadBundleWithProgress:) toTarget:self withObject:bookmark];
	
	if( bookmark.appconfig.hasPayments == YES && bookmark.appconfig.paymentIcon != nil )
	{
		NSData *iconData = [NSData dataWithContentsOfURL:[NSURL URLWithString:bookmark.appconfig.paymentIcon]];
		if( iconData != nil && [iconData length] > 0 )
		{
			NSString *iconFile = [bookmark.appconfig.baseDirectory stringByAppendingPathComponent:@"merchant.png"];
			BOOL ok = [[NSFileManager defaultManager] createFileAtPath:iconFile contents:iconData attributes:nil];
			if( ok == NO ) return NO;
		}
	}
	
	if( bookmark.appconfig.hasOAuth == YES && bookmark.appconfig.servicesURL != nil && bookmark.appconfig.servicesVersion > 0 )
	{
		NSData *servicesData = [NSData dataWithContentsOfURL:[NSURL URLWithString:bookmark.appconfig.servicesURL]];
		NSString *servicesFile = [bookmark.appconfig.baseDirectory stringByAppendingPathComponent:@"services.xml"];
		if( [[NSFileManager defaultManager] fileExistsAtPath:servicesFile] == YES ) [[NSFileManager defaultManager] removeItemAtPath:servicesFile error:&error];
		if( servicesData != nil || [servicesData length] > 0 )
		{
			BOOL ok = [[NSFileManager defaultManager] createFileAtPath:servicesFile contents:servicesData attributes:nil];
			if( ok == NO ) return NO;
		}
	}
	
	if( bookmark.appconfig.hasPayments == YES && bookmark.appconfig.paymentsURL != nil && bookmark.appconfig.paymentsVersion > 0 )
	{
		NSData *paymentsData = [NSData dataWithContentsOfURL:[NSURL URLWithString:bookmark.appconfig.paymentsURL]];
		NSString *paymentsFile = [bookmark.appconfig.baseDirectory stringByAppendingPathComponent:@"payments.xml"];
		if( [[NSFileManager defaultManager] fileExistsAtPath:paymentsFile] == YES ) [[NSFileManager defaultManager] removeItemAtPath:paymentsFile error:&error];
		if( paymentsData != nil || [paymentsData length] > 0 )
		{
			BOOL ok = [[NSFileManager defaultManager] createFileAtPath:paymentsFile contents:paymentsData attributes:nil];
			if( ok == NO ) return NO;
		}
	}
    
    return ok;
}

- (BOOL)installPayments
{
	NSString *payConfig = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/appconfig.xml", payApp, payRel]];
	if( YES == [[NSFileManager defaultManager] fileExistsAtPath:payConfig] ) return YES;
	
	NSError *error = nil;
	NSString *configBinary = [[NSBundle mainBundle] pathForResource:@"payappconfig" ofType:@"xml"];
	if( configBinary != nil && [[NSFileManager defaultManager] fileExistsAtPath:configBinary] )
	{
		AppConfig *config = [self parseAppConfig:configBinary];
		if( config.bParsed == NO ) return NO;
		self._payconfig = config;
		
		[[NSFileManager defaultManager] createDirectoryAtPath:_payconfig.baseDirectory withIntermediateDirectories:YES attributes:nil error:&error];
		
		NSString *configFile = [_payconfig.baseDirectory stringByAppendingPathComponent:@"appconfig.xml"];
		[[NSFileManager defaultManager] copyItemAtPath:configBinary toPath:configFile error:&error];
		if( error != nil ) return NO;
		
		configFile = [_payconfig.baseDirectory stringByAppendingPathComponent:@"newappconfig.xml"];
		[[NSFileManager defaultManager] copyItemAtPath:configBinary toPath:configFile error:&error];
		if( error != nil ) return NO;
	}
	else return NO;
	
	NSString *bundleBinary = [[NSBundle mainBundle] pathForResource:@"paybundle" ofType:@"zip"];
	if( bundleBinary != nil && [[NSFileManager defaultManager] fileExistsAtPath:bundleBinary] )
	{
		NSString *bundleFile = [_payconfig.baseDirectory stringByAppendingPathComponent:@"newbundle.zip"];		
		[[NSFileManager defaultManager] copyItemAtPath:bundleBinary toPath:bundleFile error:&error];
		if( error != nil ) return NO;
	}
	else return NO;
	
	return [self installUpdate:_payconfig];
}

- (void)setupPushWorker:(AppConfig *)appconfig
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	if(appconfig!=nil && appconfig.hasPush==YES && appconfig.pushServer!=nil)
	{
		//if this is expedition, check if user exists, create if not
		if( isWebContainer == YES )
		{
			pushView.config = _config;
			NSMutableArray* arguments = nil;
			AMSResponse* response = nil;
			AppMobiNotification *notification = (AppMobiNotification *) [pushView getCommandInstance:@"AppMobiNotification"];			
			if( notification.strPushUser == nil || [notification.strPushUser length] == 0 )
			{
				NSString* userID = [NSString stringWithFormat:@"mobius.%@", [[UIDevice currentDevice] uniqueIdentifier]];
				NSString* password = @"m4rc1s4w3f41l";
				NSString* email = [NSString stringWithFormat:@"%@@appmobi.com", userID];
				arguments = [NSMutableArray arrayWithObjects:userID, password, email, nil];

				response = [notification addPushUserInternal:arguments withDict:nil];
				if( response != nil && [response.result isEqualToString:@"ok"] == NO )
				{
					response = [notification checkPushUserInternal:arguments withDict:nil];
				}
			}
			else
			{
				//turn on push
				bShouldFireJSEventWithUpdateToken = NO;
				[self enablePushNotifications:self];
			}
			
			if( urlCmd != nil && [urlCmd compare:@"RUNAPP"] == NSOrderedSame )
			{
				int count = 0;
				while( strDeviceToken == nil && count < 12 )
				{
					CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.25, false);
					count++;
				}
				
				if( strDeviceToken != nil )
				{
					NSString* userID = [NSString stringWithFormat:@"mobius.%@", [[UIDevice currentDevice] uniqueIdentifier]];
					NSString* password = @"m4rc1s4w3f41l";
					NSString* email = [NSString stringWithFormat:@"%@@appmobi.com", userID];
					arguments = [NSMutableArray arrayWithObjects:userID, password, email, nil];

					[arguments addObject:urlApp];
					response = [notification addPushUserInternal:arguments withDict:nil];
					if( response != nil && [response.result isEqualToString:@"ok"] == NO )
					{
						response = [notification checkPushUserInternal:arguments withDict:nil];
					}
					[notification registerDevice:strDeviceToken withJSEvent:NO forApp:urlApp];
				}
			}
		}
		else
		{
			AppMobiNotification *notification = (AppMobiNotification *) [webView getCommandInstance:@"AppMobiNotification"];
			if( [notification.strPushUser length] != 0 )
			{
				//turn on push
				bShouldFireJSEventWithUpdateToken = NO;
				[self enablePushNotifications:self];
			}		
		}
	}
	
	if( isWebContainer == YES )
	{
		[viewController refreshBookmarks:nil];
		[NSThread detachNewThreadSelector:@selector(bookmarkWorker:) toTarget:self withObject:nil];
	}
	
	[pool release];
}

- (void)configWorker:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *configstr = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"https://services.appmobi.com/external/clientservices.aspx?feed=getmobiusconfig"] encoding:NSUTF8StringEncoding error:nil];
	if( configstr != nil && [configstr length] > 0 )
	{
		NSString *temp;
		NSRange range1 = [configstr rangeOfString:@"gallery=\""];
		NSRange range2 = [configstr rangeOfString:@"\" version=\""];
		NSRange range3 = [configstr rangeOfString:@"\" link=\""];
		NSRange range4 = [configstr rangeOfString:@"\" onetouch=\""];
		NSRange range5 = [configstr rangeOfString:@"\" />"];
		if( range1.location != NSNotFound && range2.location != NSNotFound && range3.location != NSNotFound && range4.location != NSNotFound  && range5.location != NSNotFound )
		{
			temp = [configstr substringWithRange:NSMakeRange(range1.location+range1.length, range2.location-range1.location-range1.length)];
			galleryURL = [[temp copy] retain];
			temp = [configstr substringWithRange:NSMakeRange(range2.location+range2.length, range3.location-range2.location-range2.length)];
			int version  = [temp intValue];
			temp = [configstr substringWithRange:NSMakeRange(range3.location+range3.length, range4.location-range3.location-range3.length)];
			updateURL = [[temp copy] retain];
			temp = [configstr substringWithRange:NSMakeRange(range4.location+range4.length, range5.location-range4.location-range4.length)];
			onetouchURL = [[temp copy] retain];
			
			if( version > versionNumber )
			{
				bMobiusUpdate = YES;
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"mobiUs Update" message:@"There is a new version of mobiUs available. Click Install to install now." delegate:self cancelButtonTitle:nil otherButtonTitles:@"Close", @"Install", nil];
				[alert show];
				[alert release];			
			}
		}		
	}
	
	[pool release];
}

- (void)enablePushNotifications:(id)sender
{
	#ifdef HASPUSH
	[[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound)];
	#endif
}

#ifdef HASPUSH
- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken
{
	const UInt8 *bytes = [devToken bytes];
	
	NSString *strDeviceTok = @"";
	for( int i = 0; i < 32; i++ )
	{
		unsigned int byte = bytes[i];
		strDeviceTok = [strDeviceTok stringByAppendingFormat:@"%02X", byte];
	}

	AppMobiNotification *notification = nil;
	if( isWebContainer == YES )
		notification = (AppMobiNotification *) [pushView getCommandInstance:@"AppMobiNotification"];
	else
		notification = (AppMobiNotification *) [webView getCommandInstance:@"AppMobiNotification"];
	
	//handle the case where we are automatically enabling PN with cached user info
	strDeviceToken = [[strDeviceTok copy] retain];
	[notification registerDevice:strDeviceTok withJSEvent:bShouldFireJSEventWithUpdateToken forApp:nil];
	//always reset to default
	bShouldFireJSEventWithUpdateToken = YES;
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)terr
{
	AppMobiNotification *notification = (AppMobiNotification *) [webView getCommandInstance:@"AppMobiNotification"];
	[notification registerDevice:nil withJSEvent:bShouldFireJSEventWithUpdateToken forApp:nil];
	//always reset to default
	bShouldFireJSEventWithUpdateToken = YES;
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
    NSLog(@"didReceiveRemoteNotification -- %@", userInfo);
	NSString *target = [userInfo objectForKey:@"target"];
	BOOL hidden = [[userInfo objectForKey:@"hidden"] boolValue];
	AppMobiNotification *notification = nil;
	if( isWebContainer == YES )
		notification = (AppMobiNotification *) [pushView getCommandInstance:@"AppMobiNotification"];
	else
		notification = (AppMobiNotification *) [webView getCommandInstance:@"AppMobiNotification"];
	[NSTimer scheduledTimerWithTimeInterval:1.0 target:notification selector:@selector(updatePushNotifications:) userInfo:nil repeats:NO];
	
	if( webView != nil )
	{
		NSString *userkey = [userInfo objectForKey:@"userkey"];
		if( userkey == nil || [userkey length] == 0 ) userkey = @"-";
		[webView autoLogEvent:@"/notification/push/interact.event" withQuery:userkey];
	}
	
	if( isWebContainer == YES && target != nil && [target length] > 0 )
	{
		lastPushID = [[[userInfo objectForKey:@"id"] copy] retain];
		NSDictionary *msg = [userInfo objectForKey:@"aps"];
		if( msg != nil )
		{
			NSString *alert = [msg objectForKey:@"alert"];
			NSRange range = [alert rangeOfString:@"["];
			if( range.length == 1 )
			{
				range = [alert rangeOfString:@"]"];
				if( range.length == 1 )
				{
					urlApp = [[target copy] retain];
					NSString *message = [alert substringFromIndex:range.location+2];
                    NSString *title = [NSString stringWithString:target];
                    
                    if( isWebContainer == YES )
                    {
                        NSMutableArray *bookmarks = _bookconfig.bookmarks;
                        for( int i = 0; i < [bookmarks count]; i++ )
                        {
                            Bookmark *bookmark = (Bookmark *) [bookmarks objectAtIndex:i];
                            if( [bookmark.appconfig.appName compare:target] == NSOrderedSame && bookmark.appconfig.siteName != nil )
                            {
                                title = [NSString stringWithString:bookmark.appconfig.siteName];    
                            }
                        }
                    }
                    
					bAutoPush = YES;
                    bHiddenPush = hidden;
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:nil otherButtonTitles:@"Close", @"View", nil];
					[alert show];
					[alert release];                    
					bAutoPush = YES;
				}
			}
		}
	}
}
#endif

- (void)initAudio
{
	if(bIsAudioInitialized) return;

	bIsAudioInitialized = YES;
	OSStatus ret = AudioSessionInitialize ( NULL, NULL, phonecallListener, self );
	UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
	ret = AudioSessionSetProperty( kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory );
}

- (void)initSpeech
{
	if(bIsSpeechInitialized) return;
	
	bIsSpeechInitialized = YES;
	[SpeechKit setupWithID:@"NMDPTRIAL_snarf211220110608075912" host:@"sandbox.nmdp.nuancemobility.net" port:443];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	if( webView != nil ) [webView autoLogEvent:@"/device/exit.event" withQuery:nil];
	
	//[httpServer stop];
	//[httpServer release];
	PlayingView *playerView = (PlayingView *) [viewController getPlayerView];
	if( myPlayer != nil && myPlayer.bPlaying == YES )
	{
		[playerView onStop:nil];
	}
	
	if( myPlayer )
	{
		myPlayer.bLinger = NO;
		myPlayer.bPaused = NO;
		[myPlayer stopStream:self];
	}
	
	if(bIsAudioInitialized) AudioSessionSetActive(NO);
}

- (void)handleLogin:(BOOL)haveConfig
{
}

- (void)dealloc
{
	[imageView release];
	[viewController release];
	[activityView release];
	[window release];
	[invokedURL release];
	
	[super dealloc];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	//AMLog(@"applicationDidBecomeActive:");
}

- (void)applicationWillResignActive:(UIApplication *)application {
	//AMLog(@"applicationWillResignActive:");
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	//AMLog(@"applicationDidEnterBackground:");
	bInBackground = YES;
	//AMLog(@"applicationWillResignActive:");
	NSString *js = [NSString stringWithFormat:@"var e = document.createEvent('Events');e.initEvent('appMobi.device.suspend',true,true);document.dispatchEvent(e);"];
	AMLog(@"%@",js);
	[webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:js waitUntilDone:NO];
	if( webView != nil ) [webView autoLogEvent:@"/device/suspend.event" withQuery:nil];
	[httpServer stop];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	AMLog(@"applicationWillEnterForeground:");
	bInBackground = NO;
	bWasBackground = YES;
	[(PlayingView *) [[AppMobiViewController masterViewController] getPlayerView] getAllCovers:nil];
	[(PlayingView *) [[AppMobiViewController masterViewController] getPlayerView] resetView:nil];
	[(PlayingView *) [[AppMobiViewController masterViewController] getPlayerView] repaint:nil];
	NSError *error = nil;
	if(![httpServer start:&error])
	{
		AMLog(@"Error starting HTTP Server: %@", error);
	}
	PlayingView *playerView = (PlayingView *) [[AppMobiViewController masterViewController] getPlayerView];
	NSString* lastPlaying = playerView.lastPlaying;
	NSString *js = [NSString stringWithFormat:@"AppMobi.device.lastPlaying='%@';var e = document.createEvent('Events');e.initEvent('appMobi.device.resume',true,true);document.dispatchEvent(e);", lastPlaying];
	AMLog(@"%@",js);
	[webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:js waitUntilDone:NO];
	if( webView != nil ) [webView autoLogEvent:@"/device/resume.event" withQuery:nil];

	[NSThread detachNewThreadSelector:@selector(updateWorker:) toTarget:self withObject:nil];
}

// simple API that encodes reserved characters according to:
// RFC 3986 -- http://tools.ietf.org/html/rfc3986
- (NSString *)urlencode:(NSString *)url
{
	NSArray *escapeChars  = [NSArray arrayWithObjects:@"^", @"{", @"}", @"\"", @"%", @";", @"/", @"\\", @"?", @":", @"@", @"&", @"=", @"+", @"$", @",", @"[", @"]", @"#", @"!", @"'", @"(",	@")", @"*", @" ", nil];
	NSArray *replaceChars = [NSArray arrayWithObjects:@"%5E", @"%7B", @"%7D", @"%22", @"%25", @"%3B", @"%2F", @"%5C", @"%3F", @"%3A", @"%40", @"%26", @"%3D", @"%2B", @"%24", @"%2C", @"%5B", @"%5D", @"%23", @"%21", @"%27", @"%28", @"%29", @"%2A", @"%20", nil];
	
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
	NSArray *replaceChars  = [NSArray arrayWithObjects:@"^", @"{", @"}", @"\"", @";", @"/", @"\\", @"?", @":", @"@", @"&", @"=", @"+", @"$", @",", @"[", @"]", @"#", @"!", @"'", @"(", @")", @"*", @" ", @"%", nil];
	NSArray *unescapeChars = [NSArray arrayWithObjects:@"%5E", @"%7B", @"%7D", @"%22", @"%3B", @"%2F", @"%5C", @"%3F", @"%3A", @"%40", @"%26", @"%3D", @"%2B", @"%24", @"%2C", @"%5B", @"%5D", @"%23", @"%21", @"%27", @"%28", @"%29", @"%2A", @"%20", @"%25", nil];
	
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

- (NSString *)getKey:(NSString *)key fromURL:(NSString *)url
{
	NSString *temp;
	NSString *tempkey;
	NSRange range;
	
	tempkey = [NSString stringWithFormat:@"&%@=", key];
	range = [url rangeOfString:tempkey options:NSCaseInsensitiveSearch];
	if( range.length == 0 )
	{
		tempkey = [NSString stringWithFormat:@"?%@=", key];
		range = [url rangeOfString:tempkey options:NSCaseInsensitiveSearch];
	}
	if( range.length == 0 )
	{
		tempkey = [NSString stringWithFormat:@"//%@=", key];
		range = [url rangeOfString:tempkey options:NSCaseInsensitiveSearch];
	}
	
	if( range.length == 0 )
		return [[[NSString alloc] initWithString:@""] autorelease];
	
	temp = [url substringFromIndex:range.location+[tempkey length]];
	range = [temp rangeOfString:@"&"];
	if( range.length == 1 )
		temp = [temp substringToIndex:range.location];
	temp = [self urldecode:temp];
	
	return [[temp copy] autorelease];
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
	if( isProtocolHandler == YES ) return YES;
	NSString *URLString = [url absoluteString];
	if( !URLString )
	{
		return NO;
	}
	
	NSRange range = [URLString rangeOfString:@"appmobitest:" options:NSCaseInsensitiveSearch];
	if( range.length > 0 && range.location == 0 )
	{
		AMLog(@"appmobitest: %@",URLString);
		isProtocolHandler = YES;
		appName = [[self getKey:@"APP" fromURL:URLString] copy];
		pkgName = [[self getKey:@"PKG" fromURL:URLString] copy];
		relName = [[self getKey:@"REL" fromURL:URLString] copy];
		
		if( [appName length] == 0 ) isTestContainer = YES;

		NSString *configFile = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/appconfig.xml", appName, relName]];
		if( [[NSFileManager defaultManager] fileExistsAtPath:configFile] )
		{
			AppConfig *newConfig = [self parseAppConfig:configFile];			
			if( newConfig != nil && [newConfig.pkgName compare:pkgName] != NSOrderedSame )
			{
				[[NSFileManager defaultManager] removeItemAtPath:configFile error:nil];
			}
		}
	}
	
	NSRange range2 = [URLString rangeOfString:@"mobius:" options:NSCaseInsensitiveSearch];
	if( range2.length > 0 && range2.location == 0 )
	{
		AMLog(@"mobius: %@",URLString);
		isProtocolHandler = YES;
		urlApp = [[self getKey:@"APP" fromURL:URLString] copy];
		urlRel = [[self getKey:@"REL" fromURL:URLString] copy];
		urlId  = [[self getKey:@"ID" fromURL:URLString] copy];
		urlCmd = [[self getKey:@"CMD" fromURL:URLString] copy];
		urlUrl = [[self getKey:@"URL" fromURL:URLString] copy];
		urlPay = [[self getKey:@"PAY" fromURL:URLString] copy];
		urlRtn = [[self getKey:@"RTN" fromURL:URLString] copy];
		urlKey = [[self getKey:@"importkey" fromURL:URLString] copy];
		
		if( [urlCmd compare:@"RUNAPP"] == NSOrderedSame )
		{
			NSString *configFile = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/appconfig.xml", urlApp, urlRel]];
			if( [[NSFileManager defaultManager] fileExistsAtPath:configFile] == NO )
			{
				isMobiusInstall = YES;
			}
		}
		
		if( [urlCmd compare:@"1TOUCH"] == NSOrderedSame && urlKey != nil && [urlKey length] > 0 )
		{
			urlCmd = @"RUNSITE";
			urlUrl = [[importURL stringByAppendingString:urlKey] retain];
		}
	}
	
	NSRange questionMark = [URLString rangeOfString:@"?"];
	if(questionMark.location == NSNotFound) {
		urlQuery = [@"" copy];
		AMLog(@"not found");
	} else {
		urlQuery = [[URLString substringFromIndex:(questionMark.location+1)] copy];
		AMLog(@"found:%@",urlQuery);
	}
	
	NSRange proddebug = [URLString rangeOfString:@"INT=1"];
	if( proddebug.location != NSNotFound )
		bDebug = YES;
	
	return YES;
}

-(void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
	NSLog(@"received memory warning");
}

@end

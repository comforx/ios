#import <UIKit/UIKit.h>
#import "JSON.h"

#import "AppMobiLocation.h"
#import "AppMobiDevice.h"
#import "AppMobiDebug.h"
#import "appMobiCache.h"

@class InvokedCommand;
@class AppMobiViewController;
@class AppMobiSplashController;
@class AppConfig;
@class BookmarkConfig;
@class HTTPServer;
@class AppMobiWebView;
@class Player;
@class DirectCanvas;
@class Bookmark;

void AMLog( NSString *format, ... );

@interface AMApplication : UIApplication {
}
- (void)remoteControlReceivedWithEvent:(UIEvent*)theEvent;
@end

@interface AMURLCache : NSURLCache {
}
-(void)setMemoryCapacity:(NSUInteger)memCap;
@end

@interface DownloadDelegate: NSObject {
	Bookmark *bookmark;
    NSString *strBundle;
	BOOL bDone;
    BOOL bSuccess;
	int current;
	int length;
	NSFileHandle *myHandle;
	NSTimeInterval lastUpdateTime;
}

@property (nonatomic, assign) Bookmark *bookmark;
@property (nonatomic, assign) NSString *strBundle;
@property (nonatomic) BOOL bDone;
@property (nonatomic) BOOL bSuccess;
@property (nonatomic) NSTimeInterval lastUpdateTime;

@end

@interface AppMobiDelegate : NSObject < UIApplicationDelegate, UIAlertViewDelegate >
{	
	HTTPServer *httpServer;
	Player *myPlayer;
	Player *nextPlayer;
	UIWindow *window;
	AppMobiWebView *webView;
	AppMobiWebView *payView;
	AppMobiWebView *pushView;
	AppMobiViewController *viewController;
	AppMobiSplashController *splashController;
	
	UIImageView *imageView;
	UIActivityIndicatorView *activityView;

	NSString *urlId;
	NSString *urlApp;
	NSString *urlRel;
	NSString *urlPay;
	NSString *urlCmd;
	NSString *urlUrl;
	NSString *urlKey;
	NSString *urlQuery;
	NSString *urlRtn;
	NSString *appName;
	NSString *relName;
	NSString *pkgName;
	NSString *payApp;
	NSString *payRel;
	NSString *lastApp;
	NSString *lastRel;
	NSString *lastPkg;
	NSString *userKey;
    BOOL isTestLocal;
	BOOL isTestContainer;
	BOOL isWebContainer;
	BOOL isProtocolHandler;
	BOOL isMobiusInstall;
	BOOL isPushStart;
	BOOL bWasBackground;
	BOOL bShowAds;
	BOOL bForceGoogle;
	BOOL bFirstTime;
	BOOL bAutoPush;
    BOOL bHiddenPush;
	BOOL bMobiusUpdate;
	AppConfig *_config;
	AppConfig *_payconfig;
	BookmarkConfig *_bookconfig;
	BOOL bInBackground;
	BOOL bStartup;
	int bookSequence;
	int versionNumber;
	NSLock *splashLock;
	NSString *galleryURL;
	NSString *updateURL;
	NSString *onetouchURL;
	NSString *importURL;
	NSString *strDeviceToken;
	NSString *lastPushID;
	NSString *whiteLabel;
	NSString *adSenseApplicationAppleID;
	NSString *adSenseAppName;
	NSString *adSenseCompanyName;
	NSString *adSenseAppWebContentURL;
	NSString *adSenseChannelID;
}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) AppMobiWebView *webView;
@property (nonatomic, retain) AppMobiViewController *viewController;
@property (nonatomic, retain) UIActivityIndicatorView *activityView;
@property (nonatomic, retain) NSURL *invokedURL;
@property (nonatomic, retain) NSString *urlId;
@property (nonatomic, retain) NSString *urlPay;
@property (nonatomic, retain) NSString *urlCmd;
@property (nonatomic, retain) NSString *urlUrl;
@property (nonatomic, retain) NSString *urlRtn;
@property (nonatomic, retain) NSString *appName;
@property (nonatomic, retain) NSString *relName;
@property (nonatomic, retain) NSString *pkgName;
@property (nonatomic, retain) NSString *lastApp;
@property (nonatomic, retain) NSString *lastRel;
@property (nonatomic, retain) NSString *lastPkg;
@property (nonatomic, retain) NSString *urlQuery;
@property (nonatomic, retain) NSString *strDeviceToken;
@property (nonatomic) BOOL isTestLocal;
@property (nonatomic) BOOL isTestContainer;
@property (nonatomic) BOOL isProtocolHandler;
@property (nonatomic) BOOL isWebContainer;
@property (nonatomic) BOOL isMobiusInstall;
@property (nonatomic) BOOL bShowAds;
@property (nonatomic) BOOL bForceGoogle;
@property (nonatomic) BOOL bInBackground;
@property (nonatomic) BOOL bStartup;
@property (retain) AppConfig *_config;
@property (retain) AppConfig *_payconfig;
@property (nonatomic, retain) BookmarkConfig *_bookconfig;
@property (nonatomic, assign) Player *myPlayer;
@property (nonatomic, assign) Player *nextPlayer;
@property (nonatomic, readonly) NSString *galleryURL;
@property (nonatomic, readonly) NSString *onetouchURL;
@property (nonatomic, retain) NSString *whiteLabel;
@property (nonatomic, retain) NSString *adSenseApplicationAppleID;
@property (nonatomic, retain) NSString *adSenseAppName;
@property (nonatomic, retain) NSString *adSenseCompanyName;
@property (nonatomic, retain) NSString *adSenseAppWebContentURL;
@property (nonatomic, retain) NSString *adSenseChannelID;

+ (AppMobiDelegate*) sharedDelegate;
+ (NSString*) baseDirectory;
+ (NSString*) appDirectory;

- (BOOL)downloadCachedApp:(Bookmark *)bookmark;
- (void)downloadBundleWithProgress:(Bookmark *)bookmark;
- (BOOL)downloadBundle:(AppConfig *)appconfig;
- (AppConfig *)parseAppConfig:(NSString *)configPath;
- (BOOL)downloadUpdate:(AppConfig *)appconfig;
- (BOOL)installUpdate:(AppConfig *)appconfig;
- (BOOL)installJavascript:(AppConfig *)appconfig;
- (BOOL)updateInitialApp;
- (BOOL)extractInitialApp;
- (BOOL)installPayments;
- (void)processBookmark:(Bookmark *)bookmark;
- (BOOL)updateAvailable:(AppConfig *)appconfig;
- (BOOL)downloadAppConfig:(NSString *)appname andRel:(NSString *)relname andPkg:(NSString *)pkgname;
- (BOOL)downloadInitialApp:(NSString *)appname andRel:(NSString *)relname andPkg:(NSString *)pkgname;
- (void)runMobiusApplication:(NSString *)appname andRelease:(NSString *)relname;

- (void)notifyUserAndInstall:(AppConfig *)appconfig;
- (void)promptUserForInstall:(AppConfig *)appconfig;
- (void)notifyAppForInstall:(AppConfig *)appconfig;

+ (BOOL)isIPad;
- (UIImage *)updateSplash:(id)sender;
- (void)hideSplashScreen:(id)sender;
- (void)enablePushNotifications:(id)sender;
- (void)handleLogin:(BOOL)haveConfig;
- (void)initAudio;
- (void)initSpeech;
- (void)parseBookmarks:(id)sender;

- (NSString *)urlencode:(NSString *)url;
- (NSString *)urldecode:(NSString *)url;

@end

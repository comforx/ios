
#import "AppMobiWebView.h"
#import "AppMobiViewController.h"
#import "InvokedCommand.h"
#import "AppMobiNotification.h"
#import "AppMobiPlayer.h"
//#import "AppMobiFrameworkDelegate.h"
#import "AppMobiModule.h"
#import "AppMobiAnalytics.h"
#import "AppConfig.h"
#import "AppMobiDevice.h"
#import "AppMobiCache.h"
#import "AppMobiAudio.h"
#import "AppMobiCamera.h"
#import "AppMobiOAuth.h"
#import "AppMobiCanvas.h"

@implementation AppMobiWebView

@synthesize config;
@synthesize bIsMobiusPush;

- (void)didShowKeyboard:(NSNotification *)notification
{
	if( self.isHidden == YES ) return;
	
	NSString *js = [NSString stringWithFormat:@"var e = document.createEvent('Events');e.initEvent('appMobi.device.keyboard.show',true,true);document.dispatchEvent(e);"];
	AMLog(@"%@",js);
	[self injectJS:js];
}

- (void)didHideKeyboard:(NSNotification *)notification
{
	if( self.isHidden == YES ) return;
	
	NSString *js = [NSString stringWithFormat:@"var e = document.createEvent('Events');e.initEvent('appMobi.device.keyboard.hide',true,true);document.dispatchEvent(e);"];
	AMLog(@"%@",js);
	[self injectJS:js];
}

- (void)registerKeyboardListener:(id)sender
{
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(didShowKeyboard:) name:UIKeyboardDidShowNotification object:nil];
	[center addObserver:self selector:@selector(didHideKeyboard:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)unregisterKeyboardListener:(id)sender
{
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center removeObserver:self name:UIKeyboardDidShowNotification object:nil];
	[center removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void)initialize
{
	[super setDelegate:self];
	commandObjects = [[NSMutableDictionary alloc] initWithCapacity:4];
	moduleObjects = [[NSMutableDictionary alloc] initWithCapacity:4];
	
	NSArray* modules = [NSMutableArray arrayWithArray:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"modules"]];
	for (NSString* module in modules)
	{
		if( module == nil || [module length] == 0 ) continue;
		
		id obj = [[[NSClassFromString(module) alloc] init] autorelease];
		if( obj != nil && [obj isKindOfClass:[AppMobiModule class]]  )
		{
			[obj setup:self];
			[moduleObjects setObject:obj forKey:module];
		}
	}
	[self registerKeyboardListener:nil];
}

- (id)init
{
    if ((self = [super init]))
	{
		[self initialize];
	}
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
	{
		[self initialize];
	}
    return self;
}

- (id<UIWebViewDelegate>)delegate
{
	return userDelegate;
}

- (void)setDelegate:(id<UIWebViewDelegate>)delegate
{
	[userDelegate release];	
	userDelegate = [delegate retain];
}

- (NSString *)baseDirectory
{
	if( config == nil ) return nil;
	
	return config.baseDirectory;
}

- (NSString *)appDirectory
{
	if( config == nil ) return nil;
	
	return config.appDirectory;
}

- (NSString *)webRoot
{
	if( config == nil ) return nil;
	
	return [NSString stringWithFormat:@"http://localhost:58888/%@/%@", config.appName, config.relName];
}

- (void)webViewDidStartLoad:(UIWebView *)theWebView 
{
	if( userDelegate != nil ) [userDelegate webViewDidStartLoad:theWebView];
}

- (void)webViewDidFinishLoad:(UIWebView *)theWebView
{
	NSURL *url = [[theWebView request] URL];
	AMLog(@"~~~~ DID File URL [%@]", [url description]);
	
	if( [[url description] compare:@"about:blank"] == NSOrderedSame ) return;
	
	if( [AppMobiDelegate sharedDelegate].isWebContainer == YES )
	{
		[[AppMobiViewController masterViewController] pageLoaded:theWebView];
	}

	if( [AppMobiViewController masterViewController].bRichShowing == YES )
	{
		[[AppMobiViewController masterViewController] richLoaded:theWebView];
	}
	
	if( [AppMobiDelegate sharedDelegate].isWebContainer == YES  && config != nil && [config.appType compare:@"SITE"] == NSOrderedSame )
	{
		NSString *amjspath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"appmobi_iphone"] ofType:@"js"];
		NSString *amjs = [[[NSString alloc] initWithData:[[NSFileManager defaultManager] contentsAtPath:amjspath] encoding:NSASCIIStringEncoding] autorelease];
		[theWebView stringByEvaluatingJavaScriptFromString:amjs];
	}
	
	//inject javascript to initialize appMobi framework
	AppMobiDevice *device = [self getCommandInstance:@"AppMobiDevice"];
	[device fireGetConnection:nil];

	//NSMutableString *result = [[NSMutableString alloc] initWithFormat:@"AppMobiInit = %@;", [[device deviceProperties] JSONFragment]];
	NSMutableString *result = [[NSMutableString alloc] initWithFormat:@""]; // modified to defer connection type
	//[result appendFormat:@"window.navigator.standalone = 1;\n"];
	[result appendFormat:@"if( typeof(AppMobi) == 'undefined' ) { AppMobi = {}; } AppMobi.isnative = true; AppMobi.isxdk = false;\n"];
	[result appendFormat:@"AppMobi.app = \"%@\"; AppMobi.release = \"%@\";", config.appName, config.relName];
	[result appendFormat:@"\nAppMobi.webRoot = \"http://localhost:58888/%@/%@/\";", config.appName, config.relName];

	BOOL update = [[AppMobiDelegate sharedDelegate] updateAvailable:config];
	[result appendFormat:@"\nAppMobi.updateAvailable = %@; AppMobi.updateMessage = \"%@\";", (update?@"true":@"false"), (config.updateMessage==nil?@"":config.updateMessage)];

	AppMobiOAuth *oauth = [self getCommandInstance:@"AppMobiOAuth"];
	[result appendFormat:@"\nAppMobi.oauthAvailable = %@;", (oauth.ready?@"true":@"false")];
    
	//retrieve appMobi cookies and push into web app
	NSString *appMobiCookies = [[self getCommandInstance:@"AppMobiCache"] allCookies];
	[result appendFormat:@"\nAppMobi.cookies = %@;", appMobiCookies];
	
	//retrieve appMobi cached media map and push into web app
	NSDictionary *appMobiCachedMediaMap = [[self getCommandInstance:@"AppMobiCache"] getMediaCacheList];
	NSMutableString *jsArray = nil;
	if([appMobiCachedMediaMap count]==0) {
		//handle empty case
		jsArray = [[NSMutableString alloc] initWithString:@"[]"];
	} else {
		for (id key in appMobiCachedMediaMap) {
			if(jsArray==nil) {
				jsArray = [[NSMutableString alloc] initWithString:@"["];
			} else {
				[jsArray appendString:@", "];
			}
			[jsArray appendFormat:@"'%@'",key];
		}
		[jsArray appendString:@"]"];
	}
	[result appendFormat:@"\nAppMobi.mediacache = %@;", jsArray];
	[jsArray release];

	//retrieve appMobi saved pictures list and push into web app
	NSDictionary *appMobiSavedPictures = [[self getCommandInstance:@"AppMobiCamera"] makePictureList];
	jsArray = nil;
	if([appMobiSavedPictures count]==0) {
		//handle empty case
		jsArray = [[NSMutableString alloc] initWithString:@"[]"];
	} else {
		for (id key in appMobiSavedPictures) {
			if(jsArray==nil) {
				jsArray = [[NSMutableString alloc] initWithString:@"["];
			} else {
				[jsArray appendString:@", "];
			}
			[jsArray appendFormat:@"'%@'",key];
		}
		[jsArray appendString:@"]"];
	}
	[result appendFormat:@"\nAppMobi.picturelist = %@;", jsArray];
	[jsArray release];
	
	//retrieve appMobi saved recordings list and push into web app
	NSDictionary *appMobiSavedRecordings = [[self getCommandInstance:@"AppMobiAudio"] makeRecordingList];
	jsArray = nil;
	if([appMobiSavedRecordings count]==0) {
		//handle empty case
		jsArray = [[NSMutableString alloc] initWithString:@"[]"];
	} else {
		for (id key in appMobiSavedRecordings) {
			if(jsArray==nil) {
				jsArray = [[NSMutableString alloc] initWithString:@"["];
			} else {
				[jsArray appendString:@", "];
			}
			[jsArray appendFormat:@"'%@'",key];
		}
		[jsArray appendString:@"]"];
	}
	[result appendFormat:@"\nAppMobi.recordinglist = %@;", jsArray];
	[jsArray release];
	
	NSString *trackinfo = [[AppMobiViewController masterViewController] getTrackInfo];
	if( trackinfo != nil )
	{
		[result appendFormat:@"%@", trackinfo];
	}
	
	// Inject Push Notifications
	if( [AppMobiDelegate sharedDelegate].isWebContainer == YES )
	{
		AppMobiNotification *notification = (AppMobiNotification *) [[[AppMobiViewController masterViewController] getPushView] getCommandInstance:@"AppMobiNotification"];
		[result appendFormat:@"\n%@", [notification getHiddenNotifications:config.appName]];
	}
	else
	{
		AppMobiNotification *notification = (AppMobiNotification *) [self getCommandInstance:@"AppMobiNotification"];
		[result appendFormat:@"\n%@", [notification getNotificationsString]];
	}
	
	[result appendFormat:@"AppMobiInit = %@;", [[device deviceProperties] JSONFragment]];
	AMLog(@"Device initialization: %@", result);
	[theWebView stringByEvaluatingJavaScriptFromString:result];
	[result release];
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
	
	if( userDelegate != nil ) [userDelegate webViewDidFinishLoad:theWebView];
}

- (void)webView:(UIWebView *)theWebView didFailLoadWithError:(NSError *)error
{
	if( userDelegate != nil ) [userDelegate webView:theWebView didFailLoadWithError:error];
}

- (BOOL)webView:(UIWebView *)theWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSURL *url = [request URL];
	AMLog(@"~~~~ SHOULD File URL [%@]", [url description]);
	
	if( [[url description] compare:@"about:blank"] == NSOrderedSame ) return YES;
	
	if ([[url scheme] isEqualToString:@"appmobi"]) {
		
		InvokedCommand* iuc = [[InvokedCommand newFromUrl:url] autorelease];
        
		// Tell the JS code that we've gotten this command, and we're ready for another
		[theWebView stringByEvaluatingJavaScriptFromString:@"AppMobi.queue.ready = true;"];
		
		// Check to see if we are provided a class:method style command.
		NSMutableDictionary *options = iuc.options;
		[options setObject:theWebView forKey:@"AppMobiWebView"];
		[self execute:iuc];
		
		return NO;
	}
    
    if( [AppMobiDelegate sharedDelegate].isWebContainer == YES )
    {
        [theWebView stringByEvaluatingJavaScriptFromString:@"isMobius = true;"];
    }
	
	AppMobiDevice *device = (AppMobiDevice *) [self getCommandInstance:@"AppMobiDevice"];
	if( device.shouldBlock == YES )
	{
		NSString *urlstr = [url description];
		if( [urlstr hasPrefix:@"http://localhost:58888"] == NO )
		{
			NSRange range = [urlstr rangeOfString:@"://"];
			NSString *domain = [urlstr substringFromIndex:range.location + 3];			
			range = [domain rangeOfString:@"/"];
			domain = [domain substringToIndex:range.location];
			
			for( int i = 0; i < [device.whiteList count]; i++ )
			{
				if( [domain compare:[device.whiteList objectAtIndex:i]] == NSOrderedSame ) return YES;
			}
			
			urlstr = [urlstr stringByReplacingOccurrencesOfString:@"'" withString:@"\'"];
			NSString *js = [NSString stringWithFormat:@"var e = document.createEvent('Events');e.initEvent('appMobi.device.remote.block',true,true);e.success=true;e.blocked='%@';document.dispatchEvent(e);", urlstr];
			AMLog(@"%@",js);
			[self performSelectorOnMainThread:@selector(injectJS:) withObject:js waitUntilDone:NO];
			return NO;
		}
	}
	
	if( userDelegate != nil ) return [userDelegate webView:theWebView shouldStartLoadWithRequest:request navigationType:navigationType];
	else return YES;
}

- (BOOL)execute:(InvokedCommand*)command
{
	if (command.className == nil || command.methodName == nil) {
		return NO;
	}
	
	// Fetch an instance of this class
	AppMobiCommand* obj = [self getCommandInstance:command.className];
	
	// construct the fill method name to ammend the second argument.
	NSString* fullMethodName = [[NSString alloc] initWithFormat:@"%@:withDict:", command.methodName];
	if ([obj respondsToSelector:NSSelectorFromString(fullMethodName)]) {
		[obj performSelector:NSSelectorFromString(fullMethodName) withObject:command.arguments withObject:command.options];
	}
	else {
		// There's no method to call, so throw an error.
		AMLog(@"BRIDGE ERROR *** Class method '%@' not defined in class '%@'.", fullMethodName, command.className);
	}
	[fullMethodName release];
	
	return YES;
}

- (id)getCommandInstance:(NSString *)className
{
    id obj = [commandObjects objectForKey:className];
    if( obj == nil )
	{
		obj = [[NSClassFromString(className) alloc] initWithWebView:self];
        if( obj != nil )
        {
            [commandObjects setObject:obj forKey:className];
            [obj release];
        }
        else
        {
            AMLog(@"BRIDGE ERROR *** Class '%@' not defined.", className);
        }
    }
    return obj;
}

- (id)getModuleInstance:(NSString *)className
{
    id obj = [moduleObjects objectForKey:className];
    return obj;
}

- (void)registerCommand:(AppMobiCommand *)command forName:(NSString *)name
{
	[commandObjects setObject:command forKey:name];
}

- (void)autoLogEvent:(NSString *)event withQuery:(NSString *)query;
{
	AppMobiAnalytics *analytics = (AppMobiAnalytics *) [self getCommandInstance:@"AppMobiAnalytics"];
	if( query == nil ) query = @"-";
	
	NSMutableArray *arguments = [[[NSMutableArray alloc] init] autorelease];
	[arguments addObject:event]; // page
	[arguments addObject:query]; // query
	[arguments addObject:@"200"]; // status
	[arguments addObject:@"GET"]; // method
	[arguments addObject:@"0"]; // bytes
	[arguments addObject:@"index.html"]; // referrer
	
	[analytics logPageEvent:arguments withDict:[[[NSMutableDictionary alloc] init] autorelease]];
}

- (void)injectJS:(NSString *)js
{
	[self performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:js waitUntilDone:NO];
}

- (void)clearApp:(id)sender
{
	NSURLRequest *appReq = [NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]];
	[self loadRequest:appReq];
	
	AppMobiPlayer *player = (AppMobiPlayer *) [self getCommandInstance:@"AppMobiPlayer"];
	[player stop:nil withDict:nil];

	AppMobiNotification *notification = (AppMobiNotification *) [self getCommandInstance:@"AppMobiNotification"];
	[notification closeRichPushViewer:nil withDict:nil];
	
	AppMobiDevice *device = (AppMobiDevice *) [self getCommandInstance:@"AppMobiDevice"];
	[device closeRemoteSite:nil withDict:nil];
	
	// need payment cancelling here too
	
	AppMobiCanvas *canvas = (AppMobiCanvas *) [self getCommandInstance:@"AppMobiCanvas"];
	[canvas reset:nil withDict:nil];	
}

- (void)runApp:(id)sender
{
	NSString *startPage = [NSString stringWithFormat:@"http://localhost:58888/%@/%@/index.html", config.appName, config.relName];
	NSURLRequest *appReq = [NSURLRequest requestWithURL:[NSURL URLWithString:startPage]];
	[self loadRequest:appReq];	
}

- (void)dealloc
{
	[self unregisterKeyboardListener:nil];
	[commandObjects release];
	[moduleObjects release];
	[config release];
    [super dealloc];
}

 /*
 // Test code to determine what page was loaded into a UIWebView 
 NSString *referer = [request.allHTTPHeaderFields objectForKey:@"Referer"];
 NSString *currentPage = [webView.request.mainDocumentURL absoluteString];
 BOOL isFrameLoad = [referer isEqualToString:currentPage] == NO;
 //*/

@end

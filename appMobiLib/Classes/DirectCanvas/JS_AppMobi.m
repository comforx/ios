#import "JS_AppMobi.h"
#import "AppMobiViewController.h"
#import "PlayingView.h"

@implementation JS_AppMobi


- (id)initWithContext:(JSContextRef)ctxp object:(JSObjectRef)obj argc:(size_t)argc argv:(const JSValueRef [])argv {
    self = [super initWithContext:ctxp object:obj argc:argc argv:argv];
	if( self ) {
		timers = [[NSMutableDictionary alloc] init];
		
		// Listen to notifications to pause and resume timers
		NSNotificationCenter * nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(pauseTimers:) name:@"UIApplicationWillResignActiveNotification" object:nil];
		[nc addObserver:self selector:@selector(pauseTimers:) name:@"UIApplicationDidEnterBackgroundNotification" object:nil];
		[nc addObserver:self selector:@selector(resumeTimers:) name:@"UIApplicationDidBecomeActiveNotification" object:nil];
	}
	return self;
}


// ----------------------------------------------------------
// generic

JS_FUNC( JS_AppMobi, log, ctx, argc, argv ) {
	if( argc < 1 ) return NULL;
	JSStringRef logjs = JSValueToStringCopy( ctx, argv[0], NULL );
	CFStringRef log = JSStringCopyCFString( kCFAllocatorDefault, logjs );
	
	NSLog( @"JS: %@", log );
	
	CFRelease( log );
	JSStringRelease( logjs );
	return NULL;
}

JS_FUNC( JS_AppMobi, include, ctx, argc, argv ) {
	if( argc < 1 || !JSValueIsString(ctx, argv[0]) ) return NULL;
	JSStringRef pathjs = JSValueToStringCopy( ctx, argv[0], NULL );
	CFStringRef path = JSStringCopyCFString( kCFAllocatorDefault, pathjs );
	
	[[DirectCanvas instance] loadScriptAtPath:(NSString *)path];
	
	CFRelease( path );
	JSStringRelease( pathjs );
	return NULL;
}

JS_FUNC( JS_AppMobi, openURL, ctx, argc, argv ) {
	NSString * url = JSValueToNSString( ctx, argv[0] );
	if( argc == 2 ) {
		[urlToOpen release];
		urlToOpen = [url retain];
		
		NSString * confirm = JSValueToNSString( ctx, argv[1] );
		UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Open Browser?" message:confirm delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"Cancel", nil];
		[alert show];
		[alert release];
	}
	else {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString: url]];
	}
	return NULL;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)index {
	if( index == 0 ) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlToOpen]];
	}
	[urlToOpen release];
	urlToOpen = nil;
}


JS_FUNC( JS_AppMobi, hideLoadingScreen, ctx, argc, argv ) {
	[[DirectCanvas instance] hideLoadingScreen];
	return NULL;
}

JS_FUNC( JS_AppMobi, hide, ctx, argc, argv ) {
	[[DirectCanvas instance] hide];
	return NULL;
}

JS_FUNC( JS_AppMobi, executeJavascriptInWebView, ctx, argc, argv ) {
	if( argc != 1 || !JSValueIsString(ctx, argv[0]) ) return NULL;
	
	JSStringRef scriptjs = JSValueToStringCopy( ctx, argv[0], NULL );
	CFStringRef script = JSStringCopyCFString( kCFAllocatorDefault, scriptjs );
	
	[[DirectCanvas instance] executeJavascriptInWebView: (NSString *)script];
	
	CFRelease( script );
	JSStringRelease( scriptjs );
	
	return NULL;
}

// ----------------------------------------------------------
// sounds
JS_FUNC( JS_AppMobi, startBackgroundSound, ctx, argc, argv ) {
	if( argc < 1 || !JSValueIsString(ctx, argv[0]) ) return NULL;
	if( argc > 1 && !JSValueIsBoolean(ctx, argv[1]) ) return NULL;
	
	JSStringRef strRelativeFileURLjs = JSValueToStringCopy( ctx, argv[0], NULL );
	CFStringRef strRelativeFileURL = JSStringCopyCFString( kCFAllocatorDefault, strRelativeFileURLjs );
	
	BOOL shouldLoop = argc>1?JSValueToBoolean(ctx, argv[1]):NO;
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] startAudio:(NSString *)strRelativeFileURL withLooping:shouldLoop];
	
	CFRelease( strRelativeFileURL );
	JSStringRelease( strRelativeFileURLjs );
	
	return NULL;
}

JS_FUNC( JS_AppMobi, toggleBackgroundSound, ctx, argc, argv ) {
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] toggleAudio];
	
	return NULL;
}

JS_FUNC( JS_AppMobi, stopBackgroundSound, ctx, argc, argv ) {
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] stopAudio];
	
	return NULL;
}

JS_FUNC( JS_AppMobi, loadSound, ctx, argc, argv ) {
	if( argc != 1 || !JSValueIsString(ctx, argv[0]) ) return NULL;
	
	JSStringRef strRelativeFileURLjs = JSValueToStringCopy( ctx, argv[0], NULL );
	CFStringRef strRelativeFileURL = JSStringCopyCFString( kCFAllocatorDefault, strRelativeFileURLjs );
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] loadSound:(NSString *)strRelativeFileURL];
	
	CFRelease( strRelativeFileURL );
	JSStringRelease( strRelativeFileURLjs );
	
	return NULL;
}

JS_FUNC( JS_AppMobi, togglePolySoundMode, ctx, argc, argv ) {
//	
//	AppMobiViewController *vc = [AppMobiViewController masterViewController];
//	[vc getPlayerView].polyMaxMode = (++[vc getPlayerView].polyMaxMode)%2;
//	
	return NULL;
}


JS_FUNC( JS_AppMobi, loadPolySound, ctx, argc, argv ) {
	if( argc != 2 || !JSValueIsString(ctx, argv[0]) || !JSValueIsNumber(ctx, argv[1]) ) return NULL;
	
	JSStringRef strRelativeFileURLjs = JSValueToStringCopy( ctx, argv[0], NULL );
	CFStringRef strRelativeFileURL = JSStringCopyCFString( kCFAllocatorDefault, strRelativeFileURLjs );
	
	int count = JSValueToNumberFast( ctx, argv[1] );
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] loadSound:(NSString *)strRelativeFileURL withPolyphony:count];
	
	CFRelease( strRelativeFileURL );
	JSStringRelease( strRelativeFileURLjs );
	
	return NULL;
}

JS_FUNC( JS_AppMobi, playSound, ctx, argc, argv ) {
	if( argc != 1 || !JSValueIsString(ctx, argv[0]) ) return NULL;
	
	JSStringRef strRelativeFileURLjs = JSValueToStringCopy( ctx, argv[0], NULL );
	CFStringRef strRelativeFileURL = JSStringCopyCFString( kCFAllocatorDefault, strRelativeFileURLjs );
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] playSound:(NSString *)strRelativeFileURL];
    
	
	CFRelease( strRelativeFileURL );
	JSStringRelease( strRelativeFileURLjs );
	
	return NULL;
}

JS_FUNC( JS_AppMobi, unloadSound, ctx, argc, argv ) {
	if( argc != 1 || !JSValueIsString(ctx, argv[0]) ) return NULL;
	
	JSStringRef strRelativeFileURLjs = JSValueToStringCopy( ctx, argv[0], NULL );
	CFStringRef strRelativeFileURL = JSStringCopyCFString( kCFAllocatorDefault, strRelativeFileURLjs );
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] unloadSound:(NSString *)strRelativeFileURL];
    
	
	CFRelease( strRelativeFileURL );
	JSStringRelease( strRelativeFileURLjs );
	
	return NULL;
}

JS_FUNC( JS_AppMobi, unloadAllSounds, ctx, argc, argv ) {
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] unloadAllSounds];
    
	return NULL;
}


// ----------------------------------------------------------
// timeouts/intervals

- (JSValueRef)createTimer:(JSContextRef)ctx argc:(size_t)argc argv:(const JSValueRef [])argv repeat:(BOOL)repeat {
	if( argc != 2 || !JSValueIsObject(ctx, argv[0]) || !JSValueIsNumber(ctx, argv[1]) ) return NULL;
	
	JSObjectRef func = JSValueToObject(ctx, argv[0], NULL);
	JSValueProtect(ctx, func);
	//directCanvas_callback cb = directCanvas_callback_make(ctx, func, NULL);
	NSValue * callback = [NSValue valueWithPointer:func];
	float interval = JSValueToNumber(ctx, argv[1], NULL )/1000;

	uniqueId++;
	NSTimer * timer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(timerCallback:) userInfo:callback repeats:repeat];
	[timers setObject:timer forKey:[NSNumber numberWithInt:uniqueId]];
	return JSValueMakeNumber( ctx, uniqueId );
}

- (JSValueRef)deleteTimer:(JSContextRef)ctx argc:(size_t)argc argv:(const JSValueRef [])argv {
	if( argc != 1 || !JSValueIsNumber(ctx, argv[0]) ) return NULL;
	
	NSNumber * timerId = [NSNumber numberWithInt:(int)JSValueToNumber(ctx, argv[0], NULL)];
	NSTimer * timer = [timers objectForKey:timerId];
	
	//JSObjectRef func = [[timer userInfo] pointeValue];
	//JSValueUnprotect(ctx, func); // Humm... seems to crash? FIXME
	
	[timer invalidate];
	[timers removeObjectForKey:timerId];
	return NULL;
}

JS_FUNC( JS_AppMobi, setTimeout, ctx, argc, argv ) {
	return [self createTimer:ctx argc:argc argv:argv repeat:NO];
}

JS_FUNC( JS_AppMobi, setInterval, ctx, argc, argv ) {
	return [self createTimer:ctx argc:argc argv:argv repeat:YES];
}

JS_FUNC( JS_AppMobi, clearTimeout, ctx, argc, argv ) {
	return [self deleteTimer:ctx argc:argc argv:argv];
}

JS_FUNC( JS_AppMobi, clearInterval, ctx, argc, argv ) {
	return [self deleteTimer:ctx argc:argc argv:argv];
}

-(void)cancelAllTimers {
	for( NSString * key in timers ) {
		NSTimer * timer = [timers objectForKey:key];
		if( [timer isValid] ) {
			//NSLog( @"Pausing timer: %@ with date : %@", timer, [timer fireDate] );
			[timer invalidate];
		}
	}
}

JS_FUNC( JS_AppMobi, cancelAllTimers, ctx, argc, argv ) {
    [self cancelAllTimers];
	return NULL;
}

- (void)timerCallback:(NSTimer *)timer {
	JSObjectRef func = [[timer userInfo] pointerValue];
	[[DirectCanvas instance] invokeCallback:func thisObject:NULL argc:0 argv:NULL];
}

- (void)pauseTimers:(NSNotification *)notification {
	if( pauseTime ) return; // already paused?
	
	pauseTime = [[NSDate dateWithTimeIntervalSinceNow:0] retain];
	timerTimes = [[NSMutableDictionary alloc] init];

	for( NSString * key in timers ) {
		NSTimer * timer = [timers objectForKey:key];
		if( [timer isValid] ) {
			//NSLog( @"Pausing timer: %@ with date : %@", timer, [timer fireDate] );
			[timerTimes setObject:[timer fireDate] forKey:key];
			[timer setFireDate:[NSDate distantFuture]];
		}
	}
}

- (void)resumeTimers:(NSNotification *)notification {
	if( !timerTimes ) return;
	
	for( NSString * key in timerTimes ) {
		NSTimer * timer = [timers objectForKey:key];
		NSDate * timerTime = [timerTimes objectForKey:key];
		if(	timer && timerTime ) {
			float nudge = [pauseTime timeIntervalSinceNow] * -1;
			//NSLog( @"Resuming timer: %@ with nudge : %f", timer, nudge );
			[timer setFireDate:[timerTime initWithTimeInterval:nudge sinceDate:timerTime]];
		}
	}
	
	[pauseTime release];
	pauseTime = nil;
	
	[timerTimes release];
	timerTimes = nil;
}




// ----------------------------------------------------------
// screen/device properties

JS_GET(JS_AppMobi, devicePixelRatio, ctx ) {
	return JSValueMakeNumber( ctx, [UIScreen mainScreen].scale );
}

JS_GET(JS_AppMobi, screenWidth, ctx ) {
	// FIXME: account for orientation?
	return JSValueMakeNumber( ctx, [UIScreen mainScreen].currentMode.size.width );
}

JS_GET(JS_AppMobi, screenHeight, ctx ) {
	// FIXME: account for orientation?
	float height = [UIScreen mainScreen].currentMode.size.height - ([DirectCanvas statusBarHidden] ? 0 : 20);
	return JSValueMakeNumber( ctx, height );
}

JS_GET(JS_AppMobi, landscapeMode, ctx ) {
	return JSValueMakeBoolean( ctx, [DirectCanvas landscapeMode] );
}

JS_GET(JS_AppMobi, userAgent, ctx ) {
	// FIXME?! iPhone3/4 and iPod all have the same user agent string ('iPhone')
	// Only iPad is different
	
	JSStringRef device;
	if( [[[UIDevice currentDevice] model] hasPrefix:@"iPad"] ) {
		device = JSStringCreateWithUTF8CString("iPad");
	}
	else {
		device = JSStringCreateWithUTF8CString("iPhone");
	}
	JSValueRef ret = JSValueMakeString(ctx, device);
	JSStringRelease(device);
	return ret;
}


- (void)dealloc {
    [self cancelAllTimers];
	[timers release];
	[super dealloc];
}

@end

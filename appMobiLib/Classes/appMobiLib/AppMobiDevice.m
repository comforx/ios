
#import "AppMobiDevice.h"
#import <SystemConfiguration/SCNetworkReachability.h>
#import "AppMobiViewController.h"
#import "AppMobiDelegate.h"
#import "AppConfig.h"
#import "Player.h"
#import "AppMobiModule.h"
#import "AppMobiPlayer.h"
#import "AppMobiWebView.h"
#import "PlayingView.h"

@implementation AppMobiDevice

@synthesize shouldBlock;
@synthesize whiteList;

- (id)initWithWebView:(AppMobiWebView *)webview
{
	self = (AppMobiDevice *) [super initWithWebView:webview];
	
	whiteList = [[NSArray alloc] init];
	return self;
}

- (NSDictionary*)deviceProperties
{
	UIDevice *device = [UIDevice currentDevice];
	NSMutableDictionary *devProps = [NSMutableDictionary dictionaryWithCapacity:4];
	[devProps setObject:[NSString stringWithString:@"iOS"] forKey:@"platform"];
	[devProps setObject:[device systemVersion] forKey:@"version"];
	[devProps setObject:[device uniqueIdentifier] forKey:@"uuid"];
	[devProps setObject:[device model] forKey:@"model"];
	NSString *orientation;
	switch ([[UIApplication sharedApplication] statusBarOrientation]){
		case UIInterfaceOrientationPortrait:
			orientation = @"0";
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			orientation = @"180";
			break;
		case UIInterfaceOrientationLandscapeLeft:
			orientation = @"90";
			break;
		case UIInterfaceOrientationLandscapeRight:
			orientation = @"-90";
			break;
	}
	[devProps setObject:orientation forKey:@"initialOrientation"];
	[devProps setObject:[self getConnection] forKey:@"connection"];
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"AppMobiVersion"];
	[devProps setObject:version forKey:@"appmobiversion"];
	NSString *phoneGapVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"PhoneGapVersion"];
	[devProps setObject:phoneGapVersion forKey:@"phonegapversion"];
	
	[devProps setObject:[NSNumber numberWithBool:webView.config.hasCaching] forKey:@"hasCaching"];
	AMLog(@"%@", [NSNumber numberWithBool:webView.config.hasCaching]);
	[devProps setObject:[NSNumber numberWithBool:webView.config.hasAnalytics] forKey:@"hasAnalytics"];
	[devProps setObject:[NSNumber numberWithBool:webView.config.hasStreaming] forKey:@"hasStreaming"];
	[devProps setObject:[NSNumber numberWithBool:webView.config.hasAdvertising] forKey:@"hasAdvertising"];
	[devProps setObject:[NSNumber numberWithBool:webView.config.hasPush] forKey:@"hasPush"];
	[devProps setObject:[NSNumber numberWithBool:webView.config.hasPayments] forKey:@"hasPayments"];
	[devProps setObject:[NSNumber numberWithBool:webView.config.hasUpdates] forKey:@"hasUpdates"];
	
	PlayingView *playerView = (PlayingView *) [[AppMobiViewController masterViewController] getPlayerView];
	NSString* lastPlaying = playerView.lastPlaying;
	[devProps setObject:(lastPlaying==nil?@"":lastPlaying) forKey:@"lastPlaying"];
	
	if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
		[devProps setObject:[NSString stringWithFormat:@"%f",[UIScreen mainScreen].scale] forKey:@"density"];
	} else {
		[devProps setObject:[NSString stringWithFormat:@"%f",1.0f] forKey:@"density"];
	}

	AppMobiDelegate *delegate = [AppMobiDelegate sharedDelegate];
	[devProps setObject:delegate.urlQuery==nil?@"":delegate.urlQuery forKey:@"queryString"];
	
	NSDictionary *devReturn = [NSDictionary dictionaryWithDictionary:devProps];
	return devReturn;
}

- (void)fireConnectionUpdate:(id)sender
{
	NSString *js = [NSString stringWithFormat:@"AppMobi.device.connection = \"%@\"; var e = document.createEvent('Events');e.initEvent('appMobi.device.connection.update',true,true);document.dispatchEvent(e);", connection];
	AMLog(@"%@",js);
	[webView injectJS:js];
}

- (void)getConnectionThread:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *host = @"www.flycast.fm";
	SCNetworkReachabilityFlags flags;
	SCNetworkReachabilityRef reachability =  SCNetworkReachabilityCreateWithName(NULL, [host UTF8String]);
	SCNetworkReachabilityGetFlags(reachability, &flags);
	CFRelease(reachability);
	
	BOOL isReachable = (flags & kSCNetworkReachabilityFlagsReachable) == kSCNetworkReachabilityFlagsReachable;
	BOOL needsConnection = (flags & kSCNetworkReachabilityFlagsConnectionRequired) == kSCNetworkReachabilityFlagsConnectionRequired;
	BOOL noWifi = (flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN;
	
	if(isReachable && !needsConnection && !noWifi) connection =  @"wifi";
	else if(isReachable && !needsConnection && noWifi) connection = @"cell";
	else connection = @"none";
	
	if( fireEvent == YES ) [self fireConnectionUpdate:nil];
	fireEvent = NO;
	
	[pool release];
}

- (void)timeoutConnectionUpdate:(id)sender
{
	if( fireEvent == NO ) return;
	fireEvent = NO;
	connection = @"none";
	[self fireConnectionUpdate:nil];
}

- (void)fireGetConnection:(id)sender
{
	connection = @"unknown";
	[NSThread detachNewThreadSelector:@selector(getConnectionThread:) toTarget:self withObject:nil];
}

- (NSString *)getConnection
{
	return connection;
}

- (void)managePower:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	BOOL shouldStayOn = [(NSString *)[arguments objectAtIndex:0] boolValue];
	BOOL onlyIfPluggedIn = [(NSString *)[arguments objectAtIndex:1] boolValue];
	
	UIDevice *device = [UIDevice currentDevice];
	device.batteryMonitoringEnabled = YES;
	
	if(!shouldStayOn) {
		[[UIApplication sharedApplication] setIdleTimerDisabled:NO];
	} else {
		if(onlyIfPluggedIn) {
			BOOL charging = (device.batteryState == UIDeviceBatteryStateCharging ||device.batteryState == UIDeviceBatteryStateFull);
			[[UIApplication sharedApplication] setIdleTimerDisabled:charging];
		} else {
			[[UIApplication sharedApplication] setIdleTimerDisabled:YES];
		}
    }
}

- (void)setAutoRotate:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	BOOL shouldRotate = [(NSString *)[arguments objectAtIndex:0] boolValue];
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[vc setAutoRotate:shouldRotate];
}

- (void)setRotateOrientation:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *orientation = (NSString *)[arguments objectAtIndex:0];
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[vc setRotateOrientation:orientation];
}

- (void)updateConnection:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	fireEvent =  YES;
	[self fireGetConnection:nil];
	[NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(timeoutConnectionUpdate:) userInfo:nil repeats:NO];
}

- (void)registerLibrary:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *library = (NSString *)[arguments objectAtIndex:0];
	
	if( library == nil || [library length] == 0 ) return;

	id obj = [webView getModuleInstance:library];
	if( obj != nil && [obj isKindOfClass:[AppMobiModule class]]  )
	{
		[obj initialize:webView];
	}
}

- (void)launchExternal:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *url = (NSString *)[arguments objectAtIndex:0];
	
	if( url == nil || [url length] == 0 ) return;
	
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

//called by getRemoteData to run in worker thread
- (void)downloadRemoteData:(NSMutableArray*)arguments {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSError *error = nil;
	NSHTTPURLResponse *response = nil;
	NSString *url, *method, *postData, *successCallback, *errorCallback, *rdId;
	NSData *data = nil;
	BOOL success = NO;
	BOOL hasId = NO;
	
	url = (NSString *)[arguments objectAtIndex:0];
	if( url == nil || [url length] == 0 ) return;
	
	method = (NSString *)[arguments objectAtIndex:1];
	if( method == nil || method == 0 ) return;
	
	postData = (NSString *)[arguments objectAtIndex:2];
	if(postData == nil) postData = [NSString stringWithString:@""];
	
	successCallback = (NSString *)[arguments objectAtIndex:3];
	if( successCallback == nil || [successCallback length] == 0 ) return;
	
	errorCallback = (NSString *)[arguments objectAtIndex:4];
	if( errorCallback == nil || [errorCallback length] == 0 ) return;

	//handle old js interface which did not have optional id
	rdId = [arguments count]<6?@"":(NSString *)[arguments objectAtIndex:5];
	hasId = [arguments count]<7?NO:[(NSString *)[arguments objectAtIndex:6] boolValue];

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLCacheStorageNotAllowed timeoutInterval:60];
	
	//if it's a post, set method and body
	if([method caseInsensitiveCompare:@"POST"]==NSOrderedSame) {
		[request setHTTPMethod:@"POST"];
		[request setHTTPBody:[postData dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	//send the request
	data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

	//check error
	if(error != nil) {
		//AMLog(@"error -- code: %d, localizedDescription: %@", [error code], [error localizedDescription]);
	} else {
		//check response status
		if([[NSString stringWithFormat:@"%d",[response statusCode]] hasPrefix:@"2"]) {
			success = YES;
		} else {
			//AMLog(@"error -- code: %d", [response statusCode]);
			//AMLog(@"error: %@", [response allHeaderFields]);
		}
	}
	
	//inject response
	NSString* js;
	char delimiter = '"';
	if(success) {
		NSString* responseBody = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

		//check for BOM characters, then strip if present
		NSRange xmlRange = [responseBody rangeOfString:@"\u00ef\u00bb\u00bf"];
		if(xmlRange.location == 0 && xmlRange.length == 3) responseBody = [responseBody substringFromIndex:3];
		
		//escape internal double-quotes
		responseBody = [responseBody stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
		responseBody = [responseBody stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
		
		//replace newline characters
		responseBody = [responseBody stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\\n"];
		responseBody = [responseBody stringByReplacingOccurrencesOfString:@"\r" withString:@"\\n"];
		responseBody = [responseBody stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
		
		if(hasId) {
			js = [NSString stringWithFormat:@"%@(%c%@%c, %c%@%c);", successCallback, delimiter, rdId, delimiter, delimiter, responseBody, delimiter];
		} else {
			js = [NSString stringWithFormat:@"%@(%c%@%c);", successCallback, delimiter, responseBody, delimiter];
		}
	} else {
		NSString* errorMessage;
		if(error != nil) {
			errorMessage = [NSString stringWithFormat:@"error -- code: %d, localizedDescription: %@", [error code], [error localizedDescription]];
		} else {
			errorMessage = [NSString stringWithFormat:@"error -- code: %d", [response statusCode]];
		}
		if(hasId) {
			js = [NSString stringWithFormat:@"%@(%c%@%c, %c%@%c);", errorCallback, delimiter, rdId, delimiter, delimiter, errorMessage, delimiter];
		} else {
			js = [NSString stringWithFormat:@"%@(%c%@%c);", errorCallback, delimiter, errorMessage, delimiter];
		}
	}
	
	AMLog(@"%@",js);
	[webView injectJS:js];
	
	[pool release];
}

- (void)getRemoteData:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	[NSThread detachNewThreadSelector:@selector(downloadRemoteData:) toTarget:self withObject:arguments];	
}

- (NSString *)getStatusText:(int)code
{
	NSString *status = @"";
	
	switch( code )
	{
			case 200:
			status = [NSString stringWithFormat:@"OK"];
			break;
			case 201:
			status = [NSString stringWithFormat:@"CREATED"];
			break;
			case 202:
			status = [NSString stringWithFormat:@"Accepted"];
			break;
			case 203:
			status = [NSString stringWithFormat:@"Partial Information"];
			break;
			case 204:
			status = [NSString stringWithFormat:@"No Response"];
			break;
			case 301:
			status = [NSString stringWithFormat:@"Moved"];
			break;
			case 302:
			status = [NSString stringWithFormat:@"Found"];
			break;
			case 303:
			status = [NSString stringWithFormat:@"Method"];
			break;
			case 304:
			status = [NSString stringWithFormat:@"Not Modified"];
			break;
			case 400:
			status = [NSString stringWithFormat:@"Bad request"];
			break;
			case 401:
			status = [NSString stringWithFormat:@"Unauthorized"];
			break;
			case 402:
			status = [NSString stringWithFormat:@"PaymentRequired"];
			break;
			case 403:
			status = [NSString stringWithFormat:@"Forbidden"];
			break;
			case 404:
			status = [NSString stringWithFormat:@"Not found"];
			break;
			case 500:
			status = [NSString stringWithFormat:@"Internal Error"];
			break;
			case 501:
			status = [NSString stringWithFormat:@"Not implemented"];
			break;
			case 502:
			status = [NSString stringWithFormat:@"Service temporarily overloaded"];
			break;
			case 503:
			status = [NSString stringWithFormat:@"Gateway timeout"];
			break;			
	}
	
	return status;
}

- (void)downloadRemoteDataExt:(NSMutableArray*)arguments {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSError *error = nil;
	NSHTTPURLResponse *response = nil;
	NSString *url, *method, *postData, *iden, *headers;
	NSData *data = nil;
	
	url = (NSString *)[arguments objectAtIndex:0];
	iden = (NSString *)[arguments objectAtIndex:1];
	method = (NSString *)[arguments objectAtIndex:2];
	postData = (NSString *)[arguments objectAtIndex:3];
	headers = (NSString *)[arguments objectAtIndex:4];

	if([method length] == 0) [NSString stringWithString:@"GET"];
	
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLCacheStorageNotAllowed timeoutInterval:60];
	
	//if it's a post, set method and body
	if([method caseInsensitiveCompare:@"POST"]==NSOrderedSame) {
		[request setHTTPMethod:@"POST"];
		[request setHTTPBody:[postData dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	if( [headers length] > 0 )
	{
		int length = 0;
		NSString *field = nil;
		NSString *value = nil;
		
		NSRange range = [headers rangeOfString:@"~"];
		while( range.location != NSNotFound )
		{
			length = [[headers substringToIndex:range.location] intValue];				
			if( length > 0 )
			{
				field = [[headers substringFromIndex:range.location + 1] substringToIndex:length];
			}
			headers = [headers substringFromIndex:range.location + 1 + length];
			
			range = [headers rangeOfString:@"~"];
			length = [[headers substringToIndex:range.location] intValue];				
			if( length > 0 )
			{
				value = [[headers substringFromIndex:range.location + 1] substringToIndex:length];
			}
			headers = [headers substringFromIndex:range.location + 1 + length];
			
			if( field != nil && value != nil )
			{
				[request addValue:value forHTTPHeaderField:field];
			}
			
			field = nil;
			value = nil;
			range = [headers rangeOfString:@"~"];
		}
	}
	
	//send the request
	data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	
	//inject response
	NSString* js;
	if( response != nil ) {
		NSString* responseBody = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
		
		//check for BOM characters, then strip if present
		NSRange xmlRange = [responseBody rangeOfString:@"\u00ef\u00bb\u00bf"];
		if(xmlRange.location == 0 && xmlRange.length == 3) responseBody = [responseBody substringFromIndex:3];		
		
		//escape internal double-quotes
		responseBody = [responseBody stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
		responseBody = [responseBody stringByReplacingOccurrencesOfString:@"\\\\\"" withString:@"\\\\\\\""];
		
		//replace newline characters
		responseBody = [responseBody stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\\n"];
		responseBody = [responseBody stringByReplacingOccurrencesOfString:@"\r" withString:@"\\n"];
		responseBody = [responseBody stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
		
		NSString *extras = @"{";
		extras = [extras stringByAppendingFormat:@"status:'%d',", [response statusCode]];
		extras = [extras stringByAppendingFormat:@"statusText:'%@',", [self getStatusText:[response statusCode]]];
		extras = [extras stringByAppendingFormat:@"headers: {"];
		
		NSDictionary *allheaders = [response allHeaderFields];        
		NSArray *allkeys = [allheaders allKeys];
		for( int i = 0; i < [allkeys count]; i++ )
		{
			NSString *key = [allkeys objectAtIndex:i];
			NSString *value = [allheaders objectForKey:key];
            
            if( [key compare:@"Set-Cookie" options:NSCaseInsensitiveSearch] == NSOrderedSame )
            {
                value = [value stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
                extras = [extras stringByAppendingFormat:@"'%@':'%@',", key, value];
                NSString *newvalue = @"[";
                
                NSRange rangeC = [value rangeOfString:@"," options:NSCaseInsensitiveSearch];
                NSRange rangeE = [value rangeOfString:@"expires=" options:NSCaseInsensitiveSearch];
                while( rangeC.location != NSNotFound && rangeC.length == 1 )
                {
                    if( rangeE.location != NSNotFound && rangeC.location == rangeE.location + 11 )
                        rangeC = [value rangeOfString:@"," options:NSCaseInsensitiveSearch range:NSMakeRange(rangeC.location+1, [value length] - (rangeC.location+1))];
                    
                    if( rangeC.location == NSNotFound ) continue;
                    
                    newvalue = [newvalue stringByAppendingFormat:@"'%@',", [value substringToIndex:rangeC.location]];
                    value = [value substringFromIndex:rangeC.location+2];
                    
                    rangeC = [value rangeOfString:@","];
                    rangeE = [value rangeOfString:@"expires=" options:NSCaseInsensitiveSearch];                
                }
                
                newvalue = [newvalue stringByAppendingFormat:@"'%@'", value];
                newvalue = [newvalue stringByAppendingString:@"]"];     
                extras = [extras stringByAppendingFormat:@"'All-Cookies':%@,", newvalue];
            }
            else
            {
                value = [value stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
                extras = [extras stringByAppendingFormat:@"'%@':'%@',", key, value];
            }
		}
		extras = [extras stringByAppendingFormat:@"} }"];
		
		js = [NSString stringWithFormat:@"var e = document.createEvent('Events');e.initEvent('appMobi.device.remote.data',true,true);e.success=true;e.id='%@';e.response=\"%@\";e.extras=%@;document.dispatchEvent(e);", iden, responseBody, extras];
	} else {
		NSString* errorMessage = [NSString stringWithFormat:@"error -- code: %d, localizedDescription: %@", [error code], [error localizedDescription]];
		js = [NSString stringWithFormat:@"var e = document.createEvent('Events');e.initEvent('appMobi.device.remote.data',true,true);e.success=false;e.id='%@';e.response='';e.extras={};e.error='%@';document.dispatchEvent(e);", iden, errorMessage];
	}
	
	AMLog(@"%@",js);
	[webView performSelectorOnMainThread:@selector(injectJS:) withObject:js waitUntilDone:NO];
	
	[pool release];
}

- (void)getRemoteDataExt:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	[NSThread detachNewThreadSelector:@selector(downloadRemoteDataExt:) toTarget:self withObject:arguments];	
}

- (void)showRemoteSite:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *url = (NSString *)[arguments objectAtIndex:0];
	int closePortX, closePortY, closeLandX, closeLandY, closeW, closeH;
	closePortX = [(NSString *)[arguments objectAtIndex:1] intValue];
	closePortY = [(NSString *)[arguments objectAtIndex:2] intValue];
	
	if( [arguments count] == 5 )
	{
		closeLandX = closePortX;
		closeLandY = closePortY;
		closeW = [(NSString *)[arguments objectAtIndex:3] intValue];
		closeH = [(NSString *)[arguments objectAtIndex:4] intValue];
	}
	else
	{
		closeLandX = [(NSString *)[arguments objectAtIndex:3] intValue];
		closeLandY = [(NSString *)[arguments objectAtIndex:4] intValue];
		closeW = [(NSString *)[arguments objectAtIndex:5] intValue];
		closeH = [(NSString *)[arguments objectAtIndex:6] intValue];
	}
	
	if( closeW == 0 ) closeW = 48;
	if( closeH == 0 ) closeH = 48;

	if( url == nil || [url length] == 0 ) return;
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[vc showRemote:url forApp:webView.config atPort:CGRectMake(closePortX,closePortY,closeW,closeH) atLand:CGRectMake(closeLandX,closeLandY,closeW,closeH)];
}

- (void)closeRemoteSite:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[vc hideRemote:nil];
}

- (void)mainViewExecute:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *msg = (NSString *)[arguments objectAtIndex:0];
	[[[AppMobiViewController masterViewController] getActiveWebView] performSelectorOnMainThread:@selector(injectJS:) withObject:msg waitUntilDone:NO];
}

- (void)closeTab:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[vc closeActiveTab:nil];
}

- (void)startManifestCaching:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[vc startManifestCaching:nil];
}

- (void)endManifestCaching:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[vc endManifestCaching:nil];
}

- (void)blockRemotePages:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	shouldBlock = [(NSString *)[arguments objectAtIndex:0] boolValue];
	NSString *domainlist = [arguments objectAtIndex:1];
	
	[whiteList release];
	whiteList = [[domainlist componentsSeparatedByString:@"|"] retain];
}

- (void)scanBarcode:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[vc scanBarcode:nil];
}

- (void)installUpdate:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	if( webView.config.hasUpdates == NO ) return;
	
	[[AppMobiDelegate sharedDelegate] performSelectorOnMainThread:@selector(notifyUserAndInstall:) withObject:webView.config waitUntilDone:NO];
}

- (void)hideSplashScreen:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	[[AppMobiDelegate sharedDelegate] performSelectorOnMainThread:@selector(hideSplashScreen:) withObject:nil waitUntilDone:NO];
}

- (void) dealloc
{
	[whiteList release];
	[super dealloc];
}

@end

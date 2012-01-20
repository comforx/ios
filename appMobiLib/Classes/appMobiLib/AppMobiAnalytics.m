
//
//  AppMobiAnalytics.m
//  appMobiLib
//

//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "AppMobiAnalytics.h"
#import "AppMobiDelegate.h"
#import "AppConfig.h"
#import "TargetConditionals.h"
#import "AppMobiWebView.h"

@implementation PageEvent

@synthesize page;
@synthesize url;
@synthesize date;

- (id) initWithCoder:(NSCoder *)coder
{
	if (self = [super init])
	{
		self.page = [coder decodeObjectForKey:@"page"];
		self.url = [coder decodeObjectForKey:@"url"];
		self.date = [coder decodeObjectForKey:@"date"];
	}
	
	return self;
}

- (void) encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:page forKey:@"page"];
	[coder encodeObject:url forKey:@"url"];
	[coder encodeObject:date forKey:@"date"];
}

- (void) dealloc
{
	[page release];
	[url release];
	[date release];
	[super dealloc];
}

@end

@implementation AppMobiAnalytics

@synthesize strDeviceID;

- (void)saveEvents:(id)sender
{
	NSString *filename = [webView.config.baseDirectory stringByAppendingPathComponent:@"analytics.dat"];
	[NSKeyedArchiver archiveRootObject:arEvents toFile:filename];
}

- (void)loadEvents:(id)sender
{
	NSString *filename = [webView.config.baseDirectory stringByAppendingPathComponent:@"analytics.dat"];
	
	if( [[NSFileManager defaultManager] fileExistsAtPath:filename] )
	{
		arEvents = [[NSKeyedUnarchiver unarchiveObjectWithFile:filename] retain];
	}
	else
	{
		arEvents = [[NSMutableArray alloc] init];			
	}
	
	NSDate *last = [[NSDate date] dateByAddingTimeInterval:-1 * 60 * 60 * 24 * 30];
	for( int i = [arEvents count] - 1; i >= 0; i-- )
	{
		PageEvent *event = (PageEvent *) [arEvents objectAtIndex:i];
		if( [last compare:event.date] == NSOrderedDescending )
		{
			[arEvents removeObjectAtIndex:i];
		}
	}
	
	[self saveEvents:nil];
}

- (id)initWithWebView:(AppMobiWebView *)webview
{
	self = (AppMobiAnalytics *) [super initWithWebView:webview];
	
	lkEvents = [[NSLock alloc] init];
	
	NSString *deviceJar = [NSString stringWithFormat:@"%@.deviceid", webView.config.appName];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	strDeviceID = [defaults objectForKey:deviceJar];
	if( strDeviceID == nil )
	{
		NSString *devid = [[UIDevice currentDevice] uniqueIdentifier];
		NSTimeInterval fsec = [[NSDate date] timeIntervalSince1970];
		int isec = fsec;
		strDeviceID = [NSString stringWithFormat:@"%@.%d", [devid substringFromIndex:24], isec];
		[defaults setObject:strDeviceID forKey:deviceJar];
		[defaults synchronize];		
	}
	
	[self loadEvents:nil];
	if( [arEvents count] > 0 )
		[NSThread detachNewThreadSelector:@selector(statsWorker:) toTarget:self withObject:nil];
	
	return self;
}

- (void)logPageEvent:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
	if(!webView.config.hasAnalytics) return;
	
	NSString *page = [(NSString *) [arguments objectAtIndex:0] stringByReplacingOccurrencesOfString:@" " withString:@"+"];
	NSString *query = [(NSString *) [arguments objectAtIndex:1] stringByReplacingOccurrencesOfString:@" " withString:@"+"];
	NSString *status = [(NSString *) [arguments objectAtIndex:2] stringByReplacingOccurrencesOfString:@" " withString:@"+"];
	NSString *method = [(NSString *) [arguments objectAtIndex:3] stringByReplacingOccurrencesOfString:@" " withString:@"+"];
	NSString *bytes = [(NSString *) [arguments objectAtIndex:4] stringByReplacingOccurrencesOfString:@" " withString:@"+"];
	NSString *referrer = [(NSString *) [arguments objectAtIndex:5] stringByReplacingOccurrencesOfString:@" " withString:@"+"];
	NSDate *now = [NSDate date];
	
	UIDevice *dev = [UIDevice currentDevice];
	NSString *agent = [NSString stringWithFormat:@"Mozilla/5.0+(%@;+U;+CPU+iOS+%@+like+Mac+OS+X;+en-us)+AppleWebKit/531.21.10+(KHTML,+like+Gecko)+Version/4.0.4+Mobile/7B405+Safari/531.21.10", [dev model], [dev systemVersion]];
	NSString *ref = [NSString stringWithFormat:@"http://%@-%@-%@", webView.config.appName, webView.config.relName, referrer];
	
	NSString *pagestr = [NSString stringWithFormat:@"%@ ", [now description]]; // date, time
	pagestr = [pagestr substringToIndex:20];
	pagestr = [pagestr stringByAppendingFormat:@"%%@ %@ ", strDeviceID]; // ip, user
	pagestr = [pagestr stringByAppendingFormat:@"%@ %@ %@ %@ %@ ", method, page, query, status, bytes]; // method, page, query, status bytes
	pagestr = [pagestr stringByAppendingFormat:@"%@ %@", agent, ref]; // agent referrer
	
	//Mozilla/5.0+(__DEVICE_NAME__;+U;+CPU+iOS+__OS_VERSION__+like+Mac+OS+X;+en-us)+AppleWebKit/531.21.10+(KHTML,+like+Gecko)+Version/4.0.4+Mobile/7B405+Safari/531.21.10
	
	//2011-02-28 10:01:00 173.12.6.0 97261EC5D261.1299184982 GET /device/update/download.event - 200 0 Mozilla/5.0+(iPad;+U;+CPU+iOS+3_2_1+like+Mac+OS+X;+en-us)+AppleWebKit/531.21.10+(KHTML,+like+Gecko)+Version/4.0.4+Mobile/7B405+Safari/531.21.10+(97261EC5D261.1299184982) http://FoxNews2GO-3.2.5-index.html
	
	[lkEvents lock];
	
	PageEvent *event = [[PageEvent alloc] init];
	event.date = now;
	event.url = webView.config.analyticsURL;
	event.page = pagestr;
	[arEvents addObject:event];
	[event release];
	[self saveEvents:nil];

	AMLog( @"logPageEvent ~~ %@", pagestr );
	
	[lkEvents unlock];
	
	[NSThread detachNewThreadSelector:@selector(statsWorker:) toTarget:self withObject:nil];	
}

- (void)statsWorker:(id)anObject
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSError *error = nil;
	NSHTTPURLResponse *response;
	NSData *data;
	NSString *localIP;
	NSMutableURLRequest *request = nil;
	
	NSData *result = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://services.appmobi.com/external/echoip.aspx"]];
	if( result == nil || [result length] == 0 || [result length] > 15 )
	{
		AMLog( @"statsWorker ~~ echoip fail" );
		[pool release];
		return;
	}

	localIP = [[NSString alloc ]initWithData:result encoding:NSUTF8StringEncoding];
	[lkEvents lock];
	int count = [arEvents count];
	for( int i = count - 1; i >= 0; i-- )
	{
		PageEvent *event = (PageEvent *) [arEvents objectAtIndex:i];
		NSString *page = [NSString stringWithFormat:event.page, localIP];
		NSString *newpage = [[AppMobiDelegate sharedDelegate] urlencode:page];
		
		NSString *urlstr = [NSString stringWithFormat:@"%@?Action=SendMessage&MessageBody=%@&Version=2009-02-01", event.url, newpage];
		request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlstr] cachePolicy:NSURLCacheStorageNotAllowed timeoutInterval:5];								
		data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
		if( data != nil && [data length] > 0 )
		{
			AMLog( @"statsWorker ~~ %@", urlstr );

			NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			NSRange range = [response rangeOfString:@"<SendMessageResponse"];
			if( range.length > 0 && range.location != -1 )
			{
				[arEvents removeObjectAtIndex:i];
				[self saveEvents:nil];
			}
		}
	}
	
	[lkEvents unlock];
	
	[pool release];
}

- (void) dealloc
{
	[super dealloc];
}

@end

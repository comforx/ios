//
//  AppMobiPlayer.m
//  AppMobiLib
//

//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "AppMobiPlayer.h"
#import "AppMobiViewController.h"
#import "PlayingView.h"
#import "XMLNode.h"
#import "XMLTracklist.h"
#import "AppMobiDelegate.h"
#import "AppConfig.h"
#import "AppMobiWebView.h"
#import "Player.h"
#import <AudioToolbox/AudioServices.h>
#import <AVFoundation/AVFoundation.h>

@implementation AppMobiPlayer

NSMutableDictionary *testLocalCached = nil;

- (id)initWithWebView:(AppMobiWebView *)webview
{
	lkUpdateAudioData = [[NSLock alloc] init];
	
	self = (AppMobiPlayer *) [super initWithWebView:webview];
	
    if( testLocalCached == nil ) testLocalCached = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (void)show:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];

	[vc popWebView];
	[vc pushPlayerView];
}

- (void)hide:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	
	[vc popPlayerView];
	[vc pushWebView];
}

- (void)playPodcast:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *strPodcastURL = [arguments objectAtIndex:0];
	AppMobiViewController *vc = [AppMobiViewController masterViewController];

	[vc getPlayerView].lastPlaying = [strPodcastURL copy];
	if( strPodcastURL.length == 0 || [strPodcastURL hasPrefix:@"http://"] == NO ) {
		
		NSString *filepath = [webView.config.appDirectory stringByAppendingPathComponent:strPodcastURL];
		if( [[NSFileManager defaultManager] fileExistsAtPath:filepath] == YES )
		{
			strPodcastURL = [NSString stringWithFormat:@"http://localhost:58888/%@/%@/%@", webView.config.appName, webView.config.relName, strPodcastURL];
		}
		else
		{
			[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.podcast.error" waitUntilDone:NO];
			return;
		}
	}
	
	NSURL *urlPodcastURL = [NSURL URLWithString:strPodcastURL];
	if( urlPodcastURL == nil ) {
		[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.podcast.error" waitUntilDone:NO];
		return;
	}
	
	[[AppMobiDelegate sharedDelegate] initAudio];
	AudioSessionSetActive(YES);
	
	[[vc getPlayerView] playVideo:urlPodcastURL];
}

- (void)startStation:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	if(!webView.config.hasStreaming) return;
	[[AppMobiDelegate sharedDelegate] initAudio];
	AudioSessionSetActive(YES);

	NSString *strNetStationID = [arguments objectAtIndex:0];
	BOOL boolResumeMode = [(NSString *)[arguments objectAtIndex:1] boolValue];
	BOOL boolShowPlayer = [(NSString *)[arguments objectAtIndex:2] boolValue];
	
	//check if we are already playing this station
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	if ([vc getPlayerView].lastPlaying!=nil && [[vc getPlayerView].lastPlaying isEqualToString:strNetStationID]) {
		if( boolShowPlayer == YES )
		{		
			[vc popWebView];
			[vc pushPlayerView];
		}
		
		return;
	}
	
	if( [vc getPlayerView].adPlayer!=nil || [vc getPlayerView].videoPlayer != nil || [vc getPlayerView].bStarting  )
	{
		[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.station.busy" waitUntilDone:NO];
		return;
	}
	
	if( strNetStationID.length == 0 ) {
		[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.station.error" waitUntilDone:NO];
		return;
	}
	
	[vc getPlayerView].bResumeMode = boolResumeMode;
	if( boolResumeMode == NO )
	{
		[[vc getPlayerView] clearResume];
	}
	
	if( boolShowPlayer == YES )
	{		
		[vc popWebView];
		[vc pushPlayerView];
	}

	XMLNode *node = [[[XMLNode alloc] init] retain];
	node.nodeid = [strNetStationID retain];
	[[vc getPlayerView] getBackgrounds:webView.config];
	[[vc getPlayerView] queueNextNode:node];	
	
	[AppMobiDelegate sharedDelegate].myPlayer.station = strNetStationID;
	[vc getPlayerView].lastPlaying = [strNetStationID copy];
}

- (void)startShoutcast:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	if(!webView.config.hasStreaming) return;
	[[AppMobiDelegate sharedDelegate] initAudio];
	AudioSessionSetActive(YES);

	AppMobiViewController *vc = [AppMobiViewController masterViewController];	
	if( [vc getPlayerView].adPlayer!=nil || [vc getPlayerView].videoPlayer != nil || [vc getPlayerView].bStarting  )
	{
		[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.shoutcast.busy" waitUntilDone:NO];
		return;
	}
	
	[vc getPlayerView].bResumeMode = NO;
	[[vc getPlayerView] clearResume];

	NSString *strStationURL = [arguments objectAtIndex:0];
	BOOL boolShowPlayer = [(NSString *)[arguments objectAtIndex:1] boolValue];

	//check if we are already playing this station
	if ([vc getPlayerView].lastPlaying!=nil && [[vc getPlayerView].lastPlaying isEqualToString:strStationURL]) return;
	
	if( strStationURL.length == 0 || [strStationURL hasPrefix:@"http://"] == NO ) {
		[[AppMobiViewController masterViewController] performSelectorOnMainThread:@selector(fireEvent:) withObject:@"appMobi.player.shoutcast.error" waitUntilDone:NO];
		return;
	}
	
	if( boolShowPlayer == YES )
	{
		[vc popWebView];
		[vc pushPlayerView];
	}
	
	XMLNode *node = [[[XMLNode alloc] init] retain];
	node.nodeid = nil;
	node.nodeshout = [strStationURL retain];
	[[vc getPlayerView] getBackgrounds:webView.config];
	[[vc getPlayerView] queueNextNode:node];
	
	[AppMobiDelegate sharedDelegate].myPlayer.station = strStationURL;
	[vc getPlayerView].lastPlaying = [strStationURL copy];
}

- (void)cacheSoundLocal:(NSString *)strRelativePath
{
    NSString *fullPath = [NSString stringWithFormat:@"%@/%@", webView.config.appDirectory, strRelativePath];
    
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:fullPath];
    BOOL fileCached = ( [testLocalCached objectForKey:strRelativePath] != nil );
    if( fileExists == NO || fileCached == NO )
    {
        NSString *urlString = [[[webView request] URL] description];
        NSRange range = [urlString rangeOfString:@"/" options:NSBackwardsSearch];
		if( range.location != NSNotFound )
        {
			NSString *testLocalRoot = [urlString substringToIndex:range.location];
            NSString *testLocalUrl = [NSString stringWithFormat:@"%@/%@", testLocalRoot, strRelativePath];

            NSRange dirrange = [fullPath rangeOfString:@"/" options:NSBackwardsSearch];
            NSString *testLocalPath = [fullPath substringToIndex:dirrange.location];

            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:testLocalUrl]];
            if( data != nil && [data length] > 0 )
            {
                [testLocalCached setObject:strRelativePath forKey:strRelativePath];                
                [[NSFileManager defaultManager] createDirectoryAtPath:testLocalPath withIntermediateDirectories:YES attributes:nil error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:fullPath error:nil];
                [[NSFileManager defaultManager] createFileAtPath:fullPath contents:data attributes:nil];
            }
        }
    }
}

- (void)playSound:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *strRelativePath = (NSString *)[arguments objectAtIndex:0];
    if( [[AppMobiDelegate sharedDelegate] isTestLocal] == YES ) [self cacheSoundLocal:strRelativePath];
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] playSound:strRelativePath];
}

- (void)loadSound:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	if(arguments.count==1) {
		NSString *strRelativePath = (NSString *)[arguments objectAtIndex:0];
		if( [[AppMobiDelegate sharedDelegate] isTestLocal] == YES ) [self cacheSoundLocal:strRelativePath];
		
		AppMobiViewController *vc = [AppMobiViewController masterViewController];
		[[vc getPlayerView] loadSound:strRelativePath];
	} else {
		NSString *strRelativePath = (NSString *)[arguments objectAtIndex:0];
		int count = [(NSString *)[arguments objectAtIndex:1] intValue];
		
		if( [[AppMobiDelegate sharedDelegate] isTestLocal] == YES ) [self cacheSoundLocal:strRelativePath];
		
		AppMobiViewController *vc = [AppMobiViewController masterViewController];
		[[vc getPlayerView] loadSound:strRelativePath withPolyphony:count];
	}
}

- (void)unloadSound:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *strRelativePath = (NSString *)[arguments objectAtIndex:0];
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] unloadSound:strRelativePath];
}

- (void)unloadAllSounds:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] unloadAllSounds];
}

- (void)startAudio:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *strRelativePath = (NSString *)[arguments objectAtIndex:0];
    if( [[AppMobiDelegate sharedDelegate] isTestLocal] == YES ) [self cacheSoundLocal:strRelativePath];
	BOOL doesLoop = ([arguments count] > 1)?[[arguments objectAtIndex:1] boolValue]:NO;
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] startAudio:strRelativePath withLooping:doesLoop];
	[vc getPlayerView].lastPlaying = [strRelativePath copy];	
}

- (void)toggleAudio:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] toggleAudio];
}

- (void)stopAudio:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] stopAudio];
	[vc getPlayerView].lastPlaying = nil;
}

- (void)setAudioCurrentTime:(NSMutableArray *)arguments withDict:(NSMutableDictionary *)options {
	[lkUpdateAudioData lock];
	float time = [[arguments objectAtIndex:0] floatValue];
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] setAudioCurrentTime:time];
	NSString * js = [NSString stringWithFormat:
					 @"AppMobi.player.audioInfo = new AppMobi.AudioInfo(%f, %f);var e = document.createEvent('Events');e.initEvent('appMobi.player.audio.currenttime.set',true,true);document.dispatchEvent(e);", 
					 [[vc getPlayerView] getAudioCurrentTime], [[vc getPlayerView] getAudioCurrentLength]];
	[webView injectJS:js];
	[lkUpdateAudioData unlock];
}

- (void)updateAudioTime {
	[lkUpdateAudioData lock];
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	NSString * js = [NSString stringWithFormat:
					 @"AppMobi.player.audioInfo = new AppMobi.AudioInfo(%f, %f);", 
					 [[vc getPlayerView] getAudioCurrentTime], [[vc getPlayerView] getAudioCurrentLength]];
	[webView injectJS:js];
	[lkUpdateAudioData unlock];
}

- (void)startUpdatingAudioTime:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	if(audioUpdateTimer!=nil) {
		[audioUpdateTimer invalidate];
	}
	float frequency = [[arguments objectAtIndex:0] floatValue]/1000.0;
	audioUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:frequency target:self selector:@selector(updateAudioTime) userInfo:nil repeats:YES];
}

- (void)stopUpdatingAudioTime:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	if(audioUpdateTimer!=nil) {
		[audioUpdateTimer invalidate];
	}
}

- (void)setColors:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *strBackColor = [arguments objectAtIndex:0];
	NSString *strFillColor = [arguments objectAtIndex:1];
	NSString *strDoneColor = [arguments objectAtIndex:2];
	NSString *strPlayColor = [arguments objectAtIndex:3];
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];	
	[[vc getPlayerView] setBackColor:strBackColor fillColor:strFillColor doneColor:strDoneColor playColor:strPlayColor];
}

- (void)play:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] onPlay:nil];
}

- (void)pause:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] onPlay:nil];
}

- (void)stop:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] onStop:nil];
	[vc getPlayerView].lastPlaying = nil;
}

- (void)volume:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	int percentage = [(NSString *)[arguments objectAtIndex:0] intValue];
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] adjustVolume:percentage];
}

- (void)rewind:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] onPrev:nil];
}

- (void)ffwd:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] onNext:nil];
}

- (void)setPosition:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *portraitX = [arguments objectAtIndex:0];
	NSString *portraitY = [arguments objectAtIndex:1];
	NSString *landscapeX = [arguments objectAtIndex:2];
	NSString *landscapeY = [arguments objectAtIndex:3];
	CGPoint portrait = CGPointMake([portraitX floatValue], [portraitY floatValue]);
	CGPoint landscape = CGPointMake([landscapeX floatValue], [landscapeY floatValue]);
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] setPositionsPortrait:portrait AndLandscape:landscape];
}

- (void)dealloc
{
	[super dealloc];
}

@end

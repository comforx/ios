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

- (void)playSound:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *strRelativePath = (NSString *)[arguments objectAtIndex:0];
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] playSound:strRelativePath];
}

- (void)loadSound:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *strRelativePath = (NSString *)[arguments objectAtIndex:0];
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] loadSound:strRelativePath];
}

- (void)unloadSound:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *strRelativePath = (NSString *)[arguments objectAtIndex:0];
	
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] unloadSound:strRelativePath];
}

- (void)startAudio:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options {
	NSString *strRelativePath = (NSString *)[arguments objectAtIndex:0];
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
	float time = [[arguments objectAtIndex:0] floatValue];
	AppMobiViewController *vc = [AppMobiViewController masterViewController];
	[[vc getPlayerView] setAudioCurrentTime:time];
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

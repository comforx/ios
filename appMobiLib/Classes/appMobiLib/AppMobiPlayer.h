//
//  AppMobiPlayer.h
//  AppMobiLib
//

//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AppMobiCommand.h"

@interface AppMobiPlayer : AppMobiCommand {
}

- (void)show:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)hide:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)playPodcast:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;	 
- (void)startStation:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)startShoutcast:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)playSound:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)loadSound:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)unloadSound:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)startAudio:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)stopAudio:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)setAudioCurrentTime:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)toggleAudio:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)setColors:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)play:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)pause:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)stop:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)volume:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)rewind:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)ffwd:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)setPosition:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;

@end

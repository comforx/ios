//
//  DebugConsole.m
//  AppMobi
//
//  Created by Michael Nachbaur on 14/03/09.
//  Copyright 2009 Decaf Ninja Software. All rights reserved.
//

#import "AppMobiDebug.h"
#import "AppMobiDelegate.h"

@implementation AppMobiDebug

- (void)log:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options
{
    NSString* message = [arguments objectAtIndex:0];
    NSString* log_level = @"INFO";
    if ([arguments count]>1)
        log_level = [arguments objectAtIndex:1];

    AMLog(@"[%@] %@", log_level, message);
}

@end

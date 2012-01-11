//
//  AppMobiTestAppDelegate.m
//  AppMobiTest
//

//  Copyright __MyCompanyName__ 2010. All rights reserved.
//

#import "AppDelegate.h"
#import "AppMobiViewController.h"
#import "LoginViewController.h"

@implementation AppDelegate

@synthesize loginViewController;

- (id) init
{
	isTestContainer = NO;
	
	
    return [super init];
}

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
	//[NSThread sleepForTimeInterval:30.0];
	[super applicationDidFinishLaunching:application];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	[super applicationWillTerminate:application];
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
	return [super application:application handleOpenURL:url];
}

- (void)handleLogin:(BOOL)haveConfig
{
	LoginViewController *_loginViewController;
	if([AppMobiDelegate isIPad]) {
		//iPad
		_loginViewController = [[LoginViewController alloc] initWithNibName:@"iPadLoginView" bundle:[NSBundle mainBundle]];
	} else {
		//iPhone
		_loginViewController = [[LoginViewController alloc] initWithNibName:@"LoginView" bundle:[NSBundle mainBundle]];
	}

	self.loginViewController = _loginViewController;
	[_loginViewController release];
	self.loginViewController.haveConfig = haveConfig;
	[window addSubview:[loginViewController view]];
	
	if(![AppMobiDelegate isIPad]) {
		self.loginViewController.view.frame = [[UIScreen mainScreen] bounds];
	}
}

- (void)dealloc
{
	[loginViewController release];
	[super dealloc];
}

@end

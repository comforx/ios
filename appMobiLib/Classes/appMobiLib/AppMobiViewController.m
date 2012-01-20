
#import "AppMobiViewController.h"
#import	"AppMobiPushViewController.h"
#import "AppMobiDelegate.h"
#import "AppMobiPlayer.h"
#import "AMSNotification.h"
#import "PlayingView.h"
#import "Bookmark.h"
#import <QuartzCore/QuartzCore.h>
#import "AppConfig.h"
#import "XMLTrack.h"
#import "AppMobiNotification.h"
#import "AppMobiWebView.h"
#import "AppMobiCanvas.h"
#import "DirectCanvas.h"

AppMobiViewController *master = nil;

@implementation AppMobiViewController

@synthesize runUrl;
@synthesize window;
@synthesize _payConfig;
@synthesize _payBmk;
@synthesize _runBmk;
@synthesize _installBmk;
@synthesize fixedOrientation;
@synthesize bRichShowing;
@synthesize bPushShowing;

NSString *lastTrackInfo = nil;
NSString *lastTrackGuid = nil;

BOOL playerViewWasHidden = YES;
BOOL remoteViewWasHidden = YES;
BOOL richViewWasHidden = YES;
BOOL adfullViewWasHidden = YES;
BOOL mobiusIsRestarting = YES;
NSURLRequest* webViewRequest = nil;
UILabel* labelBeingEdited = nil;
UITextField* textBeingEdited = nil;

- (id) init
{
    self = [super init];
	master = self;
	bHomeShown = YES;
	bAllShown = YES;
	autoRotate = YES;
	lastTrackInfo = [[NSString alloc] initWithString:@""];
	self.fixedOrientation = [[NSString alloc] initWithString:@"any"];

	BOOL ipad = [AppMobiDelegate isIPad];
	mobiusOnImage = ipad?@"ipad_icon_mobius_on.png":@"tab_mobius_on.png";
	mobiusOffImage = ipad?@"ipad_icon_mobius.png":@"tab_mobius.png";
	tabOnImage = ipad?@"ipad_icon_tabs_on.png":@"tab_tabs_on.png";
	tabOffImage = ipad?@"ipad_icon_tabs.png":@"tab_tabs.png";
	setOnImage = ipad?@"ipad_icon_settings_on.png":@"tab_settings_on.png";
	setOffImage = ipad?@"ipad_icon_settings.png":@"tab_settings.png";
	
	homePics = [[NSMutableArray alloc] init];
	homeNames = [[NSMutableArray alloc] init];
	homeDels =  [[NSMutableArray alloc] init];
	homeBubbles = [[NSMutableArray alloc] init];
	
	settingsBkgs = [[NSMutableArray alloc] init];
	settingsNames = [[NSMutableArray alloc] init];
	settingsSwitches = [[NSMutableArray alloc] init];
	
	tabPics = [[NSMutableArray alloc] init];
	tabDels = [[NSMutableArray alloc] init];
	arTabs = [[NSMutableArray alloc] init];
	
	arAllBookmarks = [[NSMutableArray alloc] init];
	arActiveBookmarks = arAllBookmarks;

	arTabSpinner = [[NSMutableArray alloc ]initWithObjects:
					[UIImage imageNamed:@"loading_tab_spinner_01.png"],
					[UIImage imageNamed:@"loading_tab_spinner_02.png"],
					[UIImage imageNamed:@"loading_tab_spinner_03.png"],
					[UIImage imageNamed:@"loading_tab_spinner_04.png"],
					[UIImage imageNamed:@"loading_tab_spinner_05.png"],
					[UIImage imageNamed:@"loading_tab_spinner_06.png"],
					[UIImage imageNamed:@"loading_tab_spinner_07.png"],
					[UIImage imageNamed:@"loading_tab_spinner_08.png"], nil];
	arUpdSpinner = [[NSMutableArray alloc ]initWithObjects:
					[UIImage imageNamed:@"updating_spinner_01.png"],
					[UIImage imageNamed:@"updating_spinner_02.png"],
					[UIImage imageNamed:@"updating_spinner_03.png"],
					[UIImage imageNamed:@"updating_spinner_04.png"],
					[UIImage imageNamed:@"updating_spinner_05.png"],
					[UIImage imageNamed:@"updating_spinner_06.png"],
					[UIImage imageNamed:@"updating_spinner_07.png"],
					[UIImage imageNamed:@"updating_spinner_08.png"], nil];

	return self;
}

+ (AppMobiViewController*)masterViewController
{
	return master;
}

- (NSString *)getTrackInfo
{
	return lastTrackInfo;
}

- (void)popWebView
{
	webView.hidden = YES;
}

- (void)pushWebView
{
	webView.hidden = NO;
}

- (void)popPlayerView
{
	if (!playerView.hidden) {
		playerView.hidden = YES;
		
		CATransition *animation = [CATransition animation];
		[animation setType:kCATransitionFade];	
		[[window layer] addAnimation:animation forKey:@"layerAnimation"];
		NSString *js = [NSString stringWithFormat:@"var e = document.createEvent('Events');e.initEvent('appMobi.player.hide',true,true);document.dispatchEvent(e);"];
		AMLog(@"%@",js);		
		[self performSelectorOnMainThread:@selector(internalInjectJS:) withObject:js waitUntilDone:NO];
	}
}

- (void)pushPlayerView
{
	[playerView performSelectorOnMainThread:@selector(resetView:) withObject:nil waitUntilDone:NO];
	[playerView performSelectorOnMainThread:@selector(repaint:) withObject:nil waitUntilDone:NO];
	
	playerView.hidden = NO;
	
	CATransition *animation = [CATransition animation];
	[animation setType:kCATransitionFade];
	[[window layer] addAnimation:animation forKey:@"layerAnimation"];

	NSString *js = [NSString stringWithFormat:@"var e = document.createEvent('Events');e.initEvent('appMobi.player.show',true,true);document.dispatchEvent(e);"];
	AMLog(@"%@",js);
	[self performSelectorOnMainThread:@selector(internalInjectJS:) withObject:js waitUntilDone:NO];
}

- (PlayingView *)getPlayerView
{
	return playerView;
}

- (AppMobiWebView *)getWebView
{
	return webView;
}

- (AppMobiWebView *)getPushView
{
	return pushView;
}

- (AppMobiWebView *)getActiveWebView
{
	if( appWebView != nil && appWebView.hidden == NO )
		return appWebView;

	return webView;
}

- (DirectCanvas *)getDirectCanvas
{
	return directCanvas;
}

- (void)resetDirectCanvas:(id)sender
{
    if(directCanvas != nil) {
        [directCanvas removeFromSuperview];
        [directCanvas release];
    }
	
	CGRect frame = [[UIScreen mainScreen] applicationFrame];
    BOOL ispt = (self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown || self.interfaceOrientation == UIInterfaceOrientationPortrait);
	if( ispt == NO )
	{
		frame = CGRectMake( 0, 0, frame.size.height, frame.size.width );
    }
    
    [DirectCanvas setLandscapeMode:!ispt];
	if( [[AppMobiDelegate sharedDelegate] isWebContainer] == YES )
	{
		directCanvas = [[DirectCanvas alloc] initWithView:appView andFrame:CGRectMake( 0, 20, frame.size.width, frame.size.height )];
	}
	else
	{
		directCanvas = [[DirectCanvas alloc] initWithView:self.view andFrame:CGRectMake( 0, 0, frame.size.width, frame.size.height )];
	}

	directCanvas.hidden = YES;
}

- (UIImage *)getRichSplash
{
	UIImage *richImage;
	NSString *file;
	NSString *path;
	
	BOOL port = (self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown || self.interfaceOrientation == UIInterfaceOrientationPortrait);
	BOOL ipad = [AppMobiDelegate isIPad];
	
	file = [NSString stringWithFormat:@"rich_splash%@_%@", (ipad?@"_ipad":@""), (port?@"port":@"ls")];
	path = [webView.config.appDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"_appMobi/%@.png", file]];
	
	if( NO == [[NSFileManager defaultManager] fileExistsAtPath:path] )
	{
		path = [[NSBundle mainBundle] pathForResource:file ofType:@"png"];	
	}
	
	richImage = [[UIImage alloc] initWithContentsOfFile:path];
	return richImage;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	/*
	 if autoRotate is true and rotateOrientation is set to portrait, rotate between portrait and portrait upside down
	 if autoRotate is true and rotateOrientation is set to landscape, rotate between landscape left and landscape right
	 if autoRotate is true and rotateOrientation is not set, rotate to any orientation
	 if autoRotate is false and rotateOrientation is set to portrait, rotate to portrait
	 if autoRotate is false and rotateOrientation is set to landscape, rotate to landscape left
	 if autoRotate is false and rotateOrientation is not set, do not rotate
	 */
	
	lastOrientation = interfaceOrientation;
	if( [AppMobiDelegate sharedDelegate].bStartup == YES )
	{
		NSString *initOrient = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"UIInterfaceOrientation"];
		if( initOrient != nil && [initOrient hasPrefix:@"UIInterfaceOrientationLandscape"] )
		{
			return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
					interfaceOrientation == UIInterfaceOrientationLandscapeRight);
		}
		else
		{
			return (interfaceOrientation == UIInterfaceOrientationPortrait ||
					interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
		}
	}
	
	if( [AppMobiDelegate sharedDelegate].isWebContainer == YES && bHomeShown == NO )
	{
		return YES;
	}
	
	if (autoRotate == YES) {
		if ([self.fixedOrientation isEqualToString:@"portrait"]) {
			return (interfaceOrientation == UIInterfaceOrientationPortrait ||
							interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
		} else if ([self.fixedOrientation isEqualToString:@"landscape"]) {
			return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
							interfaceOrientation == UIInterfaceOrientationLandscapeRight);
		} else {
			return YES;
		}
	} else {
		if ([self.fixedOrientation isEqualToString:@"portrait"]) {
			return (interfaceOrientation == UIInterfaceOrientationPortrait ||
					interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
		} else if ([self.fixedOrientation isEqualToString:@"landscape"]) {
			return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
					interfaceOrientation == UIInterfaceOrientationLandscapeRight);
		} else {
			return NO;
		}
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	if( playerView != nil ) [playerView setOrientation:0];

	double i = 0;
	
	switch (self.interfaceOrientation){
		case UIInterfaceOrientationPortrait:
			i = 0;
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			i = 180;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			i = 90;
			break;
		case UIInterfaceOrientationLandscapeRight:
			i = -90;
			break;
	}

	BOOL ipad = [AppMobiDelegate isIPad];
	BOOL ispt = (self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown || self.interfaceOrientation == UIInterfaceOrientationPortrait);
	if( remoteView.hidden == NO )
	{
		remoteClose.frame =  ( ispt ? rectRemoteClosePort : rectRemoteCloseLand );
	}
	if( richView.hidden == NO )
	{
		richClose.frame = ( ispt ? rectRichClosePort : rectRichCloseLand );
		richMessage.frame = ( ispt ? rectRichMessagePort : rectRichMessageLand );
		richSplash.frame = ( ispt ? rectRichSplashPort : rectRichSplashLand );
		richSpinner.frame = ( ispt ? rectRichSpinnerPort : rectRichSpinnerLand );
		richSplash.image = [self getRichSplash];
	}
	
	CGRect scrFrame = [[UIScreen mainScreen] bounds];
	CGRect webFrame = [[UIScreen mainScreen] applicationFrame];
	if( ispt == NO )
	{
		scrFrame = CGRectMake( 0, 0, scrFrame.size.height, scrFrame.size.width );
		webFrame = CGRectMake( 0, 0, webFrame.size.height, webFrame.size.width );
	}
	
	if( appView != nil )
	{
		directCanvas.frame = CGRectMake( 0, 20, webFrame.size.width, webFrame.size.height );
		appView.frame = CGRectMake( 0, 0, scrFrame.size.width, scrFrame.size.height );
		appWebView.frame = CGRectMake( 0, 20, webFrame.size.width, webFrame.size.height );
		appFooter.frame = CGRectMake( 0, 0, webFrame.size.width, 20 );
		
		appFooterBkg.frame = CGRectMake( 0, 0, webFrame.size.width, 20 );
		appUpdate.frame = CGRectMake(0, 0, 96, 20);
		appFavorite.frame = CGRectMake(webFrame.size.width/2-48, 0, 96, 20);
		appClose.frame = CGRectMake(webFrame.size.width-96, 0, 96, 20);
	}
	else
	{
		directCanvas.frame = CGRectMake( 0, 0, webFrame.size.width, webFrame.size.height );
	}
	
	if( [[AppMobiDelegate sharedDelegate] isWebContainer] == YES && bHomeShown == NO )
	{
		if( ipad == YES )
		{
			if( ispt == NO )
			{
				midWebBar.frame = CGRectMake( 0, 0, webFrame.size.width, webFrame.size.height );
			}
			else
			{
				midWebBar.frame = CGRectMake( 0, 48, webFrame.size.width, webFrame.size.height-48 );	
			}
		}
		else
		{
			if( ispt == NO )
			{
				midWebBar.frame = CGRectMake( 0, 0, webFrame.size.width, webFrame.size.height );
			}
			else
			{
				midWebBar.frame = CGRectMake( 0, 32, webFrame.size.width, webFrame.size.height-43-32 );	
			}
		}
		
		if( ispt == NO )
		{
			botTabBlk.hidden = YES;
			botTabBar.hidden = YES;
		}
		else
		{
			botTabBlk.hidden = !bTabShown;
			botTabBar.hidden = !bTabShown;	
		}

		webView.frame = CGRectMake( 0, 0, midWebBar.frame.size.width, midWebBar.frame.size.height );
	}
    
	[self internalInjectJS:[NSString stringWithFormat:@"AppMobi.device.setOrientation(%f);", i]];
}

- (void)placeManifestBlocker:(id)sender
{
    BOOL ispt = (self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown || self.interfaceOrientation == UIInterfaceOrientationPortrait);
	CGRect webFrame = [[UIScreen mainScreen] applicationFrame];
	if( ispt == NO )
	{
		webFrame = CGRectMake( 0, 0, webFrame.size.height, webFrame.size.width );
    }
    
    appUpdateMessage.frame = CGRectMake(0, 50, webFrame.size.width, 100);
    appUpdateSpinner.frame = CGRectMake((webFrame.size.width-86)/2, 156, 86, 84);
}

- (void)checkForWrongOrientation:(id)sender
{
	if( [fixedOrientation compare:@"any"] != NSOrderedSame )
	{
        NSLog(@"checkForWrongOrientation - %d", self.interfaceOrientation);
		BOOL landscape = ( self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
						   self.interfaceOrientation == UIInterfaceOrientationLandscapeRight );
		if( [fixedOrientation compare:@"landscape"] == NSOrderedSame && landscape != YES )
		{
			UIView *view = [[[[UIApplication sharedApplication] keyWindow] subviews] objectAtIndex:0];
			[view removeFromSuperview];
			[[[UIApplication sharedApplication] keyWindow] addSubview:view];
		}
		
		if( [fixedOrientation compare:@"portrait"] == NSOrderedSame && landscape != NO )
		{
			UIView *view = [[[[UIApplication sharedApplication] keyWindow] subviews] objectAtIndex:0];
			[view removeFromSuperview];
			[[[UIApplication sharedApplication] keyWindow] addSubview:view];
		}
	}
    
    if( appUpdateMessage.hidden == NO ) { [self placeManifestBlocker:nil]; }
}

- (void) setAutoRotate:(BOOL) shouldRotate {
    autoRotate = shouldRotate;
	[self checkForWrongOrientation:nil];
}

- (void) setRotateOrientation:(NSString*) orientation {
    self.fixedOrientation = orientation;
	[self checkForWrongOrientation:nil];
}

- (void) updateTrackInfo:(XMLTrack*) track
{
	if( track == nil || track.guidIndex == nil ) return;
	
	//if( lastTrackInfo != nil ) AMLog(@"updateTrackInfo ----- %@", lastTrackInfo);
	//AMLog(@"updateTrackInfo ----- %@", track.guidIndex);
	if( lastTrackGuid != nil && [lastTrackGuid compare:track.guidIndex] == NSOrderedSame )
	{
		return;
	}
	else
	{
		if( lastTrackInfo != nil ) [lastTrackInfo release];
		if( lastTrackGuid != nil ) [lastTrackGuid release];
		lastTrackGuid = [track.guidIndex copy];
	}	
	
	NSString *artist, *title, *album, *imageurl;
	artist = track.artist==nil?@"":track.artist;
	title = track.title==nil?@"":track.title;
	album = track.album==nil?@"":track.album;
	imageurl = track.imageurl==nil?@"":track.imageurl;

	lastTrackInfo = [[NSString stringWithFormat: 
					 @"AppMobi.playingtrack = {artist:\"%@\", title:\"%@\", album:\"%@\", imageurl:\"%@\"};var e = document.createEvent('Events');e.initEvent('appMobi.player.track.change',true,true);document.dispatchEvent(e);", 
					  artist, title, album, imageurl] retain];
	[self internalInjectJS:lastTrackInfo];
}

- (void) updateShoutcastInfo:(XMLTrack*) track
{
	NSString *artist, *title, *album, *imageurl;
	artist = track.artist==nil?@"":track.artist;
	title = track.title==nil?@"":track.title;
	album = track.album==nil?@"":track.album;
	imageurl = track.imageurl==nil?@"":track.imageurl;
	
	lastTrackInfo = [[NSString stringWithFormat: 
										@"AppMobi.playingtrack = {artist:\"%@\", title:\"%@\", album:\"%@\", imageurl:\"%@\"};var e = document.createEvent('Events');e.initEvent('appMobi.player.track.change',true,true);document.dispatchEvent(e);", 
										artist, title, album, imageurl] retain];
	[self internalInjectJS:lastTrackInfo];
}

- (void)hideCamera:(id)sender
{
	if( bAReality == NO ) return;
	bAReality = NO;

	CGRect rr = webView.frame;
	rr.origin.y += 20;
	rr.size.height -= 20;
	webView.frame = rr;
	
	[self dismissModalViewControllerAnimated:NO];
}

- (void)showCamera:(id)sender
{
	if( bAReality == YES ) return;
	bAReality = YES;
	
	CGRect rr = webView.frame;
	rr.origin.y -= 20;
	rr.size.height += 20;
	webView.frame = rr;
	
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = UIImagePickerControllerSourceTypeCamera;
	picker.showsCameraControls = NO;
	picker.navigationBarHidden = YES;
	picker.toolbarHidden = YES;
	picker.wantsFullScreenLayout = YES;
	picker.cameraViewTransform = CGAffineTransformScale(picker.cameraViewTransform, 1.0, 1.24824);
	picker.cameraOverlayView = self.view;
	
	[self presentModalViewController:picker animated:NO];
}

- (void)fireEvent:(NSString *)jsevent
{
	NSString *strEvent =  [NSString stringWithFormat:@"var ev = document.createEvent('Events');ev.initEvent('%@',true,true);document.dispatchEvent(ev);", jsevent];
	[self internalInjectJS:strEvent];
}

- (void)internalInjectJS:(NSString *)js
{
	if( richView != nil && richView.hidden == NO )
		[richView stringByEvaluatingJavaScriptFromString:js];
	if( remoteView != nil && remoteView.hidden == NO )
		[remoteView stringByEvaluatingJavaScriptFromString:js];
	if( appWebView != nil && appWebView.hidden == NO )
		[appWebView stringByEvaluatingJavaScriptFromString:js];
	[webView stringByEvaluatingJavaScriptFromString:js];
}

- (void)redirect:(NSString *)url
{
	AMLog(@"%@", url);
	[webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
	topUrlField.text = url;
}

- (void)dealloc
{
    if(directCanvas != nil) {
        [directCanvas release];
    }
	[fixedOrientation release];
	[lastTrackInfo release];
	[playerView release];
	[window release];
	[super dealloc];
}

- (void)updateFavorite:(id)sender
{
	[botFav setImage:[UIImage imageNamed:@"button_favorites.png"] forState:UIControlStateNormal];
	NSString *currentUrl = webView.request.URL.description;
	for( int i = 0; i < [arAllBookmarks count]; i++ )
	{
		Bookmark *bookmark = (Bookmark *) [arAllBookmarks objectAtIndex:i];
		if( [bookmark.url compare:currentUrl] == NSOrderedSame )
		{
			[botFav setImage:[UIImage imageNamed:@"button_favorites_on.png"] forState:UIControlStateNormal];
		}
	}
}

- (void)hideSettings:(id)sender
{
	if( bSetShown == YES )
	{
		bSetShown = NO;
		settingsView.hidden = YES;
		settingsHeader.hidden = YES;
		[botSettings setImage:[UIImage imageNamed:setOffImage] forState:UIControlStateNormal];
		if( bHomeShown == YES ) [botHome setImage:[UIImage imageNamed:mobiusOnImage] forState:UIControlStateNormal];
	}
}

- (void)hideTabs:(id)sender
{	
	if( bTabShown == YES )
	{
		botSettings.hidden = ( pushCount == 0 );
		[self updateButtons:nil];
		botTabBlk.hidden = YES;
		bTabShown = NO;
		[botTab setImage:[UIImage imageNamed:tabOffImage] forState:UIControlStateNormal];
		if( bHomeShown == YES ) [botHome setImage:[UIImage imageNamed:mobiusOnImage] forState:UIControlStateNormal];
		
		[self.view.layer removeAllAnimations];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationsEnabled:YES];
		[UIView setAnimationDuration:0.4];
		[UIView setAnimationDelegate:self];
		if( [AppMobiDelegate isIPad] == YES ) botTabBar.frame = CGRectMake( 0, 48, midWebBar.frame.size.width, 0 );
		else botTabBar.frame = CGRectMake( 0, midWebBar.frame.size.height+32, midWebBar.frame.size.width, 0 );
		[UIView commitAnimations];
	}
}

- (void)updateButtons:(id)sender
{
	BOOL bck = [webView canGoBack] && midWebBar.hidden == NO;
	botBack.enabled = bck;
	BOOL fwd = [webView canGoForward] && midWebBar.hidden == NO;
	botFwd.enabled = fwd;
	BOOL ref = webView.isLoading == NO  && midWebBar.hidden == NO;
	botReload.enabled = ref || bHomeShown == YES;	
}

- (void)saveAllBookmarks:(id)sender
{
	NSString *bmarksfile = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:@"bookmarks.dat"];
	[NSKeyedArchiver archiveRootObject:arAllBookmarks toFile:bmarksfile];
}

- (void)showDeletes:(id)sender
{
	for( int i = 0; i < bookmarkMax; i++ )
	{
		UIButton *del = [homeDels objectAtIndex:i];
		
		int index = startIndex + i;
		if( index < [arActiveBookmarks count] )
		{
			Bookmark *bookmark = (Bookmark *) [arActiveBookmarks objectAtIndex:index];
			if( ( bookmark.isUserFav == YES || bookmark.isInstalled == YES ) && bookmark.isFeatured == NO )
			{
				del.hidden = NO;
			}
		}
	}
}

- (void)hideDeletes:(id)sender
{
	for( int i = 0; i < bookmarkMax; i++ )
	{
		UIButton *del = [homeDels objectAtIndex:i];
		
		int index = startIndex + i;
		if( index < [arActiveBookmarks count] )
		{
			del.hidden = YES;
		}
	}
}

- (void)endLabelEdit:(id)sender
{
	int row = (labelBeingEdited.tag-995544) / 3;
	if( row > 0 && [AppMobiDelegate isIPad] == NO )
	{
		CGRect homeFrame = homeView.frame;
		[self.view.layer removeAllAnimations];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationsEnabled:YES];
		[UIView setAnimationDuration:0.3];
		[UIView setAnimationDelegate:self];
		homeView.frame = CGRectMake( 0, 0, homeFrame.size.width, homeFrame.size.height );
		[UIView commitAnimations];
	}
	if( row > 2 && [AppMobiDelegate isIPad] == YES )
	{
		CGRect homeFrame = homeView.frame;
		[self.view.layer removeAllAnimations];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationsEnabled:YES];
		[UIView setAnimationDuration:0.3];
		[UIView setAnimationDelegate:self];
		homeView.frame = CGRectMake( 0, 0, homeFrame.size.width, homeFrame.size.height );
		[UIView commitAnimations];
	}
	
	//update and save the fave
	int index = startIndex + labelBeingEdited.tag-995544;
	Bookmark* fave = [arActiveBookmarks objectAtIndex:index];
	fave.name = textBeingEdited.text;
	[self saveAllBookmarks:nil];
	
	//update the label and remove the textfield
	labelBeingEdited.text = textBeingEdited.text;
	[textBeingEdited resignFirstResponder];
	//textBeingEdited.rightView = nil;
	[textBeingEdited removeFromSuperview];
	textBeingEdited = nil;
	
	//show the label
	labelBeingEdited.hidden = NO;
	labelBeingEdited = nil;
}

- (void)startLabelEdit:(UIGestureRecognizer *)sender
{
	if(textBeingEdited!=nil) return;
	
	UILabel* label = (UILabel*)sender.view;
	
	int index = startIndex + label.tag-995544;
	Bookmark* fave = [arActiveBookmarks objectAtIndex:index];
	if( fave.isUserFav != YES ) return;
	
	[self hideDeletes:nil];
	label.hidden = YES;

	//add an editable text view in it's place with a close button
	UITextField* text = [[UITextField alloc] initWithFrame:label.frame];
	text.text = label.text;
	text.userInteractionEnabled = YES;
	text.textColor = [UIColor blackColor];
	text.backgroundColor = [UIColor whiteColor];
	text.returnKeyType = UIReturnKeyDone;
	text.font = [UIFont boldSystemFontOfSize:12.0];
	text.textAlignment = UITextAlignmentCenter;
	text.delegate = self;
	labelBeingEdited = label;
	textBeingEdited = text;
	[label.superview addSubview:text];
	[text becomeFirstResponder];
	
	int row = (labelBeingEdited.tag-995544) / bookmarkCols;
	if( row > 0 && [AppMobiDelegate isIPad] == NO )
	{
		CGRect homeFrame = homeView.frame;
		[self.view.layer removeAllAnimations];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationsEnabled:YES];
		[UIView setAnimationDuration:0.3];
		[UIView setAnimationDelegate:self];
		homeView.frame = CGRectMake( 0, 0 - (row * 123), homeFrame.size.width, homeFrame.size.height );
		[UIView commitAnimations];
	}
	if( row > 2 && [AppMobiDelegate isIPad] == YES )
	{
		CGRect homeFrame = homeView.frame;
		[self.view.layer removeAllAnimations];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationsEnabled:YES];
		[UIView setAnimationDuration:0.3];
		[UIView setAnimationDelegate:self];
		homeView.frame = CGRectMake( 0, 0 - ((row-2) * 123), homeFrame.size.width, homeFrame.size.height );
		[UIView commitAnimations];
	}
}

- (void)startBookmarkDelete:(UIGestureRecognizer *)sender
{
	homeStartView = nil;
	
	[self performSelectorOnMainThread:@selector(showDeletes:) withObject:nil waitUntilDone:NO];
	[NSTimer scheduledTimerWithTimeInterval:14.0 target:self selector:@selector(hideDeletes:) userInfo:nil repeats:NO];
}

- (void)makeBookmarks:(id)sender
{
	BOOL ipad = [AppMobiDelegate isIPad];
	int xspacer = ipad?(104+70):(104);
	int yspacer = ipad?(123+55):(123);
	int xoffset = ipad?(71):(4);
	int yoffset = ipad?(105):(35);
	for( int i = 0; i < bookmarkMax; i++)
	{
		int row = i / bookmarkCols;
		int col = i % bookmarkCols;
	
		UIImageView *fav = [[UIImageView alloc] initWithImage:nil];
		fav.frame = CGRectMake(xoffset+col*xspacer, yoffset+row*yspacer, 104, 104);
		fav.hidden = YES;
		fav.tag = 998877 + i;
		fav.userInteractionEnabled = YES;
		UILongPressGestureRecognizer *deleteGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(startBookmarkDelete:)];
		if( [deleteGesture respondsToSelector:@selector(minimumPressDuration)] == YES )
		{
			deleteGesture.minimumPressDuration = 1.0;
			[fav addGestureRecognizer:deleteGesture];
		}
		[deleteGesture release];
		[homePics addObject:fav];
		[homeView addSubview:fav];

		UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(xoffset+col*xspacer, 107+yoffset+row*yspacer, 104, 16)];
		name.text = @"";
		name.tag = 995544 + i;
		name.textColor = [UIColor whiteColor];
		name.backgroundColor = [UIColor clearColor];
		name.font = [UIFont boldSystemFontOfSize:12.0];
		name.hidden = YES;
		name.textAlignment = UITextAlignmentCenter;
		name.userInteractionEnabled = YES;
		UILongPressGestureRecognizer *editGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(startLabelEdit:)];
		if( [editGesture respondsToSelector:@selector(minimumPressDuration)] == YES )
		{
			editGesture.minimumPressDuration = 1.0;
			[name addGestureRecognizer:editGesture];
		}
		[editGesture release];
		[homeNames addObject:name];
		[homeView addSubview:name];

		UIButton *bubble = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		bubble.frame = CGRectMake(74+xoffset+col*xspacer, -7+yoffset+row*yspacer, 32, 36);
		[bubble setTitle:@"13" forState:UIControlStateNormal];
		[bubble addTarget:self action:@selector(onPushMessages:) forControlEvents:UIControlEventTouchUpInside];
		[bubble setBackgroundImage:[UIImage imageNamed:@"thumb_message_overlay.png"] forState:UIControlStateNormal];
		[bubble setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
		bubble.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
		bubble.hidden = YES;
		bubble.tag = 993366 + i;
		[homeBubbles addObject:bubble];
		[homeView addSubview:bubble];
		
		UIButton *delete = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		delete.frame = CGRectMake(xoffset+col*xspacer, yoffset+row*yspacer, 34, 34);
		[delete setTitle:@"" forState:UIControlStateNormal];
		[delete addTarget:self action:@selector(canDeleteApp:) forControlEvents:UIControlEventTouchUpInside];
		[delete setImage:[UIImage imageNamed:@"delete_favorite.png"] forState:UIControlStateNormal];
		delete.hidden = YES;
		delete.tag = 998855 + i;
		[homeDels addObject:delete];
		[homeView addSubview:delete];
	}
    
    appInstall = [[UIProgressView alloc] initWithFrame:CGRectMake(xoffset, 107+yoffset, 104, 16)];
    appInstall.progressViewStyle = UIProgressViewStyleDefault;
    appInstall.progress = 0.0;
    appInstall.hidden = YES;
    [homeView addSubview:appInstall];
}

- (void)makeSettings:(id)sender
{
	CGRect wframe = [[UIScreen mainScreen] applicationFrame];
	BOOL ipad = [AppMobiDelegate isIPad];
	int count = 0;
	int setmax = ipad?(20):(9);
	int scrmax = ipad?(910):(367);
	for( int i = 0; i < [arAllBookmarks count]; i++ )
	{
		Bookmark *bookmark = [arAllBookmarks objectAtIndex:i];		
		if( bookmark.isInstalled == YES )
		{
			if( count >= [settingsNames count] )
			{
				UIImageView *bkg = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"push_stretcher.png"] stretchableImageWithLeftCapWidth:0.0 topCapHeight:0.0]];
				bkg.frame = CGRectMake(0,0+count*40,wframe.size.width,40);
				[settingsScrollView addSubview:bkg];
				[settingsBkgs addObject:bkg];
				
				UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(5,6+count*40,wframe.size.width-105,30)];
				label.text = bookmark.name;
				label.textColor = [UIColor whiteColor];
				label.backgroundColor = [UIColor clearColor];
				label.font = [UIFont boldSystemFontOfSize:16.0];
				[settingsScrollView addSubview:label];
				[settingsNames addObject:label];
				
				UISwitch *swtch = [[UISwitch alloc] initWithFrame:CGRectMake(wframe.size.width-100,6+count*40,90,30)];
				[swtch addTarget:self action:@selector(onPushSwitch:) forControlEvents:UIControlEventValueChanged];
				swtch.backgroundColor = [UIColor clearColor];
				swtch.tag = i;
				[settingsScrollView addSubview:swtch];
				[settingsSwitches addObject:swtch];
				swtch.on = (bookmark.hasPushOn == YES);
			}
			else
			{
				UIImageView *bkg = [settingsBkgs objectAtIndex:count];
				bkg.hidden = NO;
				
				UILabel *label = [settingsNames objectAtIndex:count];
				label.text = bookmark.appconfig.appName;
				label.hidden = NO;
				
				UISwitch *swtch = [settingsSwitches objectAtIndex:count];
				swtch.on = (bookmark.hasPushOn == YES);
				swtch.hidden = NO;
			}

			count++;
		}
	}
	
	for( int i = count; i < [settingsNames count]; i++ )
	{
		UILabel *label = [settingsNames objectAtIndex:count];
		label.hidden = YES;
		
		UISwitch *swtch = [settingsSwitches objectAtIndex:count];
		swtch.hidden = YES;
	}
	
	CGSize content = CGSizeMake(settingsScrollView.frame.size.width, scrmax);
	if( count > setmax ) content = CGSizeMake(settingsScrollView.frame.size.width, 40 * count);
	settingsScrollView.contentSize = content;
}

- (void)makeApp:(id)sender
{
	CGRect wframe = [[UIScreen mainScreen] applicationFrame];
	
	appWebView = [[AppMobiWebView alloc] initWithFrame:CGRectMake( 0, 20, wframe.size.width, wframe.size.height )];
	appWebView.backgroundColor = [UIColor clearColor];
	appWebView.opaque = NO;
	appWebView.scalesPageToFit = YES;
	[appView addSubview:appWebView];
	
	appFooter = [[UIView alloc] initWithFrame:CGRectMake( 0, 0, wframe.size.width, 20 )];
	appFooter.backgroundColor = [UIColor whiteColor];
	[appView addSubview:appFooter];
	
	appFooterBkg = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"app_nav_bar-stretcher.png"] stretchableImageWithLeftCapWidth:0 topCapHeight:0]];
	appFooterBkg.frame = CGRectMake( 0, 0, wframe.size.width, 20 );
	[appFooter addSubview:appFooterBkg];
	
	appUpdate = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	appUpdate.frame = CGRectMake(0, 0, 96, 20);
	[appUpdate setTitle:@"" forState:UIControlStateNormal];
	[appUpdate addTarget:self action:@selector(onUpdateApp:) forControlEvents:UIControlEventTouchUpInside];
	[appUpdate setImage:[UIImage imageNamed:@"appnav_update.png"] forState:UIControlStateNormal];
	appUpdate.enabled = NO;
	[appFooter addSubview:appUpdate];
	
	appFavorite = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	appFavorite.frame = CGRectMake(wframe.size.width/2-48, 0, 96, 20);
	[appFavorite setTitle:@"" forState:UIControlStateNormal];
	[appFavorite addTarget:self action:@selector(onFavoriteApp:) forControlEvents:UIControlEventTouchUpInside];
	[appFavorite setImage:[UIImage imageNamed:@"appnav_add_home.png"] forState:UIControlStateNormal];
	[appFooter addSubview:appFavorite];
	
	appClose = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	appClose.frame = CGRectMake(wframe.size.width-96, 0, 96, 20);
	[appClose setTitle:@"" forState:UIControlStateNormal];
	[appClose addTarget:self action:@selector(onCloseApp:) forControlEvents:UIControlEventTouchUpInside];
	[appClose setImage:[UIImage imageNamed:@"appnav_close.png"] forState:UIControlStateNormal];
	[appFooter addSubview:appClose];
}

- (void)makeTabs:(id)sender
{
	BOOL ipad = [AppMobiDelegate isIPad];
	botTabSel = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"curr_tab_frame.gif"]];
	botTabSel.frame = CGRectMake(6, 3, 76, 76);
	botTabSel.hidden = YES;
	[botTabBar addSubview:botTabSel];
	
	botTabWin = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tab_dots_frame.png"]];
	botTabWin.frame = CGRectMake(128, 80, 64, 14);
	if( ipad == YES ) botTabWin.frame = CGRectMake(327, 80, 113, 14);
	if( ipad == YES ) botTabWin.image = [UIImage imageNamed:@"tab_dots_frame-7.png"];
	botTabWin.hidden = YES;
	[botTabBar addSubview:botTabWin];

	int xspacer = ipad?(107):(80);
	int xoffset = ipad?(26):(4);
	for( int i = 0; i < tabMax; i++)
	{
		UIImageView *tab = [[UIImageView alloc] initWithImage:nil];
		tab.frame = CGRectMake(xoffset+i*xspacer, 5, 72, 72);
		tab.hidden = YES;
		tab.tag = 997766 + i;
		[tabPics addObject:tab];
		[botTabBar addSubview:tab];
		
		UIButton *del = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		del.frame = CGRectMake(48+xoffset+i*xspacer, 5, 24, 30);
		[del setTitle:@"" forState:UIControlStateNormal];
		[del addTarget:self action:@selector(onDelTab:) forControlEvents:UIControlEventTouchUpInside];
		[del setImage:[UIImage imageNamed:@"delete_tab.png"] forState:UIControlStateNormal];
		del.hidden = YES;
		del.tag = 997755 + i;
		[tabDels addObject:del];
		[botTabBar addSubview:del];
	}
}

- (void)addNewEmptyTab:(id)sender
{
	CGRect wframe = CGRectMake( -1 * midWebBar.frame.size.width, 0, midWebBar.frame.size.width, midWebBar.frame.size.height );
	AppMobiWebView *tab = [[AppMobiWebView alloc] initWithFrame:wframe];
	tab.backgroundColor = [UIColor whiteColor];
	tab.opaque = NO;
	tab.scalesPageToFit = YES;
	tab.tag = -1;
	tab.config = [AppMobiDelegate sharedDelegate]._config;

	[arTabs addObject:tab];
	[midWebBar addSubview:tab];
}

- (void)loadView
{
	AppMobiDelegate *delegate = [AppMobiDelegate sharedDelegate];
	CGRect scrFrame = [[UIScreen mainScreen] bounds];
	CGRect webFrame = [[UIScreen mainScreen] applicationFrame];

	UIView *contentView = [[UIView alloc] initWithFrame:webFrame];
	contentView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	self.view = contentView;
	self.view.backgroundColor = [UIColor clearColor];
	
	BOOL ipad = [AppMobiDelegate isIPad];
	bookmarkMax = (ipad?20.0:9.0);
	bookmarkRows = (ipad?5:3);
	bookmarkCols = (ipad?4:3);
	tabMax = (ipad?7.0:4.0);
	
	if( [delegate isWebContainer] == YES )
	{
		homeView = [[UIView alloc] initWithFrame:CGRectMake( 0, 0, webFrame.size.width, webFrame.size.height )];
		if( ipad == YES ) homeView.frame = CGRectMake( 0, 0, webFrame.size.width, webFrame.size.height );
        homeView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
		homeView.backgroundColor = [UIColor colorWithRed:0.333f green:0.333f blue:0.333f alpha:1.0f];
		[contentView addSubview:homeView];
		
		homeBkgBar = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"base_bg.jpg"]];
		if( ipad == YES ) homeBkgBar.image = [UIImage imageNamed:@"base_bg_ipad.jpg"];
		homeBkgBar.frame = CGRectMake(0, 0, webFrame.size.width, webFrame.size.height);
		[homeView addSubview:homeBkgBar];

		[self makeBookmarks:nil];
		
		homePages = [[UIPageControl alloc] initWithFrame:CGRectMake(0, 406, webFrame.size.width, 10)];
		if( ipad == YES ) homePages.frame = CGRectMake(0, 984, webFrame.size.width, 10);
		homePages.userInteractionEnabled = NO;
		homePages.backgroundColor = [UIColor clearColor];
		homePages.numberOfPages = 1;
		homePages.currentPage = 0;
		homePages.hidesForSinglePage = NO;
		[homePages addTarget:self action:@selector(onPage:) forControlEvents:UIControlEventValueChanged];
		[homeView addSubview:homePages];
		
		topUrlField = [[UITextField alloc] initWithFrame:CGRectMake(39, 5, 243, 21)];
		if( ipad == YES ) topUrlField.frame = CGRectMake(41, 14, 413, 21);
		topUrlField.textColor = [UIColor whiteColor];
		topUrlField.backgroundColor = [UIColor clearColor];
		topUrlField.font = [UIFont systemFontOfSize:16.0];
		topUrlField.placeholder = @"";
		topUrlField.text = @"http://";
		topUrlField.keyboardType = UIKeyboardTypeDefault;
		topUrlField.returnKeyType = UIReturnKeyDone;
		topUrlField.clearButtonMode = UITextFieldViewModeWhileEditing;
		topUrlField.delegate = self;
		[homeView addSubview:topUrlField];
		
		topSearchField = [[UITextField alloc] initWithFrame:CGRectMake(281, 5, 1, 21)];
		if( ipad == YES ) topSearchField.frame = CGRectMake(453, 14, 1, 21);
		topSearchField.textColor = [UIColor blackColor];
		topSearchField.font = [UIFont systemFontOfSize:16.0];
		topSearchField.placeholder = @"";
		topSearchField.text = @"";
		topSearchField.backgroundColor = [UIColor whiteColor];
		topSearchField.keyboardType = UIKeyboardTypeDefault;
		topSearchField.returnKeyType = UIReturnKeyDone;
		topSearchField.clearButtonMode = UITextFieldViewModeWhileEditing;
		topSearchField.hidden = YES;
		topSearchField.delegate = self;
		[homeView addSubview:topSearchField];
		
		topUrlBkg = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"field_border_search.png"]];
		topUrlBkg.frame = CGRectMake(0, 0, 320, 32);
		if( ipad == YES ) topUrlBkg.frame = CGRectMake(0, 0, 508, 48);
		if( ipad == YES ) topUrlBkg.image = [UIImage imageNamed:@"field_border_search-ipad.png"];
		[homeView addSubview:topUrlBkg];		
		
		topOpenSearch = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		topOpenSearch.frame = CGRectMake(285, 0, 30, 32);
		if( ipad == YES ) topOpenSearch.frame = CGRectMake(458, 9, 30, 32);
		[topOpenSearch setTitle:@"" forState:UIControlStateNormal];
		[topOpenSearch addTarget:self action:@selector(onOpenSearch:) forControlEvents:UIControlEventTouchUpInside];
		[topOpenSearch setImage:[UIImage imageNamed:@"button_search.png"] forState:UIControlStateNormal];
		[homeView addSubview:topOpenSearch];
		
		botFav = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		botFav.frame = CGRectMake(5, 0, 30, 32);
		if( ipad == YES ) botFav.frame = CGRectMake(9, 9, 30, 32);
		[botFav setTitle:@"" forState:UIControlStateNormal];
		[botFav addTarget:self action:@selector(onAddFavorite:) forControlEvents:UIControlEventTouchUpInside];
		[botFav setImage:[UIImage imageNamed:@"button_favorites.png"] forState:UIControlStateNormal];
		[homeView addSubview:botFav];
		
		botSpeak = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		botSpeak.frame = CGRectMake(5, 0, 30, 32);
		if( ipad == YES ) botSpeak.frame = CGRectMake(9, 9, 30, 32);
		[botSpeak setTitle:@"" forState:UIControlStateNormal];
		[botSpeak addTarget:self action:@selector(onSpeech:) forControlEvents:UIControlEventTouchUpInside];
		[botSpeak setImage:[UIImage imageNamed:@"button_speak.png"] forState:UIControlStateNormal];
		botSpeak.hidden = YES;
		[homeView addSubview:botSpeak];
		
		botWebBar = [[UIView alloc] init];
		botWebBar.frame = CGRectMake( 0, webFrame.size.height-43, webFrame.size.width, 43 );
		botWebBar.backgroundColor = [UIColor blackColor];
		if( ipad == YES ) botWebBar.frame = CGRectMake( 508, 0, 260, 48 );
		if( ipad == YES ) botWebBar.backgroundColor = [UIColor clearColor];
		[homeView addSubview:botWebBar];
		if( ipad == YES ) { [botWebBar removeFromSuperview]; [homeView addSubview:botWebBar]; }
		
		botAppView = [[UIView alloc] initWithFrame:CGRectMake( 0, 0, webFrame.size.width, 43 )];
		if( ipad == YES ) botAppView.frame = CGRectMake( 0, 0, 260, 48 );
		[botWebBar addSubview:botAppView];
		
		botWebView = [[UIView alloc] initWithFrame:CGRectMake( 0, 0, webFrame.size.width, 43 )];
		if( ipad == YES ) botWebView.frame = CGRectMake( 0, 0, 260, 48 );
		botWebView.hidden = YES;
		[botWebBar addSubview:botWebView];
		
		botHome = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		botHome.frame = CGRectMake(9, 0, 54, 43);
		if( ipad == YES ) botHome.frame = CGRectMake(208, 0, 52, 48);
		[botHome setTitle:@"" forState:UIControlStateNormal];
		[botHome addTarget:self action:@selector(onHome:) forControlEvents:UIControlEventTouchUpInside];
		[botHome setImage:[UIImage imageNamed:mobiusOnImage] forState:UIControlStateNormal];
		[botWebBar addSubview:botHome];
		
		botTab = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		botTab.frame = CGRectMake(72, 0, 53, 43);
		if( ipad == YES ) botTab.frame = CGRectMake(156, 0, 52, 48);
		[botTab setTitle:@"" forState:UIControlStateNormal];
		[botTab addTarget:self action:@selector(onTabs:) forControlEvents:UIControlEventTouchUpInside];
		[botTab setImage:[UIImage imageNamed:tabOffImage] forState:UIControlStateNormal];
		[botWebBar addSubview:botTab];
		
		botGallery = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		botGallery.frame = CGRectMake(134, 0, 53, 43);
		if( ipad == YES ) botGallery.frame = CGRectMake(52, 0, 52, 48);
		[botGallery setTitle:@"" forState:UIControlStateNormal];
		[botGallery addTarget:self action:@selector(onGallery:) forControlEvents:UIControlEventTouchUpInside];
		[botGallery setImage:[UIImage imageNamed:@"tab_gallery.png"] forState:UIControlStateNormal];
		if( ipad == YES ) [botGallery setImage:[UIImage imageNamed:@"ipad_icon_gallery.png"] forState:UIControlStateNormal];
		[botAppView addSubview:botGallery];
		
		botBack = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		botBack.frame = CGRectMake(134, 0, 53, 43);
		if( ipad == YES ) botBack.frame = CGRectMake(0, 0, 52, 48);
		[botBack setTitle:@"" forState:UIControlStateNormal];
		[botBack addTarget:self action:@selector(onBack:) forControlEvents:UIControlEventTouchUpInside];
		[botBack setImage:[UIImage imageNamed:@"button_back.png"] forState:UIControlStateNormal];
		if( ipad == YES ) [botBack setImage:[UIImage imageNamed:@"ipad_icon_back.png"] forState:UIControlStateNormal];
		botBack.enabled = NO;
		[botWebView addSubview:botBack];
		
		botReload = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		botReload.frame = CGRectMake(196, 0, 53, 43);
		if( ipad == YES ) botReload.frame = CGRectMake(52, 0, 52, 48);
		[botReload setTitle:@"" forState:UIControlStateNormal];
		[botReload addTarget:self action:@selector(onRefresh:) forControlEvents:UIControlEventTouchUpInside];
		[botReload setImage:[UIImage imageNamed:@"button_refresh.png"] forState:UIControlStateNormal];
		if( ipad == YES ) [botReload setImage:[UIImage imageNamed:@"ipad_icon_refresh.png"] forState:UIControlStateNormal];
		botReload.hidden = YES;
		[botWebView addSubview:botReload];
		
		botPay = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		botPay.frame = CGRectMake(196, 0, 53, 43);
		if( ipad == YES ) botPay.frame = CGRectMake(104, 0, 52, 48);
		[botPay setTitle:@"" forState:UIControlStateNormal];
		[botPay addTarget:self action:@selector(on1Touch:) forControlEvents:UIControlEventTouchUpInside];
		[botPay setImage:[UIImage imageNamed:@"tab_1touch.png"] forState:UIControlStateNormal];
		if( ipad == YES ) [botPay setImage:[UIImage imageNamed:@"ipad_icon_1touch.png"] forState:UIControlStateNormal];
		[botAppView addSubview:botPay];
		
		botCancel = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		botCancel.frame = CGRectMake(196, 0, 53, 43);
		if( ipad == YES ) botCancel.frame = CGRectMake(52, 0, 52, 48);
		[botCancel setTitle:@"" forState:UIControlStateNormal];
		[botCancel addTarget:self action:@selector(onCancel:) forControlEvents:UIControlEventTouchUpInside];
		[botCancel setImage:[UIImage imageNamed:@"button_stop.png"] forState:UIControlStateNormal];
		if( ipad == YES ) [botCancel setImage:[UIImage imageNamed:@"ipad_icon_stop.png"] forState:UIControlStateNormal];
		botCancel.hidden = YES;
		[botWebView addSubview:botCancel];
		
		botSettings = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		botSettings.frame = CGRectMake(258, 0, 53, 43);
		if( ipad == YES ) botSettings.frame = CGRectMake(0, 0, 52, 48);
		[botSettings setTitle:@"" forState:UIControlStateNormal];
		[botSettings addTarget:self action:@selector(onSettings:) forControlEvents:UIControlEventTouchUpInside];
		[botSettings setImage:[UIImage imageNamed:setOffImage] forState:UIControlStateNormal];
		botSettings.hidden = YES;
		[botAppView addSubview:botSettings];
		
		botFwd = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		botFwd.frame = CGRectMake(258, 0, 53, 43);
		if( ipad == YES ) botFwd.frame = CGRectMake(104, 0, 52, 48);
		[botFwd setTitle:@"" forState:UIControlStateNormal];
		[botFwd addTarget:self action:@selector(onForward:) forControlEvents:UIControlEventTouchUpInside];
		[botFwd setImage:[UIImage imageNamed:@"button_forward.png"] forState:UIControlStateNormal];
		if( ipad == YES ) [botFwd setImage:[UIImage imageNamed:@"ipad_icon_forward.png"] forState:UIControlStateNormal];
		botFwd.enabled = NO;
		[botWebView addSubview:botFwd];
	
		CGRect wframe = CGRectMake( 0, 32, webFrame.size.width, webFrame.size.height-43-32 );
		if( ipad == YES ) wframe = CGRectMake( 0, 48, webFrame.size.width, webFrame.size.height-48 );
		midWebBar = [[UIView alloc] initWithFrame:wframe];
		midWebBar.backgroundColor = [UIColor clearColor];
		midWebBar.hidden = YES;
		[homeView addSubview:midWebBar];
		
		wframe = CGRectMake( -1 * midWebBar.frame.size.width, 0, midWebBar.frame.size.width, midWebBar.frame.size.height );
		webView = [[AppMobiWebView alloc] initWithFrame:wframe];
		webView.backgroundColor = [UIColor whiteColor];
		webView.opaque = NO;
		webView.scalesPageToFit = YES;
		webView.tag = -1;
		[midWebBar addSubview:webView];
		[arTabs addObject:webView];
	}
	else
	{
		webView = [[AppMobiWebView alloc] initWithFrame:CGRectMake( 0, 0, webFrame.size.width, webFrame.size.height )];
		webView.backgroundColor = [UIColor clearColor];
		webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		webView.opaque = NO;
		webView.scalesPageToFit = YES;
		[self.view addSubview:webView];

		if(webViewRequest!=nil) [webView loadRequest:webViewRequest];
	}

	if( [delegate isWebContainer] == YES )
	{
		midWebSpinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake((webFrame.size.width-60)/2, 100, 60, 60)];
		midWebSpinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
		midWebSpinner.hidden = YES;
		[contentView addSubview:midWebSpinner];
		
		botTabBlk = [[UIImageView alloc] initWithFrame:CGRectMake( 0, 0, webFrame.size.width, webFrame.size.height-43 )];
		if( ipad == YES ) botTabBlk.frame = CGRectMake( 0, 48, webFrame.size.width, webFrame.size.height-48 );
		botTabBlk.hidden = YES;
		botTabBlk.backgroundColor = [UIColor blackColor];
		botTabBlk.alpha = 0.66;
		[homeView addSubview:botTabBlk];
		
		botTabBar = [[UIView alloc] initWithFrame:CGRectMake( 0, webFrame.size.height-43, webFrame.size.width, 0 )];
		if( ipad == YES ) botTabBar.frame = CGRectMake( 0, 48, webFrame.size.width, 0 );
		botTabBar.clipsToBounds = YES;
		[homeView addSubview:botTabBar];
		
		botTabBkg = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"tabs_bg.jpg"]]; 
		if( ipad == YES ) botTabBkg.image = [[UIImage imageNamed:@"tabs_bg_stretcher.jpg"] stretchableImageWithLeftCapWidth:0.0 topCapHeight:0.0];
		botTabBkg.frame = CGRectMake( 0, 0, webFrame.size.width, 96 );
		[botTabBar addSubview:botTabBkg];
		
		tabPages = [[UIPageControl alloc] initWithFrame:CGRectMake(0, 82, webFrame.size.width, 10)];
		tabPages.userInteractionEnabled = NO;
		tabPages.backgroundColor = [UIColor clearColor];
		tabPages.numberOfPages = 0;
		tabPages.currentPage = 0;
		tabPages.hidesForSinglePage = NO;
		[tabPages addTarget:self action:@selector(onPage:) forControlEvents:UIControlEventValueChanged];
		[botTabBar addSubview:tabPages];
		
		[self makeTabs:nil];
		
		settingsView = [[UIView alloc] initWithFrame:CGRectMake( 0, 0, webFrame.size.width, webFrame.size.height-43 )];
		if( ipad == YES ) settingsView.frame = CGRectMake( 0, 48, webFrame.size.width, webFrame.size.height-48 );
		settingsView.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
		settingsView.hidden = YES;
		[contentView addSubview:settingsView];
		
		settingsHeader = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"push_settings-mast.png"]]; 
		settingsHeader.frame = CGRectMake( 0, 0, webFrame.size.width, 50 );
		settingsHeader.hidden = YES;
		if( ipad == YES ) settingsHeader.frame = CGRectMake( 0, 0, 508, 48 );
		if( ipad == YES ) settingsHeader.image = [UIImage imageNamed:@"push_settings-mast-ipad.png"];
		[settingsView addSubview:settingsHeader];
		if( ipad == YES ) { [settingsHeader removeFromSuperview]; [contentView addSubview:settingsHeader]; }
		
		settingsScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0,50,webFrame.size.width,webFrame.size.height-43-50)];
		if( ipad == YES ) settingsScrollView.frame = CGRectMake(0,0,webFrame.size.width,webFrame.size.height-48);
		[settingsScrollView setBackgroundColor:[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0]];
		[settingsScrollView setCanCancelContentTouches:NO];
		settingsScrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
		settingsScrollView.clipsToBounds = YES;
		settingsScrollView.scrollEnabled = YES;
		[settingsView addSubview:settingsScrollView];
		
		appView = [[UIView alloc] initWithFrame:CGRectMake( 0, 0, scrFrame.size.width, scrFrame.size.height )];
		appView.hidden = YES;
		appView.backgroundColor = [UIColor blackColor];
		[contentView addSubview:appView];
		
		[self makeApp:nil];
	}

	playerView = [[PlayingView alloc] init];
	playerView.hidden = playerViewWasHidden;
	[self.view addSubview:playerView];
	
	adfullView = [[AppMobiWebView alloc] initWithFrame:CGRectMake( 0, 0, webFrame.size.width, webFrame.size.height )];
	adfullView.backgroundColor = [UIColor clearColor];
	adfullView.scalesPageToFit = YES;
	adfullView.hidden = adfullViewWasHidden;
	[self.view addSubview:adfullView];
	
	richView = [[AppMobiWebView alloc] initWithFrame:CGRectMake( 0, 0, webFrame.size.width, webFrame.size.height )];
	richView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	richView.backgroundColor = [UIColor clearColor];
	richView.scalesPageToFit = YES;
	richView.hidden = richViewWasHidden;
	[self.view addSubview:richView];
	
	remoteView = [[AppMobiWebView alloc] initWithFrame:CGRectMake( 0, 0, webFrame.size.width, webFrame.size.height )];
	remoteView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	remoteView.backgroundColor = [UIColor clearColor];
	remoteView.scalesPageToFit = YES;
	remoteView.hidden = remoteViewWasHidden;
	[self.view addSubview:remoteView];
	
	appUpdateBlocker = [[UIView alloc] initWithFrame:CGRectMake( 0, 0, webFrame.size.width, webFrame.size.height )];
	appUpdateBlocker.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	appUpdateBlocker.backgroundColor = [UIColor blackColor];
	appUpdateBlocker.userInteractionEnabled = YES;
	appUpdateBlocker.alpha = 0.66;
	appUpdateBlocker.hidden = YES;
	[self.view addSubview:appUpdateBlocker];
    
    appUpdateMessage = [[UILabel alloc] initWithFrame:CGRectMake(0, 50, webFrame.size.width, 100)];
	appUpdateMessage.text = @"HTML5 Manifest Caching\nPlease wait while your webapp is (re)cached.";
	appUpdateMessage.textColor = [UIColor whiteColor];
	appUpdateMessage.backgroundColor = [UIColor clearColor];
	appUpdateMessage.font = [UIFont boldSystemFontOfSize:14.0];
	appUpdateMessage.hidden = YES;
	appUpdateMessage.textAlignment = UITextAlignmentCenter;
	appUpdateMessage.lineBreakMode = UILineBreakModeWordWrap;
	appUpdateMessage.numberOfLines = 5;
	[self.view addSubview:appUpdateMessage];
	
	appUpdateSpinner = [[UIImageView alloc] initWithImage:nil];
	appUpdateSpinner.frame = CGRectMake((webFrame.size.width-86)/2, 156, 86, 84);
	appUpdateSpinner.hidden = YES;
	appUpdateSpinner.animationImages = arUpdSpinner;
	appUpdateSpinner.animationDuration = 0.72;
	appUpdateSpinner.animationRepeatCount = 0;
	[self.view addSubview:appUpdateSpinner];
	
	pushView = [[AppMobiWebView alloc] initWithFrame:CGRectMake( 0, 0, 1, 1)];
	pushView.bIsMobiusPush = YES;
	
	remoteClose = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	remoteClose.frame = CGRectMake(0, 0, 48, 48);
	[remoteClose setTitle:@"" forState:UIControlStateNormal];
	[remoteClose addTarget:self action:@selector(onRemoteClose:) forControlEvents:UIControlEventTouchUpInside];
	[remoteClose setImage:nil forState:UIControlStateNormal];
	remoteClose.hidden = YES;
	[self.view addSubview:remoteClose];
	
	richSplash = [[UIImageView alloc] initWithImage:nil]; 
	richSplash.frame = CGRectMake( 0, 0, 320, 460 );
	richSplash.contentMode = UIViewContentModeTopLeft;
	richSplash.hidden = YES;
	[self.view addSubview:richSplash];
	
	richSpinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 36, 36)];
	richSpinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
	richSpinner.hidden = YES;
	[self.view addSubview:richSpinner];
	
	richMessage = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 5, 5)];
	richMessage.text = @"";
	richMessage.textColor = [UIColor whiteColor];
	richMessage.backgroundColor = [UIColor clearColor];
	richMessage.font = [UIFont boldSystemFontOfSize:14.0];
	richMessage.hidden = YES;
	richMessage.textAlignment = UITextAlignmentCenter;
	richMessage.lineBreakMode = UILineBreakModeWordWrap;
	richMessage.numberOfLines = 5;
	[self.view addSubview:richMessage];
	
	richClose = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	richClose.frame = CGRectMake(0, 0, 48, 48);
	[richClose setTitle:@"" forState:UIControlStateNormal];
	[richClose addTarget:self action:@selector(onRichClose:) forControlEvents:UIControlEventTouchUpInside];
	[richClose setImage:nil forState:UIControlStateNormal];
	richClose.hidden = YES;
	[self.view addSubview:richClose];
	
	speakView = [[UIView alloc] initWithFrame:CGRectMake( 0, 0, webFrame.size.width, webFrame.size.height )];
	speakView.backgroundColor = [UIColor blackColor];
	speakView.userInteractionEnabled = YES;
	speakView.alpha = 0.86;
	speakView.hidden = YES;
	[self.view addSubview:speakView];
	
	speakLogo = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"speak_icon.png"]];
	speakLogo.frame = CGRectMake(95, 70, 130, 230);
	[speakView addSubview:speakLogo];
	
	speakDone = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	speakDone.frame = CGRectMake(70, 310, 84, 48);
	[speakDone setTitle:@"" forState:UIControlStateNormal];
	[speakDone addTarget:self action:@selector(onDoneSpeech:) forControlEvents:UIControlEventTouchUpInside];
	[speakDone setImage:[UIImage imageNamed:@"button_done.png"] forState:UIControlStateNormal];
	[speakView addSubview:speakDone];
	
	speakCancel = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	speakCancel.frame = CGRectMake(166, 310, 84, 48);
	[speakCancel setTitle:@"" forState:UIControlStateNormal];
	[speakCancel addTarget:self action:@selector(onCancelSpeech:) forControlEvents:UIControlEventTouchUpInside];
	[speakCancel setImage:[UIImage imageNamed:@"button_cancel.png"] forState:UIControlStateNormal];
	[speakView addSubview:speakCancel];
	
	if( [delegate isWebContainer] == YES && mobiusIsRestarting == YES )
	{
		[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(refreshBookmarks:) userInfo:nil repeats:NO];
	}
}

- (void)onPage:(id)sender
{
}

- (void)onOpenSearch:(id)sender
{
	BOOL ipad = [AppMobiDelegate isIPad];
	if( bSearching == NO )
	{
		if( [topUrlField isFirstResponder] ) [topUrlField resignFirstResponder];
		[topOpenSearch setImage:[UIImage imageNamed:@"button_search_on.png"] forState:UIControlStateNormal];
		
		topUrlField.hidden = YES;
		topSearchField.text = @"";
		topSearchField.hidden = NO;
		botFav.hidden = YES;
		//botSpeak.hidden = NO;
		bSearching = YES;

		[self.view.layer removeAllAnimations];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationsEnabled:YES];
		[UIView setAnimationDuration:0.4];
		if( ipad == YES ) topSearchField.frame = CGRectMake(41, 14, 413, 21);
		else topSearchField.frame = CGRectMake(39, 5, 243, 21);
		[UIView commitAnimations];
	}
	else
	{
		botFav.hidden = NO;
		botSpeak.hidden = YES;
		[self.view.layer removeAllAnimations];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDidStopSelector:@selector(closer:finished:context:)];
		[UIView setAnimationsEnabled:YES];
		[UIView setAnimationDuration:0.4];
		[UIView setAnimationDelegate:self];
		if( ipad == YES ) topSearchField.frame = CGRectMake(453, 14, 1, 21);
		else topSearchField.frame = CGRectMake(281, 5, 1, 21);
		[UIView commitAnimations];
		if( [topSearchField isFirstResponder] ) [topSearchField resignFirstResponder];
	}
}

- (void)closer:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	[topOpenSearch setImage:[UIImage imageNamed:@"button_search.png"] forState:UIControlStateNormal];
	topUrlField.hidden = NO;
	topSearchField.hidden = YES;
	bSearching = NO;
	botFav.hidden = NO;
	botSpeak.hidden = YES;
}

- (void)hider:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context
{
	midWebBar.hidden = YES;
}

- (void)hideSearch:(id)sender
{
	[self closer:nil finished:nil context:nil];
	if( [AppMobiDelegate isIPad] == YES ) topSearchField.frame = CGRectMake(453, 14, 1, 21);
	else topSearchField.frame = CGRectMake(281, 5, 1, 21);
}

- (void)showWeb:(NSString *)url
{
	if( [[url lowercaseString] hasPrefix:@"http://"] == NO && [[url lowercaseString] hasPrefix:@"https://"] == NO )
	{
		url = [[NSString alloc] initWithFormat:@"http://%@", url];
	}
	
	lastURL = [url copy];
	[webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
	
	[self hideSearch:nil];
	topUrlField.text = url;
	bHomeShown = NO;
	botReload.hidden = YES;
	botCancel.hidden = NO;
	midWebBar.hidden = NO;
	botAppView.hidden = YES;
	botWebView.hidden = NO;
	[botHome setImage:[UIImage imageNamed:mobiusOffImage] forState:UIControlStateNormal];
	
	[midWebSpinner startAnimating];
	midWebSpinner.hidden = NO;
	
	[self.view.layer removeAllAnimations];
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationsEnabled:YES];
	[UIView setAnimationDuration:0.4];
	webView.frame = CGRectMake(0, 0, midWebBar.frame.size.width, midWebBar.frame.size.height);
	[UIView commitAnimations];
	
	[self updateButtons:nil];
}

- (void)onBookmark:(id)sender
{
	UIImageView *view = (UIImageView *)sender;
	int index = view.tag - 998877;
	if( [topSearchField isFirstResponder] ) [topSearchField resignFirstResponder];
	if( [topUrlField isFirstResponder] ) [topUrlField resignFirstResponder];
	
	//[webView loadHTMLString:@"" baseURL:[NSURL URLWithString:@"about:blank"]];
	//while( [webView canGoBack] ) [webView goBack];
	
	Bookmark *bookmark = [arActiveBookmarks objectAtIndex:startIndex + index];	
	if( bookmark.isInstalled == YES )
	{
		if( [bookmark.appconfig.appType compare:@"SITE"] == NSOrderedSame )
		{
			webView.config = bookmark.appconfig;
			[self showWeb:bookmark.appconfig.siteURL];
			
			[self addNewEmptyTab:nil];
		}
		else
		{
			_runBmk = bookmark;
			[self onRunApp:nil];
		}

	}
	else if( bookmark.isInstalling == YES && bookmark.isDownloading == NO)
	{
		[NSThread detachNewThreadSelector:@selector(installApps:) toTarget:self withObject:nil];
	}
	else
	{
		if( bookmark.isUserFav == YES )
		{
			[botFav setImage:[UIImage imageNamed:@"button_favorites_on.png"] forState:UIControlStateNormal];
		}
		[self showWeb:bookmark.url];
		
		[self addNewEmptyTab:nil];
	}
}

- (UIImage *)getTabImage:(UIWebView *)webview
{
	//rendering of page into tab image
	UIGraphicsBeginImageContext(webview.bounds.size);
	[webview.layer renderInContext:UIGraphicsGetCurrentContext()];
	
	UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	UIGraphicsBeginImageContext(CGSizeMake(72,72));
	[viewImage drawInRect:CGRectMake(0, 0, 72, 72)];

	UIImage *scleImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	
	return scleImage;
}

- (UIImage *)getFavImage:(id)sender
{
	UIImage *scleImage = nil;
	
	if( webView.loading == NO )
	{
		//rendering of page into tab image
		UIGraphicsBeginImageContext(webView.bounds.size);
		[webView.layer renderInContext:UIGraphicsGetCurrentContext()];
		
		UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		
		UIGraphicsBeginImageContext(CGSizeMake(104,104));
		[[UIImage imageNamed:@"96x96_shadow.png"] drawInRect:CGRectMake(0, 0, 104, 104)];
		[viewImage drawInRect:CGRectMake(4, 4, 96, 96)];
		
		scleImage = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
	}
	
	return scleImage;
}

- (void)onPushSwitch:(id)sender
{
	UISwitch *swtch = (UISwitch *)sender;
	int index = swtch.tag;
	
	// call add device or remove device	
	Bookmark *bookmark = [arActiveBookmarks objectAtIndex:startIndex + index];	
	AppMobiNotification *notification = (AppMobiNotification *) [pushView getCommandInstance:@"AppMobiNotification"];
	
	if( swtch.on == YES )
	{
		bookmark.hasPushOn = YES;
		[notification registerDevice:[AppMobiDelegate sharedDelegate].strDeviceToken withJSEvent:NO forApp:bookmark.appconfig.appName];
	}
	else
	{
		bookmark.hasPushOn = NO;
		bookmark.messages = 0;
		NSMutableArray *args = [[[NSMutableArray alloc] init] autorelease];
		[args addObject:bookmark.appconfig.appName];
		[notification deletePushUser:args withDict:nil];
		[self redrawBookmarks:nil];
	}
	
	[self saveAllBookmarks:nil];
}

- (void)onPushMessages:(id)sender
{
	UIButton *button = (UIButton *)sender;
	int index = button.tag - 993366;
	
	// Also run app/site for this push
	UIImageView *view = [homePics objectAtIndex:index];
	[self onBookmark:view];
	
	Bookmark *bookmark = [arActiveBookmarks objectAtIndex:startIndex + index];	
	AppMobiNotification *notification = (AppMobiNotification *) [pushView getCommandInstance:@"AppMobiNotification"];
	NSMutableArray *notes = [notification getAutoNotesForApp:bookmark.appconfig.appName];
	if( [notes count] > 0 )
	{
		[self showPushViewer:bookmark.appconfig forNotification:notification];
	}
}

- (void)onCloseApp:(id)sender
{
	[self checkForWrongOrientation:nil];
	
	appView.hidden = YES;
	
	CGRect scrFrame = [[UIScreen mainScreen] bounds];
	CGRect webFrame = [[UIScreen mainScreen] applicationFrame];
	appView.frame = CGRectMake( 0, 0, scrFrame.size.width, scrFrame.size.height );
	appWebView.frame = CGRectMake( 0, 20, webFrame.size.width, webFrame.size.height );
	appFooter.frame = CGRectMake( 0, 0, webFrame.size.width, 20 );
	
	appFooterBkg.frame = CGRectMake( 0, 0, webFrame.size.width, 20 );
	appUpdate.frame = CGRectMake(0, 0, 96, 20);
	appFavorite.frame = CGRectMake(webFrame.size.width/2-48, 0, 96, 20);
	appClose.frame = CGRectMake(webFrame.size.width-96, 0, 96, 20);
	
	[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:NO];
	self.view.frame = [[UIScreen mainScreen] applicationFrame];
	[appWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]]];
	_runBmk = nil;
	
	AppMobiPlayer *playMobi = [appWebView getCommandInstance:@"AppMobiPlayer"];
	[playMobi stop:nil withDict:nil];
	[playMobi stopAudio:nil withDict:nil];

	AppMobiCanvas *directMobi = [appWebView getCommandInstance:@"AppMobiCanvas"];
	[directMobi resetCanvas:nil];
	
	[self setRotateOrientation:@"portrait"];
	[self setAutoRotate:NO];
	
	NSString *rtn = [AppMobiDelegate sharedDelegate].urlRtn;
	if( sender != nil && rtn != nil && [rtn length] > 0 )
	{
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:rtn]];
	}
	
	[self refreshBookmarks:nil];
}

- (void)onFavoriteApp:(id)sender
{
	if( _runBmk != nil )
	{
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:_runBmk.appconfig.siteBook]];
	}
}

- (void)canDeleteApp:(id)sender
{
	int index = startIndex + [sender tag]-998855;
	
	Bookmark *bookmark = (Bookmark *) [arActiveBookmarks objectAtIndex:index];
	delBookmark = bookmark;
	
	NSString *name = bookmark.appname;
	if( name == nil ) name = bookmark.name;
	NSString *emessage = [NSString stringWithFormat:@"Are you sure you want to delete %@?", name];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Delete WebApp/Site" message:emessage delegate:self cancelButtonTitle:@"YES" otherButtonTitles:@"NO", nil];
	[alert show];
	[alert release];
}

- (void)removePush:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *appname = (NSString *)sender;
	NSMutableArray *args = [[[NSMutableArray alloc] init] autorelease];
	[args addObject:appname];
	
	AppMobiNotification *notification = (AppMobiNotification *) [pushView getCommandInstance:@"AppMobiNotification"];
	[notification deletePushUser:args withDict:nil];
	
	[pool release];
}

- (void)deleteApp:(id)sender
{
	if( delBookmark.hasPushOn == YES && delBookmark.appconfig != nil )
	{
		[NSThread detachNewThreadSelector:@selector(removePush:) toTarget:self withObject:delBookmark.appconfig.appName];
	}

	if( delBookmark.appconfig != nil )
	{
		[[NSFileManager defaultManager] removeItemAtPath:delBookmark.appconfig.baseDirectory error:nil];
		[[NSFileManager defaultManager] removeItemAtPath:delBookmark.appconfig.appDirectory error:nil];
	}
	
	NSMutableArray *bookmarks = [AppMobiDelegate sharedDelegate]._bookconfig.bookmarks;
	[bookmarks removeObject:delBookmark];
	[arAllBookmarks removeObject:delBookmark];
	arActiveBookmarks = arAllBookmarks;
	
	delBookmark = nil;
	[self saveAllBookmarks:nil];
	[self refreshBookmarks:nil];	
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if( buttonIndex == 0 )
	{
		[self deleteApp:nil];
	}
	delBookmark = nil;
}

- (void)alertViewCancel:(UIAlertView *)alertView
{
	delBookmark = nil;
}

- (void)installApps:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	BOOL bSuccess = NO;
	int iVersion = 0;
	bInstalling = YES;
	NSMutableArray *bookmarks = [AppMobiDelegate sharedDelegate]._bookconfig.bookmarks;
	for( int i = 0; i < [bookmarks count]; i++ )
	{
		Bookmark *bookmark = (Bookmark *) [bookmarks objectAtIndex:i];
		if( bookmark.isInstalling == YES )
		{
			bookmark.isDownloading = YES;
			[self performSelectorOnMainThread:@selector(redrawBookmarks:) withObject:nil waitUntilDone:NO];

			iVersion = bookmark.appconfig.appVersion;
			bookmark.appconfig.appVersion = 0;
			bSuccess = [[AppMobiDelegate sharedDelegate] downloadUpdate:bookmark.appconfig];
			bSuccess = [[AppMobiDelegate sharedDelegate] installUpdate:bookmark.appconfig];
			bookmark.appconfig.appVersion = iVersion;
			bookmark.isDownloading = NO;
			
			if( bSuccess == YES )
			{
				bookmark.isInstalling = NO;
				bookmark.isInstalled = YES;
				NSString *bmarksfile = [[AppMobiDelegate baseDirectory] stringByAppendingPathComponent:@"bookmarks.dat"];
				[NSKeyedArchiver archiveRootObject:[AppMobiDelegate sharedDelegate]._bookconfig.bookmarks toFile:bmarksfile];
			}
			else
			{
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Installation Error" message:@"We were unable to download the application. Please verify your connection" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
				[alert show];
				[alert release];	
			}

			
			[self performSelectorOnMainThread:@selector(redrawBookmarks:) withObject:nil waitUntilDone:NO];
			
		}
	}
	bInstalling = NO;
	
	[pool release];
}

- (void)onUpdateApp:(id)sender
{
}

- (void)onRunSite:(id)sender
{
	if( runUrl == nil && _runBmk != nil )
	{
		webView.config = _runBmk.appconfig;
		runUrl = _runBmk.appconfig.siteURL;
		_runBmk = nil;
	}
	
	[self showWeb:runUrl];
	
	[self addNewEmptyTab:nil];
}

- (void)onDownloadAppUpdate:(id)sender
{
    // start update worker to update app
}

- (void)onRunApp:(id)sender
{
    NSString *appUrl = _runBmk.appconfig.siteURL;
    if( appUrl == nil || [appUrl length] == 0 )
    {
        NSString *strFile = [_runBmk.appconfig.appDirectory stringByAppendingPathComponent:@"index.html"];
        if( [[NSFileManager defaultManager] fileExistsAtPath:strFile] == NO )
        {
            bInstalling = YES;
            _installBmk = _runBmk;
            _installBmk.isDownloading = YES;
            _runBmk = nil;
            [[AppMobiDelegate sharedDelegate] performSelectorOnMainThread:@selector(downloadCachedApp:) withObject:_installBmk waitUntilDone:NO];
            
            startIndex = bookmarkMax * (int) ([arActiveBookmarks count] / bookmarkMax);
            [self redrawBookmarks:nil];
            return;
        }
    
        [[AppMobiDelegate sharedDelegate] installUpdate:_runBmk.appconfig];
        [NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(onDownloadAppUpdate:) userInfo:nil repeats:NO];
        
        appUrl = [NSString stringWithFormat:@"http://localhost:58888/%@/%@/index.html", _runBmk.appconfig.appName, _runBmk.appconfig.relName];
    }

	[self hideTabs:nil];
	[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:NO];
	self.view.frame = [[UIScreen mainScreen] bounds];
	appWebView.config = _runBmk.appconfig;
	[appWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:appUrl]]];
	
    if(directCanvas != nil) {
        [directCanvas retain];
        [directCanvas removeFromSuperview];
        [appView insertSubview:directCanvas atIndex:0];
        [directCanvas release];
    }
	appView.hidden = NO;
	
	[self setAutoRotate:YES];
	[self setRotateOrientation:@"any"];
	
	UIViewController *c = [[[UIViewController alloc] init] autorelease];
	[self presentModalViewController:c animated:NO];
	[self dismissModalViewControllerAnimated:NO];
}

- (void)on1Touch:(id)sender
{
	[self hideSettings:nil];
	[self hideTabs:nil];
	
	webView.config = [AppMobiDelegate sharedDelegate]._payconfig;
	[self showWeb:[AppMobiDelegate sharedDelegate].onetouchURL];
	
	[self addNewEmptyTab:nil];	
}

- (void)onGallery:(id)sender
{
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[AppMobiDelegate sharedDelegate].galleryURL]];
}

- (void)onSettings:(id)sender
{
	if( bSetShown == YES ) { [self hideSettings:nil]; return; }
	
	[self hideTabs:nil];
	[self makeSettings:nil];
	bSetShown = YES;
	settingsView.hidden = NO;
	settingsHeader.hidden = NO;
	[botSettings setImage:[UIImage imageNamed:setOnImage] forState:UIControlStateNormal];
	[botHome setImage:[UIImage imageNamed:mobiusOffImage] forState:UIControlStateNormal];
}

- (void)clearNotifications:(id)sender
{
	AppMobiNotification* notification = (AppMobiNotification *) [webView getCommandInstance:@"AppMobiNotification"];
	NSArray *keys = [notification.pushUserNotifications allKeys];
	NSString* pipedKeys = [keys componentsJoinedByString:@"|"];
	NSMutableArray* args = [NSArray arrayWithObject:pipedKeys];
	[notification readPushNotifications:args withDict:nil];
	[self refreshBookmarks:self];	
}

- (void)onHome:(id)sender
{
	[self hideSettings:nil];
	[self hideTabs:nil];
	
	UIWebView *oldview = webView;
	curTab = [arTabs count] - 1;
	webView = [arTabs objectAtIndex:curTab];
	
	if( bHomeShown == NO ) startIndex = 0;
	topUrlField.text = @"http://";
	midWebBar.hidden = YES;
	botAppView.hidden = NO;
	botWebView.hidden = YES;
	bHomeShown = YES;
	arActiveBookmarks = arAllBookmarks;
	[self redrawBookmarks:nil];
	
	[botFav setImage:[UIImage imageNamed:@"button_favorites.png"] forState:UIControlStateNormal];
	[botHome setImage:[UIImage imageNamed:mobiusOnImage] forState:UIControlStateNormal];

	[midWebSpinner stopAnimating];
	midWebSpinner.hidden = YES;
	
	[self.view.layer removeAllAnimations];
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationsEnabled:YES];
	[UIView setAnimationDuration:0.4];
	oldview.frame = CGRectMake(-1 * midWebBar.frame.size.width, 0, midWebBar.frame.size.width, midWebBar.frame.size.height);
	[UIView commitAnimations];
}

- (void)refreshTabs:(id)sender
{
	botTabSel.hidden = YES;
	for( int i = 0; i < tabMax; i++ )
	{
		UIImageView *tab = [tabPics objectAtIndex:i];
		UIButton *del = [tabDels objectAtIndex:i];
		
		int index = tabIndex + i;
		if( index < [arTabs count] - 1 )
		{
			UIWebView *webview = [arTabs objectAtIndex:index];
			[tab stopAnimating];
			tab.animationImages = nil;
			tab.hidden = NO;
			
			if( webview.loading == YES )
			{
				tab.image = nil;
				tab.animationImages = arTabSpinner;
				tab.animationDuration = 0.72;
				tab.animationRepeatCount = 0;
				[tab startAnimating];
			}
			else
			{
				tab.image = [self getTabImage:webview];
			}
			del.hidden = NO;
		}
		else
		{
			tab.hidden = YES;
			del.hidden = YES;
		}
		
		if( index == curTab )
		{
			if( webView.tag == 0 )
			{
				botTabSel.frame = CGRectMake( tab.frame.origin.x - 2, 3, 76, 76 );
				botTabSel.hidden = NO;
			}
		}
	}
	
	botTabWin.hidden = YES;
	if( [AppMobiDelegate isIPad] == NO && [arTabs count] > 5 )
	{
		botTabWin.hidden = NO;
		int xcoord = 128 - ( 8 * ( [arTabs count] - 5 ) );
		botTabWin.frame = CGRectMake(xcoord + (16 * tabIndex), 80, 64, 14);
	}
	if( [AppMobiDelegate isIPad] == YES && [arTabs count] > 8 )
	{
		botTabWin.hidden = NO;
		int xcoord = 327 - ( 8 * ( [arTabs count] - 8 ) );
		botTabWin.frame = CGRectMake(xcoord + (16 * tabIndex), 80, 113, 14);
	}
	
	if( webView.tag == -1 )
	{
		tabPages.numberOfPages = 0;
		tabPages.numberOfPages = [arTabs count] - 1;
	}
}

- (void)onTabs:(id)sender
{
	if( [topSearchField isFirstResponder] ) [topSearchField resignFirstResponder];
	if( [topUrlField isFirstResponder] ) [topUrlField resignFirstResponder];

	if( bTabShown == YES ) { [self hideTabs:nil]; return; }
	
	[self hideSettings:nil];
	bTabShown = YES;
	botTabBlk.hidden = NO;
	botTabBar.hidden = NO;
	[botTab setImage:[UIImage imageNamed:tabOnImage] forState:UIControlStateNormal];
	[botHome setImage:[UIImage imageNamed:mobiusOffImage] forState:UIControlStateNormal];
	
	tabPages.numberOfPages = [arTabs count] - 1;
	tabPages.currentPage = curTab;
	
	tabIndex = curTab - (tabMax - 1);
	if( webView.tag == -1 ) tabIndex--;
	if( tabIndex < 0 ) tabIndex = 0;
	
	[self performSelectorOnMainThread:@selector(refreshTabs:) withObject:nil waitUntilDone:NO];
	
	[self.view.layer removeAllAnimations];
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationsEnabled:YES];
	[UIView setAnimationDuration:0.4];
	[UIView setAnimationDelegate:self];
	if( [AppMobiDelegate isIPad] == YES ) botTabBar.frame = CGRectMake( 0, 48, midWebBar.frame.size.width, 96 );
	else botTabBar.frame = CGRectMake( 0, midWebBar.frame.size.height+32-96, midWebBar.frame.size.width, 96 );
	[UIView commitAnimations];
}

- (void)onDelTab:(id)sender
{
	UIButton *button = (UIButton *)sender;
	int index = button.tag - 997755;
	
	AppMobiWebView *webview = [arTabs objectAtIndex:tabIndex + index];
	[webview removeFromSuperview];
	[webview release];
	[arTabs removeObjectAtIndex:tabIndex + index];

	if( tabIndex + index < curTab ) curTab--;	
	if( tabIndex > 0 && tabIndex > [arTabs count] - (tabMax + 1) ) tabIndex--;
	if( tabIndex < 0 ) tabIndex = 0;
	
	tabPages.currentPage = curTab;
	tabPages.numberOfPages = [arTabs count] - 1;
	webView = [arTabs objectAtIndex:curTab];
	
	if( curTab < [arTabs count] - 1 )
	{
		NSString *urlstr = [[[webView request] URL] absoluteString];
		topUrlField.text = urlstr;
		[midWebBar bringSubviewToFront:webView];
		webView.frame = CGRectMake(0, 0, midWebBar.frame.size.width, midWebBar.frame.size.height);
	}
	else
	{
		topUrlField.text = @"http://";
		webView.frame = CGRectMake(-1 * midWebBar.frame.size.width, 0, midWebBar.frame.size.width, midWebBar.frame.size.height);
		midWebBar.hidden = YES;
		bHomeShown = YES;
		botAppView.hidden = NO;
		botWebView.hidden = YES;
	}

	[midWebSpinner stopAnimating];
	midWebSpinner.hidden = YES;

	[self updateFavorite:nil];
	[self performSelectorOnMainThread:@selector(refreshTabs:) withObject:nil waitUntilDone:NO];
}

- (void)onTab:(id)sender
{
	UIButton *button = (UIButton *)sender;
	int index = button.tag - 997766;
	if( [topSearchField isFirstResponder] ) [topSearchField resignFirstResponder];
	if( [topUrlField isFirstResponder] ) [topUrlField resignFirstResponder];
	
	UIWebView *oldview = webView;
	index += tabIndex;

	curTab = index;
	webView = [arTabs objectAtIndex:curTab];
	
	if( oldview != webView )
	{
		[midWebSpinner stopAnimating];
		midWebSpinner.hidden = YES;

		NSString *urlstr = [[[webView request] URL] absoluteString];
		topUrlField.text = urlstr;
		midWebBar.hidden = NO;
		bHomeShown = NO;
		botWebView.hidden = NO;
		botAppView.hidden = YES;
		[botHome setImage:[UIImage imageNamed:mobiusOffImage] forState:UIControlStateNormal];
		[midWebBar bringSubviewToFront:webView];

		[self.view.layer removeAllAnimations];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationsEnabled:YES];
		[UIView setAnimationDuration:0.4];
		oldview.frame = CGRectMake(-1 * midWebBar.frame.size.width, 0, midWebBar.frame.size.width, midWebBar.frame.size.height);
		webView.frame = CGRectMake(0, 0, midWebBar.frame.size.width, midWebBar.frame.size.height);
		[UIView commitAnimations];
	}

	[self onTabs:nil];
}

- (void)onDoSearch:(id)sender
{
	NSString *strQuery = topSearchField.text;
	[topSearchField resignFirstResponder];
	
	strQuery = [[AppMobiDelegate sharedDelegate] urlencode:strQuery];
	NSString *searchURL = [NSString stringWithFormat:@"http://www.google.com/search?q=%@", strQuery];
	
	NSURLRequest *req = [webView request];
	[self showWeb:searchURL];
	
	if( req == nil ) [self addNewEmptyTab:nil];
}

- (void)onBack:(id)sender
{
	if( [webView canGoBack] )
	{
		[webView goBack];
		[self updateButtons:nil];
	}
	else if( bHomeShown == NO )
	{
		[self hideSearch:nil];
		topUrlField.text = @"http://";
		bHomeShown = YES;
		[webView loadHTMLString:@"" baseURL:[NSURL URLWithString:@"about:blank"]];
		while( [webView canGoBack] ) [webView goBack];
		
		[self.view.layer removeAllAnimations];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDidStopSelector:@selector(hider:finished:context:)];
		[UIView setAnimationsEnabled:YES];
		[UIView setAnimationDuration:0.4];
		[UIView setAnimationDelegate:self];
		webView.frame = CGRectMake(-1 * midWebBar.frame.size.width, 0, midWebBar.frame.size.width, midWebBar.frame.size.height);
		[UIView commitAnimations];
		
		[self updateButtons:nil];
	}
}

- (void)onDoSpeech:(id)sender
{
	nuance = [[SKRecognizer alloc] initWithType:SKSearchRecognizerType detection:SKShortEndOfSpeechDetection language:@"en_US" delegate:self];
}

- (void)onDoneSpeech:(id)sender
{
	speakDone.hidden = YES;
	speakCancel.hidden = YES;
	[nuance stopRecording];
}

- (void)onCancelSpeech:(id)sender
{
	bRecCancel = YES;
	[nuance cancel];
}

- (void)onSpeech:(id)sender
{
	if( bRecording == YES ) return;
	
	bRecording = YES;
	bRecCancel = NO;
	speakCancel.hidden = NO;
	speakDone.hidden = NO;
	speakView.hidden = NO;
	speakLogo.image = [UIImage imageNamed:@"speak_icon.png"];
	[NSTimer scheduledTimerWithTimeInterval:0.0 target:self selector:@selector(onDoSpeech:) userInfo:nil repeats:NO];
}

- (void)recognizerDidFinishRecording:(SKRecognizer *)recognizer
{
	speakLogo.image = [UIImage imageNamed:@"speak_processing_icon.png"];
	speakDone.hidden = YES;
	speakCancel.hidden = YES;
}

- (void)recognizer:(SKRecognizer *)recognizer didFinishWithResults:(SKRecognition *)recognition
{
	AMLog(@"didFinishWithResults -- %@", recognition.results);
	
    [nuance release];
	
	if( [recognition.results count] > 0 )
	{
		bRecording = NO;
		speakView.hidden = YES;
		topSearchField.text = [recognition.results objectAtIndex:0];
		[self onDoSearch:topSearchField];
	}
	else
	{
		speakCancel.hidden = NO;
		nuance = [[SKRecognizer alloc] initWithType:SKSearchRecognizerType detection:SKShortEndOfSpeechDetection language:@"en_US" delegate:self];
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Speech Recognition Error" message:recognition.suggestion delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];	
	}
}

- (void)recognizer:(SKRecognizer *)recognizer didFinishWithError:(NSError *)error suggestion:(NSString *)suggestion
{
	AMLog(@"didFinishWithError -- %@", error);

    [nuance release];
	bRecording = NO;
	speakView.hidden = YES;
}

- (void)hideRichSplash:(id)sender
{
	richSplash.hidden = YES;
	richMessage.hidden = YES;
	richSpinner.hidden = YES;
	[richSpinner stopAnimating];
}

- (void)richLoaded:(id)sender
{
	if( richSplash.hidden == YES ) return;
	
	NSTimeInterval delay = 2.0 - ( [[NSDate date] timeIntervalSince1970] - richStart );
	if( delay < 0.0 ) delay = 0.0;
	[NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(hideRichSplash:) userInfo:nil repeats:NO];
}

- (void)pageLoaded:(id)sender
{
	UIWebView *wview = (UIWebView *)sender;
	if( sender == nil ) return;
	
	wview.tag = 0;
	[midWebSpinner stopAnimating];
	midWebSpinner.hidden = YES;

	if( wview == webView )
	{
		[self updateFavorite:nil];
		NSString *urlstr = [[[webView request] URL] absoluteString];
		topUrlField.text = urlstr;
		[lastURL release];
		lastURL = nil;

		botCancel.hidden = YES;
		botReload.hidden = NO;
	}

	if( bTabShown == YES )
	{
		tabPages.numberOfPages = [arTabs count] - 1;
		tabPages.currentPage = curTab;

		[self performSelectorOnMainThread:@selector(refreshTabs:) withObject:nil waitUntilDone:NO];
	}
	else
	{
		[self updateButtons:nil];
	}
}

- (void)onCancel:(id)sender
{
	[midWebSpinner stopAnimating];
	midWebSpinner.hidden = YES;

	[webView stopLoading];
	botCancel.hidden = YES;
	botReload.hidden = NO;
}

- (void)onRefresh:(id)sender
{
	[webView stopLoading];
	if( lastURL != nil )
		[webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:lastURL]]];
	else
		[webView loadRequest:webView.request];
}

- (void)onForward:(id)sender
{
	if( [webView canGoForward] )
	{
		[webView goForward];
	}
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
	if( textField == topUrlField )
	{
		topUrlField.textColor = [UIColor blackColor];
		topUrlField.backgroundColor = [UIColor whiteColor];
	}
	
	return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	if( textField == topUrlField )
	{
		topUrlField.textColor = [UIColor whiteColor];
		topUrlField.backgroundColor = [UIColor clearColor];
	}
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	
	if( textField == topSearchField)
	{
		[self onDoSearch:textField];
	}
	
	if( textField == topUrlField )
	{
		if( [topUrlField.text compare:@"http://"] != NSOrderedSame )
		{
			NSURLRequest *req = [webView request];
			[self showWeb:topUrlField.text];
			if( req == nil ) [self addNewEmptyTab:nil];
		}
	}
	
	if( textField == textBeingEdited )
	{
		[self endLabelEdit:textField];
	}
	
	return YES;
}

- (void)onAddFavorite:(id)sender
{
	if( bHomeShown == YES ) return;
	[botFav setImage:[UIImage imageNamed:@"button_favorites_on.png"] forState:UIControlStateNormal];
	
	Bookmark* fave = [[Bookmark alloc] init];
	fave.url = webView.request.URL.absoluteString;
	fave.uiImage = [self getFavImage:self];
	
	//trim extra pieces from host before assigning name
	NSMutableArray* hostPieces = [NSMutableArray arrayWithArray:[webView.request.URL.host componentsSeparatedByString:@"."]];
	while ([hostPieces count]>2) [hostPieces removeObjectAtIndex:0];
	fave.name = [hostPieces componentsJoinedByString:@"."];
	fave.isUserFav = YES;
	[arAllBookmarks addObject:fave];
	
	NSMutableArray *bookmarks = [AppMobiDelegate sharedDelegate]._bookconfig.bookmarks;
	[bookmarks addObject:fave];
	
	[self saveAllBookmarks:nil];
	[self redrawBookmarks:nil];
}

- (void)updateInstall:(Bookmark *)bookmark withPercent:(double)percent
{
    bookmark.percent = percent;
    appInstall.progress = percent;
    [self redrawBookmarks:nil];
}

- (void)statusInstall:(Bookmark *)bookmark withSuccess:(BOOL)success
{
    bookmark.isDownloading = NO;
    bInstalling = NO;
    [self redrawBookmarks:nil];
    
    // run the installed app
    if( success == YES )
    {
        [self performSelectorOnMainThread:@selector(onCloseApp:) withObject:nil waitUntilDone:YES];
        _runBmk = _installBmk;
        _installBmk = nil;
        [self performSelectorOnMainThread:@selector(onRunApp:) withObject:nil waitUntilDone:NO];
    }
    else
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error Installing" message:@"Unable to download or install this application. Please contact your vendor." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        [alert release];
        
        delBookmark = _installBmk;
        _installBmk = nil;
        [self deleteApp:nil];
    }
}

- (void)refreshBookmarks:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSDictionary* msgCountPerApp = [(AppMobiNotification *) [pushView getCommandInstance:@"AppMobiNotification"] getCountsPerBookmark];
	NSMutableArray *bookmarks = [AppMobiDelegate sharedDelegate]._bookconfig.bookmarks;

	pushCount = 0;
	[arAllBookmarks removeAllObjects];
	for( int i = 0; i < [bookmarks count]; i++ )
	{
		Bookmark *bookmark = (Bookmark *) [bookmarks objectAtIndex:i];		
		bookmark.isApplication = [bookmark.appconfig.appType compare:@"APP"] == NSOrderedSame;
		if( bookmark.hasPushOn == YES ) pushCount++;
		
		NSNumber* msgCount = [msgCountPerApp objectForKey:bookmark.appname];
		if( msgCount == nil )
		{
			bookmark.messages = 0;
		}
		else
		{
			bookmark.messages = [msgCount intValue];
		}

		[arAllBookmarks addObject:bookmark];
	}
	
	[self redrawBookmarks:nil];
	
	[pool release];
}

- (void)redrawBookmarks:(id)sender
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
	appInstall.hidden = YES;
	botSettings.hidden = ( pushCount == 0 );
	homePages.numberOfPages = ceil( [arActiveBookmarks count] / bookmarkMax );
	homePages.currentPage = startIndex / bookmarkMax;
	[homePages updateCurrentPageDisplay];
	
	for( int i = 0; i < bookmarkMax; i++ )
	{
		UIImageView *fav = [homePics objectAtIndex:i];		
		UILabel *name = [homeNames objectAtIndex:i];
		UIButton *bubble = [homeBubbles objectAtIndex:i];
		UIButton *del = [homeDels objectAtIndex:i];
		
		int index = startIndex + i;
		if( index < [arActiveBookmarks count] )
		{
			Bookmark *bookmark = [arActiveBookmarks objectAtIndex:index];
			
			if( bookmark.uiImage == nil )
			{
				NSString *filename = [[AppMobiDelegate baseDirectory] stringByAppendingFormat:@"/%@/%@/merchant.png", bookmark.appname, bookmark.relname];
				fav.image = [UIImage imageWithContentsOfFile:filename];
				if( fav.image == nil ) fav.image = [UIImage imageNamed:@"default_thumb.png"];
			}
			else
			{
				fav.image = bookmark.uiImage;
			}

			fav.hidden = NO;
			fav.alpha = 1.00;
			
			name.text = bookmark.name;
			name.hidden = NO;
			del.hidden = YES;
			
			if( bookmark.messages > 0 )
			{
				[bubble setTitle:[NSString stringWithFormat:@"%d", bookmark.messages] forState:UIControlStateNormal];
				bubble.hidden = NO;
			}
			else
			{
				bubble.hidden = YES;
			}
			
			if( bookmark.isInstalling == YES ) fav.alpha = 0.66;
			if( bookmark.isDownloading == YES )
			{
				appInstall.frame = name.frame;
                name.hidden = YES;
				appInstall.hidden = NO;
			}            
		}
		else
		{
			fav.hidden = YES;
			name.hidden = YES;
			bubble.hidden = YES;
			del.hidden = YES;
		}
	}
	
	[pool release];
}
	
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if( [topSearchField isFirstResponder] )
	{
		[topSearchField resignFirstResponder];
		return;
	}
	if( [topUrlField isFirstResponder] )
	{
		[topUrlField resignFirstResponder]; 
		topUrlField.textColor = [UIColor whiteColor];
		topUrlField.backgroundColor = [UIColor clearColor];
		return;
	}
	
	if( bSetShown == YES || [[AppMobiDelegate sharedDelegate] isWebContainer] == NO ) return;

	UITouch *touch = [[touches allObjects] objectAtIndex:0];
	dragStart = [touch locationInView:nil];
		
	
	if( bHomeShown == YES && bTabShown == NO )
	{
		for( int i = 0; i < bookmarkMax; i++ )
		{
			UIImageView *view = [homePics objectAtIndex:i];
			if( view.hidden == NO && CGRectContainsPoint( view.frame, [touch locationInView:homeView] ) )
			{
				if( bInstalling == NO )
				{
					homeStartView = view;
				}
				break;
			}
		}
	}
	else if( bTabShown == YES )
	{
		for( int i = 0; i < tabMax; i++ )
		{
			UIImageView *view = [tabPics objectAtIndex:i];
			if( view.hidden == NO && CGRectContainsPoint( view.frame, [touch locationInView:botTabBar] ) )
			{
				tabStartView = view;
				break;
			}
		}
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{	
	if( bSetShown == YES || [[AppMobiDelegate sharedDelegate] isWebContainer] == NO ) return;

	if(textBeingEdited!=nil) {
		UITouch *touch = [[touches allObjects] objectAtIndex:0];
		if(CGRectContainsPoint(textBeingEdited.frame, [touch locationInView:textBeingEdited])==NO) {
			[self endLabelEdit:self];
			return;
		}
	}
	
	if( dragStart.x < 0.0 && dragStart.y < 0.0 ) return;

	UITouch *touch = [[touches allObjects] objectAtIndex:0];
	CGPoint dragEnd = [touch locationInView:nil];
	
	if( bHomeShown == YES && homeStartView != nil)
	{
		if( CGRectContainsPoint( homeStartView.frame, [touch locationInView:homeView] ) )
		{
			[self performSelectorOnMainThread:@selector(onBookmark:) withObject:homeStartView waitUntilDone:NO];
			return;
		}
	}
	else if( bTabShown == YES && tabStartView != nil )
	{
		if( CGRectContainsPoint( tabStartView.frame, [touch locationInView:botTabBar] ) )
		{
			[self performSelectorOnMainThread:@selector(onTab:) withObject:tabStartView waitUntilDone:NO];
			return;
		}
	}
		
	int count = 0;
	int index = 0;
	int max = 0;
	int swipe = 0;
	int dir = 0;
	
	homeStartView = nil;
	
	if( bTabShown == YES )
	{
		count = [arTabs count];
		index = tabIndex + tabMax;
		max = 1;
		swipe = 1;
	}
	else if( bHomeShown == YES )
	{
		count = [arActiveBookmarks count];
		index = startIndex;
		max = bookmarkMax;
		swipe = bookmarkMax;
	}
	
	if( count == 0 ) return;
	
	if( self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft )
	{
		if( (dragStart.y - dragEnd.y) > 50 && index > 0 )
		{
			dir = -1;
		}
		if( (dragStart.y - dragEnd.y) < -50 && index + max < count )
		{
			dir = 1;
		}
	}
	else if( self.interfaceOrientation == UIInterfaceOrientationLandscapeRight )
	{
		if( (dragStart.y - dragEnd.y) < -50 && index > 0 )
		{
			dir = -1;
		}
		if( (dragStart.y - dragEnd.y) > 50 && index + max < count )
		{
			dir = 1;
		}
	}
	else if( self.interfaceOrientation == UIInterfaceOrientationPortrait )
	{
		if( (dragStart.x - dragEnd.x) < -50 && index > 0 )
		{
			dir = -1;
		}
		if( (dragStart.x - dragEnd.x) > 50 && index + max < count )
		{
			dir = 1;
		}
	}
	else if( self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown )
	{
		if( (dragStart.x - dragEnd.x) > 50 && index > 0 )
		{
			dir = -1;
		}
		if( (dragStart.x - dragEnd.x) < -50 && index + max < count )
		{
			dir = 1;
		}
	}

	if( dir != 0  && bTabShown == YES )
	{
		tabIndex += dir * swipe;
		if( tabIndex < 0 ) tabIndex = 0;
		if( tabIndex > [arTabs count] - tabMax ) tabIndex = [arTabs count] - tabMax;
		[self performSelectorOnMainThread:@selector(refreshTabs:) withObject:nil waitUntilDone:NO];
	}
	else if( dir != 0  && bHomeShown == YES )
	{
		startIndex += dir * swipe;
		[self redrawBookmarks:nil];
	}

	dragStart = CGPointMake(-1.0, -1.0);
}

- (void)showPushViewer:(AppConfig *)config forNotification:(AppMobiNotification *)notification;
{
	AppMobiPushViewController *viewer = [[[AppMobiPushViewController alloc] init] autorelease];
	viewer.config = config;
	viewer.notification = notification;
	UINavigationController *navBar = [[[UINavigationController alloc] initWithRootViewController:viewer] autorelease];
	[self presentModalViewController:navBar animated:YES];
	bPushShowing = YES;
	pushConfig = config;
	pushNote = notification;
}

- (void)showRemote:(NSString*)url forApp:(AppConfig *)config atPort:(CGRect)port atLand:(CGRect)land
{
	UIImage *remoteImage;
	NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/remote_close.png"];
	if( NO == [[NSFileManager defaultManager] fileExistsAtPath:path] )
	{
		path = [[NSBundle mainBundle] pathForResource:@"remote_close" ofType:@"png"];
	}
	remoteImage = [[UIImage alloc] initWithContentsOfFile:path];
	[remoteClose setImage:remoteImage forState:UIControlStateNormal];

	remoteView.config = config;
	NSURLRequest *remoteReq = [NSURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20.0];
	[remoteView loadRequest:remoteReq];

	rectRemoteClosePort = port;
	rectRemoteCloseLand = land;
	remoteClose.frame = (self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown || self.interfaceOrientation == UIInterfaceOrientationPortrait) ? rectRemoteClosePort : rectRemoteCloseLand;
	remoteView.hidden = NO;
	remoteClose.hidden = NO;
}

- (void)showRich:(AMSNotification *)notification forApp:(AppConfig *)config atPort:(CGRect)port atLand:(CGRect)land
{
	UIImage *richImage;
	NSString *path = [config.appDirectory stringByAppendingPathComponent:@"_appMobi/rich_close.png"];
	if( NO == [[NSFileManager defaultManager] fileExistsAtPath:path] )
	{
		path = [[NSBundle mainBundle] pathForResource:@"rich_close" ofType:@"png"];	
	}
	richImage = [[UIImage alloc] initWithContentsOfFile:path];
	[richClose setImage:richImage forState:UIControlStateNormal];
	
	richView.config = config;
	if( notification.richurl != nil && [notification.richurl length] > 0 )
	{
		NSURLRequest *richReq = [NSURLRequest requestWithURL:[NSURL URLWithString:notification.richurl] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20.0];
		[richView loadRequest:richReq];
	}
	else
	{
		NSString *richpath = [config.appDirectory stringByAppendingPathComponent:@"rich_message_index.html"];
		if( YES == [[NSFileManager defaultManager] fileExistsAtPath:richpath] ) [[NSFileManager defaultManager] removeItemAtPath:richpath error:nil];
		[[NSFileManager defaultManager] createFileAtPath:richpath contents:[notification.richhtml dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];

		NSString *startPage = [NSString stringWithFormat:@"http://localhost:58888/%@/%@/rich_message_index.html", config.appName, config.relName];																			 
		NSURLRequest *richReq = [NSURLRequest requestWithURL:[NSURL URLWithString:startPage] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20.0];
		[richView loadRequest:richReq];
	}
	
	[NSTimer scheduledTimerWithTimeInterval:25.0 target:self selector:@selector(hideRichSplash:) userInfo:nil repeats:NO];
	richStart = [[NSDate date] timeIntervalSince1970];
	bRichShowing = YES;
	lastRich = [[NSString alloc] initWithFormat:@"%d", notification.ident];
	rectRichClosePort = port;
	rectRichCloseLand = land;

	BOOL ipad = [AppMobiDelegate isIPad];
	BOOL ispt = (self.interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown || self.interfaceOrientation == UIInterfaceOrientationPortrait);
	
	rectRichSplashPort = ( ipad ? CGRectMake(0,0,768,1004) : CGRectMake(0,0,320,544) );
	rectRichSplashLand = ( ipad ? CGRectMake(0,0,1024,748) : CGRectMake(-44,0,544,300) );
	rectRichSpinnerPort = ( ipad ? CGRectMake(360,478,48,48) : CGRectMake(142,212,36,36) );
	rectRichSpinnerLand = ( ipad ? CGRectMake(488,350,48,48) : CGRectMake(222,132,36,36) );
	rectRichMessagePort = ( ipad ? CGRectMake(116,208,536,124) : CGRectMake(14,71,292,100) );
	rectRichMessageLand = ( ipad ? CGRectMake(245,128,533,122) : CGRectMake(49,22,384,80) );
	
	richView.hidden = NO;
	richClose.frame = ( ispt ? rectRichClosePort : rectRichCloseLand );
	richClose.hidden = NO;
	richMessage.frame = ( ispt ? rectRichMessagePort : rectRichMessageLand );
	richMessage.text = notification.message;
	richMessage.hidden = NO;
	richSplash.frame = ( ispt ? rectRichSplashPort : rectRichSplashLand );
	richSplash.image = [self getRichSplash];
	richSplash.hidden = NO;
	richSpinner.frame = ( ispt ? rectRichSpinnerPort : rectRichSpinnerLand );
	richSpinner.hidden = NO;
	[richSpinner startAnimating];
}

- (void)hideRemote:(id)sender
{
	if( remoteView.hidden == YES ) return;
	[self performSelectorOnMainThread:@selector(onRemoteClose:) withObject:nil waitUntilDone:NO];
}

- (void)hideRich:(id)sender
{
	if( richView.hidden == YES ) return;
	[self performSelectorOnMainThread:@selector(onRichClose:) withObject:nil waitUntilDone:NO];
}

- (void)showAdFull:(NSString*)url
{
	NSURLRequest *remoteReq = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:url] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20.0];	
	[adfullView loadRequest:remoteReq];
	
	adfullView.hidden = NO;
}

- (void)hideAdFull:(id)sender
{
	adfullView.hidden = YES;
}

- (void)showUpdate:(id)sender
{	
	appUpdateBlocker.hidden = NO;
	appUpdateSpinner.hidden = NO;
	[appUpdateSpinner startAnimating];
}

- (void)hideUpdate:(id)sender
{	
	appUpdateBlocker.hidden = YES;
	appUpdateSpinner.hidden = YES;
	[appUpdateSpinner stopAnimating];
}

- (void)scanBarcode:(id)sender
{
	ZBarReaderViewController *reader = [ZBarReaderViewController new];
    reader.readerDelegate = self;
	
    ZBarImageScanner *scanner = reader.scanner;
    [scanner setSymbology:ZBAR_I25 config: ZBAR_CFG_ENABLE to:0];
	
    [self presentModalViewController:reader animated:YES];
    [reader release];
}

- (void)imagePickerController:(UIImagePickerController*)reader didFinishPickingMediaWithInfo:(NSDictionary*)info
{
    id<NSFastEnumeration> results = [info objectForKey:ZBarReaderControllerResults];

    ZBarSymbol *symbol = nil;
    for(symbol in results)
        break;
	
    [reader dismissModalViewControllerAnimated: YES];

	NSString *code = [symbol.data stringByReplacingOccurrencesOfString:@"'" withString:@"\'"];
	NSString *js = [NSString stringWithFormat:@"var e = document.createEvent('Events');e.initEvent('appMobi.device.barcode.scan',true,true);e.success=true;e.codetype='%@';e.codedata='%@';document.dispatchEvent(e);", symbol.typeName, code];
	AMLog(@"%@",js);
	[self internalInjectJS:js];	
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)reader
{
    [reader dismissModalViewControllerAnimated: YES];

	NSString *js = [NSString stringWithFormat:@"var e = document.createEvent('Events');e.initEvent('appMobi.device.barcode.scan',true,true);e.success=false;e.codetype='';e.codedata='';document.dispatchEvent(e);"];
	AMLog(@"%@",js);
	[self internalInjectJS:js];		
}

- (void)closeActiveTab:(id)sender
{
	if( [[AppMobiDelegate sharedDelegate] isWebContainer] == YES )
	{
		UIButton *tabx = [tabDels objectAtIndex:curTab];
		[self onDelTab:tabx];
	}
}

- (void)startManifestCaching:(id)sender
{
    [self placeManifestBlocker:nil];
    appUpdateBlocker.hidden = NO;
    appUpdateMessage.hidden = NO;
	appUpdateSpinner.hidden = NO;
	[appUpdateSpinner startAnimating];
}

- (void)endManifestCaching:(id)sender
{
	appUpdateBlocker.hidden = YES;
    appUpdateMessage.hidden = YES;
	appUpdateSpinner.hidden = YES;
	[appUpdateSpinner stopAnimating];
}

- (void)onRemoteClose:(id)sender
{
	[remoteView loadHTMLString:@"" baseURL:[NSURL URLWithString:@"about:blank"]];
	remoteView.hidden = YES;
	remoteClose.hidden = YES;
	[self fireEvent:@"appMobi.device.remote.close"];
}

- (void)onRichClose:(id)sender
{
	NSString *richpath = [webView.config.appDirectory stringByAppendingPathComponent:@"rich_message_index.html"];
	if( YES == [[NSFileManager defaultManager] fileExistsAtPath:richpath] ) [[NSFileManager defaultManager] removeItemAtPath:richpath error:nil];

	[richView loadHTMLString:@"" baseURL:[NSURL URLWithString:@"about:blank"]];
	richView.hidden = YES;
	richClose.hidden = YES;
	richSplash.hidden = YES;
	richMessage.hidden = YES;
	richSpinner.hidden = YES;
	[richSpinner stopAnimating];
	bRichShowing = NO;
	
	NSString *js = [NSString stringWithFormat:@"var e = document.createEvent('Events');e.initEvent('appMobi.notification.push.rich.close',true,true);e.success=true;e.id='%@';document.dispatchEvent(e);", lastRich];
	AMLog(@"%@",js);
	[self internalInjectJS:js];
	
	if( bPushShowing == YES && pushConfig != nil )
	{
		//[pushNote readPushNotifications:[NSMutableArray arrayWithObject:lastRich] withDict:nil];
		[self showPushViewer:pushConfig forNotification:pushNote];
	}
	[lastRich release];
}

- (void)viewDidLoad {
	AMLog(@"viewDidLoad");
}

- (void)viewDidUnload {
	AMLog(@"viewDidUnload");
	playerViewWasHidden = playerView.hidden;
	remoteViewWasHidden = remoteView.hidden;
	richViewWasHidden = richView.hidden;
	adfullViewWasHidden = adfullView.hidden;
	mobiusIsRestarting = YES;
	webViewRequest = webView.request;
	webView = nil;
	[AppMobiDelegate sharedDelegate].webView = nil;
}

- (void)viewDidAppear:(BOOL)animated {
	AMLog(@"viewDidAppear");
}

-(void)didReceiveMemoryWarning{
	NSLog(@"received memory warning in VC");
}

@end

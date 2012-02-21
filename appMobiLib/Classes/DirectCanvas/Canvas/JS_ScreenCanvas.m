#import "JS_ScreenCanvas.h"
#import <QuartzCore/CABase.h>

@implementation JS_ScreenCanvas

extern EAGLContext * CanvasGlobalGLContext;
extern JS_Canvas * CanvasCurrentInstance;
int currentRotation = 0;

- (void) setglDimentions {
    // NSLog(@"-------> ScreenCanvas: setting gl dimentions. Width = %f, height = %f", viewWidth, viewHeight);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrthof(0, width*scale, height*scale, 0, -1, 1);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glScalef(scale, scale, 1);
}


- (id)initWithContext:(JSContextRef)ctx object:(JSObjectRef)obj argc:(size_t)argc argv:(const JSValueRef [])argv {
    self  = [super initWithContext:ctx object:obj argc:argc argv:argv];
	if( self ) {
		width = argc>0?JSValueToNumber(ctx, argv[0], NULL):[UIScreen mainScreen].currentMode.size.width;
		height = argc>1?JSValueToNumber(ctx, argv[1], NULL):[UIScreen mainScreen].currentMode.size.height - ([DirectCanvas statusBarHidden] ? 0 : 20);
		scale = argc>2?JSValueToNumber(ctx, argv[2], NULL):[UIScreen mainScreen].scale;
		//do not use device scale - was causing double scaling on retina display devices
		scale = 1;
		requestedScale = 1;
		inverted = TRUE;
		
		NSLog(@"CanvasScreenContext: init %d, %d, %f", width, height, scale);
		
		landscapeMode = [DirectCanvas landscapeMode];

		if( landscapeMode ) {
			orientation = UIDeviceOrientationLandscapeRight;
		}
		else {
			orientation = UIDeviceOrientationPortrait;
		}
		
		[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(orientationChange:)
													 name:@"UIDeviceOrientationDidChangeNotification" object:nil];
		
		glview = [[[EAGLView alloc] initWithFrame:CGRectMake(0, 0, width*scale, height*scale)] retain];
		NSLog(@"[glview retainCount]:%d", [glview retainCount]);

		[glview setContext:CanvasGlobalGLContext];
		[glview setFramebuffer];


		[self setglDimentionsWithWidth:width Height:height Scale:scale];
        
		if( landscapeMode && currentRotation!=90) {
			currentRotation = 90;
			glRotatef( 90, 0, 0, 1 );
			glTranslatef(0, -height, 0);
		}
		
		glDisable(GL_CULL_FACE);
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		//testing glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA); // use separate functions, make alpha per canvas spec
		glEnable(GL_TEXTURE_2D);
		
		[[DirectCanvas instance] addSubview:glview];
		
        lock = [[NSLock alloc] init];
	}
	return self;
}


- (void)dealloc {
	[lock release];
    if(timer!=nil) [timer invalidate];	
	NSLog(@"[glview retainCount]:%d", [glview retainCount]);
	[glview removeFromSuperview];
	[glview release];
	NSLog(@"[glview retainCount]:%d", [glview retainCount]);
	[super dealloc];
}


- (void)setFrameBuffer {
	[glview setFramebuffer];
}


- (void)prepareThisCanvas {
    
    [glview deleteFramebuffer];  // so it'll be recreated
    [self setFrameBuffer];
    [self setglDimentionsWithWidth:width Height:height Scale:scale];

	// path api 
	if( !canvasPath ) {
		//canvasPath = [[CanvasPath alloc] initWithWidth:width height:height];
	}
	
    [self setglDimentionsWithWidth:width Height:height Scale:scale];
    //NSLog(@"JS_ScreenCanvas: PrepareThisCanvas %d", height);
	
	//we entered here 2x, causing an extra rotation
//	if( orientation == UIDeviceOrientationLandscapeLeft && currentRotation!=90) {
//		currentRotation = 90;
//		glRotatef( 90, 0, 0, 1 );
//		glTranslatef(0, -height, 0);
//	}
//	else if( orientation == UIDeviceOrientationLandscapeRight && currentRotation!=-90) {
//		currentRotation = -90;
//		glRotatef( -90, 0, 0, 1 );
//		glTranslatef( -width, 0, 0);
//	}
}


- (void)orientationChange:(NSNotification *)notification {	
	UIDeviceOrientation newOrientation = [[UIDevice currentDevice] orientation];
	if( newOrientation != orientation && UIDeviceOrientationIsLandscape(newOrientation) ) {
		orientation = newOrientation;
		/*
		 //from iOSImpact-0.9
		 UIInterfaceOrientation interfaceOrientation;
		 interfaceOrientation = ((orientation == UIDeviceOrientationLandscapeLeft) ?
		 UIInterfaceOrientationLandscapeRight : UIInterfaceOrientationLandscapeLeft);
		 
		 [UIApplication sharedApplication].statusBarOrientation = interfaceOrientation;
		*/
		if( CanvasCurrentInstance == self ) {
			[self prepareThisCanvas];
		}
	}
	[self doScale:requestedScale]; 
}

JS_FUNC(JS_ScreenCanvas, setFPS, ctx, argc, argv) {
	if( argc < 1 || !JSValueIsNumber(ctx, argv[0]) ) return NULL;
	
	float fps = JSValueToNumber(ctx, argv[0], NULL);

	[self performSelectorOnMainThread:@selector(setFPS:) withObject:[NSNumber numberWithInt:fps] waitUntilDone:NO];

	return NULL;
}

int userInfo = 0;
-(void)setFPS:(NSNumber*)fps {
	if(timer!=nil) {
		[timer invalidate];
	}
	NSTimeInterval interval = (double)1.0/[fps doubleValue];
	timer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(autoPresent:) userInfo:[NSNumber numberWithInt:userInfo++] repeats:YES];
}

double lastTime = 0;
double accumulatedTime = 0;
double counter = 0;
-(void)autoPresent:(NSTimer*)timer {
    BOOL didPresent = [self present];
    
    //only update stats if presented
    if(didPresent) {
        //calculate real fps, update last time
        double currentTime = CACurrentMediaTime(); 
        double delta = currentTime - lastTime;
        accumulatedTime += delta;
        counter++;
        lastTime = currentTime; 

        if(accumulatedTime>=1.0) {
            //inject real fps
            NSString* js = [NSString stringWithFormat:@"AppMobi.updateFPS(%d);", (int)(counter/accumulatedTime)];
            [[DirectCanvas instance] injectJSFromString:js];
            accumulatedTime = 0;
            counter = 0;
        }
    }
}

-(BOOL)present {
    if([lock tryLock]) {
        [self flushBuffers:TRUE];
        if(glview!=nil) {
            [glview presentFramebuffer];            
        }
        drawCalls = 0;
        [lock unlock];
        return YES;
    } else {
        return NO;
    }
}

JS_FUNC(JS_ScreenCanvas, present, ctx, argc, argv) {
    [self present];
	return NULL;
}

JS_FUNC(JS_ScreenCanvas, detach, ctx, argc, argv) {
	if(timer!=nil) [timer invalidate];
	timer = nil;
	[glview removeFromSuperview];
	[glview release];
	return NULL;
}

JS_GET(JS_Canvas, globalScale, ctx) {
	return JSValueMakeNumber(ctx, scale);
}

- (void)doScale:(float)gScale {
	requestedScale = gScale;
    
	//calculate scale based on content width/height vs. display width/height
	CGFloat deviceWidth, deviceHeight;//480, 300
	if([[UIScreen mainScreen] applicationFrame].size.height<deviceHeight < [[UIScreen mainScreen] applicationFrame].size.width) {//landscape
		deviceWidth = [[UIScreen mainScreen] applicationFrame].size.height;
		deviceHeight = [[UIScreen mainScreen] applicationFrame].size.width;
	} else {
		deviceWidth = [[UIScreen mainScreen] applicationFrame].size.width;
		deviceHeight = [[UIScreen mainScreen] applicationFrame].size.height;
	}
	
	double calcScaleX = deviceWidth/(width*scale), calcScaleY = deviceHeight/(height*scale), calcScale;
	calcScale = MIN(calcScaleX, calcScaleY);
    calculatedScale = calcScale;
	
    //calculate frame offset
    int offsetX = (deviceWidth-(width*scale))/2, offsetY = (deviceHeight-(height*scale))/2;
    //[glview removeFromSuperview];
    if( calculatedScale > 1.0 ) glview.transform = CGAffineTransformIdentity;
    glview.frame = CGRectMake(offsetX, offsetY, (width*scale), (height*scale));
    glview.transform = CGAffineTransformMakeScale(calculatedScale, calculatedScale);
    //[[DirectCanvas instance] addSubview:glview];
}
	 
JS_SET(JS_Canvas, globalScale, ctx, value) {
	float gScale = JSValueToNumber(ctx, value, NULL);
	requestedScale = gScale;
	[self doScale:gScale];
}


@end

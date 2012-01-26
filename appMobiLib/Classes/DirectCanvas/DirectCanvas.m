#import "DirectCanvas.h"
#import "JS_BaseClass.h"
#import <objc/runtime.h>
#import "AppMobiDelegate.h"
#import "AppMobiWebView.h"
#import "AppMobiViewController.h"
#import "AppConfig.h"

@class JS_Texture;

JSClassRef directCanvas_constructorClass;


NSString * JSValueToNSString( JSContextRef ctx, JSValueRef v ) {
	JSStringRef jsString = JSValueToStringCopy( ctx, v, NULL );
	if( !jsString ) return nil;
	
	NSString * string = (NSString *)JSStringCopyCFString( kCFAllocatorDefault, jsString );
	[string autorelease];
	JSStringRelease( jsString );
	
	return string;
}

double JSValueToNumberFast( JSContextRef ctx, JSValueRef v ) {
	unsigned char * bytes = ((unsigned char *) v) + 8;
	unsigned char * tagBytes = ((unsigned char *) v) + 12;
	int32_t unionTag = *((int32_t*)tagBytes);
	if( unionTag < 0xfffffff8 ) {
		return *((double *) bytes);
	}
	else {
		return *((int32_t *) bytes);
	}
}

JSValueRef directCanvas_getNativeClass(JSContextRef ctx, JSObjectRef object, JSStringRef propertyNameJS, JSValueRef* exception) {
    //handle props assigned in script
    JSPropertyNameArrayRef props = JSObjectCopyPropertyNames(ctx, object);
    size_t count = JSPropertyNameArrayGetCount(props);
    //loop over property names
    for(int i=0;i<count;i++) {
        JSStringRef name = JSPropertyNameArrayGetNameAtIndex(props,i);
        if(JSStringIsEqual(propertyNameJS, name)) {
            //if there is a match, return NULL to make default behavior happen
            return NULL;
        }
    }
    
	CFStringRef className = JSStringCopyCFString( kCFAllocatorDefault, propertyNameJS );
	JSObjectRef obj = NULL;
	NSString * fullClassName = [NSString stringWithFormat:@"JS_%@", className];
	id class = NSClassFromString(fullClassName);
	if( class ) {
		obj = JSObjectMake( ctx, directCanvas_constructorClass, (void *)class );
	}
	
	CFRelease(className);
	return obj ? obj : JSValueMakeUndefined(ctx);
}

JSObjectRef directCanvas_callAsConstructor(JSContextRef ctx, JSObjectRef constructor, size_t argc, const JSValueRef argv[], JSValueRef* exception) {
	id class = (id)JSObjectGetPrivate( constructor );
	
	JSClassRef jsClass = [[DirectCanvas instance] getJSClassForClass:class];
	JSObjectRef obj = JSObjectMake( ctx, jsClass, NULL );
	
	id instance = [(JS_BaseClass *)[class alloc] initWithContext:ctx object:obj argc:argc argv:argv];
	JSObjectSetPrivate( obj, (void *)instance );
    
	return obj;
}

@implementation DirectCanvas
@synthesize ctx;
@synthesize window;
@synthesize touchDelegate;
@synthesize remotePath;

static DirectCanvas * directCanvasInstance = NULL;
static BOOL isLandscapeMode = NO;

+ (DirectCanvas *)instance {
	return directCanvasInstance;
}

+ (JSObjectRef)copyConstructor:(JSContextRef)ctx forClass:(id)objc_class withCopy:(void *)internal shouldDelete:(BOOL)delflag
{
	JSClassRef jsClass = [[DirectCanvas instance] getJSClassForClass:objc_class];
	JSObjectRef obj = JSObjectMake( ctx, jsClass, NULL );
	
	id instance = [(JS_BaseClass *)[objc_class alloc] initWithCopy:internal context:ctx object:obj shouldDelete:delflag];
	JSObjectSetPrivate( obj, (void *)instance );
    
	return obj;
}

- (id)initWithView:(UIView *)view andFrame:(CGRect)rect{
    self = [super init];
	if( self ) {
		directCanvasInstance = self;
		window = [view window];
		self.frame = rect;
		[view insertSubview:self atIndex:0];
	}

	// Create the global JS context and attach the '_native' object
	jsClasses = [[NSMutableDictionary alloc] init];
	
	JSClassDefinition constructorClassDef = kJSClassDefinitionEmpty;
	constructorClassDef.callAsConstructor = directCanvas_callAsConstructor;
	directCanvas_constructorClass = JSClassCreate(&constructorClassDef);
	
	JSClassDefinition globalClassDef = kJSClassDefinitionEmpty;
	globalClassDef.getProperty = directCanvas_getNativeClass;		
	JSClassRef globalClass = JSClassCreate(&globalClassDef);
	
	ctx = JSGlobalContextCreate(NULL);
	JSObjectRef globalObject = JSContextGetGlobalObject(ctx);
	
	JSObjectRef iosObject = JSObjectMake( ctx, globalClass, NULL );
	JSObjectSetProperty(
		ctx, globalObject, 
		JSStringCreateWithUTF8CString("_native"), iosObject, 
		kJSPropertyAttributeDontDelete | kJSPropertyAttributeReadOnly, NULL
	);

	// temp workaround to avoid crash on older OS .. direct canvas won't work .. need bigger plan
	if( [[UIScreen mainScreen] respondsToSelector:@selector(scale)] == YES )
	{	
		NSString* canvasDotJs = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"canvas" ofType:@"js"] encoding:NSUTF8StringEncoding error:NULL];
		[self injectJSFromString:canvasDotJs];
	}
	
	// inject box2d to initialize box2d objects
	NSString* box2DDotJs = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"box2D" ofType:@"js"] encoding:NSUTF8StringEncoding error:NULL];
	[self injectJSFromString:box2DDotJs];
	
	return self;
}

-(void)load:(NSString *) javascriptPath {
    [self loadScriptAtPath:javascriptPath];
}

//new for Mobius, possibly temp
-(void)load2:(NSString *) javascriptPath atPath:(NSString *) path {
    remotePath = [path retain];
    [self loadScriptAtPath2:javascriptPath];	
}

-(void)show {
	//show
	self.hidden = NO;
	//invoke javascript callback
	NSString *js = [NSString stringWithFormat:@"AppMobi.wasShown();"];
	[self injectJSFromString:js];
}

-(void)hide {
	//invoke javascript callback
	NSString *js = [NSString stringWithFormat:@"AppMobi.willBeHidden();"];
	[self injectJSFromString:js];
	//hide
	self.hidden = YES;
}

- (void)hideLoadingScreen {
	[loadingScreen removeFromSuperview];
	[loadingScreen release];
}


- (JSClassRef)getJSClassForClass:(id)classId {
	JSClassRef jsClass = [[jsClasses objectForKey:classId] pointerValue];
	
	// Not already loaded? Ask the objc class for the JSClassRef!
	if( !jsClass ) {
		jsClass = [classId getJSClass];
		[jsClasses setObject:[NSValue valueWithPointer:jsClass] forKey:classId];
	}
	return jsClass;
}

- (void)loadScriptAtPath:(NSString *)path {
	NSLog(@"Loading Script: %@", path );
    NSString *fullPath = [DirectCanvas pathForResource:path];
    if( remotePath!=nil && [[NSFileManager defaultManager] fileExistsAtPath:fullPath] == NO ) {
        return [self loadScriptAtPath2:path];
    }
    
	NSString *script = [NSString stringWithContentsOfFile:fullPath encoding:NSUTF8StringEncoding error:NULL];
	if( !script ) {
		NSLog(@"Can't load Script: %@", path );
		return;
	}
	
	JSStringRef scriptJS = JSStringCreateWithCFString((CFStringRef)script);
	JSStringRef pathJS = JSStringCreateWithCFString((CFStringRef)path);
	
	JSValueRef exception = NULL;
	JSEvaluateScript( ctx, scriptJS, NULL, pathJS, 0, &exception );
	[self logException:exception ctx:ctx];
	
	JSStringRelease( scriptJS );
}

- (void)loadScriptAtPath2:(NSString *)relativePath {
    NSString * path = [NSString stringWithFormat:@"%@/%@", remotePath, relativePath];
	NSString * script = [NSString stringWithContentsOfURL:[NSURL URLWithString:path] encoding:NSUTF8StringEncoding error:NULL];	
    
	if( !script ) {
		NSLog(@"Can't load Script: %@", path );
		return;
	}
	
	NSLog(@"Loading Script: %@", path );
	JSStringRef scriptJS = JSStringCreateWithCFString((CFStringRef)script);
	JSStringRef pathJS = JSStringCreateWithCFString((CFStringRef)path);
	
	JSValueRef exception = NULL;
	JSEvaluateScript( ctx, scriptJS, NULL, pathJS, 0, &exception );
	[self logException:exception ctx:ctx];
	
	JSStringRelease( scriptJS );
}

- (void)injectJSFromString:(NSString *)script {
	
	//NSLog(@"Injecting Script: %@", script );
	JSStringRef scriptJS = JSStringCreateWithCFString((CFStringRef)script);
	
	JSValueRef exception = NULL;
	JSEvaluateScript( ctx, scriptJS, NULL, NULL, 0, &exception );
	[self logException:exception ctx:ctx];
	
	JSStringRelease( scriptJS );
}

- (void)executeJavascriptInWebView:(NSString *)script {
	[[[AppMobiViewController masterViewController] getActiveWebView] injectJS:script];
}

- (JSValueRef)invokeCallback:(JSObjectRef)callback thisObject:(JSObjectRef)thisObject argc:(size_t)argc argv:(const JSValueRef [])argv {
	JSValueRef exception = NULL;
	JSValueRef result = JSObjectCallAsFunction( ctx, callback, thisObject, argc, argv, &exception );
	[self logException:exception ctx:ctx];
	return result;
}


- (void)logException:(JSValueRef)exception ctx:(JSContextRef)ctxp {
	if( !exception ) return;
	
	JSStringRef jsLinePropertyName = JSStringCreateWithUTF8CString("line");
	JSStringRef jsFilePropertyName = JSStringCreateWithUTF8CString("sourceURL");
	
	JSObjectRef exObject = JSValueToObject( ctxp, exception, NULL );
	JSValueRef line = JSObjectGetProperty( ctxp, exObject, jsLinePropertyName, NULL );
	JSValueRef file = JSObjectGetProperty( ctxp, exObject, jsFilePropertyName, NULL );
	
	NSLog( 
		@"%@ at line %@ in %@", 
		JSValueToNSString( ctxp, exception ),
		JSValueToNSString( ctxp, line ),
		JSValueToNSString( ctxp, file )
	);
	
	JSStringRelease( jsLinePropertyName );
	JSStringRelease( jsFilePropertyName );
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	if( touchDelegate ) {
		[touchDelegate touchesBegan:touches withEvent:event];
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	if( touchDelegate ) {
		[touchDelegate touchesEnded:touches withEvent:event];
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	if( touchDelegate ) {
		[touchDelegate touchesMoved:touches withEvent:event];
	}
}

- (void)dealloc {
	JSObjectRef globalObject = JSContextGetGlobalObject(ctx);
	JSObjectDeleteProperty(ctx, globalObject, JSStringCreateWithUTF8CString("_native"), NULL);        

	JSGlobalContextRelease(ctx);
	[touchDelegate release];
	[jsClasses release];
    
    if (remotePath != nil) {
        [remotePath release];
    }
	[super dealloc];
}

+ (NSString *)pathForResource:(NSString *)path {
	//return [NSString stringWithFormat:@"%@/" DIRECTCANVAS_GAME_FOLDER "%@", [[NSBundle mainBundle] resourcePath], path];    
    NSString *fullPath = [NSString stringWithFormat:@"%@/%@", [[AppMobiViewController masterViewController] getActiveWebView].config.appDirectory, path];
    if( [DirectCanvas instance].remotePath != nil && [[NSFileManager defaultManager] fileExistsAtPath:fullPath] == NO )
    {
        
        fullPath = [NSString stringWithFormat:@"%@/%@", [DirectCanvas instance].remotePath, path];
    }
    
	return fullPath;
}

+ (BOOL)landscapeMode {
	return isLandscapeMode;
	
    /*
     return [[[[NSBundle mainBundle] infoDictionary] 
     objectForKey:@"UIInterfaceOrientation"] hasPrefix:@"UIInterfaceOrientationLandscape"];
     */
}

+ (void)setLandscapeMode:(BOOL)mode {
	isLandscapeMode = mode;
	
    /*
     return [[[[NSBundle mainBundle] infoDictionary] 
     objectForKey:@"UIInterfaceOrientation"] hasPrefix:@"UIInterfaceOrientationLandscape"];
     */
}

+ (BOOL)statusBarHidden {
	return [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"UIStatusBarHidden"] boolValue];
}

@end

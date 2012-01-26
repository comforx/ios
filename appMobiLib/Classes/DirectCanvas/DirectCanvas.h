#import <Foundation/Foundation.h>
#import "JavaScriptCore/JavaScriptCore.h"

#define DIRECTCANVAS_GAME_FOLDER @"game/"

#define DIRECTCANVAS_DEBUG_BOOT_JS @"ios-impact.js"
#define DIRECTCANVAS_DEBUG_MAIN_JS @"index.js"
#define DIRECTCANVAS_RELEASE_MASTER_JS @"game.min.js"

NSString * JSValueToNSString( JSContextRef ctx, JSValueRef v );
double JSValueToNumberFast( JSContextRef ctx, JSValueRef v );

@protocol TouchDelegate
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
@end

@interface DirectCanvas : UIView {
	JSGlobalContextRef ctx;
	UIWindow * window;
	NSMutableDictionary * jsClasses;
	UIImageView * loadingScreen;
	NSObject<TouchDelegate> * touchDelegate;
    NSString * remotePath;
}

- (id)initWithView:(UIView *)view andFrame:(CGRect)rect;

- (JSClassRef)getJSClassForClass:(id)classId;
- (void)hideLoadingScreen;
- (void)loadScriptAtPath:(NSString *)path;
- (void)loadScriptAtPath2:(NSString *)path;
- (JSValueRef)invokeCallback:(JSObjectRef)callback thisObject:(JSObjectRef)thisObject argc:(size_t)argc argv:(const JSValueRef [])argv;
- (void)logException:(JSValueRef)exception ctx:(JSContextRef)ctxp;
- (void)load:(NSString *)javascriptPath;
- (void)load2:(NSString *)javascriptPath atPath:(NSString *)path;
- (void)show;
- (void)hide;
- (void)injectJSFromString:(NSString *)script;
- (void)executeJavascriptInWebView:(NSString *)script;

+ (DirectCanvas *)instance;
+ (JSObjectRef)copyConstructor:(JSContextRef)ctx forClass:(id)objc_class withCopy:(void *)internal shouldDelete:(BOOL)delflag;
+ (NSString *)pathForResource:(NSString *)resourcePath;
+ (BOOL)landscapeMode;
+ (void)setLandscapeMode:(BOOL)mode;
+ (BOOL)statusBarHidden;

@property (readonly) JSGlobalContextRef ctx;
@property (readonly) UIWindow * window;
@property (nonatomic,retain) NSObject<TouchDelegate> * touchDelegate;
@property (readonly) NSString * remotePath;

@end

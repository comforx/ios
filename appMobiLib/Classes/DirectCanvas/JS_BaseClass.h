#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "DirectCanvas.h"


// WOHOOOO, this a HUGE mess... But it works \o/

// All classes derived from this JS_BaseClass will return a JSClassRef, describing all
// the class' methods. Properties and Functions are defined through the 
// 'staticFunctions' and 'staticValues' of the JSClassRef. Since these functions don't
// have extra data (e.g. a void*), we have to define one C callback function per function,
// per getter and per setter.
// Furthermore, a class method is added to the objc class that returns the function pointer
// to the particular C callback function - this way we can later inflect the objc class
// and gather all function pointers.

id objc_msgSend(id theReceiver, SEL theSelector, ...);

// Function - use with JS_FUNC( JS_ClassName, functName, ctx, argc, argv ) { ... }
#define JS_FUNC(CLASS, NAME, CTX_NAME, ARGC_NAME, ARGV_NAME) \
JSValueRef _##CLASS##_func_##NAME(JSContextRef ctx, JSObjectRef function, JSObjectRef object, size_t argc, const JSValueRef argv[], JSValueRef* exception) {\
	JSValueRef ret = (JSValueRef)objc_msgSend((CLASS *)JSObjectGetPrivate(object), @selector(_func_##NAME:argc:argv:), ctx, argc, argv);\
	return ret ? ret : JSValueMakeUndefined(ctx);\
}\
+ (JSObjectCallAsFunctionCallback)_callback_for_func_##NAME { return (JSObjectCallAsFunctionCallback)&_##CLASS##_func_##NAME; }\
- (JSValueRef)_func_##NAME:(JSContextRef)CTX_NAME argc:(size_t)ARGC_NAME argv:(const JSValueRef [])ARGV_NAME

// Getter - use with JS_GET( JS_ClassName, propertyName, ctx ) { ... }
#define JS_GET(CLASS, NAME, CTX_NAME) \
JSValueRef _##CLASS##_get_##NAME(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef* exception) {\
	return (JSValueRef)objc_msgSend((CLASS *)JSObjectGetPrivate(object), @selector(_get_##NAME:), ctx);\
}\
+ (JSObjectGetPropertyCallback)_callback_for_get_##NAME { return (JSObjectGetPropertyCallback)&_##CLASS##_get_##NAME; }\
- (JSValueRef)_get_##NAME:(JSContextRef)CTX_NAME

// Getter - use with JS_SET( JS_ClassName, propertyName, ctx, value ) { ... }
#define JS_SET(CLASS, NAME, CTX_NAME, VALUE_NAME) \
bool _##CLASS##_set_##NAME(JSContextRef ctx, JSObjectRef object, JSStringRef propertyName, JSValueRef value, JSValueRef* exception) {\
	objc_msgSend((CLASS *)JSObjectGetPrivate(object), @selector(_set_##NAME:value:), ctx, value);\
	return true;\
}\
+ (JSObjectSetPropertyCallback)_callback_for_set_##NAME { return (JSObjectSetPropertyCallback)&_##CLASS##_set_##NAME; }\
- (void)_set_##NAME:(JSContextRef)CTX_NAME value:(JSValueRef)VALUE_NAME



@interface JS_BaseClass : NSObject {
	JSContextRef objectCtx;
	JSObjectRef object;
	BOOL shouldDelete;
}

- (id)initWithCopy:(void *)internal context:(JSContextRef)ctxp object:(JSObjectRef)obj shouldDelete:(BOOL)delflag;
- (id)initWithContext:(JSContextRef)ctxp object:(JSObjectRef)obj argc:(size_t)argc argv:(const JSValueRef [])argv;
- (void)postInit:(JSContextRef)ctx object:(JSObjectRef)obj argc:(size_t)argc argv:(const JSValueRef [])argv;
+ (JSClassRef)getJSClass;

@end

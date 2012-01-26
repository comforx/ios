#import "JS_Audio.h"


@implementation JS_Audio

- (id)initWithContext:(JSContextRef)ctx object:(JSObjectRef)obj argc:(size_t)argc argv:(const JSValueRef [])argv {
	if( self = [super initWithContext:ctx object:obj argc:argc argv:argv] ) {
		volume = 1;
		
		
		if( argc < 1 ) return self; // Maybe just a dummy for canPlayType?
		
		path = [JSValueToNSString(ctx, argv[0]) retain];
			
		// Decide whether to load the sound as OpenAL or AVAudioPlayer source
		NSString * fullPath = [DirectCanvas pathForResource:path];
		unsigned long long size = [[[NSFileManager defaultManager] 
			attributesOfItemAtPath:fullPath error:nil] fileSize];
			
		if( size <= JS_AUDIO_OPENAL_MAX_SIZE ) {
			//NSLog(@"Loading Sound(OpenAL): %@", path);
			source = [[OpenALSource alloc] initWithPath:fullPath];
		}
		else {
			//NSLog(@"Loading Sound(AVAudio): %@", path);
			source = [[AVAudioPlayerSource alloc] initWithPath:fullPath];
		}
			
	}
	return self;
}


JS_FUNC(JS_Audio, play, ctx, argc, argv) {
	[source play];
	return NULL;
}


JS_FUNC(JS_Audio, pause, ctx, argc, argv) {
	[source pause];
	return NULL;
}


JS_FUNC(JS_Audio, load, ctx, argc, argv) {
	[source load];
	return NULL;
}


JS_FUNC(JS_Audio, canPlayType, ctx, argc, argv) {
	if( argc != 1 ) return NULL;
	
	NSString * mime = JSValueToNSString(ctx, argv[0]);
	if( [mime hasPrefix:@"audio/x-caf"] ) {
		JSStringRef jsMime = JSStringCreateWithUTF8CString("probably");
		JSValueRef ret = JSValueMakeString(ctx, jsMime );
		JSStringRelease(jsMime);
		return ret;
	}
	return NULL;
}


JS_FUNC(JS_Audio, addEventListener, ctx, argc, argv) {
	// FIXME: stub
	if( argc != 3 ) return NULL;
	
	NSString * type = JSValueToNSString(ctx, argv[0]);
	if( ![type isEqualToString:@"canplaythrough"] ) return NULL;
	
	JSObjectRef func = JSValueToObject(ctx, argv[1], NULL);
	[[DirectCanvas instance] invokeCallback:func thisObject:object argc:0 argv:NULL];
	
	return NULL;
}


JS_FUNC(JS_Audio, removeEventListener, ctx, argc, argv) {
	return NULL; // FIXME: stub
}


JS_GET(JS_Audio, loop, ctx) {
	return JSValueMakeBoolean( ctx, loop );
}

JS_SET(JS_Audio, loop, ctx, value) {
	loop = JSValueToBoolean(ctx, value);
	[source setLooping:loop];
}


JS_GET(JS_Audio, volume, ctx) {
	return JSValueMakeNumber( ctx, volume );
}

JS_SET(JS_Audio, volume, ctx, value) {
	volume = JSValueToNumberFast(ctx, value);
	[source setVolume:MIN(1,MAX(volume,0))];
}

JS_GET(JS_Audio, currentTime, ctx) {
	return JSValueMakeNumber( ctx, [source getCurrentTime] );
}

JS_SET(JS_Audio, currentTime, ctx, value) {
	float time = JSValueToNumberFast(ctx, value);
	[source setCurrentTime:time];
}


- (void)dealloc {
	[source release];
	[path release];
	
	[super dealloc];
}

@end

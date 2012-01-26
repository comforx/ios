#import <Foundation/Foundation.h>

#import <OpenAL/al.h>
#import <OpenAL/alc.h>

@interface OpenALManager : NSObject {
	ALCcontext * context;
	ALCdevice * device;
	NSMutableDictionary *buffers;
}

+ (OpenALManager *)instance;

@property (readonly) NSMutableDictionary * buffers;

@end

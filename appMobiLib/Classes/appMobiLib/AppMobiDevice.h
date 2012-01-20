
#import <UIKit/UIKit.h>
#import <UIKit/UIDevice.h>
#import "AppMobiCommand.h"

@interface AppMobiDevice : AppMobiCommand {
	NSString *connection;
	NSArray *whiteList;
	BOOL fireEvent;
	BOOL shouldBlock;
}

- (void)fireGetConnection:(id)sender;
- (NSDictionary*) deviceProperties;
- (NSString *)getConnection;

@property (nonatomic, readonly) BOOL shouldBlock;
@property (nonatomic, readonly) NSArray *whiteList;

- (void)managePower:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)setAutoRotate:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)setRotateOrientation:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)updateConnection:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)registerLibrary:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)launchExternal:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)getRemoteData:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)getRemoteDataExt:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)showRemoteSite:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)closeRemoteSite:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)blockRemotePages:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)scanBarcode:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)installUpdate:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)hideSplashScreen:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)closeTab:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)startManifestCaching:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)endManifestCaching:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
- (void)mainViewExecute:(NSMutableArray*)arguments withDict:(NSMutableDictionary*)options;
@end

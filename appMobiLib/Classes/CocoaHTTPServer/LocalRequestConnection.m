//
//  LocalRequestConnection.m
//  appMobiLib
//

//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "LocalRequestConnection.h"
#import "AsyncSocket.h"

// Define the various timeouts (in seconds) for various parts of the HTTP process
#define WRITE_ERROR_TIMEOUT   30

// Define the various tags we'll use to differentiate what it is we're currently doing
#define HTTP_FINAL_RESPONSE                45

@implementation LocalRequestConnection

- (void)replyToHTTPRequest
{
	// Check headers to get host
	NSDictionary *headers = [NSMakeCollectable(CFHTTPMessageCopyAllHeaderFields(request)) autorelease];
	NSString *host = [headers objectForKey:@"Host"];
	
	//only accept requests from localhost
	if (host==nil || ( [host hasPrefix:@"localhost"] == NO && [host hasPrefix:@"127.0.0.1"] == NO ) ) {
		NSLog(@"HTTP Server: Error 403 - Forbidden");
		
		// Status Code 403 - Forbidden
		CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 403, NULL, kCFHTTPVersion1_1);
		CFHTTPMessageSetHeaderFieldValue(response, CFSTR("Content-Length"), CFSTR("0"));
		
		NSData *responseData = [self preprocessErrorResponse:response];
		[asyncSocket writeData:responseData withTimeout:WRITE_ERROR_TIMEOUT tag:HTTP_FINAL_RESPONSE];
		
		CFRelease(response);
	} else {
		[super replyToHTTPRequest];
	}

}
			 
@end

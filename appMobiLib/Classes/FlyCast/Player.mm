
#import "Player.h"
#import "PlayingView.h"
#import "XMLTracklist.h"
#import "XMLTrack.h"
#import "XMLNode.h"
#import "Packet.h"
#import "Buffer.h"
#import "Data.h"
#import "CachedAd.h"
#import "BusyView.h"

#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioFile.h>
#import <CoreFoundation/CFUrl.h>
#import <CFNetwork/CFNetwork.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioFileStream.h>
#include <pthread.h>

const unsigned int AUDIO_QUEUE_BUFFER_COUNT = 4;
const unsigned int AUDIO_QUEUE_BUFFER_SIZE  = 4096;//32 * 128;
const unsigned int AUDIO_QUEUE_PACKET_DESCS = 128;
const unsigned int DATA_QUEUE_BUFFER_SIZE   = 4096;//16384;//128 * 128;

NSString *strBaseDir = nil;
NSString *strUIDN = nil;

struct AQTestInfo
{
	AudioFileStreamID mAudioFileStream;
	AudioStreamBasicDescription mDataFormat;
	AudioQueueBufferRef mAudioBuffers[AUDIO_QUEUE_BUFFER_COUNT];
	AudioStreamPacketDescription mPacketDescs[AUDIO_QUEUE_PACKET_DESCS];
	AudioQueueRef mQueue;
	AudioQueueBufferRef mCurrentBuffer;
	//Data *mCurrentData;
	size_t mBytesCached;
	size_t mBytesFilled;
	size_t mBytesPlayed;
	size_t mPacketsFilled;
	UInt32 mPacketCount;
	UInt32 mPacketsReady;
	UInt32 mBytesQueued;
	UInt32 mLastOffset;
	UInt32 mConnOffset;
	UInt32 mTotalLength;
	UInt32 mCachedByte;
	UInt32 mBitRate;

	bool bDoneNetworkStream;
	bool bDoneFileStream;
	bool bDoneAudioStream;
	bool bReconnecting;
	bool bConserving;
	bool bStarted;
	bool bTriggered;
	bool bDataFormat;
	bool bPacketsReady;
	bool bPlaying;
	bool bPrimed;
	bool bPaused;
	bool bThreaded;
	bool bShoutcast;
	bool bCleaned;
	bool bPodcast;
	bool bPodcastDone;
	bool bMarked;
	//bool bLive;
	bool bCacheReady;
	bool bStarving;
	bool bReconnectTrigger;

	int iReadMode;
	int iMetaInt;
	int iMetaSong;
	int iLeftToRead;
	int iBytesRead;
	int iReadTimeout;
	int rswitcher;
	int wswitcher;
	int radjuster;
	UInt8 *pMetaBuffer;
	UInt32 iMetaRead;
	XMLTrack *wtrack;
	XMLTrack *rtrack;
	int windex;
	int rindex;

	//NSMutableArray *packets;
	//NSLock *packetLock;
	NSMutableArray *buffers;
	NSLock *bufferLock;
	NSMutableArray *freebuffers;
	NSLock *freebufferLock;
	NSLock *fileLock;
	Player *myPlayer;
	FILE *audiofile;
	//AppDelegate *myApp;
	pthread_mutex_t mutex;
	pthread_cond_t cond;
};

void mypAudioQueuePackets(void * inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inCompleteAQBuffer)
{
	AQTestInfo *infoPtr = (AQTestInfo *) inUserData;

	[infoPtr->freebufferLock lock];	
	Buffer *curbuf = (Buffer *) [infoPtr->freebuffers objectAtIndex:0];
	[infoPtr->freebuffers removeObjectAtIndex:0];
	[infoPtr->freebufferLock unlock];
	
	[infoPtr->bufferLock lock];
	[infoPtr->buffers addObject:curbuf];
	[infoPtr->bufferLock unlock];

	pthread_mutex_lock(&infoPtr->mutex);
	pthread_cond_signal(&infoPtr->cond);
	pthread_mutex_unlock(&infoPtr->mutex);
	//printf( "-- \t\t\tmyAudioQueuePackets AFTER [%d] [%d] [%d]\n", [infoPtr->buffers count], [infoPtr->packets count], infoPtr->mLastOffset );
}

void mypFileStreamProperties(void *inUserData, AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, UInt32 *ioFlags)
{
	AQTestInfo *infoPtr = (AQTestInfo *) inUserData;
	if( infoPtr->bDoneFileStream ) return;

	UInt32 size;

	if( inPropertyID == kAudioFileStreamProperty_ReadyToProducePackets )
	{		
		if( infoPtr->bTriggered == NO )
		{
			infoPtr->bTriggered = YES;
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.3, false);
		}
		
		//printf( "-- AUDIO FILE READY [%X]\n", infoPtr );
		size = sizeof(infoPtr->mDataFormat);
		AudioFileStreamGetProperty(infoPtr->mAudioFileStream, kAudioFileStreamProperty_DataFormat, &size, &infoPtr->mDataFormat);
		infoPtr->bDataFormat = YES;

		size = sizeof(infoPtr->mPacketsReady);
		AudioFileStreamGetProperty(infoPtr->mAudioFileStream, kAudioFileStreamProperty_ReadyToProducePackets, &size, &infoPtr->mPacketsReady);
		infoPtr->bPacketsReady = YES;

		size = sizeof(infoPtr->mBitRate);
		AudioFileStreamGetProperty(infoPtr->mAudioFileStream, kAudioFileStreamProperty_BitRate, &size, &infoPtr->mBitRate);
		if( infoPtr->mBitRate >= 32000 )
		{
			infoPtr->mBitRate /= 1000;
		}
		if( infoPtr->wtrack != nil )
		{
			infoPtr->wtrack.bitrate = infoPtr->mBitRate;
		}
	}

	if( infoPtr->mPacketsReady && !infoPtr->bThreaded)
	{
		infoPtr->bThreaded = YES;
		[NSThread detachNewThreadSelector:@selector(audioThread:) toTarget:infoPtr->myPlayer withObject:nil];

		if( infoPtr->myPlayer.bRecorded )
		{
			do
			{
				CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
			} while ( !infoPtr->bStarted );
		}
	}
}

void mypEnqueueBuffer(AQTestInfo* infoPtr)
{
	/*
	Packet *packet = [[Packet alloc] init];
	packet.bytes = infoPtr->mBytesFilled;
	[infoPtr->packetLock lock];
	[infoPtr->packets addObject:packet];
	[infoPtr->packetLock unlock];
	//*/

	infoPtr->mCurrentBuffer->mAudioDataByteSize = infoPtr->mBytesFilled;
	//printf( "-- \t\t\tmypEnqueueBuffer [%d] [%d] [%d]\n", infoPtr->mBytesFilled, [infoPtr->buffers count], [infoPtr->packets count] );
	AudioQueueEnqueueBuffer(infoPtr->mQueue, infoPtr->mCurrentBuffer, infoPtr->mPacketsFilled, infoPtr->mPacketDescs);

	infoPtr->mCurrentBuffer = nil;
	infoPtr->mBytesFilled = 0;
	infoPtr->mPacketsFilled = 0;
}

void mypFileStreamPackets(void *inUserData, UInt32 inNumberBytes, UInt32 inNumberPackets, const void *inInputData, AudioStreamPacketDescription *inPacketDescriptions)
{
	AQTestInfo *infoPtr = (AQTestInfo *) inUserData;

	if( infoPtr->bDoneFileStream ) return;
	
	if( infoPtr->bStarted )
	{
		for( int i = 0; i < inNumberPackets; i++ )
		{
			SInt64 packetOffset = inPacketDescriptions[i].mStartOffset;
			SInt64 packetSize   = inPacketDescriptions[i].mDataByteSize;

			size_t available = AUDIO_QUEUE_BUFFER_SIZE - infoPtr->mBytesFilled;
			if(available < packetSize && infoPtr->mCurrentBuffer != nil )
			{
				mypEnqueueBuffer(infoPtr);
			}

			if( infoPtr->mCurrentBuffer == nil )
			{
				[infoPtr->bufferLock lock];
				Buffer *curbuf = (Buffer *) [infoPtr->buffers objectAtIndex:0];
				[infoPtr->buffers removeObjectAtIndex:0];
				infoPtr->mCurrentBuffer = curbuf.handle;
				[infoPtr->bufferLock unlock];
				
				[infoPtr->freebufferLock lock];
				[infoPtr->freebuffers addObject:curbuf];
				[infoPtr->freebufferLock unlock];
			}
			
			if( infoPtr->mCurrentBuffer == nil )
			{
				return;
			}

			memcpy((char*)infoPtr->mCurrentBuffer->mAudioData + infoPtr->mBytesFilled, (const char*)inInputData + packetOffset, packetSize);
			infoPtr->mPacketDescs[infoPtr->mPacketsFilled] = inPacketDescriptions[i];
			infoPtr->mPacketDescs[infoPtr->mPacketsFilled].mStartOffset = infoPtr->mBytesFilled;
			infoPtr->mBytesFilled += packetSize;
			infoPtr->mPacketsFilled++;

			available = AUDIO_QUEUE_PACKET_DESCS - infoPtr->mPacketsFilled;
			if(available == 0)
			{
				mypEnqueueBuffer(infoPtr);
			}
		}

		infoPtr->mPacketCount += inNumberPackets;
		//printf( "-- \t\tmyFileStreamPackets [%d] [%d]\n", inNumberBytes, infoPtr->mPacketCount );
		if( !infoPtr->bPrimed && infoPtr->mPacketCount >= 2 )
		{
			infoPtr->bPrimed = YES;
		}
		if( !infoPtr->bPlaying && !infoPtr->bPaused && infoPtr->bPrimed )
		{
			infoPtr->bPlaying = YES;
			infoPtr->bPaused = NO;
			//[infoPtr->myPlayer performSelectorOnMainThread:@selector(updateBuffer:) withObject:nil waitUntilDone:NO];
		}
	}
}

void mypReadStreamPackets(CFReadStreamRef stream, CFStreamEventType event, void *inUserData)
{
	AQTestInfo *infoPtr = (AQTestInfo *) inUserData;

	if( infoPtr->bDoneNetworkStream || infoPtr->bReconnecting ) return;

	CFIndex bytesRead;
	@try
	{
		switch(event)
		{
			case kCFStreamEventHasBytesAvailable:
				if( infoPtr->wtrack.begin == infoPtr->wtrack.current )
				{
					CFHTTPMessageRef msgRespuesta = (CFHTTPMessageRef) CFReadStreamCopyProperty(stream, kCFStreamPropertyHTTPResponseHeader);
					NSData *therequest = (NSData *) CFHTTPMessageCopySerializedMessage(msgRespuesta);
					NSString *dataresponse = [[[NSString alloc] initWithData:therequest encoding:NSUTF8StringEncoding] autorelease];
					[infoPtr->myPlayer parsefcResponse:dataresponse];
					[therequest release];
				}

				if( infoPtr->wtrack.wmediafile == nil )
				{
					[infoPtr->myPlayer openwritefile:infoPtr->wtrack];
				}
				
				if( infoPtr->wtrack.redirecting == YES )
				{
					return;
				}

				UInt8 buf[DATA_QUEUE_BUFFER_SIZE];
				UInt8 *buffer;
				int iToRead;
				bytesRead = CFReadStreamRead(stream, buf, DATA_QUEUE_BUFFER_SIZE);
				buffer = (UInt8*) &buf;
				//printf("mypReadStreamPackets %d of %d\n", infoPtr->wtrack.current, infoPtr->wtrack.length);
				if( bytesRead > 0 )
				{
					NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
					infoPtr->iReadTimeout = 0;
					iToRead = bytesRead;
					infoPtr->mBytesQueued += iToRead;
					NSData *pdata = [NSData dataWithBytesNoCopy:buffer length:bytesRead freeWhenDone:NO];

					[infoPtr->fileLock lock];
					[infoPtr->wtrack.wmediafile writeData:pdata];
					[infoPtr->fileLock unlock];
					infoPtr->wtrack.current += iToRead;
					infoPtr->wtrack.woffset = infoPtr->wtrack.current;					
					[pool release];
					
					if( infoPtr->bTriggered == NO && infoPtr->myPlayer.tracklist.podcasting == YES && infoPtr->wtrack.current < 8192 )
					{
						return;
					}
					
					if( infoPtr->bStarving == YES )
					{
						int secs = ( ( infoPtr->wtrack.woffset - infoPtr->wtrack.offset ) - infoPtr->wtrack.roffset ) / 128 / infoPtr->wtrack.bitrate;
						if( secs >= 12 || ( ( infoPtr->wtrack.woffset - infoPtr->wtrack.offset ) == infoPtr->wtrack.length ) )
						{
							AudioQueueStart(infoPtr->mQueue, NULL);
							[[PlayingView currentPlayingView] performSelectorOnMainThread:@selector(onBuffered:) withObject:nil waitUntilDone:NO];
							infoPtr->bStarving = NO;
						}
					}

					if( infoPtr->bStarving == NO )
					{
						pthread_mutex_lock(&infoPtr->mutex);
						pthread_cond_signal(&infoPtr->cond);
						pthread_mutex_unlock(&infoPtr->mutex);
					}

					if( infoPtr->wtrack.buffered == NO && (infoPtr->wtrack.current - infoPtr->wtrack.offset) / 128 / infoPtr->wtrack.bitrate >= 4 )
					{
						infoPtr->wtrack.buffered = YES;
						[[PlayingView currentPlayingView] processEvent:EVENT_TRACKBUFFERED forIndex:infoPtr->windex];
					}
					infoPtr->iReadTimeout = 0;
				}
				break;
			case kCFStreamEventErrorOccurred:
				infoPtr->bReconnecting = YES;
				break;
			case kCFStreamEventEndEncountered:
				if( infoPtr->bPodcast == NO  || infoPtr->mLastOffset < infoPtr->mTotalLength )
				{
					infoPtr->bReconnecting = YES;
				}
				break;
		}
	}
	@catch (NSException *theErr)
	{
		infoPtr->bReconnecting = YES;
	}
}

void mypReadShoutcastPackets(CFReadStreamRef stream, CFStreamEventType event, void *inUserData)
{
	AQTestInfo *infoPtr = (AQTestInfo *) inUserData;
	if( infoPtr->bDoneNetworkStream || infoPtr->bReconnecting ) return;

	CFIndex bytesRead;
	@try
	{
		switch(event)
		{
			case kCFStreamEventHasBytesAvailable:
				UInt8 buf[DATA_QUEUE_BUFFER_SIZE];
				UInt8 *buffer;
				int iToRead;
				int iHadRead;
				bytesRead = CFReadStreamRead(stream, buf, DATA_QUEUE_BUFFER_SIZE);
				buffer = (UInt8*) &buf;
				while( bytesRead > 0 )
				{
					if( infoPtr->iReadMode == 0 )
					{
						iHadRead = infoPtr->iMetaRead;
						if( infoPtr->iMetaRead == 0 )
						{
							memcpy( infoPtr->pMetaBuffer + infoPtr->iMetaRead, buffer, bytesRead );
							infoPtr->iMetaRead += bytesRead;
						}
						else
						{
							iToRead = ( (8192 - infoPtr->iMetaRead) > bytesRead ) ? bytesRead : (8192 - infoPtr->iMetaRead);
							memcpy( infoPtr->pMetaBuffer + infoPtr->iMetaRead, buffer, iToRead );
							infoPtr->iMetaRead += iToRead;
						}

						if( infoPtr->pMetaBuffer[0] == 'I' && infoPtr->pMetaBuffer[1] == 'C' && infoPtr->pMetaBuffer[2] == 'Y' )
						{
						   for( int x = 0; x < infoPtr->iMetaRead; x++ )
							{
								if( infoPtr->pMetaBuffer[x] == 13 && infoPtr->pMetaBuffer[x+1] == 10 && infoPtr->pMetaBuffer[x+2] == 13 && infoPtr->pMetaBuffer[x+3] == 10 )
								{
									infoPtr->iReadMode =  1;
									NSString *headers = [[[NSString alloc] initWithBytes:infoPtr->pMetaBuffer length:x encoding:NSUTF8StringEncoding] autorelease];
									[infoPtr->myPlayer parseHeaders:headers];
									bytesRead -= ( ( x - iHadRead ) + 4 );
									buffer = buf + ( ( x - iHadRead ) + 4 );
									infoPtr->iMetaRead = 0;
									break;
								}
							}
						}
						else
						{							
							CFHTTPMessageRef msgRespuesta = (CFHTTPMessageRef) CFReadStreamCopyProperty(stream, kCFStreamPropertyHTTPResponseHeader);
							NSData *therequest = (NSData *) CFHTTPMessageCopySerializedMessage(msgRespuesta);
							NSString *dataresponse = [[[NSString alloc] initWithData:therequest encoding:NSUTF8StringEncoding] autorelease];
							[infoPtr->myPlayer parsescResponse:dataresponse];
							[therequest release];
							
							infoPtr->iMetaRead = 0;
							infoPtr->iReadMode =  1;
						}

						if( infoPtr->iReadMode == 0 )
						{
							bytesRead = 0;
						}
					}
					if( infoPtr->iReadMode == 1 && bytesRead > 0 )
					{
						//printf( "-- myReadShoutcastPackets -- QUEUEING [%d]\n", bytesRead );
						iToRead = ( bytesRead > infoPtr->iLeftToRead ) ? infoPtr->iLeftToRead : bytesRead;
						infoPtr->mBytesQueued += iToRead;
						if( infoPtr->wtrack.wmediafile == nil )
						{
							[infoPtr->myPlayer openwritefile:infoPtr->wtrack];
						}

						NSData *pdata = [NSData dataWithBytesNoCopy:buffer length:iToRead freeWhenDone:NO];

						[infoPtr->fileLock lock];
						[infoPtr->wtrack.wmediafile writeData:pdata];
						[infoPtr->fileLock unlock];
						infoPtr->wtrack.current += iToRead;
						
						if( infoPtr->wtrack.current > infoPtr->wtrack.length )
							infoPtr->wtrack.length += (infoPtr->wtrack.bitrate * 128 * 60 * 15);

						pthread_mutex_lock(&infoPtr->mutex);
						pthread_cond_signal(&infoPtr->cond);
						pthread_mutex_unlock(&infoPtr->mutex);

						if( infoPtr->wtrack.buffered == NO && (infoPtr->wtrack.current - infoPtr->wtrack.offset) / 128 / infoPtr->wtrack.bitrate >= 4 )
						{
							infoPtr->wtrack.buffered = YES;
							[[PlayingView currentPlayingView] processEvent:EVENT_TRACKBUFFERED forIndex:infoPtr->windex];
						}

						infoPtr->iLeftToRead -= iToRead;
						bytesRead -= iToRead;
						buffer = buffer + iToRead;
						if( infoPtr->iLeftToRead == 0 )
						{
							infoPtr->iReadMode = 2;
						}
					}
					if( infoPtr->iReadMode == 2 )
					{
						if( bytesRead > 0 )
						{
							bytesRead--;
							infoPtr->iMetaSong = buffer[0] * 16;
							infoPtr->iReadMode = 3;
							infoPtr->iLeftToRead = infoPtr->iMetaSong;
							buffer = buffer + 1;
							if( infoPtr->iMetaSong == 0 )
							{
								infoPtr->iLeftToRead = infoPtr->iMetaInt;
								infoPtr->iReadMode = 1;
							}
						}
					}
					if( infoPtr->iReadMode == 3 )
					{
						iToRead = ( bytesRead > infoPtr->iLeftToRead ) ? infoPtr->iLeftToRead : bytesRead;
						memcpy( infoPtr->pMetaBuffer + infoPtr->iMetaRead, buffer, iToRead );
						infoPtr->iLeftToRead -= iToRead;
						bytesRead -= iToRead;
						infoPtr->iMetaRead += iToRead;
						if( infoPtr->iLeftToRead == 0 )
						{
							NSString *headers = [[[NSString alloc] initWithBytes:infoPtr->pMetaBuffer length:infoPtr->iMetaRead encoding:NSUTF8StringEncoding] autorelease];
							[infoPtr->myPlayer parseMetadata:headers];
							infoPtr->iLeftToRead = infoPtr->iMetaInt;
							infoPtr->iReadMode = 1;
							infoPtr->iMetaRead = 0;
							[[PlayingView currentPlayingView] processEvent:EVENT_TRACKUPDATED forIndex:infoPtr->windex];
						}
						buffer = buffer + iToRead;
					}
				}
				break;
			case kCFStreamEventErrorOccurred:
				infoPtr->bReconnecting = YES;
				infoPtr->iReadMode = 0;
				break;
			case kCFStreamEventEndEncountered:
				infoPtr->bReconnecting = YES;
				infoPtr->iReadMode = 0;
				break;
		}
	}
	@catch (NSException *theErr)
	{
		infoPtr->bReconnecting = YES;
		infoPtr->iReadMode = 0;
	}
}

@implementation Player

@synthesize node;
@synthesize tracklist = _tracklist;
@synthesize bPlaying;
@synthesize bStopping;
@synthesize bPaused;
@synthesize bReady;
@synthesize bError;
@synthesize bLingering;
@synthesize bLocked;
@synthesize bInter;
@synthesize bLinger;
@synthesize bMute;
@synthesize bShoutcast;
@synthesize bRecorded;
@synthesize fVolume;
@synthesize bOffline;
@synthesize mirrors;
@synthesize station;

//- (id)initWithApp:(AppDelegate *)app
- (id)init
{
	self = [super init];
	//myApp = app;
	myInfo = new AQTestInfo();
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	//infoPtr->packets = [[NSMutableArray alloc] init];
	//infoPtr->packetLock = [[NSLock alloc] init];
	infoPtr->fileLock = [[NSLock alloc] init];
	infoPtr->buffers = [[NSMutableArray alloc] init];
	infoPtr->bufferLock = [[NSLock alloc] init];
	infoPtr->freebuffers = [[NSMutableArray alloc] init];
	infoPtr->freebufferLock = [[NSLock alloc] init];
	//infoPtr->myApp = app;
	infoPtr->myPlayer = self;
	infoPtr->pMetaBuffer = new UInt8[8192];
	infoPtr->iMetaRead = 0;	infoPtr->mQueue = NULL;
	infoPtr->bPlaying = NO;
	infoPtr->bDoneAudioStream = YES;
	infoPtr->bCleaned = YES;
	//infoPtr->bLive = NO;
	pthread_mutex_init(&infoPtr->mutex, NULL);
	pthread_cond_init(&infoPtr->cond, NULL);
	fVolume = 1.0;
	mirrors = nil;
	_tracklist = nil;
	_nextAd = nil;
	node = nil;
	bPlaying = NO;
	bStopping = NO;
	bPaused = NO;
	bError = NO;
	bLinger = NO;
	bLingering = NO;
	bLocked = NO;
	bInter = NO;
	bReady = NO;
	bMute = NO;
	bShoutcast = NO;
	
	if( strBaseDir == nil )
	{
		NSArray *arr = NSSearchPathForDirectoriesInDomains( NSDocumentDirectory, NSUserDomainMask, YES );
		strBaseDir = [[arr objectAtIndex:0] retain];
		strUIDN = @"00000000-0000-0000-0000-000000000000";
	}
	station = @"";
	
	return self;
}

- (void)updateBuffer:(id)sender
{
	/*
    AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	if( bRecorded )
	{
		[myApp.recordedViewController updateStatus:infoPtr->mBytesPlayed];
	}
	else
	{
		double dt = (double)infoPtr->mBytesQueued / (double)infoPtr->mBitRate / 128.0;
		int t = (dt + 0.5);
		//printf( "-- updateBuffer -- [%f] [%d]\n", dt, t );
		int m = t / 60;
		int s =  (t - (m * 60));
	}
	//*/
}

- (void)notAvailable:(id)sender
{
	bError = YES;
	bPlaying = NO;
	bStopping = NO;
	bReady = NO;

	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Not Available" message:@"Sorry, this media is no longer available." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
	[alert show];
	[alert release];
}

- (void)stopStream:(id)sender
{
	if( bStopping == YES ) return;
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	bStopping = YES;
	bReady = NO;
	infoPtr->bDoneNetworkStream = YES;
	infoPtr->bPlaying = NO;
	if( infoPtr->bPodcastDone == YES )
	{
		[NSTimer scheduledTimerWithTimeInterval:0.0 target:[PlayingView currentPlayingView] selector:@selector(podcastComplete:) userInfo:nil repeats:NO];
	}
	CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, false);
	[self closereadfile:infoPtr->rtrack];
	[self closewritefile:infoPtr->wtrack];
}

- (void)setIntersitial:(CachedAd *)ad
{
	_nextAd = ad;
}

- (void)interDone:(id)sender
{
	//printf("interDone\n");
	AudioSessionSetActive(YES);
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	[[PlayingView currentPlayingView] interDone:sender];
	_nextAd = nil;
	bLocked = NO;
	bInter = NO;	
	pthread_mutex_lock(&infoPtr->mutex);
	pthread_cond_signal(&infoPtr->cond);
	pthread_mutex_unlock(&infoPtr->mutex);
	AudioQueueStart(infoPtr->mQueue, NULL);
}

- (void)parsescResponse:(NSString *)headers
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	NSString *strTemp;
	NSString *strValue;
	NSRange range;
	
	headers = [headers lowercaseString];	
	range = [headers rangeOfString:@"icy-metaint:"];
	strTemp = [headers substringFromIndex:range.location + range.length];
	range = [strTemp rangeOfString:@"\r\n"];
	strValue = [strTemp substringWithRange:NSMakeRange(0,range.location)];
	infoPtr->iMetaInt = [strValue intValue];
	infoPtr->iLeftToRead = infoPtr->iMetaInt;
	
	range = [headers rangeOfString:@"icy-br:"];
	strTemp = [headers substringFromIndex:range.location + range.length];
	range = [strTemp rangeOfString:@"\r\n"];
	if( range.length == 0 )
		strValue = [strTemp substringWithRange:NSMakeRange(0,range.location)];
	else
		strValue = [[strTemp copy] autorelease];
	infoPtr->mBitRate = [strValue intValue];
	if( infoPtr->mBitRate == 0 ) infoPtr->mBitRate = 128;
	infoPtr->wtrack.bitrate = infoPtr->mBitRate;
}

- (void)parseHeaders:(NSString *)headers
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	NSString *strTemp;
	NSString *strValue;
	NSRange range;

	range = [headers rangeOfString:@"icy-metaint:"];
	strTemp = [headers substringFromIndex:range.location + range.length];
	range = [strTemp rangeOfString:@"\r\n"];
	strValue = [strTemp substringWithRange:NSMakeRange(0,range.location)];
	infoPtr->iMetaInt = [strValue intValue];
	infoPtr->iLeftToRead = infoPtr->iMetaInt;

	range = [headers rangeOfString:@"icy-br:"];
	strTemp = [headers substringFromIndex:range.location + range.length];
	range = [strTemp rangeOfString:@"\r\n"];
	if( range.length != 0 )
		strValue = [strTemp substringWithRange:NSMakeRange(0,range.location)];
	else
		strValue = [[strTemp copy] autorelease];
	infoPtr->mBitRate = [strValue intValue];
	if( infoPtr->mBitRate == 0 ) infoPtr->mBitRate = 128;
	infoPtr->wtrack.bitrate = infoPtr->mBitRate;
}

- (void)parseMetadata:(NSString *)headers
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	NSRange range1;
	NSRange range2;

	range1 = [headers rangeOfString:@"StreamTitle="];
	range2 = [headers rangeOfString:@";"];
	if( range1.length != 0 && range2.length != 0 )
	{
		infoPtr->wtrack.artist = [headers substringWithRange:NSMakeRange(range1.location+12, range2.location-range1.location-12)];
		infoPtr->wtrack.artist = [[infoPtr->wtrack.artist stringByReplacingOccurrencesOfString:@"'" withString:@""] retain];
	}
}

- (int)parseResponse:(NSString *)headers
{
	NSString *strTemp;
	NSString *strValue;
	NSRange range;

	range = [headers rangeOfString:@"Accept-Ranges: none"];
	if( range.length == 0 )
	{
		range = [headers rangeOfString:@"Content-Length:"];
		strTemp = [headers substringFromIndex:range.location + range.length];
		range = [strTemp rangeOfString:@"\r\n"];
		strValue = [strTemp substringWithRange:NSMakeRange(0,range.location)];
		return [strValue intValue];
	}
	else
	{
		return 0;
	}
}

- (NSString *)getHeaderValue:(NSString *)headers forKey:(NSString *)key
{
	NSString *temp = nil;

	NSRange range = [headers rangeOfString:key options:NSCaseInsensitiveSearch];
	if( range.length > 0 )
	{
		NSRange ender = [headers rangeOfString:@"\r\n" options:NSCaseInsensitiveSearch range:NSMakeRange(range.location, [headers length]-range.location)];
		if( ender.length > 0 )
		{
			temp = [[[[headers substringWithRange:NSMakeRange(range.location+range.length, ender.location-range.location-range.length)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] copy] autorelease];
		}
	}

	if( temp != nil && [temp length] == 0 ) temp = nil;

	return temp;
}

- (int)getHeaderValueInt:(NSString *)headers forKey:(NSString *)key
{
	int num = 0;

	NSRange range = [headers rangeOfString:key options:NSCaseInsensitiveSearch];
	if( range.length > 0 )
	{
		NSRange ender = [headers rangeOfString:@"\r\n" options:NSCaseInsensitiveSearch range:NSMakeRange(range.location, [headers length]-range.location)];
		if( ender.length > 0 )
		{
			num = [[[headers substringWithRange:NSMakeRange(range.location+range.length, ender.location-range.location-range.length)] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] intValue];
		}
		if( num < 0 ) num = 117964800;
	}

	return num;
}

- (void)parsefcResponse:(NSString *)headers
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;

	/*
	printf( "\r\n ***** TRACKS IN HEADERS -- title curr -- ");
	if( [self getHeaderValue:headers forKey:@"fc_title:"] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fc_title:"] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- artis curr -- ");
	if( [self getHeaderValue:headers forKey:@"fc_artist:"] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fc_artist:"] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- album curr -- ");
	if( [self getHeaderValue:headers forKey:@"fc_album:"] != nil ) printf("%s", [[self getHeaderValue:headers forKey: @"fc_album:"] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- metad curr -- ");
	if( [self getHeaderValue:headers forKey:@"fc_metadata: "] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fc_metadata: "] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- guidi curr -- ");
	if( [self getHeaderValue:headers forKey:@"fc_mflid: "] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fc_mflid: "] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- guidc curr -- ");
	if( [self getHeaderValue:headers forKey:@"fc_cacheid: "] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fc_cacheid: "] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- lengt curr -- ");
	if( [self getHeaderValue:headers forKey:@"fc_length: "] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fc_length: "] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- syncb curr -- ");
	if( [self getHeaderValue:headers forKey:@"fc_syncbyte: "] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fc_syncbyte: "] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- covr curr -- ");
	if( [self getHeaderValue:headers forKey:@"fc_coverart: "] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fc_coverart: "] cStringUsingEncoding:NSASCIIStringEncoding]);

	printf( "\r\n ***** TRACKS IN HEADERS -- title next -- ");
	if( [self getHeaderValue:headers forKey:@"fcn_title:"] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fcn_title:"] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- artis next -- ");
	if( [self getHeaderValue:headers forKey:@"fcn_artist:"] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fcn_artist:"] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- album next -- ");
	if( [self getHeaderValue:headers forKey:@"fcn_album:"] != nil ) printf("%s", [[self getHeaderValue:headers forKey: @"fcn_album:"] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- metad next -- ");
	if( [self getHeaderValue:headers forKey:@"fcn_metadata: "] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fcn_metadata: "] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- guidi next -- ");
	if( [self getHeaderValue:headers forKey:@"fcn_mflid: "] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fcn_mflid: "] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- guidc next -- ");
	if( [self getHeaderValue:headers forKey:@"fcn_cacheid: "] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fcn_cacheid: "] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- lengt next -- ");
	if( [self getHeaderValue:headers forKey:@"fcn_length: "] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fcn_length: "] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- syncb next -- ");
	if( [self getHeaderValue:headers forKey:@"fcn_syncbyte: "] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fcn_syncbyte: "] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- covr curr -- ");
	if( [self getHeaderValue:headers forKey:@"fcn_coverart: "] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"fcn_coverart: "] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n");
	
	printf( "\r\n ***** TRACKS IN HEADERS -- Content-Length -- ");
	if( [self getHeaderValue:headers forKey:@"Content-Length:"] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"Content-Length:"] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n ***** TRACKS IN HEADERS -- Content-Range -- ");
	if( [self getHeaderValue:headers forKey:@"Content-Range:"] != nil ) printf("%s", [[self getHeaderValue:headers forKey:@"Content-Range:"] cStringUsingEncoding:NSASCIIStringEncoding]);
	printf( "\r\n");
	//*/

	NSRange range = [headers rangeOfString:@" 404 "];
	if( range.length > 0 )
	{
		infoPtr->wtrack.notfound = YES;
		return;
	}
	
	NSString *fail = [self getHeaderValue:headers forKey:@"fc_fail:"];
	if( fail != nil )
	{
		[[PlayingView currentPlayingView] performSelectorOnMainThread:@selector(onFail:) withObject:fail waitUntilDone:NO];
		return;
	}

	if( infoPtr->wtrack != nil )
	{
		NSString *newguid = [self getHeaderValue:headers forKey:@"fc_mflid: "];
		if( infoPtr->wtrack.guidIndex != nil && newguid != nil && [infoPtr->wtrack.guidIndex compare:newguid] != NSOrderedSame )
		{
			if( infoPtr->windex + 1 < [_tracklist.children count] )
			{
				XMLTrack *temp = (XMLTrack *) [_tracklist.children objectAtIndex:(infoPtr->windex + 1)];
				if( [temp.guidIndex compare:newguid] == NSOrderedSame )
				{
					infoPtr->wtrack.length = infoPtr->wtrack.current - infoPtr->wtrack.offset;
					infoPtr->wtrack.buffered = YES;
					infoPtr->wtrack.cached = YES;
					infoPtr->wtrack.seconds = infoPtr->wtrack.length / infoPtr->wtrack.bitrate / 128;

					[[PlayingView currentPlayingView] processEvent:EVENT_TRACKCACHED forIndex:infoPtr->windex];

					[self closewritefile:infoPtr->wtrack];
					infoPtr->wtrack = temp;
				}
			}
			else
			{
				if( _tracklist.recording == YES && infoPtr->wtrack.terminating == YES )
				{
					[[PlayingView currentPlayingView] processEvent:EVENT_TRACKLISTRECORDED forIndex:infoPtr->windex];
					_tracklist.recording = NO;
					_tracklist = nil;
					infoPtr->wtrack = nil;
				}
				[self addtrack];
				infoPtr->wswitcher = infoPtr->windex;
				[[PlayingView currentPlayingView] processEvent:EVENT_TRACKADDED forIndex:infoPtr->windex];
			}
		}

		NSString *tstring = [self getHeaderValue:headers forKey:@"Content-Range:"];
		BOOL found = NO;
		if( tstring != nil && infoPtr->wtrack.length == 0 )
		{
			range = [headers rangeOfString:@"/"];
			if( range.length > 0 )
			{
				found = YES;
				infoPtr->wtrack.length = [[tstring substringFromIndex:range.location+1] intValue];
				if( infoPtr->wtrack.length < 0 ) infoPtr->wtrack.length = 117964800;
			}
		}

		tstring = [self getHeaderValue:headers forKey:@"Content-Length:"];
		if( found == NO && tstring != nil && infoPtr->wtrack.length == 0 )
		{
			infoPtr->wtrack.length = [self getHeaderValueInt:headers forKey:@"Content-Length:"];
		}

		if( infoPtr->wtrack.guidIndex == nil )
		{			
			infoPtr->wtrack.timecode = CFAbsoluteTimeGetCurrent();
			infoPtr->wtrack.mediatype = [self getHeaderValue:headers forKey:@"Content-Type:"];
			infoPtr->wtrack.metadata = [self getHeaderValue:headers forKey:@"fc_metadata:"];
			infoPtr->wtrack.artist = [self getHeaderValue:headers forKey:@"fc_artist:"];
			infoPtr->wtrack.album = [self getHeaderValue:headers forKey:@"fc_album:"];
			infoPtr->wtrack.title = [self getHeaderValue:headers forKey:@"fc_title:"];
			infoPtr->wtrack.starttime = [self getHeaderValue:headers forKey:@"fc_starttime:"];
			infoPtr->wtrack.imageurl = [self getHeaderValue:headers forKey:@"fc_coverart:"];
			infoPtr->wtrack.guidIndex = [self getHeaderValue:headers forKey:@"fc_mflid:"];
			infoPtr->wtrack.guidSong = [self getHeaderValue:headers forKey:@"fc_cacheid:"];
			infoPtr->wtrack.length = [self getHeaderValueInt:headers forKey:@"fc_length:"];

			tstring = [self getHeaderValue:headers forKey:@"fc_syncbyte:"];
			if( tstring != nil )
			{
				infoPtr->wtrack.synced = YES;
				infoPtr->wtrack.syncoff = [self getHeaderValueInt:headers forKey:@"fc_syncbyte:"];
				if( infoPtr->wtrack.syncoff == 117964800 ) infoPtr->wtrack.synced = NO;
			}
			if( _tracklist.stopGuid == nil ) _tracklist.stopGuid = infoPtr->wtrack.guidIndex;
			//System.err.println( " ***** Adding first track -- " + _track.title );
		}
		else if( _tracklist.flycasting == YES && infoPtr->wtrack.redirect == nil )
		{
			infoPtr->wtrack.length = [self getHeaderValueInt:headers forKey:@"fc_length:"];
		}

		if( _tracklist.podcasting == YES || _tracklist.flycasting == YES )
		{
			tstring = [self getHeaderValue:headers forKey:@"Location: "];
			//printf( " ***** Redirect to -- %s\n", [tstring cStringUsingEncoding:NSASCIIStringEncoding] );
			if( tstring != nil ) infoPtr->wtrack.redirect = tstring;
		}

		tstring = [self getHeaderValue:headers forKey:@"fcn_mflid:"];
		if( tstring != nil )
		{
			if( tstring != nil && infoPtr->windex + 1 < [_tracklist.children count] )
			{
				XMLTrack *next = (XMLTrack *) [_tracklist.children objectAtIndex:(infoPtr->windex + 1)];
				if( next.guidIndex != nil && [next.guidIndex compare:tstring] == NSOrderedSame )
				{
					tstring = nil;
				}
			}

			if( tstring != nil )
			{
				if( _tracklist.stopGuid != nil && _tracklist.recording == YES && infoPtr->wtrack.terminating == NO && tstring != nil && [tstring compare:_tracklist.stopGuid] == NSOrderedSame )
				{
					infoPtr->wtrack.terminating = YES;
				}
				else
				{
					XMLTrack *temp = [[XMLTrack alloc] init];
					temp.stationid = _tracklist.stationid;
					temp.mediaurl = infoPtr->wtrack.mediaurl;
					temp.bitrate = infoPtr->wtrack.bitrate;
					temp.timecode = CFAbsoluteTimeGetCurrent();
					temp.listened = (temp.listened == YES) || (_tracklist.recording == NO) || ( (_tracklist.recording == NO) && (infoPtr->windex - 1 < infoPtr->rindex) );
					temp.current = infoPtr->wtrack.offset + infoPtr->wtrack.length;
					temp.offset = infoPtr->wtrack.offset + infoPtr->wtrack.length;
					temp.expdays = _tracklist.expdays;
					temp.expplays = _tracklist.expplays;

					temp.mediatype = [self getHeaderValue:headers forKey:@"Content-Type:"];
					temp.metadata = [self getHeaderValue:headers forKey:@"fcn_metadata:"];
					temp.artist = [self getHeaderValue:headers forKey:@"fcn_artist:"];
					temp.album = [self getHeaderValue:headers forKey:@"fcn_album:"];
					temp.title = [self getHeaderValue:headers forKey:@"fcn_title:"];
					temp.starttime = [self getHeaderValue:headers forKey:@"fcn_starttime:"];
					temp.imageurl = [self getHeaderValue:headers forKey:@"fcn_coverart:"];
					temp.guidIndex = [self getHeaderValue:headers forKey:@"fcn_mflid:"];
					temp.guidSong = [self getHeaderValue:headers forKey:@"fcn_cacheid:"];
					temp.length = [self getHeaderValueInt:headers forKey:@"fcn_length:"];

					tstring = [self getHeaderValue:headers forKey:@"fcn_syncbyte:"];
					if( tstring != nil )
					{
						temp.synced = YES;
						temp.syncoff = [self getHeaderValueInt:headers forKey:@"fcn_syncbyte:"];
						if( temp.syncoff == 117964800 ) temp.synced = NO;
					}

					if( temp.metadata != nil && temp.artist == nil && temp.title == nil )
					{
						temp.artist = _tracklist.station;
						temp.title = temp.metadata;
					}

					if( infoPtr->windex > infoPtr->rindex )
					{
						temp.delayed = YES;
					}

					//System.err.println( " ***** Adding next track -- " + temp.title );
					[ _tracklist.children insertObject:temp atIndex:( infoPtr->windex + 1 )];
					[[PlayingView currentPlayingView] processEvent:EVENT_TRACKADDED forIndex:infoPtr->windex];
				}
			}
		}

		if( _tracklist.podcasting == YES )
		{
			tstring = [self getHeaderValue:headers forKey:@" 416 "];
			if( tstring != nil )
			{
				infoPtr->wtrack.unsupported = YES;
			}
		}

		if( infoPtr->wtrack.redirect != nil && ( infoPtr->wtrack.redirected == NO || _tracklist.podcasting == YES ) )
		{
			range = [headers rangeOfString:@" 301 "];
			if( range.length == 0 ) range = [headers rangeOfString:@" 302 "];
			if( range.length > 0 )
			{
				tstring = [self getHeaderValue:headers forKey:@"Content-Type:"];
				if( tstring != nil && [tstring compare:@"audio/aac"] != NSOrderedSame && [tstring compare:@"audio/mpeg"] != NSOrderedSame )
				{
					infoPtr->wtrack.length = 0;
				}
				else
				{
					tstring = [self getHeaderValue:headers forKey:@"Content-Length:"];
					if( tstring != nil && infoPtr->wtrack.length == 0 )
					{
						infoPtr->wtrack.length = [self getHeaderValueInt:headers forKey:@"Content-Length:"];
					}
				}
				infoPtr->wtrack.redirecting = YES;
			}
		}

		if( infoPtr->wtrack.metadata != nil && infoPtr->wtrack.artist == nil && infoPtr->wtrack.title == nil )
		{
			infoPtr->wtrack.artist = _tracklist.station;
			infoPtr->wtrack.title = infoPtr->wtrack.metadata;
		}

		if( _tracklist.shoutcasting == YES )
		{
			infoPtr->wtrack.metaint = [self getHeaderValueInt:headers forKey:@"icy-metaint:"];
			infoPtr->wtrack.bitrate = [self getHeaderValueInt:headers forKey:@"icy-br:"];
		}
	}
}

- (void)closereadfile:(XMLTrack *)ptrack
{
	if( ptrack.rmediafile != nil )
	{
		[ptrack.rmediafile closeFile];
		ptrack.rmediafile = nil;
	}
}

- (void)closewritefile:(XMLTrack *)ptrack
{
	if( ptrack.wmediafile != nil )
	{
		[ptrack.wmediafile closeFile];
		ptrack.wmediafile = nil;
	}
}

- (void)openwritefile:(XMLTrack *)ptrack
{
	BOOL checkdir = YES;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSString *ofilename = [[[NSString alloc] initWithFormat:@"%@/%@/", strBaseDir, strUIDN] autorelease];
	if( NO == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:ofilename	withIntermediateDirectories:YES attributes:nil error:nil];
	}

	ofilename = [[[NSString alloc] initWithFormat:@"%@/%@/%d/", strBaseDir, strUIDN, ptrack.stationid] autorelease];
	if( NO == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:ofilename	withIntermediateDirectories:YES attributes:nil error:nil];
	}

	ofilename = [[[NSString alloc] initWithFormat:@"%@/%@/%d/%@", strBaseDir, strUIDN, ptrack.stationid, ptrack.guidSong] autorelease];
	if( NO == [[NSFileManager defaultManager] fileExistsAtPath:ofilename isDirectory:&checkdir] )
	{
		[[NSFileManager defaultManager] createFileAtPath:ofilename contents:nil attributes:nil];
	}

	ptrack.basefile = [[[NSString alloc] initWithFormat:@"/%@/%d/%@", strUIDN, ptrack.stationid, ptrack.guidSong] retain];
	ptrack.filename = [[[NSString alloc] initWithFormat:@"%@/%@", strBaseDir, ptrack.basefile] retain];
	ptrack.wmediafile = [NSFileHandle fileHandleForWritingAtPath:ptrack.filename];
	[ptrack.wmediafile seekToFileOffset:(ptrack.start + (ptrack.current - ptrack.offset))];
	/*		else
		{
			XMLTrack temp = m_app.findTrack( _tracklist, track );
			if( temp != null )
			{
				String url = _track.mediaurl;
				int offset = _track.offset;
				_track.copy(temp);
				_track.listened = (_track.listened == YES) || (_tracklist.recording == false) || ( (_tracklist.recording == YES) && (_currentindex - 1 < m_app.getCurrentPlayingIndex()) );
				_track.mediaurl = url;
				_track.offset = offset;
				_track.current = offset + _track.length;
				trackcached = YES;
				return;
			}
		}
	 //*/
	[pool release];
}

- (void)openreadfile:(XMLTrack *)ptrack
{
	ptrack.rmediafile = [NSFileHandle fileHandleForReadingAtPath:ptrack.filename];
	if( ptrack.resuming == NO ) ptrack.readoff = 0;
	else                        ptrack.readoff = ptrack.roffset;
	[ptrack.rmediafile seekToFileOffset:(ptrack.readoff)];
	ptrack.resuming = NO;
}

- (void)addtrack
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;

	BOOL remove = ( infoPtr->wtrack.current - infoPtr->wtrack.offset == 0 );

	infoPtr->wtrack.length = infoPtr->wtrack.current - infoPtr->wtrack.offset;
	infoPtr->wtrack.buffered = YES;
	infoPtr->wtrack.cached = YES;
	infoPtr->wtrack.seconds = infoPtr->wtrack.length / 128 / infoPtr->wtrack.bitrate;

	[[PlayingView currentPlayingView] processEvent:EVENT_TRACKCACHED forIndex:infoPtr->windex];
	[self closewritefile:infoPtr->wtrack];

	if( remove == YES )
	{
		[_tracklist.children removeObjectAtIndex:infoPtr->windex];
		infoPtr->windex--;
		[[PlayingView currentPlayingView] processEvent:EVENT_TRACKADDED forIndex:infoPtr->windex];
	}

	XMLTrack *temp = [[XMLTrack alloc] init];
	temp.stationid = _tracklist.stationid;
	temp.mediaurl = infoPtr->wtrack.mediaurl;
	temp.bitrate = infoPtr->wtrack.bitrate;
	temp.timecode = CFAbsoluteTimeGetCurrent();
	temp.delayed = YES;
	temp.listened = (temp.listened == YES) || (_tracklist.recording == NO) || ( (_tracklist.recording == NO) && (infoPtr->windex - 1 < infoPtr->rindex) );
	temp.current = infoPtr->wtrack.offset + infoPtr->wtrack.length;
	temp.offset = infoPtr->wtrack.offset + infoPtr->wtrack.length;
	temp.expdays = _tracklist.expdays;
	temp.expplays = _tracklist.expplays;

	infoPtr->wtrack = temp;
	infoPtr->windex++;
	[_tracklist.children insertObject:infoPtr->wtrack atIndex:infoPtr->windex];
}

- (void)dealloc
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	//[infoPtr->packets release];
	//[infoPtr->packetLock release];
	[infoPtr->fileLock release];
	[infoPtr->buffers release];
	[infoPtr->bufferLock release];
	[infoPtr->freebuffers release];
	[infoPtr->freebufferLock release];
	delete [] infoPtr->pMetaBuffer;
	delete infoPtr;
	if( mirrors ) [mirrors release];
	if( node ) [node release];
	[super dealloc];
}

- (void)adjustVolume:(double)level
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	if( infoPtr->mQueue == nil || infoPtr->bPlaying == NO ) return;

	fVolume = level;
	AudioQueueSetParameter(infoPtr->mQueue, kAudioQueueParam_Volume, fVolume);
}

- (void)toggleMute
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	if( infoPtr->mQueue == nil || infoPtr->bPlaying == NO ) return;

	if( bMute )
		AudioQueueSetParameter(infoPtr->mQueue, kAudioQueueParam_Volume, fVolume);
	else
		AudioQueueSetParameter(infoPtr->mQueue, kAudioQueueParam_Volume, 0.0);

	bMute = !bMute;
}

- (void)togglePause
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	if( infoPtr->mQueue == nil || bLocked || bCalling || infoPtr->bStarving == YES ) return;

	if( bPaused == YES )
	{
		AudioQueueStart(infoPtr->mQueue, NULL);
		bPaused = NO;
	}
	else
	{
		AudioQueuePause(infoPtr->mQueue);
		bPaused = YES;
	}
}

- (void)pause
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	
	if( infoPtr->mQueue == nil || bLocked ) return;
	
	bCalling = YES;	
	if( bPaused == NO )
	{
		AudioQueuePause(infoPtr->mQueue);
	}
}

- (void)resume
{	
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	
	if( infoPtr->mQueue == nil || bLocked ) return;
	
	bCalling = NO;	
	if( bPaused == NO )
	{
		AudioQueueStart(infoPtr->mQueue, NULL);
		pthread_mutex_lock(&infoPtr->mutex);
		pthread_cond_signal(&infoPtr->cond);
		pthread_mutex_unlock(&infoPtr->mutex);		
	}
}

- (int)getPlayingIndex
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	return infoPtr->rindex;
}

- (int)getPlayingOffset
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	if( infoPtr->rtrack == nil )
		return 0;
	return infoPtr->rtrack.readoff;
}

- (void)startStream:(NSString *)file
{
	bPlaying = YES;
	bMute = NO;
	bPaused = NO;
	bStopping = NO;
	bReady = NO;
	bLinger = NO;
	bLingering = NO;
	bShoutcast = NO;
	bRecorded = YES;
	bError = NO;
	filename = [[file copy] retain];

	[NSThread detachNewThreadSelector:@selector(fileThread:) toTarget:self withObject:nil];
}

- (void)startStream:(XMLTracklist *)trackList withType:(BOOL)isShoutcast
{
	bPlaying = YES;
	bMute = NO;
	bPaused = NO;
	bStopping = NO;
	bReady = NO;
	bLinger = NO;
	bLingering = NO;
	bShoutcast = isShoutcast;
	bRecorded = NO;
	bError = NO;
	_tracklist = trackList;

	if( isShoutcast == YES )
		[NSThread detachNewThreadSelector:@selector(shoutcastThread:) toTarget:self withObject:nil];
	else
		[NSThread detachNewThreadSelector:@selector(streamThread:) toTarget:self withObject:nil];

	[NSThread detachNewThreadSelector:@selector(cachingThread:) toTarget:self withObject:nil];
}

- (void)streamThread:(id)anObject
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	infoPtr->bDataFormat = NO;
	infoPtr->bPacketsReady = NO;
	infoPtr->bStarted = NO;
	infoPtr->bTriggered = NO;
	infoPtr->bCacheReady = NO;
	infoPtr->bPlaying = NO;
	infoPtr->bPrimed = NO;
	infoPtr->bPaused = NO;
	infoPtr->bDoneNetworkStream = NO;
	infoPtr->bDoneFileStream = NO;
	infoPtr->bDoneAudioStream = NO;
	infoPtr->bThreaded = NO;
	infoPtr->mPacketCount = 0;
	infoPtr->bShoutcast = NO;
	infoPtr->bCleaned = NO;
	//infoPtr->bLive = NO;
	infoPtr->iReadMode = 0;
	infoPtr->iMetaRead = 0;
	infoPtr->mLastOffset = 0;
	infoPtr->mConnOffset = 0;
	infoPtr->mCachedByte = 0;
	infoPtr->mTotalLength = 0;
	infoPtr->mAudioFileStream = nil;
	infoPtr->bReconnecting = NO;
	infoPtr->bConserving = NO;
	infoPtr->bMarked = NO;
	infoPtr->bStarving = NO;
	infoPtr->bReconnectTrigger = NO;
	infoPtr->mBytesCached = 0;
	infoPtr->mBytesFilled = 0;
	infoPtr->mBytesPlayed = 0;
	infoPtr->mPacketsFilled = 0;
	infoPtr->iReadTimeout = 0;
	infoPtr->mBitRate = _tracklist.bitrate;
	if( infoPtr->mBitRate == 0 ) infoPtr->mBitRate = 128;
	//infoPtr->mCurrentData = [[Data alloc] init];
	//infoPtr->mCurrentData.buffer = new UInt8[DATA_QUEUE_BUFFER_SIZE];
	infoPtr->bPodcast = _tracklist.podcasting;
	infoPtr->bPodcastDone = NO;
	infoPtr->rswitcher = -1;
	infoPtr->wswitcher = -1;
	infoPtr->radjuster = -1;
	infoPtr->wtrack = nil;
	infoPtr->rtrack = nil;
	NSString *mirrorurl = nil;
	int retries = 0;
	int lasttime = 0;

	UInt32 audioType = kAudioFileMP3Type;
	infoPtr->windex = _tracklist.startindex;
	infoPtr->rindex = _tracklist.startindex;
	if( bOffline == NO && _tracklist.cached == NO && _tracklist.saved == NO ) // || _tracklist.offline == NO )
	{
		do
		{
			if( infoPtr->wswitcher != -1 )
			{
				[self closewritefile:infoPtr->wtrack];
				infoPtr->wtrack = nil;
				infoPtr->windex = infoPtr->wswitcher;
				infoPtr->wswitcher = -1;
			}

			if( infoPtr->wtrack != nil )
			{
				if( infoPtr->wtrack.length > 0 && infoPtr->wtrack.current - infoPtr->wtrack.offset == infoPtr->wtrack.length )
				{
					[self closewritefile:infoPtr->wtrack];
					infoPtr->wtrack.buffered = YES;
					infoPtr->wtrack.cached = YES;
					infoPtr->wtrack.seconds = infoPtr->wtrack.length / infoPtr->wtrack.bitrate / 128;
					infoPtr->wtrack = nil;
					infoPtr->windex++;

					[[PlayingView currentPlayingView] processEvent:EVENT_TRACKCACHED forIndex:infoPtr->windex];
				}
			}
			
			do {
				CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
			} while ( !infoPtr->bDoneNetworkStream && infoPtr->windex >= [_tracklist.children count] );

			BOOL sweeper = NO;
			if( infoPtr->windex > 0 )
			{
				XMLTrack *temp = (XMLTrack *) [_tracklist.children objectAtIndex:infoPtr->windex-1];
				if( temp.seconds < 35 && temp.cached == YES )
				{
					sweeper = YES;
				}
			}

			if( _tracklist.recording == YES && infoPtr->windex < [_tracklist.children count] )
			{
				XMLTrack *temp = (XMLTrack *) [_tracklist.children objectAtIndex:infoPtr->windex];
				if( temp.guidIndex != nil && _tracklist.stopGuid != nil && [temp.guidIndex compare:_tracklist.stopGuid ] == NSOrderedSame ) 
				{
					_tracklist.recording = NO;
				}
			}
			
			do {
				CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
				if( bLocked == YES )
				{
					pthread_mutex_lock(&infoPtr->mutex);
					pthread_cond_signal(&infoPtr->cond);
					pthread_mutex_unlock(&infoPtr->mutex);
				}
			} while ( infoPtr->windex > infoPtr->rindex + 1 /* && infoPtr->windex >= [_tracklist.children count]*/ && sweeper == NO && _tracklist.recording == NO && !infoPtr->bDoneNetworkStream && infoPtr->wswitcher == -1 );
			
			if( infoPtr->wswitcher != -1 ) continue;

			if( !infoPtr->bDoneNetworkStream )
			{
				if( infoPtr->wtrack == nil )
				{
					infoPtr->wtrack = (XMLTrack *) [_tracklist.children objectAtIndex:infoPtr->windex];					
					mirrorurl = infoPtr->wtrack.mediaurl;
					if( infoPtr->wtrack.redirect != nil )
					{
						mirrorurl = infoPtr->wtrack.redirect;
						infoPtr->wtrack.redirecting = NO;
					}
					
					if( mirrorurl == nil && infoPtr->windex > 0 )
					{
						XMLTrack *old = (XMLTrack *) [_tracklist.children objectAtIndex:infoPtr->windex-1];
						mirrorurl = old.mediaurl;
						infoPtr->wtrack.bitrate = old.bitrate;
					}
					
					NSRange range = [mirrorurl rangeOfString:@".aacp"];
					if( ( range.length == 5 && range.location == [mirrorurl length] - 5 ) )
					{
						audioType = kAudioFileAAC_ADTSType;
					}					
					
					//printf( "-- SERVER CONNECTION OPENED [%X]\n", infoPtr );
					if( infoPtr->mAudioFileStream == nil )
					{
						AudioFileStreamOpen( myInfo, mypFileStreamProperties, mypFileStreamPackets, audioType, &infoPtr->mAudioFileStream );
						//printf( "-- AUDIO FILE OPENED [%X]\n", infoPtr );
					}
					
					if( infoPtr->wtrack.cached == YES )
					{
						infoPtr->wtrack = nil;
						infoPtr->windex++;
						
						do
						{
							CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
						} while( !infoPtr->bCacheReady );
						
						pthread_mutex_lock(&infoPtr->mutex);
						pthread_cond_signal(&infoPtr->cond);
						pthread_mutex_unlock(&infoPtr->mutex);
						continue;
					}
				}
				else if( infoPtr->wtrack.redirect != nil )
				{
					mirrorurl = infoPtr->wtrack.redirect;
					infoPtr->wtrack.redirecting = NO;
				}

				if( _tracklist.recording == YES && _tracklist.stopGuid != nil && infoPtr->wtrack.guidIndex != nil && [infoPtr->wtrack.guidIndex compare:_tracklist.stopGuid] == NSOrderedSame )
				{
					_tracklist.recording = NO;
					continue;
				}

				if( _tracklist.flycasting == YES && infoPtr->windex - 1 < infoPtr->rindex && infoPtr->windex + 1 < [_tracklist.children count] )
				{
					XMLTrack *temp = (XMLTrack *) [_tracklist.children objectAtIndex:infoPtr->windex+1];
					if( temp.delayed == YES )
					{
						temp.delayed = NO;
						[[PlayingView currentPlayingView] processEvent:EVENT_TRACKUPDATED forIndex:infoPtr->windex];
					}
				}
				
				if( mirrorurl == nil )
				{
					printf("^^^ MIRROR URL IS NULL ^^^ ABORT ^^^\n");
					[[PlayingView currentPlayingView] performSelectorOnMainThread:@selector(onCantConnect:) withObject:nil waitUntilDone:NO];
					infoPtr->bDoneNetworkStream = YES;
					continue;
				}
				
				printf("^^^ MIRROR URL %s\r\n", [mirrorurl cStringUsingEncoding:NSASCIIStringEncoding]);
				printf("^^^ track title %s\r\n", [infoPtr->wtrack.title cStringUsingEncoding:NSASCIIStringEncoding]);
				//AMLog(@"^^^ MIRROR URL %s\r\n", [mirrorurl cStringUsingEncoding:NSASCIIStringEncoding]);
				//AMLog(@"^^^ track title %s\r\n", [infoPtr->wtrack.title cStringUsingEncoding:NSASCIIStringEncoding]);
				//printf("^^^ track url %s\r\n", [infoPtr->wtrack.mediaurl cStringUsingEncoding:NSASCIIStringEncoding]);
				const UInt8 bodyData = 0;
				CFStringRef url = (CFStringRef) mirrorurl;
				CFURLRef myURL = CFURLCreateWithString(kCFAllocatorDefault, url, NULL);
				CFStringRef requestMethod = CFSTR("GET");
				CFHTTPMessageRef myRequest = CFHTTPMessageCreateRequest(kCFAllocatorDefault, requestMethod, myURL, kCFHTTPVersion1_1);
				CFDataRef myData = CFDataCreate(NULL, &bodyData, 0);
				CFHTTPMessageSetBody(myRequest, myData);

				infoPtr->wtrack.listened = (infoPtr->wtrack.listened == YES) || (_tracklist.recording == NO) || ( (_tracklist.recording == YES) && (infoPtr->windex - 1 < infoPtr->rindex) );
				infoPtr->wtrack.delayed = NO;

				int streamLength = infoPtr->wtrack.length;
				if( infoPtr->wtrack.length == 0 ) streamLength = 98304;
				if( ( infoPtr->wtrack.current - infoPtr->wtrack.offset ) > streamLength )
				{
					streamLength = ( infoPtr->wtrack.current - infoPtr->wtrack.offset ) + 98304;
				}
				lasttime = infoPtr->wtrack.current;

				if( infoPtr->wtrack.unsupported == NO )
				{
					if( infoPtr->wtrack.redirect != nil && _tracklist.autoshuffle == NO )
					{
						CFStringRef headerFieldName = CFSTR("Range");
						CFStringRef headerFieldValue = CFStringCreateWithFormat(NULL, NULL, CFSTR("bytes=%d-%d"), (infoPtr->wtrack.current - infoPtr->wtrack.offset), (streamLength-1));
						CFHTTPMessageSetHeaderFieldValue(myRequest, headerFieldName, headerFieldValue);
						CFRelease(headerFieldValue);
						infoPtr->wtrack.begin = (infoPtr->wtrack.current);
						printf("Range %d-%d\n", (infoPtr->wtrack.current - infoPtr->wtrack.offset), (streamLength-1));
					}
					else if( infoPtr->wtrack.redirect == nil )
					{
						CFStringRef headerFieldName = CFSTR("Range");
						CFStringRef headerFieldValue = CFStringCreateWithFormat(NULL, NULL, CFSTR("bytes=%d-%d"), (infoPtr->wtrack.current), (infoPtr->wtrack.offset+streamLength-1));
						CFHTTPMessageSetHeaderFieldValue(myRequest, headerFieldName, headerFieldValue);
						CFRelease(headerFieldValue);
						infoPtr->wtrack.begin = infoPtr->wtrack.current;
						printf("Range %d-%d\n", (infoPtr->wtrack.current), (infoPtr->wtrack.offset+streamLength-1));
					}
				}

				//printf( "-- mLastOffset [%d] -- PresentationByte [%d]\n", infoPtr->mLastOffset, infoPtr->mPresoByte );

				CFStreamClientContext clientContext = { 0, myInfo, NULL, NULL, NULL };
				CFReadStreamRef myReadStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, myRequest);
				CFRelease( myRequest );
				CFRelease( myURL );
				CFRelease( myData );
				//CFReadStreamSetProperty(myReadStream, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue);
				CFOptionFlags myStreamEvents = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered;
				CFReadStreamSetClient( myReadStream, myStreamEvents, mypReadStreamPackets, &clientContext );

				CFReadStreamScheduleWithRunLoop( myReadStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes );
				bool bOpen = CFReadStreamOpen( myReadStream );
				if( bOpen == NO )
				{
					infoPtr->bReconnecting = YES;
				}
				else
				{
					infoPtr->bReconnecting = NO;
				}

				infoPtr->iReadTimeout = 0;
				int maxTimeout = 125;
				if( _tracklist.autoshuffle == YES )
				{
					maxTimeout = 1250;
				}
				if( _tracklist.podcasting ) maxTimeout = 20;
				do
				{
					CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
					infoPtr->iReadTimeout++;
					if( infoPtr->windex > infoPtr->rindex + 1 && _tracklist.recording == false && sweeper == NO )
					{
						break;
					}
					if( infoPtr->wtrack.length > 0 && infoPtr->wtrack.current - infoPtr->wtrack.offset == infoPtr->wtrack.length )
					{
						break;
					}
					if( infoPtr->wtrack.length > 0 && infoPtr->wtrack.current - infoPtr->wtrack.offset == streamLength )
					{
						break;
					}
				} while ( !infoPtr->bDoneNetworkStream && (infoPtr->iReadTimeout < maxTimeout) && !infoPtr->bReconnectTrigger && !infoPtr->bReconnecting && !infoPtr->wtrack.redirecting && infoPtr->wswitcher == -1 );
				
				if( _tracklist.podcasting == YES && infoPtr->iReadTimeout == maxTimeout )
				{	
					if( infoPtr->wtrack.begin == infoPtr->wtrack.current )
					{
						NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
						CFHTTPMessageRef msgRespuesta = (CFHTTPMessageRef) CFReadStreamCopyProperty(myReadStream, kCFStreamPropertyHTTPResponseHeader);
						NSData *therequest = (NSData *) CFHTTPMessageCopySerializedMessage(msgRespuesta);
						NSString *dataresponse = [[[NSString alloc] initWithData:therequest encoding:NSUTF8StringEncoding] autorelease];
						[infoPtr->myPlayer parsefcResponse:dataresponse];
						[therequest release];
						[pool release];
					}
				}
				
				infoPtr->iReadTimeout = 0;
				infoPtr->bReconnectTrigger = NO;
				if( bOpen == YES )
				{
					//printf( "-- SERVER CONNECTION CLOSED [%X]\n", infoPtr );
					CFReadStreamUnscheduleFromRunLoop( myReadStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes );
					CFReadStreamSetClient( myReadStream, myStreamEvents, NULL, &clientContext );
					CFReadStreamClose( myReadStream );
					CFRelease( myReadStream );
				}
				
				if( lasttime == infoPtr->wtrack.current )
				{
					if( infoPtr->bStarving == YES || infoPtr->windex == infoPtr->rindex )retries++;
					CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.25, false);
					if( retries > 5 && infoPtr->bStarving==YES) [[PlayingView currentPlayingView] performSelectorOnMainThread:@selector(onCantConnect:) withObject:nil waitUntilDone:NO];
				}
				else
				{
					retries = 0;
				}
				
				if( infoPtr->wtrack.unsupported == YES && infoPtr->wtrack.current > 0 && infoPtr->wtrack.current < infoPtr->wtrack.length )
				{
					infoPtr->wtrack.length = infoPtr->wtrack.current;
					[[PlayingView currentPlayingView] performSelectorOnMainThread:@selector(onUnsupported:) withObject:nil waitUntilDone:NO];
				}				
				
				if( _tracklist.autoshuffle == YES && lasttime != infoPtr->wtrack.current )
				{
					infoPtr->wtrack.length = (infoPtr->wtrack.current - infoPtr->wtrack.offset);
					[self closewritefile:infoPtr->wtrack];
					infoPtr->wtrack.buffered = YES;
					infoPtr->wtrack.cached = YES;
					infoPtr->wtrack.seconds = infoPtr->wtrack.length / infoPtr->wtrack.bitrate / 128;
					infoPtr->wtrack = nil;
					infoPtr->windex++;
					
					//[infoPtr->myApp.playingViewController processEvent:EVENT_TRACKCACHED forIndex:infoPtr->windex];
					[[PlayingView currentPlayingView] processEvent:EVENT_TRACKCACHED forIndex:infoPtr->windex];
				}
			}
		} while ( !infoPtr->bDoneNetworkStream );
	}
	else
	{
		XMLTrack *temp = (XMLTrack *) [_tracklist.children objectAtIndex:0];
		NSRange range = [temp.mediaurl rangeOfString:@".aacp"];
		if( ( range.length == 5 && range.location == [temp.mediaurl length] - 5 ) )
		{
			audioType = kAudioFileAAC_ADTSType;
		}
		
		if( infoPtr->mAudioFileStream == nil )
		{
			AudioFileStreamOpen( myInfo, mypFileStreamProperties, mypFileStreamPackets, audioType, &infoPtr->mAudioFileStream );
			//printf( "-- AUDIO FILE OPENED [%X]\n", infoPtr );
		}
		
		do {
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
		} while ( !infoPtr->bCacheReady );
		
		pthread_mutex_lock(&infoPtr->mutex);
		pthread_cond_signal(&infoPtr->cond);
		pthread_mutex_unlock(&infoPtr->mutex);
		
		do {
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
		} while ( !infoPtr->bDoneNetworkStream );
	}

	infoPtr->bDoneFileStream = YES;

	do {
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
	} while ( !infoPtr->bDoneFileStream );
	//printf( "-- AUDIO FILE DONE [%X]\n", infoPtr );

	if( infoPtr->mAudioFileStream != nil ) AudioFileStreamClose(infoPtr->mAudioFileStream);
	infoPtr->bDoneAudioStream = YES;
	//printf( "-- AUDIO FILE CLOSED [%X]\n", infoPtr );

	[[PlayingView currentPlayingView] performSelectorOnMainThread:@selector(stationComplete:) withObject:nil waitUntilDone:NO];
    [pool release];
}

- (void)shoutcastThread:(id)anObject
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	infoPtr->bDataFormat = NO;
	infoPtr->bPacketsReady = NO;
	infoPtr->bStarted = NO;
	infoPtr->bTriggered = NO;
	infoPtr->bCacheReady = NO;
	infoPtr->bPlaying = NO;
	infoPtr->bPrimed = NO;
	infoPtr->bPaused = NO;
	infoPtr->bDoneNetworkStream = NO;
	infoPtr->bDoneFileStream = NO;
	infoPtr->bDoneAudioStream = NO;
	infoPtr->bThreaded = NO;
	infoPtr->mPacketCount = 0;
	infoPtr->bShoutcast = YES;
	infoPtr->bCleaned = NO;
	//infoPtr->bLive = NO;
	infoPtr->iReadMode = 0;
	infoPtr->iMetaRead = 0;
	infoPtr->mLastOffset = 0;
	infoPtr->mConnOffset = 0;
	infoPtr->mCachedByte = 0;
	infoPtr->mAudioFileStream = nil;
	infoPtr->bReconnecting = NO;
	infoPtr->bConserving = NO;
	infoPtr->bMarked = NO;
	infoPtr->bStarving = NO;
	infoPtr->bReconnectTrigger = NO;
	infoPtr->mBytesFilled = 0;
	infoPtr->mBytesCached = 0;
	infoPtr->mBytesPlayed = 0;
	infoPtr->mPacketsFilled = 0;
	infoPtr->mBitRate = _tracklist.bitrate;
	//infoPtr->mCurrentData = [[Data alloc] init];
	//infoPtr->mCurrentData.buffer = new UInt8[DATA_QUEUE_BUFFER_SIZE];
	if( infoPtr->mBitRate == 0 ) infoPtr->mBitRate = 128;
	infoPtr->rswitcher = -1;
	infoPtr->wswitcher = -1;
	infoPtr->radjuster = -1;
	infoPtr->wtrack = nil;
	infoPtr->rtrack = nil;

	infoPtr->windex = _tracklist.startindex;
	infoPtr->rindex = _tracklist.startindex;
	do
	{
		if( !infoPtr->bDoneNetworkStream )
		{
			if( infoPtr->wtrack == nil )
			{
				infoPtr->wtrack = (XMLTrack *) [_tracklist.children objectAtIndex:infoPtr->windex];
			}

			NSString *mirrorurl = infoPtr->wtrack.mediaurl;
			if( infoPtr->wtrack.redirecting == YES ) mirrorurl = infoPtr->wtrack.redirect;
			//printf("MIRROR URL %s\r\n", [mirrorurl cStringUsingEncoding:NSASCIIStringEncoding]);

			const UInt8 bodyData = 0;
			CFStringRef url = (CFStringRef) mirrorurl;
			CFURLRef myURL = CFURLCreateWithString(kCFAllocatorDefault, url, NULL);
			CFStringRef requestMethod = CFSTR("GET");
			CFHTTPMessageRef myRequest = CFHTTPMessageCreateRequest(kCFAllocatorDefault, requestMethod, myURL, kCFHTTPVersion1_1);
			CFDataRef myData = CFDataCreate(NULL, &bodyData, 0);
			CFHTTPMessageSetBody(myRequest, myData);

			CFStringRef headerFieldName = CFSTR("Icy-MetaData");
			CFStringRef headerFieldValue = CFSTR("1 ");
			CFHTTPMessageSetHeaderFieldValue(myRequest, headerFieldName, headerFieldValue);
			CFRelease(headerFieldValue);
			headerFieldName = CFSTR("User-Agent");
			headerFieldValue = CFSTR("WinampMPEG/5.35");
			CFHTTPMessageSetHeaderFieldValue(myRequest, headerFieldName, headerFieldValue);
			CFRelease(headerFieldValue);

			CFStreamClientContext clientContext = { 0, myInfo, NULL, NULL, NULL };
			CFReadStreamRef myReadStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, myRequest);
			CFRelease( myRequest );
			CFRelease( myURL );
			CFRelease( myData );
			CFReadStreamSetProperty(myReadStream, kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanTrue);
			CFOptionFlags myStreamEvents = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered;
			CFReadStreamSetClient( myReadStream, myStreamEvents, mypReadShoutcastPackets, &clientContext );

			CFReadStreamScheduleWithRunLoop( myReadStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes );
			bool bOpen = CFReadStreamOpen( myReadStream );
			if( bOpen == NO )
			{
				infoPtr->bReconnecting = YES;
			}
			else
			{
				//printf( "-- SERVER CONNECTION OPEN [%X]\n", infoPtr );
				if( infoPtr->mAudioFileStream == nil )
				{
					AudioFileStreamOpen( myInfo, mypFileStreamProperties, mypFileStreamPackets, kAudioFileMP3Type, &infoPtr->mAudioFileStream );
					//printf( "-- AUDIO FILE OPENED [%X]\n", infoPtr );
				}

				infoPtr->bReconnecting = NO;
			}

			do {
				CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
			} while ( !infoPtr->bDoneNetworkStream && !infoPtr->bReconnecting && infoPtr->wswitcher == -1 );

			if( bOpen == YES )
			{
				//printf( "-- SERVER CONNECTION CLOSED [%X]\n", infoPtr );
				CFReadStreamUnscheduleFromRunLoop( myReadStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes );
				CFReadStreamSetClient( myReadStream, myStreamEvents, NULL, &clientContext );
				CFReadStreamClose( myReadStream );
				CFRelease( myReadStream );
			}
		}
	} while ( !infoPtr->bDoneNetworkStream );

	infoPtr->bDoneFileStream = YES;

	do {
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
	} while ( !infoPtr->bDoneFileStream );

	AudioFileStreamClose(infoPtr->mAudioFileStream);
	infoPtr->bDoneAudioStream = YES;
	//printf( "-- AUDIO FILE CLOSED [%X]\n", infoPtr );

	[[PlayingView currentPlayingView] performSelectorOnMainThread:@selector(shoutcastComplete:) withObject:nil waitUntilDone:NO];
    [pool release];
}

- (void)switchtrack:(int)index
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	infoPtr->rswitcher = index;
	if( infoPtr->windex != index ) infoPtr->wswitcher = index;

	if( bPaused == YES )
	{
		AudioQueueStart(infoPtr->mQueue, NULL);
		bPaused = NO;
	}	

	pthread_mutex_lock(&infoPtr->mutex);
	pthread_cond_signal(&infoPtr->cond);
	pthread_mutex_unlock(&infoPtr->mutex);
	
	bPaused = NO;
}

- (void)adjusttrack:(int)time
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
	infoPtr->radjuster = time;
}

- (void)showInterstitial:(id)sender
{
	//printf("showInterstitial\n");
	PlayingView *playingView = [PlayingView currentPlayingView];
	BusyView *busyView = playingView.busyView;
	[playingView showBusy:YES withAd:NO];
	if( _nextAd.googleaudio == NO )
		[busyView inter:_nextAd];
	else
		[busyView performSelectorOnMainThread:@selector(googleaudio:) withObject:_nextAd waitUntilDone:NO];
}

- (void)cachingThread:(id)anObject
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	pthread_mutex_lock(&infoPtr->mutex);
	while( !infoPtr->bDoneNetworkStream )
	{
		infoPtr->bCacheReady = YES;
		pthread_cond_wait(&infoPtr->cond, &infoPtr->mutex);
		NSData *data = nil;
		int length = 0;

		if( infoPtr->bDoneNetworkStream == YES ) continue;
		
		if( infoPtr->rswitcher != -1 )
		{
			[self closereadfile:infoPtr->rtrack];
			infoPtr->rindex = infoPtr->rswitcher;
			infoPtr->rswitcher = -1;
			infoPtr->rtrack = (XMLTrack *) [_tracklist.children objectAtIndex:infoPtr->rindex];
			infoPtr->rtrack.readoff = 0;
			infoPtr->rtrack.roffset = infoPtr->rtrack.readoff;
			infoPtr->rtrack.delayed = NO;
			infoPtr->rtrack.listened = YES;
			_tracklist.startindex = infoPtr->rindex;
			[self openreadfile:infoPtr->rtrack];
			
			if( infoPtr->rindex + 1 < [_tracklist.children count] )
			{
				XMLTrack *ttemp = (XMLTrack *) [_tracklist.children objectAtIndex:infoPtr->rindex + 1];
				ttemp.delayed = NO;
				ttemp.listened = YES;
			}
			[[PlayingView currentPlayingView] processEvent:EVENT_TRACKPLAYING forIndex:infoPtr->rindex];
			
			//printf( "-- cachingThread -- [%d] of [%d]\n", infoPtr->rtrack.readoff, infoPtr->rtrack.length);
			
			int secs = ( ( infoPtr->rtrack.woffset - infoPtr->rtrack.offset ) - infoPtr->rtrack.roffset ) / 128 / infoPtr->rtrack.bitrate;
			if( secs < 8 && infoPtr->rtrack.cached == NO )
			{
				infoPtr->bStarving = YES;
			}
			else
			{
				if( bPaused == YES )
				{
					AudioQueueStart(infoPtr->mQueue, NULL);
					bPaused = NO;
				}
				else
				{
					AudioQueueFlush(infoPtr->mQueue);
				}
				
				[[PlayingView currentPlayingView] processEvent:EVENT_TRACKPLAYING forIndex:infoPtr->rindex];
				[[PlayingView currentPlayingView] performSelectorOnMainThread:@selector(onBuffered:) withObject:nil waitUntilDone:NO];
			}
		}

		[infoPtr->bufferLock lock];
		int bufcount = [infoPtr->buffers count] - 1;
		[infoPtr->bufferLock unlock];

		//printf( "-- \t\tcachingThread [%d]\n", bufcount );
		if( bufcount <= 0 && infoPtr->bTriggered == YES ) continue;
		if( bLocked == YES )
		{
			if( bufcount == AUDIO_QUEUE_BUFFER_COUNT - 2 && bInter == NO )
			{
				bInter = YES;
				AudioQueuePause(infoPtr->mQueue);
				[self performSelectorOnMainThread:@selector(showInterstitial:) withObject:nil waitUntilDone:NO];
			}
			
			continue;
		}
		//printf( "-- cachingThread -- buf count [%d]\n", bufcount );
		//printf( "-- \t\t\tcachingThread AFTER [%d] [%d] [%d]\n", [infoPtr->buffers count], [infoPtr->packets count], infoPtr->mLastOffset );

		if( infoPtr->rtrack != nil && infoPtr->rtrack.length > 0 && infoPtr->rtrack.readoff >= infoPtr->rtrack.length )
		{
			[self closereadfile:infoPtr->rtrack];
			infoPtr->rtrack = nil;
			infoPtr->rindex++;
			
			BOOL bHidden = [[PlayingView currentPlayingView] isHiding];
			if( _nextAd != nil && bHidden == NO )
			{				
				bLocked = YES;
				continue;
			}
		}

		if( infoPtr->rtrack == nil && infoPtr->rindex < [_tracklist.children count])
		{
			infoPtr->rtrack = (XMLTrack *) [_tracklist.children objectAtIndex:infoPtr->rindex];
			infoPtr->rtrack.delayed = NO;
			infoPtr->rtrack.listened = YES;
			
			if( infoPtr->rtrack.flylive == YES ) [[PlayingView currentPlayingView] processEvent:EVENT_TRACKUPDATED forIndex:infoPtr->rindex];
		}
		if( infoPtr->rindex + 1 < [_tracklist.children count])
		{
			XMLTrack *temp = (XMLTrack *) [_tracklist.children objectAtIndex:(infoPtr->rindex+1)];
			temp.delayed = NO;
			temp.listened = YES;
		}
		if( infoPtr->rtrack == nil || infoPtr->rtrack.buffered == NO ) continue;

		if( infoPtr->rtrack.rmediafile == nil )
		{
			if( _tracklist.startindex != infoPtr->rindex )
				infoPtr->rtrack.resuming = NO;
			_tracklist.startindex = infoPtr->rindex;
			[self openreadfile:infoPtr->rtrack];
			[[PlayingView currentPlayingView] processEvent:EVENT_TRACKPLAYING forIndex:infoPtr->rindex];
			if( infoPtr->rtrack.rmediafile == nil )
				[[PlayingView currentPlayingView] performSelectorOnMainThread:@selector(onFail:) withObject:@"Error playing station. Please try again later" waitUntilDone:NO];
		}

		do
		{
			if( infoPtr->rswitcher != -1 ) break;

			if( infoPtr->radjuster != -1 )
			{
				infoPtr->rtrack.readoff += (infoPtr->radjuster * infoPtr->rtrack.bitrate * 128);
				if( infoPtr->rtrack.readoff < 0 )
					infoPtr->rtrack.readoff = 0;
				else if( infoPtr->rtrack.readoff > (infoPtr->rtrack.current - infoPtr->rtrack.offset) )
					infoPtr->rtrack.readoff = (infoPtr->rtrack.current - infoPtr->rtrack.offset) - (5 * infoPtr->rtrack.bitrate * 128);
				else if( infoPtr->rtrack.readoff > infoPtr->rtrack.length )
					infoPtr->rtrack.readoff = infoPtr->rtrack.length - (5 * infoPtr->rtrack.bitrate * 128);

				[infoPtr->fileLock lock];
				[infoPtr->rtrack.rmediafile seekToFileOffset:(infoPtr->rtrack.readoff)];
				[infoPtr->fileLock unlock];
				AudioQueueFlush(infoPtr->mQueue);

				infoPtr->radjuster = -1;
				[[PlayingView currentPlayingView] performSelectorOnMainThread:@selector(onSkipDone:) withObject:nil waitUntilDone:NO];
			}

			length = 0;
			[infoPtr->fileLock lock];
			
			NSAutoreleasePool *pool2 = [[NSAutoreleasePool alloc] init];
			//[infoPtr->track.rmediafile seekToFileOffset:(infoPtr->track.readoff)];
			data = [infoPtr->rtrack.rmediafile readDataOfLength:DATA_QUEUE_BUFFER_SIZE];
			[infoPtr->fileLock unlock];
			length = [data length];

			//printf( "-- cachingThread -- [%d] of [%d]\n", infoPtr->rtrack.readoff, infoPtr->rtrack.length);
			if( length > 0 )
			{
				bufcount--;
				infoPtr->rtrack.readoff += length;
				UInt8 *bytes = (UInt8 *) [data bytes];

				//printf( "-- \t\t\t\t\tcachingThread [%d]\n", [infoPtr->buffers count] );
				OSStatus ret = AudioFileStreamParseBytes(infoPtr->mAudioFileStream, length, bytes, 0);
				if( ret != 0 )
				{
				}
				//[data release];
				//printf( "-- AudioFileStreamParseBytes (cachingThread)-- [%d]\n", [data retainCount]);
			}
			else if( bOffline == NO )
			{
				printf( "-- cachingThread -- STARVING\n");
				AudioQueuePause(infoPtr->mQueue);
				infoPtr->bStarving = YES;
				CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5.0, false);
				if( infoPtr->bStarving == YES )
				{
					infoPtr->bReconnectTrigger = YES;
					[[PlayingView currentPlayingView] performSelectorOnMainThread:@selector(onStarving:) withObject:nil waitUntilDone:NO];
				}
			}
			infoPtr->rtrack.roffset = infoPtr->rtrack.readoff;
			
			[pool2 release];			
			/*
			if( infoPtr->bTriggered == NO )
			{
				infoPtr->bTriggered = YES;
				CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.3, false);
			}
			//*/
		} while (length > 0 && bufcount > 0 && infoPtr->rtrack.readoff < infoPtr->rtrack.length);
	}
	pthread_mutex_unlock(&infoPtr->mutex);

    [pool release];
}

- (void)audioThread:(id)anObject
{
	AQTestInfo *infoPtr = (AQTestInfo*) myInfo;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	OSStatus retVal;
	UInt32 size;
	int count = 0;

	//printf( "-- AUDIO PREPARE [%X]\n", infoPtr );
	size = sizeof(infoPtr->mDataFormat);
	retVal = AudioFileStreamGetProperty(infoPtr->mAudioFileStream, kAudioFileStreamProperty_DataFormat, &size, &infoPtr->mDataFormat);
	retVal = AudioQueueNewOutput(&infoPtr->mDataFormat, mypAudioQueuePackets, myInfo, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &infoPtr->mQueue);
	retVal = AudioQueueSetParameter(infoPtr->mQueue, kAudioQueueParam_Volume, fVolume);

	[infoPtr->bufferLock lock];
	for (int i = 0; i < AUDIO_QUEUE_BUFFER_COUNT; ++i)
	{
		retVal = AudioQueueAllocateBuffer(infoPtr->mQueue, AUDIO_QUEUE_BUFFER_SIZE, &infoPtr->mAudioBuffers[i]);
		Buffer *buff = [[Buffer alloc] init];
		buff.handle = infoPtr->mAudioBuffers[i];
		[infoPtr->buffers addObject:buff];
	}
	[infoPtr->bufferLock unlock];
	infoPtr->bStarted = YES;
	printf( "-- AUDIO STARTED [%X]\n", (unsigned int)infoPtr );
	
	if( YES || _tracklist.offline == YES )
	{
		pthread_mutex_lock(&infoPtr->mutex);
		pthread_cond_signal(&infoPtr->cond);
		pthread_mutex_unlock(&infoPtr->mutex);
	}

	while( !infoPtr->bPrimed )
	{
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
	}
	bReady = YES;
	//printf( "-- AUDIO PRIMED [%X]\n", infoPtr );

	do
	{
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
	} while ( bPaused );
	CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
	//printf( "-- AUDIO READY [%X]\n", infoPtr );

	AudioQueueStart(infoPtr->mQueue, NULL);
	printf( "-- AUDIO QUEUE STARTED [%X]\n", (unsigned int)infoPtr );

	do
	{
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
	} while ( !infoPtr->bDoneAudioStream );
	//printf( "-- AUDIO DONE [%X]\n", infoPtr );

	if( bLinger == YES ) bLingering = YES;
	do
	{
		CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.2, false);
	} while ( bLinger == YES );
	bLingering = NO;
	//printf( "-- AUDIO LINGERED [%X]\n", infoPtr );

	AudioQueueFlush( infoPtr->mQueue );
	AudioQueueStop( infoPtr->mQueue, NO );
	//printf( "-- AUDIO CLOSED [%X]\n", infoPtr );

	[infoPtr->bufferLock lock];
	count = [infoPtr->buffers count];
	for (int i = 0; i < count; ++i)
	{
		Buffer *temp = (Buffer *) [infoPtr->buffers objectAtIndex:i];
		[temp release];
	}
	for (int i = 0; i < AUDIO_QUEUE_BUFFER_COUNT; ++i)
	{
		retVal = AudioQueueFreeBuffer(infoPtr->mQueue, infoPtr->mAudioBuffers[i]);
	}
	[infoPtr->buffers removeAllObjects];
	[infoPtr->bufferLock unlock];

	AudioQueueDispose( infoPtr->mQueue, YES );

	//[infoPtr->packetLock lock];
	/*
	count = [infoPtr->packets count];
	for (int i = 0; i < count; ++i)
	{
		Packet *temp = (Packet *) [infoPtr->packets objectAtIndex:i];
		[temp release];
	}
	//*/
	//[infoPtr->packets removeAllObjects];
	//[infoPtr->packetLock unlock];

	infoPtr->bCleaned = YES;
	infoPtr->mQueue = nil;
	bPlaying = NO;
	bStopping = NO;
	bReady = NO;
	
	//printf( "-- PLAYER STOPPED [%X]\n", infoPtr );
	[pool release];
}

@end

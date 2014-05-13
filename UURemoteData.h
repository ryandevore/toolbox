//
//  UURemoteData.h
//  Useful Utilities - An extension to Useful Utilities UUDataCache that fetches
//  data from a remote source
//
//	License:
//  You are free to use this code for whatever purposes you desire. The only requirement is that you smile everytime you use it.
//
//  
//  UURemoteData provides a centralized place where application components can request
//  data that may come from a remote source.  It utilizes existing UUDataCache functionality
//  to locally store files for later fetching.  It will intelligently handle multiple requests for the
//  same image so that extraneous network requests are not needed.
//
//
//  NOTE: This class depends on the following toolbox classes:
//
//  UUHttpClient
//  UUDataCache
//
//
//  NOTE NOTE:  This class is currently under development, so the interface and functionality
//              may be subject to change.
//

#import <Foundation/Foundation.h>

// Notification userInfo has two values:
//
// kUUDataRemotePathKey - NSString of the remote path
// kUUDataKey - UIImage
//
extern NSString * const kUUDataDownloadedNotification;
extern NSString * const kUUDataRemotePathKey;
extern NSString * const kUUDataKey;

@interface UURemoteData : NSObject

+ (instancetype) sharedInstance;

// Attempts to fetch remote data.  If the data exists locally in UUDataCache, it will return
// immediately.  If nil is returned, there is no local copy of the resource, and it indicates
// a remote request has either been started or is already in progress.
- (NSData*) dataForPath:(NSString*)path;

@end
//
//  UUHttpBackgroundSession.h
//

@import Foundation;

// Block callback used by application delegate callbacks
typedef void (^UUBackgroundSessionHandler)();
typedef void (^UUTaskResponseHandler)(id response, NSError* error);

// UUHttpSession
//
//
@interface UUHttpBackgroundSession : NSObject

+ (NSURLSessionTask*) get:(NSURL*)remoteUrl completion:(UUTaskResponseHandler)completion;
+ (NSURLSessionTask*) post:(NSURL*)remoteUrl file:(NSURL*)localFile completion:(UUTaskResponseHandler)completion;
+ (NSURLSessionTask*) put:(NSURL*)remoteUrl file:(NSURL*)localFile completion:(UUTaskResponseHandler)completion;

// Let's the App Delegate just directly proxy this callback here
+ (void) handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(UUBackgroundSessionHandler)completionHandler;

@end




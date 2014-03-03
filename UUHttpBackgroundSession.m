//
//  UUHttpBackgroundSession.m
//

#import "UUHttpBackgroundSession.h"

//If you want to provide your own logging mechanism, define UUDebugLog in your .pch
#ifndef UUDebugLog
#ifdef DEBUG
#define UUDebugLog(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#else
#define UUDebugLog(fmt, ...)
#endif
#endif

@interface UUHttpBackgroundSession () <NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSMutableDictionary* completionHandlerDictionary;
@property (nonatomic, strong) NSMutableDictionary* taskCompletionDictionary;

@end

@implementation UUHttpBackgroundSession

#pragma mark - Singleton Interface

- (NSURLSession*) backgroundSession
{
    /*
     Using disptach_once here ensures that multiple background sessions with the same identifier are not created in this
     instance of the application. If you want to support multiple background sessions within a single process, you should
     create each session with its own identifier.
     */
	static NSURLSession *session = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^
    {
        NSString* sessionIdentifier = @"uu.framework.uuhttpsession-default-background-session";
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfiguration:sessionIdentifier];
        session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    });
    
	return session;
}

+ (instancetype) sharedInstance
{
    static UUHttpBackgroundSession* sharedSession = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^
    {
        sharedSession = [UUHttpBackgroundSession new];
    });
    
    return sharedSession;
}

- (id) init
{
    self = [super init];
    
    if (self)
    {
        self.completionHandlerDictionary = [NSMutableDictionary dictionary];
        self.taskCompletionDictionary = [NSMutableDictionary dictionary];
    }
    
    return self;
}

+ (NSURLSessionTask*) get:(NSURL*)remoteUrl completion:(UUTaskResponseHandler)completion
{
    NSMutableURLRequest* req = [[NSMutableURLRequest alloc] initWithURL:remoteUrl];
    [req setHTTPMethod:@"GET"];
    
    UUHttpBackgroundSession* uuSession = [self sharedInstance];
    NSURLSessionDownloadTask* task = [[uuSession backgroundSession] downloadTaskWithRequest:req];
    [uuSession storeTaskCompletionHandler:completion forTask:task];
    [task resume];
    return task;
}

+ (NSURLSessionTask*) post:(NSURL*)remoteUrl file:(NSURL*)localFile completion:(UUTaskResponseHandler)completion
{
    return nil;
}

+ (NSURLSessionTask*) put:(NSURL*)remoteUrl file:(NSURL*)localFile completion:(UUTaskResponseHandler)completion
{
    return nil;
}

// Let's the App Delegate just directly proxy this callback here
+ (void) handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(UUBackgroundSessionHandler)completionHandler
{
    // Call this to create the background session object if needed.  On an app background launch, the docs indicate that
    // just by re-creating the session with the same identifier, it will resume getting delegate callbacks.
    UUDebugLog(@"Re-creating session %@", identifier);
    [[self sharedInstance] backgroundSession];
    
    // Keep the block around until URLSessionDidFinishEventsForBackgroundURLSession is called
    [[self sharedInstance] storeCompletionHandler:completionHandler forSession:identifier];
}

#pragma mark - Stored Completion Block Helpers

- (void) storeCompletionHandler:(UUBackgroundSessionHandler)handler forSession:(NSString*)identifier
{
    if ([self.completionHandlerDictionary objectForKey:identifier])
    {
        UUDebugLog(@" ******* Error: Got multiple handlers for a single session identifier.  This should not happen. ******* ");
    }
    
    [self.completionHandlerDictionary setObject:handler forKey:identifier];
}

- (void) callCompletionHandlerForSession:(NSString*) identifier
{
    UUBackgroundSessionHandler handler = [self.completionHandlerDictionary objectForKey: identifier];
    
    if (handler)
    {
        [self.completionHandlerDictionary removeObjectForKey: identifier];
        UUDebugLog(@"Calling completion handler.");
        
        handler();
    }
}

- (void) storeTaskCompletionHandler:(UUTaskResponseHandler)handler forTask:(NSURLSessionTask*)task
{
    NSString* identifier = [NSString stringWithFormat:@"%d", task.taskIdentifier];
    
    if ([self.taskCompletionDictionary objectForKey:identifier])
    {
        UUDebugLog(@" ******* Error: Multiple handlers for a task, this should not be possible! ******* ");
    }
    
    [self.taskCompletionDictionary setObject:handler forKey:identifier];
}

- (void) callTaskCompletionHandlerForTask:(NSURLSessionTask*)task response:(id)response error:(NSError*)error
{
    NSString* identifier = [NSString stringWithFormat:@"%d", task.taskIdentifier];
    
    UUTaskResponseHandler handler = [self.taskCompletionDictionary objectForKey:identifier];
    
    if (handler)
    {
        [self.taskCompletionDictionary removeObjectForKey:identifier];
        handler(response, error);
    }
}

#pragma mark - NSURLSessionDelegate

/* If an application has received an
 * -application:handleEventsForBackgroundURLSession:completionHandler:
 * message, the session delegate will receive this message to indicate
 * that all messages previously enqueued for this session have been
 * delivered.  At this time it is safe to invoke the previously stored
 * completion handler, or to begin any internal updates that will
 * result in invoking the completion handler.
 */
-(void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession*)session
{
    UUDebugLog(@"Background URL session %@ finished events.", session);
    
    if (session.configuration.identifier)
    {
        [self callCompletionHandlerForSession:session.configuration.identifier];
    }
}

#pragma mark - NSURLSessionTaskDelegate

/* Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    UUDebugLog(@"Session Complete\nSession: %@\nTask URL: %@\nerror: %@", session.configuration.identifier, task.response.URL, error);
    [self callCompletionHandlerForSession:session.configuration.identifier];
    [self callTaskCompletionHandlerForTask:task response:nil error:error];
}

#pragma mark - NSURLSessionDownloadDelegate

/* Sent when a download task that has completed a download.  The delegate should
 * copy or move the file at the given location to a new location as it will be
 * removed when the delegate message returns. URLSession:task:didCompleteWithError: will
 * still be called.
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location
{
    UUTrace();
    
    NSData* data = [[NSData alloc] initWithContentsOfURL:location];
    UUDebugLog(@"Downloaded %d bytes", data.length);
    
    id parsedResponse = [self parseResponse:data response:downloadTask.response];
    [self callTaskCompletionHandlerForTask:downloadTask response:parsedResponse error:nil];
}

/* Sent periodically to notify the delegate of download progress. */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    // Default implementation does nothing here
}

/* Sent when a download has been resumed. If a download failed with an
 * error, the -userInfo dictionary of the error will contain an
 * NSURLSessionDownloadTaskResumeData key, whose value is the resume
 * data.
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes
{
    // Default implementation does nothing here
}

#pragma mark - Private Methods

+ (NSString*) uuidString
{
    NSString* result = nil;
    
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef uuidStr = CFUUIDCreateString(NULL, uuid);
	result = [NSString stringWithFormat:@"%@", uuidStr];
    CFRelease(uuidStr);
    CFRelease(uuid);
    
    return result;
}

+ (NSString*) pathForTempUploadFile
{
    NSString* uuid = [self uuidString];
    NSString* homeDir = NSHomeDirectory();
    NSString* libDir = [homeDir stringByAppendingPathComponent:@"Library"];
    NSString* tempDir = [libDir stringByAppendingPathComponent:@"Temp"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:tempDir isDirectory:nil])
    {
        NSError* err = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&err];
        if (err)
        {
            UUDebugLog(@"Error creating temporary directory: %@", err);
            tempDir = libDir; // Library directory always exists
        }
    }
    NSString* path = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.tmp", uuid]];
    return path;
}


- (NSString*) toJsonString:(id)object
{
    NSError* err = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:object options:0 error:&err]; //NSJSONWritingPrettyPrinted
    if (err != nil)
    {
        UUDebugLog(@"Failed to serialize to json, err: %@", err);
        return nil;
    }
    
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (id) parseResponse:(NSData*)rxBuffer response:(NSURLResponse*)response
{
    if ([@"application/json" isEqualToString:response.MIMEType] ||
        [@"text/json" isEqualToString:response.MIMEType])
    {
        NSError* err = nil;
        id obj = [NSJSONSerialization JSONObjectWithData:rxBuffer options:0 error:&err];
        if (err != nil)
        {
            UUDebugLog(@"Error derializing JSON: %@", err);
            return nil;
        }
        
        if (obj == nil)
        {
            UUDebugLog(@"JSON deserialization returned success but a nil object!");
        }
        
        return obj;
    }
    else
    {
        return rxBuffer;
    }
}


@end


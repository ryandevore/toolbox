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
@property (nonatomic, strong) NSMutableDictionary* taskRxBufferDictionary;

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
        self.taskRxBufferDictionary = [NSMutableDictionary dictionary];
    }
    
    return self;
}

+ (NSURLSessionTask*) get:(NSURL*)remoteUrl completion:(UUTaskResponseHandler)completion
{
    NSMutableURLRequest* req = [[NSMutableURLRequest alloc] initWithURL:remoteUrl];
    [req setHTTPMethod:@"GET"];
    
    UUDebugLog(@"%@ %@", req.HTTPMethod, remoteUrl);
    UUHttpBackgroundSession* uuSession = [self sharedInstance];
    NSURLSessionTask* task = [[uuSession backgroundSession] downloadTaskWithRequest:req];
    [uuSession storeTaskCompletionHandler:completion forTask:task];
    [task resume];
    return task;
}

+ (NSURLSessionTask*) post:(NSURL*)remoteUrl file:(NSURL*)localFile completion:(UUTaskResponseHandler)completion
{
    NSMutableURLRequest* req = [[NSMutableURLRequest alloc] initWithURL:remoteUrl];
    [req setHTTPMethod:@"POST"];
    [req addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    UUDebugLog(@"%@ %@", req.HTTPMethod, remoteUrl);
    UUHttpBackgroundSession* uuSession = [self sharedInstance];
    NSURLSessionTask* task = [[uuSession backgroundSession] uploadTaskWithRequest:req fromFile:localFile];
    [uuSession storeTaskCompletionHandler:completion forTask:task];
    [task resume];
    return task;
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
    NSString* identifier = [NSString stringWithFormat:@"%lu", (unsigned long)task.taskIdentifier];
    
    if ([self.taskCompletionDictionary objectForKey:identifier])
    {
        UUDebugLog(@" ******* Error: Multiple handlers for a task, this should not be possible! ******* ");
    }
    
    [self.taskCompletionDictionary setObject:handler forKey:identifier];
}

- (void) callTaskCompletionHandlerForTask:(NSURLSessionTask*)task response:(id)response error:(NSError*)error
{
    NSString* identifier = [NSString stringWithFormat:@"%lu", (unsigned long)task.taskIdentifier];
    
    UUTaskResponseHandler handler = [self.taskCompletionDictionary objectForKey:identifier];
    
    if (handler)
    {
        [self.taskCompletionDictionary removeObjectForKey:identifier];
        [self.taskRxBufferDictionary removeObjectForKey:identifier];
        handler(response, error);
    }
}

- (NSMutableData*) rxBufferForTask:(NSURLSessionTask*)task
{
    NSString* identifier = [NSString stringWithFormat:@"%lu", (unsigned long)task.taskIdentifier];
    NSMutableData* buffer = [self.taskRxBufferDictionary objectForKey:identifier];
    if (!buffer)
    {
        buffer = [NSMutableData data];
        [self.taskRxBufferDictionary setObject:buffer forKey:identifier];
    }
    
    return buffer;
}

#pragma mark - NSURLSessionDelegate


/* The last message a session receives.  A session will only become
 * invalid because of a systemic error or when it has been
 * explicitly invalidated, in which case it will receive an
 * { NSURLErrorDomain, NSURLUserCanceled } error.
 */
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    UUDebugLog(@"session: %@, error: %@", session.configuration.identifier, error);
}

/* If implemented, when a connection level authentication challenge
 * has occurred, this delegate will be given the opportunity to
 * provide authentication credentials to the underlying
 * connection. Some types of authentication will apply to more than
 * one request on a given connection to a server (SSL Server Trust
 * challenges).  If this delegate message is not implemented, the
 * behavior will be to use the default handling, which may involve user
 * interaction.
 */
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    UUDebugLog(@"session: %@", session.configuration.identifier);
}

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
    UUDebugLog(@"Background URL session %@ finished events.", session.configuration.identifier);
    
    if (session.configuration.identifier)
    {
        [self callCompletionHandlerForSession:session.configuration.identifier];
    }
}

#pragma mark - NSURLSessionTaskDelegate

/* An HTTP request is attempting to perform a redirection to a different
 * URL. You must invoke the completion routine to allow the
 * redirection, allow the redirection with a modified request, or
 * pass nil to the completionHandler to cause the body of the redirection
 * response to be delivered as the payload of this request. The default
 * is to follow redirections.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler
{
    UUDebugLog(@"taskId: %lu, response.URL: %@, request.URL: %@", (unsigned long)task.taskIdentifier, response.URL, request.URL);
}

/* The task has received a request specific authentication challenge.
 * If this delegate is not implemented, the session specific authentication challenge
 * will *NOT* be called and the behavior will be the same as using the default handling
 * disposition.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    UUDebugLog(@"taskId: %lu", (unsigned long)task.taskIdentifier);
}

/* Sent if a task requires a new, unopened body stream.  This may be
 * necessary when authentication has failed for any request that
 * involves a body stream.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
 needNewBodyStream:(void (^)(NSInputStream *bodyStream))completionHandler
{
    UUDebugLog(@"taskId: %lu", (unsigned long)task.taskIdentifier);
}

/* Sent periodically to notify the delegate of upload progress.  This
 * information is also available as properties of the task.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    UUDebugLog(@"taskId: %lu, bytesSent: %lld, totalBytesSent: %lld, totalBytesExpectedToSend: %lld",
               (unsigned long)task.taskIdentifier, bytesSent, totalBytesSent, totalBytesExpectedToSend);
}

/* Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete.
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    UUDebugLog(@"Session Complete\nSession: %@\nTask URL: %@\nTask ID: %lu\nerror: %@", session.configuration.identifier, task.response.URL, (unsigned long)task.taskIdentifier, error);
    [self callCompletionHandlerForSession:session.configuration.identifier];
    
    NSMutableData* buffer = [self rxBufferForTask:task];
    UUDebugLog(@"Rx Buffer Length: %lu", (unsigned long)buffer.length);
    
    id parsedResponse = [self parseResponse:buffer response:task.response];
    UUDebugLog(@"Parsed Response Class: %@", [parsedResponse class]);
    
    [self callTaskCompletionHandlerForTask:task response:parsedResponse error:error];
}

#pragma mark - NSURLSessionDataDelegate

/* The task has received a response and no further messages will be
 * received until the completion block is called. The disposition
 * allows you to cancel a request or to turn a data task into a
 * download task. This delegate message is optional - if you do not
 * implement it, you can get the response as a property of the task.
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    UUDebugLog(@"task: %lu, response: %@", (unsigned long)dataTask.taskIdentifier, response);
}

/* Notification that a data task has become a download task.  No
 * future messages will be sent to the data task.
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask
{
    UUDebugLog(@"dataTask: %lu, downloadTask: %lu", (unsigned long)dataTask.taskIdentifier, (unsigned long)downloadTask.taskIdentifier);
}

/* Sent when data is available for the delegate to consume.  It is
 * assumed that the delegate will retain and not copy the data.  As
 * the data may be discontiguous, you should use
 * [NSData enumerateByteRangesUsingBlock:] to access it.
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    UUDebugLog(@"task: %lu, dataLength: %lu", (unsigned long)dataTask.taskIdentifier, (unsigned long)data.length);
    
    NSMutableData* buffer = [self rxBufferForTask:dataTask];
    [buffer appendData:data];
}

/* Invoke the completion routine with a valid NSCachedURLResponse to
 * allow the resulting data to be cached, or pass nil to prevent
 * caching. Note that there is no guarantee that caching will be
 * attempted for a given resource, and you should not rely on this
 * message to receive the resource data.
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler
{
    UUTrace();
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
    UUDebugLog(@"task: %lu, location: %@", (unsigned long)downloadTask.taskIdentifier, location);
    
    NSURL* destUrl = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[location lastPathComponent]]];
    UUDebugLog(@"Copying downloaded file to: %@", destUrl);
    NSError* err = nil;
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:destUrl error:&err];
    if (err)
    {
        UUDebugLog(@"There was a problem copying downloaded data! Error: %@", err);
    }
    
    NSMutableDictionary* md = [NSMutableDictionary dictionary];
    [md setValue:err forKey:@"error"];
    [md setValue:destUrl forKey:@"destUrl"];
    [md setValue:location forKey:@"sourceUrl"];
    [md setValue:downloadTask forKey:@"task"];
    
    //UUDebugLog(@"%@", location);
    //NSData* data = [[NSData alloc] initWithContentsOfURL:location];
    //UUDebugLog(@"Downloaded %d bytes", data.length);
    
    //id parsedResponse = [self parseResponse:data response:downloadTask.response];
    [self callTaskCompletionHandlerForTask:downloadTask response:md.copy error:nil];
}

/* Sent periodically to notify the delegate of download progress. */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    // Default implementation does nothing here
    UUDebugLog(@"taskId: %lu, bytesWritten: %lld, totalBytesWritten: %lld, totalBytesExpectedToWrite: %lld",
               (unsigned long)downloadTask.taskIdentifier, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite);
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
    UUDebugLog(@"task: %lu, fileOffset: %lld, expectedTotalBytes: %lld",
               (unsigned long)downloadTask.taskIdentifier, fileOffset, expectedTotalBytes);
}

#pragma mark - Private Methods

/*
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
    NSData* data = [NSJSONSerialization dataWithJSONObject:object options:0 error:&err];
    if (err != nil)
    {
        UUDebugLog(@"Failed to serialize to json, err: %@", err);
        return nil;
    }
    
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}*/

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


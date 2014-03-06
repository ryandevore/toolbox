//
//  UUAppDelegate.m
//  UUHttpClientTester
//
//  Created by Ryan DeVore on 2/28/14.
//  Copyright (c) 2014 Three Jacks Software. All rights reserved.
//

#import "UUAppDelegate.h"
#import "UUHttpBackgroundSession.h"
#import "UUHomeViewController.h"

@interface UUAppDelegate ()

@end

@implementation UUAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    self.window.rootViewController = [UUHomeViewController new];
    
    UUTrace();
    
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    UUTrace();
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    UUTrace();
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    UUTrace();
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    UUTrace();
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    UUTrace();
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
{
    UUTrace();
    
    // Proxy the call to the background session manager
    [UUHttpBackgroundSession handleEventsForBackgroundURLSession:identifier completionHandler:completionHandler];
}

/// Applications with the "fetch" background mode may be given opportunities to fetch updated content in the background or
// when it is convenient for the system. This method will be called in these situations. You should call the
// fetchCompletionHandler as soon as you're finished performing that operation, so the system can accurately estimate its power
// and data cost.
- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler
{   
    [[self class] doBackgroundUploadDownload];
    
    completionHandler(UIBackgroundFetchResultNewData);
}


+ (void) doBackgroundUploadDownload
{
    NSString* fileName = @"testData.dat";
    long fileSize = 1024 * 1000 * 1;
    [self uploadFile:fileName fileSize:fileSize completion:^
     {
         [self downloadFile:fileName];
     }];
}

+ (void) uploadFile:(NSString*)fileName fileSize:(long)fileSize completion:(void (^)())completion
{
    NSURL* uploadFile = [self generateRandomFileOfSize:fileSize];
    
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?fileName=%@", TEST_SERVER_END_POINT, fileName]];
    
    [UUHttpBackgroundSession post:url file:uploadFile completion:^(id response, NSError *error)
     {
         UUDebugLog(@"Upload complete.\nResponse: %@\nError: %@\n", response, error);
         completion();
     }];
}

+ (void) downloadFile:(NSString*)fileName
{
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?fileName=%@", TEST_SERVER_END_POINT, fileName]];
    
    [UUHttpBackgroundSession get:url completion:^(id response, NSError *error)
     {
         UUDebugLog(@"Download complete.\nResponse: %@\nError: %@\n", response, error);
     }];
}

+ (NSURL*) generateRandomFileOfSize:(long)byteSize
{
    NSString* dir = NSTemporaryDirectory();
    NSString* path = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]]];
    path = [path stringByAppendingPathExtension:@"tmp"];
    
    FILE* f = fopen([path UTF8String], "wb");
    
    long written = 0;
    long chunkSize = 1024;
    
    void* buf = malloc(chunkSize);
    
    while (written < byteSize)
    {
        arc4random_buf(buf, chunkSize);
        fwrite(buf, 1, chunkSize, f);
        written += chunkSize;
    }
    
    free(buf);
    
    NSLog(@"path: %@", path);
    return [NSURL fileURLWithPath:path];
}

@end

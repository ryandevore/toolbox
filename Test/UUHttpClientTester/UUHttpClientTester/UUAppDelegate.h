//
//  UUAppDelegate.h
//  UUHttpClientTester
//
//  Created by Ryan DeVore on 2/28/14.
//  Copyright (c) 2014 Three Jacks Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UUAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

+ (void) doBackgroundUploadDownload;

@end

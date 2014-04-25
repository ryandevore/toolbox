//
//  UUSqliteLog.h
//  Useful Utilities - Simple SQLite logger
//
//  Simple Logging utility that will write logging statements to a SQLite database.  This is useful
//  for running long term tests where you cannot be connected to a debugger.
//
//  This class can be used on its own, or it can be subsitituted for a common logging macro
//  like UUDebugLog.
//
//  To make UUDebugLog use this logger, place the following lines in your .pch file:
//
//
// Switch UUDebugLog to use a SQLite based logger
// #import "UUSqliteLog.h"
// #define __UU_FILE__ [[NSString stringWithUTF8String:__FILE__] lastPathComponent]
// #undef UUDebugLog
// #define UUDebugLog(fmt, ...) \
//      [[UUSqliteLog sharedInstance] log:[NSString stringWithFormat:@"%s [%@:%d] - " fmt, __PRETTY_FUNCTION__, __UU_FILE__, __LINE__, ##__VA_ARGS__]]; \
//      NSLog((@"%s [%@:%d] - " fmt), __PRETTY_FUNCTION__, __UU_FILE__, __LINE__, ##__VA_ARGS__);
//
// Defining it as two macros will make any UUDebugLog lines write to the SQLite db, as well as standard NSLog output
//
//

@import Foundation;

@interface UUSqliteLog : NSObject

+ (instancetype) sharedInstance;

- (void) log:(NSString*)text;

- (NSString*) pathToAppLog;
- (NSArray*) readAppLog; // NSArray of NSDictionary, two keys, 'timestamp' (NSNumber) and 'msg' (NSString)

@end

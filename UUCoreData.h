//
//  UUCoreData.h
//  Useful Utilities - CoreData helpers
//
//	License:
//  You are free to use this code for whatever purposes you desire. The only requirement is that you smile everytime you use it.
//
//  Contact: @cheesemaker or jon@threejacks.com
//

@import Foundation;
@import CoreData;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// UUCOreData

@interface UUCoreData : NSObject

// Setup the Core Data store. This MUST be called prior to using any other UUCoreData methods
+ (void) configureWithStoreUrl:(NSURL*)storeUrl modelDefinitionBundle:(NSBundle*)bundle;

// Delete's the store at the given URL and sets the shared persistentStoreCoordinator to nil.  After this users
// MUST call configureWithStoreUrl again.
+ (NSError*) destroyStoreAtUrl:(NSURL*)storeUrl;

// Singleton managed object context shared by entire application
+ (NSManagedObjectContext*) mainThreadContext;

// Short lived managed object context for use on background threads
+ (NSManagedObjectContext*) workerThreadContext;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NSManagedObjectContext extensions

@interface NSManagedObjectContext (UUCoreData)

- (BOOL) uuSubmitChanges;

+ (id) uuConvertObject:(id)object toContext:(NSManagedObjectContext*)context;

- (void) uuDeleteObjects:(NSArray*)list;
- (void) uuDeleteAllObjects:(void(^)(void))completion;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NSManagedObject extensions

@interface NSManagedObject (UUCoreData)

+ (NSString*) uuEntityName;

+ (NSFetchRequest*) uuFetchRequestInContext:(NSManagedObjectContext*)context
                                  predicate:(NSPredicate*)predicate
                            sortDescriptors:(NSArray*)sortDescriptors
                                      limit:(NSNumber*)limit;

+ (NSFetchRequest*) uuFetchRequestInContext:(NSManagedObjectContext*)context
                                  predicate:(NSPredicate*)predicate
                            sortDescriptors:(NSArray*)sortDescriptors
                                     offset:(NSNumber*)offset
                                      limit:(NSNumber*)limit;

+ (NSArray*) uuFetchObjectsWithPredicate:(NSPredicate*)predicate
                                 context:(NSManagedObjectContext*)context;

+ (NSArray*) uuFetchObjectsWithPredicate:(NSPredicate*)predicate
                         sortDescriptors:(NSArray*)sortDescriptors
                                   limit:(NSNumber*)limit
                                 context:(NSManagedObjectContext*)context;

+ (NSArray*) uuFetchObjectsWithPredicate:(NSPredicate*)predicate
                         sortDescriptors:(NSArray*)sortDescriptors
                                  offset:(NSNumber*)offset
                                   limit:(NSNumber*)limit
                                 context:(NSManagedObjectContext*)context;

+ (NSInteger) uuBatchUpdate:(NSDictionary*)properties predicate:(NSPredicate*)predicate context:(NSManagedObjectContext*)context;

+ (instancetype) uuFetchSingleObjectWithPredicate:(NSPredicate*)predicate
                                          context:(NSManagedObjectContext*)context;

+ (instancetype) uuFetchSingleObjectWithPredicate:(NSPredicate*)predicate
                                  sortDescriptors:(NSArray*)sortDescriptors
                                          context:(NSManagedObjectContext*)context;

+ (instancetype) uuFetchOrCreateSingleEntityWithPredicate:(NSPredicate *)predicate
                                                  context:(NSManagedObjectContext *)context;

+ (void) uuDeleteObjectsWithPredicate:(NSPredicate*)predicate
                              context:(NSManagedObjectContext*)context;

+ (NSUInteger) uuCountObjectsWithPredicate:(NSPredicate*)predicate
                                   context:(NSManagedObjectContext*)context;

@end
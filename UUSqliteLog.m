//
//  UUSqliteLog.m
//  Useful Utilities - Simple SQLite logger
//

#import "UUSqliteLog.h"
#import <sqlite3.h>

#define kUUSqliteLog_TableName @"UUAppLog"

#define kUUSqliteLog_CreateSql \
    @"CREATE TABLE " \
    kUUSqliteLog_TableName \
    @" (id INTEGER PRIMARY KEY, TimeStamp REAL, Message TEXT);"

#define kUUSqliteLog_InsertSql \
    @"INSERT INTO " \
    kUUSqliteLog_TableName \
    @" (TimeStamp, Message) VALUES (?,?);"

#define kUUSqliteLog_PruneSql \
    @"DELETE FROM " \
    kUUSqliteLog_TableName \
    @" WHERE TimeStamp < ?;"

#define kUUSqliteLog_GetAllSql \
    @"SELECT TimeStamp, Message FROM " \
    kUUSqliteLog_TableName \
    @" ORDER BY TimeStamp DESC;"

#define kUUSqliteLog_ClearAllSql \
    @"DROP TABLE IF EXISTS " \
    kUUSqliteLog_TableName \
    ";"

@interface UUSqliteLog ()
{
    sqlite3* _database;
    sqlite3_stmt* _insertStatement;
    sqlite3_stmt* _pruneStatement;
}

@end


@implementation UUSqliteLog

+ (instancetype) sharedInstance
{
    static id theSharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^
    {
        theSharedInstance = [[self class] new];
    });
    
    return theSharedInstance;
}

+ (NSString*) logDatabasePath
{
    return [[NSHomeDirectory() stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:@"UUAppLog.db"];
}

- (id) init
{
    self = [super init];
    
    if (self)
    {
        NSString* databasePath = [[self class] logDatabasePath];
        [self createTableIfNotExist:databasePath tableName:kUUSqliteLog_TableName createSql:kUUSqliteLog_CreateSql];
        
        _database = [self openDB:databasePath];
        _insertStatement = [self prepareStatement:_database sql:kUUSqliteLog_InsertSql];
        _pruneStatement = [self prepareStatement:_database sql:kUUSqliteLog_PruneSql];
    }
    
    return self;
}

- (void) log:(NSString*)format, ...
{
    va_list args;
    va_start(args, format);
    NSString* message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
	int i = 1;
	
	sqlite3_bind_double(_insertStatement, i++, [NSDate timeIntervalSinceReferenceDate]);
	sqlite3_bind_text(_insertStatement, i++, [message UTF8String], -1, SQLITE_TRANSIENT);
	
	int result = sqlite3_step(_insertStatement);
	if (result == SQLITE_ERROR)
	{
		NSLog(@"Failed to Insert into App Log. Error Code: %d, Error Message: %s", result, sqlite3_errmsg(_database));
	}
	
	result = sqlite3_reset(_insertStatement);
	if (result == SQLITE_ERROR)
	{
		NSLog(@"Failed to Reset Insert App Log SQL Statement! Error Code: %d, Error Message: %s", result, sqlite3_errmsg(_database));
	}
}

- (NSString*) pathToAppLog
{
    return [[self class] logDatabasePath];
}

-(NSArray*) readAppLog
{
    NSMutableArray* arr = [NSMutableArray array];
    
    sqlite3_stmt* sqlStatement;
	int result = sqlite3_prepare_v2(_database, [kUUSqliteLog_GetAllSql UTF8String], -1, &sqlStatement, nil);
	if (result == SQLITE_OK)
	{
        while (sqlite3_step(sqlStatement) == SQLITE_ROW)
        {
            int i = 0;
            NSTimeInterval timeStamp = sqlite3_column_double(sqlStatement, i++);
            const char* msg = (const char*)sqlite3_column_text(sqlStatement, i++);
            
            NSMutableDictionary* md = [NSMutableDictionary dictionary];
            md[@"timestamp"] = @(timeStamp);
            md[@"msg"] = [[NSString alloc] initWithUTF8String:msg];
            [arr addObject:md];
        }
        
        sqlite3_finalize(sqlStatement);
    }
    else
    {
		NSLog(@"Failed to Query Sqlite DB. Error Code:%d, Error Message: %s", result, sqlite3_errmsg(_database));
	}
    
    return [arr copy];
}

#pragma mark - SQLite Helpers

- (BOOL) doesTableExist:(sqlite3*)database tableName:(NSString*)tableName
{
    NSParameterAssert(database);
    NSParameterAssert(tableName);
    
	NSString* sql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='%@'", tableName];
	int count = [self execSqlScalar:database sql:sql];
	return (count > 0);
}

- (void) createTableIfNotExist:(NSString*)databasePath tableName:(NSString*)tableName createSql:(NSString*)createSql
{
	NSParameterAssert(databasePath != nil);
	NSParameterAssert(tableName != nil);
	NSParameterAssert(createSql != nil);
    
	sqlite3* database;
	int result = sqlite3_open([databasePath UTF8String], &database);
	if (result != SQLITE_OK)
	{
		NSLog(@"Failed to Open Sqlite DB. Error Code: %d", result);
		database = nil;
	}
	
	BOOL exists = [self doesTableExist:database tableName:tableName];
	if (!exists)
	{
        [self execSql:database sql:createSql];
	}
	
	if (database != nil)
	{
		sqlite3_close(database);
	}
}

- (sqlite3*) openDB:(NSString*)databasePath
{
	NSParameterAssert(databasePath != nil);
    
	sqlite3* database;
	int result = sqlite3_open([databasePath UTF8String], &database);
	if (result != SQLITE_OK)
	{
		NSLog(@"Failed to Open Sqlite DB. Error Code: %d", result);
		database = nil;
	}
	
	return database;
}

- (void) closeDB:(sqlite3*)database
{
	if (database != nil)
	{
		sqlite3_close(database);
	}
}

- (sqlite3_stmt*) prepareStatement:(sqlite3*)database sql:(NSString*)sql
{
	NSParameterAssert(database != nil);
	NSParameterAssert(sql != nil);
	
	sqlite3_stmt* sqlStatement = nil;
	sqlite3_prepare_v2(database, [sql UTF8String], -1, &sqlStatement, nil);
	return sqlStatement;
}

- (void) cleanupStatement:(sqlite3_stmt*)sqlStatement
{
	if (sqlStatement != nil)
	{
		sqlite3_finalize(sqlStatement);
	}
}

-(int) execSql:(sqlite3*)database sql:(NSString*)sql
{
	NSParameterAssert(database != nil);
	NSParameterAssert(sql != nil);
	
	char* errorMsg = nil;
	int result = sqlite3_exec(database, [sql UTF8String], nil, nil, &errorMsg);
	if (result != SQLITE_OK)
	{
		NSLog(@"ExecSQL Error! Error Code: %d, Error Message: %s", result, errorMsg);
	}
	
	if (errorMsg != nil)
	{
		// Free error per SQLite docs
		sqlite3_free(errorMsg);
	}
	
	return result;
}

-(int) execSqlScalar:(sqlite3*)database sql:(NSString*)sql
{
	NSParameterAssert(database != nil);
	NSParameterAssert(sql != nil);
	
	int queryResult = -1;
	sqlite3_stmt* sqlStatement = nil;
	int result = sqlite3_prepare_v2(database, [sql UTF8String], -1, &sqlStatement, nil);
    if (result == SQLITE_OK)
	{
		result = sqlite3_step(sqlStatement);
		if (result == SQLITE_ROW)
		{
			queryResult = (int)sqlite3_column_int(sqlStatement, 0);
		}
	}
	
	[self cleanupStatement:sqlStatement];
	return queryResult;
}

@end

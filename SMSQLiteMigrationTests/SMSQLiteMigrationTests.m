//
//  SMSQLiteMigrationTests.m
//  SMSQLiteMigrationTests
//
//  Created by 00 on 2016/11/30.
//  Copyright © 2016年 00. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FMDatabase.h"
#import "SMSQLiteMigration.h"

@interface SMSQLiteMigrationTests : XCTestCase
@property (nonatomic, strong) FMDatabase *db;
@property (nonatomic, strong) NSString *dbPath;
@property (nonatomic, assign) NSInteger version;
@end

@implementation SMSQLiteMigrationTests

- (void)setUp {
    [super setUp];
    
    NSString *dbDir = [NSHomeDirectory() stringByAppendingPathComponent:@"TestDB"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:dbDir] == NO) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dbDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString *dbPath = [dbDir stringByAppendingPathComponent:@"TestDB.sqlite"];
    NSString *bundleDB = [[NSBundle mainBundle] pathForResource:@"TestDB" ofType:@"sqlite"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:dbPath] == NO) {
        [[NSFileManager defaultManager] copyItemAtPath:bundleDB toPath:dbPath error:nil];
    }
    
    self.dbPath = dbPath;
    NSLog(@"dbPath: %@", dbPath);
    
    self.db = [[FMDatabase alloc] initWithPath:dbPath];
    NSAssert([self.db open], @"Fail to open DB！！！");
    
    self.version = [SMSQLiteMigration versionForDB:self.db];
    self.version++;
}

- (void)tearDown {
    BOOL success = [self.db close];
    NSAssert(success, @"Fail to close DB！！！");
}

- (void)testAddColumn {
    NSLog(@">>>>>>>>>>>>>>>>  testAddColumn  >>>>>>>>>>>>>>>>>>");
    
    for (int i = 1; i <= 10; i++) {
        NSString *tid = [NSString stringWithFormat:@"id_%d", i];
        NSString *name = [NSString stringWithFormat:@"name_%d", i];
        NSString *sql = [NSString stringWithFormat:@"insert into t1(id, name) values('%@', '%@')", tid, name];
        BOOL success = [self.db executeUpdate:sql];
        NSLog(@">>>>>>>>>>>>>> %d", success);
    }
    
    NSString *referDBPath = [[NSBundle mainBundle] pathForResource:@"TestDB_AddColumn" ofType:@"sqlite"];
    FMDatabase *referDB = [[FMDatabase alloc] initWithPath:referDBPath];
    NSAssert([referDB open], @"Fail to open the refer DB！！！");
    
    BOOL success = [SMSQLiteMigration migrateLocalDB:self.db referDB:referDB toVersion:self.version];
    NSAssert(success, @"Fail to add column！！！");
    
    for (int i = 1; i <= 10; i++) {
        NSString *tid = [NSString stringWithFormat:@"A_id_%d", i];
        NSString *name = [NSString stringWithFormat:@"A_name_%d", i];
        NSString *new_column = [NSString stringWithFormat:@"new_column_%d", i];
        NSString *new_column_notnull = [NSString stringWithFormat:@"new_column_notnull_%d", i];
        NSString *new_column_dltv = [NSString stringWithFormat:@"new_column_dltv_%d", i];
        NSString *sql = [NSString stringWithFormat:@"insert into t1(id, name, new_column, new_column_notnull, new_column_dltv) values('%@', '%@', '%@', '%@', '%@')", tid, name, new_column, new_column_notnull, new_column_dltv];
        BOOL success = [self.db executeUpdate:sql];
        NSLog(@"Afeter >>>>>>>>>>>>>> %d", success);
    }
}

- (void)testAddTable {
    NSLog(@">>>>>>>>>>>>>>>>  testAddTable  >>>>>>>>>>>>>>>>>>");
    NSString *referDBPath = [[NSBundle mainBundle] pathForResource:@"TestDB_AddTable" ofType:@"sqlite"];
    FMDatabase *referDB = [[FMDatabase alloc] initWithPath:referDBPath];
    NSAssert([referDB open], @"Fail to open the refer DB！！！");
    
    BOOL success = [SMSQLiteMigration migrateLocalDB:self.db referDB:referDB toVersion:self.version];
    NSAssert(success, @"Fail to add table！！！");
    
    for (int i = 1; i <= 10; i++) {
        NSString *tid = [NSString stringWithFormat:@"B_id_%d", i];
        NSString *name = [NSString stringWithFormat:@"B_name_%d", i];
        int num = i;
        NSString *sql = [NSString stringWithFormat:@"insert into t2(t2_id, t2_name, t2_num) values('%@', '%@', %d)", tid, name, num];
        BOOL success = [self.db executeUpdate:sql];
        NSLog(@">>>>>>>>>>>>>> %d", success);
    }
}

- (void)testDeleteTable {
    NSString *referDBPath = [[NSBundle mainBundle] pathForResource:@"TestDB_DeleteTable" ofType:@"sqlite"];
    FMDatabase *referDB = [[FMDatabase alloc] initWithPath:referDBPath];
    NSAssert([referDB open], @"Fail to open the refer DB！！！");
    
    BOOL success = [SMSQLiteMigration migrateLocalDB:self.db referDB:referDB toVersion:self.version];
    NSAssert(success, @"Fail to delete table！！！");
}

- (void)testRenameTable {
    NSString *referDBPath = [[NSBundle mainBundle] pathForResource:@"TestDB_RenameTabel" ofType:@"sqlite"];
    FMDatabase *referDB = [[FMDatabase alloc] initWithPath:referDBPath];
    NSAssert([referDB open], @"Fail to open the refer DB！！！");
    
    BOOL success = [SMSQLiteMigration migrateLocalDB:self.db referDB:referDB toVersion:self.version];
    NSAssert(success, @"Fail to rename table！！！");
}

- (void)testAddIndex {
    NSString *referDBPath = [[NSBundle mainBundle] pathForResource:@"TestDB_AddIndex" ofType:@"sqlite"];
    FMDatabase *referDB = [[FMDatabase alloc] initWithPath:referDBPath];
    NSAssert([referDB open], @"Fail to open the refer DB！！！");
    
    BOOL success = [SMSQLiteMigration migrateLocalDB:self.db referDB:referDB toVersion:self.version];
    NSAssert(success, @"Fail to add index！！！");
}

- (void)testDeleteIndex {
    NSString *referDBPath = [[NSBundle mainBundle] pathForResource:@"TestDB_DeleteIndex" ofType:@"sqlite"];
    FMDatabase *referDB = [[FMDatabase alloc] initWithPath:referDBPath];
    NSAssert([referDB open], @"Fail to open the refer DB！！！");
    
    BOOL success = [SMSQLiteMigration migrateLocalDB:self.db referDB:referDB toVersion:self.version];
    NSAssert(success, @"Fail to delete index！！！");
}

@end

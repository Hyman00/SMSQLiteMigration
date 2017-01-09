//
//  SMSQLiteMigration.h
//  SMSQLiteMigration
//
//  Created by hyman on 2016/11/27.
//  Copyright © 2016年 hyman. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDatabase.h"

/**
 *  According to the different reference database and local database, upgrade the differences
 *  
 *  Supports:
 *
 *  1，Add new field（the new field of constraint only support: PK, DefaultValue, NOT NULL）
 *  2，Add new table, Delete table, Rename table
 *  3，Upate index
 *
 *  @note
 *  1，Rename table must be in accordance with the following format to rename the table name：oldTableName_to_newTableName
 *
 *  （Migration, when recognition to the format of the table name, will extract the oldTableName and newTableName, and then judge whether the oldTableName exists in oldDB, if any, is renamed as newTableName;Otherwise, the oldTableName_to_newTableName will be treated as an ordinary table name）
 *  
 *  2，Does not support this case: foreign key constraints exist in the database
 *
 */
@interface SMSQLiteMigration : NSObject

/**
 the version of db
 
 @param db db
 
 @return the version of db. if error, return NSNotFound
 */
+ (NSInteger)versionForDB:(FMDatabase *)db;

/**
 set the db version
 
 @param version the new version
 @param db db
 */
+ (BOOL)setVersion:(NSInteger)version forDB:(FMDatabase *)db;

/**
 According to the reference database, migrate the old database.After successful migration, update oldDB version number into a new version number
 
 According to the different reference database and local database, upgrade the differences
 
 @param localDB      need to migration
 @param referDB      reference database
 @param newVersion   the new version
 */
+ (BOOL)migrateLocalDB:(FMDatabase *)localDB referDB:(FMDatabase *)referDB toVersion:(NSInteger)newVersion;

/**
 Copy of the specified table data from origin DB to target DB
 
 @param tableNames   need to copy
 @param originDB     the database where the table to be copied resides
 @param targetDB     the database where the table need to copy to
 
 @note
 If the corresponding table does not exist in targetDB, the method will copy the corresponding table to targetDB.
 Otherwise, only copy the field datas that also exists in the targetDB table
 */
+ (BOOL)copyDataInTables:(NSArray<NSString *> *)tableNames fromDB:(FMDatabase *)originDB toDB:(FMDatabase *)targetDB;

@end

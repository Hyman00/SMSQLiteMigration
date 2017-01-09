//
//  SMSQLiteMigration.m
//  SMSQLiteMigration
//
//  Created by hyman on 2016/11/27.
//  Copyright © 2016年 hyman. All rights reserved.
//

#import "SMSQLiteMigration.h"
#import "FMDatabaseAdditions.h"
#import "SMSQLiteMigrationContent.h"
#import "SMSQLiteMigrationColumn.h"

@implementation SMSQLiteMigration

+ (NSInteger)versionForDB:(FMDatabase *)db {
    return [db intForQuery:@"PRAGMA user_version"];
}

+ (BOOL)setVersion:(NSInteger)version forDB:(FMDatabase *)db {
    return [db executeUpdate:[NSString stringWithFormat:@"PRAGMA user_version = %ld", (unsigned long)version]];
}

+ (BOOL)migrateLocalDB:(FMDatabase *)localDB referDB:(FMDatabase *)referDB toVersion:(NSInteger)newVersion
{
    if ([self versionForDB:localDB] >= newVersion) {
        NSLog(@"The current version of the database is UP-TO-DATE and does not require an upgrade.");
        return YES;
    }
    
    BOOL success = YES;
    @try {
        SMSQLiteMigrationContent *migrationContent = [self sm_getMigrationContentWithReferDB:referDB localDB:localDB];
        
        [localDB beginTransaction];
        
        if (migrationContent.needDeleteTables.count > 0) {
            success = [self sm_deleteTables:migrationContent.needDeleteTables inDatabase:localDB];
            if (success == NO) {
                [self sm_printErrorInfo:[NSString stringWithFormat:@"SMSQLiteMigration---Fail to Delete table：%@", localDB.lastErrorMessage]];
            }
        }
        
        if (success && migrationContent.needAddTables.count > 0) {
            success = [self sm_addTables:migrationContent.needAddTables inDatabase:localDB];
            if (success == NO) {
                [self sm_printErrorInfo:[NSString stringWithFormat:@"SMSQLiteMigration---Fail to ADD table：%@", localDB.lastErrorMessage]];
            }
        }
        
        if (success && migrationContent.needModifyTuples.count > 0) {
            success = [self sm_modifyTables:migrationContent.needModifyTuples inDatabase:localDB];
            if (success == NO) {
                [self sm_printErrorInfo:[NSString stringWithFormat:@"SMSQLiteMigration---Fail to modify table：%@", localDB.lastErrorMessage]];
            }
        }
        
        if (success && migrationContent.needDeleteIndexes.count > 0) {
            success = [self sm_deleteIndexes:migrationContent.needDeleteIndexes inDatabase:localDB];
            if (success == NO) {
                [self sm_printErrorInfo:[NSString stringWithFormat:@"SMSQLiteMigration---Fail to Delete index：%@", localDB.lastErrorMessage]];
            }
        }
        
        if (success && migrationContent.needAddIndexes.count > 0) {
            success = [self sm_addIndexes:migrationContent.needAddIndexes inDatabase:localDB];
            if (success == NO) {
                [self sm_printErrorInfo:[NSString stringWithFormat:@"SMSQLiteMigration---Fail to ADD index：%@", localDB.lastErrorMessage]];
            }
        }
        
        if (success) {
            [self setVersion:newVersion forDB:localDB];
            success = [localDB commit];
        }
        
        if (success == NO) {
            [localDB rollback];
        }
    } @catch (NSException *exception) {
        success = NO;
#if DEBUG
        @throw exception;
#endif
    }
    
    [localDB close];
    
    return success;
}

+ (BOOL)copyDataInTables:(NSArray<NSString *> *)tableNames fromDB:(FMDatabase *)originDB toDB:(FMDatabase *)targetDB
{
    if (tableNames.count == 0) {
        NSLog(@"No tables are specified for copying");
        return YES;
    }
    
    BOOL success = YES;
    @try {
        [targetDB beginTransaction];
        
        NSArray<SMSQLiteMigrationTable *> *originTables = [self sm_getAllTables:originDB];
        success = originTables.count >= tableNames.count;
        if (success == NO) {
            [self sm_printErrorInfo:[NSString stringWithFormat:@"The total number of tables in originDB (%lu) < The number of tables to copy (%lu)", originTables.count, tableNames.count]];
        } else {
            // Extract the tables to be copied
            NSMutableArray *needCopyTables = [NSMutableArray arrayWithCapacity:tableNames.count];
            for (NSString *tableName in tableNames) {
                for (SMSQLiteMigrationTable *table in originTables) {
                    if ([table.name isEqualToString:tableName]) {
                        [needCopyTables addObject:table];
                    }
                }
            }
            
            // Start replication
            success = needCopyTables.count == tableNames.count;
            if (success == NO) {
                [self sm_printErrorInfo:[NSString stringWithFormat:@"The number of tables in the originDB that need to be copyed (%lu) < The number of tables to copy (%lu)", needCopyTables.count, tableNames.count]];
            } else {
                success = [self sm_copyTables:needCopyTables fromDB:originDB toDB:targetDB];
                if (success == NO) {
                    [self sm_printErrorInfo:[NSString stringWithFormat:@"Fail to copy \nError of the original table：%@ \nError of the target table：%@", originDB.lastErrorMessage, targetDB.lastErrorMessage]];
                }
            }
        }
        
        if (success) {
            success = [targetDB commit];
        }
        
        if (success == NO) {
            [targetDB rollback];
        }
    } @catch (NSException *exception) {
        success = NO;
#if DEBUG
        @throw exception;
#endif
    }
    
    [originDB close];
    [targetDB close];
    
    return success;
}

#pragma mark - Private
+ (void)sm_printErrorInfo:(NSString *)errorInfo {
#if DEBUG
    @throw [NSException exceptionWithName:errorInfo reason:nil userInfo:nil];
#endif
}

#pragma mark -- Extract Diff
+ (SMSQLiteMigrationContent *)sm_getMigrationContentWithReferDB:(FMDatabase *)referDB
                                                         localDB:(FMDatabase *)localDB
{
    SMSQLiteMigrationContent *migrationContent = [SMSQLiteMigrationContent new];
    
    [self sm_extractNeedMigrationTablesToContent:migrationContent
                                     withReferDB:referDB
                                         localDB:localDB];
    
    [self sm_extractNeedMigrationIndexesToContent:migrationContent
                                      withReferDB:referDB
                                          localDB:localDB];
    
    return migrationContent;
}

+ (void)sm_extractNeedMigrationTablesToContent:(SMSQLiteMigrationContent *)migrationContent
                                   withReferDB:(FMDatabase *)referDB
                                       localDB:(FMDatabase *)localDB
{
    NSMutableArray<SMSQLiteMigrationTable *> *localTables = [[self sm_getAllTables:localDB] mutableCopy];
    NSMutableArray<SMSQLiteMigrationTable *> *referTables = [[self sm_getAllTables:referDB] mutableCopy];
    
    /**
     * Remove tables without any changes (Two tables with the same createSQL are the same)
     */
    NSMutableIndexSet *noChangedIndexesForRefer = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *noChangedIndexesForLocal = [NSMutableIndexSet indexSet];
    [referTables enumerateObjectsUsingBlock:^(SMSQLiteMigrationTable *referTable, NSUInteger idx, BOOL * _Nonnull stop) {
        NSUInteger localNoChangeIndex = [localTables indexOfObject:referTable];
        if (localNoChangeIndex != NSNotFound) {
            [noChangedIndexesForRefer addIndex:idx];
            [noChangedIndexesForLocal addIndex:localNoChangeIndex];
        }
    }];
    [referTables removeObjectsAtIndexes:noChangedIndexesForRefer];
    [localTables removeObjectsAtIndexes:noChangedIndexesForLocal];
    
    /**
     *  Extract the tables that need to add, delete, modify, rename
     */
    NSMutableArray *addedTables = [NSMutableArray array];
    NSMutableArray *modifiedTuples = [NSMutableArray array];
    for (SMSQLiteMigrationTable *referTable in referTables) {
        
        // Extract the table to be renamed
        NSRange range = [[referTable.name lowercaseString] rangeOfString:@"_to_"];
        if ((range.location != NSNotFound && range.location > 0) && (range.length + range.location <= referTable.name.length))
        {
            NSString *oldTableName = [referTable.name substringToIndex:range.location];
            NSString *newTableName = [referTable.name substringFromIndex:range.location + range.length];
            NSInteger localTableIndex = [self sm_indexOfTableName:oldTableName inTables:localTables];
            if (localTableIndex != NSNotFound) {
                referTable.name = newTableName;
                
                SMSQLiteMigrationTableTuple *tuple = [SMSQLiteMigrationTableTuple new];
                tuple.referTable = referTable;
                tuple.localTable = localTables[localTableIndex];
                [modifiedTuples addObject:tuple];
                
                [localTables removeObjectAtIndex:localTableIndex];
                continue;
            }
        }
        
        // Extract the table to be modifiyed, added, deleted
        NSInteger modifiedIndex = [self sm_indexOfTableName:referTable.name inTables:localTables];
        if (modifiedIndex != NSNotFound) {
            SMSQLiteMigrationTableTuple *tuple = [SMSQLiteMigrationTableTuple new];
            tuple.referTable = referTable;
            tuple.localTable = localTables[modifiedIndex];
            [modifiedTuples addObject:tuple];
            
            // Remove the table that need to be modified, the last remaining table is to be deleted table
            [localTables removeObjectAtIndex:modifiedIndex];
        } else {
            [addedTables addObject:referTable];
        }
    }
    
    
    migrationContent.needDeleteTables = localTables;
    migrationContent.needAddTables = addedTables;
    migrationContent.needModifyTuples = modifiedTuples;
}

+ (void)sm_extractNeedMigrationIndexesToContent:(SMSQLiteMigrationContent *)migrationContent
                                    withReferDB:(FMDatabase *)referDB
                                        localDB:(FMDatabase *)localDB
{
    NSArray<SMSQLiteMigrationIndex *> *localIndexes = [self sm_getAllIndexes:localDB];
    NSArray<SMSQLiteMigrationIndex *> *referIndexes = [self sm_getAllIndexes:referDB];
    
    NSMutableArray *needAddedIndexes = [NSMutableArray array];
    NSMutableArray *needDeletedIndexes = [localIndexes mutableCopy];
    for (SMSQLiteMigrationIndex *referIndex in referIndexes) {
        NSInteger indexOfLocalIndex = [self sm_indexOfIndexName:referIndex.name inIndexes:localIndexes];
        if (indexOfLocalIndex == NSNotFound) {
            [needAddedIndexes addObject:referIndex];
        } else {
            [needDeletedIndexes removeObjectAtIndex:indexOfLocalIndex];
        }
    }
    
    migrationContent.needAddIndexes = needAddedIndexes;
    migrationContent.needDeleteIndexes = needDeletedIndexes;
}

+ (NSArray<SMSQLiteMigrationTable *> *)sm_getAllTables:(FMDatabase *)database {
    NSMutableArray *tables = [@[] mutableCopy];
    FMResultSet *tableResults = [database executeQuery:@"select name, sql from sqlite_master where type = 'table'"];
    while ([tableResults next]) {
        SMSQLiteMigrationTable *table = [SMSQLiteMigrationTable new];
        table.name = [[tableResults stringForColumn:@"name"] lowercaseString];
        table.createSQL = [[tableResults stringForColumn:@"sql"] lowercaseString];
        
        NSMutableSet *columns = [NSMutableSet set];
        FMResultSet *columnResult = [database executeQuery:[NSString stringWithFormat:@"PRAGMA table_info(%@)", table.name]];
        while ([columnResult next]) {
            SMSQLiteMigrationColumn *column = [SMSQLiteMigrationColumn new];
            column.name = [[columnResult stringForColumn:@"name"] lowercaseString];
            column.type = [[columnResult stringForColumn:@"type"] lowercaseString];
            column.pk = [columnResult intForColumn:@"pk"] == 1;
            column.notNull = [columnResult intForColumn:@"notnull"] == 1;
            column.defaultValue = [columnResult stringForColumn:@"dflt_value"];
            [columns addObject:column];
        }
        table.columns = columns;
        
        [tables addObject:table];
    }
    return tables;
}

+ (NSArray<SMSQLiteMigrationIndex *> *)sm_getAllIndexes:(FMDatabase *)database {
    NSMutableArray *indexes = [@[] mutableCopy];
    FMResultSet *tableResults = [database executeQuery:@"select name, sql from sqlite_master where type = 'index' and sql is not null"];
    while ([tableResults next]) {
        SMSQLiteMigrationIndex *index = [SMSQLiteMigrationIndex new];
        index.name = [[tableResults stringForColumn:@"name"] lowercaseString];
        index.createSQL = [[tableResults stringForColumn:@"sql"] lowercaseString];
        [indexes addObject:index];
    }
    return indexes;
}

+ (NSInteger)sm_indexOfTableName:(NSString *)tableName inTables:(NSArray<SMSQLiteMigrationTable *> *)tables {
    NSInteger index = NSNotFound;
    for (NSInteger i = 0; i < tables.count; i++) {
        if ([tableName isEqualToString:tables[i].name]) {
            index = i;
            break;
        }
    }
    return index;
}

+ (NSInteger)sm_indexOfIndexName:(NSString *)indexName inIndexes:(NSArray<SMSQLiteMigrationIndex *> *)indexes
{
    NSInteger index = NSNotFound;
    for (NSInteger i = 0; i < indexes.count; i++) {
        if ([indexName isEqualToString:indexes[i].name]) {
            index = i;
            break;
        }
    }
    return index;
}

#pragma mark -- Migration Operation
+ (BOOL)sm_deleteIndexes:(NSArray<SMSQLiteMigrationIndex *> *)indexes inDatabase:(FMDatabase *)database {
    NSMutableString *SQL = [@"" mutableCopy];
    for (SMSQLiteMigrationIndex *index in indexes) {
        NSString *deleteSQL = [NSString stringWithFormat:@"DROP INDEX %@", index.name];
        [SQL appendFormat:@"%@;", deleteSQL];
    }
    return [database executeStatements:SQL];
}

+ (BOOL)sm_addIndexes:(NSArray<SMSQLiteMigrationIndex *> *)indexes inDatabase:(FMDatabase *)database {
    NSMutableString *SQL = [@"" mutableCopy];
    for (SMSQLiteMigrationIndex *index in indexes) {
        [SQL appendFormat:@"%@;", index.createSQL];
    }
    return [database executeStatements:SQL];
}

+ (BOOL)sm_deleteTables:(NSArray<SMSQLiteMigrationTable *> *)tables inDatabase:(FMDatabase *)database {
    NSMutableString *SQL = [@"" mutableCopy];
    for (SMSQLiteMigrationTable *table in tables) {
        NSString *deleteSQL = [NSString stringWithFormat:@"DROP TABLE %@", table.name];
        [SQL appendFormat:@"%@;", deleteSQL];
    }
    return [database executeStatements:SQL];
}

+ (BOOL)sm_addTables:(NSArray<SMSQLiteMigrationTable *> *)tables inDatabase:(FMDatabase *)database {
    NSMutableString *SQL = [@"" mutableCopy];
    for (SMSQLiteMigrationTable *table in tables) {
        [SQL appendFormat:@"%@;", table.createSQL];
    }
    return [database executeStatements:SQL];
}

+ (BOOL)sm_modifyTables:(NSArray<SMSQLiteMigrationTableTuple *> *)modifiedTuples inDatabase:(FMDatabase *)databse {
    BOOL success = YES;
    for (SMSQLiteMigrationTableTuple *tuple in modifiedTuples) {
        
        // Rename the table first
        if ([tuple.referTable.name isEqualToString:tuple.localTable.name] == NO) {
            success = [self sm_renameOldTable:tuple.localTable.name toNewTable:tuple.referTable.name inDatabase:databse];
            if (success == NO) {
                break;
            }
            
            tuple.localTable.name = tuple.referTable.name;
        }
        
        // Processes new fields
        NSMutableSet *addedColumns = [tuple.referTable.columns mutableCopy];
        [addedColumns minusSet:tuple.localTable.columns];
        if (addedColumns.count > 0) {
            success = [self sm_addColumns:addedColumns inTable:tuple.localTable database:databse];
            if (success == NO) {
                break;
            }
        }
    }
    return success;
}

+ (BOOL)sm_renameOldTable:(NSString *)oldTableName toNewTable:(NSString *)newTableName inDatabase:(FMDatabase *)database
{
    NSString *renameSQL = [NSString stringWithFormat:@"ALTER TABLE %@ RENAME TO %@", oldTableName, newTableName];
    return [database executeUpdate:renameSQL];
}

+ (BOOL)sm_addColumns:(NSSet<SMSQLiteMigrationColumn *> *)columns inTable:(SMSQLiteMigrationTable *)table database:(FMDatabase *)database
{
    NSMutableString *SQL = [@"" mutableCopy];
    for (SMSQLiteMigrationColumn *column in columns) {
        NSString *constraint = @"";
        if (column.pk) {
            constraint = [constraint stringByAppendingString:@" PRIMARY KEY"];
        }
        if (column.notNull) {
            constraint = [constraint stringByAppendingString:@" NOT NULL"];
        }
        
        // Put the default constraint to the end
        if (column.defaultValue.length > 0) {
            constraint = [constraint stringByAppendingFormat:@" DEFAULT %@", column.defaultValue];
        }
        
        NSString *addColumnSQL = [NSString stringWithFormat:@"ALTER TABLE %@ ADD %@ %@%@", table.name, column.name, column.type, constraint];
        [SQL appendFormat:@"%@;", addColumnSQL];
    }
    return [database executeStatements:SQL];
}

#pragma mark -- Copy Table
+ (BOOL)sm_copyTables:(NSArray<SMSQLiteMigrationTable *> *)needCopyTables fromDB:(FMDatabase *)originDB toDB:(FMDatabase *)targetDB
{
    BOOL success = YES;
    
    NSArray *targetTables = [self sm_getAllTables:targetDB];
    
    /**
     *  1，Copy the table structure  2，Migrate the data for the corresponding table
     */
    for (SMSQLiteMigrationTable *table in needCopyTables)
    {
        // If the table does not exist in the targetDB then only copy the table structure
        if ([self sm_indexOfTableName:table.name inTables:targetTables] == NSNotFound)
        {
            success = [targetDB executeUpdate:table.createSQL];
            if (success == NO)
            {
                [self sm_printErrorInfo:[NSString stringWithFormat:@"SMSQLiteMigration--Fail to copy the table structure：%@", targetDB.lastErrorMessage]];
                break;
            }
        }
        
        long totalCount = [originDB longForQuery:[NSString stringWithFormat:@"SELECT count(*) FROM %@", table.name]];
        if (totalCount <= 0) {
            continue;
        }
        
        // Migrate the datas
        long loadedCount = 0;
        int pageSize = 100;
        
        while (loadedCount < totalCount) {
            FMResultSet *fetchResult = [originDB executeQuery:[NSString stringWithFormat:@"SELECT * FROM %@ LIMIT %d OFFSET %ld", table.name, pageSize, loadedCount]];
            while ([fetchResult next]) {
                NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:table.columns.count];
                
                NSMutableArray *keys = [NSMutableArray arrayWithCapacity:table.columns.count];
                NSMutableArray *vals = [NSMutableArray arrayWithCapacity:table.columns.count];
                for (SMSQLiteMigrationColumn *column in table.columns) {
                    [keys addObject:column.name];
                    [vals addObject:[NSString stringWithFormat:@":%@", column.name]];
                    
                    id obj = [fetchResult objectForColumnName:column.name];
                    parameters[column.name] = obj ?: [NSNull null];
                }
                
                NSString *columnInfos = [keys componentsJoinedByString:@","];
                NSString *valueInfos = [vals componentsJoinedByString:@","];
                NSString *insertSQL = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", table.name, columnInfos, valueInfos];
                
                success = [targetDB executeUpdate:insertSQL withParameterDictionary:parameters];
                if (success == NO) {
                    [self sm_printErrorInfo:[NSString stringWithFormat:@"SMSQLiteMigration--Fail to migrate the datas：%@", targetDB.lastErrorMessage]];
                    goto END_COPY_LOOP;
                }
            }
            
            loadedCount += pageSize;
        }
    }
    
END_COPY_LOOP:
    
    return success;
}

@end

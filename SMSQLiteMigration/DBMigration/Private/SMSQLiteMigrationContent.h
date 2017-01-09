//
//  SMSQLiteMigrationContent.h
//  SMDBMigration
//
//  Created by 00 on 2016/11/28.
//  Copyright © 2016年 hyman. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SMSQLiteMigrationTableTuple.h"
#import "SMSQLiteMigrationTable.h"
#import "SMSQLiteMigrationIndex.h"

@interface SMSQLiteMigrationContent : NSObject

@property (nonatomic, strong) NSArray<SMSQLiteMigrationTable *> *needDeleteTables;
@property (nonatomic, strong) NSArray<SMSQLiteMigrationTable *> *needAddTables;
@property (nonatomic, strong) NSArray<SMSQLiteMigrationTableTuple *> *needModifyTuples;

@property (nonatomic, strong) NSArray<SMSQLiteMigrationIndex *> *needDeleteIndexes;
@property (nonatomic, strong) NSArray<SMSQLiteMigrationIndex *> *needAddIndexes;

@end

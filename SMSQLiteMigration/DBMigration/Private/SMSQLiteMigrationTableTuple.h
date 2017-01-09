//
//  SMSQLiteMigrationTableTuple.h
//  SMDBMigration
//
//  Created by 00 on 2016/11/28.
//  Copyright © 2016年 hyman. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMSQLiteMigrationTable;

@interface SMSQLiteMigrationTableTuple : NSObject

@property (nonatomic, strong) SMSQLiteMigrationTable *referTable;
@property (nonatomic, strong) SMSQLiteMigrationTable *localTable;

@end

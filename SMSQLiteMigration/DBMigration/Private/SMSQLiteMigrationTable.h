//
//  SMSQLiteMigrationTable.h
//  SMDBMigration
//
//  Created by 00 on 2016/11/28.
//  Copyright © 2016年 hyman. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMSQLiteMigrationColumn;

/**
 *  @note Two of the same object, that is, they have the same createSQL.
 */
@interface SMSQLiteMigrationTable : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *createSQL;
@property (nonatomic, strong) NSSet<SMSQLiteMigrationColumn *> *columns;

@end

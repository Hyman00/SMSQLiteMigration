//
//  SMSQLiteMigrationColumn.h
//  SMDBMigration
//
//  Created by 00 on 2016/11/28.
//  Copyright © 2016年 hyman. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  @note Two of the same object, that is, they have the same name.
 */
@interface SMSQLiteMigrationColumn : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *type;
@property (nonatomic, assign) BOOL notNull;
@property (nonatomic, assign) BOOL pk;
@property (nonatomic, strong) NSString *defaultValue;

@end

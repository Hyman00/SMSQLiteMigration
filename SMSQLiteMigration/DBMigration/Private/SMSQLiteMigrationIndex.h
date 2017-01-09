//
//  SMSQLiteMigrationIndex.h
//  SMSQLiteMigration
//
//  Created by 00 on 2017/1/9.
//  Copyright © 2017年 00. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  @note Two of the same object, that is, they have the same createSQL.
 */
@interface SMSQLiteMigrationIndex : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *createSQL;

@end

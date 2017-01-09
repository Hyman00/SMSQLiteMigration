//
//  SMSQLiteMigrationTable.m
//  SMDBMigration
//
//  Created by 00 on 2016/11/28.
//  Copyright © 2016年 hyman. All rights reserved.
//

#import "SMSQLiteMigrationTable.h"

@implementation SMSQLiteMigrationTable

- (NSUInteger)hash {
    return [self.createSQL hash];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    
    if ([object isKindOfClass:[SMSQLiteMigrationTable class]] == NO) {
        return NO;
    }
    
    SMSQLiteMigrationTable *target = object;
    return [self.createSQL isEqualToString:target.createSQL];
}

@end

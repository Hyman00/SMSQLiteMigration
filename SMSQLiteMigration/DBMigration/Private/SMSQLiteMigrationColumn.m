//
//  SMSQLiteMigrationColumn.m
//  SMDBMigration
//
//  Created by 00 on 2016/11/28.
//  Copyright © 2016年 hyman. All rights reserved.
//

#import "SMSQLiteMigrationColumn.h"

@implementation SMSQLiteMigrationColumn

- (NSUInteger)hash {
    return [self.name hash];
}

- (BOOL)isEqual:(id)object {
    if (self ==  object) {
        return YES;
    }
    
    if ([object isKindOfClass:[SMSQLiteMigrationColumn class]] == NO) {
        return NO;
    }
    
    SMSQLiteMigrationColumn *target = object;
    return [self.name isEqualToString:target.name];
}

@end

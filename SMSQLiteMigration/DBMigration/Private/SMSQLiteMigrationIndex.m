//
//  SMSQLiteMigrationIndex.m
//  SMSQLiteMigration
//
//  Created by 00 on 2017/1/9.
//  Copyright © 2017年 00. All rights reserved.
//

#import "SMSQLiteMigrationIndex.h"

@implementation SMSQLiteMigrationIndex

- (NSUInteger)hash {
    return [self.createSQL hash];
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    
    if ([object isKindOfClass:[SMSQLiteMigrationIndex class]] == NO) {
        return NO;
    }
    
    SMSQLiteMigrationIndex *target = object;
    return [self.createSQL isEqualToString:target.createSQL];
}

@end

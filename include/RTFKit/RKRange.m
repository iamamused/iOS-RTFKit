//
//  RKRange.m
//  RTFKit
//
//  Created by Jeffrey Sambells on 10-05-13.
//  Copyright 2010 We-Create Inc. All rights reserved.
//

#import "RKRange.h"


@implementation RKRange
@synthesize start;
@synthesize end;

- (id)copyWithZone:(NSZone *)zone
{
    RKRange *copy = [[[self class] allocWithZone: zone] init];
    [copy setStart:[self start]];
    [copy setEnd:[self end]];
    return copy;
}

@end

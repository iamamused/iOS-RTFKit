//
//  RKFont.m
//  RTFKit
//
//  Created by Jeffrey Sambells on 10-05-13.
//  Copyright 2010 We-Create Inc. All rights reserved.
//

#import "RKFont.h"


@implementation RKFont
@synthesize fontIndex;
@synthesize fontSize;
@synthesize isBold;
@synthesize isItalic;

- (id)copyWithZone:(NSZone *)zone
{
    RKFont *copy = [super copyWithZone: zone];
	[copy setFontIndex:self.fontIndex];
	[copy setFontSize:self.fontSize];
	[copy setIsBold:self.isBold];
	[copy setIsItalic:self.isItalic];
    return copy;
}

@end

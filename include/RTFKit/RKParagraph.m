//
//  RKParagraph.m
//  RTFKit
//
//  Created by Jeffrey Sambells on 10-05-13.
//  Copyright 2010 We-Create Inc. All rights reserved.
//

#import "RKParagraph.h"


@implementation RKParagraph
@synthesize indentLeft;
@synthesize indentRight;
@synthesize indentFirst;
@synthesize just; 

- (id)copyWithZone:(NSZone *)zone
{
    RKParagraph *copy = [super copyWithZone: zone];
	[copy setIndentLeft:self.indentLeft];
	[copy setIndentRight:self.indentRight];
	[copy setIndentFirst:self.indentFirst];
	[copy setJust:self.just];
    return copy;
}

@end

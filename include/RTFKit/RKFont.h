//
//  RKFont.h
//  RTFKit
//
//  Created by Jeffrey Sambells on 10-05-13.
//  Copyright 2010 We-Create Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RKRange.h"

@interface RKFont : RKRange {
	
	int fontIndex;
	float fontSize;
    bool isBold;
    bool isItalic;
}

@property (assign) int fontIndex;
@property (assign) float fontSize;
@property (assign) bool isBold;
@property (assign) bool isItalic;

 

@end

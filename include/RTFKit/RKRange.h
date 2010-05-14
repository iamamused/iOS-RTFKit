//
//  RKRange.h
//  RTFKit
//
//  Created by Jeffrey Sambells on 10-05-13.
//  Copyright 2010 We-Create Inc. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface RKRange : NSObject <NSCopying> {
	int start;
	int end;
}

@property (assign) int start;
@property (assign) int end;

@end

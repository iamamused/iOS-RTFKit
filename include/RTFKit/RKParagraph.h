//
//  RKParagraph.h
//  RTFKit
//
//  Created by Jeffrey Sambells on 10-05-13.
//  Copyright 2010 We-Create Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RKRange.h"

typedef enum {
	rkParaJustLeft, 
	rkParaJustRight, 
	rkParaJustCenter, 
	rkParaJustForced 
} rkParaJust;


@interface RKParagraph : RKRange {	
    int indentLeft;                 // Left indent in twips
    int indentRight;                // Right indent in twips
    int indentFirst;                // First line indent in twips
    rkParaJust just;       // Justification
}

@property(assign) int indentLeft;                 // Left indent in twips
@property(assign) int indentRight;                // Right indent in twips
@property(assign) int indentFirst;                // First line indent in twips
@property(assign) rkParaJust just;       // Justification


@end

//
//  RKReader.h
//  RTFKit
//
//  Created by Jeffrey Sambells on 10-05-10.
//  Copyright TropicalPixels. 2010. All rights reserved.
//  Please see the included LICENSE for applicable licensing information. 
//

#import <CoreText/CoreText.h>
#import <RTFKit/RTFKit.h>

// typedef char bool;
#define fTrue 1
#define fFalse 0

#pragma mark -
#pragma mark Enumerations


typedef enum { 
	rkDestinationStateNorm,  // Store the character in the destination
	rkDestinationStateSkip   // Skip the character
} rkDestinationState;

typedef enum { 
	rkInternalStateNorm,       // Store characters
	rkInternalStateBin,        // Store BIN data
	rkInternalStateHex         // Store HEX data
} rkInternalState;

//http://msdn.microsoft.com/en-us/library/aa140283(v=office.10).aspx
typedef enum {
	rkPropFontIndex,
	rkPropFontSize,
	rkPropBold, 
	rkPropItalic, 
	rkPropLeftInd,
	rkPropRightInd,
	rkPropFirstInd, 
	rkPropJust,
	rkPropPard,
	rkPropPlain,
	rkPropMax 
} rkProperty;

typedef enum {
	rkValueTypeSpec, 
	rkValueTypeByte, 
	rkValueTypeWord
} rkValueType;

typedef enum {
	rkPropertyTypeFont, 
	rkPropertyTypeParagraph,
	rkPropertyTypeColor
} rkPropertyType;

typedef enum {
	rkSpecialTypeBin, 
	rkSpecialTypeHex, 
	rkSpecialTypeSkip 
} rkSpecialType;

typedef enum {
	rkDestinationTypePict, 
	rkDestinationTypeSkip 
} rkDestinationType;

typedef enum {
	rkKeywordTypeCharacter, 
	rkKeywordTypeDestination, 
	rkKeywordTypeProperty, 
	rkKeywordTypeSpecial
} rkKeywordType;

#pragma mark -
#pragma mark Structs


typedef struct save
{
    struct save *pNext;         // next save

    rkDestinationState  destinationState;
    rkInternalState     internalState;
} RTFSaveState;

typedef struct propmod
{
    rkValueType actn;     // size of value
    rkPropertyType prop;           // structure containing value
    SEL selector;    // offset of value from base of structure
} RTFProperty;


typedef struct symbol
{
    char *szKeyword;     // RTF keyword
    int  dflt;           // default value to use
    bool fPassDflt;      // true to use default value from this table
    rkKeywordType  kwd;  // base action to take
    int  idx;            // index into property table if kwd == rkKeywordTypeProperty
						 // index into destination table if kwd == rkKeywordTypeDestination
                         // character to print if kwd == rkKeywordTypeCharacter
} RTFSymbol;


typedef struct rk_coretext_attributes
{ 
	CFNumberRef         characterShape;      //kCTCharacterShapeAttributeName
	CTFontRef           font;                //kCTFontAttributeName
	CFNumberRef         kern;                //kCTKernAttributeName
	CFNumberRef         ligature;            //kCTLigatureAttributeName
	CGColorRef          foregroundColor;     //kCTForegroundColorAttributeName
	CFBooleanRef        foregroundColorFrom; //kCTForegroundColorFromContextAttributeName
	CTParagraphStyleRef paragraphStyle;      //kCTParagraphStyleAttributeName
	CFNumberRef         strokeWidth;         //kCTStrokeWidthAttributeName
	CGColorRef          strokeColor;         //kCTStrokeColorAttributeName
	CFNumberRef         superscript;         //kCTSuperscriptAttributeName
	CGColorRef          underlineColor;      //kCTUnderlineColorAttributeName
	CFNumberRef         underlineStyle;      //kCTUnderlineStyleAttributeName
	CFBooleanRef        verticalForms;       //kCTVerticalFormsAttributeName
	CTGlyphInfoRef      glyphInfo;           //kCTGlyphInfoAttributeName
	//CTRunDelegateRef    runDelegate;          //kCTRunDelegateAttributeName
} RTFCoreTextAttributes;

#pragma mark -
#pragma mark Defines

// RTF parser error codes
#define rkOK 0                      // Everything's fine!
#define rkStackUnderflow    1       // Unmatched '}'
#define rkStackOverflow     2       // Too many '{' -- memory exhausted
#define rkUnmatchedBrace    3       // RTF ended during an open group.
#define rkInvalidHex        4       // invalid hex character found in data
#define rkBadTable          5       // RTF table (sym or prop) invalid
#define rkAssertion         6       // Assertion failure
#define rkEndOfFile         7       // End of file reached while reading RTF

#pragma mark -
#pragma mark Interface

@interface RKReader : NSObject {
	
	FILE *fpIn;
	
	int  cGroup;
	bool fSkipDestIfUnk;
	long cbBin;
	long lParam;
	
	rkDestinationState     destinationState;
	rkInternalState        internalState;

	RTFSaveState *psave;
	
	// RTFDoc buffer elements.
	NSData          * sourceRTFData;
	int               bufferPosition;
	unsigned char     putBuffer[64];
	int               putBufferLength;
	unsigned char     characters[8096];
	int               destinationLength;
	NSMutableAttributedString   * destinationString;

	NSMutableArray       *fontRuns;
	NSMutableArray		 *paragraphRuns;
		
}

- (id)initWithFilePath:(NSString *)filePath;


@end






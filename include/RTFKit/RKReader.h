//
//  RKReader.h
//  RTFKit
//
//  Created by Jeffrey Sambells on 10-05-10.
//  Copyright TropicalPixels. 2010. All rights reserved.
//  Please see the included LICENSE for applicable licensing information. 
//


// typedef char bool;
#define fTrue 1
#define fFalse 0

#pragma mark -
#pragma mark Enumerations

typedef enum {
	rkJustificationLeft, 
	rkJustificationRight, 
	rkJustificationCenter, 
	rkJustificationForced 
} rkJustification;

typedef enum {
	sbkNon, 
	sbkCol, 
	sbkEvn, 
	sbkOdd, 
	sbkPg
} SBK;

typedef enum {
	pgDec, 
	pgURom, 
	pgLRom, 
	pgULtr, 
	pgLLtr
} PGN;

typedef enum { 
	rkDestinationStateNorm,  // Store the character in the destination
	rkDestinationStateSkip   // Skip the character
} rkDestinationState;

typedef enum { 
	rkInternalStateNorm,       // Store characters
	rkInternalStateBin,        // Store BIN data
	rkInternalStateHex         // Store HEX data
} rkInternalState;

typedef enum {
	rkPropBold, 
	rkPropItalic, 
	rkPropUnderline, 
	rkPropLeftInd,
	rkPropRightInd,
	rkPropFirstInd, 
	rkPropCols, 
	rkPropPgnX,
	rkPropPgnY,
	rkPropXaPage,
	rkPropYaPage, 
	rkPropXaLeft,
	rkPropXaRight,
	rkPropYaTop,
	rkPropYaBottom,
	rkPropPgnStart,
	rkPropSbk,
	rkPropPgnFormat,
	rkPropFacingp,
	rkPropLandscape,
	rkPropJust,
	rkPropPard,
	rkPropPlain,
	rkPropSectd,
	rkPropMax 
} rkProperty;

typedef enum {
	rkActionTypeSpec, 
	rkActionTypeByte, 
	rkActionTypeWord
} rkActionType;

typedef enum {
	rkPropertyTypeCharacter, 
	rkPropertyTypeParagraph, 
	rkPropertyTypeSection, 
	rkPropertyTypeDocument
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

typedef struct char_prop
{
    char fBold;
    char fUnderline;
    char fItalic;
} RTFCharacter;

typedef struct para_prop
{
    int xaLeft;                 // Left indent in twips
    int xaRight;                // Right indent in twips
    int xaFirst;                // First line indent in twips
    rkJustification just;       // Justification
} RTFParagraph;

typedef struct sect_prop
{
    int cCols;                  // Number of columns
    SBK sbk;                    // Section break type
    int xaPgn;                  // X position of page number in twips
    int yaPgn;                  // Y position of page number in twips
    PGN pgnFormat;              // How the page number is formatted
} RTFSection;

typedef struct doc_prop
{
    int xaPage;                 // Page width in twips
    int yaPage;                 // Page height in twips
    int xaLeft;                 // Left margin in twips
    int yaTop;                  // Top margin in twips
    int xaRight;                // Right margin in twips
    int yaBottom;               // Bottom margin in twips
    int pgnStart;               // Starting page number in twips
    char fFacingp;              // Facing pages enabled?
    char fLandscape;            // Landscape or portrait??
} RTFDocument;

typedef struct save
{
    struct save *pNext;         // next save
    RTFCharacter        characterProperties;
    RTFParagraph        paragraphProperties;
    RTFSection          sectionProperities;
    RTFDocument         documentProperties;
    rkDestinationState  destinationState;
    rkInternalState     internalState;
} RTFSaveState;

typedef struct propmod
{
    rkActionType actn;      // size of value
    rkPropertyType prop;    // structure containing value
    int  offset;            // offset of value from base of structure
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

	RTFCharacter characterProperties;
	RTFParagraph paragraphProperties;
	RTFSection   sectionProperities;
	RTFDocument  documentProperties;
	
	RTFSaveState *psave;
	
	// RTFDoc buffer elements.
	NSData          * sourceRTFData;
	int               bufferPosition;
	unsigned char     putBuffer[64];
	int               putBufferLength;
	unsigned char     characters[8096];
	int               destinationLength;
	NSMutableAttributedString   * destinationString;
}

- (id)initWithFilePath:(NSString *)filePath;


@end






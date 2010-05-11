/* RTFType.h */



// typedef char bool;
#define fTrue 1
#define fFalse 0

typedef struct char_prop
{
    char fBold;
    char fUnderline;
    char fItalic;
} rkCharacterProperities;

typedef enum {justL, justR, justC, justF } JUST;
typedef struct para_prop
{
    int xaLeft;                 // Left indent in twips
    int xaRight;                // Right indent in twips
    int xaFirst;                // First line indent in twips
    JUST just;                  // Justification
} rkParagraphProperities;

typedef enum {sbkNon, sbkCol, sbkEvn, sbkOdd, sbkPg} SBK;
typedef enum {pgDec, pgURom, pgLRom, pgULtr, pgLLtr} PGN;
typedef struct sect_prop
{
    int cCols;                  // Number of columns
    SBK sbk;                    // Section break type
    int xaPgn;                  // X position of page number in twips
    int yaPgn;                  // Y position of page number in twips
    PGN pgnFormat;              // How the page number is formatted
} rkSectionProperities;

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
} rkDocumentProperities;

typedef enum { 
	rdsNorm,                    // Store the character in the destination
	rdsSkip                     // Skip the character
} rkDestinationState;

typedef enum { 
	internalStateNorm,         // Store characters
	internalStateBin,          // Store BIN data
	internalStateHex           // Store HEX data
} rkInternalState;

typedef struct save
{
    struct save *pNext;         // next save
    rkCharacterProperities characterProperties;
    rkParagraphProperities paragraphProperties;
    rkSectionProperities   sectionProperities;
    rkDocumentProperities  documentProperties;
    rkDestinationState     destinationState;
    rkInternalState        internalState;
} rkSavePropertyState;

// What types of properties are there?
typedef enum {
	ipropBold, ipropItalic, ipropUnderline, 
	ipropLeftInd,ipropRightInd, ipropFirstInd, 
	ipropCols, 
	ipropPgnX, ipropPgnY, ipropXaPage, ipropYaPage, 
	ipropXaLeft,ipropXaRight, ipropYaTop, ipropYaBottom, ipropPgnStart,
	ipropSbk, ipropPgnFormat, ipropFacingp, ipropLandscape,
	ipropJust, ipropPard, ipropPlain, ipropSectd,
	ipropMax 
} rkProperties;

typedef enum {
	actnSpec, 
	actnByte, 
	actnWord
} rkActionType;

typedef enum {
	rkPropertyTypeCharacter, 
	rkPropertyTypeParagraph, 
	rkPropertyTypeSection, 
	rkPropertyTypeDocument
} rkPropertyType;

typedef struct propmod
{
    rkActionType actn;      // size of value
    rkPropertyType prop;    // structure containing value
    int  offset;            // offset of value from base of structure
} rkProperty;

typedef enum {
	ipfnBin, 
	ipfnHex, 
	ipfnSkipDest 
} rkImageTypes;

typedef enum {
	idestPict, 
	idestSkip 
} rkDestinationType;

typedef enum {
	kwdChar, 
	kwdDest, 
	kwdProp, 
	kwdSpec
} rkKeywordType;

typedef struct symbol
{
    char *szKeyword;     // RTF keyword
    int  dflt;           // default value to use
    bool fPassDflt;      // true to use default value from this table
    rkKeywordType  kwd;  // base action to take
    int  idx;            // index into property table if kwd == kwdProp
						 // index into destination table if kwd == kwdDest
                         // character to print if kwd == kwdChar
} rkSymbol;

// RTF parser error codes
#define rkOK 0                      // Everything's fine!
#define rkStackUnderflow    1       // Unmatched '}'
#define rkStackOverflow     2       // Too many '{' -- memory exhausted
#define rkUnmatchedBrace    3       // RTF ended during an open group.
#define rkInvalidHex        4       // invalid hex character found in data
#define rkBadTable          5       // RTF table (sym or prop) invalid
#define rkAssertion         6       // Assertion failure
#define rkEndOfFile         7       // End of file reached while reading RTF


@interface RTFReader : NSObject {
	
	FILE *fpIn;
	
	int  cGroup;
	bool fSkipDestIfUnk;
	long cbBin;
	long lParam;
	
	rkDestinationState     destinationState;
	rkInternalState        internalState;

	rkCharacterProperities characterProperties;
	rkParagraphProperities paragraphProperties;
	rkSectionProperities   sectionProperities;
	rkDocumentProperities  documentProperties;
	
	rkSavePropertyState *psave;
	
	// RTFDoc buffer elements.
	NSData          * sourceRTFData;
	int               bufferPosition;
	unsigned char     putBuffer[64];
	int               putBufferLength;
	unsigned char     characters[8096];
	int               destinationLength;
	NSMutableData   * destinationString;
}

- (id)initWithFilePath:(NSString *)filePath;


@end






/* RTFType.h */



// typedef char bool;
#define fTrue 1
#define fFalse 0

typedef struct char_prop
{
    char fBold;
    char fUnderline;
    char fItalic;
} rkCharacterProperities;                  // CHaracter Properties

typedef enum {justL, justR, justC, justF } JUST;
typedef struct para_prop
{
    int xaLeft;                 // left indent in twips
    int xaRight;                // right indent in twips
    int xaFirst;                // first line indent in twips
    JUST just;                  // justification
} rkParagraphProperities;                  // PAragraph Properties

typedef enum {sbkNon, sbkCol, sbkEvn, sbkOdd, sbkPg} SBK;
typedef enum {pgDec, pgURom, pgLRom, pgULtr, pgLLtr} PGN;
typedef struct sect_prop
{
    int cCols;                  // number of columns
    SBK sbk;                    // section break type
    int xaPgn;                  // x position of page number in twips
    int yaPgn;                  // y position of page number in twips
    PGN pgnFormat;              // how the page number is formatted
} rkSectionProperities;                  // SEction Properties

typedef struct doc_prop
{
    int xaPage;                 // page width in twips
    int yaPage;                 // page height in twips
    int xaLeft;                 // left margin in twips
    int yaTop;                  // top margin in twips
    int xaRight;                // right margin in twips
    int yaBottom;               // bottom margin in twips
    int pgnStart;               // starting page number in twips
    char fFacingp;              // facing pages enabled?
    char fLandscape;            // landscape or portrait??
} rkDocumentProperities;                  // DOcument Properties

typedef enum { 
	rdsNorm, 
	rdsSkip 
} rkDestinationState;              // Rtf Destination State
typedef enum { 
	risNorm, 
	risBin, 
	risHex 
} rkInternalState;       // Rtf Internal State

typedef struct save             // property save structure
{
    struct save *pNext;         // next save
    rkCharacterProperities chp;
    rkParagraphProperities pap;
    rkSectionProperities sep;
    rkDocumentProperities dop;
    rkDestinationState rds;
    rkInternalState ris;
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
	propChp, 
	propPap, 
	propSep, 
	propDop
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
    char *szKeyword;        // RTF keyword
    int  dflt;              // default value to use
    bool fPassDflt;         // true to use default value from this table
    rkKeywordType  kwd;               // base action to take
    int  idx;               // index into property table if kwd == kwdProp
	// index into destination table if kwd == kwdDest
	// character to print if kwd == kwdChar
} rkSymbol;

typedef struct _RTFDOC {
	
	NSData          * src;
	int               pos;
	
	unsigned char     ungetbuf[64];
	int               ungetbufL;
	
	unsigned char     c[8096];
	int               cL;
	
	int               cch;
	
	NSMutableData   * dest;
	
	
	
} RTFDOC;

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
	
	int cGroup;
	bool fSkipDestIfUnk;
	long cbBin;
	long lParam;
	
	rkDestinationState rds;
	rkInternalState ris;
	
	rkCharacterProperities chp;
	rkParagraphProperities pap;
	rkSectionProperities sep;
	rkDocumentProperities dop;
	
	rkSavePropertyState *psave;
}

- (id)initWithFilePath:(NSString *)filePath;


@end






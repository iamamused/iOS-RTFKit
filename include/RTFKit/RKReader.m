//
//  RKReader.m
//  RTFKit
//
//  Created by Jeffrey Sambells on 10-05-10.
//  Copyright TropicalPixels. 2010. All rights reserved.
//  Please see the included LICENSE for applicable licensing information. 
//

/**
 * Based on http://latex2rtf.sourceforge.net/rtfspec_45.html
 *
 * Step 1:
 * Isolate RTF keywords and send them to parseNextKeyword;
 * Push and pop state at the start and end of RTF groups;
 * Send text to parseCharacter for further processing.
 *
 * Step 2:
 * get a control word (and its associated value) and
 * call translateKeyword to dispatch the control.
 *
 * Step 3.
 * Search keywordDescription for szKeyword and evaluate it appropriately.
 */

#import <UIKit/UIKit.h>
#import "RKReader.h"
#import <CoreText/CoreText.h>

@interface RKReader (Private) 
- (int) parse;
- (int) pushState;
- (int) popState;
- (int) parseNextKeyword;
- (int) parseCharacter:(int)ch;
- (int) translateKeyword:(char *)szKeyword withParam:(int)param fParam:(bool)fParam;
- (int) storeCharacter:(int)ch flush:(bool)flush;
- (int) endGroupAction:(rkDestinationState)rds;
- (int) applyPropertyChange:(rkProperty)rkProp val:(int)val;
- (int) changeOutputDestination:(rkDestinationType)idest;
- (int) parseSpecialKeyword:(rkSpecialType)ipfn;
- (int) parseSpecialProperty:(rkProperty)rkProp val:(int) val;

- (int) putCharacter:(int)ch;
- (int) getCharacterFromBuffer;

@end


@implementation RKReader

// RTF parser tables

// Property descriptions
static RTFProperty propertyDescription[rkPropMax] = {
    {rkActionTypeByte,   rkPropertyTypeCharacter,  offsetof(RTFCharacter, fBold)},       // rkPropBold
    {rkActionTypeByte,   rkPropertyTypeCharacter,  offsetof(RTFCharacter, fItalic)},     // rkPropItalic
    {rkActionTypeByte,   rkPropertyTypeCharacter,  offsetof(RTFCharacter, fUnderline)},  // rkPropUnderline
    {rkActionTypeWord,   rkPropertyTypeParagraph,  offsetof(RTFParagraph, xaLeft)},      // rkPropLeftInd
    {rkActionTypeWord,   rkPropertyTypeParagraph,  offsetof(RTFParagraph, xaRight)},     // rkPropRightInd
    {rkActionTypeWord,   rkPropertyTypeParagraph,  offsetof(RTFParagraph, xaFirst)},     // rkPropFirstInd
    {rkActionTypeWord,   rkPropertyTypeSection,    offsetof(RTFSection,   cCols)},       // rkPropCols
    {rkActionTypeWord,   rkPropertyTypeSection,    offsetof(RTFSection,   xaPgn)},       // rkPropPgnX
    {rkActionTypeWord,   rkPropertyTypeSection,    offsetof(RTFSection,   yaPgn)},       // rkPropPgnY
    {rkActionTypeWord,   rkPropertyTypeDocument,   offsetof(RTFDocument,  xaPage)},      // rkPropXaPage
    {rkActionTypeWord,   rkPropertyTypeDocument,   offsetof(RTFDocument,  yaPage)},      // rkPropYaPage
    {rkActionTypeWord,   rkPropertyTypeDocument,   offsetof(RTFDocument,  xaLeft)},      // rkPropXaLeft
    {rkActionTypeWord,   rkPropertyTypeDocument,   offsetof(RTFDocument,  xaRight)},     // rkPropXaRight
    {rkActionTypeWord,   rkPropertyTypeDocument,   offsetof(RTFDocument,  yaTop)},       // rkPropYaTop
    {rkActionTypeWord,   rkPropertyTypeDocument,   offsetof(RTFDocument,  yaBottom)},    // rkPropYaBottom
    {rkActionTypeWord,   rkPropertyTypeDocument,   offsetof(RTFDocument,  pgnStart)},    // rkPropPgnStart
    {rkActionTypeByte,   rkPropertyTypeSection,    offsetof(RTFSection,   sbk)},         // rkPropSbk
    {rkActionTypeByte,   rkPropertyTypeSection,    offsetof(RTFSection,   pgnFormat)},   // rkPropPgnFormat
    {rkActionTypeByte,   rkPropertyTypeDocument,   offsetof(RTFDocument,  fFacingp)},    // rkPropFacingp
    {rkActionTypeByte,   rkPropertyTypeDocument,   offsetof(RTFDocument,  fLandscape)},  // rkPropLandscape
    {rkActionTypeByte,   rkPropertyTypeParagraph,  offsetof(RTFParagraph, just)},        // rkPropJust
    {rkActionTypeSpec,   rkPropertyTypeParagraph,  0},                                   // rkPropPard
    {rkActionTypeSpec,   rkPropertyTypeCharacter,  0},                                   // rkPropPlain
    {rkActionTypeSpec,   rkPropertyTypeSection,    0},                                   // rkPropSectd
};

// Keyword descriptions
static RTFSymbol keywordDescription[] = {
	//  keyword     dflt    fPassDflt   kwd         idx
    {"b",        1,      fFalse,     rkKeywordTypeProperty,    rkPropBold},      // kCTFontBoldTrait
    {"u",        1,      fFalse,     rkKeywordTypeProperty,    rkPropUnderline}, //
    {"i",        1,      fFalse,     rkKeywordTypeProperty,    rkPropItalic},    // kCTFontItalicTrait
    {"li",       0,      fFalse,     rkKeywordTypeProperty,    rkPropLeftInd},   //
    {"ri",       0,      fFalse,     rkKeywordTypeProperty,    rkPropRightInd},  //
    {"fi",       0,      fFalse,     rkKeywordTypeProperty,    rkPropFirstInd},  //
    {"cols",     1,      fFalse,     rkKeywordTypeProperty,    rkPropCols},      //
    {"sbknone",  sbkNon, fTrue,      rkKeywordTypeProperty,    rkPropSbk},       //
    {"sbkcol",   sbkCol, fTrue,      rkKeywordTypeProperty,    rkPropSbk},       //
    {"sbkeven",  sbkEvn, fTrue,      rkKeywordTypeProperty,    rkPropSbk},       //
    {"sbkodd",   sbkOdd, fTrue,      rkKeywordTypeProperty,    rkPropSbk},       //
    {"sbkpage",  sbkPg,  fTrue,      rkKeywordTypeProperty,    rkPropSbk},
    {"pgnx",     0,      fFalse,     rkKeywordTypeProperty,    rkPropPgnX},
    {"pgny",     0,      fFalse,     rkKeywordTypeProperty,    rkPropPgnY},
    {"pgndec",   pgDec,  fTrue,      rkKeywordTypeProperty,    rkPropPgnFormat},
    {"pgnucrm",  pgURom, fTrue,      rkKeywordTypeProperty,    rkPropPgnFormat},
    {"pgnlcrm",  pgLRom, fTrue,      rkKeywordTypeProperty,    rkPropPgnFormat},
    {"pgnucltr", pgULtr, fTrue,      rkKeywordTypeProperty,    rkPropPgnFormat},
    {"pgnlcltr", pgLLtr, fTrue,      rkKeywordTypeProperty,    rkPropPgnFormat},
    {"qc",       rkJustificationCenter,  fTrue,      rkKeywordTypeProperty,    rkPropJust},
    {"ql",       rkJustificationLeft,  fTrue,      rkKeywordTypeProperty,    rkPropJust},
    {"qr",       rkJustificationRight,  fTrue,      rkKeywordTypeProperty,    rkPropJust},
    {"qj",       rkJustificationForced,  fTrue,      rkKeywordTypeProperty,    rkPropJust},
    {"paperw",   12240,  fFalse,     rkKeywordTypeProperty,    rkPropXaPage},
    {"paperh",   15480,  fFalse,     rkKeywordTypeProperty,    rkPropYaPage},
    {"margl",    1800,   fFalse,     rkKeywordTypeProperty,    rkPropXaLeft},
    {"margr",    1800,   fFalse,     rkKeywordTypeProperty,    rkPropXaRight},
    {"margt",    1440,   fFalse,     rkKeywordTypeProperty,    rkPropYaTop},
    {"margb",    1440,   fFalse,     rkKeywordTypeProperty,    rkPropYaBottom},
    {"pgnstart", 1,      fTrue,      rkKeywordTypeProperty,    rkPropPgnStart},
    {"facingp",  1,      fTrue,      rkKeywordTypeProperty,    rkPropFacingp},
    {"landscape",1,      fTrue,      rkKeywordTypeProperty,    rkPropLandscape},
    {"par",      0,      fFalse,     rkKeywordTypeCharacter,    0x0a},
    
    
    
    // JIMB BUG BUG ...
    // Most of these need better mapping ...
    {"emspace",  0,      fFalse,     rkKeywordTypeCharacter,    ' '},
    {"enspace",  0,      fFalse,     rkKeywordTypeCharacter,    ' '},
    {"~",        0,      fFalse,     rkKeywordTypeCharacter,    ' '},
    {"lquote",   0,      fFalse,     rkKeywordTypeCharacter,    '\''},
    {"rquote",   0,      fFalse,     rkKeywordTypeCharacter,    '\''},
    {"-",        0,      fFalse,     rkKeywordTypeCharacter,    '-'},
    {"_",        0,      fFalse,     rkKeywordTypeCharacter,    '-'},
    {"emdash",   0,      fFalse,     rkKeywordTypeCharacter,    '-'},
    {"endash",   0,      fFalse,     rkKeywordTypeCharacter,    '-'},
    {"line",     0,      fFalse,     rkKeywordTypeCharacter,    0x0a},
    {"page",     0,      fFalse,     rkKeywordTypeCharacter,    0x0a},
    {"pagebb",   0,      fFalse,     rkKeywordTypeCharacter,    0x0a},
    {"outlinelevel",  0, fFalse,     rkKeywordTypeCharacter,    0x0a},
	
	
    
    {"\0x0a",    0,      fFalse,     rkKeywordTypeCharacter,    0x0a},
    {"\0x0d",    0,      fFalse,     rkKeywordTypeCharacter,    0x0a},
    {"tab",      0,      fFalse,     rkKeywordTypeCharacter,    0x09},
    {"ldblquote",0,      fFalse,     rkKeywordTypeCharacter,    '"'},
    {"rdblquote",0,      fFalse,     rkKeywordTypeCharacter,    '"'},
    {"bin",      0,      fFalse,     rkKeywordTypeSpecial,        rkSpecialTypeBin},
    {"*",        0,      fFalse,     rkKeywordTypeSpecial,        rkSpecialTypeSkip},
    {"'",        0,      fFalse,     rkKeywordTypeSpecial,        rkSpecialTypeHex},
    {"author",   0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"buptim",   0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"colortbl", 0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"comment",  0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"creatim",  0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"doccomm",  0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"fonttbl",  0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"footer",   0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"footerf",  0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"footerl",  0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"footerr",  0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"footnote", 0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"ftncn",    0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"ftnsep",   0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"ftnsepc",  0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"header",   0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"headerf",  0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"headerl",  0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"headerr",  0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"info",     0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"keywords", 0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"operator", 0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"pict",     0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"printim",  0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"private1", 0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"revtim",   0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"rxe",      0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"stylesheet",   0,  fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"subject",  0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"tc",       0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"title",    0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"txe",      0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"xe",       0,      fFalse,     rkKeywordTypeDestination,    rkDestinationTypeSkip},
    {"{",        0,      fFalse,     rkKeywordTypeCharacter,      '{'},
    {"}",        0,      fFalse,     rkKeywordTypeCharacter,      '}'},
    {"\\",       0,      fFalse,     rkKeywordTypeCharacter,      '\\'}
};
int isymMax = sizeof(keywordDescription) / sizeof(RTFSymbol);


/**
 * Initialize the object with a path to the RTF document.
 */
- (id)initWithFilePath:(NSString *)filePath;
{
	
	NSMutableString * newText = nil;
		
    sourceRTFData  = [[NSData dataWithContentsOfMappedFile:filePath] retain];
    destinationString = [[[NSMutableAttributedString alloc] initWithString:@""] retain];
	
	if ([self parse] == rkOK) {
		NSLog(@"%@", destinationString);
	}
	
	NSString *myText = [NSString stringWithContentsOfFile:filePath];  
	NSLog(@"%@", myText);
	
	return self;
}

- (void)dealloc;
{
	//[sourceRTFData release];
	//[destinationString release];
	[super dealloc];
}


/**
 * Set the property identified by prop to the value val.
 */
- (int) applyPropertyChange:(rkProperty)prop val:(int)val;
{
    char *pb;
	
    if (destinationState == rkDestinationStateSkip) {
		// If we're skipping text don't do anything.
        return rkOK;
	}
	
	// Get the appropriate property set based on the description.
    switch (propertyDescription[prop].prop) {
		
		case rkPropertyTypeDocument:
			pb = (char *)&documentProperties;
			break;
		
		case rkPropertyTypeSection:
			pb = (char *)&sectionProperities;
			break;
		
		case rkPropertyTypeParagraph:
			pb = (char *)&paragraphProperties;
			break;
		
		case rkPropertyTypeCharacter:
			pb = (char *)&characterProperties;
			break;
			
		default:
			if (propertyDescription[prop].actn != rkActionTypeSpec) {
				return rkBadTable;
			}
			break;
    }
	
	// Apply the appropriate action based on the description
    switch (propertyDescription[prop].actn) {
		
		case rkActionTypeByte:
			pb[propertyDescription[prop].offset] = (unsigned char)val;
			break;
			
		case rkActionTypeWord:
			(*(int *)(pb+propertyDescription[prop].offset)) = val;
			break;
			
		case rkActionTypeSpec:
			return [self parseSpecialProperty:prop val:val];
			break;
			
		default:
			return rkBadTable;
    }
	
    return rkOK;
}

/**
 * Set a property that requires code to evaluate.
 */
- (int) parseSpecialProperty:(rkProperty)prop val:(int)val;
{
    switch (prop) {
		
		case rkPropPard:
			memset(&paragraphProperties, 0, sizeof(paragraphProperties));
			return rkOK;
		
		case rkPropPlain:
			memset(&characterProperties, 0, sizeof(characterProperties));
			return rkOK;
		
		case rkPropSectd:
			memset(&sectionProperities, 0, sizeof(sectionProperities));
			return rkOK;
	
		default:
			return rkBadTable;
    }
	
    return rkBadTable;
}

/**
 * Search keywordDescription for szKeyword and evaluate it appropriately.
 *
 * Inputs:
 * szKeyword:   The RTF control to evaluate.
 * param:       The parameter of the RTF control.
 * fParam:      fTrue if the control had a parameter; (that is, if param is valid)
 *              fFalse if it did not.
 */
- (int) translateKeyword:(char *)szKeyword withParam:(int)param fParam:(bool)fParam;
{
	//NSLog(@"keyword: %@", [NSString stringWithCString:szKeyword]);
    int isym;
	
    // search for szKeyword in keywordDescription
	
    for (isym = 0; isym < isymMax; isym++)
        if (strcmp(szKeyword, keywordDescription[isym].szKeyword) == 0)
            break;
    if (isym == isymMax)            // control word not found
    {
        if (fSkipDestIfUnk)         // if this is a new destination
            destinationState = rkDestinationStateSkip;          // skip the destination
		// else just discard it
        fSkipDestIfUnk = fFalse;
        return rkOK;
    }
	
    // Found it!  use kwd and idx to determine what to do with it.
	
    fSkipDestIfUnk = fFalse;
	
    switch (keywordDescription[isym].kwd) {
			
		case rkKeywordTypeProperty:
			if (keywordDescription[isym].fPassDflt || !fParam)
				param = keywordDescription[isym].dflt;
			return [self applyPropertyChange:(rkProperty)keywordDescription[isym].idx val:param];
		
		case rkKeywordTypeCharacter:
			return [self parseCharacter:keywordDescription[isym].idx];
		
		case rkKeywordTypeDestination:
			return [self changeOutputDestination:(rkDestinationType)keywordDescription[isym].idx];
		
		case rkKeywordTypeSpecial:
			return [self parseSpecialKeyword:(rkSpecialType)keywordDescription[isym].idx];
		
		default:
			return rkBadTable;
	}
	
    return rkBadTable;
}

/**
 * Change to the destination specified by idest.
 * There's usually more to do here than this...
 */
- (int) changeOutputDestination:(rkDestinationType)dt
{
    if (destinationState == rkDestinationStateSkip) {
		// if we're skipping text don't do anything.
        return rkOK;
	}
	
	// TODO: handle other types.
    switch (dt) {
		default:
			// when in doubt, skip it...
			destinationState = rkDestinationStateSkip;              
			break;
    }
	
    return rkOK;
}

/**
 * The destination specified by destinationState is coming to a close.
 * If there's any cleanup that needs to be done, do it now.
 */
- (int) endGroupAction:(rkDestinationState)rds
{
    return rkOK;
}

/**
 * Evaluate an RTF control that needs special processing.
 */
- (int) parseSpecialKeyword:(rkSpecialType)type 
{
    if (destinationState == rkDestinationStateSkip && type != rkSpecialTypeBin) {
		// if we're skipping, and it's not the \bin keyword, ignore it.
        return rkOK;
	}
	
    switch (type) {
			
		case rkSpecialTypeBin:
			internalState = rkInternalStateBin;
			cbBin = lParam;
			break;
			
		case rkSpecialTypeSkip:
			fSkipDestIfUnk = fTrue;
			break;
		
		case rkSpecialTypeHex:
			internalState = rkInternalStateHex;
			break;
		
		default:
			return rkBadTable;
    }
	
    return rkOK;
}


/**
 * Get a character
 */
- (int) getCharacterFromBuffer;
{
	
    unsigned char ch = 0x00;
    
    if (putBufferLength > 0) {
        return (int)putBuffer[--putBufferLength];
	}
    
    if (bufferPosition >= [sourceRTFData length]) {
        return EOF;
	}
	
    NSRange range = {bufferPosition, 1};
    
	[sourceRTFData getBytes:&ch range:range];
    
    bufferPosition++;
    
    return (int)ch;
    
} 


/**
 * Put a character
 */
- (int)putCharacter:(int)ch
{
    if (putBufferLength >= sizeof(putBuffer)/sizeof(*putBuffer)) {
        return EOF;
	}

    putBuffer[putBufferLength++] = (unsigned char)ch;
    
	return ch;
} 


/**
 * Stat parsing
 */
- (int) parse;
{
    int ch;
    int ec;
    int cNibble = 2;
    int b = 0;
	
    while ((ch = [self getCharacterFromBuffer]) != EOF)
    {
        if (cGroup < 0) {
            return rkStackUnderflow;
		}
		
        if (internalState == rkInternalStateBin) {
			
			// If we're parsing binary data, handle it directly.
            if ((ec = [self parseCharacter:ch]) != rkOK) {
                return ec;
			}
			
        } else {
			
            switch (ch) {
					
				case '{':
					//NSLog(@"Start { %d", destinationLength);
					if ((ec = [self pushState]) != rkOK)
						return ec;
					break;
				
				case '}':
					//NSLog(@"End } %d", destinationLength);
					if ((ec = [self popState]) != rkOK)
						return ec;
					break;
				
				case '\\':
					//NSLog(@"Parse control words %d", destinationLength);
					// Parse control words
					if ((ec = [self parseNextKeyword]) != rkOK)
						return ec;
					break;
				
				case 0x0d:
					break;
				
				case 0x0a:
					// cr and lf are noise characters...
					//storeCharacter('\n', fp, false);
					break;
				
				default:
					
					// parse out the characters
					if (internalState == rkInternalStateNorm) {
						//NSLog(@"Parse normal character %d", destinationLength);
						if ((ec = [self parseCharacter:ch]) != rkOK) {
							return ec;
						}
					} else {
						// parsing hex data
						if (internalState != rkInternalStateHex) {
							return rkAssertion;
						}
						
						b = b << 4;
						
						if (isdigit(ch)) {
							b += (char) ch - '0';
						} else {
							if (islower(ch))
							{
								if (ch < 'a' || ch > 'f')
									return rkInvalidHex;
								b += 0x0a + (char) ch - 'a';
							}
							else
							{
								if (ch < 'A' || ch > 'F')
									return rkInvalidHex;
								b += 0x0A + (char) ch - 'A';
							}
						}
						
						cNibble--;
						if (!cNibble) {
							if ((ec = [self parseCharacter:b]) != rkOK) {
								return ec;
							}
							cNibble = 2;
							b = 0;
							internalState = rkInternalStateNorm;
						}
					}
					break;
            }
        }
    }
    
    [self storeCharacter:'\n' flush:true];
    
    if (cGroup < 0) {
        return rkStackUnderflow;
	}
    
	if (cGroup > 0) {
        return rkUnmatchedBrace;
	}
	
    return rkOK;
}

/**
 * Save relevant info on a linked list of RTFSaveState structures.
 */
- (int) pushState
{
    RTFSaveState *psaveNew = (RTFSaveState *)malloc(sizeof(RTFSaveState));
    
	if (!psaveNew) {
        return rkStackOverflow;
	}
	
    psaveNew -> pNext = psave;
    psaveNew -> characterProperties = characterProperties;
    psaveNew -> paragraphProperties = paragraphProperties;
    psaveNew -> sectionProperities = sectionProperities;
    psaveNew -> documentProperties = documentProperties;
    psaveNew -> destinationState = destinationState;
    psaveNew -> internalState = internalState;
	
    internalState = rkInternalStateNorm;
    psave = psaveNew;
    cGroup++;
    
	return rkOK;
}

/**
 * If we're ending a destination (that is, the destination is changing),
 * call endGroupAction.
 * Always restore relevant info from the top of the RTFSaveState list.
 */
- (int) popState
{
    RTFSaveState *psaveOld;
    int ec;
	
    if (!psave)
        return rkStackUnderflow;
	
    if (destinationState != psave->destinationState)
    {
        if ((ec = [self endGroupAction:destinationState]) != rkOK)
            return ec;
    }
	
    characterProperties = psave->characterProperties;
    paragraphProperties = psave->paragraphProperties;
    sectionProperities = psave->sectionProperities;
    documentProperties = psave->documentProperties;
    destinationState = psave->destinationState;
    internalState = psave->internalState;
	
    psaveOld = psave;
    psave = psave->pNext;
    cGroup--;
    free(psaveOld);
    return rkOK;
}


/**
 * Parse out keywords
 */
- (int) parseNextKeyword
{
    int ch;
    bool fParam = fFalse;
    bool fNeg = fFalse;
    int param = 0;
    char *pch;
    char szKeyword[30];
    char szParameter[20];
	
    szKeyword[0] = '\0';
    szParameter[0] = '\0';
    if ((ch = [self getCharacterFromBuffer]) == EOF)
        return rkEndOfFile;
    if (!isalpha(ch))           // a control symbol; no delimiter.
    {
        szKeyword[0] = (char) ch;
        szKeyword[1] = '\0';
		
        return [self translateKeyword:szKeyword withParam:0 fParam:fParam];
    }
    for (pch = szKeyword; isalpha(ch); ch = [self getCharacterFromBuffer])
        *pch++ = (char) ch;
    *pch = '\0';
    if (ch == '-')
    {
        fNeg  = fTrue;
        // if ((ch = getc(fp)) == EOF)
        if ((ch = [self getCharacterFromBuffer]) == EOF)
            return rkEndOfFile;
    }
    if (isdigit(ch))
    {
        fParam = fTrue; // a digit after the control means we have a parameter
        for (pch = szParameter; isdigit(ch); ch = [self getCharacterFromBuffer])
            *pch++ = (char) ch;
        *pch = '\0';
        param = atoi(szParameter);
        if (fNeg)
            param = -param;
        lParam = atol(szParameter);
        if (fNeg)
            param = -param;
    }
    
	if (ch != ' ') {
        [self putCharacter:ch];
	}
	
    return [self translateKeyword:szKeyword withParam:param fParam:fParam];
}

/**
 * Route the character to the appropriate destination stream.
 */
- (int) parseCharacter:(int)ch;
{
    if (internalState == rkInternalStateBin && --cbBin <= 0) {
        internalState = rkInternalStateNorm;
	}
	
    switch (destinationState) {
		case rkDestinationStateSkip:
			// Skip this character.
			return rkOK;
			
		case rkDestinationStateNorm:
			// Output a character. Properties are valid at this point.
			return [self storeCharacter:ch flush:false];   
			
		default:
			// handle other destinations....
			return rkOK;
    }
}


/**
 * Send a character to the output file.
 */
- (int) storeCharacter:(int)ch flush:(bool)flush;
{   
	/*
    char boldTest = characterProperties.fBold;
	if (boldTest == fTrue) {
		NSLog( @"Bold at %d", destinationLength );
	} else {
		NSLog(@"Not Bold at %d", destinationLength);
	}
	 */
		
	unsigned char chars[1];
	chars[0] = ch;
	
	NSString *s = [NSString stringWithCString:chars length:1];
	
	
	CFStringRef keys[] = { 
		//kCTCharacterShapeAttributeName,
		kCTFontAttributeName
		//kCTKernAttributeName,
		//kCTLigatureAttributeName,
		//kCTForegroundColorAttributeName,
		//kCTForegroundColorFromContextAttributeName,
		//kCTParagraphStyleAttributeName,
		//kCTStrokeWidthAttributeName,
		//kCTStrokeColorAttributeName,
		//kCTSuperscriptAttributeName,
		//kCTUnderlineColorAttributeName,
		//kCTUnderlineStyleAttributeName,
		//kCTVerticalFormsAttributeName,
		//kCTGlyphInfoAttributeName,
		//kCTRunDelegateAttributeName
	};
	
	CFTypeRef values[] = { 
		CTFontCreateWithName( (CFStringRef)@"Helvetica", 12, NULL) 
	};
	

	CFDictionaryRef attr = CFDictionaryCreate(
											  NULL, 
											  (const void **)&keys, 
											  (const void **)&values,
											  sizeof(keys) / sizeof(keys[0]), 
											  &kCFTypeDictionaryKeyCallBacks, 
											  &kCFTypeDictionaryValueCallBacks
											  );
	
	NSAttributedString *chr = [[NSAttributedString alloc] initWithString:s attributes:(NSDictionary *)attr];
	[destinationString appendAttributedString:chr];
	CFRelease(attr);
	[chr release];
	
	destinationLength++;
	
    return rkOK;
}

@end


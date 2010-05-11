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
#import "RTFReader.h"

@interface RTFReader (Private) 
- (int) parse;
- (int) pushState;
- (int) popState;
- (int) parseNextKeyword;
- (int) parseCharacter:(int)ch;
- (int) translateKeyword:(char *)szKeyword withParam:(int)param fParam:(bool)fParam;
- (int) storeCharacter:(int)ch flush:(bool)flush;
- (int) endGroupAction:(rkDestinationState)rds;
- (int) applyPropertyChange:(rkProperties)iprop val:(int)val;
- (int) changeOutputDestination:(rkDestinationType)idest;
- (int) parseSpecialKeyword:(rkImageTypes)ipfn;
- (int) parseSpecialProperty:(rkProperties)iprop val:(int) val;

- (int) putCharacter:(int)ch;
- (int) getCharacterFromBuffer;

@end


@implementation RTFReader

// RTF parser tables

// Property descriptions
static rkProperty propertyDescription[ipropMax] = {
    {actnByte,   rkPropertyTypeCharacter,    offsetof(rkCharacterProperities, fBold)},       // ipropBold
    {actnByte,   rkPropertyTypeCharacter,    offsetof(rkCharacterProperities, fItalic)},     // ipropItalic
    {actnByte,   rkPropertyTypeCharacter,    offsetof(rkCharacterProperities, fUnderline)},  // ipropUnderline
    {actnWord,   rkPropertyTypeParagraph,    offsetof(rkParagraphProperities, xaLeft)},      // ipropLeftInd
    {actnWord,   rkPropertyTypeParagraph,    offsetof(rkParagraphProperities, xaRight)},     // ipropRightInd
    {actnWord,   rkPropertyTypeParagraph,    offsetof(rkParagraphProperities, xaFirst)},     // ipropFirstInd
    {actnWord,   rkPropertyTypeSection,    offsetof(rkSectionProperities, cCols)},       // ipropCols
    {actnWord,   rkPropertyTypeSection,    offsetof(rkSectionProperities, xaPgn)},       // ipropPgnX
    {actnWord,   rkPropertyTypeSection,    offsetof(rkSectionProperities, yaPgn)},       // ipropPgnY
    {actnWord,   rkPropertyTypeDocument,    offsetof(rkDocumentProperities, xaPage)},      // ipropXaPage
    {actnWord,   rkPropertyTypeDocument,    offsetof(rkDocumentProperities, yaPage)},      // ipropYaPage
    {actnWord,   rkPropertyTypeDocument,    offsetof(rkDocumentProperities, xaLeft)},      // ipropXaLeft
    {actnWord,   rkPropertyTypeDocument,    offsetof(rkDocumentProperities, xaRight)},     // ipropXaRight
    {actnWord,   rkPropertyTypeDocument,    offsetof(rkDocumentProperities, yaTop)},       // ipropYaTop
    {actnWord,   rkPropertyTypeDocument,    offsetof(rkDocumentProperities, yaBottom)},    // ipropYaBottom
    {actnWord,   rkPropertyTypeDocument,    offsetof(rkDocumentProperities, pgnStart)},    // ipropPgnStart
    {actnByte,   rkPropertyTypeSection,    offsetof(rkSectionProperities, sbk)},         // ipropSbk
    {actnByte,   rkPropertyTypeSection,    offsetof(rkSectionProperities, pgnFormat)},   // ipropPgnFormat
    {actnByte,   rkPropertyTypeDocument,    offsetof(rkDocumentProperities, fFacingp)},    // ipropFacingp
    {actnByte,   rkPropertyTypeDocument,    offsetof(rkDocumentProperities, fLandscape)},  // ipropLandscape
    {actnByte,   rkPropertyTypeParagraph,    offsetof(rkParagraphProperities, just)},        // ipropJust
    {actnSpec,   rkPropertyTypeParagraph,    0},                          // ipropPard
    {actnSpec,   rkPropertyTypeCharacter,    0},                          // ipropPlain
    {actnSpec,   rkPropertyTypeSection,    0},                          // ipropSectd
};

// Keyword descriptions
static rkSymbol keywordDescription[] = {
	//  keyword     dflt    fPassDflt   kwd         idx
    {"b",        1,      fFalse,     kwdProp,    ipropBold},      // kCTFontBoldTrait
    {"u",        1,      fFalse,     kwdProp,    ipropUnderline}, //
    {"i",        1,      fFalse,     kwdProp,    ipropItalic},    // kCTFontItalicTrait
    {"li",       0,      fFalse,     kwdProp,    ipropLeftInd},   //
    {"ri",       0,      fFalse,     kwdProp,    ipropRightInd},  //
    {"fi",       0,      fFalse,     kwdProp,    ipropFirstInd},  //
    {"cols",     1,      fFalse,     kwdProp,    ipropCols},      //
    {"sbknone",  sbkNon, fTrue,      kwdProp,    ipropSbk},       //
    {"sbkcol",   sbkCol, fTrue,      kwdProp,    ipropSbk},       //
    {"sbkeven",  sbkEvn, fTrue,      kwdProp,    ipropSbk},       //
    {"sbkodd",   sbkOdd, fTrue,      kwdProp,    ipropSbk},       //
    {"sbkpage",  sbkPg,  fTrue,      kwdProp,    ipropSbk},
    {"pgnx",     0,      fFalse,     kwdProp,    ipropPgnX},
    {"pgny",     0,      fFalse,     kwdProp,    ipropPgnY},
    {"pgndec",   pgDec,  fTrue,      kwdProp,    ipropPgnFormat},
    {"pgnucrm",  pgURom, fTrue,      kwdProp,    ipropPgnFormat},
    {"pgnlcrm",  pgLRom, fTrue,      kwdProp,    ipropPgnFormat},
    {"pgnucltr", pgULtr, fTrue,      kwdProp,    ipropPgnFormat},
    {"pgnlcltr", pgLLtr, fTrue,      kwdProp,    ipropPgnFormat},
    {"qc",       justC,  fTrue,      kwdProp,    ipropJust},
    {"ql",       justL,  fTrue,      kwdProp,    ipropJust},
    {"qr",       justR,  fTrue,      kwdProp,    ipropJust},
    {"qj",       justF,  fTrue,      kwdProp,    ipropJust},
    {"paperw",   12240,  fFalse,     kwdProp,    ipropXaPage},
    {"paperh",   15480,  fFalse,     kwdProp,    ipropYaPage},
    {"margl",    1800,   fFalse,     kwdProp,    ipropXaLeft},
    {"margr",    1800,   fFalse,     kwdProp,    ipropXaRight},
    {"margt",    1440,   fFalse,     kwdProp,    ipropYaTop},
    {"margb",    1440,   fFalse,     kwdProp,    ipropYaBottom},
    {"pgnstart", 1,      fTrue,      kwdProp,    ipropPgnStart},
    {"facingp",  1,      fTrue,      kwdProp,    ipropFacingp},
    {"landscape",1,      fTrue,      kwdProp,    ipropLandscape},
    {"par",      0,      fFalse,     kwdChar,    0x0a},
    
    
    
    // JIMB BUG BUG ...
    // Most of these need better mapping ...
    {"emspace",  0,      fFalse,     kwdChar,    ' '},
    {"enspace",  0,      fFalse,     kwdChar,    ' '},
    {"~",        0,      fFalse,     kwdChar,    ' '},
    {"lquote",   0,      fFalse,     kwdChar,    '\''},
    {"rquote",   0,      fFalse,     kwdChar,    '\''},
    {"-",        0,      fFalse,     kwdChar,    '-'},
    {"_",        0,      fFalse,     kwdChar,    '-'},
    {"emdash",   0,      fFalse,     kwdChar,    '-'},
    {"endash",   0,      fFalse,     kwdChar,    '-'},
    {"line",     0,      fFalse,     kwdChar,    0x0a},
    {"page",     0,      fFalse,     kwdChar,    0x0a},
    {"pagebb",   0,      fFalse,     kwdChar,    0x0a},
    {"outlinelevel",  0, fFalse,     kwdChar,    0x0a},
	
	
    
    {"\0x0a",    0,      fFalse,     kwdChar,    0x0a},
    {"\0x0d",    0,      fFalse,     kwdChar,    0x0a},
    {"tab",      0,      fFalse,     kwdChar,    0x09},
    {"ldblquote",0,      fFalse,     kwdChar,    '"'},
    {"rdblquote",0,      fFalse,     kwdChar,    '"'},
    {"bin",      0,      fFalse,     kwdSpec,    ipfnBin},
    {"*",        0,      fFalse,     kwdSpec,    ipfnSkipDest},
    {"'",        0,      fFalse,     kwdSpec,    ipfnHex},
    {"author",   0,      fFalse,     kwdDest,    idestSkip},
    {"buptim",   0,      fFalse,     kwdDest,    idestSkip},
    {"colortbl", 0,      fFalse,     kwdDest,    idestSkip},
    {"comment",  0,      fFalse,     kwdDest,    idestSkip},
    {"creatim",  0,      fFalse,     kwdDest,    idestSkip},
    {"doccomm",  0,      fFalse,     kwdDest,    idestSkip},
    {"fonttbl",  0,      fFalse,     kwdDest,    idestSkip},
    {"footer",   0,      fFalse,     kwdDest,    idestSkip},
    {"footerf",  0,      fFalse,     kwdDest,    idestSkip},
    {"footerl",  0,      fFalse,     kwdDest,    idestSkip},
    {"footerr",  0,      fFalse,     kwdDest,    idestSkip},
    {"footnote", 0,      fFalse,     kwdDest,    idestSkip},
    {"ftncn",    0,      fFalse,     kwdDest,    idestSkip},
    {"ftnsep",   0,      fFalse,     kwdDest,    idestSkip},
    {"ftnsepc",  0,      fFalse,     kwdDest,    idestSkip},
    {"header",   0,      fFalse,     kwdDest,    idestSkip},
    {"headerf",  0,      fFalse,     kwdDest,    idestSkip},
    {"headerl",  0,      fFalse,     kwdDest,    idestSkip},
    {"headerr",  0,      fFalse,     kwdDest,    idestSkip},
    {"info",     0,      fFalse,     kwdDest,    idestSkip},
    {"keywords", 0,      fFalse,     kwdDest,    idestSkip},
    {"operator", 0,      fFalse,     kwdDest,    idestSkip},
    {"pict",     0,      fFalse,     kwdDest,    idestSkip},
    {"printim",  0,      fFalse,     kwdDest,    idestSkip},
    {"private1", 0,      fFalse,     kwdDest,    idestSkip},
    {"revtim",   0,      fFalse,     kwdDest,    idestSkip},
    {"rxe",      0,      fFalse,     kwdDest,    idestSkip},
    {"stylesheet",   0,  fFalse,     kwdDest,    idestSkip},
    {"subject",  0,      fFalse,     kwdDest,    idestSkip},
    {"tc",       0,      fFalse,     kwdDest,    idestSkip},
    {"title",    0,      fFalse,     kwdDest,    idestSkip},
    {"txe",      0,      fFalse,     kwdDest,    idestSkip},
    {"xe",       0,      fFalse,     kwdDest,    idestSkip},
    {"{",        0,      fFalse,     kwdChar,    '{'},
    {"}",        0,      fFalse,     kwdChar,    '}'},
    {"\\",       0,      fFalse,     kwdChar,    '\\'}
};
int isymMax = sizeof(keywordDescription) / sizeof(rkSymbol);


/**
 * Initialize the object with a path to the RTF document.
 */
- (id)initWithFilePath:(NSString *)filePath;
{
	
	NSMutableString * newText = nil;
		
    sourceRTFData  = [[NSData dataWithContentsOfMappedFile:filePath] retain];
    destinationString = [[NSMutableData alloc] initWithCapacity:4096];
	
	if ([self parse] == rkOK) {
		newText = [[[NSMutableString alloc] initWithData:destinationString encoding:NSUTF8StringEncoding] retain];
		NSLog(@"%@", newText);
	}
	
	NSString *myText = [NSString stringWithContentsOfFile:filePath];  
	NSLog(@"%@", myText);
	
	return self;
}

- (void)dealloc;
{
	[sourceRTFData release];
	[destinationString release];
	[super dealloc];
}


/**
 * Set the property identified by iprop to the value val.
 */
- (int) applyPropertyChange:(rkProperties)iprop val:(int)val;
{
    char *pb;
	
    if (destinationState == rdsSkip)                 // If we're skipping text,
        return rkOK;                    // don't do anything.
	
    switch (propertyDescription[iprop].prop)
    {
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
			if (propertyDescription[iprop].actn != actnSpec)
				return rkBadTable;
			break;
    }
    switch (propertyDescription[iprop].actn)
    {
		case actnByte:
			pb[propertyDescription[iprop].offset] = (unsigned char) val;
			break;
		case actnWord:
			(*(int *) (pb+propertyDescription[iprop].offset)) = val;
			break;
		case actnSpec:
			return [self parseSpecialProperty:iprop val:val];
			break;
		default:
			return rkBadTable;
    }
    return rkOK;
}

/**
 * Set a property that requires code to evaluate.
 */
- (int) parseSpecialProperty:(rkProperties)iprop val:(int) val
{
    switch (iprop)
    {
		case ipropPard:
			memset(&paragraphProperties, 0, sizeof(paragraphProperties));
			return rkOK;
		case ipropPlain:
			memset(&characterProperties, 0, sizeof(characterProperties));
			return rkOK;
		case ipropSectd:
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
	NSLog(@"keyword: %@", [NSString stringWithCString:szKeyword]);
    int isym;
	
    // search for szKeyword in keywordDescription
	
    for (isym = 0; isym < isymMax; isym++)
        if (strcmp(szKeyword, keywordDescription[isym].szKeyword) == 0)
            break;
    if (isym == isymMax)            // control word not found
    {
        if (fSkipDestIfUnk)         // if this is a new destination
            destinationState = rdsSkip;          // skip the destination
		// else just discard it
        fSkipDestIfUnk = fFalse;
        return rkOK;
    }
	
    // Found it!  use kwd and idx to determine what to do with it.
	
    fSkipDestIfUnk = fFalse;
    switch (keywordDescription[isym].kwd)
    {
		case kwdProp:
			if (keywordDescription[isym].fPassDflt || !fParam)
				param = keywordDescription[isym].dflt;
			return [self applyPropertyChange:(rkProperties)keywordDescription[isym].idx val:param];
		case kwdChar:
			return [self parseCharacter:keywordDescription[isym].idx];
		case kwdDest:
			return [self changeOutputDestination:(rkDestinationType)keywordDescription[isym].idx];
		case kwdSpec:
			return [self parseSpecialKeyword:(rkImageTypes)keywordDescription[isym].idx];
		default:
			return rkBadTable;
    }
    return rkBadTable;
}

/**
 * Change to the destination specified by idest.
 * There's usually more to do here than this...
 */
- (int) changeOutputDestination:(rkDestinationType)idest
{
    if (destinationState == rdsSkip)             // if we're skipping text,
        return rkOK;                // don't do anything
	
    switch (idest)
    {
		default:
			destinationState = rdsSkip;              // when in doubt, skip it...
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
- (int) parseSpecialKeyword:(rkImageTypes)ipfn
{
    if (destinationState == rdsSkip && ipfn != ipfnBin)  // if we're skipping, and it's not
        return rkOK;                        // the \bin keyword, ignore it.
    switch (ipfn)
    {
		case ipfnBin:
			internalState = internalStateBin;
			cbBin = lParam;
			break;
		case ipfnSkipDest:
			fSkipDestIfUnk = fTrue;
			break;
		case ipfnHex:
			internalState = internalStateHex;
			break;
		default:
			return rkBadTable;
    }
    return rkOK;
}


/**
 * Get a buffered character
 */
- (int) getCharacterFromBuffer;
{
    unsigned char ch = 0x00;
    
    if (putBufferLength > 0)
        return (int)putBuffer[--putBufferLength];
    
    if (bufferPosition >= [sourceRTFData length])
        return EOF;
	
    NSRange range = {bufferPosition, 1};
    [sourceRTFData getBytes:&ch range:range];
    
    bufferPosition++;
    
    return (int)ch;
    
} 


/**
 * Get an unbufferend character
 */
- (int)putCharacter:(int)ch
{
    if (putBufferLength >= sizeof(putBuffer)/sizeof(*putBuffer))
        return EOF;
    
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
        if (cGroup < 0)
            return rkStackUnderflow;
        if (internalState == internalStateBin)                      // if we're parsing binary data, handle it directly
        {
            if ((ec = [self parseCharacter:ch]) != rkOK)
                return ec;
        }
        else
        {
            switch (ch)
            {
				case '{':
					NSLog(@"Start { %d", destinationLength);
					if ((ec = [self pushState]) != rkOK)
						return ec;
					break;
				case '}':
					NSLog(@"End } %d", destinationLength);
					if ((ec = [self popState]) != rkOK)
						return ec;
					break;
				case '\\':
					NSLog(@"Parse control words %d", destinationLength);
					// Parse control words
					if ((ec = [self parseNextKeyword]) != rkOK)
						return ec;
					break;
				case 0x0d:
					break;
				case 0x0a:          // cr and lf are noise characters...
					//storeCharacter('\n', fp, false);
					break;
				default:
					
					// parse out the characters
					if (internalState == internalStateNorm)
					{
						if (psave) {
							NSLog(@"stopping");
						}
						NSLog(@"Parse normal character %d", destinationLength);
						if ((ec = [self parseCharacter:ch]) != rkOK)
							return ec;
					}
					else
					{               // parsing hex data
						if (internalState != internalStateHex)
							return rkAssertion;
						b = b << 4;
						if (isdigit(ch))
							b += (char) ch - '0';
						else
						{
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
						if (!cNibble)
						{
							if ((ec = [self parseCharacter:b]) != rkOK)
								return ec;
							cNibble = 2;
							b = 0;
							internalState = internalStateNorm;
						}
					}   // end else (internalState != internalStateNorm)
					
					break;
            }       // switch
        }           // else (internalState != internalStateBin)
    }               // while
    
    [self storeCharacter:'\n' flush:true];
    
    if (cGroup < 0)
        return rkStackUnderflow;
    if (cGroup > 0)
        return rkUnmatchedBrace;
    return rkOK;
}

/**
 * Save relevant info on a linked list of rkSavePropertyState structures.
 */
- (int) pushState
{
    rkSavePropertyState *psaveNew = (rkSavePropertyState *)malloc(sizeof(rkSavePropertyState));
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
    internalState = internalStateNorm;
    psave = psaveNew;
    cGroup++;
    
	return rkOK;
}

/**
 * If we're ending a destination (that is, the destination is changing),
 * call endGroupAction.
 * Always restore relevant info from the top of the rkSavePropertyState list.
 */
- (int) popState
{
    rkSavePropertyState *psaveOld;
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
    if (ch != ' ')
        [self putCharacter:ch];
    return [self translateKeyword:szKeyword withParam:param fParam:fParam];
}

/**
 * Route the character to the appropriate destination stream.
 */
- (int) parseCharacter:(int)ch;
{
    if (internalState == internalStateBin && --cbBin <= 0) {
        internalState = internalStateNorm;
	}
	
    switch (destinationState) {
		case rdsSkip:
			// Skip this character.
			return rkOK;
			
		case rdsNorm:
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
    characters[destinationLength++] = ch;
    if (flush || destinationLength >= sizeof(characters)/sizeof(*characters))
    {
        // [destinationString appendFormat:@"%.*S", destinationLength, characters];
		[destinationString appendBytes:&characters[0] length:destinationLength];
		//NSAttributedString *chr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%.*S", destinationLength, c]];
        //[destinationString appendAttributedString:chr];
		//[chr release];
		
		destinationLength = 0;
    }
	
    return rkOK;
}

@end


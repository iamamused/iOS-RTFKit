/**
 * Based on http://latex2rtf.sourceforge.net/rtfspec_45.html
 *
 * Step 1:
 * Isolate RTF keywords and send them to parseKeyword;
 * Push and pop state at the start and end of RTF groups;
 * Send text to parseCharacter for further processing.
 *
 * Step 2:
 * get a control word (and its associated value) and
 * call translateKeyword to dispatch the control.
 *
 * Step 3.
 * Search rgsymRtf for szKeyword and evaluate it appropriately.
 */

#import <UIKit/UIKit.h>
#import "RTFReader.h"

@interface RTFReader (Private) 
- (int) parse:(RTFDOC *)fp;
- (int) pushState;
- (int) popState;
- (int) parseKeyword:(RTFDOC *)fp;
- (int) parseCharacter:(int)ch doc:(RTFDOC *)fp;
- (int) translateKeyword:(char *)szKeyword  param:(int)param fParam:(bool)fParam  doc:(RTFDOC *)fp;
- (int) storeCharacter:(int)ch doc:(RTFDOC *)fp flush:(bool)flush;
- (int) endGroupAction:(rkDestinationState)rds;
- (int) applyPropertyChange:(rkProperties)iprop val:(int)val;
- (int) changeOutputDestination:(rkDestinationType)idest;
- (int) parseSpecialKeyword:(rkImageTypes)ipfn;
- (int) parseSpecialProperty:(rkProperties)iprop val:(int) val;

- (int) putCharacter:(int)ch inBuffer:(RTFDOC *)rtfdoc;
- (int) getCharacterFromBuffer:(RTFDOC *)rtfdoc;

@end


@implementation RTFReader

// RTF parser tables

// Property descriptions
static rkProperty rgprop[ipropMax] = {
    {actnByte,   propChp,    offsetof(rkCharacterProperities, fBold)},       // ipropBold
    {actnByte,   propChp,    offsetof(rkCharacterProperities, fItalic)},     // ipropItalic
    {actnByte,   propChp,    offsetof(rkCharacterProperities, fUnderline)},  // ipropUnderline
    {actnWord,   propPap,    offsetof(rkParagraphProperities, xaLeft)},      // ipropLeftInd
    {actnWord,   propPap,    offsetof(rkParagraphProperities, xaRight)},     // ipropRightInd
    {actnWord,   propPap,    offsetof(rkParagraphProperities, xaFirst)},     // ipropFirstInd
    {actnWord,   propSep,    offsetof(rkSectionProperities, cCols)},       // ipropCols
    {actnWord,   propSep,    offsetof(rkSectionProperities, xaPgn)},       // ipropPgnX
    {actnWord,   propSep,    offsetof(rkSectionProperities, yaPgn)},       // ipropPgnY
    {actnWord,   propDop,    offsetof(rkDocumentProperities, xaPage)},      // ipropXaPage
    {actnWord,   propDop,    offsetof(rkDocumentProperities, yaPage)},      // ipropYaPage
    {actnWord,   propDop,    offsetof(rkDocumentProperities, xaLeft)},      // ipropXaLeft
    {actnWord,   propDop,    offsetof(rkDocumentProperities, xaRight)},     // ipropXaRight
    {actnWord,   propDop,    offsetof(rkDocumentProperities, yaTop)},       // ipropYaTop
    {actnWord,   propDop,    offsetof(rkDocumentProperities, yaBottom)},    // ipropYaBottom
    {actnWord,   propDop,    offsetof(rkDocumentProperities, pgnStart)},    // ipropPgnStart
    {actnByte,   propSep,    offsetof(rkSectionProperities, sbk)},         // ipropSbk
    {actnByte,   propSep,    offsetof(rkSectionProperities, pgnFormat)},   // ipropPgnFormat
    {actnByte,   propDop,    offsetof(rkDocumentProperities, fFacingp)},    // ipropFacingp
    {actnByte,   propDop,    offsetof(rkDocumentProperities, fLandscape)},  // ipropLandscape
    {actnByte,   propPap,    offsetof(rkParagraphProperities, just)},        // ipropJust
    {actnSpec,   propPap,    0},                          // ipropPard
    {actnSpec,   propChp,    0},                          // ipropPlain
    {actnSpec,   propSep,    0},                          // ipropSectd
};

// Keyword descriptions
static rkSymbol rgsymRtf[] = {
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
int isymMax = sizeof(rgsymRtf) / sizeof(rkSymbol);


/**
 * Initialize the object with a path to the RTF document.
 */
- (id)initWithFilePath:(NSString *)filePath;
{
	
	NSMutableString * newText = nil;
	
    RTFDOC rtfdoc = {0};
	
    rtfdoc.src  = [[NSData dataWithContentsOfMappedFile:filePath] retain];
    rtfdoc.dest = [[NSMutableData alloc] initWithCapacity:4096];
	
    if (rtfdoc.src && rtfdoc.dest)
    {
		if ([self parse:&rtfdoc] == rkOK) {
			newText = [[[NSMutableString alloc] initWithData:rtfdoc.dest encoding:NSUTF8StringEncoding] retain];
		}
    }
	
    if (rtfdoc.src)
        [rtfdoc.src release];
	
    if (rtfdoc.dest)
        [rtfdoc.dest release];
	
	
	NSLog(@"%@", newText);
	
	
	NSString *myText = [NSString stringWithContentsOfFile:filePath];  
	NSLog(@"%@", myText);
	
	return self;
	
}


/**
 * Set the property identified by iprop to the value val.
 */
- (int) applyPropertyChange:(rkProperties)iprop val:(int)val;
{
    char *pb;
	
    if (rds == rdsSkip)                 // If we're skipping text,
        return rkOK;                    // don't do anything.
	
    switch (rgprop[iprop].prop)
    {
		case propDop:
			pb = (char *)&dop;
			break;
		case propSep:
			pb = (char *)&sep;
			break;
		case propPap:
			pb = (char *)&pap;
			break;
		case propChp:
			pb = (char *)&chp;
			break;
		default:
			if (rgprop[iprop].actn != actnSpec)
				return rkBadTable;
			break;
    }
    switch (rgprop[iprop].actn)
    {
		case actnByte:
			pb[rgprop[iprop].offset] = (unsigned char) val;
			break;
		case actnWord:
			(*(int *) (pb+rgprop[iprop].offset)) = val;
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
			memset(&pap, 0, sizeof(pap));
			return rkOK;
		case ipropPlain:
			memset(&chp, 0, sizeof(chp));
			return rkOK;
		case ipropSectd:
			memset(&sep, 0, sizeof(sep));
			return rkOK;
		default:
			return rkBadTable;
    }
    return rkBadTable;
}

/**
 * Search rgsymRtf for szKeyword and evaluate it appropriately.
 *
 * Inputs:
 * szKeyword:   The RTF control to evaluate.
 * param:       The parameter of the RTF control.
 * fParam:      fTrue if the control had a parameter; (that is, if param is valid)
 *              fFalse if it did not.
 */
- (int) translateKeyword:(char *)szKeyword  param:(int)param fParam:(bool)fParam  doc:(RTFDOC *)fp;
{
	NSLog(@"keyword: %@", [NSString stringWithCString:szKeyword]);
    int isym;
	
    // search for szKeyword in rgsymRtf
	
    for (isym = 0; isym < isymMax; isym++)
        if (strcmp(szKeyword, rgsymRtf[isym].szKeyword) == 0)
            break;
    if (isym == isymMax)            // control word not found
    {
        if (fSkipDestIfUnk)         // if this is a new destination
            rds = rdsSkip;          // skip the destination
		// else just discard it
        fSkipDestIfUnk = fFalse;
        return rkOK;
    }
	
    // Found it!  use kwd and idx to determine what to do with it.
	
    fSkipDestIfUnk = fFalse;
    switch (rgsymRtf[isym].kwd)
    {
		case kwdProp:
			if (rgsymRtf[isym].fPassDflt || !fParam)
				param = rgsymRtf[isym].dflt;
			return [self applyPropertyChange:(rkProperties)rgsymRtf[isym].idx val:param];
		case kwdChar:
			return [self parseCharacter:rgsymRtf[isym].idx doc:fp];
		case kwdDest:
			return [self changeOutputDestination:(rkDestinationType)rgsymRtf[isym].idx];
		case kwdSpec:
			return [self parseSpecialKeyword:(rkImageTypes)rgsymRtf[isym].idx];
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
    if (rds == rdsSkip)             // if we're skipping text,
        return rkOK;                // don't do anything
	
    switch (idest)
    {
		default:
			rds = rdsSkip;              // when in doubt, skip it...
			break;
    }
    return rkOK;
}

/**
 * The destination specified by rds is coming to a close.
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
    if (rds == rdsSkip && ipfn != ipfnBin)  // if we're skipping, and it's not
        return rkOK;                        // the \bin keyword, ignore it.
    switch (ipfn)
    {
		case ipfnBin:
			ris = risBin;
			cbBin = lParam;
			break;
		case ipfnSkipDest:
			fSkipDestIfUnk = fTrue;
			break;
		case ipfnHex:
			ris = risHex;
			break;
		default:
			return rkBadTable;
    }
    return rkOK;
}


/**
 * Get a buffered character
 */
- (int) getCharacterFromBuffer:(RTFDOC *)rtfdoc
{
    unsigned char ch = 0x00;
    
    if (rtfdoc->ungetbufL > 0)
        return (int)rtfdoc->ungetbuf[--rtfdoc->ungetbufL];
    
    if (rtfdoc->pos >= [rtfdoc->src length])
        return EOF;
	
    NSRange range = {rtfdoc->pos, 1};
    [rtfdoc->src getBytes:&ch range:range];
    
    rtfdoc->pos++;
    
    return (int)ch;
    
} 


/**
 * Get an unbufferend character
 */
- (int)putCharacter:(int)ch inBuffer:(RTFDOC *)rtfdoc
{
    if (rtfdoc->ungetbufL >= sizeof(rtfdoc->ungetbuf)/sizeof(*rtfdoc->ungetbuf))
        return EOF;
    
    rtfdoc->ungetbuf[rtfdoc->ungetbufL++] = (unsigned char)ch;
    
    return ch;
} 


/**
 * Stat parsing
 */
- (int) parse:(RTFDOC *)fp;
{
    int ch;
    int ec;
    int cNibble = 2;
    int b = 0;
	
    while ((ch = [self getCharacterFromBuffer:fp]) != EOF)
    {
        if (cGroup < 0)
            return rkStackUnderflow;
        if (ris == risBin)                      // if we're parsing binary data, handle it directly
        {
            if ((ec = [self parseCharacter:ch doc:fp]) != rkOK)
                return ec;
        }
        else
        {
            switch (ch)
            {
				case '{':
					NSLog(@"Start { %d", fp->cL);
					if ((ec = [self pushState]) != rkOK)
						return ec;
					break;
				case '}':
					NSLog(@"End } %d", fp->cL);
					if ((ec = [self popState]) != rkOK)
						return ec;
					break;
				case '\\':
					NSLog(@"Parse control words %d", fp->cL);
					// Parse control words
					if ((ec = [self parseKeyword:fp]) != rkOK)
						return ec;
					break;
				case 0x0d:
					break;
				case 0x0a:          // cr and lf are noise characters...
					//storeCharacter('\n', fp, false);
					break;
				default:
					
					// parse out the characters
					if (ris == risNorm)
					{
						if (psave) {
							NSLog(@"stopping");
						}
						NSLog(@"Parse normal character %d", fp->cL);
						if ((ec = [self parseCharacter:ch doc:fp]) != rkOK)
							return ec;
					}
					else
					{               // parsing hex data
						if (ris != risHex)
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
							if ((ec = [self parseCharacter:b doc:fp]) != rkOK)
								return ec;
							cNibble = 2;
							b = 0;
							ris = risNorm;
						}
					}   // end else (ris != risNorm)
					
					break;
            }       // switch
        }           // else (ris != risBin)
    }               // while
    
    [self storeCharacter:'\n' doc:fp flush:true];
    
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
    psaveNew -> chp = chp;
    psaveNew -> pap = pap;
    psaveNew -> sep = sep;
    psaveNew -> dop = dop;
    psaveNew -> rds = rds;
    psaveNew -> ris = ris;
    ris = risNorm;
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
	
    if (rds != psave->rds)
    {
        if ((ec = [self endGroupAction:rds]) != rkOK)
            return ec;
    }
    chp = psave->chp;
    pap = psave->pap;
    sep = psave->sep;
    dop = psave->dop;
    rds = psave->rds;
    ris = psave->ris;
	
    psaveOld = psave;
    psave = psave->pNext;
    cGroup--;
    free(psaveOld);
    return rkOK;
}


/**
 * Parse out keywords
 */
- (int) parseKeyword:(RTFDOC *)fp
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
    if ((ch = [self getCharacterFromBuffer:fp]) == EOF)
        return rkEndOfFile;
    if (!isalpha(ch))           // a control symbol; no delimiter.
    {
        szKeyword[0] = (char) ch;
        szKeyword[1] = '\0';
		
        return [self translateKeyword:szKeyword param:0 fParam:fParam doc:fp];
    }
    for (pch = szKeyword; isalpha(ch); ch = [self getCharacterFromBuffer:fp])
        *pch++ = (char) ch;
    *pch = '\0';
    if (ch == '-')
    {
        fNeg  = fTrue;
        // if ((ch = getc(fp)) == EOF)
        if ((ch = [self getCharacterFromBuffer:fp]) == EOF)
            return rkEndOfFile;
    }
    if (isdigit(ch))
    {
        fParam = fTrue; // a digit after the control means we have a parameter
        for (pch = szParameter; isdigit(ch); ch = [self getCharacterFromBuffer:fp])
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
        [self putCharacter:ch inBuffer:fp];
    return [self translateKeyword:szKeyword param:param fParam:fParam doc:fp];
}

/**
 * Route the character to the appropriate destination stream.
 */
- (int) parseCharacter:(int)ch doc:(RTFDOC *)fp;
{
    if (ris == risBin && --cbBin <= 0) {
        ris = risNorm;
	}
	
    switch (rds) {
		case rdsSkip:
			// Skip this character.
			return rkOK;
			
		case rdsNorm:
			// Output a character. Properties are valid at this point.
			return [self storeCharacter:ch doc:fp flush:false];   
			
		default:
			// handle other destinations....
			return rkOK;
    }
}


/**
 * Send a character to the output file.
 */
- (int) storeCharacter:(int)ch doc:(RTFDOC *)fp flush:(bool)flush;
{   
    fp->c[fp->cL++] = ch;
    if (flush || fp->cL >= sizeof(fp->c)/sizeof(*fp->c))
    {
        // [fp->dest appendFormat:@"%.*S", fp->cL, fp->c];
		[fp->dest appendBytes:&fp->c[0] length:fp->cL];
		//NSAttributedString *chr = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%.*S", fp->cL, fp->c]];
        //[fp->dest appendAttributedString:chr];
		//[chr release];
		
		fp->cL = 0;
    }
	
    return rkOK;
}

@end


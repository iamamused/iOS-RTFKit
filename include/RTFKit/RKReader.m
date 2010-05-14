//
//  RKReader.m
//  RTFKit
//
//  Created by Jeffrey Sambells on 10-05-10.
//  Copyright TropicalPixels. 2010. All rights reserved.
//  Please see the included LICENSE for applicable licensing information.
//
//  Based on http://latex2rtf.sourceforge.net/rtfspec_45.html
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#import "RKReader.h"

@interface RKReader (Private)
- (int)parse;
- (int)pushState;
- (int)opState;
- (int)parseNextKeyword;
- (int)parseCharacter:(int)ch;
- (int)translateKeyword: (char *)szKeyword withParam:(int)param fParam:( bool )fParam;
- (int)storeCharacter:(int)ch;
- (int)endGroupAction:( rkDestinationState )rds;
- (int)applyPropertyChange:(rkProperty) rkProp val:(int)val;
- (int)changeOutputDestination:( rkDestinationType )idest;
- (int)parseSpecialKeyword:( rkSpecialType )ipfn;
- (int)putCharacter:(int)ch;
- (int)getCharacterFromBuffer;

- (int)pushFontRun;
- (int)pushParagraphRun;

@end

@implementation RKReader

// RTF parser tables
// Property descriptions


// Keyword descriptions
static RTFSymbol keywordDescription[] = {
	//  keyword       dflt               fPassDflt   kwd                       idx
	{"f",             0,                 fTrue,      rkKeywordTypeProperty,    rkPropFontIndex},
	{"fs",            10.0f,             fTrue,      rkKeywordTypeProperty,    rkPropFontSize},
	{"b",             1,                 fFalse,     rkKeywordTypeProperty,    rkPropBold},
	{"i",             1,                 fFalse,     rkKeywordTypeProperty,    rkPropItalic},
	{"li",            0,                 fFalse,     rkKeywordTypeProperty,    rkPropLeftInd},
	{"ri",            0,                 fFalse,     rkKeywordTypeProperty,    rkPropRightInd},
	{"fi",            0,                 fFalse,     rkKeywordTypeProperty,    rkPropFirstInd},
	{"qc",            rkParaJustCenter,  fTrue,      rkKeywordTypeProperty,    rkPropJust},
	{"ql",            rkParaJustLeft,    fTrue,      rkKeywordTypeProperty,    rkPropJust},
	{"qr",            rkParaJustRight,   fTrue,      rkKeywordTypeProperty,    rkPropJust},
	{"qj",            rkParaJustForced,  fTrue,      rkKeywordTypeProperty,    rkPropJust},
	{"par",           0,                 fFalse,     rkKeywordTypeCharacter,   0x0a},

	{"\0x0a",         0,      fFalse,     rkKeywordTypeCharacter,    0x0a},
	{"\0x0d",         0,      fFalse,     rkKeywordTypeCharacter,    0x0a},

	{"emspace",       0,      fFalse,     rkKeywordTypeCharacter,    ' '},
	{"enspace",       0,      fFalse,     rkKeywordTypeCharacter,    ' '},
	{"~",             0,      fFalse,     rkKeywordTypeCharacter,    ' '},
	{"lquote",        0,      fFalse,     rkKeywordTypeCharacter,    '\''},
	{"rquote",        0,      fFalse,     rkKeywordTypeCharacter,    '\''},
	{"-",             0,      fFalse,     rkKeywordTypeCharacter,    '-'},
	{"_",             0,      fFalse,     rkKeywordTypeCharacter,    '-'},
	{"emdash",        0,      fFalse,     rkKeywordTypeCharacter,    '-'},
	{"endash",        0,      fFalse,     rkKeywordTypeCharacter,    '-'},
	{"line",          0,      fFalse,     rkKeywordTypeCharacter,    0x0a},
	{"page",          0,      fFalse,     rkKeywordTypeCharacter,    0x0a},
	{"pagebb",        0,      fFalse,     rkKeywordTypeCharacter,    0x0a},
	{"outlinelevel",  0,      fFalse,     rkKeywordTypeCharacter,    0x0a},
	
	{"tab",           0,      fFalse,     rkKeywordTypeCharacter,    0x09},
	{"ldblquote",     0,      fFalse,     rkKeywordTypeCharacter,    '"'},
	{"rdblquote",     0,      fFalse,     rkKeywordTypeCharacter,    '"'},
	{"bin",           0,      fFalse,     rkKeywordTypeSpecial,        rkSpecialTypeBin},
	{"*",             0,      fFalse,     rkKeywordTypeSpecial,        rkSpecialTypeSkip},
	{"'",             0,      fFalse,     rkKeywordTypeSpecial,        rkSpecialTypeHex},
    {"author",        0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"buptim",        0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"colortbl",      0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"comment",       0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"creatim",  0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"doccomm",  0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"fonttbl",  0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"footer",   0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"footerf",  0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"footerl",  0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"footerr",  0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"footnote", 0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"ftncn",    0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"ftnsep",   0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"ftnsepc",  0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"header",   0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"headerf",  0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"headerl",  0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"headerr",  0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"info",     0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"keywords", 0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"operator", 0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"pict",     0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"printim",  0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"private1", 0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"revtim",   0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"rxe",      0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"stylesheet",   0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"subject",  0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
	{"tc",       0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"title",    0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"txe",      0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
    {"xe",       0,      fFalse,     rkKeywordTypeDestination,    rkSpecialTypeSkip},
	{"{",        0,      fFalse,     rkKeywordTypeCharacter,      '{'},
	{"}",        0,      fFalse,     rkKeywordTypeCharacter,      '}'},
	{"\\",       0,      fFalse,     rkKeywordTypeCharacter,      '\\'}
};

int numKeywords = sizeof(keywordDescription) / sizeof(RTFSymbol);

#pragma mark -
#pragma mark Initialization

/**
 * Initialize the object with a path to the RTF document.
 */
-( id )initWithFilePath:( NSString * )filePath;
{
		
	sourceRTFData  = [[NSData dataWithContentsOfMappedFile:filePath] retain];
	destinationString = [[NSMutableAttributedString alloc] initWithString:@""];

	fontRuns = [[NSMutableArray arrayWithObject:[[[RKFont alloc] init] autorelease]] retain];
	paragraphRuns = [[NSMutableArray arrayWithObject:[[[RKParagraph alloc] init] autorelease]] retain];
	
	if ([self parse] == rkOK ) {
		NSLog(@"Result: %@", destinationString);
	}
	
	NSError *error;
	NSString *myText = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
	
	NSLog(@"%@", myText);
	
	return self;
}



#pragma mark -
#pragma mark Memory Management

-( void )dealloc;
{
	[sourceRTFData release];
	[destinationString release];
	[super dealloc];
}


#pragma mark -
#pragma mark RTF Property Management

/**
 * Set the property identified by prop to the value val.
 */
-(int)applyPropertyChange:(rkProperty)prop val:(int)val;
{
	RKRange *range;
	int ec;
	
	if ( destinationState == rkDestinationStateSkip ) {
		// If we're skipping text don't do anything.
		return rkOK;
	}
	
	// Process Property
	switch ( prop ) {
		case rkPropFontIndex:
			if ( (ec = [self pushFontRun]) != rkOK ) { return ec; }
			[(RKFont *)[fontRuns lastObject] setFontIndex:(int)val];
			break;
		case rkPropFontSize:
			if ( (ec = [self pushFontRun]) != rkOK ) { return ec; }
			[(RKFont *)[fontRuns lastObject] setFontSize:(int)val];
			break;
		case rkPropBold:
			if ( (ec = [self pushFontRun]) != rkOK ) { return ec; }
			[(RKFont *)[fontRuns lastObject] setIsBold:(int)val];
			break;
		case rkPropItalic: 
			if ( (ec = [self pushFontRun]) != rkOK ) { return ec; }
			[(RKFont *)[fontRuns lastObject] setIsItalic:(int)val];
			break;
		case rkPropLeftInd:
			if ( (ec = [self pushParagraphRun]) != rkOK ) { return ec; }
			[(RKParagraph *)[paragraphRuns lastObject] setIndentLeft:(int)val];
			break;
		case rkPropRightInd:
			if ( (ec = [self pushParagraphRun]) != rkOK ) { return ec; }
			[(RKParagraph *)[paragraphRuns lastObject] setIndentRight:(int)val];
			break;
		case rkPropFirstInd: 
			if ( (ec = [self pushParagraphRun]) != rkOK ) { return ec; }
			[(RKParagraph *)[paragraphRuns lastObject] setIndentFirst:(int)val];
			break;
		case rkPropJust:
			if ( (ec = [self pushParagraphRun]) != rkOK ) { return ec; }
			[(RKParagraph *)[paragraphRuns lastObject] setJust:(int)val];
			break;
		case rkPropPard:
		case rkPropPlain:
			// @TODO reset the styles to default.
			break;
		default:
			return rkBadTable;
			break;
	} /* switch */
	
	/*
	// Apply the appropriate action based on the description
	switch ( propertyDescription[prop].actn ) {
		case rkValueTypeByte: {
			//(unsigned char)val
			SEL selector = propertyDescription[prop].selector;
			NSString *data = [NSString stringWithFormat:@"%s",(int *)val];
			[range performSelector:selector withObject:data];
		} break;
			
		case rkValueTypeWord:{
			//( *(int *)(pb + propertyDescription[prop].offset) ) = val;
			SEL selector = propertyDescription[prop].selector;
			NSData *data = [NSData dataWithBytes:(int *)val length:1];
			[range performSelector:selector withObject:data];
		}
			break;
			
	}
	*/
	
	return rkOK;
}



#pragma mark -
#pragma mark Keyword Management


/**
 * Search keywordDescription for szKeyword and evaluate it appropriately.
 *
 * Inputs:
 * szKeyword:   The RTF control to evaluate.
 * param:       The parameter of the RTF control.
 * fParam:      fTrue if the control had a parameter; (that is, if param is valid)
 *              fFalse if it did not.
 */
-(int)translateKeyword:(char *)keyword withParam:(int)param fParam:(bool)fParam;
{
	NSLog(@"Processing: %@", [NSString stringWithUTF8String: keyword]);
	int isym;
	
	// search for keyword in keywordDescription
	for ( isym = 0 ; isym < numKeywords ; isym++ ) {
		if ( strcmp(keyword, keywordDescription[isym].szKeyword) == 0 ) {
			// The keyword is in the description list.
			break;
		}
	}
	
	if ( isym == numKeywords ) {
		NSLog(@"Ignore: %@", [NSString stringWithUTF8String:keyword]);
		// control word not found
		if ( fSkipDestIfUnk ) {
			// if this is a new destination skip the destination
			destinationState = rkDestinationStateSkip;
		}
		// just discard it
		fSkipDestIfUnk = fFalse;
		return rkOK;
	}
	
	NSLog(@"Found: %@", [NSString stringWithUTF8String:keyword]);
	
	// Found it! use kwd and idx to determine what to do with it.
	fSkipDestIfUnk = fFalse;
	
	switch ( keywordDescription[isym].kwd ) {
		case rkKeywordTypeProperty:
			if ( keywordDescription[isym].fPassDflt || !fParam ) {
				param = keywordDescription[isym].dflt;
			}
			return [self applyPropertyChange:(rkProperty)keywordDescription[isym].idx val:param];
			
		case rkKeywordTypeCharacter:
			return [self parseCharacter:keywordDescription[isym].idx];
			
		case rkKeywordTypeDestination:
			return [self changeOutputDestination:(rkDestinationType)keywordDescription[isym].idx];
			
		case rkKeywordTypeSpecial:
			return [self parseSpecialKeyword:(rkSpecialType)keywordDescription[isym].idx];
			
		default:
			return rkBadTable;
	} /* switch */
	
	return rkBadTable;
}


/**
 * Evaluate an RTF control that needs special processing.
 */
-(int) parseSpecialKeyword:( rkSpecialType )type
{
	if ( destinationState == rkDestinationStateSkip && type != rkSpecialTypeBin ) {
		// if we're skipping, and it's not the \bin keyword, ignore it.
		return rkOK;
	}
	switch ( type ) {
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
	} /* switch */
	return rkOK;
}


#pragma mark -
#pragma mark IO Management

/**
 * Change to the destination specified by idest.
 * There's usually more to do here than this...
 */
-(int) changeOutputDestination:( rkDestinationType )dt
{
	if ( destinationState == rkDestinationStateSkip ) {
		// if we're skipping text don't do anything.
		return rkOK;
	}
	// TODO: handle other types.
	switch ( dt ) {
		default:
			// when in doubt, skip it...
			destinationState = rkDestinationStateSkip;
			break;
	} /* switch */
	return rkOK;
}


/**
 * The destination specified by destinationState is coming to a close.
 * If there's any cleanup that needs to be done, do it now.
 */
-(int) endGroupAction:( rkDestinationState )rds
{
	return rkOK;
}


/**
 * Get a character
 */
-(int) getCharacterFromBuffer;
{
	unsigned char ch = 0x00;
	if ( putBufferLength > 0 ) {
		return (int)putBuffer[--putBufferLength];
	}
	if ( bufferPosition >= [sourceRTFData length] ) {
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
-(int)putCharacter:(int)ch
{
	if ( putBufferLength >= sizeof(putBuffer) / sizeof(*putBuffer) ) {
		return EOF;
	}
	putBuffer[putBufferLength++] = (unsigned char)ch;
	return ch;
}


#pragma mark -
#pragma mark Run Storage

-(void)incrementRunRanges;
{
	[(RKRange *)[fontRuns lastObject] setEnd:[(RKRange *)[fontRuns lastObject] end] + 1];
	[(RKRange *)[paragraphRuns lastObject] setEnd:[(RKRange *)[paragraphRuns lastObject] end] + 1];
}

-(void)setRunRangeEnd:(int)end;
{
	[(RKRange *)[fontRuns lastObject] setEnd:end];
	[(RKRange *)[paragraphRuns lastObject] setEnd:end];
}

/**
 * Save relevant info on a linked list of RTFSaveState structures.
 */
-(int)pushFontRun;
{
	// Only push a new run if new characters have been added.
	RKRange *last = [fontRuns lastObject];
	if (destinationLength > [last end]) {
		[last setEnd:destinationLength];
		RKFont *new = [[fontRuns lastObject] copy];
		[new setStart:destinationLength];
		[new setEnd:destinationLength];
		[fontRuns addObject:new];
	}
	return rkOK;
}

-(int)pushParagraphRun;
{
	// Only push a new run if new characters have been added.
	RKRange *last = [paragraphRuns lastObject];
	if (destinationLength > [last end]) {
		[last setEnd:destinationLength];
		RKParagraph *new = [[paragraphRuns lastObject] copy];
		[new setStart:destinationLength];
		[new setEnd:destinationLength];
		[paragraphRuns addObject:new];
	} 
	return rkOK;
}

#pragma mark -
#pragma mark State Management

/**
 * Save relevant info for the current state. This will be re-populated 
 * When the group ends..
 */
-(int) pushState
{
	RTFSaveState *psaveNew = (RTFSaveState *)malloc( sizeof(RTFSaveState) );
	if ( !psaveNew ) {
		return rkStackOverflow;
	}
	psaveNew->pNext = psave;
	psaveNew->destinationState = destinationState;
	psaveNew->internalState = internalState;
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
-(int) popState
{
	RTFSaveState *psaveOld;
	
	int ec;
	
	if ( !psave ) {
		return rkStackUnderflow;
	}
	
	if ( destinationState != psave->destinationState ) {
		if ( (ec = [self endGroupAction:destinationState]) != rkOK ) {
			return ec;
		}
	}
	
	destinationState = psave->destinationState;
	internalState = psave->internalState;
	
	psaveOld = psave;
	psave = psave->pNext;
	cGroup--;
	free(psaveOld);
	
	return rkOK;
}


#pragma mark -
#pragma mark Parseing


/**
 * Stat parsing
 */
-(int) parse;
{
	int ch;
	int ec;
	int cNibble = 2;
	int b = 0;
	while ( (ch = [self getCharacterFromBuffer]) != EOF ) {
		
		// Check if we're in a group (the first char should have been be {)
		if ( cGroup < 0 ) {
			return rkStackUnderflow;
		}
		
		// Check if we're in BIN mode
		if ( internalState == rkInternalStateBin ) {
			// If we're parsing binary data, handle it directly.
			if ( (ec = [self parseCharacter:ch]) != rkOK ) {
				return ec;
			}
		} else {
			// Switch on the ch
			switch ( ch ) {
				case '{':
					// We're beginning a group.
					if ( (ec = [self pushState]) != rkOK ) {
						return ec;
					}
					break;
					
				case '}':
					// We're ending a group.
					if ( (ec = [self popState]) != rkOK ) {
						return ec;
					}
					break;
					
				case '\\':
					// We're at the start of a control word.
					if ( (ec = [self parseNextKeyword]) != rkOK ) {
						return ec;
					}
					break;
					
				case 0x0d:
					break;
					
				case 0x0a:
					// cr and lf are noise characters...
					//storeCharacter('\n', fp, false);
					break;
					
				default:
					if ( internalState == rkInternalStateNorm ) {
						// We're in the middle of soem text so parse it out.
						if ( (ec = [self parseCharacter:ch]) != rkOK ) {
							return ec;
						}
					} else {
						// We're parsing hex data.
						if ( internalState != rkInternalStateHex ) {
							return rkAssertion;
						}
						b = b << 4;
						if ( isdigit(ch) ) {
							b += (char) ch - '0';
						} else {
							if ( islower(ch) ) {
								if ( ch < 'a' || ch > 'f' ) {
									return rkInvalidHex;
								}
								b += 0x0a + (char) ch - 'a';
							} else  {
								if ( ch < 'A' || ch > 'F' ) {
									return rkInvalidHex;
								}
								b += 0x0A + (char) ch - 'A';
							}
						}
						cNibble--;
						if ( !cNibble ) {
							if ( (ec = [self parseCharacter:b]) != rkOK ) {
								return ec;
							}
							cNibble = 2;
							b = 0;
							internalState = rkInternalStateNorm;
						}
					}
					break;
			} /* switch */
		}
	}
		
	if ( cGroup < 0 ) {
		return rkStackUnderflow;
	}
	if ( cGroup > 0 ) {
		return rkUnmatchedBrace;
	}
	
	[self applyRuns];

	return rkOK;
}


/**
 * Parse out keywords
 */
-(int) parseNextKeyword
{
	// The parser found a \ character so the keyword parser has been invoked.
	// Look at the rest of the string for the keyword
	int ch;
	bool fParam = fFalse;
	bool fNeg = fFalse;
	int param = 0;
	char *pch;
	char szKeyword[30];
	char szParameter[20];
	szKeyword[0] = '\0';
	szParameter[0] = '\0';
	// Get the next character
	if ( (ch = [self getCharacterFromBuffer]) == EOF ) {
		// It is the end of the file.
		return rkEndOfFile;
	}
	if ( !isalpha(ch) ) {
		// If the character isn't alplanumeric it's a control symbol; no delimiter.
		szKeyword[0] = (char)ch;
		szKeyword[1] = '\0'; // end the string.
		return [self translateKeyword:szKeyword withParam:0 fParam:fParam];
	}
	// Keep getting characters until we hit a non alpha character.
	for ( pch = szKeyword ; isalpha(ch) ; ch = [self getCharacterFromBuffer] ) {
		*pch++ = (char)ch;
	}
	// End the string.
	*pch = '\0';
	// Check if the last character was a dash.
	if ( ch == '-' ) {
		// Flag the parameter as negative for later.
		fNeg  = fTrue;
		// Update ch to the next character.
		if ( (ch = [self getCharacterFromBuffer]) == EOF ) {
			return rkEndOfFile;
		}
	}
	// Check if the the ch character is a digit.
	if ( isdigit( ch ) ) {
		// If there is a digit after the control it's a parameter.
		fParam = fTrue;
		// Keep getting digits until we hit a non digit character.
		for ( pch = szParameter ; isdigit(ch) ; ch = [self getCharacterFromBuffer] ) {
			*pch++ = (char)ch;
		}
		// End the string.
		*pch = '\0';
		// The atoi() function converts str into an integer, and returns
		// that integer. str should start with some sort of number, and atoi()
		// will stop reading from str as soon as a non-numerical character
		//has been read.
		param = atoi(szParameter);
		// If the param was negative make it negative.
		if ( fNeg ) {
			param = -param;
		}
		// The function atol() converts str into a long, then returns
		// that value. atol() will read from str until it finds any character
		// that should not be in a long. The resulting truncated value is
		// then converted and returned.
		lParam = atol(szParameter);
		// If the param was negative make it negative.
		if ( fNeg ) {
			param = -param;
		}
	}
	// If the character isn't a space put it in the destination.
	if ( ch != ' ' ) {
		[self putCharacter:ch];
	}
	// We have the keyword so let's figure out what to do with it.
	return [self translateKeyword:szKeyword withParam:param fParam:fParam];
}


/**
 * Route the character to the appropriate destination stream.
 */
-(int) parseCharacter:(int)ch;
{
	if ( internalState == rkInternalStateBin && --cbBin <= 0 ) {
		internalState = rkInternalStateNorm;
	}
	switch ( destinationState ) {
		case rkDestinationStateSkip:
			// Skip this character.
			return rkOK;
			
		case rkDestinationStateNorm:
			// Output a character. Properties are valid at this point.
			return [self storeCharacter:ch ];
			
		default:
			// handle other destinations....
			return rkOK;
	} /* switch */
}


#pragma mark -
#pragma mark Output Creation

/**
 * Send a character to the output file.
 */
-(int) storeCharacter:(int)ch;
{
	// @TODO revert this to use NSData.
	unsigned char chars[1];
	chars[0] = ch;
	NSString *s = [NSString stringWithCString:chars length:1];
	NSAttributedString *chr = [[NSAttributedString alloc] initWithString:s];
	[destinationString appendAttributedString:chr];
	[chr release];
	destinationLength++;
	return rkOK;
}

#pragma mark -
#pragma mark Formatting

/**
 * Send a character to the output file.
 */
-(int) applyRuns;
{

	[self setRunRangeEnd:destinationLength];

	//kCTCharacterShapeAttributeName,

	//kCTFontAttributeName
	
	for (RKFont *fontRun in fontRuns) {
		CTFontRef value = CTFontCreateWithName( (CFStringRef) @"Helvetica", [fontRun fontSize], NULL );
		CFRange range = CFRangeMake(fontRun.start, fontRun.end - fontRun.start);
		CFAttributedStringSetAttribute((CFMutableAttributedStringRef)destinationString, range, kCTFontAttributeName, value);
	}
	
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
	
	
	return rkOK;
}

@end
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
- (int)storeCharacter:(int)ch flush:(bool)flush;
- (int)endGroupAction:( rkDestinationState )rds;
- (int)applyPropertyChange:(rkProperty) rkProp val:(int)val;
- (int)changeOutputDestination:( rkDestinationType )idest;
- (int)parseSpecialKeyword:( rkSpecialType )ipfn;
- (int)parseSpecialProperty:(rkProperty)rkProp val:(int) val;
- (int)putCharacter:(int)ch;
- (int)getCharacterFromBuffer;

- (int)pushFontRun;

@end

@implementation RKReader

// RTF parser tables
// Property descriptions
static RTFProperty propertyDescription[rkPropMax] = {
	{rkActionTypeByte,   rkPropertyTypeFont,  offsetof(RKFont, fontIndex)},
	{rkActionTypeWord,   rkPropertyTypeFont,  offsetof(RKFont, fontSize)},
	{rkActionTypeByte,   rkPropertyTypeFont,  offsetof(RKFont, isBold)},
	{rkActionTypeByte,   rkPropertyTypeFont,  offsetof(RKFont, isItalic)},
	{rkActionTypeWord,   rkPropertyTypeParagraph,  offsetof(RKParagraph, indentLeft)},
	{rkActionTypeWord,   rkPropertyTypeParagraph,  offsetof(RKParagraph, indentRight)},
	{rkActionTypeWord,   rkPropertyTypeParagraph,  offsetof(RKParagraph, indentFirst)},
	{rkActionTypeByte,   rkPropertyTypeParagraph,  offsetof(RKParagraph, just)},
	{rkActionTypeSpec,   rkPropertyTypeParagraph,  0},                               
	{rkActionTypeSpec,   rkPropertyTypeFont,  0},                               
};

// Keyword descriptions
static RTFSymbol keywordDescription[] = {
	//  keyword     dflt    fPassDflt   kwd         idx
	{"f",   0,       fTrue,     rkKeywordTypeProperty,    rkPropFontIndex},
	{"fs",   12.0f,       fTrue,     rkKeywordTypeProperty,    rkPropFontSize},
	{"b",        1,      fFalse,     rkKeywordTypeProperty,    rkPropBold},  // kCTFontBoldTrait
	{"i",        1,      fFalse,     rkKeywordTypeProperty,    rkPropItalic}, // kCTFontItalicTrait
	{"li",       0,      fFalse,     rkKeywordTypeProperty,    rkPropLeftInd}, //
	{"ri",       0,      fFalse,     rkKeywordTypeProperty,    rkPropRightInd}, //
	{"fi",       0,      fFalse,     rkKeywordTypeProperty,    rkPropFirstInd}, //
	{"qc",       rkJustificationCenter,  fTrue,      rkKeywordTypeProperty,    rkPropJust},
	{"ql",       rkJustificationLeft,  fTrue,      rkKeywordTypeProperty,    rkPropJust},
	{"qr",       rkJustificationRight,  fTrue,      rkKeywordTypeProperty,    rkPropJust},
	{"qj",       rkJustificationForced,  fTrue,      rkKeywordTypeProperty,    rkPropJust},
	{"par",      0,      fFalse,     rkKeywordTypeCharacter,    0x0a},
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
-( id )initWithFilePath : ( NSString * )filePath;
{
		
	sourceRTFData  = [[NSData dataWithContentsOfMappedFile:filePath] retain];
	destinationString = [[NSMutableAttributedString alloc] initWithString:@""];
	
	fontRun = (RKFont *)malloc( sizeof(RKFont) );
	fontRun->rangeStart = 0;
	fontRun->rangeEnd = 0;
	fontRun->fontIndex = 0;
	fontRun->fontSize = 12.0;
	fontRun->isBold = FALSE;
	fontRun->isItalic = FALSE;
	
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
-(int) applyPropertyChange : (rkProperty) prop val : (int)val;
{
	char *pb;
	int ec;
	
	if ( destinationState == rkDestinationStateSkip ) {
		// If we're skipping text don't do anything.
		return rkOK;
	}
	// Get the appropriate property set based on the description.
	switch ( propertyDescription[prop].prop ) {
			
		case rkPropertyTypeParagraph:
			pb = (char *)&paragraphRun;
			break;
			
		case rkPropertyTypeFont:
			// Font property is changing so push the run.
			if ( (ec = [self pushFontRun]) != rkOK ) {
				return ec;
			}
			pb = (char *)&fontRun;
			break;
			
		default:
			if ( propertyDescription[prop].actn != rkActionTypeSpec ) {
				return rkBadTable;
			}
			break;
	} /* switch */
	
	// Apply the appropriate action based on the description
	switch ( propertyDescription[prop].actn ) {
		case rkActionTypeByte:
			pb[propertyDescription[prop].offset] = (unsigned char)val;
			break;
			
		case rkActionTypeWord:
			( *(int *)(pb + propertyDescription[prop].offset) ) = val;
			break;
			
		case rkActionTypeSpec:
			return [self parseSpecialProperty : prop val : val];
			break;
			
		default:
			return rkBadTable;
	} /* switch */
	return rkOK;
}


/**
 * Set a property that requires code to evaluate.
 */
-(int) parseSpecialProperty : (rkProperty) prop val : (int)val;
{
	switch ( prop ) {
		case rkPropPard:
			memset( &paragraphRun, 0, sizeof(paragraphRun) );
			return rkOK;
			
		case rkPropPlain:
			memset( &fontRun, 0, sizeof(fontRun) );
			return rkOK;
			
		case rkPropSectd:
			//memset( &sectionProperities, 0, sizeof(sectionProperities) );
			return rkOK;
			
		default:
			return rkBadTable;
	} /* switch */
	return rkBadTable;
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
		NSLog(@"Ignore: %@", [NSString stringWithUTF8String : keyword]);
		// control word not found
		if ( fSkipDestIfUnk ) {
			// if this is a new destination skip the destination
			destinationState = rkDestinationStateSkip;
		}
		// just discard it
		fSkipDestIfUnk = fFalse;
		return rkOK;
	}
	
	NSLog(@"Found: %@", [NSString stringWithUTF8String : keyword]);
	
	// Found it! use kwd and idx to determine what to do with it.
	fSkipDestIfUnk = fFalse;
	
	switch ( keywordDescription[isym].kwd ) {
		case rkKeywordTypeProperty:
			if ( keywordDescription[isym].fPassDflt || !fParam ) {
				param = keywordDescription[isym].dflt;
			}
			return [self applyPropertyChange : (rkProperty)keywordDescription[isym].idx val : param];
			
		case rkKeywordTypeCharacter:
			return [self parseCharacter : keywordDescription[isym].idx];
			
		case rkKeywordTypeDestination:
			return [self changeOutputDestination : (rkDestinationType)keywordDescription[isym].idx];
			
		case rkKeywordTypeSpecial:
			return [self parseSpecialKeyword : (rkSpecialType)keywordDescription[isym].idx];
			
		default:
			return rkBadTable;
	} /* switch */
	
	return rkBadTable;
}


/**
 * Evaluate an RTF control that needs special processing.
 */
-(int) parseSpecialKeyword : ( rkSpecialType )type
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
-(int) changeOutputDestination : ( rkDestinationType )dt
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
-(int) endGroupAction : ( rkDestinationState )rds
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
	[sourceRTFData getBytes : &ch range : range];
	bufferPosition++;
	return (int)ch;
}


/**
 * Put a character
 */
-(int)putCharacter : (int)ch
{
	if ( putBufferLength >= sizeof(putBuffer) / sizeof(*putBuffer) ) {
		return EOF;
	}
	putBuffer[putBufferLength++] = (unsigned char)ch;
	return ch;
}


#pragma mark -
#pragma mark Run Storage

/**
 * Save relevant info on a linked list of RTFSaveState structures.
 */
-(int) pushFontRun
{
	RKFont *fontNew = (RKFont *)malloc( sizeof(RKFont) );
	if ( !fontNew ) {
		return rkStackOverflow;
	}
	
	fontNew->next = fontRun;
	fontNew->rangeStart = destinationLength;
	fontNew->rangeEnd = destinationLength;
	
	// Maintain existing properties
	fontNew->fontIndex = fontRun->fontIndex;
	fontNew->fontSize = fontRun->fontSize;
	fontNew->isBold = fontRun->isBold;
	fontNew->isItalic = fontRun->isItalic;
	
	fontRun = fontNew;
	return rkOK;
}

#pragma mark -
#pragma mark State Management

/**
 * Save relevant info on a linked list of RTFSaveState structures.
 */
-(int) pushState
{
	RTFSaveState *psaveNew = (RTFSaveState *)malloc( sizeof(RTFSaveState) );
	if ( !psaveNew ) {
		return rkStackOverflow;
	}
	psaveNew->pNext = psave;
	psaveNew->fontRun = fontRun;
	psaveNew->paragraphRun = paragraphRun;
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
	
	fontRun = psave->fontRun;
	paragraphRun = psave->paragraphRun;
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
		if ( cGroup < 0 ) {
			return rkStackUnderflow;
		}
		if ( internalState == rkInternalStateBin ) {
			// If we're parsing binary data, handle it directly.
			if ( (ec = [self parseCharacter:ch]) != rkOK ) {
				return ec;
			}
		} else {
			switch ( ch ) {
				case '{':
					//NSLog(@"Start { %d", destinationLength);
					if ( (ec = [self pushState]) != rkOK ) {
						return ec;
					}
					break;
					
				case '}':
					//NSLog(@"End } %d", destinationLength);
					if ( (ec = [self popState]) != rkOK ) {
						return ec;
					}
					break;
					
				case '\\':
					//NSLog(@"Parse control word %d", destinationLength);
					// Parse control words
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
					// parse out the characters
					if ( internalState == rkInternalStateNorm ) {
						//NSLog(@"Parse normal character %d", destinationLength);
						if ( (ec = [self parseCharacter:ch]) != rkOK ) {
							return ec;
						}
					} else {
						// parsing hex data
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
	[self storeCharacter : '\n' flush : true];
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
		return [self translateKeyword : szKeyword withParam : 0 fParam : fParam];
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
		[self putCharacter : ch];
	}
	// We have the keyword so let's figure out what to do with it.
	return [self translateKeyword : szKeyword withParam : param fParam : fParam];
}


/**
 * Route the character to the appropriate destination stream.
 */
-(int) parseCharacter : (int)ch;
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
			return [self storeCharacter : ch flush : false];
			
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
-(int) storeCharacter : (int)ch flush : ( bool )flush;
{
	// @TODO revert this to use NSData.
	unsigned char chars[1];
	chars[0] = ch;
	NSString *s = [NSString stringWithCString:chars length:1];
	NSAttributedString *chr = [[NSAttributedString alloc] initWithString:s];
	[destinationString appendAttributedString : chr];
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

	
	// Apply font runs
	
	RKFont *run = fontRun;
	do {
		
		float size = run->fontSize;
		
	} while ( (run = fontRun->next) != nil );
	
	/*
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
		CTFontCreateWithName( (CFStringRef) @"Helvetica", fontRun->fontSize, NULL )
	};
	CFDictionaryRef attr = CFDictionaryCreate(
											  NULL,
											  (const void **)&keys,
											  (const void **)&values,
											  sizeof(keys) / sizeof(keys[0]),
											  &kCFTypeDictionaryKeyCallBacks,
											  &kCFTypeDictionaryValueCallBacks
											  );
	NSAttributedString *chr = [[NSAttributedString alloc] initWithString:s attributes:( NSDictionary * )attr];
	[destinationString appendAttributedString : chr];
	CFRelease(attr);
	[chr release];
	destinationLength++;
	 */
	return rkOK;
}

@end
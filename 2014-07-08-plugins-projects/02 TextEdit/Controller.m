
/*
     File: Controller.m
 Abstract: Central controller object for TextEdit, for implementing app functionality (services) as well
 as few tidbits for which there are no dedicated controllers.
 
  Version: 1.9
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

#import <Cocoa/Cocoa.h>
#import "Controller.h"
#import "DocumentController.h"
#import "Document.h"
#import "EncodingManager.h"
#import "TextEditDefaultsKeys.h"
#import "TextEditErrors.h"
#import "TextEditMisc.h"
#import "PluginManager.h"

static NSDictionary *defaultValues() {
    static NSDictionary *dict = nil;
    if (!dict) {
        dict = [[NSDictionary alloc] initWithObjectsAndKeys:
                [NSNumber numberWithInteger:30], AutosavingDelay,
                [NSNumber numberWithBool:NO], NumberPagesWhenPrinting,
                [NSNumber numberWithBool:YES], WrapToFitWhenPrinting,
                [NSNumber numberWithBool:YES], RichText, 
                [NSNumber numberWithBool:NO], ShowPageBreaks,
		[NSNumber numberWithBool:NO], OpenPanelFollowsMainWindow,
		[NSNumber numberWithBool:YES], AddExtensionToNewPlainTextFiles,
                [NSNumber numberWithInteger:90], WindowWidth, 
                [NSNumber numberWithInteger:30], WindowHeight, 
                [NSNumber numberWithUnsignedInteger:NoStringEncoding], PlainTextEncodingForRead,
                [NSNumber numberWithUnsignedInteger:NoStringEncoding], PlainTextEncodingForWrite,
		[NSNumber numberWithInteger:8], TabWidth,
		[NSNumber numberWithInteger:50000], ForegroundLayoutToIndex,       
                [NSNumber numberWithBool:NO], IgnoreRichText,
		[NSNumber numberWithBool:NO], IgnoreHTML,
                [NSNumber numberWithBool:YES], CheckSpellingAsYouType,
                [NSNumber numberWithBool:NO], CheckGrammarWithSpelling,
                [NSNumber numberWithBool:[NSSpellChecker isAutomaticSpellingCorrectionEnabled]], CorrectSpellingAutomatically,
                [NSNumber numberWithBool:YES], ShowRuler,
                [NSNumber numberWithBool:YES], SmartCopyPaste,
                [NSNumber numberWithBool:NO], SmartQuotes,
                [NSNumber numberWithBool:NO], SmartDashes,
                [NSNumber numberWithBool:NO], SmartLinks,
                [NSNumber numberWithBool:NO], DataDetectors,
                [NSNumber numberWithBool:[NSSpellChecker isAutomaticTextReplacementEnabled]], TextReplacement,
                [NSNumber numberWithBool:NO], SubstitutionsEnabledInRichTextOnly,
                @"", AuthorProperty,
                @"", CompanyProperty,
                @"", CopyrightProperty,
                [NSNumber numberWithBool:NO], UseXHTMLDocType,
                [NSNumber numberWithBool:NO], UseTransitionalDocType,
                [NSNumber numberWithBool:YES], UseEmbeddedCSS,
                [NSNumber numberWithBool:NO], UseInlineCSS,
                [NSNumber numberWithUnsignedInteger:NSUTF8StringEncoding], HTMLEncoding,
                [NSNumber numberWithBool:YES], PreserveWhitespace,
                [NSNumber numberWithBool:NO], UseScreenFonts,
		nil];
    }
    return dict;
}

@implementation Controller

@synthesize preferencesController, propertiesController, lineController;

+ (void)initialize {
    // Set up default values for preferences managed by NSUserDefaultsController
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues()];
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:defaultValues()];
#if __LP64__
    // At some point during 32-to-64 bit transition of TextEdit, some versions erroneously wrote out the value of -1 to defaults. These values cause grief throughout the program under 64-bit, so it's best to clean them out from defaults permanently. Note that it's often considered bad form to write defaults while launching; however, here we do this only once, ever.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([[defaults objectForKey:PlainTextEncodingForRead] unsignedIntegerValue] == 0xFFFFFFFFFFFFFFFFULL) [defaults removeObjectForKey:PlainTextEncodingForRead];
    if ([[defaults objectForKey:PlainTextEncodingForWrite] unsignedIntegerValue] == 0xFFFFFFFFFFFFFFFFULL) [defaults removeObjectForKey:PlainTextEncodingForWrite];
#endif
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    // To get service requests to go to the controller...
    [NSApp setServicesProvider:self];
    
    
    [self setPluginManager:[[[PluginManager alloc] init] autorelease]];
    
    [[self pluginManager] loadPlugins];
    
}

/*** Services support ***/

- (void)openFile:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error {
    NSString *filename, *origFilename;
    NSURL *url = nil;
    NSError *err = nil;
    NSString *type = [pboard availableTypeFromArray:[NSArray arrayWithObject:(NSString *)kUTTypePlainText]];

    if (type && (filename = origFilename = [pboard stringForType:type])) {
        BOOL success = NO;
        if ([filename isAbsolutePath] && (url = [NSURL fileURLWithPath:filename])) {	// If seems to be a valid absolute path, first try using it as-is
	    success = [(DocumentController *)[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES error:&err] != nil;
        }
        if (!success) {	// Check to see if the user mistakenly included a carriage return or more at the end of the file name...
            filename = [[filename substringWithRange:[filename lineRangeForRange:NSMakeRange(0, 0)]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([filename hasPrefix:@"~"]) filename = [filename stringByExpandingTildeInPath];	// Convert the "~username" case
	    if (![origFilename isEqual:filename] && [filename isAbsolutePath]) {
                url = [NSURL fileURLWithPath:filename];
		success = [(DocumentController *)[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES error:&err] != nil;
	    }
        }
        // Given that this is a one-way service (no return), we need to put up the error panel ourselves and we do not set *error.
        if (!success) {
	    if (!err) {
		err = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadInvalidFileNameError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:truncatedString(filename, PATH_MAX+10), NSFilePathErrorKey, nil]];
	    }
	    [[NSAlert alertWithError:err] runModal];
        }
    }
}

/* The following, apart from providing the service through the Services menu, allows the user to drop snippets of text on the TextEdit icon and have it open as a new document. */
- (void)openSelection:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error {
    NSError *err = nil;
    Document *document = [(DocumentController *)[NSDocumentController sharedDocumentController] openDocumentWithContentsOfPasteboard:pboard display:YES error:&err];
    
    if (!document) {
	[[NSAlert alertWithError:err] runModal];
        // No need to report an error string...
    }
}

@end




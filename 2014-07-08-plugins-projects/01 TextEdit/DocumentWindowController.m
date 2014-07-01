
/*
     File: DocumentWindowController.m
 Abstract: Document's main window controller object for TextEdit.
 
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

#import "DocumentWindowController.h"
#import "Document.h"
#import "MultiplePageView.h"
#import "TextEditDefaultsKeys.h"
#import "TextEditMisc.h"
#import "TextEditErrors.h"

@interface DocumentWindowController(Private)

- (void)setDocument:(Document *)doc; // Overridden with more specific type. Expects Document instance.

- (void)setupInitialTextViewSharedState;
- (void)setupTextViewForDocument;
- (void)setupWindowForDocument;
- (void)setupPagesViewForLayoutOrientation:(NSTextLayoutOrientation)orientation;

- (void)updateForRichTextAndRulerState:(BOOL)rich;
- (void)autosaveIfNeededThenToggleRich;
- (void)toggleRichWithNewFileType:(NSString *)fileType;

- (void)showRulerDelayed:(BOOL)flag;

- (void)addPage;
- (void)removePage;

- (NSTextView *)firstTextView;

- (void)printInfoUpdated;

- (void)resizeWindowForViewSize:(NSSize)size;
- (void)setHasMultiplePages:(BOOL)pages force:(BOOL)force;

@end


@implementation DocumentWindowController

- (id)init {
    if (self = [super initWithWindowNibName:@"DocumentWindow"]) {
	layoutMgr = [[NSLayoutManager allocWithZone:[self zone]] init];
	[layoutMgr setDelegate:self];
	[layoutMgr setAllowsNonContiguousLayout:YES];
    }
    return self;
}

- (void)dealloc {
    if ([self document]) [self setDocument:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [[self firstTextView] removeObserver:self forKeyPath:@"backgroundColor"];
    [scrollView removeObserver:self forKeyPath:@"scaleFactor"];
    [[scrollView verticalScroller] removeObserver:self forKeyPath:@"scrollerStyle"];
    [layoutMgr release];
    
    [self showRulerDelayed:NO];
    
    [super dealloc]; // NSWindowController deallocates all the nib objects
}

/* This method can be called in three different situations (number three is a special TextEdit case):
	1) When the window controller is created and set up with a new or opened document. (!oldDoc && doc)
	2) When the document is closed, and the controller is about to be destroyed (oldDoc && !doc)
	3) When the window controller is assigned to another document (a document has been opened and it takes the place of an automatically-created window).  In that case this method is called twice.  First as #2 above, second as #1.
 
   The window can be visible or hidden at the time of the message.
*/
- (void)setDocument:(Document *)doc {
    Document *oldDoc = [[self document] retain];
    
    if (oldDoc) {
        [layoutMgr unbind:@"hyphenationFactor"];
        [[self firstTextView] unbind:@"editable"];
    }
    [super setDocument:doc];
    if (doc) {
        [layoutMgr bind:@"hyphenationFactor" toObject:self withKeyPath:@"document.hyphenationFactor" options:nil];
        [[self firstTextView] bind:@"editable" toObject:self withKeyPath:@"document.readOnly" options:[NSDictionary dictionaryWithObject:NSNegateBooleanTransformerName forKey:NSValueTransformerNameBindingOption]];
    }
    if (oldDoc != doc) {
	if (oldDoc) {
            /* Remove layout manager from the old Document's text storage. No need to retain as we already own the object. */
	    [[oldDoc textStorage] removeLayoutManager:layoutMgr];
	    
	    [oldDoc removeObserver:self forKeyPath:@"printInfo"];
	    [oldDoc removeObserver:self forKeyPath:@"richText"];
	    [oldDoc removeObserver:self forKeyPath:@"viewSize"];
	    [oldDoc removeObserver:self forKeyPath:@"hasMultiplePages"];
	}
	
	if (doc) {
            [[doc textStorage] addLayoutManager:layoutMgr];
	    
	    if ([self isWindowLoaded]) {
                [self setHasMultiplePages:[doc hasMultiplePages] force:NO];
                [self setupInitialTextViewSharedState];
                [self setupWindowForDocument];
		if ([doc hasMultiplePages]) [scrollView setScaleFactor:[[self document] scaleFactor] adjustPopup:YES];
                [[doc undoManager] removeAllActions];
            }
	    
	    [doc addObserver:self forKeyPath:@"printInfo" options:0 context:NULL];
	    [doc addObserver:self forKeyPath:@"richText" options:0 context:NULL];
	    [doc addObserver:self forKeyPath:@"viewSize" options:0 context:NULL];
	    [doc addObserver:self forKeyPath:@"hasMultiplePages" options:0 context:NULL];
	}
    }
    
    [oldDoc release];
}

- (void)breakUndoCoalescing {
    [[self firstTextView] breakUndoCoalescing];
}

- (NSLayoutManager *)layoutManager {
    return layoutMgr;
}

- (NSTextView *)firstTextView {
    return [[self layoutManager] firstTextView];
}

- (void)setupInitialTextViewSharedState {
    NSTextView *textView = [self firstTextView];
    
    [textView setUsesFontPanel:YES];
    [textView setUsesFindBar:YES];
    [textView setIncrementalSearchingEnabled:YES];
    [textView setDelegate:self];
    [textView setAllowsUndo:YES];
    [textView setAllowsDocumentBackgroundColorChange:YES];
    [textView setIdentifier:@"First Text View"];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Some settings are not enabled for plain text docs if the default "SubstitutionsEnabledInRichTextOnly" is set to YES.
    // There is no UI at this stage for this preference.
    BOOL substitutionsOK = [[self document] isRichText] || ![defaults boolForKey:SubstitutionsEnabledInRichTextOnly];    
    [textView setContinuousSpellCheckingEnabled:[defaults boolForKey:CheckSpellingAsYouType]];
    [textView setGrammarCheckingEnabled:[defaults boolForKey:CheckGrammarWithSpelling]];
    [textView setAutomaticSpellingCorrectionEnabled:substitutionsOK && [defaults boolForKey:CorrectSpellingAutomatically]];
    [textView setSmartInsertDeleteEnabled:[defaults boolForKey:SmartCopyPaste]];
    [textView setAutomaticQuoteSubstitutionEnabled:substitutionsOK && [defaults boolForKey:SmartQuotes]];
    [textView setAutomaticDashSubstitutionEnabled:substitutionsOK && [defaults boolForKey:SmartDashes]];
    [textView setAutomaticLinkDetectionEnabled:[defaults boolForKey:SmartLinks]];
    [textView setAutomaticDataDetectionEnabled:[defaults boolForKey:DataDetectors]];
    [textView setAutomaticTextReplacementEnabled:substitutionsOK && [defaults boolForKey:TextReplacement]];
    
    [textView setSelectedRange:NSMakeRange(0, 0)];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [self firstTextView]) {
	if ([keyPath isEqualToString:@"backgroundColor"]) {
	    [[self document] setBackgroundColor:[[self firstTextView] backgroundColor]];
	} 
    } else if (object == scrollView) {
	if ([keyPath isEqualToString:@"scaleFactor"]) {
	    [[self document] setScaleFactor:[scrollView scaleFactor]];
	} 
    } else if (object == [scrollView verticalScroller]) {
        if ([keyPath isEqualToString:@"scrollerStyle"]) {
            [self invalidateRestorableState];
            NSSize size = [[self document] viewSize];
            if (!NSEqualSizes(size, NSZeroSize)) {
                [self resizeWindowForViewSize:size];
            }
        }
    } else if (object == [self document]) {
	if ([keyPath isEqualToString:@"printInfo"]) {
	    [self printInfoUpdated];
	} else if ([keyPath isEqualToString:@"viewSize"]) {
	    if (!isSettingSize) {
		NSSize size = [[self document] viewSize];
		if (!NSEqualSizes(size, NSZeroSize)) {
		    [self resizeWindowForViewSize:size];
		}
	    }
	} else if ([keyPath isEqualToString:@"hasMultiplePages"]) {
	    [self setHasMultiplePages:[[self document] hasMultiplePages] force:NO];
	}
    }
}

- (void)setupTextViewForDocument {
    Document *doc = [self document];
    NSArray *sections = [doc originalOrientationSections];
    NSTextLayoutOrientation orientation = NSTextLayoutOrientationHorizontal;
    BOOL rich = [doc isRichText];
    
    if (doc && (!rich || [[[self firstTextView] textStorage] length] == 0)) [[self firstTextView] setTypingAttributes:[doc defaultTextAttributes:rich]];
    [self updateForRichTextAndRulerState:rich];
    
    [[self firstTextView] setBackgroundColor:[doc backgroundColor]];
    [[[self firstTextView] layoutManager] setUsesScreenFonts:[doc usesScreenFonts]];

    // process the initial container
    if ([sections count] > 0) {
        for (NSDictionary *dict in sections) {
            id rangeValue = [dict objectForKey:NSTextLayoutSectionRange];
            
            if (!rangeValue || NSLocationInRange(0, [rangeValue rangeValue])) {
                orientation = NSTextLayoutOrientationVertical;
                [[self firstTextView] setLayoutOrientation:orientation];
                break;
            }
        }
    }

    if (hasMultiplePages && (orientation != NSTextLayoutOrientationHorizontal)) [self setupPagesViewForLayoutOrientation:orientation];
}

- (void)printInfoUpdated {
    if (hasMultiplePages) {
        NSUInteger cnt;
        MultiplePageView *pagesView = [scrollView documentView];
        NSArray *textContainers = [[self layoutManager] textContainers];
	
        [pagesView setPrintInfo:[[self document] printInfo]];

        for (cnt = 0; cnt < [self numberOfPages]; cnt++) {      // Call -numberOfPages repeatedly since it may change
            NSRect textFrame = [pagesView documentRectForPageNumber:cnt];
            NSTextContainer *textContainer = [textContainers objectAtIndex:cnt];
            [textContainer setContainerSize:textFrame.size];
            [[textContainer textView] setFrame:textFrame];
        }
    }
}

/* Method to lazily display ruler. Call with YES to display, NO to cancel display; this method doesn't remove the ruler. 
*/
- (void)showRulerDelayed:(BOOL)flag {
    if (!flag && rulerIsBeingDisplayed) {
        [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(showRuler:) object:self];
    } else if (flag && !rulerIsBeingDisplayed) {
        [self performSelector:@selector(showRuler:) withObject:self afterDelay:0.0];
    }
    rulerIsBeingDisplayed = flag;
}

- (void)showRuler:(id)obj {
    if (rulerIsBeingDisplayed && !obj) [self showRulerDelayed:NO];	// Cancel outstanding request, if not coming from the delayed request
    if ([[NSUserDefaults standardUserDefaults] boolForKey:ShowRuler]) [[self firstTextView] setRulerVisible:YES];
}

/* Used when converting to plain text
*/
- (void)removeAttachments {
    NSTextStorage *attrString = [[self document] textStorage];
    NSTextView *view = [self firstTextView];
    NSUInteger loc = 0;
    NSUInteger end = [attrString length];
    [attrString beginEditing];
    while (loc < end) {	/* Run through the string in terms of attachment runs */
        NSRange attachmentRange;	/* Attachment attribute run */
        NSTextAttachment *attachment = [attrString attribute:NSAttachmentAttributeName atIndex:loc longestEffectiveRange:&attachmentRange inRange:NSMakeRange(loc, end-loc)];
        if (attachment) {	/* If there is an attachment and it is on an attachment character, remove the character */
            unichar ch = [[attrString string] characterAtIndex:loc];
            if (ch == NSAttachmentCharacter) {
		if ([view shouldChangeTextInRange:NSMakeRange(loc, 1) replacementString:@""]) {
		    [attrString replaceCharactersInRange:NSMakeRange(loc, 1) withString:@""];
		    [view didChangeText];
		}
                end = [attrString length];	/* New length */
            }
	    else loc++;	/* Just skip over the current character... */
        }
    	else loc = NSMaxRange(attachmentRange);
    }
    [attrString endEditing];
}

/* This method implements panel-based "attach" functionality. Note that as-is, it's set to accept all files; however, by setting allowed types on the open panel it can be restricted to images, etc.
*/

- (void)presenterDidPresent:(BOOL)inDidSucceed soContinue:(void (^)(BOOL didSucceed))inContinuerCopy {
    inContinuerCopy(inDidSucceed);
    Block_release(inContinuerCopy);
}

- (void)chooseAndAttachFiles:(id)sender {
    [[self document] performActivityWithSynchronousWaiting:YES usingBlock:^(void (^activityCompletionHandler)(void)) {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setAllowsMultipleSelection:YES];
    // Use the 10.6-introduced sheet API with block handler
    [panel beginSheetModalForWindow:[self window] completionHandler:^(NSInteger result) {
	if (result == NSFileHandlingPanelOKButton) {	// Only if not cancelled
            NSArray *urls = [panel URLs];
	    NSTextView *textView = [self firstTextView];
	    NSInteger numberOfErrors = 0;
	    NSError *error = nil;
	    NSMutableAttributedString *attachments = [[NSMutableAttributedString alloc] init];
            
	    // Process all the attachments, creating an attributed string 
	    for (NSURL *url in urls) {
		NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithURL:url options:NSFileWrapperReadingImmediate error:&error];
		if (wrapper) {
		    NSTextAttachment *attachment = [[NSTextAttachment alloc] initWithFileWrapper:wrapper];
		    [attachments appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
		    [wrapper release];
		    [attachment release];
		} else {
		    numberOfErrors++;
		}
	    }
	    
	    // We could actually take an approach where on partial success we allow the user to cancel the operation, but since it's easy enough to undo, this seems reasonable enough
	    if ([attachments length] > 0) {
		NSRange selectionRange = [textView selectedRange];
		if ([textView shouldChangeTextInRange:selectionRange replacementString:[attachments string]]) {  // Shouldn't fail, since we are controlling the text view; but if it does, we simply don't allow the change
		    [[textView textStorage] replaceCharactersInRange:selectionRange withAttributedString:attachments];
		    [textView didChangeText];
		}
	    }
	    [attachments release];
	    
	    [panel orderOut:nil];   // Strictly speaking not necessary, but if we put up an error sheet, a good idea for the panel to be dismissed first
            
	    // Deal with errors opening some or all of the attachments
	    if (numberOfErrors > 0) {
		if (numberOfErrors > 1) {  // More than one failure, put up a summary error (which doesn't do a good job of communicating the actual errors, but multiple attachments is a relatively rare case). For one error, we present the actual NSError we got back.
		    // The error message will be different depending on whether all or some of the files were successfully attached.
		    NSString *description = (numberOfErrors == [urls count]) ? NSLocalizedString(@"None of the items could be attached.", @"Title of alert indicating error during 'Attach Files...' when user tries to attach (insert) multiple files and none can be attached.") : NSLocalizedString(@"Some of the items could not be attached.", @"Title of alert indicating error during 'Attach Files...' when user tries to attach (insert) multiple files and some fail.");
		    error = [NSError errorWithDomain:TextEditErrorDomain code:TextEditAttachFilesFailure userInfo:[NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, NSLocalizedString(@"The files may be unreadable, or the volume they are on may be inaccessible. Please check in Finder.", @"Recommendation when 'Attach Files...' command fails"), NSLocalizedRecoverySuggestionErrorKey, nil]];
		}
                    [[self window] presentError:error modalForWindow:[self window] delegate:self didPresentSelector:@selector(presenterDidPresent:soContinue:) contextInfo:Block_copy(^(BOOL didSucceed) {
                        activityCompletionHandler();
                    })];
                } else {
                    activityCompletionHandler();
	    }
            } else {
                activityCompletionHandler();
	}
    }];
    }];
}


/* Doesn't check to see if the prev value is the same --- Otherwise the first time doesn't work... */
- (void)updateForRichTextAndRulerState:(BOOL)rich {
    NSTextView *view = [self firstTextView];
    [view setRichText:rich];
    [view setUsesRuler:rich];	// If NO, this correctly gets rid of the ruler if it was up
    [view setUsesInspectorBar:rich];
    if (!rich && rulerIsBeingDisplayed) [self showRulerDelayed:NO];	// Cancel delayed ruler request
    if (rich && ![[self document] isReadOnly]) [self showRulerDelayed:YES];
    [view setImportsGraphics:rich];
    [[view layoutManager] setUsesScreenFonts:rich ? NO : YES];
}

- (void)configureTypingAttributesAndDefaultParagraphStyleForTextView:(NSTextView *)view {
    Document *doc = [self document];
    BOOL rich = [doc isRichText];
    NSDictionary *textAttributes = [doc defaultTextAttributes:rich];
    NSParagraphStyle *paragraphStyle = [textAttributes objectForKey:NSParagraphStyleAttributeName];

    [view setTypingAttributes:textAttributes];
    [view setDefaultParagraphStyle:paragraphStyle];
}

- (void)convertTextForRichTextState:(BOOL)rich removeAttachments:(BOOL)attachmentFlag {
    NSTextView *view = [self firstTextView];
    Document *doc = [self document];
    NSDictionary *textAttributes = [doc defaultTextAttributes:rich];
    NSParagraphStyle *paragraphStyle = [textAttributes objectForKey:NSParagraphStyleAttributeName];
    
    // Note, since the textview content changes (removing attachments and changing attributes) create undo actions inside the textview, we do not execute them here if we're undoing or redoing
    if (![[doc undoManager] isUndoing] && ![[doc undoManager] isRedoing]) {
	NSTextStorage *textStorage = [[self document] textStorage];
	if (!rich && attachmentFlag) [self removeAttachments];
	NSRange range = NSMakeRange(0, [textStorage length]);
        if ([view shouldChangeTextInRange:range replacementString:nil]) {
            [textStorage beginEditing];
            [doc applyDefaultTextAttributes:rich];
            [textStorage endEditing];
	    [view didChangeText];
	}
    }
    [view setTypingAttributes:textAttributes];
    [view setDefaultParagraphStyle:paragraphStyle];
}

- (NSUInteger)numberOfPages {
    return hasMultiplePages ? [[scrollView documentView] numberOfPages] : 1;
}

- (void)updateTextViewGeometry {
    MultiplePageView *pagesView = [scrollView documentView];

    [[[self layoutManager] textContainers] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [[obj textView] setFrame:[pagesView documentRectForPageNumber:idx]];
    }];
}

- (void)setupPagesViewForLayoutOrientation:(NSTextLayoutOrientation)orientation {
    MultiplePageView *pagesView = [scrollView documentView];
    
    [pagesView setLayoutOrientation:orientation];
    [[self firstTextView] setLayoutOrientation:orientation];
    [self updateTextViewGeometry];
    
    [scrollView setHasHorizontalRuler:(NSTextLayoutOrientationHorizontal == orientation) ? YES : NO];
    [scrollView setHasVerticalRuler:(NSTextLayoutOrientationHorizontal == orientation) ? NO : YES];
}

- (void)addPage {
    NSZone *zone = [self zone];
    NSUInteger numberOfPages = [self numberOfPages];
    MultiplePageView *pagesView = [scrollView documentView];
    
    NSSize textSize = [pagesView documentSizeInPage];
    NSTextContainer *textContainer = [[NSTextContainer allocWithZone:zone] initWithContainerSize:textSize];
    NSTextView *textView;
    NSUInteger orientation = [pagesView layoutOrientation];
    NSRect visibleRect = [pagesView visibleRect];
    CGFloat originalWidth = NSWidth([pagesView bounds]);

    [textContainer setWidthTracksTextView:YES];
    [textContainer setHeightTracksTextView:YES];

    [pagesView setNumberOfPages:numberOfPages + 1];
    if (NSTextLayoutOrientationVertical == [pagesView layoutOrientation]) {
        visibleRect.origin.x += (NSWidth([pagesView bounds]) - originalWidth);
        [pagesView scrollRectToVisible:visibleRect];
    }

    textView = [[NSTextView allocWithZone:zone] initWithFrame:[pagesView documentRectForPageNumber:numberOfPages] textContainer:textContainer];
    [textView setLayoutOrientation:orientation];
    [textView setHorizontallyResizable:NO];
    [textView setVerticallyResizable:NO];

    if (NSTextLayoutOrientationVertical == orientation) { // Adjust the initial container size
        textSize = NSMakeSize(textSize.height, textSize.width); // Translate size
        [textContainer setContainerSize:textSize];
    }
    [self configureTypingAttributesAndDefaultParagraphStyleForTextView:textView];
    [pagesView addSubview:textView];
    [[self layoutManager] addTextContainer:textContainer];

    [textView release];
    [textContainer release];
}

- (void)removePage {
    NSUInteger numberOfPages = [self numberOfPages];
    NSArray *textContainers = [[self layoutManager] textContainers];
    NSTextContainer *lastContainer = [textContainers objectAtIndex:[textContainers count] - 1];
    MultiplePageView *pagesView = [scrollView documentView];
    
    [pagesView setNumberOfPages:numberOfPages - 1];
    [[lastContainer textView] removeFromSuperview];
    [[lastContainer layoutManager] removeTextContainerAtIndex:[textContainers count] - 1];
}

- (NSView *)documentView {
    return [scrollView documentView];
}

- (void)setHasMultiplePages:(BOOL)pages force:(BOOL)force {
    NSTextLayoutOrientation orientation = NSTextLayoutOrientationHorizontal;
    NSZone *zone = [self zone];
    
    if (!force && (hasMultiplePages == pages)) return;
    
    hasMultiplePages = pages;
    
    [[self firstTextView] removeObserver:self forKeyPath:@"backgroundColor"];
    [[self firstTextView] unbind:@"editable"];

    if ([self firstTextView]) {
        orientation = [[self firstTextView] layoutOrientation];
    } else {
        NSArray *sections = [[self document] originalOrientationSections];

        if (([sections count] > 0) && (NSTextLayoutOrientationVertical == [[[sections objectAtIndex:0] objectForKey:NSTextLayoutSectionOrientation] unsignedIntegerValue])) orientation = NSTextLayoutOrientationVertical;
    }

    if (hasMultiplePages) {
        NSTextView *textView = [self firstTextView];
        MultiplePageView *pagesView = [[MultiplePageView allocWithZone:zone] init];
	
        [scrollView setDocumentView:pagesView];
	
        [pagesView setPrintInfo:[[self document] printInfo]];
        [pagesView setLayoutOrientation:orientation];

        // Add the first new page before we remove the old container so we can avoid losing all the shared text view state.
        [self addPage];
        if (textView) {
            [[self layoutManager] removeTextContainerAtIndex:0];
        }

        if (NSTextLayoutOrientationVertical == orientation) [self updateTextViewGeometry];
        
        [scrollView setHasVerticalScroller:YES];
        [scrollView setHasHorizontalScroller:YES];

        // Make sure the selected text is shown
        [[self firstTextView] scrollRangeToVisible:[[self firstTextView] selectedRange]];
	
        NSRect visRect = [pagesView visibleRect];
        NSRect pageRect = [pagesView pageRectForPageNumber:0];
        if (visRect.size.width < pageRect.size.width) {	// If we can't show the whole page, tweak a little further
            NSRect docRect = [pagesView documentRectForPageNumber:0];
            if (visRect.size.width >= docRect.size.width) {	// Center document area in window
                visRect.origin.x = docRect.origin.x - floor((visRect.size.width - docRect.size.width) / 2);
                if (visRect.origin.x < pageRect.origin.x) visRect.origin.x = pageRect.origin.x;
            } else {	// If we can't show the document area, then show left edge of document area (w/out margins)
                visRect.origin.x = docRect.origin.x;
            }
            [pagesView scrollRectToVisible:visRect];
        }
        [pagesView release];
    } else {
        NSSize size = [scrollView contentSize];
        NSTextContainer *textContainer = [[NSTextContainer allocWithZone:zone] initWithContainerSize:NSMakeSize(size.width, CGFLOAT_MAX)];
        NSTextView *textView = [[NSTextView allocWithZone:zone] initWithFrame:NSMakeRect(0.0, 0.0, size.width, size.height) textContainer:textContainer];
	
        // Insert the single container as the first container in the layout manager before removing the existing pages in order to preserve the shared view state.
        [[self layoutManager] insertTextContainer:textContainer atIndex:0];
	
        if ([[scrollView documentView] isKindOfClass:[MultiplePageView class]]) {
            NSArray *textContainers = [[self layoutManager] textContainers];
            NSUInteger cnt = [textContainers count];
            while (cnt-- > 1) {
                [[self layoutManager] removeTextContainerAtIndex:cnt];
            }
        }

        [textContainer setWidthTracksTextView:YES];
        [textContainer setHeightTracksTextView:NO];		/* Not really necessary */
        [textView setHorizontallyResizable:NO];			/* Not really necessary */
        [textView setVerticallyResizable:YES];
        [textView setAutoresizingMask:NSViewWidthSizable];
        [textView setMinSize:size];	/* Not really necessary; will be adjusted by the autoresizing... */
        [textView setMaxSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];	/* Will be adjusted by the autoresizing... */  
        [self configureTypingAttributesAndDefaultParagraphStyleForTextView:textView];

        [textView setLayoutOrientation:orientation]; // this configures the above settings

        /* The next line should cause the multiple page view and everything else to go away */
        [scrollView setDocumentView:textView];

        [scrollView setHasVerticalScroller:YES];
        [scrollView setHasHorizontalScroller:YES];

        [textView release];
        [textContainer release];
	
        // Show the selected region
        [[self firstTextView] scrollRangeToVisible:[[self firstTextView] selectedRange]];
    }

    [scrollView setHasHorizontalRuler:((orientation == NSTextLayoutOrientationHorizontal) ? YES : NO)];
    [scrollView setHasVerticalRuler:((orientation == NSTextLayoutOrientationHorizontal) ? NO : YES)];

    [[self firstTextView] addObserver:self forKeyPath:@"backgroundColor" options:0 context:NULL];
    [[self firstTextView] bind:@"editable" toObject:self withKeyPath:@"document.readOnly" options:[NSDictionary dictionaryWithObject:NSNegateBooleanTransformerName forKey:NSValueTransformerNameBindingOption]];
    
    [[scrollView window] makeFirstResponder:[self firstTextView]];
    [[scrollView window] setInitialFirstResponder:[self firstTextView]];	// So focus won't be stolen (2934918)
}

/* We override these pair of methods so we can stash away the scrollerStyle, since we want to preserve the size of the document (rather than the size of the window).
 */
- (void)restoreStateWithCoder:(NSCoder *)coder {
    [super restoreStateWithCoder:coder];
    if ([coder containsValueForKey:@"scrollerStyle"]) {
        NSScrollerStyle previousScrollerStyle = [coder decodeIntegerForKey:@"scrollerStyle"];
        if (previousScrollerStyle != [NSScroller preferredScrollerStyle] && ! [[self document] hasMultiplePages]) {
            // When we encoded the frame, the window was sized for this saved style. The preferred scroller style has since changed. Given our current frame and the style it had applied, compute how big the view must have been, and then resize ourselves to make the view that size.
            NSSize scrollViewSize = [scrollView frame].size;
            NSSize previousViewSize = [[scrollView class] contentSizeForFrameSize:scrollViewSize horizontalScrollerClass:[scrollView hasHorizontalScroller] ? [NSScroller class] : Nil verticalScrollerClass:[scrollView hasVerticalScroller] ? [NSScroller class] : Nil borderType:[scrollView borderType] controlSize:NSRegularControlSize scrollerStyle:previousScrollerStyle];
            previousViewSize.width -= (defaultTextPadding() * 2.0);
            [self resizeWindowForViewSize:previousViewSize];
        }
    }
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    // Normally you would just encode things that changed; however, since the only invalidation we do is for scrollerStyle, this approach is fine for now.
    [coder encodeInteger:[NSScroller preferredScrollerStyle] forKey:@"scrollerStyle"];
}

- (void)resizeWindowForViewSize:(NSSize)size {
    NSWindow *window = [self window];
    NSRect origWindowFrame = [window frame];
    NSScrollerStyle scrollerStyle;
    if (![[self document] hasMultiplePages]) {
	size.width += (defaultTextPadding() * 2.0);
        scrollerStyle = [NSScroller preferredScrollerStyle];
    } else {
        scrollerStyle = NSScrollerStyleLegacy;  // For the wrap-to-page case, which uses legacy style scrollers for now
    }
    NSRect scrollViewRect = [[window contentView] frame];
    scrollViewRect.size = [[scrollView class] frameSizeForContentSize:size horizontalScrollerClass:[scrollView hasHorizontalScroller] ? [NSScroller class] : Nil verticalScrollerClass:[scrollView hasVerticalScroller] ? [NSScroller class] : Nil borderType:[scrollView borderType] controlSize:NSRegularControlSize scrollerStyle:scrollerStyle];
    NSRect newFrame = [window frameRectForContentRect:scrollViewRect];
    newFrame.origin = NSMakePoint(origWindowFrame.origin.x, NSMaxY(origWindowFrame) - newFrame.size.height);
    [window setFrame:newFrame display:YES];
}

- (void)setupWindowForDocument {
    NSSize viewSize = [[self document] viewSize];
    [self setupTextViewForDocument];
    
    if (!NSEqualSizes(viewSize, NSZeroSize)) { // Document has a custom view size that should be used
	[self resizeWindowForViewSize:viewSize];
    } else { // Set the window size from defaults...
	if (hasMultiplePages) {
	    [self resizeWindowForViewSize:[[scrollView documentView] pageRectForPageNumber:0].size];
	} else {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSInteger windowHeight = [defaults integerForKey:WindowHeight];
            NSInteger windowWidth = [defaults integerForKey:WindowWidth];
            NSFont *font = [[self document] isRichText] ? [NSFont userFontOfSize:0.0] : [[NSFont userFixedPitchFontOfSize:0.0] screenFontWithRenderingMode:NSFontDefaultRenderingMode];
            NSSize size;
            size.height = ceil([[self layoutManager] defaultLineHeightForFont:font] * windowHeight);
            size.width = [@"x" sizeWithAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]].width;
            if (size.width == 0.0) size.width = [@" " sizeWithAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]].width; /* try for space width */
            if (size.width == 0.0) size.width = [font maximumAdvancement].width; /* or max width */
            size.width  = ceil(size.width * windowWidth);
            [self resizeWindowForViewSize:size];
	}
    }
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // This creates the first text view
    [self setHasMultiplePages:[[self document] hasMultiplePages] force:YES];
    
    // This sets it up
    [self setupInitialTextViewSharedState];
    
    // This makes sure the window's UI (including text view shared state) is updated to reflect the document
    [self setupWindowForDocument];
    
    // Changes to the zoom popup need to be communicated to the document
    if ([[self document] hasMultiplePages]) [scrollView setScaleFactor:[[self document] scaleFactor] adjustPopup:YES];
    [scrollView addObserver:self forKeyPath:@"scaleFactor" options:0 context:NULL];
    [[scrollView verticalScroller] addObserver:self forKeyPath:@"scrollerStyle" options:0 context:NULL];
    [[[self document] undoManager] removeAllActions];
}

- (void)setDocumentEdited:(BOOL)edited {
    [super setDocumentEdited:edited];
    if (edited) [[self document] setOriginalOrientationSections:nil];
}

/* Layout orientation sections */
- (NSArray *)layoutOrientationSections {
    NSArray *textContainers = [layoutMgr textContainers];
    NSMutableArray *sections = nil;
    NSUInteger layoutOrientation = 0; // horizontal
    NSRange range = NSMakeRange(0, 0);
    
    for (NSTextContainer *container in textContainers) {
        NSUInteger newOrientation = [container layoutOrientation];
        
        if (newOrientation != layoutOrientation) {
            if (range.length > 0) {
                if (!sections) sections = [NSMutableArray arrayWithCapacity:0];
                
                [sections addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:layoutOrientation], NSTextLayoutSectionOrientation, [NSValue valueWithRange:range], NSTextLayoutSectionRange, nil]];
                
                range.length = 0;
            }
            
            layoutOrientation = newOrientation;
        }
        
        if (layoutOrientation > 0) {
            NSRange containerRange = [layoutMgr characterRangeForGlyphRange:[layoutMgr glyphRangeForTextContainer:container] actualGlyphRange:NULL];
            
            if (range.length == 0) {
                range = containerRange;
            } else {
                range.length = NSMaxRange(containerRange) - range.location;
            }
        }
    }
    
    if (range.length > 0) {
        if (!sections) sections = [NSMutableArray arrayWithCapacity:0];
        
        [sections addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:layoutOrientation], NSTextLayoutSectionOrientation, [NSValue valueWithRange:range], NSTextLayoutSectionRange, nil]];
    }
    
    return sections;
}

- (void)toggleRichWithNewFileType:(NSString *)type {
    Document *document = [self document];
    NSURL *fileURL = [document fileURL];
    BOOL isRich = [document isRichText];    // This is the old value
    
    NSUndoManager *undoManager = [document undoManager];
    [undoManager beginUndoGrouping];
    
    NSString *undoType = (NSString *)((isRich) ? (([[[self firstTextView] textStorage] containsAttachments] || [[document fileType] isEqualToString:(NSString *)kUTTypeRTFD]) ? kUTTypeRTFD : kUTTypeRTF) : kUTTypePlainText);

    [undoManager registerUndoWithTarget:self selector:_cmd object:undoType];
    
    [document setUsesScreenFonts:isRich];
    [self updateForRichTextAndRulerState:!isRich];
    [self convertTextForRichTextState:!isRich removeAttachments:isRich];
    
    if (isRich) {
        [document clearDocumentProperties];
    } else {
        [document setDocumentPropertiesToDefaults];
    }
    
    [undoManager setActionName:([undoManager isUndoing] ^ isRich) ? NSLocalizedString(@"Make Plain Text", @"Undo menu item text (without 'Undo ') for making a document plain text") : NSLocalizedString(@"Make Rich Text", @"Undo menu item text (without 'Undo ') for making a document rich text")];
    
    [undoManager endUndoGrouping];
    
    if (type == nil) type = (NSString *)(isRich ? kUTTypePlainText : kUTTypeRTF);
    
    if (fileURL) {

        // Synchronously calling a method that invokes -performAsynchronousFileAccessUsingBlock: (like -saveToURL:ofType:forSaveOperation:completionHandler:) in the completion handler of method that uses -continueAsynchronousWorkOnMainThreadUsingBlock: to invoke its completion handler on the main thread (like -autosaveWithImplicitCancellability:completionHandler:, used in -toggleRich:) triggers a bug in NSdocument where the -performAsynchronousFileAccessUsingBlock: invocation has no effect besides invoking its block. This can potentially result in two 'file access' blocks being invoked at the same time, which breaks the contract.
        CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopDefaultMode, ^{
            [document saveToURL:fileURL ofType:type forSaveOperation:NSAutosaveInPlaceOperation completionHandler:^(NSError *error) {
                if (error) {
                    [document setFileURL:nil];
                    [document setFileType:type];
                }
            }];
        });
    } else {
        [document setFileType:type];
    }
}

/* toggleRich: puts up an alert before ultimately calling -setRichText:
*/
- (void)toggleRich:(id)sender {
    Document *document = [self document];
    [document performActivityWithSynchronousWaiting:YES usingBlock:^(void (^activityCompletionHandler)(void)) {

        // What we'll do to cause the document to toggle rich, after maybe showing an alert about loss of information.
        void (^continueTogglingRich)(void) = ^{
            [document autosaveWithImplicitCancellability:NO completionHandler:^(NSError *error) {
                if (!error) {
                    [self toggleRichWithNewFileType:nil];
                }
                activityCompletionHandler();
            }];

        };

        // Check if there is any loss of information, waiting for any previous saves (which might be changing the type) to complete.
        __block BOOL willLoseInformation = NO;
        [document performSynchronousFileAccessUsingBlock:^{
            willLoseInformation = [document toggleRichWillLoseInformation];
        }];
        if (willLoseInformation) {
            NSString *messageText = NSLocalizedString(@"Convert this document to plain text?", @"Title of alert confirming Make Plain Text");
            NSString *defaultButton = NSLocalizedString(@"OK", @"OK");
            NSString *alternateButton = NSLocalizedString(@"Cancel", @"Button choice that allows the user to cancel.");
            NSString *informativeText = NSLocalizedString(@"Making a rich text document plain will lose all text styles (such as fonts and colors), images, attachments, and document properties.", @"Subtitle of alert confirming Make Plain Text");
            NSAlert *alert = [NSAlert alertWithMessageText:messageText defaultButton:defaultButton alternateButton:alternateButton otherButton:nil informativeTextWithFormat:@"%@", informativeText];
            [alert beginSheetModalForWindow:[[self document] windowForSheet] modalDelegate:self didEndSelector:@selector(didEndToggleRichSheet:returnCode:contextInfo:) contextInfo:Block_copy(^(BOOL okToToggleRich){
                if (okToToggleRich) {
                    continueTogglingRich();
                } else {
                    activityCompletionHandler();
                }
            })];
        } else {
            continueTogglingRich();
        }

    }];
}

- (void)didEndToggleRichSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void (^)(BOOL))block {
    block(returnCode == NSAlertDefaultReturn);
    Block_release(block);
}

/* Layout orientation
 */
- (void)toggleLayoutOrientation:(id)sender {
    NSInteger tag = [sender tag];

    if (hasMultiplePages) {
        NSUInteger count = [[[self layoutManager] textContainers] count];

        while (count-- > 1) [self removePage]; // remove 2nd ~ nth pages

        [self setupPagesViewForLayoutOrientation:tag];
    } else {
        [[self firstTextView] setLayoutOrientation:[sender tag]];
    }
}
@end


@implementation DocumentWindowController(Delegation)

/* Window delegation messages */

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)defaultFrame {
    if (!hasMultiplePages) {	// If not wrap-to-page, use the default suggested
        return defaultFrame;
    } else {
        NSRect currentFrame = [window frame];	// Get the current size and location of the window
        NSRect standardFrame;
        NSSize paperSize = [[[self document] printInfo] paperSize];	// Get a frame size that fits the current printable page
        NSRect newScrollView;
	
        // Get a frame for the window content, which is a scrollView
        newScrollView.origin = NSZeroPoint;
        newScrollView.size = [[scrollView class] frameSizeForContentSize:paperSize horizontalScrollerClass:[scrollView hasHorizontalScroller] ? [NSScroller class] : Nil verticalScrollerClass:[scrollView hasVerticalScroller] ? [NSScroller class] : Nil borderType:[scrollView borderType] controlSize:NSRegularControlSize scrollerStyle:NSScrollerStyleLegacy];
	
        // The standard frame for the window is now the frame that will fit the scrollView content
        standardFrame.size = [[window class] frameRectForContentRect:newScrollView styleMask:[window styleMask]].size;
        
        // Set the top left of the standard frame to be the same as that of the current window
        standardFrame.origin.y = NSMaxY(currentFrame) - standardFrame.size.height;
        standardFrame.origin.x = currentFrame.origin.x;
	
        return standardFrame;
    }
}

- (void)windowDidResize:(NSNotification *)notification {
    [[self document] setTransient:NO]; // Since the user has taken an interest in the window, clear the document's transient status
    
    if (!isSettingSize) {   // There is potential for recursion, but typically this is prevented in NSWindow which doesn't call this method if the frame doesn't change. However, just in case...
	isSettingSize = YES;
	NSSize viewSize = [[scrollView class] contentSizeForFrameSize:[scrollView frame].size hasHorizontalScroller:[scrollView hasHorizontalScroller] hasVerticalScroller:[scrollView hasVerticalScroller] borderType:[scrollView borderType]];
	
	if (![[self document] hasMultiplePages]) {
	    viewSize.width -= (defaultTextPadding() * 2.0);
	}
	[[self document] setViewSize:viewSize];
	isSettingSize = NO;
    }
}

- (void)windowDidMove:(NSNotification *)notification {
    [[self document] setTransient:NO]; // Since the user has taken an interest in the window, clear the document's transient status
}

/* Text view delegation messages */

- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex {
    NSURL *linkURL = nil;
    
    if ([link isKindOfClass:[NSURL class]]) {	// Handle NSURL links
        linkURL = link;
    } else if ([link isKindOfClass:[NSString class]]) {	// Handle NSString links
        linkURL = [NSURL URLWithString:link relativeToURL:[[self document] fileURL]];
    }
    if (linkURL) {
        NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
        if ([linkURL isFileURL]) {
	    NSError *error;
            if (![linkURL checkResourceIsReachableAndReturnError:&error]) {	// To be able to present an error panel, see if the file is reachable
                [[self document] performActivityWithSynchronousWaiting:YES usingBlock:^(void (^activityCompletionHandler)(void)) {
                    [[self window] presentError:error modalForWindow:[self window] delegate:self didPresentSelector:@selector(presenterDidPresent:soContinue:) contextInfo:Block_copy(^(BOOL didSucceed) {
                        activityCompletionHandler();
                    })];
                }];
		return YES;
	    } else {
                // Special case: We want to open text types in TextEdit, as presumably that is what was desired
                NSString *typeIdentifier = nil;
                if ([linkURL getResourceValue:&typeIdentifier forKey:NSURLTypeIdentifierKey error:NULL] && typeIdentifier) {
                    BOOL openInTextEdit = NO;
                    for (NSString *textTypeIdentifier in [NSAttributedString textTypes]) {
                        if ([workspace type:typeIdentifier conformsToType:textTypeIdentifier]) {
                            openInTextEdit = YES;
                            break;
                        }
                    }
                    if (openInTextEdit) {
                        if ([[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:linkURL display:YES error:NULL]) return YES;                    
                    }
                }
                // Other file URLs are displayed in Finder
                [workspace activateFileViewerSelectingURLs:[NSArray arrayWithObject:linkURL]];
                return YES;
            }
        } else {
            // Other URLs are simply opened
            if ([workspace openURL:linkURL]) return YES;
        }
    }
    
    // We only get here on failure... Because we beep, we return YES to indicate "success", so the text system does no further processing.
    NSBeep();
    return YES;
}

- (NSURL *)textView:(NSTextView *)textView URLForContentsOfTextAttachment:(NSTextAttachment *)textAttachment atIndex:(NSUInteger)charIndex {
    NSURL *attachmentURL = nil;
    NSString *name = [[textAttachment fileWrapper] filename];

    if (name) {
        Document *document = [self document];
        NSURL *docURL = [document fileURL];

        if (!docURL) docURL = [document autosavedContentsFileURL];

        if (docURL && [docURL isFileURL]) attachmentURL = [docURL URLByAppendingPathComponent:name];
    }
    
    return attachmentURL;
}

- (NSArray *)textView:(NSTextView *)view writablePasteboardTypesForCell:(id <NSTextAttachmentCell>)cell atIndex:(NSUInteger)charIndex {
    NSString *name = [[[cell attachment] fileWrapper] filename];
    NSURL *docURL = [[self document] fileURL];
    return (docURL && [docURL isFileURL] && name) ? [NSArray arrayWithObject:NSFilenamesPboardType] : nil;
}

- (BOOL)textView:(NSTextView *)view writeCell:(id <NSTextAttachmentCell>)cell atIndex:(NSUInteger)charIndex toPasteboard:(NSPasteboard *)pboard type:(NSString *)type {
    NSString *name = [[[cell attachment] fileWrapper] filename];
    NSURL *docURL = [[self document] fileURL];
    if ([type isEqualToString:NSFilenamesPboardType] && name && [docURL isFileURL]) {
	NSString *docPath = [docURL path];
	NSString *pathToAttachment = [docPath stringByAppendingPathComponent:name];
        if (pathToAttachment) {
	    [pboard setPropertyList:[NSArray arrayWithObject:pathToAttachment] forType:NSFilenamesPboardType];
	    return YES;
	}
    }
    return NO;
}

/* Layout manager delegation message */

- (void)layoutManager:(NSLayoutManager *)layoutManager didCompleteLayoutForTextContainer:(NSTextContainer *)textContainer atEnd:(BOOL)layoutFinishedFlag {
    if (hasMultiplePages) {
        MultiplePageView *pagesView = [scrollView documentView];
        NSArray *containers = [layoutManager textContainers];
	
        if (!layoutFinishedFlag || (textContainer == nil)) {
            // Either layout is not finished or it is but there are glyphs laid nowhere.
            NSTextContainer *lastContainer = [containers lastObject];
	    
            if ((textContainer == lastContainer) || (textContainer == nil)) {
                // Add a new page if the newly full container is the last container or the nowhere container.
                // Do this only if there are glyphs laid in the last container (temporary solution for 3729692, until AppKit makes something better available.)
                if ([layoutManager glyphRangeForTextContainer:lastContainer].length > 0) {
                    [self addPage];
                    if (NSTextLayoutOrientationVertical == [pagesView layoutOrientation]) [self updateTextViewGeometry];
                }
            }
        } else {
            // Layout is done and it all fit.  See if we can axe some pages.
            NSUInteger lastUsedContainerIndex = [containers indexOfObjectIdenticalTo:textContainer];
            NSUInteger numContainers = [containers count];
            while (++lastUsedContainerIndex < numContainers) {
                [self removePage];
            }
            
            if (NSTextLayoutOrientationVertical == [pagesView layoutOrientation]) [self updateTextViewGeometry];

            [[self document] setOriginalOrientationSections:nil];
        }
    }
}


- (void)pluginMenuItemCalledAction:(id)sender {
    
    id <TextEditPlugin>plugin = [sender representedObject];
    
    [plugin actionCalledWithTextView:[self firstTextView] inDocument:[self document]];
    
}

@end


@implementation DocumentWindowController(NSMenuValidation)

- (BOOL)validateMenuItem:(NSMenuItem *)aCell {
    SEL action = [aCell action];
    if (action == @selector(toggleRich:)) {
	validateToggleItem(aCell, [[self document] isRichText], NSLocalizedString(@"&Make Plain Text", @"Menu item to make the current document plain text"), NSLocalizedString(@"&Make Rich Text", @"Menu item to make the current document rich text"));
        if ([[self document] isReadOnly]) return NO;
    } else if (action == @selector(chooseAndAttachFiles:)) {
        return [[self document] isRichText] && ![[self document] isReadOnly];
    } else if (action == @selector(toggleLayoutOrientation:)) {
        NSString *title = nil;
        NSTextLayoutOrientation orientation = [[self firstTextView] layoutOrientation];;

        if (NSTextLayoutOrientationHorizontal == orientation) {
            title = NSLocalizedString(@"Make Layout Vertical", @"Menu item ot make the current document layout vertical");
            orientation = NSTextLayoutOrientationVertical;
        } else {
            title = NSLocalizedString(@"Make Layout Horizontal", @"Menu item ot make the current document layout horizontal");
            orientation = NSTextLayoutOrientationHorizontal;
        }

        [aCell setTitle:title];
        [aCell setTag:orientation];

        if ([[self document] isReadOnly]) return NO;
    }
    return YES;
}

- (NSMenu *)textView:(NSTextView *)view menu:(NSMenu *)menu forEvent:(NSEvent *)event atIndex:(NSUInteger)charIndex {
    // Removing layout orientation menu item in multipage mode for enforcing the document-wide setting
    if (hasMultiplePages) {
        [[menu itemArray] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            BOOL remove = NO;
            if ([obj action] == @selector(changeLayoutOrientation:)) {
                remove = YES;
            } else {
                NSMenu *submenu = [obj submenu];

                if (submenu) {
                    [[submenu itemArray] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        if ([obj action] == @selector(changeLayoutOrientation:)) [submenu removeItem:obj];
                    }];
                    if (0 == [submenu numberOfItems]) remove = YES;
                }
            }

            if (remove) {
                [menu removeItem:obj];
                *stop = YES;
            }
        }];
    }
    return menu;
}
@end


@implementation NSTextView (TextEditAdditions)

/* This method causes the text to be laid out in the foreground (approximately) up to the indicated character index.  Note that since we are adding a category on a system framework, we are prefixing the method with "textEdit" to greatly reduce chance of any naming conflict.
*/
- (void)textEditDoForegroundLayoutToCharacterIndex:(NSUInteger)loc {
    NSUInteger len;
    if (loc > 0 && (len = [[self textStorage] length]) > 0) {
        NSRange glyphRange;
        if (loc >= len) loc = len - 1;
        /* Find out which glyph index the desired character index corresponds to */
        glyphRange = [[self layoutManager] glyphRangeForCharacterRange:NSMakeRange(loc, 1) actualCharacterRange:NULL];
        if (glyphRange.location > 0) {
            /* Now cause layout by asking a question which has to determine where the glyph is */
            (void)[[self layoutManager] textContainerForGlyphAtIndex:glyphRange.location - 1 effectiveRange:NULL];
        }
    }
}

@end



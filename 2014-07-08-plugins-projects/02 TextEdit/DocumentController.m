
/*
     File: DocumentController.m
 Abstract: NSDocumentController subclass for TextEdit.
 Required to support transient documents and customized Open panel.
 
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

#import "DocumentController.h"
#import "Document.h"
#import "EncodingManager.h"
#import "TextEditDefaultsKeys.h"
#import "TextEditErrors.h"

/* A very simple container class which is used to collect the outlets from loading the encoding accessory.  No implementation provided, because all of the references are weak and don't need retain/release.  Would be nice to be able to switch to a mutable dictionary here at some point.
*/
@interface OpenSaveAccessoryOwner : NSObject {
@public
    IBOutlet NSView *accessoryView;
    IBOutlet NSPopUpButton *encodingPopUp;
    IBOutlet NSButton *checkBox;
}
@end

@implementation OpenSaveAccessoryOwner
@end

@implementation DocumentController

- (void)awakeFromNib {
    [self bind:@"autosavingDelay" toObject:[NSUserDefaultsController sharedUserDefaultsController] withKeyPath:@"values." AutosavingDelay options:nil];
    customOpenSettings = [[NSMutableDictionary alloc] init];
    transientDocumentLock = [[NSLock alloc] init];
    displayDocumentLock = [[NSLock alloc] init];
}

- (void)dealloc {
    [self unbind:@"autosavingDelay"];
    [customOpenSettings release];
    [transientDocumentLock release];
    [displayDocumentLock release];
    [super dealloc];
}

/* Create a new document of the default type and initialize its contents from the pasteboard. 
*/
- (Document *)openDocumentWithContentsOfPasteboard:(NSPasteboard *)pb display:(BOOL)display error:(NSError **)error {
    // Read type and attributed string.
    NSString *pasteboardType = [pb availableTypeFromArray:[NSAttributedString readableTypesForPasteboard:pb]];
    NSData *data = [pb dataForType:pasteboardType];
    NSAttributedString *string = nil;
    NSString *type = nil;

    if (data != nil) {
        NSDictionary *attributes = nil;
        string = [[[NSAttributedString alloc] initWithData:data options:nil documentAttributes:&attributes error:error] autorelease];
    
        // We only expect to see plain-text, RTF, and RTFD at this point.
        NSString *docType = [attributes objectForKey:NSDocumentTypeDocumentAttribute];
        if ([docType isEqualToString:NSPlainTextDocumentType]) {
            type = (NSString *)kUTTypeText;
        } else if ([docType isEqualToString:NSRTFTextDocumentType]) {
            type = (NSString *)kUTTypeRTF;
        } else if ([docType isEqualToString:NSRTFDTextDocumentType]) {
            type = (NSString *)kUTTypeRTFD;
        }
    }
    
    if (string != nil && type != nil) {
	Class docClass = [self documentClassForType:type];
        
        if (docClass != nil) {
            Document *transientDoc = nil;
            
            [transientDocumentLock lock];
            transientDoc = [self transientDocumentToReplace];
            if (transientDoc) {
                // If this document has claimed the transient document, cause -transientDocumentToReplace to return nil for all other documents.
                [transientDoc setTransient:NO];
            }
            [transientDocumentLock unlock];
            
            id doc = [[[docClass alloc] initWithType:type error:error] autorelease];
            if (!doc) return nil; // error has been set
            
            NSTextStorage *text = [doc textStorage];
            [text replaceCharactersInRange:NSMakeRange(0, [text length]) withAttributedString:string];
            if ([type isEqualToString:(NSString *)kUTTypeText]) [doc applyDefaultTextAttributes:NO];
            
            [self addDocument:doc];
            [doc updateChangeCount:NSChangeReadOtherContents];
            
            if (transientDoc) [self replaceTransientDocument:[NSArray arrayWithObjects:transientDoc, doc, nil]];
            if (display) [self displayDocument:doc];
            
            return doc;
        }
    }
    
    // Either we could not read data from pasteboard, or the data was interpreted with a type we don't understand.
    if ((data == nil || (string != nil && type == nil)) && error) *error = [NSError errorWithDomain:TextEditErrorDomain code:TextEditOpenDocumentWithSelectionServiceFailed userInfo:[
            NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"Service failed. Couldn\\U2019t open the selection.", @"Title of alert indicating error during 'New Window Containing Selection' service"), NSLocalizedDescriptionKey,
            NSLocalizedString(@"There might be an internal error or a performance problem, or the source application may be providing text of invalid type in the service request. Please try the operation a second time. If that doesn\\U2019t work, copy/paste the selection into TextEdit.", @"Recommendation when 'New Window Containing Selection' service fails"), NSLocalizedRecoverySuggestionErrorKey,
            nil]];

    return nil;
}

/* This method is overridden in order to support transient documents, i.e. the automatic closing of an automatically created untitled document, when a real document is opened. 
*/
- (id)openUntitledDocumentAndDisplay:(BOOL)displayDocument error:(NSError **)outError {
    Document *doc = [super openUntitledDocumentAndDisplay:displayDocument error:outError];
    
    if (!doc) return nil;
    
    if ([[self documents] count] == 1) {
        // Determine whether this document might be a transient one
        // Check if there is a current AppleEvent. If there is, check whether it is an open or reopen event. In that case, the document being created is transient.
        NSAppleEventDescriptor *evtDesc = [[NSAppleEventManager sharedAppleEventManager] currentAppleEvent];
        AEEventID evtID = [evtDesc eventID];
        
        if (evtDesc && (evtID == kAEReopenApplication || evtID == kAEOpenApplication) && [evtDesc eventClass] == kCoreEventClass) {
            [doc setTransient:YES];
        }
    }
    
    return doc;
}

- (Document *)transientDocumentToReplace {
    NSArray *documents = [self documents];
    Document *transientDoc = nil;
    return ([documents count] == 1 && [(transientDoc = [documents objectAtIndex:0]) isTransientAndCanBeReplaced]) ? transientDoc : nil;
}

- (void)displayDocument:(NSDocument *)doc {
    // Documents must be displayed on the main thread.
    if ([NSThread isMainThread]) {
        [doc makeWindowControllers];
        [doc showWindows];
    } else {
        [self performSelectorOnMainThread:_cmd withObject:doc waitUntilDone:YES];
    }
}

- (void)replaceTransientDocument:(NSArray *)documents {
    // Transient document must be replaced on the main thread, since it may undergo automatic display on the main thread.
    if ([NSThread isMainThread]) {
        NSDocument *transientDoc = [documents objectAtIndex:0], *doc = [documents objectAtIndex:1];
        NSArray *controllersToTransfer = [[transientDoc windowControllers] copy];
        NSEnumerator *controllerEnum = [controllersToTransfer objectEnumerator];
        NSWindowController *controller;
        
        [controllersToTransfer makeObjectsPerformSelector:@selector(retain)];
        
        while (controller = [controllerEnum nextObject]) {
            [doc addWindowController:controller];
            [transientDoc removeWindowController:controller];
        }
        [transientDoc close];
        
        [controllersToTransfer makeObjectsPerformSelector:@selector(release)];
        [controllersToTransfer release];
	
	// We replaced the value of the transient document with opened document, need to notify accessibility clients.
	for (NSLayoutManager *layoutManager in [[(Document *)doc textStorage] layoutManagers]) {
	    for (NSTextContainer *textContainer in [layoutManager textContainers]) {
		NSTextView *textView = [textContainer textView];
		if (textView) NSAccessibilityPostNotification(textView, NSAccessibilityValueChangedNotification);
	    }
	}
	
    } else {
        [self performSelectorOnMainThread:_cmd withObject:documents waitUntilDone:YES];
    }
}

/* When a document is opened, check to see whether there is a document that is already open, and whether it is transient. If so, transfer the document's window controllers and close the transient document. When +[Document canConcurrentlyReadDocumentsOfType:] return YES, this method may be invoked on multiple threads. Ensure that only one document replaces the transient document. The transient document must be replaced before any other documents are displayed for window cascading to work correctly. To guarantee this, defer all display operations until the transient document has been replaced.
*/
- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL display:(BOOL)displayDocument error:(NSError **)outError {
    Document *transientDoc = nil;
    
    [transientDocumentLock lock];
    transientDoc = [self transientDocumentToReplace];
    if (transientDoc) {
        // Once this document has claimed the transient document, cause -transientDocumentToReplace to return nil for all other documents.
        [transientDoc setTransient:NO];
        deferredDocuments = [[NSMutableArray alloc] init];
    }
    [transientDocumentLock unlock];
    
    // Don't make NSDocumentController display the NSDocument it creates. Instead, do it later manually to ensure that the transient document has been replaced first.
    Document *doc = [super openDocumentWithContentsOfURL:absoluteURL display:NO error:outError];
    
    [customOpenSettings removeObjectForKey:absoluteURL];
    
    if (transientDoc) {
        if (doc) {
            [self replaceTransientDocument:[NSArray arrayWithObjects:transientDoc, doc, nil]];
            if (displayDocument) [self displayDocument:doc];
        }
        
        // Now that the transient document has been replaced, display all deferred documents.
        [displayDocumentLock lock];
        NSArray *documentsToDisplay = deferredDocuments;
        deferredDocuments = nil;
        [displayDocumentLock unlock];
        for (NSDocument *document in documentsToDisplay) [self displayDocument:document];
        [documentsToDisplay release];
    } else if (doc && displayDocument) {
        [displayDocumentLock lock];
        if (deferredDocuments) {
            // Defer displaying this document, because the transient document has not yet been replaced.
            [deferredDocuments addObject:doc];
            [displayDocumentLock unlock];
        } else {
            // The transient document has been replaced, so display the document immediately.
            [displayDocumentLock unlock];
            [self displayDocument:doc];
        }
    }
    
    return doc;
}

/* When a second document is added, the first document's transient status is cleared. This happens when the user selects "New" when a transient document already exists. 
*/
- (void)addDocument:(NSDocument *)newDoc {
    Document *firstDoc;
    NSArray *documents = [self documents];
    if ([documents count] == 1 && (firstDoc = [documents objectAtIndex:0]) && [firstDoc isTransient]) {
        [firstDoc setTransient:NO];
    }
    [super addDocument:newDoc];
}

/* Loads the "encoding" accessory view used in save plain and open panels. There is a checkbox in the accessory which has different purposes in each case; so we let the caller set the title and other info for that checkbox.
*/
+ (NSView *)encodingAccessory:(NSStringEncoding)encoding includeDefaultEntry:(BOOL)includeDefaultItem encodingPopUp:(NSPopUpButton **)popup checkBox:(NSButton **)button {
    OpenSaveAccessoryOwner *owner = [[[OpenSaveAccessoryOwner alloc] init] autorelease];
    // Rather than caching, load the accessory view everytime, as it might appear in multiple panels simultaneously.
    if (![[NSBundle mainBundle] loadNibNamed:@"EncodingAccessory" owner:owner topLevelObjects:NULL])  {
        NSLog(@"Failed to load EncodingAccessory.nib");
        return nil;
    }
    if (popup) *popup = owner->encodingPopUp;
    if (button) *button = owner->checkBox;
    [[EncodingManager sharedInstance] setupPopUpCell:[owner->encodingPopUp cell] selectedEncoding:encoding withDefaultEntry:includeDefaultItem];
    return owner->accessoryView;
}

/* Overridden to add an accessory view to the open panel. This method is called for both modal and non-modal invocations.
*/
- (void)beginOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)types completionHandler:(void (^)(NSInteger result))completionHandler {
    NSButton *ignoreRichTextButton;
    NSPopUpButton *encodingPopUp;

    BOOL ignoreHTMLOrig = [[NSUserDefaults standardUserDefaults] boolForKey:IgnoreHTML];
    BOOL ignoreRichOrig = [[NSUserDefaults standardUserDefaults] boolForKey:IgnoreRichText];
    NSView *accessoryView = [[self class] encodingAccessory:[[[NSUserDefaults standardUserDefaults] objectForKey:PlainTextEncodingForRead] unsignedIntegerValue] includeDefaultEntry:YES encodingPopUp:&encodingPopUp checkBox:&ignoreRichTextButton];
    accessoryView.translatesAutoresizingMaskIntoConstraints = NO;
    [openPanel setAccessoryView:accessoryView];
    [ignoreRichTextButton setTitle:NSLocalizedString(@"Ignore rich text commands", @"Checkbox indicating that when opening a rich text file, the rich text should be ignored (causing the file to be loaded as plain text)")];
    [ignoreRichTextButton setToolTip:NSLocalizedString(@"If selected, HTML and RTF files will be loaded as plain text, allowing you to see and edit the HTML or RTF directives.", @"Tooltip for checkbox indicating that when opening a rich text file, the rich text should be ignored (causing the file to be loaded as plain text)")];
    if (ignoreRichOrig != ignoreHTMLOrig) {
	[ignoreRichTextButton setAllowsMixedState:YES];
	[ignoreRichTextButton setState:NSMixedState];
    } else {
	if ([ignoreRichTextButton allowsMixedState]) [ignoreRichTextButton setAllowsMixedState:NO];
	[ignoreRichTextButton setState:ignoreRichOrig ? NSOnState : NSOffState];
    }

    [super beginOpenPanel:openPanel forTypes:types completionHandler:^(NSInteger result) {
        if (result == NSOKButton) {
            BOOL ignoreHTML = ignoreHTMLOrig;
            BOOL ignoreRich = ignoreRichOrig;
            NSUInteger encoding = (NSStringEncoding)[[[encodingPopUp selectedItem] representedObject] unsignedIntegerValue];
            NSInteger ignoreState = [ignoreRichTextButton state];
            if (ignoreState != NSMixedState) {  // Mixed state indicates they were different, and to leave them alone
                ignoreHTML = ignoreRich = (ignoreState == NSOnState);
            }
            NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger:encoding], PlainTextEncodingForRead, [NSNumber numberWithBool:ignoreHTML], IgnoreHTML, [NSNumber numberWithBool:ignoreRich], IgnoreRichText, nil];
            for (NSURL *url in [openPanel URLs]) {
                [customOpenSettings setObject:options forKey:url];
            }
        }
        completionHandler(result);
    }];
    
}

- (NSStringEncoding)lastSelectedEncodingForURL:(NSURL *)url {
    NSDictionary *options = [customOpenSettings objectForKey:url];
    return options ? [[options objectForKey:PlainTextEncodingForRead] unsignedIntegerValue] : [[[NSUserDefaults standardUserDefaults] objectForKey:PlainTextEncodingForRead] unsignedIntegerValue];
}

- (BOOL)lastSelectedIgnoreHTMLForURL:(NSURL *)url {
    NSDictionary *options = [customOpenSettings objectForKey:url];
    return options ? [[options objectForKey:IgnoreHTML] unsignedIntegerValue] : [[NSUserDefaults standardUserDefaults] boolForKey:IgnoreHTML];;
}

- (BOOL)lastSelectedIgnoreRichForURL:(NSURL *)url {
    NSDictionary *options = [customOpenSettings objectForKey:url];
    return options ? [[options objectForKey:IgnoreRichText] unsignedIntegerValue] : [[NSUserDefaults standardUserDefaults] boolForKey:IgnoreRichText];
}

/* The user can change the default document type between Rich and Plain in Preferences. We override
   -defaultType to return the appropriate type string. 
*/
- (NSString *)defaultType {
    return (NSString *)([[NSUserDefaults standardUserDefaults] boolForKey:RichText] ? kUTTypeRTF : kUTTypeText);
}

@end

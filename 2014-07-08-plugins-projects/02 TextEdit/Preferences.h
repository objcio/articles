
/*
     File: Preferences.h
 Abstract: Preferences controller, subclass of NSWindowController. Since the switch to a bindings-based preferences interface, the class has become a lot simpler; its only duties now are to manage the user fonts for rich and plain text documents, translate HTML saving options from backwards-compatible defaults values into pop-up menu item tags, and revert everything to the initial defaults if the user so chooses.
 
 The Preferences instance also acts as a delegate for the window, in order to validate edits before it closes, and for the two text fields bound to the window size in characters, so that invalid entries trigger a reset to a field's previous value.
 
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

enum {
    HTMLDocumentTypeOptionUseTransitional = (1 << 0),
    HTMLDocumentTypeOptionUseXHTML = (1 << 1)
};
typedef NSUInteger HTMLDocumentTypeOptions;

enum {
    HTMLStylingUseEmbeddedCSS = 0,
    HTMLStylingUseInlineCSS = 1,
    HTMLStylingUseNoCSS = 2
};
typedef NSInteger HTMLStylingMode;

@interface Preferences : NSWindowController {
    BOOL changingRTFFont;
    NSInteger originalDimensionFieldValue;
}
- (IBAction)revertToDefault:(id)sender;    

- (IBAction)changeRichTextFont:(id)sender;	/* Request to change the rich text font */
- (IBAction)changePlainTextFont:(id)sender;	/* Request to change the plain text font */
- (void)changeFont:(id)fontManager;	/* Sent by the font manager */

- (NSFont *)richTextFont;
- (void)setRichTextFont:(NSFont *)newFont;
- (NSFont *)plainTextFont;
- (void)setPlainTextFont:(NSFont *)newFont;

@end

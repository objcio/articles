
/*
     File: PrintPanelAccessoryController.m
 Abstract: PrintPanelAccessoryController is a subclass of NSViewController demonstrating how to add an accessory view to the print panel.
 
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

#import "PrintPanelAccessoryController.h"
#import "TextEditDefaultsKeys.h"


@implementation PrintPanelAccessoryController

@synthesize showsWrappingToFit, wrappingToFit;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    // We override the designated initializer, ignoring the nib since we need our own
    return [super initWithNibName:@"PrintPanelAccessory" bundle:nibBundleOrNil];
}

/* The first time the printInfo is supplied, initialize the value of the pageNumbering setting from defaults
 */
- (void)setRepresentedObject:(id)printInfo {
    [super setRepresentedObject:printInfo];
    // We don't bind to NSUserDefaults since we don't want changes while one panel is up to affect other panels that may be up
    self.pageNumbering = [[NSUserDefaults standardUserDefaults] boolForKey:NumberPagesWhenPrinting];
    self.wrappingToFit = [[NSUserDefaults standardUserDefaults] boolForKey:WrapToFitWhenPrinting];
    [self addObserver:self forKeyPath:@"pageNumbering" options:0 context:NULL];
    [self addObserver:self forKeyPath:@"wrappingToFit" options:0 context:NULL];
}

- (void)dealloc {
    if (self.representedObject) {   // If setRepresentedObject: wasn't called, no observers, so don't attempt to remove
        [self removeObserver:self forKeyPath:@"pageNumbering"];
        [self removeObserver:self forKeyPath:@"wrappingToFit"];
    }
    [super dealloc];
}

/* The values are sticky, so write them out to defaults when they change
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqual:@"pageNumbering"]) {
        [[NSUserDefaults standardUserDefaults] setBool:self.pageNumbering forKey:NumberPagesWhenPrinting];
    } else if ([keyPath isEqual:@"wrappingToFit"]) {
        [[NSUserDefaults standardUserDefaults] setBool:self.wrappingToFit forKey:WrapToFitWhenPrinting];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

/* We don't use a instance variable to store pageNumbering, but instead get/set it in the printInfo. Hence we need custom accessors.
 */
- (void)setPageNumbering:(BOOL)flag {
    NSPrintInfo *printInfo = [self representedObject];
    [[printInfo dictionary] setObject:[NSNumber numberWithBool:flag] forKey:NSPrintHeaderAndFooter];
}

- (BOOL)pageNumbering {
    NSPrintInfo *printInfo = [self representedObject];
    return [[[printInfo dictionary] objectForKey:NSPrintHeaderAndFooter] boolValue];
}

- (NSSet *)keyPathsForValuesAffectingPreview {
    return [NSSet setWithObjects:@"pageNumbering", @"wrappingToFit", nil];
}

/* This enables TextEdit-specific settings to be displayed in the Summary pane of the print panel.
*/
- (NSArray *)localizedSummaryItems {
    NSMutableArray *items = [NSMutableArray array];
    [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                      NSLocalizedStringFromTable(@"Header and Footer", @"PrintAccessory", @"Print panel summary item title for whether header and footer (page number, date, document title) should be printed"), NSPrintPanelAccessorySummaryItemNameKey,
                      [self pageNumbering] ? NSLocalizedStringFromTable(@"On", @"PrintAccessory", @"Print panel summary value for feature that is enabled") : NSLocalizedStringFromTable(@"Off", @"PrintAccessory", @"Print panel summary value for feature that is disabled"), NSPrintPanelAccessorySummaryItemDescriptionKey,
                      nil]];
    // We add the "Rewrap to fit page" item to the summary only if the item is settable (which it isn't, for "wrap-to-page" mode)
    if ([self showsWrappingToFit]) [items addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     NSLocalizedStringFromTable(@"Rewrap to fit page", @"PrintAccessory", @"Print panel summary item title for whether document contents should be rewrapped to fit the page"), NSPrintPanelAccessorySummaryItemNameKey,
                                                     [self wrappingToFit] ? NSLocalizedStringFromTable(@"On", @"PrintAccessory", @"Print panel summary value for feature that is enabled") : NSLocalizedStringFromTable(@"Off", @"PrintAccessory", @"Print panel summary value for feature that is disabled"), NSPrintPanelAccessorySummaryItemDescriptionKey,
                                                     nil]];
    return items;
}

@end

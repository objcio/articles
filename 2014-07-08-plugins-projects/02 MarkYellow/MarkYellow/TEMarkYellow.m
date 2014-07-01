//
//  TEMarkYellow.m
//  MarkYellow
//
//  Created by August Mueller on 6/14/14.
//  Copyright (c) 2014 August Mueller. All rights reserved.
//

#import "TEMarkYellow.h"
#import "TEPluginManagerInterface.h"

#define debug NSLog

@implementation TEMarkYellow

- (void)pluginDidLoad:(id <TEPluginManager>)pluginManager {
    
    [pluginManager addPluginsMenuWithTitle:@"Mark Selected Text Yellow"
                                    target:self
                                    action:@selector(changeTextColor:inDocument:userObject:)
                             keyEquivalent:@""
                 keyEquivalentModifierMask:0
                                userObject:[NSColor yellowColor]];
    
    [pluginManager addPluginsMenuWithTitle:@"Mark Selected Text Blue"
                                    target:self
                                    action:@selector(changeTextColor:inDocument:userObject:)
                             keyEquivalent:@""
                 keyEquivalentModifierMask:0
                                userObject:[NSColor blueColor]];
    
    [pluginManager addPluginsMenuWithTitle:@"Run Selected Text as AppleScript"
                                    target:self
                                    action:@selector(runTextAsAppleScript:inDocument:userObject:)
                             keyEquivalent:@""
                 keyEquivalentModifierMask:0
                                userObject:nil];
    
}

- (void)changeTextColor:(NSTextView*)textView inDocument:(id)document userObject:(NSColor*)color {
    if ([textView selectedRange].length) {
        
        NSMutableAttributedString *ats = [[[textView textStorage] attributedSubstringFromRange:[textView selectedRange]] mutableCopy];
        
        [ats addAttribute:NSBackgroundColorAttributeName value:color range:NSMakeRange(0, [ats length])];
        
        // By asking the text view if we can change the text first, it will automatically do the right thing to enable undoing of attribute changes
        if ([textView shouldChangeTextInRange:[textView selectedRange] replacementString:[ats string]]) {
            [[textView textStorage] replaceCharactersInRange:[textView selectedRange] withAttributedString:ats];
            [textView didChangeText];
        }
    }
}

- (void)runTextAsAppleScript:(NSTextView*)textView inDocument:(id)document userObject:(id)userObject {
    
    if ([textView selectedRange].length) {
        
        NSString *s = [[[textView textStorage] string] substringWithRange:[textView selectedRange]];
        
        NSAppleScript *as = [[NSAppleScript alloc] initWithSource:s];
        NSDictionary *outDict;
        if (![as executeAndReturnError:&outDict]) {
            NSLog(@"Error: %@", outDict);
        }
    }
    
}



@end

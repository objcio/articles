//
//  TEMarkYellow.m
//  MarkYellow
//
//  Created by August Mueller on 6/14/14.
//  Copyright (c) 2014 August Mueller. All rights reserved.
//

#import "TEMarkYellow.h"

#define debug NSLog

@implementation TEMarkYellow

- (NSString*)menuItemTitle {
    return @"Mark Selected Text Yellow";
}

- (void)actionCalledWithTextView:(NSTextView*)textView inDocument:(id)document {
    if ([textView selectedRange].length) {
        
        NSMutableAttributedString *ats = [[[textView textStorage] attributedSubstringFromRange:[textView selectedRange]] mutableCopy];
        
        [ats addAttribute:NSBackgroundColorAttributeName value:[NSColor yellowColor] range:NSMakeRange(0, [ats length])];
        
        // By asking the text view if we can change the text first, it will automatically do the right thing to enable undoing of attribute changes
        if ([textView shouldChangeTextInRange:[textView selectedRange] replacementString:[ats string]]) {
            [[textView textStorage] replaceCharactersInRange:[textView selectedRange] withAttributedString:ats];
            [textView didChangeText];
        }
    }
}

@end

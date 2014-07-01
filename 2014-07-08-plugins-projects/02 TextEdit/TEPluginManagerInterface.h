//
//  PluginManager.h
//  TextEdit
//
//  Created by August Mueller on 6/23/14.
//
//

#import <Foundation/Foundation.h>

@protocol TEPluginManager <NSObject>


- (BOOL)addPluginsMenuWithTitle:(NSString*)menuTitle
                         target:(id)target
                         action:(SEL)selector
                  keyEquivalent:(NSString*)keyEquivalent
      keyEquivalentModifierMask:(NSUInteger)mask
                     userObject:(id)userObject;

@end

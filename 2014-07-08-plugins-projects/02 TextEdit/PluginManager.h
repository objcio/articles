//
//  PluginManager.h
//  TextEdit
//
//  Created by August Mueller on 6/23/14.
//
//

#import <Foundation/Foundation.h>
#import "TEPluginManagerInterface.h"

@interface PluginManager : NSObject <TEPluginManager>

- (void)loadPlugins;

@end

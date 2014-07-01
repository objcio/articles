//
//  PluginManager.m
//  TextEdit
//
//  Created by August Mueller on 6/23/14.
//
//

#import "PluginManager.h"
#import "TextEditMisc.h"
#import "PluginTarget.h"

@interface PluginManager ()
@property (retain) NSMenu *pMenu;
@end

@implementation PluginManager

- (BOOL)addPluginsMenuWithTitle:(NSString*)menuTitle
                         target:(id)target
                         action:(SEL)selector
                  keyEquivalent:(NSString*)keyEquivalent
      keyEquivalentModifierMask:(NSUInteger)mask
                     userObject:(id)userObject
{
    if (!keyEquivalent) {
        keyEquivalent = @"";
    }
    
    NSMenuItem *item = [[self pluginsMenu] addItemWithTitle:menuTitle action:@selector(pluginMenuItemCalledAction:) keyEquivalent:keyEquivalent];
    
    [item setKeyEquivalentModifierMask:mask];
    
    PluginTarget *t = [[PluginTarget new] autorelease];
    
    [t setUserObject:userObject];
    [t setTarget:target];
    [t setAction:selector];
    
    [item setRepresentedObject:t];
    
    return YES;
}

- (NSMenu*)pluginsMenu {
    if (_pMenu) {
        return _pMenu;
    }
    
    NSMenuItem *pluginsMenuItem = [[NSMenuItem alloc] init];
    _pMenu = [[NSMenu alloc] initWithTitle:@"Plug-ins"];
    [pluginsMenuItem setTitle:@"Plug-ins"];
    [pluginsMenuItem setSubmenu:_pMenu];
    
    // Insert this guy right after the View menu.
    [[NSApp mainMenu] insertItem:pluginsMenuItem atIndex:5];
    
    return _pMenu;
}


- (NSString *)pluginsFolder {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    
    if ([paths count] > 0) {
        
        NSString *appSupport    = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Application Support"];
        NSString *appDir        = [appSupport stringByAppendingPathComponent:@"Text Edit"];
        NSString *pluginsFolder = [appDir stringByAppendingPathComponent:@"Plug-Ins"];
        
        NSError *err = nil;
        if (![fm fileExistsAtPath:pluginsFolder]) {
            if (![fm createDirectoryAtPath:pluginsFolder withIntermediateDirectories:YES attributes:nil error:&err]) {
                NSLog(@"I could not create the directory %@", appDir);
                NSLog(@"err: %@", err);
                return nil;
            }
        }
        
        return pluginsFolder;
    }
    
    return nil;
}


- (void)loadPlugins {
    
    NSString *pluginsFolder = [self pluginsFolder];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSError *outErr;
    for (NSString *item in [fm contentsOfDirectoryAtPath:pluginsFolder error:&outErr]) {
        
        if (![item hasSuffix:@".bundle"]) {
            continue;
        }
        
        NSString *bundlePath = [pluginsFolder stringByAppendingPathComponent:item];
        
        NSBundle *b = [NSBundle bundleWithPath:bundlePath];
        
        if (!b) {
            NSLog(@"Could not make a bundle from %@", bundlePath);
            continue;
        }
        
        id <TextEditPlugin> plugin = [[b principalClass] new];
        
        [plugin pluginDidLoad:self];
        
    }
    
    [self sortMenu];
}

- (void)sortMenu {
    
    NSMutableArray *menuItems = [NSMutableArray array];
    
    for (NSMenuItem *item in [[self pluginsMenu] itemArray]) {
        [menuItems addObject:item];
    }
    
    [menuItems sortUsingComparator:^NSComparisonResult(NSMenuItem *a, NSMenuItem *b) {
        return [[a title] caseInsensitiveCompare:[b title]];
    }];
    
    [[self pluginsMenu] removeAllItems];
    
    for (NSMenuItem *item in menuItems) {
        [[self pluginsMenu] addItem:item];
    }
    
}

@end

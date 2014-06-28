//
//  PluginTarget.h
//  TextEdit
//
//  Created by August Mueller on 6/23/14.
//
//

#import <Foundation/Foundation.h>

@interface PluginTarget : NSObject

@property (assign) SEL action;
@property (retain) id target;
@property (retain) id userObject;


@end

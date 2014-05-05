//
//  ClockFace.m
//  ClockFace
//
//  Created by Nick Lockwood on 28/04/2014.
//  Copyright (c) 2014 Charcoal Design. All rights reserved.
//

#import "ClockFace.h"


@implementation ClockFace

@dynamic time;

- (id)init
{
    if ((self = [super init]))
    {
        self.bounds = CGRectMake(0, 0, 200, 200);
        [self setNeedsDisplay];
    }
    return self;
}

+ (BOOL)needsDisplayForKey:(NSString *)key
{
    if ([@"time" isEqualToString:key])
    {
        return YES;
    }
    return [super needsDisplayForKey:key];
}

- (id<CAAction>)actionForKey:(NSString *)key
{
    if ([key isEqualToString:@"time"])
    {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:key];
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        animation.fromValue = @([[self presentationLayer] time]);
        return animation;
    }
    return [super actionForKey:key];
}

- (void)display
{
    NSLog(@"time: %f", [self.presentationLayer time]);
    
    //get interpolated time value
    float time = [self.presentationLayer time];
    
    //create drawing context
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    //draw clock face
    CGContextSetLineWidth(ctx, 4);
    CGContextStrokeEllipseInRect(ctx, CGRectInset(self.bounds, 2, 2));
    
    //draw hour hand
    CGFloat angle = time / 12.0 * 2.0 * M_PI;
    CGPoint center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
    CGContextSetLineWidth(ctx, 4);
    CGContextMoveToPoint(ctx, center.x, center.y);
    CGContextAddLineToPoint(ctx, center.x + sin(angle) * 80, center.y - cos(angle) * 80);
    CGContextStrokePath(ctx);
    
    //draw minute hand
    angle = (time - floor(time)) * 2.0 * M_PI;
    CGContextSetLineWidth(ctx, 2);
    CGContextMoveToPoint(ctx, center.x, center.y);
    CGContextAddLineToPoint(ctx, center.x + sin(angle) * 90, center.y - cos(angle) * 90);
    CGContextStrokePath(ctx);
    
    //set backing image
    self.contents = (id)UIGraphicsGetImageFromCurrentImageContext().CGImage;
    UIGraphicsEndImageContext();
}
      
@end
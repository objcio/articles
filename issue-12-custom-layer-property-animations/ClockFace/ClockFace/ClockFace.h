//
//  ClockFace.h
//  ClockFace
//
//  Created by Nick Lockwood on 28/04/2014.
//  Copyright (c) 2014 Charcoal Design. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>


@interface ClockFace: CAShapeLayer

@property (nonatomic, strong) NSDate *time;

@end


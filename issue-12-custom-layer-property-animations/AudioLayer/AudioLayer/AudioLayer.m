//
//  AudioLayer.m
//  AudioLayer
//
//  Created by Nick Lockwood on 29/04/2014.
//  Copyright (c) 2014 Charcoal Design. All rights reserved.
//

#import "AudioLayer.h"


@interface AudioLayer ()

@property (nonatomic, strong) AVAudioPlayer *player;

@end


@implementation AudioLayer

@dynamic volume;

- (id)initWithAudioFileURL:(NSURL *)URL
{
    if ((self = [self init]))
    {
        self.volume = 1.0;
        self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:URL error:NULL];
    }
    return self;
}

- (void)play
{
    [self.player play];
}

- (void)stop
{
    [self.player stop];
}

- (BOOL)isPlaying
{
    return self.player.playing;
}

+ (BOOL)needsDisplayForKey:(NSString *)key
{
    if ([@"volume" isEqualToString:key])
    {
        return YES;
    }
    return [super needsDisplayForKey:key];
}

- (id<CAAction>)actionForKey:(NSString *)key
{
    if ([key isEqualToString:@"volume"])
    {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:key];
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
        animation.fromValue = @([[self presentationLayer] volume]);
        return animation;
    }
    return [super actionForKey:key];
}

- (void)display
{
    NSLog(@"volume: %f", [self.presentationLayer volume]);

    //set audio volume to interpolated volume value
    self.player.volume = [self.presentationLayer volume];
}

@end

//
//  AudioLayer.h
//  AudioLayer
//
//  Created by Nick Lockwood on 29/04/2014.
//
//

#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>

@interface AudioLayer : CALayer

- (id)initWithAudioFileURL:(NSURL *)URL;

@property (nonatomic, assign) float volume;

- (void)play;
- (void)stop;
- (BOOL)isPlaying;

@end

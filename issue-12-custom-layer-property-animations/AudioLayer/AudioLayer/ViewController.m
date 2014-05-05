//
//  AudioLayerViewController.m
//  AudioLayer
//
//  Created by Nick Lockwood on 29/04/2014.
//  Copyright (c) 2014 Charcoal Design. All rights reserved.
//

#import "ViewController.h"
#import "AudioLayer.h"


@interface ViewController ()

@property (nonatomic, strong) AudioLayer *audioLayer;

@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSURL *musicURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"music" ofType:@"caf"]];
    self.audioLayer = [[AudioLayer alloc] initWithAudioFileURL:musicURL];
    [self.view.layer addSublayer:self.audioLayer];
}

- (IBAction)playPauseMusic:(UIButton *)sender
{
    if ([self.audioLayer isPlaying])
    {
        [self.audioLayer stop];
        [sender setTitle:@"Play Music" forState:UIControlStateNormal];
    }
    else
    {
        [self.audioLayer play];
        [sender setTitle:@"Pause Music" forState:UIControlStateNormal];
    }
}

- (IBAction)fadeIn
{
    self.audioLayer.volume = 1;
}

- (IBAction)fadeOut
{
    self.audioLayer.volume = 0;
}

@end

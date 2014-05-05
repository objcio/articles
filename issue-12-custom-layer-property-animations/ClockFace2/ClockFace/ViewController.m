//
//  ViewController.m
//  ClockFace
//
//  Created by Nick Lockwood on 28/04/2014.
//  Copyright (c) 2014 Charcoal Design. All rights reserved.
//

#import "ViewController.h"
#import "ClockFace.h"


@interface ViewController () <UITextFieldDelegate>

@property (nonatomic, strong) ClockFace *clockFace;

@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    //add clock face layer
    self.clockFace = [[ClockFace alloc] init];
    self.clockFace.position = CGPointMake(self.view.bounds.size.width / 2, 150);
    [self.view.layer addSublayer:self.clockFace];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    self.clockFace.time = [textField.text floatValue];
}

@end

[WIP] Animating custom CALayer properties
======================================

By default, almost every property of a CALayer can be animated. But sometimes it's useful to be able to define new properties and animate those as well. We can subclass CALayer and add our own properties to create animations that would be difficult or inelegant to perform any other way.

Generally, these break down into three types:

1) Custom properties that need to modify one or more standard properties of the layer (or one of its sublayers).

2) Custom properties that need to trigger redrawing of the layer's backing image (the contents property).

3) Custom properties that do something that doesn't involve redrawing or setting an existing animatable property.

Custom properties that need to set a standard animatable property are the simplest of all. These are really just custom setter methods that don't need to do anything clever. As an example, lets create a simple analog clockface where we can set the time using a "time" property of type NSDate:

We'll start by creating our static clock face. The clock consists of three CAShapeLayers; A circular layer for the face and two rectangular sublayers for the hour and minute hands:

    @interface ClockFace: CAShapeLayer
    
    @property (nonatomic, strong) NSDate *time;
    
    @end
    
    
    @interface ClockFace ()
    
    //private properties
    @property (nonatomic, strong) CALayer *hourHand;
    @property (nonatomic, strong) CALayer *minuteHand;
    
    @end
    
    
    @implementation ClockFace
    
    - (id)init
    {
        if ((self = [super init]))
        {
            self.bounds = CGRectMake(0, 0, 200, 200);
            self.path = [UIBezierPath bezierPathWithOvalInRect:self.bounds].CGPath;
            self.fillColor = [UIColor whiteColor].CGColor;
            self.strokeColor = [UIColor blackColor].CGColor;
            self.lineWidth = 4;
            
            self.hourHand = [CAShapeLayer layer];
            self.hourHand.path = [UIBezierPath bezierPathWithRect:CGRectMake(-4, -70, 8, 70)].CGPath;
            self.hourHand.fillColor = [UIColor blackColor].CGColor;
            self.hourHand.position = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
            [self addSublayer:self.hourHand];
            
            self.minuteHand = [CAShapeLayer layer];
            self.minuteHand.path = [UIBezierPath bezierPathWithRect:CGRectMake(-2, -90, 4, 90)].CGPath;
            self.minuteHand.fillColor = [UIColor blackColor].CGColor;
            self.minuteHand.position = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
            [self addSublayer:self.minuteHand];
        }
        return self;
    }
          
    @end
    
We'll also set up a basic view controller with a UIDatePicker so we can test our layer (the date picker is set up in the project storyboard):

    @interface ViewController ()
    
    @property (nonatomic, strong) IBOutlet UIDatePicker *datePicker;
    @property (nonatomic, strong) ClockFace *clockFace;
    
    @end
    
    
    @implementation ViewController
    
    - (void)viewDidLoad
    {
        [super viewDidLoad];
        
        //add clockface layer
        self.clockFace = [[ClockFace alloc] init];
        self.clockFace.position = CGPointMake(self.view.bounds.size.width / 2, 150);
        [self.view.layer addSublayer:self.clockFace];
        
        //set default time
        self.clockFace.time = [NSDate date];
    }
    
    - (IBAction)setTime
    {
        self.clockFace.time = self.datePicker.date;
    }
    
    @end
    
Now we just need to implement the setter method for our time property. This method gets the time in hours/minutes and converts them to radial coordinates, then transforms the hand layers:

    - (void)setTime:(NSDate *)time
    {
        _time = time;
        
        NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents *components = [calendar components:NSHourCalendarUnit | NSMinuteCalendarUnit fromDate:time];
        self.hourHand.affineTransform = CGAffineTransformMakeRotation(components.hour / 12.0 * 2.0 * M_PI);
        self.minuteHand.affineTransform = CGAffineTransformMakeRotation(components.minute / 60.0 * 2.0 * M_PI);
    }

As you can see, this is really not doing anything clever; we are not actually creating a new animated property - merely encapsulating several built-in animations into a single method. So what if we want to create an animation that doesn't map to any existing animatable layer properties?

Suppose that instead of implementing our clock face with individual layers, we wanted to draw the clock using Core Graphics? (In general this wouldn't be the best idea for performance reasons, but it's possible to imagine that there are more complex drawing operations that we might want to implement that would be hard to replicate by transforming individual layers). How would we do that?

Much like NSManagedObject, CALayer has the ability to generate dynamic setters and getters for any declared property at runtime. In our current clockface implementation, we've allowed Xcode to synthesise the time ivar and the getter method for our time property, and we've provided our own implementation for the setter. Let's change that now by getting rid of our setter and marking the time property as dynamic. We'll also get rid of the hand layers since we'll be drawing those ourselves now:

    @interface ClockFace ()

    @end
    
    
    @implementation ClockFace
    
    @dynamic time;
    
    - (id)init
    {
        if ((self = [super init]))
        {
            self.bounds = CGRectMake(0, 0, 200, 200);
        }
        return self;
    }
    
    @end

Before we do anything else, we need to make one other slight adjustment: Unfortunately, CALayer doesn't know how to interpolate between NSDate types (i.e. it cannot automatically generate intermediate values between NSDate objects as it can with numeric types and others such as colours and transforms). We could keep our custom date setter method and have it set another dynamic property representing the NSTimeInterval, but to keep things simple we'll replace our NSDate property with a floating point value that represents hours, and update the user interface to a simple text field to set the value:
    
    @interface ViewController () <UITextFieldDelegate>

    @property (nonatomic, strong) IBOutlet UITextField *textField;
    @property (nonatomic, strong) ClockFace *clockFace;
    
    @end
    
    
    @implementation ViewController
    
    - (void)viewDidLoad
    {
        [super viewDidLoad];
        
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
    
So now we've removed our custom setter, how are we going to know when our time property changes? We need a war to tell the CALayer that the time property changing means that the view needs to be updated. We do that by overriding the +needsDisplayForKey method, as follows:

    + (BOOL)needsDisplayForKey:(NSString *)key
    {
        if ([@"time" isEqualToString:key])
        {
            return YES;
        }
        return [super needsDisplayForKey:key];
    }
    
This tells our layer that whenever the time property is modified, it needs to call the -display method. We'll now override the display method and add a log of time value:

    - (void)display
    {
        NSLog(@"time: %f", self.time);
    }
    
If we set the time value to 1.5 we'll see that display is called with the new time.

    2014-04-28 22:37:04.253 ClockFace[49145:60b] time: 1.500000

That isn't really what we wanted though: We want the time value to animate smoothly between it's previous and new values. To make that happen, we need to specify an animation (or "action") for our time property. We do that by overriding the -actionForKey: method:

    - (id<CAAction>)actionForKey:(NSString *)key
    {
        if ([key isEqualToString:@"time"])
        {
            CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:key];
            animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
            animation.fromValue = @(self.time);
            return animation;
        }
        return [super actionForKey:key];
    }
    
Now if we set the time again, we see that display is called multiple times (~60 times per second, for the duration of the animation, which will be 0.25 seconds by default).

    2014-04-28 22:37:04.253 ClockFace[49145:60b] time: 1.500000
    2014-04-28 22:37:04.255 ClockFace[49145:60b] time: 1.500000
    2014-04-28 22:37:04.351 ClockFace[49145:60b] time: 1.500000
    2014-04-28 22:37:04.370 ClockFace[49145:60b] time: 1.500000
    2014-04-28 22:37:04.388 ClockFace[49145:60b] time: 1.500000
    2014-04-28 22:37:04.407 ClockFace[49145:60b] time: 1.500000
    2014-04-28 22:37:04.425 ClockFace[49145:60b] time: 1.500000
    2014-04-28 22:37:04.443 ClockFace[49145:60b] time: 1.500000
    2014-04-28 22:37:04.461 ClockFace[49145:60b] time: 1.500000
    2014-04-28 22:37:04.479 ClockFace[49145:60b] time: 1.500000
    2014-04-28 22:37:04.497 ClockFace[49145:60b] time: 1.500000
    2014-04-28 22:37:04.515 ClockFace[49145:60b] time: 1.500000
    2014-04-28 22:37:04.755 ClockFace[49145:60b] time: 1.500000

But for some reason it is still always being called with the final value. Why aren't we getting the interpolated values? The reason is that we are looking at the wrong time value.

When you set a property of a CALayer, you are really setting the value of the *model* layer - the layer that represents the final state of the layer at any given point in time. If you ask the model layer for its values, it will always tell you the last value that was set. But attached to the model layer is the *presentation* layer, an identical copy of the model layer whose values represent the *current*, mid-animation state of the layer. If we modify our -display method to log the time value of the presentationLayer, we will see the interpolated values. We should also use the presentationLayer's time value as the starting value for our animation, instead of self.time:

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
        NSLog(@"time: %f", [[self presentationLayer] time]);
    }
    
And here are the values:

    2014-04-28 22:43:31.200 ClockFace[49176:60b] time: 0.000000
    2014-04-28 22:43:31.203 ClockFace[49176:60b] time: 0.002894
    2014-04-28 22:43:31.263 ClockFace[49176:60b] time: 0.363371
    2014-04-28 22:43:31.300 ClockFace[49176:60b] time: 0.586421
    2014-04-28 22:43:31.318 ClockFace[49176:60b] time: 0.695179
    2014-04-28 22:43:31.336 ClockFace[49176:60b] time: 0.803713
    2014-04-28 22:43:31.354 ClockFace[49176:60b] time: 0.912598
    2014-04-28 22:43:31.372 ClockFace[49176:60b] time: 1.021573
    2014-04-28 22:43:31.391 ClockFace[49176:60b] time: 1.134173
    2014-04-28 22:43:31.409 ClockFace[49176:60b] time: 1.242892
    2014-04-28 22:43:31.427 ClockFace[49176:60b] time: 1.352016
    2014-04-28 22:43:31.446 ClockFace[49176:60b] time: 1.460729
    2014-04-28 22:43:31.464 ClockFace[49176:60b] time: 1.500000
    2014-04-28 22:43:31.636 ClockFace[49176:60b] time: 1.500000
    
So now all we have to do is draw our clock. We do this by using ordinary CoreGraphics functions to draw a CGImage and set it as our layer contents. Here is the updated -display method:

    - (void)display
    {
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
    
Now, drawing the clock in this way is not ideal because CoreGraphics functions are not hardware accelerated, and may cause the framerate of our animation to drop. An alternative to redrawing the contents image each frame is to store a number of predawn frames in an array and simply select the correct image based on the interpolated value. The code to do that might look like this:

    - (void)display
    {
        //get interpolated time value
        float time = [self.presentationLayer time];
        
        //fetch frame from a previously defined array of images
        NSInteger index = floor(time / [self.frames count]);
        UIImage *frame = self.frames[index];
        self.contents = (id)frame.CGImage;
    }
    
But this raises an interesting possibility; what happens if e don't update the contents image in our display method at all? What if we do something else?

There would be no point in setting any other layer property from within -display, because we could simply animate such properties directly, as we did in the first clockface example. But what if we set something else, perhaps something entirely unrelated to the layer?

The following code uses a CALayer combined with AVAudioPlayer to create an animated volume control. By making the volume a dynamic layer property, we can use Core Animation's implicit property tweening to smoothly slide between different volume levels in the same way we might animate any visual property of the layer:

    #import <QuartzCore/QuartzCore.h>
    #import <AVFoundation/AVFoundation.h>
    
    @interface AudioLayer : CALayer
    
    - (id)initWithAudioFileURL:(NSURL *)URL;
    
    @property (nonatomic, assign) float volume;
    
    - (void)play;
    - (void)stop;
    - (BOOL)isPlaying;
    
    @end


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
        //set audio volume to interpolated volume value
        self.player.volume = [self.presentationLayer volume];
    }
    
    @end
    
We can test this using a simple view controller with play, stop and fadeIn/Out volume buttons:

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

Note that even though our layer has no visual appearance, it still needs to be added to the onscreen view hierarchy in order for the animations to work correctly.
    
So in conclusion, CALayer's dynamic properties provide a simple mechanism to implement animations for any sort of property, not just the built-in ones. And by overriding the -display method, we can use those properties to control anything, not just the visual appearance of the layer.
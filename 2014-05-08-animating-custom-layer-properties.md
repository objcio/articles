---
title:  "Animating Custom Layer Properties"
category: "12"
date: "2014-05-08 10:00:00"
tags: article
author: "<a href=\"http://twitter.com/nicklockwood\">Nick Lockwood</a>"
---

By default, almost every standard property of `CALayer` and its subclasses can be animated, either by adding a `CAAnimation` to the layer (explicit animation), or by specifying an action for the property and then modifying it (implicit animation).

But sometimes we may wish to animate several properties in concert as if they were a single animation, or we may need to perform an animation that cannot be implemented by applying animations to standard layer properties.

In this article, we will discuss how to subclass `CALayer` and add our own properties to easily create animations that would be cumbersome to perform any other way.

Generally speaking, there are three types of animatable property that we might wish to add to a subclass of `CALayer`:

* A property that indirectly animates one or more standard properties of the layer (or one of its sublayers).
* A property that triggers redrawing of the layer's backing image (the `contents` property).
* A property that doesn't involve redrawing the layer or animating any existing properties.

## Indirect Property Animation

Custom properties that indirectly modify other standard layer properties are the simplest of these options. These are really just custom setter methods that convert their input into one or more different values suitable for creating the animation.

We don't actually need to write any animation code at all if the properties we are setting already have standard animation actions set up, because if we modify those properties, they will inherit whatever animation settings are configured in the current `CATransaction`, and will animate automatically.

In other words, even if `CALayer` doesn't know how to animate our custom property, it can already animate all of the visible side effects that are caused by changing our property, and that's all we care about.

To demonstrate this approach, let's create a simple analog clock where we can set the time using a `time` property of type `NSDate`. We'll start by creating our static clock face. The clock consists of three `CAShapeLayer` instances -- a circular layer for the face and two rectangular sublayers for the hour and minute hands:

    @interface ClockFace: CAShapeLayer

    @property (nonatomic, strong) NSDate *time;

    @end

    @interface ClockFace ()

    //private properties
    @property (nonatomic, strong) CAShapeLayer *hourHand;
    @property (nonatomic, strong) CAShapeLayer *minuteHand;

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
            self.hourHand.path = [UIBezierPath bezierPathWithRect:CGRectMake(-2, -70, 4, 70)].CGPath;
            self.hourHand.fillColor = [UIColor blackColor].CGColor;
            self.hourHand.position = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
            [self addSublayer:self.hourHand];
            
            self.minuteHand = [CAShapeLayer layer];
            self.minuteHand.path = [UIBezierPath bezierPathWithRect:CGRectMake(-1, -90, 2, 90)].CGPath;
            self.minuteHand.fillColor = [UIColor blackColor].CGColor;
            self.minuteHand.position = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
            [self addSublayer:self.minuteHand];
        }
        return self;
    }
          
    @end
    
We'll also set up a basic view controller with a `UIDatePicker` so we can test our layer (the date picker itself is set up in the Storyboard):

    @interface ViewController ()

    @property (nonatomic, weak) IBOutlet UIDatePicker *datePicker;
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
        
        //set default time
        self.clockFace.time = [NSDate date];
    }

    - (IBAction)setTime
    {
        self.clockFace.time = self.datePicker.date;
    }

    @end

Now we just need to implement the setter method for our `time` property. This method uses `NSCalendar` to break the time down into hours and minutes, which we then convert into angular coordinates. We then use these angles to generate a `CGAffineTransform` to rotate the hands:

    - (void)setTime:(NSDate *)time
    {
        _time = time;
        
        NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        NSDateComponents *components = [calendar components:NSHourCalendarUnit | NSMinuteCalendarUnit fromDate:time];
        self.hourHand.affineTransform = CGAffineTransformMakeRotation(components.hour / 12.0 * 2.0 * M_PI);
        self.minuteHand.affineTransform = CGAffineTransformMakeRotation(components.minute / 60.0 * 2.0 * M_PI);
    }
    
The result looks like this:

<img src="{{site.images_path}}/issue-12/clock.gif" width="320px">

You can check out the project for yourself [on GitHub](https://github.com/objcio/issue-12-custom-layer-property-animations).

As you can see, this is really not doing anything clever; we are not actually creating a new animated property, but merely setting several standard animatable layer properties from a single method. So what if we want to create an animation that doesn't map to any existing layer properties?

## Animating Layer Contents

Suppose that instead of implementing our clock face using individual layers, we wanted to draw the clock using Core Graphics. (In general this will have inferior performance, but it's possible to imagine that there are complex drawing operations that we might want to implement that would be hard to replicate using ordinary layer properties and transforms.) How would we do that?

Much like `NSManagedObject`, `CALayer` has the ability to generate dynamic setters and getters for any declared property. In our current implementation, we've allowed the compiler to synthesize the `time` property's ivar and getter method for us, and we've provided our own implementation for the setter method. But let's change that now by getting rid of our setter and marking the property as `@dynamic`. We'll also get rid of the individual hand layers since we'll now be drawing those ourselves:

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

Before we do anything else, we need to make one other slight adjustment: Unfortunately, `CALayer` doesn't know how to interpolate `NSDate` properties (i.e. it cannot automatically generate intermediate values between `NSDate` instances, as it can with numeric types and others such as `CGColor` and `CGAffineTransform`). We could keep our custom setter method and have it set another dynamic property representing the equivalent `NSTimeInterval` (which is a numeric value, and can be interpolated), but to keep the example simple, we'll replace our `NSDate` property with a floating-point value that represents hours on the clock, and update the user interface so it uses a simple `UITextField` to set the value instead of a date picker:

    @interface ViewController () <UITextFieldDelegate>

    @property (nonatomic, strong) IBOutlet UITextField *textField;
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
    
Now that we've removed our custom setter method, how are we going to know when our `time` property changes? We need a way to automatically notify the `CALayer` whenever the `time` property changes, so that it can redraw its contents. We do that by overriding the `+needsDisplayForKey:` method, as follows:

    + (BOOL)needsDisplayForKey:(NSString *)key
    {
        if ([@"time" isEqualToString:key])
        {
            return YES;
        }
        return [super needsDisplayForKey:key];
    }
    
This tells the layer that whenever the `time` property is modified, it needs to call the `-display` method. We'll now override the `-display` method as well, and add an `NSLog` statement to print out the value of `time`:

    - (void)display
    {
        NSLog(@"time: %f", self.time);
    }
    
If we set the `time` property to 1.5, we'll see that display is called with the new value:

    2014-04-28 22:37:04.253 ClockFace[49145:60b] time: 1.500000

That isn't really what we want though; we want the `time` property to animate smoothly between its old and new values over several frames. To make that happen, we need to specify an animation (or "action") for our time property, which we can do by overriding the `-actionForKey:` method:

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
    
Now, if we set the `time` property again, we see that `-display` is called multiple times. The number of times should equate to approximately 60 times per second, for the duration of the animation (which defaults to 0.25 seconds, or about 15 frames):

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

But for some reason when we log the `time` value at each of these intermediate points, we are still seeing the final value. Why aren't we getting the interpolated values? The reason is that we are looking at the wrong `time` property.

When you set a property of a `CALayer`, you are really setting the value of the *model* layer -- the layer that represents the final state of the layer when any ongoing animations have finished. If you ask the model layer for its values, it will always tell you the last value that it was set to.

But attached to the model layer is the *presentation* layer -- a copy of the model layer with values that represent the *current*, mid-animation state. If we modify our `-display` method to log the `time` property of the layer's `presentationLayer`, we will see the interpolated values we were expecting. (We'll also use the `presentationLayer`'s `time` property to get the starting value for our animation action, instead of `self.time`):

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
    
So now, all we have to do is draw our clock. We do this by using ordinary Core Graphics functions to draw to a Graphics Context, and then set the resultant image as our layer's `contents`. Here is the updated `-display` method:

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
    
The result looks like this:

<img src="{{site.images_path}}/issue-12/clock2.gif" width="320px">

As you can see, unlike the first clock animation, the minute hand actually cycles through a full revolution for each hour that the hour hand moves (like a real clock would), instead of just moving to its final position via the shortest path. That's an advantage of animating in this way; because we are animating the `time` value itself instead of just the positions of the hands, the contextual information is preserved. 

Drawing the clock in this way is not ideal because Core Graphics functions are not hardware accelerated, and may cause the frame rate of our animation to drop. An alternative to redrawing the `contents` image 60 times per second would be to store a number of pre-drawn images in an array and simply select the correct image based on the interpolated value. The code to do that might look like this:

    const NSInteger hoursOnAClockFace = 12;

    - (void)display
    {
        //get interpolated time value
        float time = [self.presentationLayer time] / hoursOnAClockFace;
        
        //fetch frame from a previously defined array of images
        NSInteger numberOfFrames = [self.frames count];
        NSInteger index = round(time * numberOfFrames) % numberOfFrames;
        UIImage *frame = self.frames[index];
        self.contents = (id)frame.CGImage;
    }
    
This improves animation performance by avoiding the need for costly software drawing during each frame, but the tradeoff is that we need to store all of the pre-drawn animation frame images in memory, which -- for a complex animation -- might be prohibitively wasteful of RAM.
    
But this raises an interesting possibility. What happens if we don't update the `contents` image in our `-display` method at all? What if we do something else?

## Animating Non-Visual Properties

There would be no point in updating any other layer property from within `-display`, because we could simply animate any such property directly, as we did in the first clock-face example. But what if we set something else, perhaps something entirely unrelated to the layer?

The following code uses a `CALayer` combined with `AVAudioPlayer` to create an animated volume control. By tying the volume to a dynamic layer property, we can use Core Animation's property interpolation to smoothly ramp between different volume levels in the same way we might animate any cosmetic property of the layer:

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
    
We can test this using a simple view controller with play, stop, volume up, and volume down buttons:

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

Note: even though our layer has no visual appearance, it still needs to be added to the onscreen view hierarchy in order for the animations to work correctly.
    
## Conclusion
    
`CALayer`'s dynamic properties provide a simple mechanism to implement any sort of animation-- not just the built-in ones -- and by overriding the `-display` method, we can use those properties to control anything we like, even something like sound volume.

By using these properties, we not only avoid reinventing the wheel, but we ensure that our custom animations work with the standard animation timing and control functions, and can easily be synchronized with other animated properties.

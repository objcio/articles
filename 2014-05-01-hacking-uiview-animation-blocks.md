[WIP] Hacking UIView animation blocks for fun and profit
===================================================

In David's article, he examined the relationship between views and layers, and how the view uses the actionForLayer:forKey: method of the CALayerDelegate to override the implicit animation behaviour of the layer. If you've not done so already, go read that first.

In this article, I'm going to explore a way that we can create views that implement these custom animations in a natural way.

As we know, layers in iOS come in two flavours: Backing layers and hosted layers. The only difference between them is that the view acts as the layer delegate for its backing layer, but not for any hosted sublayers.

In order to implement the UIView transactional animation blocks, UIView disables all animations by default and then e-enables them individually as required. It does this using the actionForLayer:forKey: method.

Somewhat strangely, UIView doesn't enable animations for every property that CALayer does by default. A notable example is the layer.contents property, which is animatable by default for a hosted layer, but cannot be animated using a UIView animation block.

The ability to animate layer contents is incredibly useful in practice. It means that you can do things like crossfade between two images in a UIImageView, or between two different text strings in a label. So let's enable that feature.

In the code below, we create a UILabel subclass called FancyLabel, and override actionForLayer:forKey: so that it returns [CATransition animation] for the contents key instead of [NSNull null] (which is what the method returns normally):

    @interface FancyLabel : UILabel
    
    @end

    @implementation FancyLabel
    
    - (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)key
    {
        if ([key isEqualToString:@"contents"])
        {
            return [CATransition animation];
        }
        return [super actionForLayer:layer forKey:key];
    }
    
    @end
    
We'll rig up a simple view controller to test our label. Here is the code (the label and UITextField have been added in the Storyboard):

    @interface ViewController () <UITextFieldDelegate>
    
    @property (nonatomic, strong) IBOutlet FancyLabel *label;
    
    @end
    
    @implementation ViewController
    
    - (BOOL)textFieldShouldReturn:(UITextField *)textField
    {
        [textField resignFirstResponder];
        return NO;
    }
    
    - (void)textFieldDidEndEditing:(UITextField *)textField
    {
        self.label.text = textField.text;
    }
    
    @end

If you set the text property of the label, instead of updating immediately, it will now crossfade from the previous text to the new text. You might wonder why we've overridden the action for the "contents" key instead of "text"?

The key passed to the actionForLayer:forKey: method relates to the property of the underlying layer that is being modified, not the original property of the view that caused that modification to happen. When you set the text of a UILabel, it causes the contents of the layer to be redrawn. This is not always the case for all properties of all views; it depends on the type of view and the specific property.

On iOS, the view is composed of a hierarchy of layers, each of which are drawn to the screen using hardware accelerated OpenGL drawing. Because some layers contain graphics that cannot be drawn using OpenGL, layers have an optional backing image, which can be drawn using the slower-but-more-flexible Quartz graphics APIs and then rendered as a texture by OpenGL.

The contents property represents the backing CGImage of the layer. Most views do not actually have a backing image, as their contents can be drawn directly using OpenGL, but text drawing cannot currently be handled using OpenGL, and must be drawn into an image first.

When we set the text property of a UILabel, it draws the new text into an image and sets that image as the layer contents. At that point, the actionForLayer:forKey: method is called, and we return our overridden action.

The action we are returning is a CAAnimation subclass of type CATransition. CATransition is a special type of animation that affects the entire layer instead of just one property. By default, CATransition uses a crossfade affect, but if we wanted we could use one of several other transition types. For example, the following creates a sort of flipboard effect, where the old text scrolls up to reveal the new text underneath whenever it is changed:

    - (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)key
    {
        if ([key isEqualToString:@"contents"])
        {
            CATransition *transition = [CATransition animation];
            transition.type = kCATransitionPush;
            transition.subtype = kCATransitionFromTop;
            return transition;
        }
        return [super actionForLayer:layer forKey:key];
    }
        
OK, so this is neat, but it's not a very good iOS citizen as view subclasses go. We don't expect layer properties to animate whenever we set them unless we are currently inside a UIView animation block. What we ideally want to do is only animate our contents when inside an animation block, i.e. when other view properties would normally animate. How can we do that?

First, we need to tie our transition to a property that Core Animation knows how to animate. The contents key is a bit of a special case, so we need to use something else for this trick. Fortunately, Core Animation has a neat feature whereby we can simply use KVC (Key Value Coding) to set arbitrary properties on the layer. That means we can dynamically add new animatable properties at runtime without subclassing the layer itself. If we override the setText: method of our view to also set a "text" key on our layer, we can then observe that in our actionForLayer:forKey: method, as follows:

    @implementation FancyLabel
    
    - (void)setText:(NSString *)text
    {
        //actually update the text
        [super setText:text];
        
        //trigger our transition animation
        [self.layer setValue:text forKey:@"text"];
    }
    
    - (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)key
    {
        if ([key isEqualToString:@"text"])
        {
            CATransition *transition = [CATransition animation];
            transition.type = kCATransitionPush;
            transition.subtype = kCATransitionFromTop;
            return transition;
        }
        return [super actionForLayer:layer forKey:key];
    }
    
    @end

The UIView animation mechanism implementation is private, so there's no simple flag we can check to see if the view is currently animating, however we do know one thing: When animating, UIView's actionForLayer:forKey: will return valid CAActions for its animatable property keys, and when not animating it will return [NSNull null] for them. If we simply pick a suitable key we can interrogate UIView to see if it's currently supplying an action for that key, and use that to determine our response for our custom key. We'll use the key "bounds" since that's a property of UIView that normally supports animation:

    - (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)key
    {
        if ([key isEqualToString:@"text"])
        {
            if ([super actionForLayer:layer forKey:@"bounds"] != [NSNull null])
            {
                CATransition *transition = [CATransition animation];
                transition.type = kCATransitionPush;
                transition.subtype = kCATransitionFromTop;
                return transition;
            }
        }
        return [super actionForLayer:layer forKey:key];
    }
    
Setting the label text directly will no longer animate, but if we set it inside a UIView animation block it will still animate as before:

    - (void)textFieldDidEndEditing:(UITextField *)textField
    {
        [UIView animateWithDuration:1.0 animations:^{
            self.label.text = textField.text;
        }];
    }
    
That works, but although we've set the durations of our animation to one second, the transition is actually taking place within 0.25 seconds. The problem is that we're detecting the fact that we're inside a UIView animation block, but not taking into account its properties. Fortunately we can obtain those values from the bounds action and transfer them to our transition, as follows:

    - (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)key
    {
        if ([key isEqualToString:@"text"])
        {
            CAAnimation *action = (CAAnimation *)[self actionForLayer:layer forKey:@"bounds"];
            if (action != (CAAnimation *)[NSNull null])
            {
                CATransition *transition = [CATransition animation];
                transition.type = kCATransitionPush;
                transition.subtype = kCATransitionFromTop;
                
                //CAMediatiming attributes
                transition.beginTime = action.beginTime;
                transition.duration = action.duration;
                transition.speed = action.speed;
                transition.timeOffset = action.timeOffset;
                transition.repeatCount = action.repeatCount;
                transition.repeatDuration = action.repeatDuration;
                transition.autoreverses = action.autoreverses;
                transition.fillMode = action.fillMode;
                
                //CAAnimation attributes
                transition.timingFunction = action.timingFunction;
                transition.delegate = action.delegate;
                
                return transition;
            }
        }
        return [super actionForLayer:layer forKey:key];
    }

Success! Our transition now respects the duration, timing function, etc. of our UIView animation block. It will also call the completion block if specified. One small caveat is that if we use a delay argument for our animation block it won't work because the text will still be updated immediately. To fix that we would need to reimplement the UILabel text drawing ourselves (which is possible, but out of scope for this tutorial).

So there you have it, you now have the means to tie your custom CALayer animations into the standard UIView animation mechanism, without swizzling or calling private APIs.

---
layout: post
title:  "View-Layer Synergy"
category: "12"
date: "2014-05-01 11:00:00"
tags: article
author: "<a href=\"https://twitter.com/davidronnqvist\">David Rönnqvist</a>"
---

On iOS, views always have an underlying layer. There is a very strong relationship between the view and its layer, and the view derives most of its data from the layer object directly. There are also standalone layers -- for example, `AVCaptureVideoPreviewLayer` and `CAShapeLayer` -- that present content on the screen without being attached to a view. In either case, there is a layer involved. Still, the layers that are attached to views and the standalone layers behave slightly differently. 

If you change almost any property of a standalone layer, it will make a brief animation from the old value to the new value.[^animatable] However, if you change the same property of a view's layer, it just changes from one frame to the next. Despite it being layers involved in both cases, the default layer behavior of implicit animations doesn't apply when the layer is attached to a view.

An explanation as to _why_ this is happening can be found in the Core Animation Programming Guide in the section "How to Animate Layer-Backed Views":

> The UIView class disables layer animations by default but reenables them inside animation blocks

That is the behavior that we are seeing; when a property is changed outside of an animation block, there is no animation, but when the property is changed inside of an animation, there is an animation. The answer to the question of _how_ this is happening is both simple and elegant and speaks well to how views and layers were designed to work together. 

Whenever an animatable layer property changes, the layer looks for the appropriate 'action' to run for that property change. An action in Core Animation terminology is a more general term for an animation.[^CAAction] The layer searches for an action in a very well-documented manner, consisting of five steps. The first step is the most interesting when looking at the interaction between the view and the layer:

[^CAAction]: Technically, it is a protocol and could be pretty much anything, but in practice you are talking about an animation of some sort.

The layer asks its delegate to provide an action for the property that was changed by sending the `actionForLayer:forKey:` message to its delegate. The delegate can respond with one out of three things:

1. It can respond with an action object, in which case the layer will use that action.
2. It can respond with `nil` to tell the layer to keep looking elsewhere.
3. It can respond with the `NSNull` object to tell the layer that no action should run and that the search should be terminated.

What makes this so interesting is that, for a layer that is backing a view, the view is always the delegate:

> In iOS, if the layer is associated with a UIView object, this property _must_ be set to the view that owns the layer.

What may have seemed complicated a minute ago is all of a sudden very simple: the view returns `NSNull` whenever the layer asks for an action, except when the property change happened inside of an animation block. But don't just take my word for it. It's very easy to verify that this is the case. Simply ask the view to provide an action for a layer property that would normally animate, for example, 'position':

    NSLog(@"outside animation block: %@",
          [myView actionForLayer:myView.layer forKey:@"position"]);

    [UIView animateWithDuration:0.3 animations:^{
        NSLog(@"inside animation block: %@",
              [myView actionForLayer:myView.layer forKey:@"position"]);
    }];

Running the above code shows that the view returns the NSNull object outside of the block and returns a CABasicAnimation inside of the block. Elegant, isn't it? Note that the description of NSNull prints with angle brackets, just like other objects, ("`<null>`") and that nil prints with parenthesis ("`(null)`"): 

	outside animation block: <null>
	inside animation block: <CABasicAnimation: 0x8c2ff10>

For backing layers, the search for an action doesn't go further than the first step.[^neverSeen] For standalone layers, there are four more steps that you can read more about in [the documentation for `actionForKey:` on CALayer][actionForKeyDocs]. 

[^neverSeen]: At least I have never seen a case where the view returns `nil` so that the search for an action continues.

# Learning from UIKit

I'm sure that we can all agree that UIView animation is a really nice API with its concise, declarative style. And the fact that it's using Core Animation to perform these animations gives us an opportunity to dig deep and see how UIKit uses Core Animation. There may even be some good practices and neat tricks to pick up along the way :)

When a property changes inside of an animation block, the view returns a basic animation to the layer and that animation gets added to the layer via the regular `addAnimation:forKey:` method, just like an explicit animation would. Once again, don't just take my word for it. Let's verify.

The interaction between views and layers is rather easy to inspect, all thanks to the `+layerClass` class method on UIView. It determines what class is used when creating the backing layer of the view. By subclassing UIView and returning a custom layer class, we can override `addAnimation:forKey:` in that layer subclass and log to see that it gets called. The only thing we need to remember is to always call super so that we don't alter the behavior that we are trying to inspect:

	@interface DRInspectionLayer : CALayer
	@end
	
	@implementation DRInspectionLayer
	- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key
	{
	    NSLog(@"adding animation: %@", [anim debugDescription]);
	    [super addAnimation:anim forKey:key];
	}
	@end
	
	
	@interface DRInspectionView : UIView
	@end
	
	@implementation DRInspectionView
	+ (Class)layerClass
	{
	    return [DRInspectionLayer class];
	}
	@end

By logging the debug description of the animation, we don't only see that it gets called as expected, but we also see how the animation is constructed:

	<CABasicAnimation:0x8c73680; 
		delegate = <UIViewAnimationState: 0x8e91fa0>;
		fillMode = both; 
		timingFunction = easeInEaseOut; 
		duration = 0.3; 
		fromValue = NSPoint: {5, 5}; 
		keyPath = position
	>
	
At the time when the animation is added to the layer, the new value of the property hasn't yet been changed. The animation is constructed to make good use of this by only specifying an explicit `fromValue` (the current value). A quick glance at [the CABasicAnimation documentation][basicAnimation] reminds us what this means for the interpolation of the animation:

> `fromValue` is non-`nil`. Interpolates between `fromValue` and the current presentation value of the property.

This is how I like to work with explicit animations as well, by changing the property to the new value and then adding the animation object to the layer:

    CABasicAnimation *fadeIn = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeIn.duration  = 0.75;
    fadeIn.fromValue = @0;
    
    myLayer.opacity = 1.0; // change the model value ...
    // ... and add the animation object
    [myLayer addAnimation:fadeIn forKey:@"fade in slowly"];

I find it to be very clean, and you don't have to do anything extra when the animation is removed. If the animation starts after a delay, you can use a backward fill mode (or the 'both' fill mode), just like the animation that UIKit created.


You may have seen the animation delegate and wondered what that class is for. Looking at a [class dump][animationState], we can see that it's mostly maintaining state about the animations (duration, delay, repeat count, etc.). We can also see that it pushes and pops to a stack to be able to get the correct state when nesting one animation block inside of another. All of that is mostly an implementation detail and not very interesting unless you are trying to write your own block-based animation API (which is actually quite a fun idea). 

However, it _is_ interesting to see that the delegate implements `animationDidStart:` and `animationDidStop:finished:` and passes that information on to its own delegate. We can log the delegate's delegate to see that it is of another private class: UIViewAnimationBlockDelegate. Looking at [its class dump][blockDelegate], we can see that it is a very small class with a single responsibility: responding to the animation delegate callbacks and executing the corresponding blocks. This is something that we can easily add to our own Core Animation code if we prefer blocks over delegate callbacks:

	@interface DRAnimationBlockDelegate : NSObject
	
	@property (copy) void(^start)(void);
	@property (copy) void(^stop)(BOOL);
	
	+(instancetype)animationDelegateWithBeginning:(void(^)(void))beginning
	                                   completion:(void(^)(BOOL finished))completion;
	
	@end
	
	@implementation DRAnimationBlockDelegate
	
	+ (instancetype)animationDelegateWithBeginning:(void (^)(void))beginning
	                                    completion:(void (^)(BOOL))completion
	{
	    DRAnimationBlockDelegate *result = [DRAnimationBlockDelegate new];
	    result.start = beginning;
	    result.stop  = completion;
	    return result;
	}
	
	- (void)animationDidStart:(CAAnimation *)anim
	{
	    if (self.start) {
	        self.start();
	    }
	    self.start = nil;
	}
	
	- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
	{
	    if (self.stop) {
	        self.stop(flag);
	    }
	    self.stop = nil;
	}
	
	@end

Depending on personal preference, a block-based callback style, like this, may fit you better than implementing the delegate callbacks in your code: 

    fadeIn.delegate = [DRAnimationBlockDelegate animationDelegateWithBeginning:^{
        NSLog(@"beginning to fade in");
    } completion:^(BOOL finished) {
        NSLog(@"did fade %@", finished ? @"to the end" : @"but was cancelled");
    }];

# Custom Block-Based Animation APIs

Once you know about the `actionForKey:` mechanism, UIView animations are a lot less magical than they might first seem. In fact, there isn't really anything stopping us from writing our own block-based animation APIs that are tailored to our needs. The one I'm designing will be used to draw attention to a view by animating the change inside of the block with a very aggressive timing curve, and then slowly animate back to the original value. You could say that it makes the view 'pop.'[^pop] Unlike a regular animation block with the `UIViewAnimationOptionAutoreverse` option, I'm also changing the model value back to what it was before, since that's what the animation conceptually does. Using the custom animation API will look like this:

[^pop]: Not to be confused with Facebook's new framework.

	[UIView DR_popAnimationWithDuration:0.7
	                             animations:^{
	                                 myView.transform = CGAffineTransformMakeRotation(M_PI_2);
	                                }];

When we are done, it is going to look like this (animating the position, size, color, and rotation of four different views):

![The custom block animation API, used to animate the position, size, color, and rotation of four different views](/images/issue-12/2014-05-01-view-layer-synergy-custom-block-animations.gif) 
      
To start with, we need to get the delegate callback when a layer property changes. Since we can't know what layers are going to change beforehand, I have chosen to swizzle `actionForLayer:forKey:` in a category on UIView:

	@implementation UIView (DR_CustomBlockAnimations)
	
	+ (void)load
	{	    
	    SEL originalSelector = @selector(actionForLayer:forKey:);
	    SEL extendedSelector = @selector(DR_actionForLayer:forKey:);
	    
	    Method originalMethod = class_getInstanceMethod(self, originalSelector);
	    Method extendedMethod = class_getInstanceMethod(self, extendedSelector);
	    
	    NSAssert(originalMethod, @"original method should exist");
	    NSAssert(extendedMethod, @"exchanged method should exist");
	    
	    if(class_addMethod(self, originalSelector, method_getImplementation(extendedMethod), method_getTypeEncoding(extendedMethod))) {
	        class_replaceMethod(self, extendedSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
	    } else {
	        method_exchangeImplementations(originalMethod, extendedMethod);
	    }
	}

To make sure that we don't break any other code that relies on the `actionForLayer:forKey:` callback, we use a static variable to determine if this is our custom animation context or not. It could have been just a `BOOL` for this single use, but a context is more flexible if we would like to write more code like this in the future:

	static void *DR_currentAnimationContext = NULL;
	static void *DR_popAnimationContext     = &DR_popAnimationContext;
	
	- (id<CAAction>)DR_actionForLayer:(CALayer *)layer forKey:(NSString *)event
	{
	    if (DR_currentAnimationContext == DR_popAnimationContext) {
	        // our custom code here...
	    }
	    
	    // call the original implementation
	    return [self DR_actionForLayer:layer forKey:event]; // yes, they are swizzled
	}

In our implementation, we will make sure to set the animation context before executing the animation block, and then restore the context afterward:

	+ (void)DR_popAnimationWithDuration:(NSTimeInterval)duration
	                         animations:(void (^)(void))animations
	{
	    DR_currentAnimationContext = DR_popAnimationContext;
	    // execute the animations (which will trigger callbacks to the swizzled delegate method)
	    animations();
	    /* more code to come */
	    DR_currentAnimationContext = NULL;
	}

If all we wanted to do was to add a basic animation from the old value to the new, then we could do so directly from within the delegate callback. But since we want more control of the animation, we need to use a keyframe animation. A keyframe animation requires all of the values to be known, and in our case, the new value hasn't been set so we can't know it yet.

Interestingly, iOS 7 added a block-based animation API that encounters the same obstacle. Using the same inspection technique as above, we can see how it overcomes that obstacle. For each keyframe, the view returns `nil` when the property is changed, but saves the necessary state so that the CAKeyframeAnimation object can be created after all the keyframe blocks have executed. 

Inspired by that approach, we can create a small class that stores the information that we need to create the animation: what layer was modified, what key path was changed, and what the old value was:

	@interface DRSavedPopAnimationState : NSObject
	
	@property (strong) CALayer  *layer;
	@property (copy)   NSString *keyPath;
	@property (strong) id        oldValue;
	
	+ (instancetype)savedStateWithLayer:(CALayer *)layer
	                            keyPath:(NSString *)keyPath;
	
	@end
	
	@implementation DRSavedPopAnimationState
	
	+ (instancetype)savedStateWithLayer:(CALayer *)layer
	                            keyPath:(NSString *)keyPath
	{
	    DRSavedPopAnimationState *savedState = [DRSavedPopAnimationState new];
	    savedState.layer    = layer;
	    savedState.keyPath  = keyPath;
	    savedState.oldValue = [layer valueForKeyPath:keyPath];
	    return savedState;
	}
	
	@end

Then, in our swizzled delegate callback, we simply store the state for the property that changed in a static mutable array:

	if (DR_currentAnimationContext == DR_popAnimationContext) {
        [[UIView DR_savedPopAnimationStates] addObject:[DRSavedPopAnimationState savedStateWithLayer:layer
                                                                                  keyPath:event]];
        
        // no implicit animation (it will be added later)
        return (id<CAAction>)[NSNull null];
    }

After the animation block has executed, all the properties have been changed and their states have been saved. Now, we can enumerate over the saved state and create the keyframe animations:

	+ (void)DR_popAnimationWithDuration:(NSTimeInterval)duration
	                         animations:(void (^)(void))animations
	{
	    DR_currentAnimationContext = DR_popAnimationContext;
	    
	    // do the animation (which will trigger callbacks to the swizzled delegate method)
	    animations();
	    
	    [[self DR_savedPopAnimationStates] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
	        DRSavedPopAnimationState *savedState   = (DRSavedPopAnimationState *)obj;
	        CALayer *layer    = savedState.layer;
	        NSString *keyPath = savedState.keyPath;
	        id oldValue       = savedState.oldValue;
	        id newValue       = [layer valueForKeyPath:keyPath];
	    
	        CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:keyPath];
	        
	        CGFloat easing = 0.2;
	        CAMediaTimingFunction *easeIn  = [CAMediaTimingFunction functionWithControlPoints:1.0 :0.0 :(1.0-easing) :1.0];
	        CAMediaTimingFunction *easeOut = [CAMediaTimingFunction functionWithControlPoints:easing :0.0 :0.0 :1.0];
	        
	        anim.duration = duration;
	        anim.keyTimes = @[@0, @(0.35), @1];
	        anim.values = @[oldValue, newValue, oldValue];
	        anim.timingFunctions = @[easeIn, easeOut];
	        
	        // back to old value without an animation
	        [CATransaction begin];
	        [CATransaction setDisableActions:YES];
	        [layer setValue:oldValue forKeyPath:keyPath];
	        [CATransaction commit];
	        
	        // animate the "pop"
	        [layer addAnimation:anim forKey:keyPath];
	        
	    }];
	    
	    // clean up (remove all the stored state)
	    [[self DR_savedPopAnimationStates] removeAllObjects];
	    
	    DR_currentAnimationContext = nil;
	}

Note that the old model value was set on the layer so that the model and the presentation match when the animation finishes and is removed. 

Creating your own API like this is not going to be a good fit for every case, but if you are doing the same animation in many places throughout your app, it can help clean up your code and reduce duplication. Even if you never end up using it, having walked through it once demystifies the UIView block animation APIs, especially if you are comfortable with Core Animation.

# Other Animation Inspiration

I'd like to leave you with a completely different approach to a higher-level animation API: the UIImageView animation. On the surface, it barely resembles a traditional animation API. All that you are doing is specifying an array of images and a duration, and telling the image view to start animating. Behind that abstraction, it results in a discrete keyframe animation of the contents property being added to the image view's layer:

	<CAKeyframeAnimation:0x8e5b020; 
		removedOnCompletion = 0; 
		delegate = <_UIImageViewExtendedStorage: 0x8e49230>; 
		duration = 2.5; 
		repeatCount = 2.14748e+09; 
		calculationMode = discrete; 
		values = (
		    "<CGImage 0x8d6ce80>",
		    "<CGImage 0x8d6d2d0>",
		    "<CGImage 0x8d5cd30>"
		); 
		keyPath = contents
	>

Animation APIs can come in many different forms, and the same applies to the animation APIs you write yourself.

[blockDelegate]: https://github.com/EthanArbuckle/IOS-7-Headers/blob/master/Frameworks/UIKit.framework/UIViewAnimationBlockDelegate.h "UIViewAnimationBlockDelegate class dump"

[animationState]: https://github.com/rpetrich/iphoneheaders/blob/master/UIKit/UIViewAnimationState.h "UIViewAnimationState class dump"

[keyframeState]: https://github.com/limneos/classdump-dyld/blob/master/iphoneheaders/iOS7.0.3/System/Library/Frameworks/UIKit.framework/UIViewKeyframeAnimationState.h "UIViewKeyframeAnimationState class dump"

[actionForKeyDocs]: https://developer.apple.com/library/mac/documentation/graphicsimaging/reference/CALayer_class/Introduction/Introduction.html#//apple_ref/occ/instm/CALayer/actionForKey: "actionForKey: documentation"

[^animatable]: Almost all layer properties are implicitly animatable. You will see that their brief descriptions in the documentation end with 'animatable.' This applies to pretty much any numeric property, such as the position, size, color, and opacity, and even for boolean properties like isHidden and doubleSided. Properties that are paths are animatable but do not support implicit animations.

[basicAnimation]: https://developer.apple.com/library/ios/documentation/GraphicsImaging/Reference/CABasicAnimation_class/Introduction/Introduction.html "CABasicAnimation documentation"


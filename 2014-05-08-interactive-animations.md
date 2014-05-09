---
layout: post
title:  "Interactive Animations"
category: "12"
date: "2014-05-08 06:00:00"
tags: article
author: "<a href=\"https://twitter.com/chriseidhof\">Chris Eidhof</a> and <a href=\"https://twitter.com/floriankugler\">Florian Kugler</a>"
---


When Steve Jobs introduced the first iPhone in 2007, the touch screen interaction had a certain kind of magic to it. A prime example of this was his [first demonstration of scrolling a table view](http://www.youtube.com/watch?v=t4OEsI0Sc_s&t=16m9s). You can hear in the reaction of the audience how impressive what seems the most normal thing to us today was back then. A little bit later in the presentation, he underlined this point by quoting somebody he had given a demo to before: ["You got me at scrolling"](https://www.youtube.com/watch?v=t4OEsI0Sc_s&t=22m10s). 

What was it about scrolling that created this 'wow' effect?

Scrolling was a perfect example of direct manipulation through capacitive touch displays. The scroll view obeyed the movements of your finger so closely, and it continued the motion seamlessly after you let go. From there, it decelerated in a natural way, and even exhibited a nice bounce when it hit its boundaries. Scrolling was responsive at any time and behaved just like an object from the real world.


## State of Animations

Most animations in iOS still don't live up to the standard that scrolling set on the original iPhone. 
They are fire-and-forget animations, which cannot be interacted with once they're running (for example the unlock animation, the animations opening and closing groups on the home screen, and the navigation controller animations, to name just a few).

However, there are some apps out there that bring that aspect of always in control, direct manipulation to all animations they use. It's a big difference in how these apps feel compared to the rest. Prominent examples of such apps are the original Twitter iPad app and the current Facebook Paper app. But for the time being, apps that fully embrace direct manipulation and always interruptible animations are still rare. This creates an opportunity for apps that do this well, as they have a very different, high-quality feel to them. 


## Challenges of Truly Interactive Animations

Using `UIView` or `CAAnimation` animations has two big problems when it comes to interactive animations: those animations separate what you see on the screen from what the actual spacial properties are on the layer, and they directly manipulate the spacial properties.


### Separation of Model and Presentation

Core Animation is designed in a way that it decouples the layer's model properties from what you see on the screen (the presentation layer). This makes it more difficult to create animations you can interact with at any time, because those two representations do not match. It's up to you to do the manual work to get them in sync before you change the animation:

    view.layer.center = view.layer.presentationLayer.center;
    [view.layer removeAnimationForKey:@"animation"];
    // add new animation...


### Direct vs. Indirect Control

The bigger problem with `CAAnimation` animations is that they directly operate on the spatial properties of a layer. This means, for example, that you specify that a layer should animate from position `(100, 100)` to position `(300, 300)`. If you want to stop this animation halfway and to animate the layer back to where it came from, things get very complicated. If you simply remove the current animation and add a new animation, then the layer's velocity would be discontinuous.

<img src="{{site.images_path}}/issue-12/abrupt.png" width="600" />

What we want to have, though, is a nice, smooth deceleration and acceleration.

<img src="{{site.images_path}}/issue-12/smooth.png" width="600" />

This only becomes feasible once you start controlling animations *indirectly*, i.e. through simulated forces acting on the view. The new animation needs to take the layer's current velocity *vector* as input in order to produce a smooth result.

Looking at the `UIView` animation API for spring animations (`animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:`), you'll notice that the velocity is a `CGFloat`. So while you can give the animation an initial velocity in the direction the animation moves the view, you cannot tell the animation that the view is, for example, currently moving at a certain velocity perpendicular to the new animation direction. In order to enable this, the velocity needs to be expressed as a vector.


## Solutions

So let's take a look at how we can correctly implement interactive and interruptible animations. To do this, we're going to build something like the Control Center panel:

<center><video style="display:block;max-width:100%;height:auto;border:0;" controls="1">
  <source src="{{site.images_path}}/issue-12/interactive-animation.mov"></source>
</video></center>

The panel has two states: opened and closed. You can toggle the states by tapping it, or dragging it up and down. The challenge is to make everything interactive, even while animating. For example, if you tap the panel while it's animating to the opened state, it should animate back to the closed state from its current position. In a lot of apps that use default animation APIs, you'll have to wait until the animation is finished before you can do anything. Or, if you don't have to wait, the animation exhibits a discontinuous velocity curve. We want to work around this.


### UIKit Dynamics

With iOS 7, Apple introduced the animation framework UIKit Dynamics (see WWDC 2013 sessions [206](https://developer.apple.com/videos/wwdc/2013/index.php?id=206) and [221](https://developer.apple.com/videos/wwdc/2013/index.php?id=221)). UIKit Dynamics is based on a pseudo-physics engine that can animate everything that implements the [`UIDynamicItem`](https://developer.apple.com/library/ios/documentation/uikit/reference/UIDynamicItem_Protocol/Reference/Reference.html) protocol by adding specific behaviors to an animator object. This framework is very powerful and enables complex behaviors of many items like attachments and collisions. Take a look at the sample [dynamics catalog](https://developer.apple.com/library/ios/samplecode/DynamicsCatalog/Introduction/Intro.html) to see what's available.

Since animations with UIKit Dynamics are driven indirectly, as we discussed above, this enables us to implement truly interactive animations that can be interrupted and that exhibit continuous acceleration behavior at any time. At the same time, the abstraction of UIKit Dynamics at the physics level can also seem overwhelming for the kind of animations that we generally need in user interfaces. In most cases, we'll only use a very small subset of its capabilities.


#### Defining Behaviors

In order to implement our sliding-panel behavior, we'll make use of two different behaviors that come with UIKit Dynamics: [`UIAttachmentBehavior`](https://developer.apple.com/library/ios/documentation/uikit/reference/UIAttachmentBehavior_Class/Reference/Reference.html) and [`UIDynamicItemBehavior`](https://developer.apple.com/library/ios/documentation/uikit/reference/UIDynamicItemBehavior_Class/Reference/Reference.html). The attachment behavior fulfills the role of a spring, pulling our view toward its target point. The dynamic item behavior, on the other hand, defines intrinsic properties of the view, such as its friction coefficient.

To package these two behaviors for our sliding panel, we'll create our own behavior subclass:

    @interface PaneBehavior : UIDynamicBehavior
    
    @property (nonatomic) CGPoint targetPoint;
    @property (nonatomic) CGPoint velocity;
    
    - (instancetype)initWithItem:(id <UIDynamicItem>)item;
    
    @end

We initialize this behavior with one dynamic item and then can set its target point and velocity to whatever we want. Internally, we create the attachment behavior and the dynamic item behavior and add both as child behavior to our custom behavior:

    - (void)setup
    {
        UIAttachmentBehavior *attachmentBehavior = [[UIAttachmentBehavior alloc] initWithItem:self.item attachedToAnchor:CGPointZero];
        attachmentBehavior.frequency = 3.5;
        attachmentBehavior.damping = .4;
        attachmentBehavior.length = 0;
        [self addChildBehavior:attachmentBehavior];
        self.attachmentBehavior = attachmentBehavior;
        
        UIDynamicItemBehavior *itemBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self.item]];
        itemBehavior.density = 100;
        itemBehavior.resistance = 10;
        [self addChildBehavior:itemBehavior];
        self.itemBehavior = itemBehavior;
    }

In order to make the `targetPoint` and `velocity` properties affect the item's behavior, we overwrite their setters and modify the corresponding properties on the attachment and item behaviors, respectively. For the target point, this is very simple:

    - (void)setTargetPoint:(CGPoint)targetPoint
    {
        _targetPoint = targetPoint;
        self.attachmentBehavior.anchorPoint = targetPoint;
    }

For the velocity property, we have to jump through one more hoop, since the dynamic item behavior only allows relative changes in velocity. That means that in order to set the velocity to an absolute value, we first have to get its current velocity and then add the difference to the target velocity:

    - (void)setVelocity:(CGPoint)velocity
    {
        _velocity = velocity;
        CGPoint currentVelocity = [self.itemBehavior linearVelocityForItem:self.item];
        CGPoint velocityDelta = CGPointMake(velocity.x - currentVelocity.x, velocity.y - currentVelocity.y);
        [self.itemBehavior addLinearVelocity:velocityDelta forItem:self.item];
    }


#### Putting the Behavior to Use

Our sliding panel has three different states: it is at rest in one of its end positions, being dragged by the user, or animating without the user's interaction toward one of its end points.

At the transition from the direct manipulation state (the user dragging the panel) to the animation state, we have to do some extra work to make sure that the panel exhibits a smooth animation behavior. When the user stops dragging the panel, it sends a message to its delegate. Within this method, we decide toward what position the panel should animate and add our custom `PaneBehavior` with this endpoint and -- very important -- the initial velocity, in order to ensure a smooth transition from dragging to animation:

    - (void)draggableView:(DraggableView *)view draggingEndedWithVelocity:(CGPoint)velocity
    {
        PaneState targetState = velocity.y >= 0 ? PaneStateClosed : PaneStateOpen;
        [self animatePaneToState:targetState initialVelocity:velocity];
    }

    - (void)animatePaneToState:(PaneState)targetState initialVelocity:(CGPoint)velocity
    {
        if (!self.paneBehavior) {
            PaneBehavior *behavior = [[PaneBehavior alloc] initWithItem:self.pane];
            self.paneBehavior = behavior;
        }
        self.paneBehavior.targetPoint = [self targetPointForState:targetState];
        if (!CGPointEqualToPoint(velocity, CGPointZero)) {
            self.paneBehavior.velocity = velocity;
        }
        [self.animator addBehavior:self.paneBehavior];
        self.paneState = targetState;
    }

As soon as the user puts his or her finger down on the panel again, we have to remove the dynamic behavior from the animator, in order to not interfere with the pan gesture:

    - (void)draggableViewBeganDragging:(DraggableView *)view
    {
        [self.animator removeAllBehaviors];
    }
    
We not only allow the panel to be dragged, but it can also be tapped to toggle from one position to the other. When a tap happens, we immediately adjust the panel's target position. Since we don't control the animation directly, but via spring and friction forces, the animation will proceed smoothly without abruptly reversing its movement:

    - (void)didTap:(UITapGestureRecognizer *)tapRecognizer
    {
        PaneState targetState = self.paneState == PaneStateOpen ? PaneStateClosed : PaneStateOpen;
        [self animatePaneToState:targetState initialVelocity:CGPointZero];
    }

And that's pretty much all there is to it. You can check out the whole example project on [GitHub](https://github.com/objcio/issue-12-interactive-animations-uidynamics). 

To reiterate the crucial point: UIKit Dynamics allows us to drive the animation indirectly by simulating forces on the view (in our case, spring and friction forces). This indirection enables us to interact with the view at any time while maintaining a continuous velocity curve.

Now that we have implemented this interaction with UIKit Dynamics, we'll take a look behind the scenes. Animations like the one in our example only use a tiny fraction of UIKit Dynamic's capabilities, and it's surprisingly simple to implement them yourself. That's a good exercise to understand what's going on, but it can also be necessary if you either don't have UIKit Dynamics available (e.g. on the Mac) or it's not a good abstraction for your use case.



### Driving Animations Yourself

As for the animations you'll use most of the time in your apps, e.g. simple spring animations, it's surprisingly not difficult to drive those yourself. It's a good exercise to lift the lid of the huge black box of UIKit Dynamics and to see what it takes to implement simple interactive animations 'manually.' The idea is rather easy: we make sure to change the view's frame 60 times per second. For each frame, we adjust the view's frame based on the current velocity and the forces acting on the view.


#### The Physics

Let's first take a look at some basic physics necessary to drive a spring animation like we created before using UIKit Dynamics. To simplify things, we'll look at a purely one-dimensional case (as it is the case in our example), although introducing the second dimension is straightforward.

The objective is to calculate the new position of the panel based on its current position and the time that has elapsed since the last animation tick. This can be expressed as:

    y = y0 + Δy

The position delta is a function of the velocity and the time:
 
    Δy = v ⋅ Δt
    
The velocity can be calculated as the previous velocity plus the velocity delta, caused by the force acting on the view:

    v = v0 + Δv

The change in velocity can be calculated by the impulse applied to the view:

    Δv = (F ⋅ Δt) / m
    
Now, let's take a look at the force acting on the view. In order to get the spring effect, we have to combine a spring force with friction force:

    F = F_spring + F_friction

The spring force comes straight from the textbook:

    F_spring = k ⋅ x

where `k` is the spring constant and `x` is the distance of the view to its target end point (the length of the spring). Therefore, we can also write this as:

    F_spring = k ⋅ abs(y_target - y0)

We calculate friction as being proportional to the view's velocity:

    F_friction = μ ⋅ v

`μ` is a simple friction constant. You could come up with other ways to calculate the friction force, but this works well to create the animation we want to have.

Putting this together, the force on the view is calculated as:

    F = k ⋅ abs(y_target - y0) + μ ⋅ v

To simplify things a bit more, we'll set the view's mass to `1`, so that we can calculate the change in position as:

    Δy = (v0 + (k ⋅ abs(y_target - y0) + μ ⋅ v) ⋅ Δt) ⋅ Δt


#### Implementing the Animation

To implement this, we first create our own `Animator` class, which drives the animations. This class uses a `CADisplayLink`, which is a timer made specifically for drawing synchronously with the display's refresh rate. In other words, if your animation is smooth, the timer calls your methods 60 times per second. Next, we implement a protocol `Animation` that works together with our `Animator`. This protocol has only one method, `animationTick:finished:`. This method gets called every time the screen is updated, and gets two parameters: the first parameter is the duration of the previous frame, while the second parameter is a pointer to a `BOOL`. By setting the value of the pointer to `YES`, we can communicate back to the `Animator` that we're done animating:

    @protocol Animation <NSObject>
    - (void)animationTick:(CFTimeInterval)dt finished:(BOOL *)finished;
    @end

The method is implemented below. First, based on the time interval, we calculate a force, which is a combination of the spring force and the friction force. Then we update the velocity with this force, and adjust the view's center accordingly. Finally, if the speed gets low and the view is at its goal, we stop the animation:

    - (void)animationTick:(CFTimeInterval)dt finished:(BOOL *)finished
    {
        static const float frictionConstant = 20;
        static const float springConstant = 300;
        CGFloat time = (CGFloat) dt;
    
        // friction force = velocity * friction constant
        CGPoint frictionForce = CGPointMultiply(self.velocity, frictionConstant);
        // spring force = (target point - current position) * spring constant
        CGPoint springForce = CGPointMultiply(CGPointSubtract(self.targetPoint, self.view.center), springConstant);
        // force = spring force - friction force
        CGPoint force = CGPointSubtract(springForce, frictionForce);

        // velocity = current velocity + force * time / mass
        self.velocity = CGPointAdd(self.velocity, CGPointMultiply(force, time));
        // position = current position + velocity * time
        self.view.center = CGPointAdd(self.view.center, CGPointMultiply(self.velocity, time));
    
        CGFloat speed = CGPointLength(self.velocity);
        CGFloat distanceToGoal = CGPointLength(CGPointSubtract(self.targetPoint, self.view.center));
        if (speed < 0.05 && distanceToGoal < 1) {
            self.view.center = self.targetPoint;
            *finished = YES;
        }
    }

That's all there is to it. We capsulated this method in a `SpringAnimation` object. The only other method in this object is the initializer, which takes the view to animate, the target point for the view's center (in our case, it's either the center point for the opened state, or the closed state), and the initial velocity.

#### Adding the Animation to the View

Our view class is exactly the same as in the UIDynamics example: it has a pan recognizer and updates its center based on the pan gestures. It sends out the same two delegate methods, which we will implement to initialize our animation. First of all, when the user starts dragging, we cancel all animations:

    - (void)draggableViewBeganDragging:(DraggableView *)view
    {
        [self cancelSpringAnimation];
    }

After the dragging ends, we start our animation with the last velocity value from the pan gesture. The target point is calculated from the `paneState`:

    - (void)draggableView:(DraggableView *)view draggingEndedWithVelocity:(CGPoint)velocity
    {
        PaneState targetState = velocity.y >= 0 ? PaneStateClosed : PaneStateOpen;
        self.paneState = targetState;
        [self startAnimatingView:view initialVelocity:velocity];
    }

    - (void)startAnimatingView:(DraggableView *)view initialVelocity:(CGPoint)velocity
    {
        [self cancelSpringAnimation];
        self.springAnimation = [UINTSpringAnimation animationWithView:view target:self.targetPoint velocity:velocity];
        [view.animator addAnimation:self.springAnimation];
    }

The only thing left to do is add the tap animation and that is relatively easy. We toggle the state and start animating. If there is a spring animation, we start with that velocity. If the spring animation is nil, the initial velocity will be CGPointZero. To understand why it still animates, look at the `animationTick:finished:` code. When the initial velocity is zero, the spring force will slowly keep increasing the velocity until the pane arrives at the target center point:

    - (void)didTap:(UITapGestureRecognizer *)tapRecognizer
    {
        PaneState targetState = self.paneState == PaneStateOpen ? PaneStateClosed : PaneStateOpen;
        self.paneState = targetState;
        [self startAnimatingView:self.pane initialVelocity:self.springAnimation.velocity];
    }

#### The Animation Driver

Finally, the last part we need is the `Animator`, which is the driver of the animations. The animator is a wrapper around the display link. Because each display link is coupled to a specific `UIScreen`, we initialize our animator with a specific screen. We set up a display link, and add it to the run loop. Because there are no animations yet, we start in a paused state: 

    - (instancetype)initWithScreen:(UIScreen *)screen
    {
        self = [super init];
        if (self) {
            self.displayLink = [screen displayLinkWithTarget:self selector:@selector(animationTick:)];
            self.displayLink.paused = YES;
            [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
            self.animations = [NSMutableSet new];
        }
        return self;
    }

Once we add the animation, we make sure that the display link is not paused anymore:

    - (void)addAnimation:(id<Animation>)animation
    {
        [self.animations addObject:animation];
        if (self.animations.count == 1) {
            self.displayLink.paused = NO;
        }
    }

We set up the display link to call `animationTick:`, and on each tick we iterate over the animations, send them a message, and that's it. If there are no animations left, we pause the display link:

     - (void)animationTick:(CADisplayLink *)displayLink
     {
         CFTimeInterval dt = displayLink.duration;
         for (id<Animation> a in [self.animations copy]) {
             BOOL finished = NO;
             [a animationTick:dt finished:&finished];
             if (finished) {
                 [self.animations removeObject:a];
             }
         }
         if (self.animations.count == 0) {
             self.displayLink.paused = YES;
         }
     }

The entire project is available on [GitHub](https://github.com/objcio/issue-12-interactive-animations).


#### Tradeoffs

It's important to keep in mind that driving animations via display links (as demonstrated above or by using UIKit Dynamics or something like Facebook's POP framework) comes with a tradeoff. As [Andy Matuschak pointed out](https://twitter.com/andy_matuschak/status/464790108072206337) `UIView` and `CAAnimation` animations are less likely to be affected by other tasks running on the system, because the render server runs at a higher priority than your app. 


### Back to the Mac

There's nothing like UIKit Dynamics available on Mac at this time. If you want
to create truly interactive animations here, you have to take the route of
driving those animations yourself.  Now that we've already shown how to
implement this on iOS, it's very simple to make the same example work on OS X; check out the [full project](https://github.com/objcio/issue-12-interactive-animations-osx) on GitHub. These are the things that need to be changed:

* The first thing to change is the `Animator`. On the Mac, there is no `CADisplayLink`, but instead, a `CVDisplayLink`, which has a C-based API. Setting it up is a bit more work, but just as straightforward.
* Our spring animation on iOS adjusts the center of the view. An `NSView` doesn't have a center property, so instead we animate the frame's origin.
* On the Mac, there are no gesture recognizers. Instead, we have to implement `mouseDown:`, `mouseUp:`, and `mouseDragged:` in our custom view subclass.

These are the only changes we need to make to port our animation code to the Mac. For a simple view like this, it works really well. For more complex things, you might not want to animate the frame, but use `transform` instead, which is the topic of a blogpost on [OS X Animations](http://jwilling.com/osx-animations) by Jonathan Willing.


### Facebook's POP Framework

There has been quite a bit of buzz in the last weeks around Facebook's [POP framework](https://github.com/facebook/pop). This is the animation engine that powers its Paper app. It operates very similar to the example above of driving your own animations, but it comes in a neat package with a lot more flexibility. 

So, let's try to make our own manually driven animation work with POP instead. Since we already had our own spring animation packaged into its own class, the change is pretty trivial. All we have to do is instantiate a POP animation instead of our own one, and add this to the view:

    - (void)animatePaneWithInitialVelocity:(CGPoint)initialVelocity
    {
        [self.pane pop_removeAllAnimations];
        POPSpringAnimation *animation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewCenter];
        animation.velocity = [NSValue valueWithCGPoint:initialVelocity];
        animation.toValue = [NSValue valueWithCGPoint:self.targetPoint];
        animation.springSpeed = 15;
        animation.springBounciness = 6;
        [self.pane pop_addAnimation:animation forKey:@"animation"];
        self.animation = animation;
    }

You can find the full working example using POP on [GitHub](https://github.com/objcio/issue-12-interactive-animations-pop).

It's super easy to get it to work, and it's pretty straightforward to create more complex animations. But the real power of it lies in the fact that it enables you to create truly interactive and interruptible animations, as we have talked about before, because the animations it supports out of the box take the velocity as input. If you plan your interactions from the get-go to be interruptible at any time, a framework like POP helps you to implement this in a way that ensures animations always stay smooth.

If you need more than what `POPSpringAnimation` and `POPDecayAnimation` can do out of the box, POP also comes with a `POPCustomAnimation` class, which basically is a convenient wraparound display link to drive your own animation in a callback block that gets called on each animation tick.


## The Road Ahead

With iOS 7's shift away from visual imitation of real-world objects toward a stronger focus on the UI's behavior, truly interactive animations are a great way to stand out. They're also a way to extend the magic of the original iPhone's scrolling behavior into every aspect of the interaction. To make this work, it's important to consider those interactions early on in the design instead of just bolting on animations late in the development process.

A special thanks goes to [Loren Brichter](https://twitter.com/lorenb) for his advice on this article!

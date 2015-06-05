---
title:  "Custom Container View Controller Transitions"
category: "12"
date: "2014-05-08 09:00:00"
tags: article
author:
  - name: Joachim Bondo
    url: https://twitter.com/osteslag
---

In [issue #5](/issues/5-ios7/), [Chris Eidhof](http://twitter.com/chriseidhof) took us through the new custom [View Controller Transitions](/issues/5-ios7/view-controller-transitions/) in iOS 7. He [concluded](/issues/5-ios7/view-controller-transitions/#conclusion) (emphasis mine):

> We only looked at animating between two view controllers in a navigation controller, but **you can do the same for** tab bar controllers or **your own custom container view controllers**…

While it is technically true that you can customize the transition between two view controllers in custom containment, if you're using the iOS 7 API, it is not supported out of the box. Far from. 

Note that I am talking about custom container view controllers as direct subclasses of `UIViewController`, not `UITabBarController` or `UINavigationController` subclasses.

There is no ready-to-use API for your custom container `UIViewController` subclass that allows an arbitrary *animation controller* to automatically conduct the transition from one of your child view controllers to another, interactively or non-interactively. I am tempted to say it was not even Apple’s intention to support it. What is supported are the following transitions:

- Navigation controller pushes and pops
- Tab bar controller selection changes
- Modal presentations and dismissals

In this chapter I will demonstrate how you *can* build a custom container view controller yourself while supporting third-party animation controllers.

If you need to brush up on view controller containment, introduced in iOS 5, make sure to read [Ricky Gregersen](https://twitter.com/rickigregersen)’s “[View Controller Containment](/issues/1-view-controllers/containment-view-controller/)” in the very [first issue](/issues/1-view-controllers/).

## Before We Begin

You may ask yourself a question or two at this point, so let me answer them for you:

*Why not just subclass `UINavigationController` or `UITabBarController` and get the support for free?*

Well, sometimes that’s just not what you want. Maybe you want a very specific appearance or behavior, far from what these classes offer, and therefore would have to resort to tricky hacking, risking it to break with any new version of the framework. Or maybe you just want to be in total control of your containment and avoid having to support specialized functionality.

*OK, but then why not just use `transitionFromViewController:toViewController:duration:options:animations:completion:` and be over with it?*

Another good question, and you may just want to do that. But perhaps you care about your code and want to encapsulate the transition. So why not use a now-established and well-proven design pattern? And, heck, as a bonus, have support for third-party transition animations thrown in for free.

## Introducing the API

Now, before we start coding – and we will in a minute, I promise – let's set the scene.

The components of the iOS 7 custom view controller transition API are mostly protocols which make them extremely flexible to work with, because you can very easily plug them into your existing class hierarchy. The five main components are:

1. **Animation Controllers** conforming to the `UIViewControllerAnimatedTransitioning` protocol and in charge of performing the actual animations.

2. **Interaction Controllers** controlling the interactive transitions by conforming to the `UIViewControllerInteractiveTransitioning` protocol.

3. **Transitioning Delegates** conveniently vending animation and interaction controllers, depending on the kind of transition to be performed.

4. **Transitioning Contexts** defining metadata about the transition, such as properties of the view controllers and views participating in the transition. These objects conform to the `UIViewControllerContextTransitioning` protocol, *and are created and provided by the system*.

5. **Transition Coordinators** providing methods to run other animations in parallel with the transition animations. They conform to the `UIViewControllerTransitionCoordinator` protocol.

As you know, from otherwise reading this publication, there are interactive and non-interactive transitions. In this article, we will concentrate on non-interactive transitions. These are the simplest, so they're a great place to start. This means that we will be dealing with *animation controllers*, *transitioning delegates*, and *transitioning contexts* from the list above.

Enough talk, let’s get our hands dirty…

## The Project

In three stages, we will be creating a sample app featuring a custom container view controller, which implements support for custom child view controller transition animations.

The Xcode project, in its three stages, is put in a [repository on GitHub](https://github.com/objcio/issue-12-custom-container-transitions).

### Stage 1: The Basics

The central class in our app is `ContainerViewController`, which hosts an array of `UIViewController` instances -- in our case, trivial `ChildViewController` objects. The container view controller sets up a private subview with tappable icons representing each child view controller:

![Stage 1: no animation](/images/issue-12/2014-05-01-custom-container-view-controller-transitions-stage-1.gif)

To switch between child view controllers, tap the icons. At this stage, there is no transition animation when switching child view controllers.

Check out the [stage-1](https://github.com/objcio/issue-12-custom-container-transitions/tree/stage-1) tag to see the code for the basic app.

### Stage 2: Animating the Transition

When adding a transition animation, we want to support *animation controllers* conforming to `UIViewControllerAnimatedTransitioning`. The protocol defines these three methods, the first two of which are required:

```objc
- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext;
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext;
- (void)animationEnded:(BOOL)transitionCompleted;
```

This tells us everything we need to know. When our container view controller is about to perform the animation, we can query the animation controller for the duration and ask it to perform the actual animation. When it is done, we can call `animationEnded:` on the the animation controller, if it implements that optional method.

However, there is one thing we need to figure out first. As you can see from the method signatures above, the two required ones take a *transitioning context* parameter, i.e., an object conforming to `UIViewControllerContextTransitioning`. Normally, when using the built-in classes, the framework creates and passes on this context to our animation controller for us. But in our case, since we are acting as the framework, *we* need to create that object.

This is where the convenience of the heavy use of protocols comes in. Instead of having to override a private class, which obviously is a no-go, we can make our own and just have it conform to the documented protocol.

There are a [lot of methods](https://developer.apple.com/library/ios/documentation/uikit/reference/UIViewControllerContextTransitioning_protocol/Reference/Reference.html), though, and they are all required. But we can ignore some of them for now, because we are currently only supporting non-interactive transitions.

Just like UIKit, we define a private `NSObject <UIViewControllerContextTransitioning>` class. In our specialized case, it is the `PrivateTransitionContext` class, and the initializer is implemented like this:

```objc
- (instancetype)initWithFromViewController:(UIViewController *)fromViewController toViewController:(UIViewController *)toViewController goingRight:(BOOL)goingRight {
    NSAssert ([fromViewController isViewLoaded] && fromViewController.view.superview, @"The fromViewController view must reside in the container view upon initializing the transition context.");
    
    if ((self = [super init])) {
        self.presentationStyle = UIModalPresentationCustom;
        self.containerView = fromViewController.view.superview;
        self.viewControllers = @{
            UITransitionContextFromViewControllerKey:fromViewController,
            UITransitionContextToViewControllerKey:toViewController,
        };
        
        CGFloat travelDistance = (goingRight ? -self.containerView.bounds.size.width : self.containerView.bounds.size.width);
        self.disappearingFromRect = self.appearingToRect = self.containerView.bounds;
        self.disappearingToRect = CGRectOffset (self.containerView.bounds, travelDistance, 0);
        self.appearingFromRect = CGRectOffset (self.containerView.bounds, -travelDistance, 0);
    }
    
    return self;
}
```

We basically capture state, including initial and final frames, for the appearing and disappearing views.

Notice, our initializer requires information about whether we are going right or not. In our specialized `ContainerViewController` context, where buttons are arranged horizontally next to each other, the transition context is recording information about their positional relationship by setting the respective frames. The animation controller, or *animator*, can choose to use this when composing the animation. 

We could gather this information in other ways, but it would require the animator to know about the `ContainerViewController` and its view controllers, and we don’t want that. The animator should only concern itself with the context, which is passed to it, because that would, ideally, make the animator reusable in other contexts.

We will keep this in mind when making our own animation controller next, now that we have the transition context available to us.

You probably remember that this was exactly what we did in [View Controller Transitions](/issues/5-ios7/view-controller-transitions/), [issue #5](/issues/5-ios7/). So why not just use that? In fact, because of the extensive use of protocols in this framework, we can take the animation controller, the `Animator` class, from that project and plug it right in to ours – without any modifications.

Using an `Animator` instance to animate our transition essentially looks like this:

```objc
[fromViewController willMoveToParentViewController:nil];
[self addChildViewController:toViewController];

Animator *animator = [[Animator alloc] init];

NSUInteger fromIndex = [self.viewControllers indexOfObject:fromViewController];
NSUInteger toIndex = [self.viewControllers indexOfObject:toViewController];
PrivateTransitionContext *transitionContext = [[PrivateTransitionContext alloc] initWithFromViewController:fromViewController toViewController:toViewController goingRight:toIndex > fromIndex];

transitionContext.animated = YES;
transitionContext.interactive = NO;
transitionContext.completionBlock = ^(BOOL didComplete) {
    [fromViewController.view removeFromSuperview];
    [fromViewController removeFromParentViewController];
    [toViewController didMoveToParentViewController:self];
};

[animator animateTransition:transitionContext];
```

Most of this is the required container view controller song and dance, and finding out whether we going left or right. Doing the animation is basically three lines of code: 1) creating the animator, 2) creating the transition context, and 3) triggering the animation.

With that, the transition now looks like this:

![Stage 2: third-party animation](/images/issue-12/2014-05-01-custom-container-view-controller-transitions-stage-2.gif)

Pretty cool. We haven’t even written any animation code ourselves!

This is reflected in the code with the [stage-2](https://github.com/objcio/issue-12-custom-container-transitions/tree/stage-2) tag. To see the full extent of the stage 2 changes, check the [diff against stage 1](https://github.com/objcio/issue-12-custom-container-transitions/compare/stage-1...stage-2).

### Stage 3: Shrink-Wrapping

One last thing I think we should do is shrink-wrapping `ContainerViewController` so that it:

1. comes with its own default transition animation, and
2. supports a delegate for vending alternative animation controllers.

This entails conveniently removing the dependency to the `Animator` class, as well as creating a delegate protocol.

We define our protocol as:

```objc
@protocol ContainerViewControllerDelegate <NSObject>
@optional
- (void)containerViewController:(ContainerViewController *)containerViewController didSelectViewController:(UIViewController *)viewController;
- (id <UIViewControllerAnimatedTransitioning>)containerViewController:(ContainerViewController *)containerViewController animationControllerForTransitionFromViewController:(UIViewController *)fromViewController toViewController:(UIViewController *)toViewController;
@end
```

The `containerViewController:didSelectViewController:` method just makes it easier to integrate `ContainerViewController` into more feature-complete apps. 

The interesting method is `containerViewController:animationControllerForTransitionFromViewController:toViewController:`, of course, which can be compared to the following container view controller delegate protocol methods in UIKit:

- `tabBarController:animationControllerForTransitionFromViewController:toViewController:` (`UITabBarControllerDelegate`)
- `navigationController:animationControllerForOperation:fromViewController:toViewController:` (`UINavigationControllerDelegate`)

All these methods return an `id<UIViewControllerAnimatedTransitioning>` object.

Instead of always using an `Animator` object, we can now ask our delegate for an animation controller:

```objc
id<UIViewControllerAnimatedTransitioning>animator = nil;
if ([self.delegate respondsToSelector:@selector (containerViewController:animationControllerForTransitionFromViewController:toViewController:)]) {
    animator = [self.delegate containerViewController:self animationControllerForTransitionFromViewController:fromViewController toViewController:toViewController];
}
animator = (animator ?: [[PrivateAnimatedTransition alloc] init]);
```

If we have a delegate, and it returns an animator, we will use that. Otherwise, we will create our own private default animator of class `PrivateAnimatedTransition`. We will implement this next.

Although the default animation is somewhat different than that of `Animator`, the code looks surprisingly similar. Here is the full implementation:

```objc
@implementation PrivateAnimatedTransition

static CGFloat const kChildViewPadding = 16;
static CGFloat const kDamping = 0.75f;
static CGFloat const kInitialSpringVelocity = 0.5f;

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return 1;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    
    UIViewController* toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController* fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    
    // When sliding the views horizontally, in and out, figure out whether we are going left or right.
    BOOL goingRight = ([transitionContext initialFrameForViewController:toViewController].origin.x < [transitionContext finalFrameForViewController:toViewController].origin.x);
    
    CGFloat travelDistance = [transitionContext containerView].bounds.size.width + kChildViewPadding;
    CGAffineTransform travel = CGAffineTransformMakeTranslation (goingRight ? travelDistance : -travelDistance, 0);
    
    [[transitionContext containerView] addSubview:toViewController.view];
    toViewController.view.alpha = 0;
    toViewController.view.transform = CGAffineTransformInvert (travel);
    
    [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0 usingSpringWithDamping:kDamping initialSpringVelocity:kInitialSpringVelocity options:0x00 animations:^{
        fromViewController.view.transform = travel;
        fromViewController.view.alpha = 0;
        toViewController.view.transform = CGAffineTransformIdentity;
        toViewController.view.alpha = 1;
    } completion:^(BOOL finished) {
        fromViewController.view.transform = CGAffineTransformIdentity;
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }];
}

@end
```

Note that even if the view frames haven’t been set to reflect the positional relationships, the code would still work, though it would always transition in the same direction. This class can therefore still be used in other codebases.

The transition animation now looks like this:

![Stage 3: third-party animation](/images/issue-12/2014-05-01-custom-container-view-controller-transitions-stage-3.gif)

In the code with the [stage-3](https://github.com/objcio/issue-12-custom-container-transitions/tree/stage-3) tag, setting the delegate in the app delegate has been [commented out](https://github.com/objcio/issue-12-custom-container-transitions/blob/stage-3/Container%20Transitions/AppDelegate.m#L41) in order to see the default animation in action. Set it back in to use `Animator` again. You may want to check out the [full diff against stage-2](https://github.com/objcio/issue-12-custom-container-transitions/compare/stage-2...stage-3).

We now have a self-contained `ContainerViewController` with a nicely animated default transition that developers can override with their own, iOS 7 custom animation controller (`UIViewControllerAnimatedTransitioning`) objects – even without needing access to our source code.

## Conclusion

In this article we looked at making our custom container view controller a first-class UIKit citizen by integrating it with the Custom View Controller Transitions, new in iOS 7.

This means you can apply your own non-interactive transition animation to our custom container view controller. We saw that because we could take an existing transition class, from seven issues ago, and plug it right in – without modification.

This is perfect if you are distributing your custom container view controller as part of a library or framework, or just want your code to be reusable.

Note that we only support non-interactive transitions so far. The next step is supporting interactive transitions as well.

I will leave that as an exercise for you. It is somewhat more complex because we are basically mimicking the framework behavior, which is all guesswork, really.

**Update:** [Alek Åström](https://twitter.com/MisterAlek) was quick to take on the challenge and has posted a very interesting article, “[Interactive Custom Container View Controller Transitions](http://www.iosnomad.com/blog/2014/5/12/interactive-custom-container-view-controller-transitions)”. As an added bonus, it includes a new exercise…

## Further Indulgence

- iOS 7 Tech Talks Videos, 2014: “[Architecting Modern Apps, Part 1](https://developer.apple.com/tech-talks/videos/index.php?id=3#3)” (07:23-31:27)
- Full code on [GitHub](https://github.com/objcio/issue-12-custom-container-transitions).
- Follow-up article by [Alek Åström](https://twitter.com/MisterAlek): “[Interactive Custom Container View Controller Transitions](http://www.iosnomad.com/blog/2014/5/12/interactive-custom-container-view-controller-transitions)”.

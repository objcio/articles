---
layout: post
title:  "Custom Container View Controller Animations"
category: "12"
date: "2014-05-01 10:00:00"
tags: article
author: "<a href=\"https://twitter.com/osteslag\">Joachim Bondo</a>"
---

(Too long working title:)
# Custom Container View Controller Animations, iOS 7 style

In [issue #5](http://www.objc.io/issue-5/index.html), [Chris Eidhof](http://twitter.com/chriseidhof) took us through the new custom [View Controller Transitions](http://www.objc.io/issue-5/view-controller-transitions.html) in iOS 7. He [concluded](http://www.objc.io/issue-5/view-controller-transitions.html#conclusion) (emphasis mine):

> We only looked at animating between two view controllers in a navigation controller, but **you can do the same for** tab bar controllers or **your own custom container view controllers**…

While it is technically true, that you can customize the transition between two view controllers in custom containment, using the iOS 7 API, it is not supported out of the box. Far from. 

Note, that I am talking about custom container view controllers as direct subclasses of `UIViewController`. Not `UITabBarController` or `UINavigationController` subclasses.

There is no ready-to-use API for your custom container `UIViewController` subclass that allows an arbitrary *Animation Controller* to automatically conduct the transition from one of your child view controllers to another, interactively or non-interactively. I am tempted to say it was not even Apple’s intension to support it. What is supported, are the following transitions:

- Navigation controller pushes and pops
- Tab bar controller selection changes
- Modal presentations and dismissals

In this chapter I will demonstrate how you *can* build a custom container view controller yourself while supporting third-party animation controllers.

If you need to brush up on view controller containment, introduced in iOS 5, make sure to read [Ricky Gregersen](https://twitter.com/rickigregersen)’s “[View Controller Containment](http://www.objc.io/issue-1/containment-view-controller.html)” in the very [first issue](http://www.objc.io/issue-1/).

## Before We Begin

You may ask yourself a question or two at this point, so let me answer them for you:

**Why not just subclass `UINavigationController` or `UITabBarController` and get the support for free?**

Well, sometimes that’s just not what you want. Maybe you want a very specific appearance or behavior, far from what these classes offer, and therefore would have to resort to tricky hacking, risking it to break with any new version of the framework. Or maybe you just want to be in total control of your containment, let alone avoid having to support their specialized functionality.

**OK, but then why not just use `transitionFromViewController:toViewController:duration:options:animations:completion:` and be over with it?**

Another good question, and you may just want to do that. But perhaps you care about your code and want to encapsulate the transition. So why not use a now established and well-proven design pattern? And, heck, as a bonus have support for third-party transition animations thrown in for free.

## (Setting the Scene)

Now, before we start – and we will in a minute, I promise – let’s set the scene.

The components of the iOS 7 custom view controller transition API are mostly protocols which make them extremely flexible to work with because you can very easily plug them into your existing class hierarchy. The five main components are:

1. **Animation Controllers** which conform to the `UIViewControllerAnimatedTransitioning` protocol and are in charge of performing the actual animations.

2. **Interaction Controllers** controlling the interactive transitions by conforming to the `UIViewControllerInteractiveTransitioning` protocol.

3. **Transitioning Delegates** conveniently vending the animation and interaction controllers, depending on the kind of transition to be performed. [Note to self: when writing our custom code, talk about their conformance to `UIViewControllerTransitioningDelegate`, `UINavigationControllerDelegate` or `UITabBarControllerDelegate`, depending on the parent container view controller class.]

4. **Transitioning Contexts** defining meta data about the transition, such as properties of the view controllers and views participating in the transition. These conform to the `UIViewControllerContextTransitioning` protocol – *and are created and provided by the system*.

5. **Transition Coordinators** providing methods to run other animations in parallel to the transition animations. They conform to the `UIViewControllerTransitionCoordinator` protocol.

As you know, from otherwise reading this publication, there are interactive and non-interactive transitions. In this chapter, we will concentrate on non-interactive. These are the simplest, so it’s a great place to start. This means that we will be dealing with *animation controllers*, *transitioning delegates*, and *transitioning contexts* from the list above.

Enough talk, let’s get our hands dirty…

## The Exercise/Project/Code…

The central class in our sample app is `ContainerViewController`  which hosts an array of `UIViewController` instances, `ChildViewController` objects in our case. The container view controller sets up a subview containing tappable icons representing each child view controller:

[image]

To switch between child view controllers, tap the icons.

The code for our sample app is put in a [repository on GitHub](https://github.com/.../). To see the code at this stage, check out the [stage-1](http://github.com/.../tree/stage-1) tag. At this stage there is no transition animation when switching child view controllers.

[Note to self: use dynamic type properties in the code?]

### Stage 2: Animating the Transition

When adding a transition animation, we want to support *animation controllers* conforming to `UIViewControllerAnimatedTransitioning`. The protocol defines these three methods, of which the first two are required:

```objc
- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext;
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext;
- (void)animationEnded:(BOOL)transitionCompleted;
```

This tells us everything we need to know: when our container view controller is about to perform the animation, we will query the delegate for the duration and ask it to perform the actual animation. When it’s done, we can call `animationEnded:` on the animator, if it implements that optional method.

However, there is one thing we need to figure out first. As you noticed, the two required methods take a *transitioning context* parameter, i.e., an object conforming to `UIViewControllerContextTransitioning`. Normally, when using the built-in classes, the framework creates and passes on this context to our animator for us. But in our case we are acting as the framework, se *we* need to create that object.

Luckily, this is fairly easy because the protocol is [documented](https://developer.apple.com/library/ios/documentation/uikit/reference/UIViewControllerContextTransitioning_protocol/Reference/Reference.html). There is a lot of methods, though, and they are all required. We can ignore some of them for now, though, because we are currently only supporting non-interactive transitions.

TODO: Show the code to make our own, private `_TransitionContext` object.

With the transition context available to us now, we can perform our animation by implementing an *animation controller*.

Remember, that’s what we did in [View Controller Transitions](http://www.objc.io/issue-5/view-controller-transitions.html), [issue #5]((http://www.objc.io/issue-5/). So why not just use that? In fact, because the extensive use of protocols, we can use it without any modifications. The transition now looks like this:

[can we display gifs, and do we want to? this would loop the animated transition from VC 1 to VC 2 to VC 1 etc.]

This is reflected in the code with the [stage-2](https://github.com/.../tree/stage-2) tag. To see everything that was added for stage 2, check [the diff against stage 1](https://github.com/...).

### Scrap

```objc
if (self.delegate != nil) {
    NSTimeInterval duration = [delegate transitionDuration:transitionContext];
    
    [CATransaction begin];
    [CATransaction setAnimationDuration:duration];
    
    // TODO: Instead of setting the completion block, just call animationEnded: when our completeTransition: is called
    if (delegate respondsToSelector:@selector (animationEnded:)]) {
        [CATransaction setCompletionBlock:^{
            [delegate animationEnded:YES/NO];
        }];
    }
    
    [delegate animateTransition:transitionContext];
    [CATransaction commit];
}
```

### Stage 3: Wrapping Up

One last thing I think we should do…

- add, encapsulate and use own, private `UIViewControllerAnimatedTransitioning` animator (sporting an alternative, horizontal sliding animation)
- support external delegate (although we’ll comment out that line in `stage-3` to keep the new, default animation active).

[show the animated gif?]

Check out [stage-3](https://github.com/.../tree/stage-2) to see the project at this stage. The [full diff against stage-2 is here](https://github.com/...).

Now third-party developers can use our `ContainerViewController` class with their own, custom animation (`UIViewControllerAnimatedTransitioning`) objects – even without access to the source code. Just like we use UIKit.

## Conclusion

What did we just do? Our custom container view controller behaves like a UIKit class in that you can apply your custom non-interactive transition animation. We saw that because we could take an existing transition class, from seven issues ago, and plug it right in.

Next step is supporting interactive transitions. Somewhat more complex because we are basically mimicking the framework behavior which is all guesswork, really.

## Further Reading

- iOS 7 Tech Talks Videos, 2014: [“Architecting Modern Apps, Part 1”](https://developer.apple.com/tech-talks/videos/index.php?id=3#3) (07:23-31:27)
- Link to the repository on GitHub

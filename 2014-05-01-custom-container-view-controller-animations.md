---
layout: post
title:  "Custom Container View Controller Animations"
category: "12"
date: "2014-05-01 10:00:00"
tags: article
author: "<a href=\"https://twitter.com/osteslag\">Joachim Bondo</a>"
---

**Custom Container View Controller Animations, iOS 7 style**  
(Too long working title)

## Outline

Because of View Controller Transitions in issue #5, I can skip a bunch of introduction, [previously outlined](https://github.com/objcio/articles-private/commit/91a6ab25560126fb30d37bfa7542b18f16baee22). The outline is therefore now something along these lines:

1. Introduction of custom view controller transition animations
	- In issue 5 we talked about these transitions using a `UINavigationController`.
	- In this issue we will take it a step further and implement it for our own, custom container view controller.
	- Don’t remember what containment is? Go look in issue #1.
	- So, only the following transitions are readily supported:
		1. Navigation controller pushes, pops
		2. Tab bar controller selection changes (a first!)
		3. Modal presentations, dismissals
	- Framework support for custom container view controllers glaringly missing.
	- Why go through hoops to support the API for our custom container view controller in the first place?
		- Can’t/don’t want to subclass `UINavigationController` or `UINavigationController`.
		- Support third-party transition animations.
		- Use a established, well-proven design pattern.
	- Introduce the five components of the new API:
		- Animation controllers
		- Interaction controllers
		- Transitioning delegates
		- Transitioning contexts
		- Transition coordinators
	- We will only be doing non-interactive. To begin with. Refer to other chapter(s) in current issue for more on interactivity?

2. The code: a simple custom container view controller (the containment is not our focus point)
	- Implement a custom container view controller with default transition animation, prepared for third-party animation controllers.
	- Plug in custom animation controller.
	- Heck, why not take the `Animator` class from issue #5, unmodified, and plug that in!?

3. Final Words
	- Can we do this with interactive transitions? If so, how?

## Article

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

To be written.

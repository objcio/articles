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

1. Introduction of custom view controller transition animations
	- Pre-iOS 7: `animated:YES` only
	- iOS 7: new transition API, interactive and non-interactive
	- Mainly (exclusively?) protocols
	- Offers custom animations of:
		1. Navigation controller pushes, pops
		2. Tab bar controller selection changes (a first!)
		3. Modal presentations, dismissals

2. Components of the new API
	- Animation controllers
	- Interaction controllers
	- Transitioning delegates
	- Transitioning contexts
	- Transition coordinators

3. How to implement a custom transition animation
	- Implement on stock `UITabBarController` – yay, finally alive without unsupported trickery!
	- Non-interactive only, possibly explain what would be needed to make interactive. Refer to other chapter(s) in current issue?

4. How about support for custom containment view controller?
	- Refer to [Containment View Controller](https://github.com/objcio/articles-private/blob/master/2013-06-07-containment-view-controller.md), issue 1, for an explanation of containment. (use the project of Ricki Gregersen as a starting point?)
	- Framework support for custom container view controllers glaringly missing?
	- Why would we want to support it in our own controllers?
		- Your containment view controller does not descend from `UITabBarController` or `UINavigationController`, so the new API is not available.
		- Support third-party transition animations.
		- Use a familiar, well-proven design pattern.
	- Implement a custom container view controller with default transition animation, prepared for third-party animation controllers.
	- Plug in custom animation controller from bullet 3 above. Works without any modifications!

5. Final Words
	- Can we do this with interactive transitions? If so, how?

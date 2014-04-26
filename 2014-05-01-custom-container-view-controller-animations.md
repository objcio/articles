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

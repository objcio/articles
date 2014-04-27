---
layout: post
title:  "Interactive animations"
category: "12"
date: "2014-05-01 10:00:00"
tags: article
author: TODO
---

The magic of the original iPhone. 
Steve Jobs: "You got me at scrolling".
Scrolling felt so different than what existed before because it was true direct manipulation. The content obeys your finger.
Scrolling can be stopped at any time.
Scrolling can be performed at any velocity you can move your finger at.
Scrolling transitions without smoothly from direct manipulation to animation.

With iOS 7 highly refined visual design details became less important,  interaction and direct manipulation became more important. 
It's more about how an app behaves than how pretty it's graphics are.


## State of Animations

Most animations in iOS still don't live up to the standard that scrolling has set on the original iPhone. 
They are fire-and-forget animations, that cannot be interacted with once they're running.

However, there are some apps out there that bring that aspect of always in control, direct manipulation to all animations they use. It's a big difference in how these apps feel compared to the rest.
For example: Original Twitter for iPad, Facebook Paper.

For the time being, fully embracing direct manipulation and always interruptible animations is still a unique selling point. It gives your app a feel to it that not many others have.


## Challenges of Truly Interactive Animations

Using `UIView` or `CAAnimation` animations has too big problems when it comes to interactive animations: Those animations separate what you see on the screen from what the actual spacial properties are on the layer, and they directly manipulate the spacial properties.


### Separation of Model and Presentation

Core Animation is designed in a way that it decouples the layer's model properties from what you see on the screen (the presentation layer). 
This makes it more difficult to create animations you can interact with at any time, because those two representations do not match. 
It's up to you to do the manual work to get them in sync before you change the animation.
That's cumbersome to do, but not a knockout argument against using those animations.


### Direct vs. Indirect Control

The bigger problem with `CAAnimation` animations is that they directly operate on the spatial properties of a layer, i.e. you for example specify that a layer should animate from position `(100, 100)` to position `(300, 300)`. 
If you would want to stop this animation halfway and to animate the layer back to where it came from, things get very complicated. 
We don't want the layer to stop abruptly, but it should have a nice smooth deceleration and acceleration.

Illustrate animation curves.

This only becomes feasible once you start controlling animations indirectly, e.g. via a spring like physics. 
The new animation need to take the current layer's velocity *vector* as an input, as well as it's target position and the spring properties that control the dynamics of how the animation will go down.

Looking at the `UIView` animation API for spring animations (`animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:`) you'll notice that the velocity is a `CGFloat`.
It's not a vector, so you cannot tell the animation that the layer for example has an initial velocity that's moving it away from the target.


## Solutions

### UIKit Dynamics

iOS 7 introduced UIKit Dynamics which is a physics inspired animation engine for views.
It's a very powerful system that allows you to do much more complex things than what you'll need 99% of the time for animations in apps.
However, it's a system that perfectly allows us to create truly interactive animations, because animations are controlled indirectly by the views' "physical" properties and the properties of the interactions between them.

Simply using UIKit Dynamics doesn't automatically get you interactive animations tough. 
You have to put in the extra work of actually making the dynamics system react to touches at any time.

Show how to implement a control center style sliding panel with UIKit Dynamics.


### Driving Animations Yourself

For the animations you'll use most of the time in your apps, e.g. simple spring animations, it's actually surprisingly simple to drive those yourself.
It's a good exercise to lift the lid of the huge black box of UIKit Dynamics and to see what it takes to implement simple interactive animations "manually".

We're going to cheat on the math of the spring animation a bit to make it more simple, which is perfectly fine for our purposes. We don't need to have a real world physics simulation.
Explain the calculation of an animation tick with the layer's position and velocity as input.

Show the same control center style example from before with a manually driven animation.


### Back to the Mac

There's nothing like UIKit Dynamics available on Mac at this time. If you want to create truly interactive animations here, you have to take the route of driving those animations yourself.
Now that we've already shown how to implement this on iOS, it's very simple to make the same example work on OS X.

Show the example from before running on OS X.


## POP ?

Would be cool if we could say a few words about Facebook's POP framework. I've contacted Kimon Tsinteris about this, let's see if we can get something done here in time.


## The Road Ahead

With iOS 7's shift away from visual imitation of real world objects towards a stronger focus on the UI's behaviour, truly interactive animations are a great way to stand out.
It's a way to extend the magic of the original iPhone's scrolling behaviour into every aspect of the interaction.
Interactive animations are fulfilling the promise and increasingly the expectations of users that comes with touchscreen devices. 


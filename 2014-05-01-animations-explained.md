---
layout: post
title:  "Animations Explained"
category: "12"
date: "2014-05-01 10:00:00"
tags: article
author: "<a href=\"https://twitter.com/ceterum_censeo\">Robert Böhnke</a>"
---

# Animations Explained

The applications we write are rarely a static experience, they adapt to the users needs and change state to perform a multitude of tasks.

When transitioning between these states, it is important to communicate what is going on. Rather than jumping between screens, animations help us explain where the user is coming from and where they are going.

The keyboard slides in and out of view to give the illusion that it is a natural part of the phone that was just hidden below the screen. View controller transitions reinforce the navigational structure of our apps and give the user hints which in direction they are moving. Subtle bounces and collisions make interfaces life-like and evoke physical qualities in what is otherwise a felt-free environment.

Animations are a great way to tell the story of your application and by understanding basic the basic principles behind animation, designing them will be a lot easier.

## First thing's first

In this article (and for most of the rest of issue), we will look at Core Animation specifically. While a lot of what you will see can also be accomplished using higher level UIKit methods, Core Animation will give you a better understanding what is going on. It also allows for a more explicit way of describing animations, which is useful for readers of this article as well as readers of your code.

Before we can have a look at how animations interact with what we see on screen, we need to take a quick look at Core Animation's `CALayer`, which is what the animations operate on.

You probably know that `UIView` instances, as well as layer-backed `NSView`s,modify their `layer` to delegate rendering to the powerful Core Graphics framework. However, it is important to understand that animations, when added to a layer, don't modify its properties directly.

Instead, Core Animation maintains two parallel layer hierarchies: the _model layer tree_ and the _presentation layer tree_[^1]. Layers in the former reflect the well-known state of the layers wheres only layers in the latter approximate the in-flight values of animations.

[^1]: There is actually a third layer tree called the _rendering tree_. Since it's private to Core Animation, we won't cover it here.

Consider adding a fade-out animation to a view. If you, at any point during the animation inspect the layer's `opacity` value, you most likely won't get an opacity that corresponds to what is on screen. Instead, you need to need to
inspect the presentation layer to get the correct result.

While you may not set properties of the presentation layer directly, it can be
useful to use its current values to create new animations or to interact with
layers while an animation is taking place.

By using `-[CALayer presentationLayer]` and `-[CALayer modelLayer]`, you can switch between the two layer hierarchies with ease.

## A basic animation

The probably most common case is to animate a view's property from one value to another. Consider this example:

[ Animation of a rectangle moving from left to right ]

Here, we animate our little red rectangle from `50,0` to `150,0`. In order to fill in all the steps along the way, we need to determine where our rectangle is going to be at a given point in time. This is commonly done using linear interpolation:

```
x(t) = x_0 + t * ∆x
```

That is, for a given fraction of the animation `t`, the x-coordinate of the rectangle is the x-coordinate of the starting point `50`, plus the distance to the end point `∆x = 100` multiplied with said fraction.

Using `CABasicAnimation`, we can implement this animation as follows:

```objc
CABasicAnimation *animation = [CABasicAnimation animation];
animation.keyPath = @"position.x";
animation.fromValue = @50;
animation.toValue = @150;
animation.duration = 1;

[rectangle.layer addAnimation:animation forKey:@"basic"];
```

---
layout: post
title:  "Animations Explained"
category: "12"
date: "2014-05-01 10:00:00"
tags: article
author: "<a href=\"https://twitter.com/ceterum_censeo\">Robert Böhnke</a>"
---

# Animations Explained

The apps we write are rarely a static experience, they adapt to the users needs and change state to perform a multitude of tasks.

When transitioning between these states, it is important to explain to our users what is going on. Rather jumping from screen to screen, animations help us explain where the user is coming from and where they are going.

The keyboard slides in and out of view to give the illusion that it is a natural part of the phone that was just hidden below the screen. View controller transitions reinforce the navigational structure of our apps and give the user hints which direction they are going. Subtle bounces and collisions make our interfaces life-like and evoke physical qualities in an otherwise felt-free environment.

Animations are a great way to tell the story of your application and by understanding basic the basic principles behind animation, we'll have a better time designing them.

## A basic animation

The probably most common case is to animate a views property from one value to another. Consider this example:

[ Animation of a rectangle moving from left to right ]

Here, we animate our little red rectangle from `50,0` to `150,0`. In order to fill in all the steps along the way, we need to determine where our rectange needs to be at a given point in time. This is commonly done using linear interpolation:

```
x(t) = x_0 + t * ∆x
```

That is, for a given fraction of the animation `t`, the x-coordinate of the rectangle is the x-coordinate of the starting point `50` plus the distance to the end point `∆x = 100` multiplied with said fraction.

Using `CABasicAnimation`, we can implement this animation as follows:

```objc
CABasicAnimation *animation = [CABasicAnimation animation];
animation.keyPath = @"position.x";
animation.fromValue = @50;
animation.toValue = @150;

[self.layer addAnimation:animation forKey:@"basic"];
```

---
layout: post
title: Testing bad practices
category: "15"
date: "2014-08-02 09:00:00"
author: "<a href=\"http://twitter.com/luisobo/">Luis Solano</a>"
tags: article
---

Writing tests is considered a good practice by itself but as we will see in this article tests can cause us some trouble. Let's discuss some of these scenarios and how to overcome them or how to avoid them in the first place.

## Initial premise

Let's start by stating an initial premise: The only purpose of having tests is so we can modify our code later on.

We want tests when we:

### Change the behavior of our system

### Refactor the implementation of our system

## Testing good practices 101

Quickly cover some basic guidelines to write good tests: Fast, Indepdendent, Repeatable, Self-checking, Timely

## Bad practices

### Don't test private methods

### Don't stub private methods

### Don't stub external libraries

### Don't stub dependencies partially

### Don't test constructors

## Conclusion

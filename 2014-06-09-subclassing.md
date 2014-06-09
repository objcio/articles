---
layout: post
title:  "Subclassing"
category: "13"
date: "2014-06-09 09:00:00"
tags: article
author: "<a href=\"https://twitter.com/chriseidhof\">Chris Eidhof</a>"
---

This article is a little bit different from the usual articles I write. It's more a collection of thoughts and patterns than a guide. Almost all the patterns I will describe are found out the hard way: by making mistakes. By no means do I consider myself an authority on subclassing, but I did want to share a few things I've learned. Don't read this as a definitive guide, but rather as a collection of examples.

When asked about OOP (object-oriented programming), Alan Kay (the inventor) wrote that it's not about classes, but rather about messaging.[^1] Still, a lot of people focus on creating class hierarchies. In this article, we'll look at some cases where it's useful, but we'll mostly pay attention to alternatives to creating complicated class hierarchies. In our experience, this leads to code that's simpler and easier to maintain. A lot of things have been written on this topic, which you can find in books like [Clean Code](http://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882) and [Code Complete](http://www.amazon.com/Code-Complete-Practical-Handbook-Construction/dp/0735619670), both of which are recommended reading.

[^1]: http://c2.com/cgi/wiki?AlanKayOnMessaging


## When to Subclass

First, let's talk about some cases where it makes sense to create subclasses. If you're building a `UITableViewCell` with custom layout, create a subclass. The same holds for almost every view; once you start doing layout, it makes sense to move this into a subclass, so that you not only have your code nicely bundled up, but also have a reusable object that you can share across projects.

Suppose you're targeting multiple platforms and versions from your code, and you need to somehow write custom bits for every platform and version. It might then make sense to create an `OBJDevice` class, which has subclasses like `OBJIPhoneDevice` and `OBJIPadDevice`, and maybe even deeper subclasses like `OBJIPhone5Device`, which override specific methods. For example, your `OBJDevice` could contain a method `applyRoundedCornersToView:withRadius:`. It has a default implementation, but can be overriden by specific subclasses.

Another case where subclassing might be very helpful is in model objects. Most of the time, my model objects inherit from a class that implements `isEqual:`, `hash`, `copyWithZone:`, and `description`. These methods are implemented once by iterating over the properties, making it a lot harder to make mistakes. (If you're looking for a base class like this, you can consider using [Mantle](https://github.com/mantle/mantle), which does exactly this, and more.)

## When Not to Subclass

In a lot of projects that I've worked on, I've seen deep hierarchies of subclasses. I am guilty of doing this as well. Unless the hierarchies are very shallow, you very quickly tend to hit limits.[^2] 

Luckily, if you find yourself in a deep hierarchy like that, there are lot of alternatives. In the sections below, we'll go into each in more detail. If your subclasses merely share the same interface, protocols can be a very good alternative. If you know an object needs to be modified a lot, you might want to use delegates to dynamically change and configure it. When you want to extend an existing object with some simple functionality, categories might be an option. When you have a set of subclasses that each override the same methods, you might instead use configuration objects. And finally, when you want to reuse some functionality, it might be better to compose multiple objects instead of extending them.

[^2]: http://c2.com/cgi/wiki?LimitsOfHierarchies

## Alternatives

### Alternative: Protocols

Often, a reason to use subclassing is when you want to make sure that an object responds to certain messages. Consider an app where you have a player object, that can play videos. Now, if you want to add YouTube support, you want the same interface, but a different implementation. One way you can achieve this with subclassing is like this:

    @class Player : NSObject

    - (void)play;
    - (void)pause;

    @end


    @class YouTubePlayer : Player

    @end


Most likely, the two classes don't share a lot of code, just the same interface. When that's the case, it might be a good solution to use protocols instead. Using protocols, you would write the code like this:

    @protocol VideoPlayer <NSObject>

    - (void)play;
    - (void)pause;

    @end


    @class Player : NSObject <VideoPlayer>

    @end


    @class YouTubePlayer : NSObject <VideoPlayer>

    @end

This way, the `YouTubePlayer` doesn't need to know about the `Player` internals.


### Alternative: Delegation

Again, suppose you have a `Player` class like in the example above. Now, at one place, you might want to perform a custom action on play. Doing this is relatively easy: you can create a custom subclass, override the `play` method, call `[super play]`, and then do your custom work. This is one way to deal with it. Another way is to change your `Player` object and give it a delegate. For example:

    @class Player;

    @protocol PlayerDelegate

    - (void)playerDidStartPlaying:(Player *)player;

    @end


    @class Player : NSObject

    @property (nonatomic,weak) id<PlayerDelegate> delegate;

    - (void)play;
    - (void)pause;

    @end

Now, in the player's `play` method, the delegate gets sent the `playerDidStartPlaying:` message. Any consumers of this class can now just implement the delegate protocol instead of having to subclass, and the `Player` object can stay very generic. This is a very powerful technique, which Apple uses abundantly in its own frameworks. Think of classes like `UITextField`, but also `NSLayoutManager`. Sometimes you want to group different methods together in separate protocols, such as `UITableView` -- which has not only a delegate but also a data source -- does.


### Alternative: Categories

Sometimes, you might want to extend an object with a little bit of extra functionality. Suppose you want to extend `NSArray` by adding a method `arrayByRemovingFirstObject`. Instead of subclassing, you can put this into a category. It works like this:

    @interface NSArray (OBJExtras)

    - (void)obj_arrayByRemovingFirstObject;

    @end

When using categories and extending a class that's not your own, it's good practice to prefix your methods. If you don't, there is a chance that somebody else might implement the same method using the same technique. Then, if the behavior doesn't match, unexpected things could happen.

One of the dangers of using categories is that you might end up with a large amount of categories, and you can lose your overview. In that case, it's probably easier to create custom classes.


### Alternative: Configuration Objects

One of the mistakes I keep on making (but can now recognize fairly quickly), is having a class with some abstract functionality, and then a lot of subclasses that override one specific method. For example, in a presentation app, you might have a class `Theme`, which has a couple of properties, such as `backgroundColor` and `font`, and some logic for laying things out on a slide.

Then, for each theme, you create a subclass of `Theme`, override a method (e.g. `setup`), and configure the properties. Using the superclass directly wouldn't make sense. In this case, you can make your code a bit simpler by using configuration objects. You can keep the shared logic in the `Theme` class (e.g. slide layout), but move the configuration into simpler objects that only have properties.

For example, a `ThemeConfiguration` class would have the `backgroundColor` and `font` properties, and the `Theme` class gets a value of this class in the initializer.


### Alternative: Composition

The most powerful alterative to subclassing is composition. If you want to reuse existing code but you're not sharing the same interface, composition can be your weapon of choice. For example, suppose you are designing a caching class:

    @interface OBJCache : NSObject

    - (void)cacheValue:(id)value forKey:(NSString *)key;
    - (void)removeCachedValueForKey:(NSString *)key;

    @end

One easy way to do this is by subclassing `NSDictionary` and implementing the two methods by calling to dictionary methods: 

    @interface OBJCache : NSDictionary

However, there are a couple of drawbacks. The fact that it is implemented with a dictionary should be an implementation detail. Now, everywhere where you expect an `NSDictionary` parameter, you could provide an `OBJCache` value. If you would ever want to switch to something completely different (e.g. your own library), you might need to refactor a lot of code.

A better approach is to store this dictionary in a private property (or instance variable), and only expose the two `cache` methods. Now, you maintain the flexibility to change the implementation as you gain more insight, and consumers of your class don't need to be refactored.


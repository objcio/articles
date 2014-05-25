---
layout: post
title:  "Subclassing"
category: "13"
date: "2014-06-07 06:00:00"
tags: article
author: "<a href=\"https://twitter.com/chriseidhof\">Chris Eidhof</a>"
---

Talk about experience, and lack of knowledge. By no means an extensive overview.

> Its not about classes, but about messages

## When to subclass

Examples: browser object, model object (but only one layer)

## When not to subclass

* Configuration object

## Alternatives

### Alternative: Protocols

Often, a reason to use subclassing is when you want to make sure that an object responds to certain messages. Consider an app where you have a player object, which can play videos. Now, if you want to add YouTube support, you want the same interface, but a different implementation. One way you can achieve this with subclassing, is like this:

```objectivec
@class Player : NSObject
- (void)play;
- (void)pause;
@end

@class YouTubePlayer : Player
@end
```

Probably, the two classes don't share a lot of code, just the same interface. When that's the case, it might be a good solution to use protocols instead. Using protocols, you would write the code like this:

```objectivec
@protocol VideoPlayer <NSObject>
- (void)play;
- (void)pause;
@end

@class Player : NSObject <VideoPlayer>
@end
@class YouTubePlayer : NSObject <VideoPlayer>
@end
```

This way, the `YoutubePlayer` doesn't need to know about the `Player` internals.

### Alternative: Delegation

Again, suppose you have a `Player` class like in the example above. Now, at one place, you might want to perform a custom action on play. Doing this is relatively easy: you can create a custom subclass, override the `play` method, call `[super play]` and then do your custom work. This is one way to deal with it. Another way is to change your `Player` object, and give it a delegate. For example:

```objectivec
@class Player;

@protocol PlayerDelegate
- (void)playerDidStartPlaying:(Player *)player;
@end

@class Player : NSObject

- (void)play;
- (void)pause;

@property (nonatomic,weak) id<PlayerDelegate> delegate;

@end
```

Now, in the player's `play` method, the delegate gets sent the `playerDidStartPlaying:` message. Any consumers of this class can now just implement the delegate protocol instead of having to subclass, and the `Player` object can stay very generic. This is a very powerful technique which Apple uses abundantly in their own frameworks. Think of classes like `UITextField`, but also `NSLayoutManager`. Sometimes, you want to group different methods together in separate protocols, such as `UITableView` which has not only a delegate but also a data source.

### Alternative: Categories

Sometimes, you might want to extend an object with a little bit of extra functionality. Suppose you want to extend `NSArray` by adding a method `arrayByRemovingFirstObject`. Instead of subclassing, you can put this into a category. It works like this:

```objectivec
@interface NSArray (OBJExtras)
- (void)obj_arrayByRemovingFirstObject;
@end
```

When extending a class that's not your own using categories, it is good practice that you prefix your methods. If you wouldn't, there is a chance that somebody else might implement the same method using the same technique. If the behavior doesn't match, unexpected things might happen.

### Alternative: Configuration objects

Example: Stylesheet?

### Alternative: Composition



## Smells



----


* `isKindOfClass:`
* Liskov Substitution Principle


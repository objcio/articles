---
title: Debugging Checklist
category: "19"
date: "2014-12-08 09:00:00"
tags: article
author: "<a href=\"http://twitter.com/chriseidhof\">Chris Eidhof</a>"
---

Finding bugs can be very time-consuming; almost every experienced developer can
relate to having spent days on a single bug. As you become more experienced on a
platform, it becomes easier to find bugs. However, some bugs will always be
hard to find or reproduce. As a first step, it is always useful to find a way
to reproduce the bug. Once you have a way to reproduce it consistently, you can
get to the next stage: finding the bug.

This article tries to sketch a number of common problems that we usually run into when
debugging. You could use this as a checklist when you encounter a bug, and
maybe by checking some of these things, you'll find that bug way sooner.
And hopefully, some of the techniques help to prevent the bugs in the first place.

We'll start off with a couple of very common sources of bugs that happen to us a lot.

## Are Your Callbacks on the Right Thread?

One source of unexpected behavior is when things are happening on the wrong thread. For example, when you update UIKit objects from any other thread than the main thread, things could break. Sometimes updating works, but mostly you will get strange behavior, or even crashes. One thing you can do to mitigate this is having assertions in your code that check whether or not you're on the main thread. Common callbacks that might (unexpectedly) happen on a background thread could be coming from network calls, timers, file reading, or external libraries.

Another solution is to keep the places where threading happens very isolated. As an example, if you are building a wrapper around an API on the network, you could handle all threading in that wrapper. All network calls will happen on a background thread, but all callbacks could happen on the main thread, so that you'll never have to worry about that occurring in the calling code. Having a simple design really helps.

## Is This Object Really the Right Class?

This is mostly an Objective-C problem; in Swift, there's a stronger type system with more precise guarantees about the type of an object or value. However, in Objective-C, it's fairly common to accidentally have objects of the wrong class.

For example, in [Deckset](http://www.decksetapp.com), we were adding a new feature that had to do with fonts. One of the objects had a `fonts` array property, and I assumed the objects in the array were of type `NSFont`. As it turned out, the array contained `NSString` objects (the font names). It took quite a while to figure this out, because, for the most part, things worked as expected. In Objective-C, one way to check this is by having assertions. Another way to help yourself is to encode type information in the name (e.g. this array could have been named `fontNames`). In Swift, these errors can be prevented by having precise types (e.g. `[NSFont]` rather than `[AnyObject]`).

When unsure about whether the object is of the right type, you can always print it in the debugger. It is also useful to have assertions that check whether or not an object is the right class using `isKindOfClass:`. In Swift, rather than force casting with the `as` keyword, rely on having optionals and use `as?` to typecast whenever you need to. This will let you minimize the chances of errors.

## Build-Specific Settings

Another common source of bugs that are hard to find is when there are settings that differ between builds. For example, sometimes optimizations that happen in the compiler could cause bugs in production builds that never show up during debugging. This is relatively uncommon, although there are reports of this happening with the the current Swift releases.

Another source of bugs is where certain variables or macros are defined differently. For example, some code might be commented out during development. We had an instance where we were writing incorrect (crashing) analytics code, but during development we turned off analytics, so we never saw these crashes when developing the app. 

These kinds of bugs can be hard to detect during development. As such, you should always thoroughly test the release build of your app. Of course, it's even better if someone else (e.g. a QA department) can test it.

## Different Devices

Meanwhile, there are many different devices with different capabilities. If you have only tested on a limited number of devices, this is a potential cause of bugs. The classic scenario is just testing on the simulator without having the real device. But even when you do test with a real device, you need to account for different capabilities. For example, when dealing with the built-in camera, always use methods like `isSourceTypeAvailable:` to check whether you can use a specific input source. You might have a working camera on your device, but it might not be available on the user's device. 

## Mutability

Mutability is also a common source of bugs that can be very hard to track down. For example, if you share an object between two threads, and they both modify it at the same time, you might get very unexpected behavior. The tough thing about these kinds of bugs is that they can be very hard to reproduce.

One way to deal with this is to have immutable objects. This way, once you have access to an object, you know that it'll never change its state. There is so much to say about this, but for more information, we'd rather direct you to read the following: [A Warm Welcome to Structs and Value Types](/issue-16/swift-classes-vs-structs.html), [Value Objects](/issue-7/value-objects.html), [Object Mutability](https://developer.apple.com/library/mac/documentation/General/Conceptual/CocoaEncyclopedia/ObjectMutability/ObjectMutability.html), and [About Mutability](http://www.bignerdranch.com/blog/about-mutability/).

## Nullability

As Objective-C programmers, we sometimes make fun of Java programmers because of their `NullPointerException`s. For the most part, we can safely send messages to nil and not have any problems. Still, there are some tricky bugs that might arise out of this. If you are writing Swift instead of Objective-C, you can safely skip most of this section, because Swift optionals are a solution to many of these problems.

### Does the Method You Call Take `nil` Parameters?

This is a common source of bugs. Some methods will crash when you call them with a nil parameter. For example, consider the following fragment:

```objectivec
NSString *name = @"";
NSAttributedString *string = [[NSAttributedString alloc] initWithString:name];
```

If `name` is nil, this code will crash. The tricky thing is when this is an edge case that you might not discover (e.g. `myObject` is non-nil in most of the cases). When writing your own methods, you can add a custom attribute to inform the compiler about whether or not you expect nil parameters:

```objectivec
- (void)doSomethingWithRequiredString:(NSString *)requiredString
                                  bar:(NSString *)optionalString
        __attribute((nonnull(1)));
```

(Source: [StackOverflow](http://stackoverflow.com/a/19186298))

Adding this attribute will give a compiler warning when you try to pass in a nil parameter. This is nice, because now you don't have to think about this edge case anymore: you can leverage the compiler infrastructure to have this checked for you.

Another possible way around this is to invert the flow of messages. For example, you could create a custom category on `NSString` which has an instance method `attributedString`:

```objectivec
@implementation NSString (Attributes)

- (NSAttributedString*)attributedString {
	return [[NSAttributedString alloc] initWithString:self];
}

@end
```

The nice thing about the above code is that you can now safely construct an `attributedString`. You could write `[@"John" attributedString]`, but you can also send this message to nil (`[nil attributedString]`), and rather than a crash, you get a nil result. For some more ideas about this, see Graham Lee's article on [reversing the polarity of the message flow](http://www.sicpers.info/2014/10/reversing-the-polarity-of-the-message-flow/).

If you want to capture more constraints that need to be true (e.g. a parameter should always be a certain class), you can use [`NSParameterAssert`](https://developer.apple.com/library/ios/documentation/Cocoa/Reference/Foundation/Miscellaneous/Foundation_Functions/#//apple_ref/c/macro/NSParameterAssert) as well.

### Are You Sure You Can Send the Message to `nil`?

This is a rather uncommon source of bugs, but it happened to us in a real app. Sometimes when dealing with scalar values, sending a message to nil might produce an unexpected result. Consider the following innocent-looking snippet of code:

```objectivec
NSString *greeting = @"Hello objc.io";
NSRange range = [greeting rangeOfString:@"objc.io"];
if (range.location != NSNotFound) {
  NSLog(@"Found the keyword!");
}
```

If `greeting` contains the string `"objc.io"`, a message is logged. If `greeting` does not contain this string, no message is logged. But what if greeting is `nil`? Then the `range` will be a struct with zeroes, and the `location` will be zero. Because `NSNotFound` is defined as `-1`, this will log the message. So whenever you deal with scalar values and `nil`, be sure to take extra care. Again, this is not an issue in Swift because of optionals.

## Is There Anything in the Class That's Not Initialized?

Sometimes when working with an object, you might end up working with a half-initialized object. Because it's uncommon to do any work in `init`, sometimes you need to call some methods on the object before you can start working with it. If you forget to call these methods, the class might not be initialized completely and weird behavior might occur. Therefore, always make sure that after the designated initializer is run, the class is in a usable state. If you absolutely need your designated initializer to run, and can't construct a working class using just the `init` method, you can still override the `init` method and crash. This way, when you do accidentally instantiate an object using `init`, you'll hopefully find out about it early.

## Key-Value Observing

Another common source of bugs is when you're using key-value observing (KVO) incorrectly. Unfortunately, it's not that hard to make mistakes, but luckily, there are a couple of ways to avoid them.

### Are You Cleaning Up Your Observers?

An easy-to-make mistake is adding an observer, but then never cleaning it up. This way, KVO will keep sending messages, but the receiver might have dealloc'ed, so there will be a crash. One way around this is to use a full-blown framework like [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa), but there are some lighter approaches as well.

One such way is, whenever you create a new observer, immediately write a line in dealloc that removes it. However, this process can be automated. Rather than adding the observer directly, you can create a custom object that adds it for you. This custom object adds the observer and removes it in its own dealloc. The advantage of this is that the lifetime of your observer is the same as the lifetime of the object. This means that creating this object adds the observer. You can then store it in a property, and whenever the containing object is dealloc'ed, the property will automatically be set to nil, thus removing the observer.
A slightly longer explanation of this technique, including sample code, can be found [here](http://chris.eidhof.nl/posts/lightweight-key-value-observing.html). A tiny library that does this is [THObserversAndBinders](https://github.com/th-in-gs/THObserversAndBinders), or you could look at Facebook's [KVOController](https://github.com/facebook/KVOController).

Another problem with KVO is that callbacks might arrive on a different thread than you expected (just like we described in the beginning). Again, by using an object to deal with this (as described above), you can make sure that all callbacks get delivered on a specific thread.

### Dependent Key Paths

If you're observing properties that depend on other properties, you need to make sure that you [register dependent keys](https://developer.apple.com/library/ios/DOCUMENTATION/Cocoa/Conceptual/KeyValueObserving/Articles/KVODependentKeys.html). Otherwise, you might not get callbacks when your properties change. A while ago, I created a recursive dependency (a property dependent on itself) in my dependent key declarations, and strange things happened.

## Views

### Outlets and Actions

A common mistake when using Interface Builder is to forget to wire up outlets and actions. This is now often indicated in the code (you can see small circles next to outlets and actions). Also, it's very possible to add unit tests that test whether everything is connected as you expect (but it might be too much of a maintenance burden).

Here, you could also use asserts like [`NSAssert`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Miscellaneous/Foundation_Functions/#//apple_ref/c/macro/NSAssert) to verify that your outlets are not nil, in order to make sure you fail fast whenever this happens.

### Retaining Objects

When you use Interface Builder, you need to make sure that your object graph that you load from a nib file stays retained. There are [good pointers on this by Apple](https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/LoadingResources/CocoaNibs/CocoaNibs.html#//apple_ref/doc/uid/10000051i-CH4-SW6). Be sure to read that section and follow the advice, otherwise your objects might either disappear underneath you, or get over-retained. There are differences between plain XIB files and Storyboards; be sure to account for that.

### View Lifecycle

When dealing with views, there are many potential bugs that can arise. One common mistake is to work with views when they are not yet initialized. Alternatively, you might work with initialized views that don't have a size yet. The key here is to do things at the right point in [the view lifecycle](http://developer.apple.com/library/ios/#documentation/uikit/reference/UIViewController_Class/Reference/Reference.html#//apple_ref/doc/uid/TP40006926-CH3-SW58). Investing the time in understanding exactly how this works will almost certainly pay off in decreased debugging time.

When you port an existing app to the iPad, this might also be a common source of bugs. All of a sudden, you might need to worry about whether a view controller is a child view controller, how it responds to rotation events, and many other subtle differences. Here, auto layout might be helpful, as it can automatically respond to many of these changes.

One common mistake that we keep making is creating a view, adding some constraints, and then adding it to the superview. In order for most constraints to work, the view needs to be in the superview hierarchy. Luckily, most of the time this will crash your code, so you'll find the bug fast.

## Finally

The techniques above are hopefully helpful to get rid of bugs or prevent them completely. There is also automated help available: turning on all warning messages in Clang can show you a lot of possible bugs, and running the static analyzer will almost certainly find some bugs (unless you run it on a regular basis).

---
title: Debugging Checklist
category: "19"
date: "2014-12-10 10:00:00"
tags: article
author: "<a href=\"http://twitter.com/chriseidhof\">Chris Eidhof</a>"
---

Finding bugs can be very time-consuming. Almost every experienced developer can
relate to spending days on a single bug. As you get more experienced on a
platform, it becomes easier to find bugs. However, some bugs always will be
hard to find or reproduce. As a first step, it is always useful to find a way
to reproduce the bug. Once you have a way to reproduce it consistently, you can
get to the next stage: finding the bug.

In this article, we try to sketch a number of common problems that we find when
debugging. You could use this as a checklist when you encounter a bug, and
maybe by checking some of these things you'll find that bug way sooner. This article is about the kind of bugs that we experienced ourselves.

We'll start of with a couple of very common sources of bugs that happen to us a lot.

### Are your callbacks on the right thread?

One source of unexpected behavior is when things are happening on the wrong thread. For example, when you update UIKit objects from any other thread than the main thread, things could break. Sometimes this works, but mostly you will get strange behavior or even crashes. One thing you can do to mitigate this is having assertions in your code that check whether or not you're on the main thread. Common callbacks that might (unexpectedly) happen on a background thread could be coming from network calls, timers, file reading or external libraries.

Another solution is to keep the places where threading happens very isolated. As an example, if you are building a wrapper around an API on the network, you could handle all threading in that wrapper. All network calls will happen on a background thread, but all callbacks could happen on the main thread, so that you never have to worry about that in the calling code. Having a simple design really helps.

### Is this object really the right class?

This is mostly an Objective-C problem, in Swift there's a stronger type-system with way stronger guarantees about the type of an object or value. However, in Objective-C it's fairly common to accidentally have objects of the wrong class.

For example, in [Deckset](http://www.decksetapp.com), we were adding a new feauture that had to do with fonts. One of the objects had a `fonts` array property, and I assumed the objects in the array were of type `NSFont`. As it turned out, the array contained `NSString` objects (the font names). It took quite a while to figure this out, because mostly things worked as expected. In Objective-C, one way to check this is by having assertions. Another way to help yourself is to encode type-information in the name (e.g. this array could have been named `fontNames`). In Swift, these errors can be prevented by having precise types (e.g. `[NSFont]` rather than `[AnyObject]`).

When unsure about whether the object is of the right type, you can always print it in the debugger. You can even have assertions that check whether or not an object is the right class using `isKindOfClass:`. In Swift, rather than force-casting with the `as` keyword, rely on having optionals and use `as?` to typecast whenever you need to. This will let you minimize the chances of errors.

### Build-specific settings

Another common source of bugs that are hard to find is when there are settings that differ between builds. For example, sometimes optimizations that happen in the compiler could cause bugs in production builds that never show up during debugging. This is relatively uncommon, although there are reports of this happening with the the current Swift releases.

Another source of bugs is where certain variables or macros are defined differently. For example, some code might be commented out during development. We had an instance where we where writing incorrect (crashing) analytics code, but during development we turned off analytics so never saw these crashes when developing the app. 

These kinds of bugs can be hard to detect during development. You should always thoroughly test the release build of your app. Of course, it's even better if someone else (e.g. a QA department) can test it.

### Different devices

Meanwhile, there are many different devices with different capabilities. If you only have test on a limited number of devices, this is a potential cause of bugs. The classic scenario is just testing on the simulator without having the real device. But even when you do test with a real device, you need to account for different capabilities. For example, when dealing with the built-in camera, always use methods like `isSourceTypeAvailable:` to check whether you can use a specific input source. You might have a working camera on your device, but it might not be available on the user's device. 

### Mutability

Mutability is also a common source of bugs that can be very hard to track down. For example, if you share an object between two threads, and they both modify it at the same time, you might get very unexpected behavior. The tough thing about these kinds of bugs is that they can be very hard to reproduce.

One way to deal with this is to have immutable objects. This way, once you have access to an object you know that it'll never change it's state. 

TODO reference to other articles?

## Nullability

As Objective-C programmers, we sometimes make fun of Java-programmers, because of their `NullPointerException`s. For the most part, we can safely send messages to nil, and not have any problems. Still, there are some tricky bugs that might arise out of this. If you are writing Swift instead of Objective-C, you can safely skip most of this section, because Swift optionals are a solution to many of these problems.

### Does the method you call take nil parameters?

This is a common source of bugs. Some methods will crash when you call them with a nil parameter. For example, consider the following fragment:

```objectivec
NSString *name = @"";
NSAttributedString *string = [[NSAttributedString alloc] initWithString:name];
```

If `myObject` is nil, this code will crash. The tricky thing is when this is an edge-case that you might not discover (e.g. `myObject` is non-nil in most of the cases). When writing your own methods, you can add a custom attribute to inform the compiler about whether you expect nil parameters:

```objectivec
* TODO insert example
```

Adding this attribute will give a compiler warning when you try to pass in a nil parameter. This is nice, because now you don't have to think about this edge-case anymore: you can leverage the compiler infrastructure to have this checked for you.

Another possible way around this is to invert the flow of messages. For example, you could create a custom category on `NSString` which has an instance method `attributedString`:

```objectivec
@implementation NSString (Attributes)

- (NSAttributedString*)attributedString {
	return [[NSAttributedString alloc] initWithString:self];
}

@end
```

The nice thing about the above code is that you can now safely construct an `attributedString`. You could write `[@"John" attributedString]`, but you can also send this message to nil (`[nil attributedString]`) and rather than a crash, you get a nil result. For more background, see Graham Lee's article on inverting messaging.

TODO link

### Are you sure you can send the message to nil?

This is a rather uncommon source of bugs, but happened to us in a real app. Sometimes when dealing with scalar values, sending a message to nil might produce an unexpected result. Consider the following innocent-looking snippet of code:

```objectivec
NSString *greeting = @"Hello objc.io";
NSRange range = [greeting rangeOfString:@"objc.io"];
if (range.location != NSNotFound) {
  NSLog(@"Found the keyword!");
}
```

If `greeting` contains the string `"objc.io"`, a message is logged. If `greeting` does not contain this string, no message is logged. But what if greeting is `nil`? Then the `range` will be a struct with zeroes, and the `location` will be zero. Because `NSNotFound` is defined as `-1`, this is will log the message. So whenever you deal with scalar values and `nil`, be sure to take extra care. Again, in Swift this is not an issue because of optionals.

### Is there anything in the class that's not initialized?

Sometimes when working with an object, you might end up working with a half-initialized object. Because it's uncommon to do any work in `init`, sometimes you need to call some methods on the object before you can start working with it. If you forget to call these methods, the class might not be initialized completely and weird behavior might occur. Therefore, always make sure that after the designated initializer is run, the class is in a usable state. If you absolutely need your designated initializer to run, and can't construct a working class using just the `init` method, you can still override the `init` method and crash. This way, when you do accidently instantiate an object using `init` you'll hopefully find out about it early.

## Architecture

* Archictecture: 32bit vs 64bit
  * Things like CGFloat
  * Do you have a broken format string?

## Key-Value Observing

Another common source of bugs is when you're using Key-Value Observing (KVO) incorrectly. Unfortunately, it's not that hard to make mistakes, but luckily, there are a couple of ways to avoid them.

### Are you cleaning up your observers?

An easy-to-make mistake is adding an observer, but then never cleaning it up. This way, KVO will keep sending messages, but the receiver might have dealloc'ed, so there will be a crash. One way around this is to use a full-blown framework like [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa), but there are some lighter approaches as well.

One way is to, whenever you create a new observer, immediately write a line in dealloc that removes it. However, this process can be automated. Rather than adding the observer directly, you can create a custom object that adds it for you. This custom object adds the observer, and removes it in its own dealloc. The advantage of this is that the lifetime of your observer is the same as the lifetime of the object. This means that creating this object adds the observer. You can then store it in a property, and whenever the containing object is dealloc'ed, the property will automatically be set to nil, thus removing the observer.
A slightly longer explanation of this technique, including sample code, can be found [here](http://chris.eidhof.nl/posts/lightweight-key-value-observing.html). A tiny library that does this is [THObserversAndBinders](https://github.com/th-in-gs/THObserversAndBinders).

Another problem with KVO is that callbacks might arrive on a different thread than you expected (just like we described in the beginning). Again, by using an object to deal with this (as described above) you can make sure that all callbacks get delivered on a specific thread.

### Dependent key paths

If you're observing properties that depend on other properties, you need to make sure that you [register dependent keys](https://developer.apple.com/library/ios/DOCUMENTATION/Cocoa/Conceptual/KeyValueObserving/Articles/KVODependentKeys.html). Otherwise, you might not get callbacks when your properties change. Also, when you're 

## IB

* Outlets
* actions
* Retaining objects

## Misc

* View lifecycle (e.g. rotation)
* Entitlements / Sandboxing / etc.
* Did you turn on -Wall

???
* malloc

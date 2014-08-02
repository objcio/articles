---
layout: post
title: Dependency Injection
category: "15"
date: "2014-08-02 09:00:00"
author: "<a href=\"http://qualitycoding.org/about/\">Jon Reid</a>"
tags: article
---

Let's say you want to write a method that looks something like this:

```objective-c
- (NSNumber *)nextReminderId
{
    NSNumber *currentReminderId = [[NSUserDefaults standardUserDefaults] objectForKey:@"currentReminderId"];
    if (currentReminderId) {
        // Increment the last reminderId
        currentReminderId = @([currentReminderId intValue] + 1);
    } else {
        // Set to 0 if it doesn't already exist
        currentReminderId = @0;
    }
    // Update currentReminderId to model
    [[NSUserDefaults standardUserDefaults] setObject:currentReminderId forKey:@"currentReminderId"];

    return currentReminderId;
}
```

How do you write unit tests for this? The problem is that it's interacting with another object that we don't control, namely NSUserDefaults.

Bear with me. As we work through this example, the issue isn't, "How do we test a method interacting with NSUserDefaults?" Rather, I'm using NSUserDefaults as an example of a bigger question: "How do we test a method that depends on another object, when that object will keep the tests from being [fast and repeatable][firstTests]?"

[firstTests]: http://pragprog.com/magazines/2012-01/unit-tests-are-first

One of the biggest barriers to approaching unit testing for the first time is not knowing how to manage dependencies on things outside of the code you want to test. But there's a whole school of approaches to this problem, which fall under the name "Dependency Injection" or DI.

## Forms of Dependency Injection

Now as soon as I said "DI," many of you thought of "Dependency Injection Frameworks" or "Inversion Of Control (IOC) Containers". Please set that thought aside; we'll return to it in the FAQ.

There are various techniques for taking a dependency and injecting something else in its place. In the Objective-C runtime, swizzling — that is, dynamically replacing one method with another — is certainly one such technique. Some even argue that [swizzling makes DI unnecessary][injectionIsNotAVirtue], and that the techniques below should be avoided. But I'd rather have code that makes dependencies explicit, so that I can see them (and be forced to deal with the code smelling when there are too many dependencies, or the wrong ones).

[injectionIsNotAVirtue]: http://sharpfivesoftware.com/2013/03/20/dependency-injection-is-not-a-virtue-in-objective-c/

So with that, let's quickly run through a number of forms of DI. With one exception, these all come from [Dependency Injection in .NET][Seemann] by Mark Seemann.

[Seemann]: http://www.amazon.com/Dependency-Injection-NET-Mark-Seemann/dp/1935182501

### Constructor Injection

*Note: Even though Objective-C doesn't have constructors per se, I use the term "constructor injection" instead of "initializer injection". It's a standard DI term, and it's easier to look up for more information across languages.*

In Constructor Injection, a dependency is passed in to the constructor (in Objective-C, the designated initializer) and captured for later use:

```objective-c
@interface Example ()
@property (nonatomic, strong, readonly) NSUserDefaults *userDefaults;
@end

@implementation Example
- (instancetype)initWithUserDefaults:(NSUserDefaults *userDefaults)
{
    self = [super init];
    if (self) {
        _userDefaults = userDefaults;
    }
    return self;
}
@end
```

The dependency can be captured in an instance variable, or in a property. The example above uses a read-only property to make it a little harder to tamper with.

It may look odd to inject NSUserDefaults, and that's where this example may fall short. Remember, NSUserDefaults is standing in for "dependency that creates trouble." It would make more sense for the injected value to be an abstraction (that is, an `id` satisfying some protocol) instead of a concrete object. But I'm going to wave my hands in order to keep going with the examples.

Now every place in this class that would refer to the singleton `[NSUserDefaults standardUserDefaults]` should instead refer to `self.userDefaults`:

```objective-c
- (NSNumber *)nextReminderId
{
    NSNumber *currentReminderId = [self.userDefaults objectForKey:@"currentReminderId"];
    if (currentReminderId) {
        currentReminderId = @([currentReminderId intValue] + 1);
    } else {
        currentReminderId = @0;
    }
    [self.userDefaults setObject:currentReminderId forKey:@"currentReminderId"];
    return currentReminderId;
}
```

### Property Injection

In Property Injection, the code for `nextReminderId` looks the same, referring to `self.userDefaults`. But instead of passing the dependency to the initializer, we make it a settable property:

```objective-c
@interface Example
@property (nonatomic, strong) NSUserDefaults *userDefaults;
- (NSNumber *)nextReminderId;
@end
```

Now a test can construct the object, then set the `userDefaults` property with whatever it needs. But what should happen if the property isn't set? In that case, let's use lazy initialization to establish a reasonable default in the getter:

```objective-c
- (NSUserDefaults *)userDefaults
{
    if (!_userDefaults) {
        _userDefaults = [NSUserDefaults standardUserDefaults];
    }
    return _userDefaults;
}
```

Now if any calling code sets the `userDefaults` property before it's used, `self.userDefaults` will use the given value. But if the property isn't set, then `self.userDefaults` will use `[NSUserDefaults standardUserDefaults]`.

### Method Injection

If the dependency is only referenced in a single method, then we can just inject it directly as a method parameter:

```objective-c
- (NSNumber *)nextReminderIdWithUserDefaults:(NSUserDefaults *)userDefaults
{
    NSNumber *currentReminderId = [userDefaults objectForKey:@"currentReminderId"];
    if (currentReminderId) {
        currentReminderId = @([currentReminderId intValue] + 1);
    } else {
        currentReminderId = @0;
    }
    [userDefaults setObject:currentReminderId forKey:@"currentReminderId"];
    return currentReminderId;
}
```

Again, this may look odd — and again, remember that NSUserDefaults may not quite fit every example. But an NSDate parameter would fit well with Method Injection. (More on this below when we discuss the benefits of each form.)

### Ambient Context

When the dependency is accessed through a class method (such as a singleton), then there are two ways to control that dependency from a test:

  * If you control the singleton, you may be able to **expose its properties** to control its state.
  * If fiddling with properties is insufficient, or the singleton isn't yours to control, then **it's time to swizzle:** replace the class method so that it returns the fake you need.

I won't go into the details of a swizzling example; there are plenty of other resources on that. But see? Swizzling *can* be used for DI, and I have no argument there. Do read on, though. After this brief overview of  different forms of DI, we'll discuss their pros and cons.

### Extract and Override Call

This final technique falls outside the forms of DI from Seemann's book. Instead, Extract and Override Call comes from [Working Effectively with Legacy Code][Feathers] by Michael Feathers. Here's how to apply the technique to our NSUserDefaults problem in 3 steps:

[Feathers]: http://www.amazon.com/Working-Effectively-Legacy-Michael-Feathers/dp/0131177052

Step 1 — Select one of the calls `[NSUserDefaults standardUserDefaults]`. Use automated refactoring (in either Xcode or AppCode) to extract it to a new method.

Step 2 — Change other places where the call is made, replacing them with calls to the new method. (But be careful not to change the new method itself.)
  
The modified code looks like this:

```objective-c
- (NSNumber *)nextReminderId
{
    NSNumber *currentReminderId = [[self userDefaults] objectForKey:@"currentReminderId"];
    if (currentReminderId) {
        currentReminderId = @([currentReminderId intValue] + 1);
    } else {
        currentReminderId = @0;
    }
    [[self userDefaults] setObject:currentReminderId forKey:@"currentReminderId"];
    return currentReminderId;
}

- (NSUserDefaults *)userDefaults
{
    return [NSUserDefaults standardUserDefaults];
}
```

With that in place, here's the final step.

Step 3 — Create a special **testing subclass**, overriding the extracted method, like this:

```objective-c
@interface TestingExample : Example
@end

@implementation TestingExample

- (NSUserDefaults *)userDefaults
{
    // Do whatever you want!
}

@end
```

Test code can now instantiate TestingExample instead of Example, and have complete control over what happens when the production code calls `[self userDefaults]`.

## "So which should form should I use?"

We have five different forms of DI. Each comes with pros and cons, so each has its place.

### Constructor Injection

Constructor Injection should be your weapon of choice. When in doubt, start here. The advantage is that **it makes dependencies explicit.**

The disadvantage is that it can feel cumbersome at first. This is especially true when an initializer has a long list of dependencies. But this reveals a previously hidden code smell: does the class have *too many dependencies?* Perhaps it doesn't conform to the [Single Responsibility Principle][SRP].

[SRP]: https://cleancoders.com/episode/clean-code-episode-9/show

### Property Injection

The advantage of Property Injection that it separates initialization from injection, which is necessary when you can't change the callers. The disadvantage is that, well, it separates initialization from injection! It makes it possible to have incomplete initialization. That's why it's best used when there's a specific default value for your dependency, or when you know the dependency will be filled in by a DI framework.

Property injection looks simple, but **making it robust is surprisingly tricky:**

  * You may want to guard against the property being reset arbitrarily. So instead of the default setter, you may want a custom setter that makes sure the backing instance variable is nil, and the given argument is non-nil.
  * Does the getter need to be thread-safe? If so, you'll have an easier time using Constructor Injection instead of trying to make the getter both safe and fast.

Also, beware of automatically leaning towards Property Injection just because you have a specific instance in mind. **Make sure the default value doesn't refer to another library.** Otherwise, you will require users of your class to also include that other library, breaking the benefits of loose coupling. (In Seemann's terminology, this is the difference between a Local Default and a Foreign Default.)

### Method Injection

Method Injection is good when the dependency will vary with each call. This could be some app-specific context about the calling point. It could be a random number. It could be the current time.

Consider a method that uses the current time. Instead of directly calling `[NSDate date]`, try adding an NSDate parameter to your method. With a small increase in calling complexity, it opens up options for the method to be used more flexibly.

(While Objective-C makes it easy to substitute test doubles without requiring protocols, I recommend reading [Beyond Mock Objects][Rainsberger] by J.B. Rainsberger. It's an interesting example of how wrestling with an injected date opens up larger questions of design and reuse.)

[Rainsberger]: http://blog.thecodewhisperer.com/2013/11/23/beyond-mock-objects/

### Ambient Context

If you have a dependency that is used at various low-level points, you may have a "cross-cutting concern". Passing this dependency around through higher levels can interfere with your code, especially when you can't predict in advance where it will be needed. Examples of this may include:

  * Logging
  * `[NSUserDefaults standardUserDefaults]`
  * `[NSDate date]`

Ambient Context may be just what you need. But because it affects global context, don't forget to reset it when you're done. For example, if you swizzle a method, use `tearDown` or `afterEach` (depending on your testing framework) to restore the original method.

Instead of doing your own swizzling, see if someone has already written a library focusing on the ambient context you need. For example:

  * Networking: [OHHTTPStubs][OHHTTPStubs] or [Nocilla][Nocilla]
  * NSDate: [TUDelorean][TUDelorean]

[OHHTTPStubs]: https://github.com/AliSoftware/OHHTTPStubs
[Nocilla]: https://github.com/luisobo/Nocilla
[TUDelorean]: https://github.com/tuenti/TUDelorean

### Extract and Override Call

Because Extract and Override Call is so simple and powerful, you may be tempted to use it everywhere. But because it requires test-specific subclasses, it's easy for tests to become fragile.

That said, it's effective with legacy code, especially when you don't want to change all the calling points.

## FAQ

### "Which DI framework should I use?"

My advice for folks starting off with mock objects is to avoid using any mock object framework, at first: you'll have a better sense of what's going on. My advice for folks starting off with DI is the same. But you can get even further in DI without a framework, relying solely on "Poor Man's DI" where you do it yourself.

Actually, chances are good that you've already used a DI framework! **It's called Interface Builder.** IB isn't just about laying out interfaces; arbitrary properties can be filled with the real objects by declaring those properties as IBOutlets. This works well for creating an object graph at the point when you create a view. In his 2009 article [Dependency Inversion Principle and iPhone][Smith], Eric Smith calls Interface Builder "my favorite DI framework of all time" and gives a good example.

[Smith]: http://blog.8thlight.com/eric-smith/2009/04/16/dependency-inversion-principle-and-iphone.html

If you decide you need a DI framework and that Interface Builder isn't enough, how do you pick a good one? My advice is: **Be cautious of any framework that requires you to change your code.** As soon as you have to subclass something, conform to a protocol, or add some kind of annotations, you're tying your code directly to a particular implementation. (This goes against the basic idea behind DI!) Instead, find a framework that lets you specify the wiring from *outside* your classes, whether that's specified via a DSL or in code.

### "I don't want to expose all these hooks."

Exposing injection points in initializers, properties, and method arguments can make it feel like you're breaking encapsulation. There's a desire to avoid showing the seams when "these are just to enable testing, and shouldn't pollute the API." And this can be done, by declaring them in a class category in a separate header file. For example, if we're dealing with Example.h, then create an additional header ExampleInternal.h. This will be imported only by Example.m and by test code.

But before you take that approach, I want to question the idea that DI leads to breaking encapsulation. What we're doing is making dependencies explicit. We are defining the edges of our components, and how they fit together: "In order to use this class, you need to give it objects that satisfy Foo, Bar, and Baz." It's defining a set of sockets on your class, and the plugs that fit them.

When it feels cumbersome to expose dependencies, see if either of these scenarios fits:

  * Does it feel silly to expose dependencies on Apple's objects, "because of course everything depends on these"? Ah, but not everything does. Take our NSUserDefaults example: What if you've decided, for some reason, to avoid using NSUserDefaults? Having it explicitly identified as a dependency instead of hidden as an implementation detail will alert you to investigate this component. You can check to see if its use of NSUserDefaults violates your design constraints.
  * Does it feel like you have to expose a bunch of internals in order to test your class? First, see if you can write tests that only go through your existing public API (while still being fast and deterministic). If you can't and need to manipulate dependencies that would otherwise be hidden, chances are there's another class trying to get out. Extract it, turn it into a dependency, and test it separately.

## DI is Bigger than Testing

My initial motivation for exploring DI came from doing Test Driven Development, because in TDD you constantly wrestle with the question, "How do I write a unit test for this?" But I discovered that DI is actually concerned with a bigger idea: that **our code should be composed of modules that we snap together to build an application.**

There are many benefits to such an approach. Graham Lee's article [Dependency Injection, iOS and You][leeg] describes some of them: "to adapt… to new requirements, make bug fixes, add new features, and test components in isolation."

[leeg]: http://www.bignerdranch.com/blog/dependency-injection-ios/

So as you begin to apply DI to write unit tests, remember the bigger idea above. Keep *pluggable modules* in the back of your head. It will inform many design decisions and lead you to more DI patterns and principles.

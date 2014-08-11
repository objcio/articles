---
layout: post
title: "Test Doubles: Mocks, Stubs, and More"
category: "15"
date: "2014-08-11 07:00:00"
author: "<a href=\"http://lazerwalker.com\">Mike Lazer-Walker</a>"
tags: article
---


## Intro

In an ideal world, all of your tests would be high-level tests that run against your actual code. UI tests would simulate actual user input (as Klaas discusses in [his article](/issue-15/user-interface-testing.html)), etc. In practice, this isn't always a good idea. Hitting the database or spinning up a UI for every test can make your test suite too slow, which either slows down productivity or encourages you to not run your tests as often. If the code you're testing depends on a network connection, this requires that your test environment has network access, and also makes it difficult to simulate edge cases, like when a phone is in airplane mode.

Because of all that, it can often be useful to write tests that replace some of your actual code with fake code.

## When Would You Want to Use Some Sort of Mock Object?

Let's start with some basic definitions of the different sorts of fake objects there are.

A *double* is a general catch-all term for any sort of fake test object. In general, when you create any sort of test double, it's going to replicate an object of a specific class. 

A *stub* can be told to return a specified fake value when a given method is called. If your test subject requires a companion object to provide some sort of data, you can use a stub to "stub out" that data source and return consistent fake data in your test setup.

A *spy* keeps track of what methods are called, and what arguments they are called with. You can use it to make test assertions, like whether a specific method was called or that it was called with the correct argument. This can be valuable for when you want to test the contract or relationship between two objects.

A *mock* is similar to a spy, but the way you use it differs slightly. Rather than just capturing all method calls and letting you write assertions on them after the fact, a mock typically requires you to set up expectations beforehand. You tell it what you expect it to happen, execute the code you're testing, and then verify that the correct behavior happened.

A *fake* is an object that has a full working implementation and behaves like a real object of its type, but differs from the class it is faking in a way that makes things easier to test. A classic example would be a data persistence object that uses an in-memory database instead of hitting a real production database.

In practice, these terms are often used differently than these definitions, or even interchangeably. The libraries we'll be looking at later in this article consider themselves to be "mock object frameworks"—even though they also provide stubbing capabilities, and the way you verify behavior more resembles what I've described as "spies" rather than "mocks." But don't get too caught up on the specifics of the vocabulary; I give these definitions more because it's useful to think about different types of test object behaviors as distinct concepts at a high level.

If you're interested in a more in-depth discussion about the different types of fake test objects, Martin Fowler's article, ["Mocks Aren't Stubs,"](http://martinfowler.com/articles/mocksArentStubs.html) is considered the definitive article on the subject.

### Mockists vs. Statists
Many discussions of mock objects, mostly deriving from the Fowler article, talk about two different types of programmers who write tests: mockists and statists. 

The mockist way of doing things is about testing the interaction between objects. By using mock objects, you can more easily verify that the subject under test follows the contract it has established with other classes, making the correct external calls at the correct time. For those who practice behavior-driven development, this is intricately tied in with the idea that your tests can help drive out better production code, as needing to explicitly mock out specific method calls can help you design a more elegant API contract between two objects. This sort of testing lends itself more to unit-level tests than full end-to-end tests.

The statist way of doing things doesn't use mock objects. The idea is that your tests should test state, rather than behavior, as that sort of test will be more robust. Mocking out a class requires you to update your mock if you update the actual class behavior; if you forget to do so, you can get into situations where your tests pass but your code doesn't work. By emphasizing only using real collaborators in your test environment, statist testing can help minimize tight coupling of your tests and your implementation, and reduce false negatives. This sort of testing, as you might guess, lends itself to more full end-to-end tests.

Naturally, it's not like these are two rival schools of programmers; you'd be hard-pressed to see a mockist and a statist dueling it out on the street. This dichotomy is useful, though, in terms of recognizing that there are times when mocks are and are not the most appropriate tools in your tool belt. Different kinds of tests are useful for different tasks, and the most effective test suites will tend to have a blend of different testing styles. Thinking about what you are trying to accomplish with an individual test can help you figure out the best approach to take, and whether or not fake test objects might be the right tool for the job.

## Diving into Code

Talking about this theoretically is all well and good, but let's look at a real-word use case where you'd need to use mocks.

Let's say we're trying to test an object with a method that opens another application by calling `UIApplication`'s `openURL:` method. (This is a real problem I faced while testing my [IntentKit](http://intentkit.github.io)  library.) Writing an end-to-end test for this is difficult (if not impossible), since 'success' involves closing your application. The natural choice is to mock out a `UIApplication` object, and assert that the code in question calls `openURL` on that object, with the correct URL.

Imagine the object in question has a single method:

    @interface AppLinker : NSObject
            - (instancetype)initWithApplication:(UIApplication *)application;
            - (void)doSomething:(NSURL *)url;
    @end

This is a pretty contrived example, but bear with me. In this case, you'll notice we're using constructor injection to inject a `UIApplication` object when we create our instance of `AppLinker`. In most cases, using mock objects is going to require some form of dependency injection. If this is a foreign concept to you, definitely check out [Jon's article](/issue-15/dependency-injection.html) in this issue.

### OCMockito

[OCMockito](https://github.com/jonreid/OCMockito) is a very lightweight mocking library: 

    UIApplication *app = mock([UIApplication class]);
    AppLinker *linker = [AppLinker alloc] initWithApplication:app];
    NSURL *url = [NSURL urlWithString:@"https://google.com"];
    
    [linker doSomething:URL];
    
    [verify(app) openURL:url];

### OCMock
[OCMock](http://ocmock.org) is another Objective-C mock object library. Like OCMockito, it provides full functionality for stubs, mocks, and just about everything else you might want. It has a lot more functionality than OCMockito, which, depending on your personal preference, could be a benefit or a drawback.

At the most basic level, we can rewrite the previous test using OCMock in a way that will look very familiar:

    id app = OCMClassMock([UIApplication class]);
    AppLinker *linker = [AppLinker alloc] initWithApplication:app];
    NSURL *url = [NSURL urlWithString:@"https://google.com"];
    
    [linker doSomething:url];
    
    OCMVerify([app openURL:url]);

This style of mocking, where you verify that a method was called after your test, is known as a "verify after running" approach. OCMock just added support for this in its recent 3.0 release. It also supports an older style, known as expect-run-verify, that has you setting up your expectations before executing the code you are testing. At the end, you simply verify that the expectations were met:

    id app = OCMClassMock([UIApplication class]);

    AppLinker *linker = [AppLinker alloc] initWithApplication:app];
    NSURL *url = [NSURL urlWithString:@"https://google.com"];

    OCMExpect([app openURL:url]);

    [linker doSomething:url];
    
    OCMVerifyAll();


Because OCMock lets you stub out class methods, you could also test this using OCMock, if your implementation of `doSomething` uses `[UIApplication sharedApplication]` rather than the `UIApplication` object injected in the initializer: 

    id app = OCMClassMock([UIApplication class]);
    OCMStub([app sharedInstance]).andReturn(app);

    AppLinker *linker = [AppLinker alloc] init];
    NSURL *url = [NSURL urlWithString:@"https://google.com"];
    
    [linker doSomething:url];
    
    OCMVerify([app openURL:url]);

You'll notice that stubbing out class methods looks exactly the same as stubbing out instance methods.

## Roll Your Own
For a simple use case like this, you might not need the full weight of a mock object library. Often, you can just as easily create your own fake object to test the behavior you care about:

    @interface FakeApplication : NSObject
        @property (readwrite, nonatomic, strong) NSURL *lastOpenedURL;
        
        - (void)openURL:(NSURL *)url;
    @end
    
    @implementation FakeApplication
        - (void)openURL:(NSURL *)url {
            self.lastOpenedURL = url;
        }
    @end

And then the test:

    FakeApplication *app = [[FakeApplication alloc] init];
    AppLinker *linker = [AppLinker alloc] initWithApplication:app];
    NSURL *url = [NSURL urlWithString:@"https://google.com"];
    
    [linker doSomething:url];
    
    XCAssertEqual(app.lastOpenedURL, url, @"Did not open the expected URL");

For a contrived example such as this, it might appear that creating your own fake object just adds in a lot of unnecessary boilerplate, but if you find yourself needing to simulate more complex object interactions, having full control over the behavior of your mock object can be very valuable.

### Which to Use?
Which approach you take depends completely on both the specifics of what you're testing and your own personal preference. OCMockito and OCMock are both installable via CocoaPods, so they're easy to integrate with your existing test setup, but there is also something to be said for avoiding adding dependencies and creating simple mock objects until you need something more. 


## Things to Watch Out for While Mocking
One of the biggest problems you run into with any form of testing is writing tests that are too tightly coupled to the implementation of your code. One of the biggest points of testing is to reduce the cost of future change; if changing the implementation details of some of your code breaks your tests, you've increased that cost. That said, there are a number of things you can do to minimize the possible negative effects of using test fakes.

### Dependency Injection Is Your Friend
If you're not already using [dependency injection](/issue-15/dependency-injection.html), you probably want to. While there are sometimes sensible ways to mock out objects without DI (typically by mocking out class methods, as seen in the OCMock example above), it's often flat out not possible. Even when it is possible, the complexity of the test setup might outweigh the benefits. If you're using dependency injection consistently, you'll find writing tests using stubs and mocks will be much easier.

### Don't Mock What You Don't Own
Many experienced testers warn that you "shouldn't mock what you don't own," meaning that you should only create mocks or stubs of objects that are part of your codebase itself, rather than third-party dependencies or libraries. There are two main reasons for this, one practical and one more philosophical.

With your codebase, you probably have a sense of how stable or volatile different interfaces are, so you can use your gut feeling about when using a double might lead to brittle tests. You generally have no such guarantee with third-party code. A common way to get around this is to create your own wrapper class to abstract out the third-party code's behavior. This can, in some situations, amount to little more than just shifting your complexity elsewhere without decreasing it meaningfully, but in cases where your third-party library is used very frequently, it can be a great way to clean up your tests. Your unit tests can mock out your own custom object, leaving your higher-level integration or functional tests to test the implementation of your wrapper itself. 

The uniqueness of the iOS and OS X development world complicates things a bit, though. So much of what we do is dependent on first-party frameworks, which tend to be more overreaching than the standard library in many other languages. Although `NSUserDefaults` is an object you 'don't own,' for example, if you find yourself needing to mock it out, it's a fairly safe bet that Apple won't introduce breaking API changes in a future Xcode release.

The other reason to not mock out third-party dependencies is more philosophical. Part of the reason to write tests in a mockist style is to help drive out what the interface between your two objects should look like. But with a third-party dependency, you don't have control over that; the specifics of the API contract are already set in stone by a third party, so you can't effectively use tests as an experiment to see if things could be improved. This isn't a problem, per se, but in many cases, it reduces the effectiveness of mocking to the point that it's no longer worth it.

## Don't Mock Me!
There is no silver bullet in testing; different strategies are needed for different situations, based both on your personal proclivities and the specifics of your code. While they might not be appropriate for every situation, test doubles are a very effective tool to have in your testing tool belt. Whether your inclination is to mock out everything in your unit tests using a framework, or to just create your own fake objects as needed, it's worth keeping mock objects in mind as you think about how to test your code.

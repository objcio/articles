---
layout: post
title:  "Avoiding Singleton Abuse"
category: "13"
date: "2014-05-31 08:00:00"
tags: article
author: "<a href=\"https://twitter.com/stephenpoletto\">Stephen Poletto</a>"
---

Singletons are one of the core design patterns used throughout Cocoa. In fact, Apple's developer library itself considers the singleton one of the "Cocoa Core Competencies." As iOS developers, we're familiar with interacting with singletons, from `UIApplication` to `NSFileManager.` We've seen countless examples of singleton usage, in open source projects, Apple's code samples, and on StackOverflow. Xcode even has a default code snippet, the "Dispatch Once" snippet, that makes it incredibly easy to add a singleton to your code:

    + (instancetype)sharedInstance
	{
    	static dispatch_once_t once;
	    static id sharedInstance;
	    dispatch_once(&once, ^{
    	    sharedInstance = [[self alloc] init];
	    });
	    return sharedInstance;
	}
	
For these reasons, singletons are commonplace in iOS programming. The problem is that they're easy to abuse.

While others have called singletons an "anti-pattern", "evil", and ["pathological liars"][pathologicalLiars], I won't completely rule out the merit of singletons. Instead, I want to demonstrate a few problems with singletons so that the next time you're about to auto-complete that `dispatch_once` snippet, you think twice about the implications.

#Global State

Most developers agree that global mutable state is a bad thing. Here's a simple demonstration of why mutable state is bad, even within a single instance:

    @implementation SPMath {
        NSUInteger _a;
        NSUInteger _b;
	}

	- (NSUInteger)computeSum
	{
		return _a + _b;
	}
	
With this implementation, the programmer is expected to set instance variables `_a` and `_b` to the proper values before invoking `computeSum`. There are a few problems here:

1. `computeSum` does not make the fact that it depends upon state `_a` and `_b` explicit by taking the values as parameters. Instead of inspecting the interface and understanding which variables control the output of the function, another developer reading this code must inspect the implementation to understand the dependency. Hidden dependencies are bad.
2. When modifying `_a` and `_b` in preparation for calling `computeSum`, the programmer needs to be sure the modification does not affect the correctness of any other code that depends upon these variables. This is particularly difficult in multi-threaded environments.
3. Unit testing this method is difficult. Persistent state is the enemy of unit testing, since unit testing is made effective by each test being independent of all other tests. If state is left behind from one test to another, then the order of execution of tests suddenly matters. Buggy tests, especially when a test succeeds when it shouldn't, is a very bad thing.

TODO: Add an example

Contrast the above example with this: 
  
	+ (NSUInteger)computeSumOf:(NSUInteger)a plus:(NSUInteger)b
	{
		return a + b;
	}

Here, the dependency on `a` and `b` is made explicit. We don't need to mutate instance state to prepare for calling this method. And, we don't need to worry about leaving behind persistent side effects as a result of calling this method: as a note to the reader of this code, we can even make this method a class method to indicate that instance state will not be mutated by calling it.

Okay, we all know global state is bad, so why did we walk through this example? In the words of Miško Hevery, ["Singletons are global state in sheep’s clothing."][sheepsClothing]

A singleton can be used anywhere, without explictly declaring the dependency. Just like `_a` and `_b` were used in `computeSum` without the depedency being made explict, any module of the program can call `[SPMySingleton sharedInstance]` and get access to the singleton. This means singletons are effectively global state. If you're implementing a singleton, odds are the instance in question has instance state associated with it (otherwise, why not just use class methods or functions?). This entire blob of instance state is effectively global state. 

We as iOS developers are not in the habit of thinking of singletons as glorified global variables, but we need to admit to ourselves they are.

#Object Lifecycle
The other major problem with singletons is their lifecycle. When adding a singleton to your program, it's easy to think, "There will only ever be one of these." But in much of the iOS code I've seen in the wild, that assumption can break down.

For example, suppose we're building an app where users can see a list of their friends. Each of their friends has an profile picture, and we want the app to be able to download and cache those images on the device. With the `dispatch_once` snippet handy, we might find ourselves writing an `SPThumbnailCache` singleton:

	@interface SPThumbnailCache : NSObject

	+ (instancetype)sharedThumbnailCache;

	- (void)cacheProfileImage:(NSData *)imageData forUserId:(NSString *)userId;
	- (NSData *)cachedProfileImageForUserId:(NSString *)userId;

	@end
	
We continue building out the app, and all seems well in the world. Until one day, when we decide it's time to implement the "log out" functionality, so users can switch accounts inside the app. Suddenly, we have a nasty problem on our hands: user-specific state is stored in a global singleton. When the user signs out of the app, we want to be able to clean up all persistent states on disk. Otherwise, we'll leave behind orphaned data on the user's device, wasting their precious disk space. In case the user signs out and then signs into a new account, we also want to be able to have a new `SPThumbnailCache` for the new user.

The problem here is that singletons, by definition, are assumed to be "create once, live forever" instances. You could imagine a few solutions to the problem outlined above. Perhaps we could tear down the singleton instance when the user signs out:

    static SPThumbnailCache *sharedThumbnailCache;

	+ (instancetype)sharedThumbnailCache
	{
	    if (!sharedThumbnailCache) {
	        sharedThumbnailCache = [[self alloc] init];
	    }
	    return sharedThumbnailCache;
	}
	
	+ (void)tearDown
	{
	    // The SPThumbnailCache will clean up persistent states when deallocated
		sharedThumbnailCache = nil;
	}
	
This is a flagrant abuse of the singleton pattern, but it will work, right?

We could certainly make this solution work, but the cost is far too great. For one, we've lost the simplicity of the `dispatch_once` solution, a solution which guarentees thread safety and that all code calling `[SPThumbnailCache sharedThumbnailCache]` only ever gets the same instance. We now need to be extremely careful about the order of code execution for code that utilizes the thumbnail cache. Suppose while the user is in the process of signing out, there's some background task that is in the process of saving an image into the cache: 

		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			[[SPThumbnailCache sharedThumbnailCache] cacheProfileImage:newImage forUserId:userId];
		});

We need to be certain `tearDown` doesn't execute until after that background task completes. This ensures the `newImage` data will get cleaned up properly. Or, we need to make sure the background task is cancelled when the thumbnail cache is shut down. Otherwise, a new thumbnail cache will be lazily created, and stale user state (the `newImage`) will be stored inside of it. 

Since there's no distinct owner for the singleton instance (i.e. the singleton manages its own lifecycle), it becomes very difficult to ever "shut down" a singleton.

At this point, I hope you're saying, "the thumbnail cache shouldn't have ever been a singleton!" The problem is that lifecycles sometimes are not well understood during the first implementation of a project. As a concrete example, the Dropbox iOS app only ever had support for a single user account to be signed in. The app existed in this state for years. Until one day when we wanted to support multiple user accounts (both personal and business accounts) to be signed in simultaneously. All of a sudden, assumptions about "there will only ever be a single user signed in at a time" started to break down.

The lesson here is that singletons should be preserved only for state that is global, and not tied to any scope. If state is scoped to any session shorter than "a complete lifecycle of my app", that state should not be managed by a singleton. A singleton that's managing user-specific state is a code smell, and you should critically re-evaluate the design of your object graph.

#Avoiding Singletons

So, if singletons are so bad for scoped state, how do we avoid using them?

TODO: keep writing


[pathologicalLiars]: http://misko.hevery.com/2008/08/17/singletons-are-pathological-liars/
[sheepsClothing]: http://misko.hevery.com/2008/08/25/root-cause-of-singletons/
---
title:  "Activity Tracing"
category: "19"
date: "2014-12-08 07:00:00"
tags: article
author: "<a href=\"https://twitter.com/floriankugler\">Florian Kugler</a>"
---


Activity tracing is a new technology in iOS 8 and OS X 10.10. This year's WWDC had an excellent [session][wwdcsession] about it, but we thought it would be a good idea to give another overview here, since it is not widely known yet.

Activity tracing is a technique that allows you to augment crash reports with very useful information about the context and the events leading up to the crash, especially while using asynchronous APIs like libdispatch, `NSOperationQueue` or XPC.

The basic idea is that work done in response to user interactions or other events is grouped under an activity, no matter if the work is done synchronously or if it's dispatched to other queues or processes. For example, if the user triggers a refresh in your app, you'll know that this particular user interaction caused a subsequent crash, even if it happens on a different queue and several other code paths could have lead to the crashing code as well.

Activity tracing has three different parts to it: activities, breadcrumbs, and trace messages. We'll go into those in more detail below, but here's the gist of it: activities allow you to trace back the crashing code to its originating event in a cross-queue and cross-process manner. With breadcrumbs you can leave a trail of meaningful events across activities leading up to a crash. And finally, trace messages allow you to add further detail to the current activity. All this information will show up in the crash report in case anything goes wrong.

Before we go into more detail, let me just quickly mention a potential pitfall when trying to get activity tracing to work: If the activity messages are not showing up, check the `system.log` for any messages like "Signature Validation Failed" from the `diagnosticd` daemon -- you might be running into code signing issues.


## Activities

Activities are at the heart of this new technology. An activity groups the code executing in response to a certain event together, no matter on what queues and in what processes the code is executing in. This way, if anything goes wrong in the middle, the crash can be traced back to the original event.

Activity tracing is integrated into AppKit and UIKit, so that an activity is started automatically for you whenever a user interface event is sent through the target-action mechanism. In case of user interactions that don't send events through the responder chain (like a tap on a table view cell), you'll have to initiate an activity yourself.

Starting an activity is very simple:

```
#import <os/activity.h>

os_activity_initiate("activity name", OS_ACTIVITY_FLAG_DEFAULT, ^{
    // do some work...
});
```

This API executes the block synchronously, and everything you do within the block will be scoped under this activity, even if you dispatch work onto other queues or do xpc calls. The first parameter is the label of the activity, and has to be provided as a constant string (like all string parameters of the activity tracing API).

The second parameter, `OS_ACTIVITY_FLAG_DEFAULT`, is the activity flag you use to create an activity from scratch. If you want to create a new activity within the scope of an existing activity, you have to use `OS_ACTIVITY_FLAG_DETACHED`. For example, when reacting to a action message of an user interface control, AppKit already started an activity for you. If you want to start an activity from here that is not the direct result of the user interaction, that's when you'd the detached activity flag.

There are other variants of this API that work in the same away: a function based one (`os_activity_initiate_f`) and one that consists of a pair of macros:

```
os_activity_t activity = os_activity_start("label", OS_ACTIVITY_FLAG_DEFAULT);
// do some work...
os_activity_end(activity);
```

Note that activities will not show up in crash reports (or other ways of inspecting them) if you don't set at least one trace message. See below for more details on trace messages.


## Breadcrumbs

Breadcrumbs are used for what the name suggests: you're code leaves a trail of labeled events while it executes to provide context in case a crash happens. Setting breadcrumbs is very simple:

```
os_activity_set_breadcrumb("event description");
```

Those events are stored in a ring buffer that only holds the last 50 events. Therefore this API should be used to indicate macro-level events, like meaningful user interactions. Note that setting breadcrumbs only works in the scope of an activity.


## Trace Messages

Trace messages are used to add additional information to activities, very similar to how you would use log messages. You can use them to add valuable information to crash reports, in order to easier understand the root cause for the problem. Within an activity, a very simple trace message can be set like this:

```
#import <os/trace.h>

os_trace("my message");
```

Trace messages can do more than that though. The first argument to `os_trace` is a format string, similar to what you'd use with `printf` or `NSLog`. However, there are some restrictions to that: the format string can be a maximum of 100 characters long and can contain placeholder for up to seven *scalar* values. This means that you cannot log strings. 


Format strings. No string arguments. Max. 7 scalar arguments.

error/failure variants.

Trace messages don't show up if not at least one is created on another queue.

Debug trace messages, OS_ACTIVITY_MODE=debug

payload trace messages, OS_ACTIVITY_MODE=stream


## Inspecting Activity Tracing

thread info: only shows info from current thread

ostraceutil

crash reports


## Activity Tracing and Swift

At the time of writing, activity tracing is not accessible from Swift. Surely though it's just a matter of time until this will change.

If you want to use it now within a Swift project, you would have to create an Objective-C Wrapper around it and make this API accessible in Swift using the bridging header. Note though that activity tracing macros expect strings to be constants, i.e. you can't pass a string argument of your wrapper function to the activity tracing API.


## Conclusion



[wwdcsession]: https://developer.apple.com/videos/wwdc/2014/#714
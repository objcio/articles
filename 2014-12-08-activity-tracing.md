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

Activity tracing has three different parts to it: breadcrumbs, activities, and trace messages. We'll go into those in more detail below, but here's the gist of it: with breadcrumbs you can leave a trail of meaningful events leading up to a crash. Activities allow you to trace back the crashing code to its originating event in a cross-queue and cross-process manner. Finally, trace messages allow you to add further detail to the current activity. All this information will show up in the crash report in case anything goes wrong.


TODO: Code signing

## Breadcrumbs

Breadcrumbs are used for what the name suggests: you're code leaves a trail of labeled events while it executes to provide context in case a crash happens. Setting breadcrumbs is very simple:

```
os_activity_set_breadcrumb("event description");
```

Those event are stored in a ring buffer that only holds the last 50 events. Therefore this API should be used to indicate macro-level events, like meaningful user interactions.

Breadcrumbs only work inside activities.


## Activities

Started automatically on user events

Start your own activities from within other activities

Start your own activities from scratch

Activities will not show up if there's not at least one trace message within it's lifecycle


## Trace Messages

How to set trace messages

Format strings. No string arguments. Max. 7 scalar arguments.

error/failure variants.

Trace messages don't show up if not at least one is created on another queue.


## Inspecting Activity Tracing

thread info: only shows info from current thread

ostraceutil

crash reports


## Activity Tracing and Swift

At the time of writing, activity tracing is not accessible from Swift. Surely though it's just a matter of time until this will change.

If you want to use it now within a Swift project, you would have to create an Objective-C Wrapper around it and make this API accessible in Swift using the bridging header. Note though that activity tracing macros expect strings to be constants, i.e. you can't pass a string argument of your wrapper function to the activity tracing API.


## Conclusion



[wwdcsession]: https://developer.apple.com/videos/wwdc/2014/#714
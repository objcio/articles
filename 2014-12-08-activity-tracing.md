---
title:  "Activity Tracing"
category: "19"
date: "2014-12-08 07:00:00"
tags: article
author: "<a href=\"https://twitter.com/floriankugler\">Florian Kugler</a>"
---


Tracking down crashes in asynchronous code is often very hard, because the stack trace is confined to the crashed thread and you're missing contextual information. At the same time, writing asynchronous code has become significantly easier with APIs like [libdispatch](/issue-2/low-level-concurrency-apis.html), operation queues, and [XPC](/issue-14/xpc.html).

Activity tracing is a new technology introduced in iOS 8 and OS X 10.10 that aims to alleviate this problem. This year's WWDC had an excellent [session][wwdcsession] about it, but we thought it would be a good idea to give another overview here, since it is not widely known yet.

The basic idea is that work done in response to user interactions or other events is grouped under an activity, no matter if the work is done synchronously or if it's dispatched to other queues or processes. For example, if the user triggers a refresh in your app, you'll know that this particular user interaction caused a subsequent crash, even if it happens on a different queue and several other code paths could have led to the crashing code as well.

Activity tracing has three different parts to it: activities, breadcrumbs, and trace messages. We'll go into those in more detail below, but here's the gist of it: Activities allow you to trace the crashing code back to its originating event in a cross-queue and cross-process manner. With breadcrumbs, you can leave a trail of meaningful events across activities leading up to a crash. And finally, trace messages allow you to add further detail to the current activity. All this information will show up in the crash report in case anything goes wrong.

Before we go into more detail, let me just quickly mention a potential pitfall when trying to get activity tracing to work: if the activity messages are not showing up, check the `system.log` for any messages like "Signature Validation Failed" from the `diagnosticd` daemon — you might be running into code signing issues. Also, note that on iOS, activity tracing only works on a real device, and not in the simulator.


## Activities

Activities are at the heart of this new technology. An activity groups together the code executing in response to a certain event, no matter on what queues and in what processes the code is executing. This way, if anything goes wrong in the middle, the crash can be traced back to the original event.

Activity tracing is integrated into AppKit and UIKit, so that an activity is started automatically whenever a user interface event is sent through the target-action mechanism. In case of user interactions that don't send events through the responder chain (like a tap on a table view cell), you'll have to initiate an activity yourself.

Starting an activity is very simple:

```
#import <os/activity.h>

os_activity_initiate("activity name", OS_ACTIVITY_FLAG_DEFAULT, ^{
    // do some work...
});
```

This API executes the block synchronously, and everything you do within the block will be scoped under this activity, even if you dispatch work onto other queues or do XPC calls. The first parameter is the label of the activity, and has to be provided as a constant string (like all string parameters of the activity tracing API).

The second parameter, `OS_ACTIVITY_FLAG_DEFAULT`, is the activity flag you use to create an activity from scratch. If you want to create a new activity within the scope of an existing activity, you have to use `OS_ACTIVITY_FLAG_DETACHED`. For example, when reacting to an action message of a user interface control, AppKit has already started an activity for you. If you want to start an activity from here that is not the direct result of the user interaction, that's when you'd use a detached activity.

There are other variants of this API that work in the same away — a function-based one (`os_activity_initiate_f`), and one that consists of a pair of macros:

```
os_activity_t activity = os_activity_start("label", OS_ACTIVITY_FLAG_DEFAULT);
// do some work...
os_activity_end(activity);
```

Note that activities will not show up in crash reports (or other ways of inspecting them) if you don't set at least one trace message. See below for more details on trace messages.


## Breadcrumbs

Breadcrumbs are used for what the name suggests: your code leaves a trail of labeled events while it executes in order to provide context in case a crash happens. Setting breadcrumbs is very simple:

```
os_activity_set_breadcrumb("event description");
```

The events are stored in a ring buffer that only holds the last 50 events. Therefore, this API should be used to indicate macro-level events, like meaningful user interactions. Note that setting breadcrumbs only works in the scope of an activity.


## Trace Messages

Trace messages are used to add additional information to activities, very similar to how you would use log messages. You can use them to add valuable information to crash reports, in order to more easily understand the root cause of the problem. Within an activity, a very simple trace message can be set like this:

```
#import <os/trace.h>

os_trace("my message");
```

Trace messages can do more than that though. The first argument to `os_trace` is a format string, similar to what you'd use with `printf` or `NSLog`. However, there are some restrictions to this: the format string can be a maximum of 100 characters long and can contain a placeholder for up to seven *scalar* values. This means that you cannot log strings. If you try to do so, the strings will be replaced by a placeholder.

Here are two examples of using format strings with `os_trace`:

```
os_trace("Received %d creates, %d updates, %d deletes", created, updated, deleted);
os_trace("Processed %d records in %g seconds", count, time);
```

One caveat that I stumbled upon while experimenting with this API is that trace messages don't show up in crash reports if no trace messages are sent from the crashing thread.


### Trace Message Variants

There are several variants to the basic `os_trace` API. First, there's `os_trace_debug`, which you can use to output trace messages that only show up in debug mode. This can be helpful to reduce the amount of trace messages in production, so that you will only see the most meaningful ones, and don't flood the limited ring buffer that's used to storing those messages with less useful information. To enable debug mode, set the environment variable `OS_ACTIVITY_MODE` to `debug`.

Additionally, there are two more variants of these macros to output trace messages: `os_trace_error` and `os_trace_fault`. The first one can be used to indicate unexpected errors, and the second one to indicate catastrophic failures, i.e. that you're about to crash.

As discussed above, the standard `os_trace` API only accepts a constant format string of limited length and scalar values. This is done for privacy, security, and performance reasons. However, there are situations where you'd like to see more data when debugging a problem. This is where payload trace messages come in.

The API for this is `os_trace_with_payload`, and may seem a bit weird at first: similar to `os_trace`, it takes a format string, a variable number of value arguments, and a block with a parameter of type `xpc_object_t`. This block will not be called in production mode, and therefore poses no overhead. However, when debugging, you can store whatever data you want in the dictionary that the block receives as its first and only argument:

```
os_trace_with_payload("logged in: %d", guid, ^(xpc_object_t xdict) {
    xpc_dictionary_set_string(xdict, "name", username);
});
```

The reason that the argument to the block is an XPC object is that activity tracing works with the `diagnosticd` daemon under the hood to collect the data. By setting values in this dictionary using the `xpc_dictionary_set_*` APIs, you're communicating with this daemon. To inspect the payload data, you can use the `ostraceutil` command line utility, which we will look at in more detail below.

You can use payloads with all previously discussed variants of the `os_trace` macro. Next to `os_trace_with_payload` (which we used above), there's also `os_trace_debug_with_payload`, `os_trace_error_with_payload`, and `os_trace_fault_with_payload`.


## Inspecting Activity Tracing

There are two ways you can get to the output of activity tracing aside from crash reports. First, activity tracing is integrated into the debugger. By typing `thread info` into the LLDB console, you can inspect the current activity and the trace messages from the current thread:

```
(lldb) thread info
thread #1: tid = 0x19514a, 0x000000010000125b ActivityTracing2`__24-[ViewController crash:]_block_invoke_4(.block_descriptor=<unavailable>) + 27 at ViewController.m:26, queue = 'com.apple.main-thread', activity = 'crash button pressed', 1 messages, stop reason = EXC_BAD_ACCESS (code=1, address=0x0)

  Activity 'crash button pressed', 0x8e700000005

  Current Breadcrumb: button pressed

  1 trace messages:
    message1
```

Another option is to use the `ostraceutil` command line utility. Executing

```
sudo ostraceutil -diagnostic -process <pid> -quiet
```

from the command line (replace `<pid>` with the process id) yields the following (shortened) information:

```
Process:
==================
PID: 16992
Image_uuid: FE5A6C31-8710-330A-9203-CA56366876E6
Image_path: [...]

Application Breadcrumbs:
==================
Timestamp: 59740.861604, Breadcrumb ID = 6768, Name = 'Opened theme picker', Activity ID: 0x000008e700000001
Timestamp: 59742.202451, Breadcrumb ID = 6788, Name = 'button pressed', Activity ID: 0x000008e700000005

Activity:
==================
Activity ID: 0x000008e700000005
Activity Name: crash button pressed
Image Path: [...]
Image UUID: FE5A6C31-8710-330A-9203-CA56366876E6
Offset: 0x1031
Timestamp: 59742.202350
Reason: none detected

Messages:
==================
Timestamp: 59742.202508
FAULT
Activity ID: 0x000008e700000005
Trace ID: 0x0000c10000001ac0
Thread: 0x1951a8
Image UUID: FE5A6C31-8710-330A-9203-CA56366876E6
Image Path: [...]
Offset: 0x118d
Message: 'payload message'
----------------------
Timestamp: 59742.202508
RELEASE
Trace ID: 0x0000010000001aad
Offset: 0x114c
Message: 'message2'
----------------------
Timestamp: 59742.202350
RELEASE
Trace ID: 0x0000010000001aa4
Thread: 0x19514a
Offset: 0x10b2
Message: 'message1'
```

The output is more extensive than the one from the LLDB console, since it also contains the breadcrumb trail, as well as the trace messages from all threads.

Instead of using `ostraceutil` with the `-diagnostic` flag, we can also use the `-watch` flag to put it into a live mode where we can see the trace messages and breadcrumbs coming in as they happen. In this mode, we can also see the payload data of trace messages:

```
[...]
----------------------
Timestamp: 60059.327207
FAULT
Trace ID: 0x0000c10000001ac0
Offset: 0x118d
Message: 'payload message'
Payload: '<dictionary: 0x7fd2b8700540> { count = 1, contents =
	"test-key" => <string: 0x7fd2b87000c0> { length = 10, contents = "test-value" }
}'
----------------------
[...]
```


## Activity Tracing and Swift

At the time of writing, activity tracing is not accessible from Swift.

If you want to use it now within a Swift project, you would have to create an Objective-C wrapper around it and make this API accessible in Swift using the bridging header. Note that activity tracing macros expect strings to be constant, i.e. you can't pass a string argument of your wrapper function to the activity tracing API. To illustrate this point, the following doesn't work:

```
void sendTraceMessage(const char *msg) {
    os_trace(msg); // this doesn't work!
}
```

One possible workaround is to define specific helper functions like this:

```
void traceLogin(int guid) {
    os_trace("Login: %d", guid);
}
```


## Conclusion

Activity tracing is a very welcome addition to our debugging toolkit and makes diagnosing crashes in asynchronous code so much easier. We really should make it a habit to add activities, breadcrumbs, and trace messages to our code.

The most painful point at this time is the missing Swift integration, at least for those of us who already use Swift in production code. Hopefully it is just a matter of (a not too long) time until this will change.


[wwdcsession]: https://developer.apple.com/videos/wwdc/2014/#714

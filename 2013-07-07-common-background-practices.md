---
title:  "Common Background Practices"
category: "2"
date: "2013-07-07 09:00:00"
author:
  - name: Chris Eidhof
    url: http://twitter.com/chriseidhof
tags: article
---


In this article we will describe best practices for doing common
tasks in the background. We will look at how to use Core Data concurrently,
how to draw concurrently, and how to do asynchronous networking. Finally,
we'll look at how to process large files asynchronously while keeping a
low memory profile. 

With asynchronous programming it is very easy to make mistakes. Therefore, all 
examples in this article will use a very simple approach. Using 
simple structures helps us to think through our code and to maintain an overview.
If you end up with complicated nested callbacks, you should probably revise some of your design decisions.

## Operation Queues vs. Grand Central Dispatch

Currently, there are two main modern concurrency APIs available on iOS and OS X:
[operation queues](http://developer.apple.com/library/ios/#documentation/Cocoa/Reference/NSOperationQueue_class/Reference/Reference.html)
and [Grand Central Dispatch](https://developer.apple.com/library/ios/#documentation/Performance/Reference/GCD_libdispatch_Ref/Reference/reference.html) (GCD). 
GCD is a low-level C API, whereas operation queues are implemented
on top of GCD and provide an Objective-C API. For a more comprehensive
overview of available concurrency APIs see the [concurrency APIs and challenges][100] 
article in this issue.

Operation queues offer some useful convenience features not easily 
reproducible with GCD. In practice, one of the most important ones is 
the possibility to cancel operations in the queue, as we will demonstrate below.
Operation queues also make it a bit easier to manage dependencies between operations. 
On the flip side, GCD gives you more control and low-level functionality that
is not available with operation queues. Please refer to the
[low level concurrency APIs][300] article for more details.

Further reading:

* [StackOverflow: NSOperation vs. Grand Central Dispatch](http://stackoverflow.com/questions/10373331/nsoperation-vs-grand-central-dispatch)
* [Blog: When to use NSOperation vs. GCD](http://eschatologist.net/blog/?p=232)


### Core Data in the Background

**Update March 2015**: This is based off of older recommendations in the now outdated Core Data Concurrency Guide.

Before doing anything concurrent with Core Data, it is important to get
the basics right. We strongly recommend reading through Apple's [Concurrency
with Core Data](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CoreData/Concurrency.html) guide.
This document lays down the ground rules, such as never passing managed objects between
threads. This doesn't just mean that you should never modify a managed object on another
thread, but also that you should never read any properties from it. To pass around
an object, pass its object ID and retrieve the object from the context associated to the
other thread.

Doing concurrent programming with Core Data is simple when you stick to those rules 
and use the method described in this article.

The standard setup for Core Data in the Xcode templates is one
persistent store coordinator with one managed object context that runs
on the main thread. For many use cases, this is just fine.
Creating some new objects and modifying existing objects is very cheap and can
be done on the main thread without problems.
However, if you want to do big chunks of work, then it makes sense to do this 
in a background context. A prime example for this is importing large data sets
into Core Data.

Our approach is very simple, and well-covered in existing literature:

1. We create a separate operation for the import work
2. We create a managed object context with the same persistent store
   coordinator as the main managed object context
3. Once the import context saves, we notify the main managed object
   context and merge the changes

In the [example application](https://github.com/objcio/issue-2-background-core-data), we will import a big set of transit data for
the city of Berlin. 
During the import, we show a progress indicator, and we'd like to be able 
to cancel the current
import if it's taking too long. Also, we show a table view with all the
data available so far, which automatically updates when new data comes in.
The example data set is publicly available under the Creative
Commons license, and you can download it [here](http://stg.daten.berlin.de/datensaetze/vbb-fahrplan-2013). It conforms to the [General Transit
Feed](https://developers.google.com/transit/gtfs/reference) format, an
open standard for transit data. 

We create an `ImportOperation` as a subclass of `NSOperation`, which will handle
the import. We override the `main` method, which is
the method that will do all the work. Here we create a separate
managed object context with the private queue concurrency type. This means that
this context will manage its own queue, and all operations on it
need to be performed using `performBlock` or `performBlockAndWait`.
This is crucial to make sure that they will be executed on the right thread.

```objc
NSManagedObjectContext* context = [[NSManagedObjectContext alloc]
    initWithConcurrencyType:NSPrivateQueueConcurrencyType];
context.persistentStoreCoordinator = self.persistentStoreCoordinator;
context.undoManager = nil;
[self.context performBlockAndWait:^
{
    [self import];
}];
```

Note that we reuse the existing persistent store coordinator.
In modern code, you should initialize managed object contexts with either
the `NSPrivateQueueConcurrencyType` or the `NSMainQueueConcurrencyType`. 
The third concurrency type constant, `NSConfinementConcurrencyType`, is for 
legacy code, and our advice is to not use it anymore.

To do the import, we iterate over the lines in our file and create a
managed object for each line that we can parse:

```objc
[lines enumerateObjectsUsingBlock:
  ^(NSString* line, NSUInteger idx, BOOL* shouldStop)
  {
      NSArray* components = [line csvComponents];
      if(components.count < 5) {
          NSLog(@"couldn't parse: %@", components);
          return;
      }
      [Stop importCSVComponents:components intoContext:context];
  }];
```

To start this operation, we perform the following code from our view
controller:

```objc
ImportOperation* operation = [[ImportOperation alloc] 
     initWithStore:self.store fileName:fileName];
[self.operationQueue addOperation:operation];
```

For importing in the background, that's all you have to do. Now, we will add
support for cancelation, and luckily, it's as simple as adding one check
inside the enumeration block:

```objc
if(self.isCancelled) {
    *shouldStop = YES;
    return;
}
```

Finally, to support progress indication, we create a `progressCallback`
property on our operation. It is vital that we update our progress indicator on the main thread, otherwise UIKit will crash. 

```objc
operation.progressCallback = ^(float progress) 
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^
    {
        self.progressIndicator.progress = progress;
    }];
};
```

To call the progress block, we add the following line in the enumeration block:

```objc
self.progressCallback(idx / (float) count);
```

However, if you run this code, you will see that everything slows down
enormously. Also, it looks like the operation doesn't cancel
immediately. The reason for this is that the main operation queue fills up with
blocks that want to update the progress indicator. A simple solution is to decrease 
the granularity of updates, i.e. we only call the progress callback for
one percent of the lines imported:

```objc
NSInteger progressGranularity = lines.count / 100;

if (idx % progressGranularity == 0) {
    self.progressCallback(idx / (float) count);
}
```

### Updating the Main Context

The table view in our app is backed by a fetched results controller 
on the main thread. During and after the import, we'd like
to show the results of the import in our table view.

There is one missing piece to make this work; the data imported into the 
background context will not propagate to the main context unless we explicitly
tell it to do so. We add the following line to the `init` method of the `Store` class where we set up the Core Data stack:

```objc
[[NSNotificationCenter defaultCenter] 
    addObserverForName:NSManagedObjectContextDidSaveNotification
                object:nil
                 queue:nil
            usingBlock:^(NSNotification* note)
{
    NSManagedObjectContext *moc = self.mainManagedObjectContext;
    if (note.object != moc)
        [moc performBlock:^(){
            [moc mergeChangesFromContextDidSaveNotification:note];
        }];
    }];
}];
```

Note that by calling `performBlock:` on the main managed object context, the block will be called on the main thread. 
If you now start the app, you will notice that the table view reloads 
its data at the end of the import. However, this blocks the user interface 
for a couple of seconds.

To fix this, we need to do something that we should have
done anyway: save in batches. When doing large imports, you want to
ensure that you save regularly, otherwise you might run out of memory, and 
performance generally will get worse. Furthermore, saving regularly 
spreads out the work on the main thread to update the table view over time.

How often you save is a matter of trial and
error. Save too often, and you'll spend too much time doing I/O. Save too
little, and the app will become unresponsive. We set the batch
size to 250 after trying out some different numbers. Now the import is
smooth, updates the table view, and doesn't block the main context for
too long.


### Other Considerations

In the import operation, we read the entire file into a string and then
split that into lines. This will work for relatively small files,
but for larger files, it makes sense to lazily read the file line by line. 
The last example in this article will do exactly that by using input streams.
There's also an excellent [write-up on
StackOverflow](http://stackoverflow.com/questions/3707427/how-to-read-data-from-nsfilehandle-line-by-line/3711079#3711079)
by Dave DeLong that shows how to do this.

Instead of importing a large data set into core data when the app first runs, 
you could also ship an sqlite file within your app bundle, or download it 
from a server, where you could even generate it dynamically. 
If your particular use case works 
with this solution, it will be a lot faster and save processing time on the device.

Finally, there is a lot of noise about child contexts these days. Our
advice is not to use them for background operations. If you create a
background context as a child of the main context, saving the background
context [will still block the main thread](http://floriankugler.com/blog/2013/4/29/concurrent-core-data-stack-performance-shootout) a lot. If you create
the main context as a child of a background context, you actually don't
gain anything compared to a more traditional setup with two independent
contexts, because you still have to merge the changes from the background to 
the main context manually. 

The setup with one persistent store coordinator and
two independent contexts is the proven way of doing core data in the background. Stick with it unless you have really good reasons not to.

Further reading:

* [Core Data Programming Guide: Efficiently importing data](http://developer.apple.com/library/ios/#documentation/Cocoa/Conceptual/CoreData/Articles/cdImporting.html)
* [Core Data Programming Guide: Concurrency with Core Data](http://developer.apple.com/library/ios/#documentation/Cocoa/Conceptual/CoreData/Articles/cdConcurrency.html#//apple_ref/doc/uid/TP40003385-SW1j)
* [StackOverflow: Rules for working with Core Data](http://stackoverflow.com/questions/2138252/core-data-multi-thread-application/2138332#2138332)
* [WWDC 2012 Video: Core Data Best Practices](https://developer.apple.com/videos/wwdc/2012/?id=214)
* [Book: Core Data by Marcus Zarra](http://pragprog.com/book/mzcd/core-data)

 
## UI Code in the Background

First of all: UIKit only works on the main thread. That said,
there are some parts of UI code which are not directly related to UIKit 
and which can take a significant amount of time. These tasks can be moved
to the background to not block the main thread for too long.
But before you start moving parts of your UI code into background queues,
it's important to measure which part of your code really is the problem.
This is vital, otherwise you might be optimizing the wrong thing.

If you have identified an expensive operation that you can isolate, 
put it in an operation queue:

```objc
__weak id weakSelf = self;
[self.operationQueue addOperationWithBlock:^{
    NSNumber* result = findLargestMersennePrime();
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        MyClass* strongSelf = weakSelf;
        strongSelf.textLabel.text = [result stringValue];
    }];
}];
```

As you can see, this is not completely straightforward; we need to make
a weak reference to self, otherwise we create a retain cycle (the block
retains self, the private operation queue retains the block, and self
retains the operation queue). Within the block we convert it
back to a strong reference to make sure it doesn't get deallocated while
running the block. 

### Drawing in the Background

If your measurements show that `drawRect`: is your performance bottleneck, 
you can move this drawing code to the background. Before
you do that though, check if there are other ways to achieve the same effect, 
e.g. by using core animation layers or pre-rendered images instead of plain 
Core Graphics drawing. See [this
post](http://floriankugler.com/blog/2013/5/24/layer-trees-vs-flat-drawing-graphics-performance-across-ios-device-generations)
by Florian for graphic performance measurements on current devices, or
[this comment](https://lobste.rs/s/ckm4uw/a_performance-minded_take_on_ios_design/comments/itdkfh)
by Andy Matuschak, a UIKit engineer, to get a good feel for all the
subtleties involved.

If you do decide that your best option is to execute the drawing code
in the background, the solution is quite simple. Take the code in your
`drawRect:` method and put it in an operation. Then replace the
original view with an image view that gets updated once the operation has
completed. In your drawing method, use
`UIGraphicsBeginImageContextWithOptions` instead of `UIGraphicsGetCurrentContext`:

```objc
UIGraphicsBeginImageContextWithOptions(size, NO, 0);
// drawing code here
UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
UIGraphicsEndImageContext();
return i;
```

By passing in 0 as the third parameter, the scale of the device's main screen
will be automatically filled in, and the image will look great on both
retina and non-retina devices.

If you do custom drawing in table view or collection view cells, it makes sense to put
all that into operation subclasses. You can add them to a background operation queue, and
cancel them when the user scrolls cells out of bounds from the `didEndDisplayingCell`
delegate method. All of this is explained in detail in [WWDC 2012 Session 211 -- Building Concurrent User Interfaces on iOS](https://developer.apple.com/videos/wwdc/2012/).

Instead of scheduling the drawing code in the background yourself, you should 
also experiment with the `drawsAsynchronously` property of `CALayer`. However, make sure to measure the effect of this. Sometimes it speeds things up, and sometimes
it's counterproductive.


## Asynchronous Networking

All your networking should be done asynchronously.
However, with Grand Central Dispatch, you sometimes see code like this:

```objc
// Warning: please don't use this code.
dispatch_async(backgroundQueue, ^{
   NSData* contents = [NSData dataWithContentsOfURL:url]
   dispatch_async(dispatch_get_main_queue(), ^{
      // do something with the data.
   });
});
```

This might look quite smart, but there is a big problem with this code: there
is no way to cancel this synchronous network call. It will block the
thread until it's done. In case the operation times out, this might take a
very long time (e.g. `dataWithContentsOfURL` has a timeout of 30 seconds). 

If the queue is a serial queue, then it will be blocked for the whole time. If the queue is concurrent, then GCD has to spin up a new thread in order to make up for the thread which you are blocking. Both cases are not good. It's best to avoid blocking altogether.

To improve upon this situation, we will use the asynchronous methods of 
`NSURLConnection` and wrap everything up in an operation. This way we get the
full power and convenience of operation queues; we can easily control
the number of concurrent operations, add dependencies, and cancel
operations. 

However, there is something to watch out for when doing this: URL
connections deliver their events in a run loop. It is easiest to just
use the main run loop for this, as the data delivery doesn't take much
time. Then we can dispatch the processing of the incoming data onto
a background thread. 

Another possibility is the approach that libraries like [AFNetworking](http://afnetworking.com) take:
create a separate thread, set up a run loop on this thread, and schedule 
the url connection there. But you probably wouldn't want to do this yourself.

To kick off the URL connection, we override the `start` method in our custom operation subclass:

```objc
- (void)start
{
    NSURLRequest* request = [NSURLRequest requestWithURL:self.url];
    self.isExecuting = YES;
    self.isFinished = NO;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^
    {
        self.connection = [NSURLConnection connectionWithRequest:request
                                                        delegate:self];
    }];
}
```

Since we overrode the `start` method, we now must manage the 
operation's state properties, `isExecuting` and `isFinished`, ourselves. 
To cancel an operation, we need to cancel the connection and then set
the right flags so the operation queue knows the operation is done.

```objc
- (void)cancel
{
    [super cancel];
    [self.connection cancel];
    self.isFinished = YES;
    self.isExecuting = NO;
}
```

When the connection finishes loading, it sends a delegate callback:

```objc
- (void)connectionDidFinishLoading:(NSURLConnection *)connection 
{
    self.data = self.buffer;
    self.buffer = nil;
    self.isExecuting = NO;
    self.isFinished = YES;
}
```

And that's all there is to it. Check the [example project on GitHub](https://github.com/objcio/issue-2-background-networking)
for the full source code. 
To conclude, we would like to recommend either taking your time to do this
right, or to use a library like
[AFNetworking](http://afnetworking.com). They
provide handy utilities like a category on `UIImageView` that asynchronously loads an image from a URL.
Using this in your table view code will automatically take care of
canceling image loading operations.

Further reading:

* [Concurrency Programming Guide](http://developer.apple.com/library/ios/#documentation/General/Conceptual/ConcurrencyProgrammingGuide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008091-CH1-SW1)
* [NSOperation Class Reference: Concurrent vs. Non-Concurrent Operations](http://developer.apple.com/library/ios/#documentation/Cocoa/Reference/NSOperation_class/Reference/Reference.html%23http://developer.apple.com/library/ios/#documentation/Cocoa/Reference/NSOperation_class/Reference/Reference.html%23//apple_ref/doc/uid/TP40004591-RH2-SW15)
* [Blog: synchronous vs. asynchronous NSURLConnection](http://www.cocoaintheshell.com/2011/04/nsurlconnection-synchronous-asynchronous/)
* [GitHub: `SDWebImageDownloaderOperation.m`](https://github.com/rs/SDWebImage/blob/master/SDWebImage/SDWebImageDownloaderOperation.m)
* [Blog: Progressive image download with ImageIO](http://www.cocoaintheshell.com/2011/05/progressive-images-download-imageio/)
* [WWDC 2012 Session 211: Building Concurrent User Interfaces on iOS](https://developer.apple.com/videos/wwdc/2012/)


## Advanced: File I/O in the Background

In our core data background example, we read the entire file 
that is to be imported into memory.
This works for smaller files, but for larger files this is not
feasible, because memory is limited on iOS devices.
To resolve this problem, we will build a class that does two things:
it reads a file line by line without having the entire file in
memory, and process the file on a background queue so the app stays
responsive.

For this purpose we use `NSInputStream`, which will let us do asynchronous 
processing of a file. As [the documentation](http://developer.apple.com/library/ios/#documentation/FileManagement/Conceptual/FileSystemProgrammingGUide/TechniquesforReadingandWritingCustomFiles/TechniquesforReadingandWritingCustomFiles.html)
says: <q>If you always read or write a file’s contents from start to
finish, streams provide a simple interface for doing so
asynchronously.</q>.

Whether you use streams or not, the general pattern for reading a file
line-by-line is as follows:

1. Have an intermediate buffer that you append to while not finding a newline
2. Read a chunk from the stream
3. For each newline found in the chunk, take the intermediate buffer,
   append data from the stream up to (and including) the newline, and output that
4. Append the remaining bytes to the intermediate buffer
5. Go back to 2 until the stream closes

To put this into practice, we created a [sample application](https://github.com/objcio/issue-2-background-file-io) with a
`Reader` class that does just this. The interface is very simple:

```objc
@interface Reader : NSObject
- (void)enumerateLines:(void (^)(NSString*))block
            completion:(void (^)())completion;
- (id)initWithFileAtPath:(NSString*)path;
@end
```

Note that this is not a subclass of `NSOperation`. Like URL connections, 
input streams deliver
their events using a run loop. Therefore, we will use the main run loop 
again for event delivery, and then dispatch the processing of the data
onto a background operation queue.

```objc
- (void)enumerateLines:(void (^)(NSString*))block
            completion:(void (^)())completion
{
    if (self.queue == nil) {
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.maxConcurrentOperationCount = 1;
    }
    self.callback = block;
    self.completion = completion;
    self.inputStream = [NSInputStream inputStreamWithURL:self.fileURL];
    self.inputStream.delegate = self;
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                forMode:NSDefaultRunLoopMode];
    [self.inputStream open];
}
```

Now the input stream will send us delegate messages (on the main
thread), and we do the processing on the operation
queue by adding a block operation:

```objc
- (void)stream:(NSStream*)stream handleEvent:(NSStreamEvent)eventCode
{
    switch (eventCode) {
        ...
        case NSStreamEventHasBytesAvailable: {
            NSMutableData *buffer = [NSMutableData dataWithLength:4 * 1024];
            NSUInteger length = [self.inputStream read:[buffer mutableBytes] 
                                             maxLength:[buffer length]];
            if (0 < length) {
                [buffer setLength:length];
                __weak id weakSelf = self;
                [self.queue addOperationWithBlock:^{
                    [weakSelf processDataChunk:buffer];
                }];
            }
            break;
        }
        ...
    }
}
```

Processing a data chunk looks at the current buffered data and appends
the newly streamed chunk. It then breaks that into components, separated
by newlines, and emits each line. The remainder gets stored again:

```objc
- (void)processDataChunk:(NSMutableData *)buffer;
{
    if (self.remainder != nil) {
        [self.remainder appendData:buffer];
    } else {
        self.remainder = buffer;
    }
    [self.remainder obj_enumerateComponentsSeparatedBy:self.delimiter
                                            usingBlock:^(NSData* component, BOOL last) {
        if (!last) {
            [self emitLineWithData:component];
        } else if (0 < [component length]) {
            self.remainder = [component mutableCopy];
        } else {
            self.remainder = nil;
        }
    }];
}
```

If you run the sample app, you will see that the app stays very
responsive, and the memory stays very low (in our test runs, the heap
size stayed under 800 KB, regardless of the file size). For processing
large files chunk by chunk, this technique is probably what you want.

Further reading:

* [File System Programming Guide: Techniques for Reading and Writing Files Without File Coordinators](http://developer.apple.com/library/ios/#documentation/FileManagement/Conceptual/FileSystemProgrammingGUide/TechniquesforReadingandWritingCustomFiles/TechniquesforReadingandWritingCustomFiles.html)
* [StackOverflow: How to read data from NSFileHandle line by line?](http://stackoverflow.com/questions/3707427/how-to-read-data-from-nsfilehandle-line-by-line)

## Conclusion

In the examples above we demonstrated how to perform common tasks
asynchronously in the background. In all of these solutions, we tried 
to keep our code simple, because it's very easy to make mistakes with 
concurrent programming without noticing.

Oftentimes you might get away with just doing your work on the main thread,
and when you can, it'll make your life a lot easier. But if you find performance bottlenecks, put these tasks into the background using the 
simplest approach possible. 

The pattern we showed in the examples above is a safe choice for other 
tasks as well. Receive events or data on the main queue, then
use a background operation queue to perform the actual work before getting 
back onto the main queue to deliver the results.


[90]: /issues/2-concurrency/editorial/
[100]: /issues/2-concurrency/concurrency-apis-and-pitfalls/
[101]: /issues/2-concurrency/concurrency-apis-and-pitfalls/#challenges
[102]: /issues/2-concurrency/concurrency-apis-and-pitfalls/#priority_inversion
[103]: /issues/2-concurrency/concurrency-apis-and-pitfalls/#shared_resources
[104]: /issues/2-concurrency/concurrency-apis-and-pitfalls/#dead_locks
[200]: /issues/2-concurrency/common-background-practices/
[300]: /issues/2-concurrency/low-level-concurrency-apis/
[301]: /issues/2-concurrency/low-level-concurrency-apis/#async
[302]: /issues/2-concurrency/low-level-concurrency-apis/#multiple-readers-single-writer
[400]: /issues/2-concurrency/thread-safe-class-design/

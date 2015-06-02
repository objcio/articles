---
title:  "Communication Patterns"
category: "7"
date: "2013-12-09 08:00:00"
tags: article
author:
  - name: Florian Kugler
    url: https://twitter.com/floriankugler
---


Every application consists of multiple more or less loosely coupled objects that need to communicate with each other to get the job done. In this article we will go through all the available options, look at examples how they are used within Apple’s frameworks, and extract some best-practice recommendations regarding when you should use which mechanism. 

Although this issue is about the Foundation framework, we will look beyond the communication mechanisms that are part of Foundation -- KVO and Notifications -- and also talk about delegation, blocks, and target-action. 

Of course, there are cases where there is no definitive answer as to what pattern should be used, and the choice comes down to a matter of taste. But there are also many cases that are pretty clear cut.

In this article, we will often use the terms "recipient" and "sender.” What we mean with those in the context of communication patterns is best explained by a few examples: a table view is the sender, while its delegate is the recipient. A Core Data managed object context is the sender of the notifications it posts, and whatever picks them up is the recipient. A slider is the sender of a action message, and the responder that implements this action is the recipient. An object with a KVO-compliant property that changes is the sender, while the observer is the recipient. Getting the hang of it?



## Patterns

First we will have a look at the specific characteristics of each available communication pattern. Based on this, we will construct a flow chart in the next section that helps to choose the right tool for the job. Finally, we will go over some examples from Apple's frameworks and reason why they decided to use specific patterns for certain use cases.


### KVO

KVO is a mechanism to notify objects about property changes. It is implemented in Foundation and many frameworks built on top of Foundation rely on it. To read more about best practices and examples of how to use KVO, please read Daniel's [KVO and KVC article](/issues/7-foundation/key-value-coding-and-observing/) in this issue.

KVO is a viable communication pattern if you're only interested in changed values of another object. There are a few more requirements though. First, the recipient -- the object that will receive the messages about changes -- has to know about the sender -- the object with values that are changed. Furthermore, the recipient also needs to know about the lifespan of the sender, because it has to unregister the observer before the sender object gets deallocated. If all these requirements are met, the communication can even be one-to-many, since multiple observers can register for updates from the object in question. 

If you plan to use KVO on Core Data objects, you have to know that things work a bit differently here. This has to do with Core Data's faulting mechanism. Once a managed object turns into a fault, it will fire the observers on its properties although their values haven't changed.


### Notifications

Notifications are a very good tool to broadcast messages between relatively unrelated parts of your code, especially if the messages are more informative in kind and you don't necessarily expect anyone to do something with them. 

Notifications can be used to send arbitrary messages and they can even contain a payload in form of their `userInfo` dictionary or by subclassing `NSNotification`. What makes notifications unique is that the sender and the recipient don't have to know each other. They can be used to send information between very loosely coupled modules. Therefore, the communication is one-way -- you cannot reply to a notification.


### Delegation

Delegation is a widespread pattern throughout Apple's frameworks. It allows us to customize an object's behavior and to be notified about certain events. For the delegation pattern to work, the message sender needs to know about the recipient (the delegate), but not the other way around. The coupling is further loosened, because the sender only knows that its delegate conforms to a certain protocol.

Since a delegate protocol can define arbitrary methods, you can model the communication exactly to your needs. You can hand over payloads in the form of method arguments, and the delegate can even respond in terms of the delegate method's return value. Delegation is a very flexible and straightforward communication pattern if you only need to communicate between two specific objects that are in relative proximity to each other in terms of their place in your app architecture.

But there's also the danger of overusing the delegation pattern. If two objects are that tightly coupled to each other that one cannot function without the other, there's no need to define a delegate protocol. In these cases, the objects can know of the other's type and talk to each other directly. Two modern examples of this are `UICollectionViewLayout` and `NSURLSessionConfiguration`. 

<a name="blocks"> </a>

### Blocks

Blocks are a relatively recent addition to Objective-C, first available in OS X 10.6 and iOS 4. Blocks can often fulfill the role of what previously would have been implemented using the delegation pattern. However, both patterns have unique sets of requirements and advantages.

One pretty clear criterium of when not to use blocks has to do with the danger of creating [retain cycles](https://developer.apple.com/library/mac/documentation/cocoa/conceptual/memorymgmt/Articles/mmPractical.html#//apple_ref/doc/uid/TP40004447-1000810). If the sender needs to retain the block and cannot guarantee that this reference will be a nilled out, then every reference to `self` from within the block becomes a potential retain cycle.

Let's assume we wanted to implement a table view, but we want to use block callbacks instead of a delegate pattern for the selection methods, like this:

    self.myTableView.selectionHandler = ^void(NSIndexPath *selectedIndexPath) {
        // handle selection ...
    };
    
The issue here is that `self` retains the table view, and the table view has to retain the block in order to be able to use it later. The table view cannot nil out this reference, because it cannot tell when it will not need it anymore. If we cannot guarantee that the retain cycle will be broken and we will retain the sender, then blocks are not a good choice.

`NSOperation` is a good example of where this does not become a problem, because it breaks the retain cycle at some point:

    self.queue = [[NSOperationQueue alloc] init];
    MyOperation *operation = [[MyOperation alloc] init];
    operation.completionBlock = ^{
        [self finishedOperation];
    };
    [self.queue addOperation:operation];
    
At first glance this seems like a retain cycle: `self` retains the queue, the queue retains the operation, the operation retains the completion block, and the completion block retains `self`. However, adding the operation to the queue will result in the operation being executed at some point and then being removed from the queue afterward. (If it doesn't get executed, we have a bigger problem anyway.) Once the queue removes the operation, the retain cycle is broken.

Another example: let's say we're implementing a video encoder class, on which we call an `encodeWithCompletionHandler:` method. To make this non-problematic, we have to guarantee that the encoder object nils out its reference to the block at some point. Internally, this would have to look something like this:

    @interface Encoder ()
    @property (nonatomic, copy) void (^completionHandler)();
    @end
    
    @implementation Encoder
    
    - (void)encodeWithCompletionHandler:(void (^)())handler
    {
        self.completionHandler = handler;
        // do the asynchronous processing...
    }
    
    // This one will be called once the job is done
    - (void)finishedEncoding
    {
        self.completionHandler();
        self.completionHandler = nil; // <- Don't forget this!
    }
    
    @end
    
Once our job is done and we've called the completion block, we nil it out. 

Blocks are a very good fit if a message we call has to send back a one-off response that is specific to this method call, because then we can break potential retain cycles. Additionally, if it helps readability to have the code processing the message together with the message call, it's hard to argue against the use of blocks. Along these lines, a very common use case of blocks are completion handlers, error handlers, and the like.


### Target-Action

Target-Action is the typical pattern used to send messages in response to user-interface events. Both `UIControl` on iOS and `NSControl`/`NSCell` on the Mac have support for this pattern. Target-Action establishes a very loose coupling between the sender and the recipient of the message. The recipient of the message doesn't know about the sender, and even the sender doesn't have to know up front what the recipient will be. In case the target is `nil`, the action will travel up the [responder chain](https://developer.apple.com/library/ios/documentation/general/conceptual/Devpedia-CocoaApp/Responder.html) until it finds an object that responds to it. On iOS, each control can even be associated with multiple target-action pairs.

A limitation of target-action-based communication is that the messages sent cannot carry any custom payloads. On the Mac action methods always receive the sender as first argument. On iOS they optionally receive the sender and the event that triggered the action as arguments. But beyond that, there is no way to have a control send other objects with the action message.


## Making the Right Choice

Based on the characteristics of the different patterns outlined above, we have constructed a flowchart that helps to make good decisions of which pattern to use in what situation. As a word of warning: the recommendation of this chart doesn't have to be the final answer; there might be other alternatives that work equally well. But in most cases it should guide you to the right pattern for the job.

![Decision flow chart for communication patterns in Cocoa](/images/issue-7/communication-patterns-flow-chart.png)

There are a few other details in this chart which deserve further explanation:

One of the boxes says, *sender is KVO compliant*. This doesn't mean only that the sender sends KVO notifications when the value in question changes, but also that the observer knows about the lifespan of the sender. If the sender is stored in a weak property, it can get nilled out at any time and the observer will leak.

Another box in the bottom row says, *message is direct response to method call*. This means that the receiver of the method call needs to talk back to the caller of the method as a direct response of the method call. It mostly also means that it makes sense to have the code processing this message in the same place as the method call.

Lastly, in the lower right, a decision question states, *sender can guarantee to nil out reference to block?*. This refers to the discussion [above](#blocks) about block-based APIs and potential retain cycles. If the sender cannot guarantee that the reference to the block it’s holding will be nilled out at some point, you're asking for trouble with retain cycles.


## Framework Examples

In this section, we will go through some examples from Apple's frameworks to see if the decision flow outlined before actually makes sense, and why Apple chose the patterns as they are.


### KVO

`NSOperationQueue` uses KVO to observe changes to the state properties of its operations (`isFinished`, `isExecuting`, `isCancelled`). When the state changes, the queue gets a KVO notification. Why do operation queues use KVO for this? 

The recipient of the messages (the operation queue) clearly knows the sender (the operation) and controls its lifespan by retaining it. Furthermore, this use case only requires a one-way communication mechanism. When it comes to the question of if the operation queue is only interested in value changes of the operation, the answer is less clear. But we can at least say that what has to be communicated (the change of state) can be modeled as value changes. Since the state properties are useful to have beyond the operation queue's need to be up to date about the operation's status, using KVO is a logical choice in this scenario.

![Decision flow chart for communication patterns in Cocoa](/images/issue-7/kvo-flow-chart.png)

KVO is not the only choice that would work though. We could also imagine that the operation queue becomes the operation's delegate, and the operation would call methods like `operationDidFinish:` or `operationDidBeginExecuting:` to signal changes in its state to the queue. This would be less convenient though, because the operation would have to keep its state properties up to date in addition to calling these methods. Furthermore, the queue would have to keep track of the state of all its operations, because it cannot ask for them anymore.


### Notifications

Core Data uses notifications to communicate events like changes within a managed object context (`NSManagedObjectContextObjectsDidChangeNotification`). 

The change notification is sent by managed object contexts, so that we cannot assume that the recipient of this message necessarily knows about the sender. Since the origin of the message is clearly not a UI event, multiple recipients might be interested in it, and all it needs is a one-way communication channel, notifications are the only feasible choice in this scenario.

![Decision flow chart for communication patterns in Cocoa](/images/issue-7/notification-flow-chart.png)


### Delegation

Table view delegates fulfill a variety of functions, from managing accessory views over editing to tracking the cells that are on screen. For the sake of this example, we'll look at the `tableView:didSelectRowAtIndexPath:` method. Why is this implemented as a delegate call? Why not as a target-action pattern?

As we've outlined in the flowchart above, target-action only works if you don't have to transport any custom payloads. In the selection case, the collection view tells us not only that a cell got selected, but also which cell got selected by handing over its index path. If we maintain this requirement to send the index path, our flowchart guides us straight to the delegation pattern.

![Decision flow chart for communication patterns in Cocoa](/images/issue-7/delegation-flow-chart.png)

What about the option to not send the index path with the selection message, but rather retrieve it by asking the table view about the selected cells once we've received the message? This would be pretty inconvenient, because then we would have to do our own bookkeeping of which cells are currently selected in order to tell which cell was newly selected in the case of multiple selection.

Similarly, we could envision being notified about a changed selection by simply observing a property with selected index paths on the table view. However, we would run into the same problem as outlined above, where we couldn’t distinguish which cell was recently selected/deselected without doing our own bookkeeping of it.


### Blocks

For a block-based API we're going to look at `-[NSURLSession dataTaskWithURL:completionHandler:]` as an example. What is the communication back from the URL loading system to the caller of it like? First, as caller of this API, we know the sender of the message, but we don't retain it. Furthermore, it's a one way-communication that is a directly coupled to the `dataTaskWithURL:` method call. If we apply all these factors into the flowchart, we directly end up at the block-based communication pattern.

![Decision flow chart for communication patterns in Cocoa](/images/issue-7/block-flow-chart.png)

Are there other options? For sure, Apple's own `NSURLConnection` is the best example. `NSURLConnection` was crafted before Objective-C had blocks, so they needed to take a different route and implemented this communication using the delegation pattern. Once blocks were available, Apple added the method `sendAsynchronousRequest:queue:completionHandler:` to `NSURLConnection` in OS X 10.7 and iOS 5, so that you didn't need the delegate any longer for simple tasks. 

Since `NSURLSession` is a very modern API that was just added in OS X 10.9 and iOS 7, blocks are now the pattern of choice to do this kind of communication (`NSURLSession` still has a delegate, but for other purposes). 


### Target-Action

An obvious use case for the target-action pattern are buttons. Buttons don't have to send any information except that they have been clicked (or tapped). For this purpose, target-action is a very flexible pattern to inform the application of this user interface event. 

![Decision flow chart for communication patterns in Cocoa](/images/issue-7/target-action-flow-chart.png)

If the target is specified, the action message gets sent straight to this object. However, if the target is `nil`, the action message bubbles up the responder chain to look for an object that can process it. In this case, we have a completely decoupled communication mechanism where the sender doesn't have to know the recipient, and the other way around.

The target-action pattern is perfect for user interface events. No other communication pattern can provide the same functionality. Notifications come the closest in terms of total decoupling of sender and recipient, but what makes target-action special is the use of the responder chain. Only one object gets to react to the action, and the action travels a well-defined path through the responder hierarchy until it gets picked up by something.


## Conclusion

The number of patterns available to communicate information between objects can be overwhelming at first. The choice of which pattern to use often feels ambiguous. But once we investigate each pattern more closely, they all have very unique requirements and capabilities.

The decision flowchart is a good start to create clarity in the choice of a particular pattern, but of course it's not the end to all questions. We're happy to hear from you if it matches up with the way you're using these patterns, or if you think there's something missing or misleading. 



---
title:  "Behaviors in iOS Apps"
category: "13"
date: "2014-06-09 09:00:00"
tags: article
author: "<a href=\"https://twitter.com/merowing_\">Krzysztof Zabłocki</a>"
---

As developers, we strive to write clean and well-structured code. There are many patterns we can use to make it happen, and one of the best ones is composition. Composition makes it easier to follow the Single Responsibility Principle and simplify our classes. 

Instead of having a Massive View Controller that serves multiple different roles (like data sources and delegates), you separate those roles into different classes. The view controller can then just be responsible for configuring them and coordinating the work. After all, the less code we write, the less code we need to debug and maintain. 


## So What Exactly is a Behavior?

A behavior is an object responsible for implementing a specific role, e.g. you can have a behavior that implements a parallax animation.

Behaviors in this article will be leveraging Interface Builder to limit the amount of code one has to write, as well as enable more efficient cooperation with non-coders. However, you could use behaviors even if you don't use Interface Builder, and still reap most of the benefits.

Many behaviors won't need any extra code other than that required to set them up, which can be done fully in Interface Builder or in code (same setup method). In many cases, you won't even need to have a property referencing them.


## Why Use Behaviors?

Lots of iOS projects end up with massive view controller classes, because people put 80% of the application logic in there. This is a serious problem, because since view controllers are the least reusable parts of our code, they are hard to test and maintain.

Behaviors are here to help avoid that scenario, so what benefits can they bring?

### Lighter View Controllers

Using behaviors means moving lots of the code from view controllers into separate classes. If you use behaviors, you usually end up with very lightweight view controllers. For example, mine are usually less than 100 lines of code.

### Code Reuse

Because a behavior is responsible for just a single role, it's easy to avoid dependencies between behavior-specific and application-specific logic. This allows you to share the same behaviors across different applications.

### Testability

Behaviors are small classes that work like a black box. This means they are very easy to cover with unit tests. You could test them without even creating real views, and instead by supplying mock objects.

### Ability to Modify Application Logic by Non-Coders

If we decide to leverage behaviors with Interface Builder, we can teach our designer how to modify application logic. The designer can add or remove behaviors and modify parameters, all without knowing anything about Objective-C.

This is a great benefit for the workflow, especially on small teams.


## How Can One Build Flexible Behaviors?

Behaviors are simple objects that don't require much special code, but there are a few concepts that can really help to make them easier to use as well as more powerful.

### Runtime Attributes

Many developers disregard Interface Builder without even learning it, and as such, they often miss how powerful it can really be. 

Runtime attributes are one of the key features of using Interface Builder. They offer you a way to set up custom classes and even set properties on iOS's built-in classes. For example, have you ever had to set a corner radius on your layer? You can do that straight from Interface Builder by simply specifying runtime attributes for it: 

<img src="{{ site.images_path }}/issue-13/cornerRadius.png" width="260">

When creating behaviors in Interface Builder, you are going to rely heavily on runtime attributes to set up the behavior options. As a result, there will typically be more runtime attributes: 

<img src="{{ site.images_path }}/issue-13/runtimeAttributes.png" width="253">


### Behavior Lifetime

If an object is created from Interface Builder, it will be created and then removed immediately, unless another object holds a strong reference to it. However, this is not ideal for behaviors that need to be alive as long as the view controllers they are working on is.

One could create a property on the view controller to keep a strong reference to the behavior, but this is not perfect either, for a few reasons:

- You won't need to interact with many behaviors after creating and configuring them.
- Creating a property just to keep an object alive is messy.
- If you want to remove a specific behavior, you need to go and clean up that unused property.

#### Using Objective-C Runtime to Reverse Lifetime Binding 

Instead of manually setting up a strong reference to the behavior from the view controller, we make the behavior assign itself as an associated object of the view controller as part of the configuration process, if needed.

This means that if at some point we need to remove a specific behavior, we just need to remove the code or Interface Builder object that configures that behavior, and no extra changes should be necessary.

This can be implemented as follows:

    @interface KZBehavior : UIControl
    
    //! object that this controller life will be bound to
    @property(nonatomic, weak) IBOutlet id owner;
    
    @end
    
    
    @implementation KZBehavior
    
    - (void)setOwner:(id)owner
    {
        if (_owner != owner) {
            [self releaseLifetimeFromObject:_owner];
            _owner = owner;
            [self bindLifetimeToObject:_owner];
        }
    }
    
    - (void)bindLifetimeToObject:(id)object
    {
        objc_setAssociatedObject(object, (__bridge void *)self, self, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    - (void)releaseLifetimeFromObject:(id)object
    {
        objc_setAssociatedObject(object, (__bridge void *)self, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    @end

Here we leverage associated objects to create a strong reference to a specific owner object.

### Behavior Events 

It's very useful to have behaviors be able to post events, e.g. when an animation finishes. One can enable that in Interface Builder by making behaviors inherit from `UIControl`. Then a specific behavior can just call:

    [self sendActionsForControlEvents:UIControlEventValueChanged];

This will allow you to connect events from behaviors to your view controller code.


## Examples of Basic Behaviors

So what kind of things are easiest to implement as behaviors?

Here's how easy it is to add a parallax animation to a `UIViewController` class (no custom class):

<video style="display:block;max-width:100%;height:auto;border:0;" controls="1">
  <source src="{{ site.images_path }}/issue-13/parallaxAnimationBehaviour.mov"></source>
</video>

Ever needed to pick an image from your user library or camera?

<video style="display:block;max-width:100%;height:auto;border:0;" controls="1">
  <source src="{{ site.images_path }}/issue-13/imagePickerBehaviour.mp4"></source>
</video>


## More Advanced

The above behaviors were straightforward, but have you ever wondered what to do when we need to have more advanced features? Behaviors are as powerful as you make them, so let's look at some more complex examples.

If your behavior needs a delegate of some kind, like `UIScrollViewDelegate`, you will soon run into a situation where you can't have more than one behavior like that on a specific screen. But we can deal with that by implementing a simple multiplexer proxy object:

    @interface MultiplexerProxyBehavior : KZBehavior
    
    //! targets to propagate messages to
    @property(nonatomic, strong) IBOutletCollection(id) NSArray *targets;
    
    @end
    
    
    @implementation MultiplexerProxyBehavior
    
    - (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
    {
        NSMethodSignature *sig = [super methodSignatureForSelector:sel];
        if (!sig) {
            for (id obj in self.targets) {
                if ((sig = [obj methodSignatureForSelector:sel])) {
                    break;
                }
            }
        }
        return sig;
    }
    
    - (BOOL)respondsToSelector:(SEL)aSelector
    {
        BOOL base = [super respondsToSelector:aSelector];
        if (base) {
            return base;
        }
        
        return [self.targets.firstObject respondsToSelector:aSelector];
    }
    
    
    - (void)forwardInvocation:(NSInvocation *)anInvocation
    {
        for (id obj in self.targets) {
            if ([obj respondsToSelector:anInvocation.selector]) {
                [anInvocation invokeWithTarget:obj];
            }
        }
    }
    
    @end

By creating an instance of that multiplexer behavior, you can assign it as a delegate of a scroll view (or any other object that has a delegate) so that the delegate calls are forwarded to all of them.


## Conclusion

Behaviors are an interesting concept that can simplify your code base and allow you to reuse lots of code across different apps. They will also allow you to work more effectively with non-coders on your team by allowing them to tweak and modify the application behavior. 

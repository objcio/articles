---
layout: post
title:  "Behaviours in iOS apps"
category: "12"
date: "2014-05-28 06:00:00"
tags: article
author: "<a href=\"https://twitter.com/chriseidhof\">Krzysztof Zabłocki</a> and <a href=\"https://twitter.com/merowing_\">Krzysztof Zabłocki</a>"
---

As developers we strive to write clean and well structured code. There are many patterns one can use to make it happen, one of the best ones is composition. 
Composition makes it easier to follow Single Responsibility Principle and simplify our classes. 

Instead of having Massive View Controller that has N different roles like UITableViewDataSource, Delegate and who knows what else, you separate those roles into different classes. 

View controller can then just be responsible for configuring them and coordinating the work. After all, the less code we write, the less code we need to debug and maintain. 

Behaviours are concept that is built on composition but tries to achieve even more benefits.

# So what exactly is behaviour?
Behaviour is an object responsible for implementing a specific role/behaviour eg. you can have a behaviour that implements parallax animation.

Behaviours in this article will be leveraging Interface Builder to limit the amount of code one can write and work more efficently with non-coders. 

You could use Behaviours even if you don't use InterfaceBuilder, and still reap most of the benefits.

Many behaviours won't need any extra code other than setting them up, which can be done fully in interface builder or in code (some setup method). In many cases you won't even need to have property referencing to them.

## Why use behaviours?

Lots of iOS projects end up with what we now call Massive View Controller pattern, it's an anti-pattern of MVC, one when people end up putting 80% of application logic in ViewControllers. 

This is a serious problem since View Controllers are the least reusable parts of our code, they are hard to test and maintain.

Behaviours are here to help avoid that dark scenario, so what benefits can they bring?

### Lighter view controllers
Using behaviours means moving lots of the code from view controllers into separate classes. If you use behaviours you usually end-up with very lightweight view controllers, mine are usually less than 100 lines of code.

### Code reuse
Because a behaviour is responsible for just a single role, it's easy to avoid dependency between behaviour and application specific logic.

This allows you to share same behaviours across different applications.

### Testability
Behaviours are small classes that work like a black-box, that means they are very easy to cover with unit tests. You could test them without even creating real views, just supplying mock objects.

### Ability to modify application logic by non-coders
If we decide to leverage Behaviours with interface builder we can teach our designer how to modify application logic. They can add / remove behaviours and modifying params, all without even knowing anything about Objective-C.

This is great improvement to workflow, especially on small teams.

# How one can build flexible Behaviour's?
Behaviours are simple objects that don't require much of special code, but there are a few concepts that can really help make them easier to use and more powerful.

### Runtime attributes
Many developers disregard Interface Builder without even learning it, they often miss how powerful it can really be. 

Runtime attributes are one of the key features of using interface builder, they offer you a way to setup custom classes and even set properties on iOS built-in classes:
eg. did you ever had to add corner radius masking to your layer?
you can do that straight from IB by just specifying runtime attribute for it: ![](Image)

When creating behaviours in IB you are going to relay heavily on runtime attributes to setup their options.

### Behaviour lifetime
If an object is created from interface builder, it will be created and then removed immediately unless someone keeps a strong reference to it.

This is not ideal for behaviours that need to be alive as long as the view controllers they are working on is.

One could create a property on the view controller to keep the strong reference to the behaviour, but this is not perfect:
- many behaviours you won't need to interact with after creating and configuring them.
- creating a property just to keep object alive is messy.
- it also means that if you want to remove a specific behaviour you need to go and clean-up that unused property.

#### We can simplify this by using Objective-C runtime to reverse lifetime binding. 
Instead of View Controller holding reference to behaviour, we make behaviour assign it's lifetime to a view controller (if needed) as part of configuration process.

This means that if at some point we need to remove a specific behaviour, we just need to remove the code / IB object that configures that behaviour, no extra changes should be necessary.

This can be implemented as follows:
````
@interface KZBehaviour : UIControl
//! object that this controller life will be bound to
@property(nonatomic, weak) IBOutlet id owner;
@end

@implementation KZBehaviour
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
````

Here we leverage associated objects to create strong reference to a specific owner object.

### Behaviour events 
It's very useful to have behaviours be able to post events, eg. when animation finishes or when specific behaviour has been achieved.

One can enable that in interface builder by inheriting behaviour from UIControl, then a specific behaviour can just call:
````
[self sendActionsForControlEvents:UIControlEventValueChanged];
````

This will allow you to connect events from behaviours to your view controller code.

# Examples of basic Behaviours
So what kind of things are easiest to implement as Behaviours?

Here's how easy it is to add Parallax animation to a UIViewController class(no custom class):
![](Video)

Ever needed to pick an image from user library or camera?
![](Video)
- Image picking.

# More advanced
Above behaviours were straightforward, but what to do when we need to have more advanced features? Behaviours are as powerful as you make them, let's look at some more complex example:

If your behaviour need a delegate of some kind like UIScrollViewDelegate you will soon run to situation when you can't have more than one behaviour like that on a specific screen. But we can deal with that by implementing a simple multiplexer proxy object:

````
@interface MultiplexerProxyBehaviour : KZBehaviour
//! targets to propagate messages to
@property(nonatomic, strong) IBOutletCollection(id) NSArray *targets;
@end

@implementation MultiplexerProxyBehaviour
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
````
By creating an instance of that multiplexer behaviour, you can assign it as delegate of UIScrollView (or other) and then just forward the delegate calls to all of them.

# Conclusion
Behaviours are interesting concept that can simplify your code bases and allow you to re-use lots of code across different apps. They will also allow you to work more effectively with non-coders in your team by allowing them to tweak / modify the application behaviour. 

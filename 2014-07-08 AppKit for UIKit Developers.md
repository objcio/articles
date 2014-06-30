---
layout: post
title:  "AppKit for UIKit Developers"
category: "14"
date: "2014-07-08 06:00:00"
tags: article
author: "<a href=\"https://twitter.com/chriseidhof\">Chris Eidhof</a> and <a href=\"https://twitter.com/floriankugler\">Florian Kugler</a>"
---

The Mac is not only a great platform to develop on, it's also a great platform to develop *for*. Last year we started building our first [Mac app](http://decksetapp.com) and it was a great experience to finally build something for the platform we're working on all day. However, we also had some tough times finding out about the peculiarities of the Mac compared to developing for iOS. In this article we'll summarise what we've learned from this transition to hopefully give you a head start for your first Mac app.

In this article we will already assume OS X Yosemite to be the default platform we're talking about, as Apple made some significant strides this year to harmonise the platforms from a developers perspective. However, we'll also point out what only applies to Yosemite, and how the situation was prior to this release.


## What's Similar

Although iOS and OS X are separate operating systems, they share a lot of commonalities as well, starting with the development environment -- same language, same IDE. So you'll feel right at home. 

More importantly though, OS X also shares a lot of the frameworks that you're already familiar with from iOS, like Foundation, Core Data and Core Animation. This year Apple harmonised the platforms further and brought frameworks like Multipeer Connectivity to the Mac that were iOS only previously. Also on a lower level you'll immediately see the APIs you're familiar with: Core Graphics, Core Text, libdispatch and many more.

The UI framework is where things really start to diverge -- UIKit feels like a slimmed down and modernized version of AppKit that has been around and evolving since the NeXT days. With the introduction of the iPhone Apple got the chance to start fresh with UIKit, whereas AppKit still has to bear the weight of its origins. AppKit gets modernized step by step every year, but it never had the clean cut as UIKit did.

That being said, UIKit and AppKit still share a lot of concepts. The UI is constructed out of windows and views with messages being sent over the responder chain just as on iOS (although you'll usually never have more than one window on iOS). What's `UIWindow` to iOS, is `NSWindow` on the Mac. `UIView` is `NSView`, `UIControl` is `NSControl`, `UIImage` is `NSImage`, `UIViewController` is `NSViewController`, `UITextView` is `NSTextView`. The list goes on and on.

It's tempting to assume that you can use these classes in the same way, just replace `UI` by `NS`. But that's not going to work in many cases. The similarity is more on the conceptual than on the implementation level. You'll pretty much know about the building blocks to look for to construct your user interface, which is a great help. But the devil is in the details -- you really need to look into the documentation and find out how these classes work.

In the next section we'll take a look at some of these pitfalls we got hung up with ourselves the most.


## What's Different

### Windows and Window Controllers

While you almost never interact with windows on iOS (since they take up the whole screen anyway), windows are key component on the Mac. Therefore AppKit has a `NSWindowController` class that traditionally took on much of the tasks that you would handle in a view controller on iOS. In fact, on the Mac only the window controller was hooked into the responder chain by default, view controllers were not receiving actions by default and missed a lot of the lifecycle methods, view controller containment and other features you're used from UIKit.

This changes in a pretty big way on Yosemite though. `NSViewController` is now much more similar to `UIViewController` and is also part of the responder chain by default. Just remember that if you target your Mac app to OS X 10.9 or earlier, window controllers on the mac are much more akin to what you're used to as view controllers from iOS. As [Mike Ash writes](https://www.mikeash.com/pyblog/friday-qa-2013-04-05-windows-and-window-controllers.html), a good pattern to instantiate windows on the Mac is to have one nib file and one window controller per window type.


### Responder Chain

Prior to OS X 10.10 the responder chain on the Mac was significantly different from iOS as view controllers were not part of it by default. In fact, `NSViewController` was just introduced in 2007 (in OS X 10.5), but it didn't take on the same role as it did on iOS. Events would bubble up through the view tree and then go straight to the window and the window controller. If you would want a view controller to handle events, you'd have to add it to the responder chain [manually)(http://www.cocoawithlove.com/2008/07/better-integration-for-nsviewcontroller.html).

With Yosemite this changes: view controllers are now first class citizens in the responder chain and therefore the model feels much more familiar for iOS developers. 

Other than the path events and actions travel, AppKit also has a more strict convention as to the method signature of actions. In AppKit an action method always looks like this:

    - (void)performAction:(id)sender;
    
The variants that are permissible on iOS with no argument at all or a sender and an event argument don't work on OS X. Furthermore, in AppKit controls usually hold a reference to one target and and action pair, whereas you can associate multiple target action pairs with a control on iOS using the `addTarget:action:forControlEvents:` method.


### Views 

The view system works very differently on the Mac for historic reasons. On iOS views were backed by Core Animation layers by default from the beginning. But AppKit predates Core Animation and the availability of powerful GPUs considerably. Therefore the view system evolved under very different premises.

By default AppKit views are not backed by Core Animation layers. Layer backing support has been integrated into AppKit retroactively, but while you never have to worry about this with UIKit, with AppKit there are decisions to make. AppKit differentiates between layer backed and layer hosting views, and layer backing can be turned on and off on a per view basis. 


#### Layer backed views

You turn an AppKit view into a layer backed view by setting its `wantsLayer` property to `YES`. Once you do this, all subviews of this view will implicitly become layer backed too. The most straightforward approach is to simply enable layer backing once on the window's content view and never touch the `wantsLayer` property again. This can be done in code or simply in Interface Builder's view effects inspector.

Once you enable layer backing, you should treat the layers as an implementation detail. AppKit owns those layers and you should never touch them directly. For example, on iOS you would simply say

    self.layer.cornerRadius = 10;
    
to enable rounded corners. But in AppKit you shouldn't touch the layer. If you want to interact with the layer in such ways, then you have to go one step further. Overriding `NSView`'s `wantsUpdateLayer` method to return `YES` enables you to change the layer's properties. If you do this though, AppKit will no longer call the view's `drawRect:` method. Instead `updateLayer` will be called during the view update cycle, where you can modify the layer. 

You can use this for example to implement a very simple view with a uniform background color (yes, `NSView` has no `backgroundColor` property):

    @interface ColoredView: NSView
    
    @property (nonatomic) NSColor *backgroundColor;
    
    @end
    
    
    @implementation ColoredView
    
    - (BOOL)wantsUpdateLayer
    {
        return YES;
    }
    
    - (void)updateLayer
    {
        self.layer.backgroundColor = self.backgroundColor.CGColor;
    }
    
    - (void)setBackgroundColor:(NSColor *)backgroundColor
    {
        _backgroundColor = backgroundColor;
        [self setNeedsDisplay:YES];
    }
    
    @end

This example assumes that layer backing is already enabled for the view tree where you'll insert this view. The alternative to this would be to simply override the `drawRect:` method to draw the colored background.

Since OS X 10.9 you can tell AppKit to coalesce the contents of a view tree into one common backing layer by using the `canDrawSubviewsIntoLayer` property. All subviews that are implicitly layer backed (i.e. you didn't explicitly set `wantsLayer = YES` on these sub views) will now get drawn into the same layer. However, as soon as you enable this `drawRect:` will be called on the view and its subviews no matter what `wantsUpdateLayer` returns.

As you see this can become somewhat confusing pretty quickly. Therefore we recommend that you follow the simplest approach of enabling `wantsLayer` once on the window's content view if you don't have very good reasons not to do this.


#### Layer hosting views

`NSView`'s layer story doesn't end here though. There is a whole different option to work with Core animation layers called layer hosting views. In short, with a layer hosting view you can do with the layer and its sublayers whatever you want. The price you pay for this is that you cannot add any subviews to this view anymore. A layer hosting view is a leaf node in the view tree. 

The API to create a layer hosting vs. a layer backed view is non-intuitive in the beginning as well, as the sequence of how you set up things is crucial. To create a layer hosting view you could add the following to the initializer:

    - (instancetype)initWithFrame:(NSRect)frame
    {
        self = [super initWithFrame:frame];
        if (self) {
            self.layer = [[CALayer alloc] init];
            self.wantsLayer = YES;
        }
    }
    
It's important that you set `wantsLayer` *after* you've set your custom layer.


#### Other View Related Gotchas

By default the view's coordinate system origin is located at the lower left, not the upper left as on iOS. This can be confusing at first, but you can also decide to restore the behavior you're used to by overriding `isFlipped` to return `YES`.

As AppKit views don't have a background color property as UIKit views that you can set to `[NSColor clearColor]` in order to let the background shine through, many `NSView` subclasses like `NSTextView` or `NSScrollView` have a `drawsBackground` property that you have to set to `NO` if you want the view to be transparent. 

In order to receive events for the mouse cursor entering or exiting the view or being moved within the view, you need to create a tracking area. There's a special override point in `NSView` called `updateTrackingAreas` to do this. A common pattern looks like this:

    - (void)updateTrackingAreas
    {
        [self removeTrackingArea:self.trackingArea];
        self.trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds 
                                                         options:NSTrackingMouseEnteredAndExited|STrackingActiveInActiveApp 
                                                           owner:self 
                                                        userInfo:nil];
        [self addTrackingArea:self.trackingArea];
    }

AppKit controls have been traditionally backed by `NSCell` subclasses. These cells should not be confused with table view cells or collection view cells in UIKit. AppKit made the distinction between views and cells in order to save resources -- views would delegate all their drawing to a cell object that could be reused for all views of the same type. Apple is deprecating this approach step by step, but you'll still encounter them from time to time. For example if you would want to create a custom button, you would subclass `NSButton` *and* `NSButtonCell`, implement your custom drawing in the cell subclass, and then assign your cell subclass to be used for the custom button by overriding the  `+[NSControl cellClass]` method.

Lastly, if you'll ever wonder how to get to the current Core Graphics context when implementing your own `drawRect:` method, its the `graphicsPort` property on `NSGraphicsContext`.


### Images

Coming from iOS you'll be familiar with `UIImage`, and conveniently there is a corresponding `NSImage` class in AppKit. But you'll quickly notice that these classes are vastly different. `NSImage` is in many ways a more powerful class than `UIImage`, but this comes at the cost of increased complexity.

The most important conceptual difference is that `NSImage` is backed by one or more image representations. AppKit comes with some `NSImageRep` subclasses, like `NSBitmapImageRep`, `NSPDFImageRep`, and `NSEPSImageRep`. For example one `NSImage` object could hold a thumbnail, a full size, and a PDF representation for printing of the same content. When you draw the image, an image representation matching the current graphics context and drawing dimensions will be picked, based on the color space, dimensions, resolution, and depth. 

Furthermore, images on the Mac have the notion of resolution additional to size. An image representation has three properties that play into that: `size`, `pixelsWide`, and `pixelsHigh`. The size property determines the size of the image representation when being rendered, whereas the pixel width and height values specify the raw image size as derived from the image data itself. Together those properties determine the resolution of the image representation. The pixel dimensions can be different from the representation's size, which in turn can be different from the size of the image the representation belongs to. 


### Sandboxing

If you want to sell your Mac app through the Mac App Store it has to be sandboxed. You might wonder why we're mentioning this here, since sandboxing has been the norm on iOS from day one, so you're very much familiar with it. However, we're so used to what apps were able to do on the Mac before sandboxing appeared on the radar, that it's sometimes easy to oversee that a feature you want to implement will get you into conflict with the sandboxing restrictions.

The file system has always been exposed to the user on the Mac, so sandboxed apps are able to get access to files outside of its container if the user signals clear intent to do so. It's the same model that now came to iOS 8. However, whereas this approach enhances the prior possibilities on iOS, it restricts the prior possibilities on the Mac. That makes it easy to oversee or forget.

We're guilty of this ourselves, therefore we hope to be able to prevent you from running into the same trap. When we started development of [Deckset](http://decksetapp.com) -- an app that transforms simple markdown into presentation slides -- we never thought that we might run into sandboxing issues. After all, we only needed read access to the markdown file. 

What we forgot about is that we also needed to display the images that are referenced in the Markdown. And although you type the path to the image in your markdown file, that's not a user intent that counts within the sandboxing system. In the end we "solved" the problem by adding a notification UI in the app that prompts the user to allow us access to the files by explicitly opening the common ancestor folder of all images in the file once.

Take a look at Apple's [sandboxing guides](https://developer.apple.com/app-sandboxing/) early in the development process so that you don't get tripped up later on.


### Text System

With [TextKit](TODO link Max's article) iOS 7 for the first time got an equivalent to what has been around on the Mac since ages as the [Cocoa Text System](https://developer.apple.com/library/mac/documentation/TextFonts/Conceptual/CocoaTextArchitecture/TextSystemArchitecture/ArchitectureOverview.html). But Apple didn't just transfer the system from the Mac to iOS, they also made some more and less subtle changes to it. 

For example, AppKit exposes the `NSTypesetter` and `NSGlyphGenerator` which you can subclass to customize their behavior. On iOS those classes are not exposed, but some of the hooks for customization are available via the `NSLayoutManagerDelegate` protocol. 

Overall it's still pretty similar and you'll be able to do everything on the Mac that you can do on iOS (and more), but for some things you will have to look for the appropriate hooks in different places. 


## What You'll Miss

Although AppKit comes with a `NSCollectionView` class, its capabilities lag far behind its UIKit counterpart. Since `UICollectionView` is such a versatile building block on iOS, depending on your UI concept it's a tough pill to swallow that there is nothing like it in AppKit. 

TODO: what else? there has to be more :)


## What's Unique

There are many things you can only do on the Mac, mostly either due to its different interaction model or to its more liberal security policies. In this issue we have articles covering some of these things in depth: [Cross process communication](TODO), [making an app scriptable](TODO), [scripting other apps in the sandbox](TODO), and creating a [plugin infrastructure](TODO) for your apps.

Of course that's just a small subset of features unique to the Mac, but it gives you a good idea of the aspects that iOS 8 just starts to scratch the surface in terms of extensibility and communication between apps. There's of course much more to explore: Drag & Drop, Printing, Bindings, OpenCL, to name just a few examples.


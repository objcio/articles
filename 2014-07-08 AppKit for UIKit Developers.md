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


### Document based apps


### Responder Chain


### Views 


### Images


### Sandboxing



## What You'll Miss

uicollectionview



## What's Unique

cool stuff only the mac can do + links to other articles
drag&drop
scripting
plugins
xpc

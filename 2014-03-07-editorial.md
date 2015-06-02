---
title:  "Editorial"
category: "10"
date: "2014-03-07 12:00:00"
tags: editorial
---

Welcome to objc.io issue #10!

This issue is all about data synchronization and network communication. It's a world of connected devices out there. We all own multiple devices, and making our data available on all of them has become very important. Yet syncing is inherently difficult to solve well.

Here, we will try to help you get a better grasp of the problems involved. First off, to get you started and help you understand the domain, we have an [overview of the possible approaches and their challenges](/issues/10-syncing-data/data-synchronization/) by [Drew McCormack](https://twitter.com/drewmccormack). After that, we take a closer look at Apple's iCloud syncing solutions. In particular, iCloud Core Data sync has received a lot of attention and criticism, and it was deemed unusable by many developers. [Matthew Bischoff](https://twitter.com/mb) and [Brian Capps](https://twitter.com/bcapps) give us an update of the state of [iCloud Core Data](/issues/10-syncing-data/icloud-core-data/), and [Friedrich Gräter](https://twitter.com/hdrxs) and [Max Seelemann](http://twitter.com/macguru17) take a closer look at [iCloud Documents](/issues/10-syncing-data/icloud-document-store/).

We also have an example of a [custom syncing solution](/issues/10-syncing-data/sync-case-study/) on top of Core Data, which goes into detail of a specific solution, and an article on how to structure a [simple networking application with Core Data](/issues/10-syncing-data/networked-core-data-application/), which helps by pointing out how to get some of the basics right. If you're up for something more low level, this issue also has a thorough fundamentals article on [TCP/IP and HTTP](/issues/10-syncing-data/ip-tcp-http/) -- the technology that most of our network communication relies on.

We've created a new public repository on [GitHub](https://github.com/objcio/articles) that contains all current and past objc.io articles. If you find any mistakes or have suggestions for improvements, please don't hesitate to [file issues](https://github.com/objcio/articles/issues), or even better: submit a [pull request](https://github.com/objcio/articles/pulls)!


All the best from Berlin,

Chris, Daniel, and Florian.

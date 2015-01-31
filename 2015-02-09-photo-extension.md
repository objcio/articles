---
title:  "Photo Extension"
category: "21"
date: "2015-02-09 09:00:00"
tags: article
author: "<a href=\"https://twitter.com/iwantmyrealname\">Sam Davies</a>"
---


iOS 8 introduced extensions to the world - with six extension points available.
These offer unprecedented access to the operating system and the photo editing
extension allows developers to build functionality into the system Photos app.

The user workflow for photo editing extensions is not the most intuitive. From
selecting the photo you want to edit, it takes three taps to launch the
extension, one of which is on a tiny, unintuitive button.

![Image Editing Extension User Workflow](http://f.cl.ly/items/2C1V2t1x04402v1K3Q3m/user_workflow.png)

Nevertheless, image editing extensions offer a fantastic opportunity for
developers to offer a seamless experience to users - creating a consistent
approach to managing photos.

This article will talk briefly about how to create extensions and their
lifecycle before moving on to look at the photo editing workflow in more
details. It will conclude by looking at some common concerns and scenarios
associated with creating photo editing extensions.

The __Filtster__ project, which accompanies this article, demonstrates how you
can set up your own image editing extension. It represents a really simple image
filtering process, using a couple of CoreImage filters. You can get hold of the
complete __Filtster__ project on Github at 
[github.com/sammyd/Filtster](https://github.com/sammyd/Filtster).

## Creating an extension

All types of iOS extension have to be contained by a fully-functional iOS app,
and this includes photo editing extensions. This can mean that you would have to
do a lot of work to get your amazing new custom CoreImage filter in the hands of
some users. It remains to be seen how strict Apple is on this, since most apps
in the App Store with custom image editing extensions existed before the
introduction of iOS 8.

To create a new image editing extension you add a new target to an existing iOS
app project. There is a template target for the image editing extension:

![Image Editing Extension Template](http://f.cl.ly/items/2t433C2Z0q1W17313a1B/Screen%20Shot%202015-01-31%20at%2017.42.36.png)

This template consists of three components:

1. __Storyboard__ Image editing extensions can have an almost completely custom
UI. The system provides just a toolbar across the top, containing __Cancel__ and
__Done__ buttons.
__IMAGE__
Although the storyboard doesn't have size classes enabled by
default, the system will respect them should you choose to activate them. Apple
highly recommends using Auto Layout for building photo editing extensions,
although there is no obvious reason why you couldn't perform manual layout at
the current time. You're flying in the face of danger if you decide to ignore
Apple's advice.
2. __Info.plist__ This specifies the extension type and accepted media types,
and is common to all extension types. The `NSExtension` key contains a
dictionary containing all the extension-related configuration.
__IMAGE__
The  `NSExtensionPointIdentifier` entry informs the system that this is a photo
editing extension with its value of `com.apple.photo-editing`. The only key that
is specific to photo editing is `PHSupportedMediaTypes` and this is related to
what types of media the extension can operate on. By default this is an array
with a single entry of `Image`, but you have the option of adding `Video`.
3. __View Controller__ This adopts the `PHContentEditingController` protocol,
which contains methods that form the lifecycle of an image editing extension.
See the next section for further detail.

Notably missing from this list is the ability to provide the imagery for the
icon that appears in the extension selection menu:

__IMAGE__

This icon is provided by the AppIcon image set in the host app's asset catalog.
The documentation is a little confusing here as it implies that you have to
provide an icon in the extension itself but, although this is possible, the
extension will not honor the selection. This point is somewhat moot as Apple
specifies that the icon associated with an extension should be identical to that
of the container app.

## Extension Lifecycle

- Adjustment data
- Start Editing
- Commit edits
- Save the adjustment data


## Photo Editing Flow

- Handling adjustment data
- Live editing with low resolution
- Apply to high resolution
- Update adjustment data


## Common concerns

- Handling memory restrictions
- Sharing code with the container app
- Developing and debugging
- Profiling


## Conclusion
- Put your code right in the heart of the Photos app
- Still a little fiddly to get to (screen taps)
- Resumable editing
- Great potential


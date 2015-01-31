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

# Creating an extension

- Has to be part of a fully-functioning app
- Xcode template
- Has three components:
-- Storyboard for UI
-- Plist to specify extension type
-- Accepted media types
- Need a VC which adopts 


# Extension Lifecycle

- Adjustment data
- Start Editing
- Commit edits
- Save the adjustment data


# Photo Editing Flow

- Handling adjustment data
- Live editing with low resolution
- Apply to high resolution
- Update adjustment data


# Common concerns

- Handling memory restrictions
- Sharing code with the container app
- Developing and debugging


# Conclusion
- Put your code right in the heart of the Photos app
- Still a little fiddly to get to (screen taps)
- Resumable editing
- Great potential


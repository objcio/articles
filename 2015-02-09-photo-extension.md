---
title:  "Photo Extension"
category: "21"
date: "2015-02-09 09:00:00"
tags: article
author: "<a href=\"https://twitter.com/iwantmyrealname\">Sam Davies</a>"
---


- Extensions give unprecedented access to operating system
- Photo extension is a window into the photos app
- Some pics of the user-flow associated with a custom photo extension

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


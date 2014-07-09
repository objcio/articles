---
layout: post
title:  "Snapshot"
category: "1"
date: "2013-07-11 08:00:00"
author: "<a href=\"https://orta.github.io\">Orta Therox</a>"
tags: article
---

## Overview

* What is the problem
  - Testing view code is tricky 
  - Want to test different view states
  - Want to know if anything has changed the visual aspect of my app without you knowing

* How do we solve the problem
  - Take pictures, duh

* Advantages
  - Can provide a test around tough to test code
  - Provides a good overview of a application's state
  - Wraps up the Code Review: `description of change` - `tests` - `snapshots` - `code`
  - Fits in with current testing tools, e.g. runs inline with other unit tests

* Disadvantages
  - Async tests
    - This is common, but tests can be repeated multiple times
   
  - OS changes
    - Font Rendering
    - Supporting older builds
  
  - Repo gets full of images
  
* How do we make that even easier to use
  - Expanding on testing DSLs
  - Xcode plugins
  - Using Kaleidoscope
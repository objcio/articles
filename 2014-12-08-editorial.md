---
title:  "Editorial"
category: "19"
date: "2014-12-08 12:00:00"
tags: editorial
---


Welcome to objc.io issue 19: all about debugging.

We're all making mistakes, all the time. As such, debugging is a core part of what we do every day, and we've all developed debugging habits — our own way of approaching the all-too-common situation where something is not working as it should.

But there's always more to learn about debugging. Do you use LLDB to its full potential? Have you disassembled framework code to glance under the covers? Have you ever used the DTrace framework? Do you know about Apple's new activity tracing APIs? We're going to take a look at these topics and more in this issue.

Peter starts off with a [debugging case study](/issues/19-debugging/debugging-case-study/): he walks us through the workflow and the tools he used to track down a regression bug in UIKit, from first report to filed radar. Next, Ari shows us the [power of LLDB](/issues/19-debugging/lldb-debugging/), and how you can leverage it to make debugging less cumbersome. Chris writes about his [debugging checklist](/issues/19-debugging/debugging-checklist/), a list of the many things to consider when diagnosing bugs. Last but not least, Daniel and Florian talk about two powerful but relatively unknown debugging technologies: [DTrace](/issues/19-debugging/dtrace/) and [Activity Tracing](/issues/19-debugging/activity-tracing/).

We'd love for you to never need all of this — but since that's not going to happen, we at least hope you'll enjoy these articles! :-)

Best from a wintry Berlin,

Chris, Daniel, and Florian.

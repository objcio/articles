---
title:  "Inside Omni"
category: "22"
date: "2015-03-10 12:00:00"
tags: article
author: "<a href=\"https://twitter.com/brentsimmons\">Brent Simmons</a>"
---

The Omni Group is an employee-owned company where people bring their dogs to work.

In other words: when you think about managing large projects, think about culture *first*. It almost doesn’t matter what the details are — how we’re organized, what we use for source control management, and so on — because a great culture makes for a happy team that will figure out how to work together. And Omni has done a *great* job with that.

Omni’s culture deserves an article of its own, but I’m not going to get into culture much. Instead, this is an engineering-centric tour of the details of how we manage our apps.

## Flat Organization

All engineers report to Tim Wood, CTO and founder. Each product has a project manager.

Teams for the various apps are fluid. They don’t change often or willy-nilly, but they do change.

## In-House Communication

People talk face-to-face, since everybody works at the office. There are meetings from time to time, some regularly scheduled, some not. Everybody attends the weekly all-hands meeting, which lasts for around 20 minutes, where section heads and project managers report on how things are going. It’s followed by the weekly engineering meeting, which also lasts around 20 minutes. Most of the engineering reporting is about things of general interest (as opposed to catching up on what each person is doing, though there’s some of that too).

Face-to-face communication is helped by Omni’s core hours: people are expected to be in the office 11 a.m. to 4 p.m. every day, so you know that you can find people during that period. (Otherwise, you can come in and leave as early or late as you want, as long as you put in a full week of work.)

Then there’s email, including several mailing lists, and our internal chatroom-plus-direct-messages thing. (We recently replaced Messages and Jabber with a system that actually remembers history. And allows animated GIFs.)

## Bugs

Every engineering organization larger than zero people revolves around its bug tracker. Omni uses a housemade Mac app named OmniBugZapper (OBZ) that has the features you’d expect. It’s not polished the same way the public apps are, but it is nevertheless an effective tool.

A typical workflow goes like this: you look at the bugs in your current milestone, pick one with a high priority, and then open it so that people can see you’re working on it.

Once it’s finished, you add a note to the bug saying what you did to fix it, and perhaps add a note on how to test it, and you include the SCM revision number.

You switch the status to Verify — and then a tester takes over and makes sure the bug really is fixed. It could get reopened if it’s not actually fixed. If the fix creates a new bug, then a new bug is added to OBZ.

Once a bug in Verify status passes testing, it gets marked as Fixed.

(Worth noting: the relationship between engineers and testers is not adversarial, as I’ve heard it is in some companies. There are moments when you may think the testers want to kill you with work — but that’s normal and as it should be. It means they’re doing a great job. We all have the exact same goal, which is to ship great apps.)

There are some bug fixes that require an engineer to verify, but these are relatively rare; most bugs are verified by testing. (The engineer who verifies a bug can’t be the same engineer who fixed it.)

Some bugs are never intended to be fixed or verified. There are discussion bugs, where we talk about a change or addition, and there are reference bugs, which document behavior and appearance of a feature.

## Milestones

OmniBugZapper has the concept of milestones, of course, and it has a Milestones Monitor window where you can see progress and status of current milestones.

Each milestone has triage, planned, and verify categories. Bugs are triaged and become planned, or put off till later.

The process of deciding which bugs and features go into which milestone and into which release is collaborative, and everybody who wants to participate does participate. That said, project managers make many (if not most) of the decisions. For the bigger issues, there is often more discussion, and we often reach consensus — but we don’t make design decisions by voting, and CEO Ken Case has the ultimate authority. Ken creates the roadmap.

## SCM

We use Subversion. All the apps and the website are in one giant repository. I wouldn’t be surprised if everybody’s working copy is just a partial version, rather than the entire thing.

You might think Subversion is unfrozen caveman engineer stuff, and it wouldn’t surprise you to learn that people have thought about switching. But Subversion gets the job done, and there’s something to be said for the simplicity of managing one big repository for everything.

We have a number of scripts that help with this. For instance, when I want to get the latest changes to OmniFocus, I type <code>./Update OmniFocus</code> and it updates my working copy (I usually do this once a day, first thing). I don’t have OmniGraffle in my working copy, since I haven’t had a need to look at it. But I could get it by typing <code>./Update OmniGraffle</code>.

Subversion may not make branching as easy as Git and Mercurial do, but it’s not like it’s crazily difficult, either. We make a branch when an app gets close to release, in order to protect it from other changes. People make private branches and directories whenever they want to for whatever reason.

Commit messages are sent via email to engineers and everybody else who wants them.

## Crashes

Since apps sit at the top of a mountain of system frameworks that have their own bugs, and since apps run not on an ideal machine but on actual people’s computers, there’s no way to guarantee that an app will never crash.

But it’s our job to make sure that *our* code doesn’t crash — and that if we note a crashing bug in system frameworks, we find a way to work around it.

We have stats and graphs that show us how long an app goes, on average, before crashing. There’s another homemade app called OmniCrashSorter, where we can look at symbolicated crash logs, including exception backtraces and any notes from the user about what was happening when it crashed.

Here’s the thing about crashes: unfortunately, apps never crash for the people writing the code (this seems to be a natural law of software development). This makes crash logs from users — and steps to reproduce — absolutely critical. So we collect these and make them easy to get to.

And: we crash on exceptions, on purpose. Since our apps autosave, it’s safer to crash rather than try to recover and possibly corrupt data.

## Code

We have a small style guide, on our internal wiki, and I’ve already internalized it so I forget what it says.

Except for this one thing. Methods should start like this:

<code>- (void)someMethod;</code><br />
<code>{</code>

It may not be widely known that that semicolon is allowed in Objective-C. It is.

One of the points of this style is that it makes it easy to copy a prototype to the header file or class extension. Another is that you can select the entire line, cmd-E, and then do a find to look it up in the header file (or .m file if you’re going the other direction).

I don’t love this. To me — a compulsive simplifier — the semicolon is an extra thing, and all extra things must be carved away. (How satisfying to imagine my X-ACTO blade slowly drawing a line around the ; and then, with a northeast flick, throwing it in the air, off the side of the desk, where it then flutters into the recycling bin.)

But this is just me idly complaining. The point — which I’m on board with, completely — is that we *have* a style guide, and everybody uses it, and we can read each other’s code without being tempted to argue the fine points of semicolon placement. We don’t get tempted to waste time reformatting existing code just to match our tastes.


### Shared Frameworks

All of Omni’s apps are one big app, in a way; there are lots of shared frameworks they depend on. A bunch of them are open source, and you can [read about them](http://www.omnigroup.com/developer/) and [get the code from GitHub](https://github.com/omnigroup/OmniGroup). There are additional internal frameworks — some used by every app, some used by just some apps.

Shared frameworks make it easier to develop a bunch of different apps, and they make it easier to switch teams, since so much will be the same.

There’s a downside, of course, which is that a change to a framework could break a bunch of apps all at once. But the only way to deal with that is to deal with it. Bugs are bugs.

(Since we do a branch when an app gets close to release, we have protection against framework changes during those last few weeks of development.)

### ARC

New code is usually ARC code. There is plenty of older code that hasn’t been converted — and that’s mostly fine, because making changes to working, debugged code is something you do only when you need to. But sometimes it’s worth doing the conversion. (I’ve done some and will do more. I think it’s easier to write crash-free code using ARC.)

### Swift

Though a bunch of engineers have written Swift code, Swift has yet to appear in any apps or frameworks.

This could change tomorrow, or it might take a year. Or two. Or it might have changed by the time you’re reading this.

### Tests

OmniFocus has unit tests that cover the model classes; other apps have more or less similar test coverage. The problem we face is the same problem other OS X and iOS developers face, which is that so much of each app is UI, and doing automated UI testing is difficult. Our solution for our Mac apps is AppleScript-based tests. (That’s one of the best reasons for making sure an app supports AppleScript, and writing tests is a good way to make sure that the support makes sense and works.)

Tests will never be quite as important to Cocoa developers as to Ruby, JavaScript, and Python developers, since the compiler and static analyzer catch so many things that the compilers for scripting languages don’t catch.

But they’re important nevertheless.

### Assertions

You can see a bunch of the assertions we use — OBASSERT_NOT_REACHED, OBPRECONDITION, OBASSERT, and friends — [in our repository](https://github.com/omnigroup/OmniGroup/blob/master/Frameworks/OmniBase/assertions.h).

We use these to document assumptions and intentions. They’re for later versions of ourselves and for other engineers, and we use them liberally.

The downside to so many assertions is that you get failures, and you have to figure out why. Why is the code not working as expected? Is the assertion just wrong, or does it need to be extended or modified?

There are moments when I look at a bunch of console spew and wonder if it’s a good idea. It is.

## Builds

### Xcode Organization

Each app has a workspace file that includes OS X and iOS projects and embeds the various frameworks that it uses.

### Config Files

We use .xcconfig files pretty heavily. You can see a bunch of them [in our repository](https://github.com/omnigroup/OmniGroup/tree/master/Configurations).

This is one of those things I haven’t used in the past, and haven’t had to even look at in my several months at Omni. They just work.

### Debug Builds

With OmniFocus, debug builds use a separate database and set of preferences, so developers don’t have to subject their real data to the contortions they put debug data through.

(Our other apps are document-based apps, so the exact same issue doesn’t apply, but some apps aside from OmniFocus also use separate app IDs for the debug builds.)

### Static Analyzer

Analysis is set to deep, even for debug builds. This is as it should be.

### Automated Builds

We have a build server, of course, and we’re alerted when builds break. There’s another in-house Mac app, OmniAutoBuild, where we can see the status of the various builds and see where they broke when they break.

Building full, releasable applications is done with scripts. And we can set flags so that builds go to the staging server, so external beta testers can download the latest test versions.

iOS betas go out through TestFlight.

## No Magic

I wish I could say there are some secret incantations — I could just tell you what they are.

But, instead, managing large projects at Omni is like you think it is. Communication, defined broadly — talking in person, chatting, using OmniBugZapper, using assertions, doing code reviews, following coding guidelines — is the big thing.

The next thing is automation: make computers do the things computers do best.

But, again, the zeroth thing — the thing that comes before choosing a bug tracker or SCM system or anything — is company culture. Build one based on trust and respect, with great people, and they’ll want to work together on large projects, and they’ll make good decisions, and they’ll learn from the bad ones.

The good news is that it’s all just work.

And lunches. Work *and* lunches. We all eat together. It makes a difference.

P.S. Many thanks to the folks at Omni who read drafts of this article and provided feedback: [Rachael Worthington](https://twitter.com/nothe), [Curt Clifton](https://twitter.com/curtclifton), [Jim Correia](https://twitter.com/jimcorreia), [Tim Ekl](https://twitter.com/timothyekl), [Tim Wood](https://twitter.com/tjw), and [Ken Case](https://twitter.com/kcase). Anything weird or wrong is my fault, not theirs.

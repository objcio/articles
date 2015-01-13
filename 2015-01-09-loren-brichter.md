---
title:  "Something Slightly Less Terrible"
category: "20"
date: "2015-01-13 10:00:00"
tags: article
author: "<a href=\"https://twitter.com/lorenb\">Loren Brichter</a>"
---

**Loren, thanks for taking the time to talk to us — especially during the holidays. What are you up to these days?**

I've been pretty busy over the holidays, mostly with family stuff. I'm finally getting back into real work now.

**What are you currently working on?**

I can't share any specifics yet, but I've been working on some low-level experiments for a while that are starting to come together. It's been nice to take a step back and to reflect on what I'm actually doing for a bit without the pressure to ship something.

**Before you went down the road of programming, did you have other strong interests you could have imagined making a career of?**

I definitely could have been an architect or mechanical engineer, or maybe a carpenter or photographer. I've been spending a lot more time away from glowing rectangles lately, which has been hard, because it's so easy for them to take over my field of view.

**From carpenter to photographer — that's quite a range! With many options, what keeps you in programming?**

Pure inertia. I'm decent at it, and I hope I can figure out a way to do some good with these skills.

**What are the most non-obvious career choices you've made?**

I think the obvious ones to me were the ones that weren't so obvious to other people, like repeatedly quitting really stable, well-paying jobs to try something crazy. I'm lucky that some of the things I've made worked out well. It probably wouldn't work out the same way if I did it today.

**Aside from the inertia that keeps you in programming, what about it is appealing to you?**

Honestly, it appeals to me less and less. Maybe it's the Graybeard engineer in me, but the more I learn, the more terrible I think programming is. I'd love to rip everything up and start over. But you can only swim against the tide so far, so it's sometimes satisfying to sift through the garbage and repurpose terrible technologies to make something that is slightly less terrible.

**With the appeal of programming in decline, could you see yourself doing something completely different in the future?**

I'll always do something that involves programming, but it'll probably be something where software is a piece of it, rather than the whole thing.

**So since you're not going to jump ship any time soon, let's talk about the terrible parts of programming...**

It's not like a boat with a couple of holes that we can patch; it's more like trying to sail across an ocean on a pile of accrued garbage. Sure, some of the stuff floats, and it keeps some other stuff from sinking. A better question might be: which parts are good? And you can only answer that if you look at a thing in isolation. Like, I could say that Rust is good. But even that enshrines the Von Neumann philosophy, and so you can crawl your way down the stack questioning everything, which isn't practical.

**Which way do you think this is going to go? Will it get better?**

I do think things will get better eventually. And then worse again. Then someone else will come along and go, "Oy what a mess!" And they'll make something better. And then the cycle starts again. Anyway, it's easy to complain, which is why I've been working on what I've been working on.

**When you're trying to make things "less terrible," do you have any greater goals in mind that guide your decisions? Why do you do all this?**

Oh yeah, but it's so abstract that people will think I'm nuts. So for a goal, I'll just say "build tools to make us more enlightened." I mean "enlightened" in a Carl Sagan sense, where we are the universe trying to understand itself. And we've long hit the limit of what we can think with our naked brain, so we need to augment it in some way with mind tools. But the tools right now are so complicated that it takes all your mental energy just to try and "hold" them, so you have nothing left to actually do something interesting. Or at least they're too complicated for me. I'm not that smart.

Personally, I'm tired of the trivial app stuff, and the App Store isn't conducive to anything more interesting. I think the next big thing in software will happen outside of it.

**With regard to the next big thing in software, are there any truly interesting developments out there today?**

Totally. Lots of little glimmers of hope: Rust, Swift, TypeScript, asm.js, broad WebGL support — all pretty interesting in a narrow sense.

**What specifically do you like about Swift?**

It's great to have a modern type system (it'll be nicer once it's finished). And I think the custom operators are ridiculously cute and I hope they're copied.

**Do you already use it in your daily work?**

I don't use it for anything real yet; the tools are still brittle. And until it's open-sourced or cloned, I can't really use it for anything that isn't locked to an Apple platform. Hell, I could at least build Objective-C on Linux.

**You said earlier that you've been spending less time in front of the screen lately. I can imagine that becoming a father has been a major part of this.**

Absolutely. I'm going to be crazy strict in terms of limiting screen time, which maybe is ironic given what I've done for a living. I'm not sure when it happened, but my perspective on the mobile revolution shifted. It used to be really exciting just to see someone pull out an iPhone. Now it's like, "Hey kid, stop staring at your phone!" And apps, apps everywhere! Apps for wiping your butt. I've become an old fogey. Get your apps off my lawn!

**I think many of us could benefit from limiting screen time — do you want to take the opportunity to make a public commitment?**

Haha, no way.

**Fair enough. Can you tell us a little bit more about how you work? You work mostly from home, right?**

Yes, every time I try not working from home, I'm miserable. I love working from home.

**How do you structure your day — do you work on a fixed schedule or handle things more flexibly?**

Man, having a kid really threw a wrench into my work schedule. My old cadence was really consistent. I worked without distraction until ridiculously early in the morning, then slept in. Now I have to go to bed at a reasonable time so I'm not a zombie when the little guy gets up in the morning. I feel like I'm starting to figure it out, but yeah, it's harder.

**Do you mostly focus on one project at a time, or are you a multitasker?**

I'd describe my work schedule as cooperatively single-threaded with a heavy context switch cost, so I try to keep time slices on the order of about a week. So I have lots of projects going at once that usually relate to each other in some way, but I only consciously work on one at a time.

I can't consciously multitask at all, but I think my brain works a bit like libdispatch. The subconscious can chew on a lot of stuff in parallel. So when my conscious mind switches back to some other work it put aside earlier, there are usually a couple good ideas waiting for it.

**You're known for building great apps all by yourself, combining many tasks that often would be done by different people. What draws you to this way of working, compared to working in a team?**

We draw lines between disciplines as a way to divvy up work, the same way you split up programs into modules or objects or some other thing. But whenever you split something in two, the pieces inevitably diverge, and it gets harder to piece them back together when you go to build something. I find that after a while, you actually spend more time dealing with "glue" than the actual thing itself, dealing with impedance mismatches or what-not (both at an architectural/engineering level, or at an interpersonal level). So my little cheat is to try and build things in a more holistic way. It's not actually much more work, because you only have to build the parts that actually, you know, *do* something, and there's minimal hacking required to stick them together.

**Clearly though, there are limits to what you can build alone. Some projects will just require more people to get them done...**

Absolutely, but I think the limit is way further out than people realize. Some remarkable stuff throughout history has been accomplished by individuals — part of the trick is standing on the right shoulders. So sure, the space of ideas I am capable of exploring is smaller than if I were working on a big team, but they're both infinitely big, even if one infinity is smaller than the other. And for me personally, that's a worthwhile tradeoff.

**How do you think teams could be organized in order to minimize the friction you're talking about?**

I don't know. I do know that there are parallels to bad coding architecture at organizational and interpersonal levels, and just as an engineer might be capable of building a thing in a holistic way, a great manager might be able to organize a group of people in a holistic way, by deeply understanding each person and the problem they all need to solve together. I don't have those skills, but I don't think it involves any sort of magic template. If I picked up any wisdom over the last few years, it would be to try to know — like *really know* — what you're doing. It's harder, but it's simpler in the long run.

**So when you're working on a project in a holistic way, is there still a separation between prototyping and building the actual product, or do these two things blend together a lot?**

They're completely blended, which usually means I end up doing my prototyping in code rather than in some other tool like Quartz Composer or Form. The obvious next step for any of those tools is to stop calling them prototyping tools and let them just create the final product.

**How much time actually goes into the prototyping/experimentation phase versus building the things that end up in the actual product?**

I guess it's 100 percent prototyping until I find the right thing (or run out of time), scrapping tons of stuff along the way, and then that's it — I just call it the final product. I guess I'll go back and rip out vestiges of failed evolutions and clean it up a bit, but that usually doesn't take long.

**I guess the design and development processes are also very much interleaved for you?**

Completely, since design and prototyping are the same thing and I do that work in the same medium that the final product takes. Once I'm happy with it, I'm done.

**In this process, do you mostly build technology with a specific product idea in mind, or do product ideas flow from technology you're building?**

Recently it's been a weird mix. I have definite product goals in mind (otherwise I'd end up in the weeds), but the stuff I've been actually coding is somewhat abstract. And the more I work on it, the more I see how different products really aren't — or at least shouldn't be — different products at all. It's like hacking apart a grand idea to shove each piece into a vertical silo. The more I think about it, the more I think that "apps" are a bad unit of organization of software.

**You've been around in this game for a while, and you've had great successes. How do you keep learning after all these years?**

By remembering that, at a fundamental level, nobody really knows anything. So in between swings of crippling confusion and daunting awe, my brain is in a nice mushy phase where it's receptive to absorbing stuff. Mostly through books. The ones with the paper.

**What are some of your favorite books — you know, those with paper?**

Some favorites on the shelf next to me: The C Programming Language, Mindstorms, Turtle Geometry, Ender's Game, Schild's Ladder, Advanced Global Illumination, The Theoretical Minimum, Collective Electrodynamics, A New Kind of Science.

**What would your advice be for people who are just starting out in this field?**

Remember that nothing is magic. Even though it seems like you're working at the top of a stack of impenetrable abstractions, they're made by people (who were probably rushed, or drunk, or both). Learn how they work, then figure out how to minimize your dependence on them.

**Looking back on all the things you've built, do you have a "hack" that you're especially proud of?**

Nope. In hindsight, I think everything I've made stinks.

**Well, let's end on a more positive note then: what do you do to get work out of your head?**

Playing with my son. It's the best.


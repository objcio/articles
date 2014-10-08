---
layout: post
title: Why Is Security Still a Thing?
category: "17"
date: "2014-10-10 09:00:00"
author: "<a href=\"http://twitter.com/secboffin\">Graham Lee</a>"
tags: article
---


As this article was being written, systems administrators were rushing to ensure their networks were robust against [CVE 2014-6271](http://web.nvd.nist.gov/view/vuln/detail?vulnId=CVE-2014-6271), also known as "Shellshock." The vulnerability report describes the ability to get the `bash` shell, installed on most Linux and OS X systems (and, though most people are unlikely to use it there, on iOS too) to run functions under the attacker's control. Considering that security has been a design consideration in software systems at least since the [Compatible Time-Sharing System](http://publications.csail.mit.edu/lcs/pubs/pdf/MIT-LCS-TR-016.pdf) of the 1960s, why isn't it a solved problem yet? Why do software systems still have security problems, and why are we app developers told we have to do something about it?

## Our Understanding Has Changed

The big challenge faced by CTSS — which informed architectural decisions in later systems, including the UNIX system from which OS X and iOS are derived — was to allow multiple people to access the same computer without getting in each other's way. The solution was that each user runs his or her own tasks in an environment that looks like a real computer, but in fact is a sandbox carved out of a shared computer.

When one user needs substantial computing resources, the program shouldn't adversely affect those of the other users. This is the model that leads to multiple user accounts, with quotas and resource usages and accounting systems. It works pretty well: in 2006, I was using the same system to give more than 1,000 users access to a shared OS X computer.

Unfortunately, that view of the problem is incomplete. Technical countermeasures to stop one _account_ from using the resources allocated to another _account_ often do not, in fact, stop one _user_ from using resources allocated to another _user_. If one user can gain access to the account of another, or can convince the other user to run his or her programs, then the accounting and permissions system is circumvented. That is the root problem exposed in the Shellshock vulnerability: that one user can get another to run his or her program with the permissions and resources normally available to the victim.

## The Problem Has Changed

In the time since UNIX was designed, computers have become smaller, faster, and better connected. They've also found uses in more and more situations that weren't foreseen when the software that supports those situations was created. Electronic mail as an effectively public, plain-text system was OK when every user of the mail system worked for the same university, and every terminal was owned by that university. Supporting communication between people in different organizations, in different locations, and on different networks is a different problem and requires different solutions.

In one way, iOS is still a multi-user system. Unlike the environment in which UNIX was designed, all of the users have access to the same account that's operated by the phone's owner. Those users are the owner themselves: you, me, all the other app developers whose products are installed on the phone, and Apple.

That's actually a bit of an oversimplification, because many of those apps aren't the sole work of the developers who submitted them to the store. SDKs, remote services like analytics, and open-source components mean that many apps actually contain code from multiple organizations, and must communicate over networks that are potentially being surveilled. The game is no longer to protect different people at the same computer from each other, but to protect one person's different _tasks_ from each other.

This all sounds pretty negative, perhaps like a mild form of paranoia. The reality is that security can be an _enabling_ force, because it reduces the risks of new scenarios and processes to make them accessible to people in a wider range of contexts. Imagine how much more risky mobile banking would be without the availability of cryptography, and how many fewer people (or even banks) would participate.

## …While Some Things Stayed the Same+

The only reason that UNIX is still at all relevant to modern discussions of software security is that we haven't gotten rid of it, which is mainly because we've never tried. The history of computing is full of examples of systems that were shown to suffer from significant security problems, but which are still in use because the industry is collectively bad at cleaning up its own mess. Even on the latest version of iOS, using the latest tools and the latest programming language, we can use functions like those in the C string library that have been known to be broken for decades.

At almost every step in the evolution of software systems, patches over existing, broken technology have been accepted in favor of reinventions designed to address the problems that have been discovered. While we like to claim that we're inventing the future, in fact we spend a lot of time and resources in clinging onto the past. Of course, maybe _replacing_ these systems would reintroduce a lot of the problems that we _have_ already fixed.

## Apple Can't Solve Your Problems

Apple tells us that each version of iOS is more secure than the last, and publishes a white paper [detailing the security features of its systems](https://www.apple.com/privacy/docs/iOS_Security_Guide_Sept_2014.pdf). Apple explains how it's using ever-newer (and hopefully more advanced) cryptographic algorithms and protocols, stronger forms of identification, and more. Why isn't this enough?

The operating system security features can only make provisions that apply to _any_ app; they cannot do everything required to support _your_ app. While Apple can tell you that your app connected to a server that presented _some_ valid identity, it cannot tell you whether it [is an identity _you_ trust](http://www.securemacprogramming.com/SSL_handout.pdf).

Apple can provide file protection to encrypt your data, and unlock it when requested. It cannot tell you _when_ it's appropriate to make that request.

Apple can limit the ways in which apps can communicate, so that data is only exchanged over controlled channels like URL schemes. It cannot decide what _level_ of control is appropriate for your app, nor can it tell what _forms_ of data your app should accept and what forms are inappropriate.

## You Can't Either (Not Entirely, Anyway)

Similar to operating system features, popularity charts of [mobile app vulnerabilities](https://www.owasp.org/index.php/Projects/OWASP_Mobile_Security_Project_-_Top_Ten_Mobile_Risks) tell you what problems are encountered by _many_ apps, but not which are relevant to _your_ app, or _how_ they manifest. They certainly say nothing about vulnerabilities that are specific to the uses to which _your customers_ are putting _your app_: vulnerabilities that emerge from the tasks and processes your customers are completing, and the context and environment in which they are doing so.

Security is a part of your application architecture: a collection of constraints that your proposed solution must respect as it respects response time, scale of the customer base, and compatibility with external systems. This means that you have to design it into your application as you design the app to operate within the other constraints.

A common design technique used in considering application security is [threat modeling](http://msdn.microsoft.com/en-us/magazine/cc163519.aspx): identify the reasons people would want to attack your system, the ways in which they would try to do that with the resources at their disposal, and the vulnerabilities in the system's design that could be exploited to make the attack a success.

Even once you've identified the vulnerabilities, there are multiple ways to deal with them. As a real-world analogy, imagine that you're booking a holiday, but there's a possibility that your employer will need you to be on call that week to deal with emergencies, and ready to show up in the office. You could deal with that by:

 - accepting the risk — book the holiday anyway, but be ready to accept that you might not get to go.
 - preventing the risk — quit your job, so you definitely won't be on call.
 - reacting to the risk — try to deal with it once it arises, rather than avoiding it in advance.
 - transferring the risk — buy insurance for your holiday so you can reschedule or get a refund if you end up being called in.
 - withdraw from the activity — give up on the idea of going on holiday.

All of these possibilities are available in software security, too. You can select one, or combine multiple approaches. The goal is usually not to _obviate_ the risk, but to _mitigate_ it. How much mitigation is acceptable? That depends on how much residual risk you, your business, your customers, and your partners are willing to accept.

Your mitigation technique also depends on your goals: What are you trying to achieve in introducing any security countermeasure? Are you trying to protect your customers' privacy, ensure the continued availability of your service, or comply with applicable legislation? If these goals come into conflict, you will need to choose which is most important. Your decision will probably depend on the specific situation, and may not be something you can design out in advance. Plenty of contingency plans are created so that people know what to do when something bad happens…_again_.

## Conclusion

Despite advances and innovations in software security technology and the security capabilities of systems like iOS, risk analysis and designing security countermeasures are still the responsibility of app developers. The specific tasks to which our apps are put, and the environments and systems in which they're deployed, are the sources of particular threats, which are impossible to address generally in operating systems or frameworks.

With the security and cryptography features of the iOS SDK, Apple has led us to the water. It's up to us to drink.

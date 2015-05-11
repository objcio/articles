---
title:  "Play, Fail, Iterate: Sound Design for Products"
category: "24"
date: "2015-05-13 10:00:00"
tags: article
author: "Aaron"
author: "<a href=\"https://twitter.com/rx_tx\">Aaron Day</a>"
---



# Play, Fail, Iterate: Sound Design for Products

Our world gets noisier every day. This is the case for all modalities, and not just sound. Alerts and cues blink, beep, jingle, and vibrate from an ever-expanding array of sources. If there is a “war” for our attention, the only guarantee is that there will be no winners. Consider over-compressed and dynamically limited music where “everything is as loud as everything else.” This can be an impressive and even enjoyable experience for a limited amount of time. Over a longer period, however, the listener is left fatigued. If we create a product where modalities are unnecessarily stacked, e.g. you are looking at it and it blinks and it beeps and it vibrates, we will get the same effect: overloaded perceptual bandwidth, fatigue, and frustration with the product.

We can do better. Let's reduce the collective load on our perceptual bandwidth. How? By starting with a careful integration of sound with the other aspects of interaction design. Use it where it's needed, and even then, with respect for the idea that a given sound or alert comprising sound and some visual or haptic element might be experienced by someone many thousands of times or more during his or her exposure to our product. 

Sound design is part of the interaction design process, and not something to be tacked on at the end. Experiment early and often, or in this case: play, fail, iterate.

Here are five guidelines and associated concepts that help me design and integrate sound into products — digital, physical, or otherwise. They can be used however you like: as a checklist, manifesto, guideline, etc.  

### Sound design for products and interaction shall:

### 1. Not annoy the person using it.

This should be obvious, but it is truly a wicked problem — what is annoying to one person might be just right for someone else. There are many ways to solve this problem! To start, create sounds that play at appropriate times and volumes and are mindful of people’s needs. Above all else: when in doubt, leave it out. Some of the best sound design is NO sound design. Look for opportunities to create silence and reflection. 

### 2. Help a person do what he or she wants to do or let him or her know that something has happened.

“If I touch the interface and don’t feel or hear anything change, how will I know I have succeeded in doing what I wanted to do?” Sound, of course, fills this gap. That said, we should take care to make interactive sound as relevant, accurate, and non-intrusive as possible. Take the time to test, then tune the synchronization of audio and moving elements. When that isn’t possible, deemphasize the correlation. Unless sound *has* to be there, leave it out.

The graphic below is a mental model that might help in implementing this idea.

The user experience of a given interaction can be seen as the sum of the physical, graphical, and audio interfaces over time. The ratio of the different modalities changes over time according to context and interaction flow (see graphic). There are cases such as targeted interactions, e.g. looking directly at the GUI where the AUI (audio user interface) part of the venn diagram might be very small or nonexistent, whereas for an “eyes-free” interaction such as an incoming phone call, the AUI would be much more important. These rations change over time depending on the use case or cases, and in the end provide the basis for a user’s experience.

![The user experience of an interaction can be seen as the sum of the physical, graphical, and audio interfaces over time](/images/sum-of-interfaces.png)

### 3. Reproduce well on the target.

Many technical problems have non-technical origins. Getting UI sound and related audio to sound good on hardware is no exception. Don’t pick your soundset by listening to it through a nice stereo system or, conversely, through the speakers of a Dell laptop in an echoey conference room. Decisions concerning selection of sounds and their relative merits within a design system should be made on the target hardware, i.e. test it on the device(s) you are developing for. You might say: “But sound coming out of a handheld device (medical device, automobile, etc.) sucks!” That is exactly why the decision about what goes into a build should be made on target hardware. 

Restated: confirm stakeholder buy-in and integrate sound into the beginning of the design process. Communicate the risk(s) of bad, inappropriate, or poorly implemented sound design before all the project’s capacity is spoken for.


### 4. Reflect the product tone of voice in a unique way.

Some things have a face, others a voice, and a limited few have an aura. Does your product have an aura?


### 5. Be future-proof.

To hit a moving target, you have to aim ahead of it. 

Less-than-optimal audio hardware, such as tiny little speakers, underpowered amplifiers, extremely band-limited frequency response, etc. has been the hobgoblin of sound design for many products for a long time — especially mobile devices. There were mobile devices that had good sound hardware before the iPhone, but none that had the same impact. After the iPhone came out, user expectations went up. They are continuing to go up, and this should be reflected in whatever sound design you incorporate into your product. Design for the “late now” and the future. Furthermore, interfaces are getting smaller, to the point of disappearing altogether, e.g. wearables (see graphic). Sound design just got some new pants.


![Size of physical display vs. importance of auditive and tactile display](/images/size-vs-auditive.png)


### Is That All? 

No. There is more, but that is a start. These guidelines are no guarantee for successful integration of sound into products, but they will definitely point the development and design process in the right direction.

### In Conclusion

 * The proper mix of beautiful sound and well-timed silence will make for happier customers.
 * Sound design is part of interaction design — not something added “on top.”
 * Take the time to test and tune. When that isn’t possible, deemphasize the correlation.
 * When in doubt, leave it out.
 * Confirm stakeholder buy-in and integrate sound into the beginning of the design process.
 * Don’t let app store reviews rule your life! You will never make everyone happy all the time, especially with sound. 
 * Play. Fail. Iterate.





----


Aaron Day lives in Berlin, Germany, and has been designing sounds and interactions since 1998. He currently designs sound for Wire and tweets at @rx_tx.

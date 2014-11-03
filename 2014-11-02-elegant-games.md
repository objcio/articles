---
layout: post
title:  "Designing Elegant Mobile Games"
category: "18"
date: "2014-11-02 08:00:00"
tags: article
author: "<a href=\"https://twitter.com/lazerwalker">Mike Lazer-Walker</a>"
---

# Designing Elegant Mobile Games

The idea of "designing mobile games" is a funny one. In theory, there isn't anything about the process of making games for smartphones or tablets that's fundamentally different from any other form of game design. The formal properties of games as systems are the same across any genre or platform, and the process of game design tends to look relatively similar regardless of whether you're trying to create the next Farmville, Call of Duty, or chess.

In practice, though, creatig a successful mobile game can be a very different beast. So many different concerns, from market saturation and lack of discoverability to the use patterns of when and how people play games on their phones, can make it feel like making a good mobile game is like turning on "hard mode" as a designer.

Specifically, the various constraints at play mean that most successful mobile games tend towards elegant rulesets. That is, they strive to be capable of deep, meaningful play, but that meaning needs to arise from a minimal set of simple rules. While there certainly is a place for more ornate and baroque games, that style of game tends to be a poor fit for mobile, no matter whether you're considering "success" from a critical or commercial standpoint.

Let's look at two of the defining characteristics of mobile games, play session length and the controls, and look at a few lenses through which we can help achieve this sort of elegant design.


## Play Session Length

People play mobile games differently than most other kinds of games. Players demand games that are playable in short bursts while they're waiting in line or on the toilet, but they also want the ability to partake in more meaningful, longer-term play sessions. Most studies peg the average iOS game session length at somewhere between one and two minutes, but at the same time the majority of mobile game play time happens inside the home. Striking a balance to make your game fun and rewarding in both situations is a *really* hard probem.

To help us think about designing for both of these contexts, it's useful to think about a game as a collection of feedback loops. At any given moment of a game, you have a mental model of the game's system. Based on that, you're going to perform some action that will result in the game giving you feedback, which will in turn inform your mental model.

The key thing about these feedback loops is that they're fractal in nature; at any given moment, there could be any number of nested feedback loops at play. As an example, let's think about what is happenening when you play a game of [Angry Birds](https://www.angrybirds.com).

![http://www.mobygames.com/images/shots/l/467764-angry-birds-iphone-screenshot-how-to-plays.png]()

Let's start at the level of each individual move you make. Flinging an individual bird across the map gives you the satisfaction of accomplishing something, but also gives you feedback: did you destroy the blocks or pigs you thought you would? Did the arc your bird took (still visible on-screen after the bird has landed) mirror what you thought it would? This information informs your future shots.

Taking a step back, the next most atomic unit of measurement is the 'level'. Each level also acts as its own closed system of feedback and rewards: clearing it gives you anywhere from 1 to 3 stars, encouraging you to develop the skills necessary to truly "beat" it.

In aggregate, all of these levels themselves form a feedback loop and narrative arc, giving you a clear sense of progression over time and giving you a sense of your skill relative to the overall system.

We could keep going, but I think the concept is clear. Again, this isn't a game design concept that is unique to mobile games; if either the moment-to-moment experience of playing your game or the overarching sense of personal progression is lacking, your game likely has room for improvement, no matter the platform.

This becomes particularly interesting when thinking about the problem of play session length, though. It's possible to have a game whose moment-to-moment gameplay is fun, while still having the smallest systemic loops be sufficiently long that trying to pick it up for a minute or two while in line wouldn't be fun. That same minute or two in Angry Birds lets you experience multiple full iterations of some of the game's feedback loops, giving a sense of fun even in such a short playtime. The existence of higher-level feedback loops means that these atomic micro-moments of fun don't come at the expense of ruining the potential for longer-term meaningful play.


## The Controller Conundrum

Most digital games have a larger number of inputs than smartphones or tablets, whether you're talking about console controllers, a PC mouse and keyboard, or even an arcade joystick. Many great mobile games find unique ways to use multitouch or the iPhone's accelerometer rather than throwing lots of virtual buttons on-screen, but that still leaves iOS devices with far less discrete inputs than most other forms of digital games. The result is a difficult design challenge: how can we make interesting, meaningful, and deep game systems when our input is constrained? This is a relatively frequent topic of discussion for game design students — creating a "one-button game" is a classic educational exercise for aspiring desigers — but the restrictions of iOS frequently make it more than an academic concern. Ultimately, it's a similar problem as we faced with gameplay session length: how do you create something that's simple and immediately approachable without giving up the depth and meaningful play that other forms of games exhibit?

One useful way for framing interactions in a game is to reduce the formal elements of the game down to 'nouns' and 'verbs'. Let's take the original Super Mario Brothers as an example. Mario has two main verbs: he can "run" and he can "jump". The challenge in Mario comes from the way the game introduces and arranges nouns to shape these verbs over the course of the game, giving you different obstacles that require you to apply and combine these two verbs in interesting and unique ways.

Of course, Mario would be much more boring if you could only run *or* jump. But even the six buttons required to play Mario (a four-directional d-pad and discrete 'run' and 'jump' buttons) are in many ways too complex an input for an ideal touch-screen game; there's a reason there are very few successful traditional platform games on iOS.

So how can we add depth and complexity to a game while minimizing the types of input? Within this framework of nouns and verbs, there are essentially three ways we can add complexity to a game. We can add a new input, we can add a new verb that uses an existing input, or we cantake an existing verb and add more nouns that color that verb with new meaning. The first option is generally going to add complexity in the way we don't want, but the other two can be very effective when done right. Let's look at some examples of mobile games that use each of these ways to layer in additional depth without muddying the core game interations.


### Hundreds
The game [Hundreds](http://playhundreds.com)[2] is a great example of adding in new 'verbs' without complicating the way you perform the game's verbs.

![http://www.gamasutra.com/db_area/images/igf/Hundreds/screenshot.jpg]()

Initially, the only verb at your disposal is 'touch a bubble to grow it'. As the game progresses, new types of objects are introduced: bubbles that slowly deflate over time, spiky gears that puncture any they touch, ice balls that 'freeze' bubbles in place. It would be easy for this to become overwhelming to the player, but crucially nothing every breaks the input model of "tap an object to do something to it". Even though the number of possible verbs balloons to a pretty large number, they cohere in a way that keeps it simple. The interaction between these elements is very rich — moments such as using the ice balls to freeze the dangerous gears, rendering them harmless, is a particularly great emergent moment — but the fundamental way you interact with the system stays simple.


### Threes
The puzzle game [Threes](http://asherv.com/threes/)[3] exemplifies the other approach, managing to layer in complexity and strategy without making any changes to the things you can do in the game.

![http://asherv.com/threes/images/THREES_trailer.gif](threes)

Throughout the game, its rules remain completely constant. From beginning to end, the only verb in your toolbelt is "swipe to shift blocks over", with no variation at all. Because of the way the rules of the system create new objects at a predictable rate, complexity emerges naturally as a result of progression. When the screen only has a few low-numbered blocks at the beginning of the game, decisions are easy. When you're balancing building up lower-level numbers with managing a cluster of higher numbers, that same one verb suddenly has a lot more meaning and nuance behind it.

Both of these are great examples of games that manage to offer simplicity on the surface but great depth underneath by carefully managing where and how they add complexity and meaning to their verbs. The approach between the two might be different, but both do a fantastic job of shifting some of that complexity away from the lowest levels of the game to make them more approachable.


## Elegance

We've now explored two different lenses we can use to think about designing games. Thinking about your systems in terms of nested feedback loops, and managing the relative lengths of one iteration of each loop, can help you design something that is fun for both ten seconds and an hour at a time. Managing where and how your game adds complexity to its interactions by managing the way you handle your game's verbs can help you consciously push your game's complexity into the realm of more systemic depth than simply presenting a complicated interface for new players.

Ultimately, each of these topics explores similar ground: the idea that gameplay depth and systemic complexity, while related, are not necessarily equivalent, and that being conscious about at what layer of your game the complexity lies can help make your games as accessible as possible to new players and for short pick-up-and-play game sessions without sacrificing depth or long-term engagement.

Again, neither of these concepts are particularly new to the world of game design. In particular, design blogger Dan Cook talks a lot about nested feedback loops in his article [The Chemistry of Game Design](http://www.gamasutra.com/view/feature/129948/the_chemistry_of_game_design.php), and Anna Anthropy and Naomi Clark's book [A Game Design Vocabulary](http://www.amazon.com/Game-Design-Vocabulary-Foundational-Principles/dp/0321886925) has a fantastic exploration of what it means to conceptualize your game in terms of verbs.

But these problem spaces are exacerbated on mobile. The context of mobile gaming makes it vital to keep your lowest-level loops and arcs as short and self-contained as possible, without losing sight of the bigger-picture. The practicalities of touch-screen controls make adding complexity and nuance at the input level difficult, making it that much more important to be able to understand where and how to insert the systems in your game that will provide rewarding higher-level play for experienced players. The unforgiving nature of mobile games means that elegance in design isn't merely ideal, but a necessity; recognizing that "simple" doesn't have to equal "shallow" is one of the most important elements of designing good games on mobile.


[1] The basic concept of Hundreds is simple: each level has a bunch of bubbles bouncing around, each with a number inside it. The larger the number, the bigger the bubble. While you are touching a bubble with your finger, it turns red, grows larger, and its number increases. When you stop touching it, it stops growing and turns black again, but it maintains its new number and size. Once the sum of all on-screen bubbles is at least 100, you've beaten the level. However, if a circle touches another circle while it is red (i.e. being touched), you need to restart.

[2] If you don't know Threes, you might instead be familiar with the more popular clone [2048](http://gabrielecirulli.github.io/2048/). Either way, Threes presents you with a 4x4 game grid with a few numbered squares, where every square's number is either a 1, a 2, or 3 doubled some number of times (3, 6, 12, 24, etc). When you swipe in any direction, every square that is capable of doing so will shift over one space in that direction, with a new square being pushed onto the game board in an empty square from the appropriate side. If two squares of the same number are pushed into each other, they will become one square whose number is the sum of them together (1s and 2s are different; you must combine a 1 and a 2 to get a 3). When you can no longer move, your score is calculated based on the numbers visible on the board, with higher numbers being worth disproportionately more than lower ones.

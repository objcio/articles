---
layout: post
title:  "Virtual Soundscapes: The Art of Sound Design"
category: "2"
date: "2014-11-01 09:00:00"
author: "<a href=\"http://twitter.com/redqueencoder\">Janie Clayton</a>"
tags: article
---

Take a moment to just close your eyes and listen to the world around you. If you are in an office, you probably hear people typing and phones ringing. You might hear the drone of the heater or the air conditioner going on in the background. You hear your coworkers. You hear their footsteps and their conversation about working on a particularly nasty bug.

Sound is all around us. And it is such an integral part of our world that we just absorb and accept all the ambient noises that fill our daily lives. People who have been born hearing impaired and received cochlear implants have been driven insane by all the sounds that we subconsciously absorb and process.

Sound is becoming increasingly important in game development. One of the biggest challenges faced with fully immersive virtual reality is designing a realistic soundscape. If you were in an immersive virtual forest, but didn’t hear the sound of leaves rustling and insects chirping, you wouldn’t feel like it was real. 

In some ways, sound design is a thankless task. If you do everything right, no one will notice, but they sure as heck will notice if you do something wrong. It is painstaking, detail-oriented work that virtually goes unnoticed. However, the joy that you feel when you nail an awesome sound effect or a realistic soundscape totally makes up for the lack of recognition you get for the hard work you put into it. Mostly.

## Recording Sound

Recording sound is very similar to functional programming: you want to eliminate side effects. One massive side effect that can ruin your recording is reverb. Reverb is the effect you hear when sound bounces off of reflective surfaces and creates an echo effect. 

If you want a good idea of what reverb is, walk into a large public bathroom and listen to what that sounds like. Bathrooms have lots of nice sound reflecting surfaces and very little sound absorption. Drop something on the floor and talk really loudly. Listen to how this sounds. This is a very distinctive side effect that, if your game does not take place in a bathroom, would sound incredibly out of place.

Reverb is not something you can “fix in post.” There are no audio filters or plug-ins to eliminate reverb. You can add reverb to a recording, but once you compile and render the recording, you are stuck with it. Trying to take reverb out of a sound file is like trying to remove the eggs from the cake you just pulled out of the oven. It really isn’t going to happen, so you need to make sure that you try to isolate your recording from as much of this as possible before you begin.

You don’t need to go to a professional studio, but if you could, that would be awesome. If you are trying this at home, do what you can to deaden the noise in the room as much as possible. I have seen people cover the walls with blankets. If you want to embrace your inner Martha Stewart, you can repurpose egg cartons by chaining them together and hanging them on the walls. If that seems like too much work, or simply strikes you as bizarre, just be sure to find the smallest room you can.

Also, make sure your microphone is as close to your sound source as possible. You not only want to avoid recording reverb — you also want to avoid recording noise. Anyone who has been on a conference call where the other team is in a room with one recording device in the middle knows that people trying to talk into a microphone that is 10 feet away sound terrible. There is a lot of noise between the microphone and the person, so everything sounds staticky. 

We can’t completely eliminate noise, but fortunately there are tools that can remove noise if you record your sounds properly. When recording a sound, be sure to do some pre-roll and post-roll recording. Pre-roll is recording a couple of seconds of silence before capturing your sound. One product on the market, [Izotope’s RX 4](https://www.izotope.com/en/products/audio-repair/rx/), can analyze the noise and remove it from your recording. This product is not the only audio repair program on the market. RX 4 costs more than Logic, so even though you can remove noise in post, the cheapest solution is to avoid recording it in the first place. Noise is a side effect. Avoid side effects as much as possible.

## Microphones

If you are serious about making the best sound design experience you can for your users, there are a few essential tools that I recommend you invest time and money into.

The first, and only, indispensable tool that you absolutely must buy is a decent microphone. Using your laptop microphone to record sounds for your game is absolutely unacceptable. Your laptop microphone is sufficient for talking to people on Skype, but it was never designed or intended for professional sound quality or work. Your laptop microphone can’t be tuned or modified. It can’t be controlled or targeted in any meaningful way. You need to have more control over your tools than you can get with the microphone built into your computer.

There are several kinds of microphones out on the market, which range from 10 dollars to thousands of dollars. The cheapest and most primitive type of microphone is a dynamic coil microphone. If you were an AV nerd in high school and helped set up the sound for school assemblies, the microphones you worked with were most likely dynamic coil microphones. Dynamic coil microphones are very robust. You can drop them off a building or run them over with a car and they will still work. As such, they tend to not be particularly sensitive and won’t pick up on subtleties and nuances. An external dynamic microphone, even if you steal it from your Rock Band setup, is still a vast improvement over your laptop microphone, but it is the minimum viable product.

Another type of microphone you probably won’t see very often is a ribbon microphone. Ribbon microphones were developed to make up for the weaknesses in dynamic coil microphones. Ribbon microphones are incredibly sensitive, but that increased sensitivity makes them incredibly fragile and expensive. These microphones are great for high-quality vocal recordings, but for our purpose,s they are not ideal.

The type of microphone I recommend you invest in is a condenser microphone. Condenser microphones are the best of both worlds. They are far more sensitive than dynamic coil microphones, but they have comparable sensitivity to ribbon microphones. Condensers are more expensive than dynamic coil microphones, but less expensive than ribbon microphones.

For convenience purposes, I would recommend buying a microphone that can interface directly with the computer via USB. When I was learning audio engineering, you needed to purchase an external mixer and other hardware to get your microphone to interface with the computer. With the advent of podcasting and home audio/video production, many easy and low-cost solutions have appeared on the market. 

A decent USB-connected condenser microphone can be found on Amazon for about 50 bucks. You can pay more for a USB microphone, but I have not really seen any that are more than 150 dollars. Considering that a decent, non-USB condenser microphone was more than 500 dollars five years ago, this really is not that bad. A good microphone is worth every penny you invest in it.

Another thing to keep in mind when picking out a microphone is its polar pattern. Polar patterns are also called pick-up patterns. Not all microphones pick up sounds all around them. The ones that do are called omnidirectional. Omnidirectional microphones are not ideal for our purposes. Even if you are able to isolate your sound source, your microphone will still pick up ambient noise.

A better polar pattern is a cardioid polar pattern. Cardioid patterns are heart shaped and have a dead spot behind them. This pattern really helps you isolate your sound source. There are a few flavors of cardioid: super and hyper. Both of these cardioid patterns pick up a small amount of sound behind them, but both are far better than plain vanilla omnidirectional.

## Digital Audio Workstations (DAW)

If you are serious about sound design, you will need to invest some time and probably some money into a Digital Audio Workstation (DAW). You have a free DAW included on your Mac, GarageBand. GarageBand has improved greatly over the last few years, but it is still a rather limited piece of software. GarageBand is primarily targeted at people who want to make music, rather than people who want to design sound effects for a game. So, you can spend a lot of time trying to force GarageBand to do a job it wasn’t really designed to do, or you can spend a little more money and buy a much better tool.

I highly recommend purchasing [Logic Pro X](https://www.apple.com/logic-pro/). Logic Pro is Apple’s upgrade to GarageBand. Logic Pro costs 200 dollars and, unfortunately, it does not have upgrade pricing. However, Logic’s price has dropped significantly over the last few years. Back in 2007, Logic 7 cost 1,000 dollars and required an external software dongle. Logic 8 cost half that, and the last two versions of Logic Pro have stabilized at around 200 dollars. You could buy the last three versions of Logic for less than the price of Logic 7.

Similarly, if we jump in the Wayback Machine, we can see that buying a DAW used to be incredibly expensive. The industry standard DAW 10 years ago, [Pro Tools](http://www.avid.com/US/products/pro-tools-software), was prohibitively expensive. If you bought Pro Tools, you also had to buy an external piece of hardware for the software to work. The barebones Pro Tools setup was 2,000 dollars minimum. Pro Tools also did not come with any plugins or functionality. All you could do with a barebones system was record and edit sound. There were no filters, no effects, and no virtual instruments. Everything came separately, and the cost of a tricked-out Pro Tools DAW could run you 10,000 dollars easily.

All of these things that you had to buy in addition to a Pro Tools rig come for free in Logic Pro. Logic Pro comes with a large library of royalty-free special effect sounds and music loop components. If you don’t know how to play an instrument but would still like to put together your own sound track, playing around with the built-in Apple Loops is a good way to explore. Garage Band has some Apple Loops, but not nearly as many.

Logic Pro also includes 20 audio effect plugins to modify pitch, remove noise, and add the reverb that you actually want to include in your sound. These tools are invaluable to crafting a unique set of sounds for your games.

Another DAW that I have used and enjoyed working with is [Reason](https://www.propellerheads.se/products/reason/). Reason is available as a free download for trial use, but you can’t save any of your projects if you don’t purchase the software. You can download it and play around with it to see if you like working with it, without having to invest money up front. Additionally, Reason has a lot of third-party instrument and sound libraries available to it, making it incredibly powerful and versatile.

DAWs are kind of like programming languages. Once you master one, it isn't hard to take that knowledge and apply it to other DAWs. In many ways, the one you choose to work with is all a matter of taste and what clicks for you. Each of them have their own unique set of features, but much of the base functionality is the same. The ones I mentioned are ones I learned and enjoyed using that also fit into an indie game developer budget.

These are serious tools that take a bit of time to master, but there are a multitude of resources out in the world in the form of books and online tutorials. If you had the patience to master either a programming language or a gaming engine, you should be able to master these tools with some hard work and practice. Once you have an understanding of how all of these tools work, the only limit to what you can do with them is what you can imagine.

## Foley

Foley is the art of reproducing and recording everyday sounds to add into your game project. One of the more famous examples of foley that all geeks should be familiar with is the use of coconuts to reproduce the sound of a horse’s hooves. 

With the above example, it is clear that you do not have to record the exact sound in order to get an approximation of it for your game, and sometimes it's even the better choice. One great example of a time when you would not want to use the direct sound source is when you have a gun shot. If you have ever heard a real gun shooting, you might have realized that it counterintuitively sounds fake. <Find out what people actually use for a gun shot.>

There are many tutorials available for the budding foley artist, but the best tools you have as a foley artist are your ears and your imagination. I had a sound design project where I had to recreate the sound of several objects rolling across a screen. I remembered when I was a child that I had a marble machine that I would drop marbles into and they would roll down several tracks before landing in a bucket at the bottom with a satisfying plop. I bought some marbles and recorded the sound of them traveling around and dropping. I then went into Logic and I pitch shifted the sound of the marbles so that the sound was lower for larger objects and higher for smaller objects.

Think about what something should sound like, and try to think about whether you have any memories of sounds that could work. Keep your ears open for anything you hear or observe that makes interesting sounds. If you are looking for inspiration, [read a bit about how Ben Burtt designed the sound effects in Star Wars.](http://filmsound.org/starwars/)

## Apple Loops and Other Prebuilt Sounds

Since we are all busy game designers and software engineers, we don’t necessarily have a week to spend futzing around with Logic and carefully handcrafting our own custom sounds. That said, there are resources out there for the busy software engineer who just needs the sound of a dinosaur roaring right away.

I have already briefly mentioned Apple Loops. Apple Loops are royalty-free sound snippets that come with both GarageBand and Logic. They used to be sold separately from Apple, but as of Logic 8, all Apple Loops come with Logic.

These can be used as is without royalty or attribution. Even though there are a few thousand loops to choose from, there will probably only be a few that meet your needs. It is helpful to understand audio filters, so that you can modify these sounds to make them unique, but it will be a little bit like the Taco Bell menu, where you have five ingredients that can only be combined in a finite number of ways. These are a great starting point, but after a while, all of your sounds will be the same, and nothing is going to stand out from anyone else doing the same thing. As such, you will probably want to explore some more specialized sounds.

There are many websites that have both free, open-source sounds and proprietary sounds that you would pay a nominal licensing fee to use. Two for-pay websites with a good selection of sounds are [Big Fish Audio](http://www.bigfishaudio.com) and [Audio Jungle.](http://audiojungle.net) There are many free sound sites online, but they will not have as good a selection, and you will probably spend a lot more time looking for what you want. Convenience has a cost, so figure out how much time you will save and how much that is worth when making the determination about whether you will make, buy, or find your audio.

A word of warning about online sounds: Make sure you understand the rights you have associated with those sounds. Make sure you have a license that permits you to include the sounds in your project and that you pay for such rights if you find a sound you want to use. The people who are creating these sounds worked very hard on them. We want people to pay for our software, so we should be willing to pay for a sound that can really set our game apart from the rest of the pack.

## Audio Filters

I have mentioned audio filters a few times already in this article, so now seems like a good time to begin explaining what they are and how you can use them in your projects.

There are a lot of really cool effects filters out there on the market, but generally speaking, you will be using filters to clear out noise and tune your sound more than you will to create really wonky sound effects. Let’s go over some of the more common audio filters you will be seeing and using most frequently.

I have mentioned trying to eliminate reverb from your audio projects, because it can be added in later in a way that you control. One important set of filters you will be dealing with are reverb filters. You can design a reverb pattern around general and specific types of architectures. Some reverb software was created by taking response patterns from specific places like the Sistine Chapel and Grand Central Station. If you are writing a game that takes place in a real location, it is possible to design your reverb to exactly match the location your game takes place in. You usually don’t need this level of detail, but if you are a massive audio geek, knowing this is possible is a really exciting thing.

Additional audio filters you should familiarize yourself with are high- and low-pass filters. These filters are pretty self-explanatory. A high-pass filter lets higher frequencies go through, and a low-pass filter only lets lower frequencies through.

Humans generally can hear sounds up to around 20,000 Hz. If you ever wondered why the sample rate for CDs was 44.1kHz, it has to do with science. There is a formula called the [Nyquist Theorem](http://en.wikipedia.org/wiki/Nyquist–Shannon_sampling_theorem), which states that if you want to accurately capture a sound, you need to sample at at least twice the highest frequency. Sound is a wave that has both a compression and a rarefaction. If you think back to high school trigonometry when you programmed a sine wave on your graphing calculator, you noticed that the wave traveled above and below the y-axis. If you wanted to measure that wave, you would need to make sure to capture both where the wave goes above the axis and where it goes below it.

As we age, many of us lose the ability to hear sounds at these higher frequencies, especially if we have destroyed our hearing blasting death metal and cranking the volume on our Call of Duty sessions. However, not everyone loses the high end of their hearing. I personally know someone who can hear dog whistles. There are a lot of nasty, off-sounds that most of us can’t hear, but there are people out there who can. It doesn’t hurt to run your sounds through a low-pass filter and filter out anything over 15kHz just to clear out some of the garbage that might bother our supernaturally ultrasonic listeners.

Likewise, filtering out some of the wonky lower frequencies can clean up your sound. Utilizing both a high-pass and a low-pass filter is called a band-pass filter. You are specifying that you only want to use frequencies within a contained band of frequencies.

Speaking of frequencies, I wanted to briefly mention a little bit about pumping the bass. I know that back in the day when we used to listen to our music through stereo systems, the popular thing to do was crank the bass. You might be tempted while creating your sounds to crank the bass in your equalizer, but don’t do that. Here is a pro tip: It is easier to remove frequencies than it is to add them in. If you want to increase the lower frequencies in your sounds, decrease the higher frequencies. Frequencies cancel one another out and by directly removing the frequencies you don’t want to hear, you are increasing the ones that you do want to hear.

Depending on what DAW you are using, you should have access to a bunch of audio effects plugins. There are plugins that speed up and slow down your sounds, either with pitch shift or without. I used to have a plug in that would 'smear' two sounds together. Another Izotope product, [Trash 2](https://www.izotope.com/en/products/effects-instruments/trash/), lets you selectively distort and mangle your sound in a highly controlled way. There are so many awesome effect plugins out on the market that I really can’t go into all of them. The best way to work with these effects is to just play with them and see what they do. Again, your ears and your imagination are the most valuable tools in your toolbox. If you look for plugins and you find one that looks cool, see if you can have a trial playing around with it to see if you like the sounds you can create with it.

## Realistic vs. Unrealistic Sound Design

I know, you might be wondering why you would want to create unrealistic sound design. Hear me out.

Your approach to sound design is going to be radically different between a platformer game like Super Mario Bros. and a cinematic game like Heavy Rain. Trying to create realistic sound effects for Mario bashing his head against a brick isn’t going to work as well as the cute 8-bit sounds created when Mario jumps and collects coins.

When you are dealing with a cinematic game, it is vitally important to pay a lot of attention to everything going on in your scene to make sure you are including anything that your player might be hearing. If your game takes place in a forest, think about what sounds you hear when you are walking through the woods. If your game is a first-person shooter where your character is running through a hallway, remember to add footsteps and the appropriate amount of reverb.

Even within a realistic game, it is sometimes necessary to take some liberties with making everything sound exactly realistic. There are a multitude of various TV shows and films that take place in space. Nearly all of them utilize some kind of sound design, even though space is a vacuum and realistically there should be no sound. Sound is generated in these films because we psychologically expect to hear noise when something explodes. 

One cool thing you can do if you are using AV Foundation for your sounds is use the pan property. The pan property determines how much sound gets directed to either the left or right speaker in the case of stereo sound. If you have a rocket or something than generates sound that travels across the screen, you can tell the program to set the pan to the projectile’s location so that your player can hear the rocket whizzing through his or her head. Setting this property and paying attention to positional sound design really brings your soundscape to the next level. Anything you can do to immerse your player in the virtual world you have created is a good thing.

In some ways, realistic sound design is simpler than unrealistic sound design. You know what a gunshot is supposed to sound like. You know what a car crash is supposed to sound like. There are a lot of sound libraries out there that provide common realistic sounds. Creating a unique sound style for your game can be incredibly challenging. However, if you are able to accomplish something unique, you will give your game a tremendous boost. Think of how many instantly recognizable sounds came from Star Wars. No one can use any of those sounds without instantly bringing the film to mind.

I highly recommend becoming familiar with synthesizers if you are working with unrealistic sound design. Many highly recognizable sound effects are a series of musical tones. Synthesizers offer you a great deal of customization and flexibility to develop a sound personality for your game. Both Reason and Logic come with several highly capable virtual synthesizers. Synthesizers are powerful, complex tools, but like all such things, take some time and patience to master fully.

Another tip I want to pass along is to utilize natural sounds. There is a fairly well-known hoax that claims [if you slow down a recording of crickets, it sounds like humans singing.](http://www.snopes.com/critters/gnus/cricketsong.asp) The track passed around was created by layering the sounds multiple times and manipulating the speed and pitch of each layer. Slowed-down crickets may not sound exactly like humans singing, but with a lot of work they did sound radically different.

Modifying natural sounds by speeding them up or slowing them down and shifting their pitches up and down can create completely unique sounds that still have enough of a familiar undertone that they don’t sound wholly unrealistic or out of place. The sound effect that the TIE fighters make as they fly by in Star Wars is a modified howler monkey cry. The sound is unusual, but it is also familiar. We don’t think about what its base component is because we are taking it out of its original context. There is a lot of potential and flexibility to take modified animal and insect noises and place them in completely different and unexpected ways. Most of the time, your player won’t find the sound out of place if you did your job right.

## Ambient Sounds

One alternative you have to composing or commissioning a sound track is to generate an ambient soundscape for your game.

The best example I can think of for this is the game Myst. Myst had some short bits of soundtrack, but one of the big selling points of the game was this idea that you were wandering around this virtual world. Standing on the dock listening to the waves lapping against the shore and hearing the dock creaking under your feet created a far more realistic feel than you would have gotten if the game designers had had a relentless looping soundtrack in the background. 

Ambient soundscapes work really well if you have a story-based game. Strategically withdrawing sound during intense moments in your story is a great way to build tension. You know that moment in the movies when everything feels a little too quiet and it makes you uneasy? Sound is as much about what you don’t hear as it is what you do.

One thing to watch out for when creating ambient soundscapes is to avoid overdoing things. Think back to our introductory example of the ambient sounds in an office. It is really easy to go crazy adding a lot of ringing phones and slurping coffee. Coco Chanel once famously said: “Before you leave the house, look in the mirror and remove one accessory.” Have fun going overboard generating your soundscape, but be sure to go back through and tone it down a lot before you ship your game. A little goes a long way. You want your sound to be subtle and not obtrusive. It is there to enhance the experience, not overwhelm it.

## Sound Mixing

One problem I have observed, especially in media that has voice acting, is that not enough care has been taken with sound mixing. A major complaint I hear from a lot of people when I tell them I do sound design is that when they are watching something, they can’t hear the dialogue because the soundtrack is too loud.

I know, you have an awesome, kickass soundtrack. I know your soundtrack is the most amazing soundtrack ever. I know that you love to blast the killing music that plays during your final boss battle when you are coding like a rockstar. I get it.

People are not playing your game to listen to the soundtrack.

Your soundtrack, no matter how awesome, should never overpower the rest of the sound in your game, especially if that sound is dialogue that is necessary for your player to hear to understand what is going on.

Right now, go to your game. Adjust your soundtrack to how loud you think it should be relative to everything else. Do you have it where you think it should be? Good. Now make it half as loud. Now it should be about where it needs to be in order to do its job of enhancing your game rather than overpowering it. You may adjust it upward again if your beta testers tell you they want it louder. If you are not using beta testers, you should be ashamed of yourself.

## Takeaways

If you looked at the article and determined that it was too long but would still like a few tips to help you along your way, here are a few takeaways from the article:

- Buy decent tools
- Take the time to learn how to use them
- Noise and reverb are the enemy. Avoid them at all costs.
- Determine whether you want realistic or cartoon-like sound effects.
- Don’t let your soundtrack overwhelm the rest of the sound in your game.
- Close your eyes and open your ears. You can learn how to master every single audio tool on the market and it will all be worthless if you don’t use your imagination to think about what something should sound like.

Sound design is an awesome, fulfilling, creative art. Being able to walk into a world that didn't exist before and dictating what it sounds like is an amazing thing to be able to do. I went into programming for the same reasons I love sound design. It gave me a chance to start with nothing and create something that didn't exist before.

We all got into this business to create new worlds. Too often we focus just on what that world should look like without thinking about what it should sound like. Give your world a little bit of love and give it its own voice.

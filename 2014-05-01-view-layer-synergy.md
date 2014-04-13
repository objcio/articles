---
layout: post
title:  "View-layer synergy"
category: "12"
date: "2014-05-01 11:00:00"
tags: article
author: "<a href=\"https://twitter.com/davidronnqvist\">David Rönnqvist</a>"
---


**This is very rough. I mostly scribbled down my thoughts as I went through the idea. This is so that others can see what I was planning.**

---

Talk about views and layers. Even though they are very similar, they behave differently

Layers have implicit animations but views don't. 

The documentation says that the view disables implicit animations, excerpt for when done inside of an animation block. 

More documentation says that the layer asks the delegate to provide an "action" when a property changes and that the view is the layers delegate. 

This is how the view can control the layer delegate

Quick experiment to verify this: UIView animateWithDuration:animations:

Depending on if other articles have written about it or not, write about the rest of the steps in finding an implicit animation and point out what steps you can use (on a standalone layer) and when that could be a good fit. It should be [this kind of explanation](http://stackoverflow.com/a/21240400/608157) but more about how the different steps can be used. For example, have anyone ever used the actions dictionary or the style dictionary? What does "Animatable" mean? Check the the layer/view responds for animatable and non-animatable properties.

Continue the experiment to see that the animation is added to the layer using the default addAnimation:forKey: mechanism

This time I use the layerClass to be able to log when a method on the layer is called and  with what data and what the super implementation returns

UIView block based animations is a really nice API. Next up, see what is going on behind the scenes. How is the completion block being managed, what properties are set on the basic animation. 

This can be an example of a good way to deal with animation completion. There is a single purpose class that we will have to class dump to see what it is used for. 

With an understanding of how the view can return basic animations directly on the callback method, next up is key frame animations. There is a bit of trickery involved in returning NSNull first and then adding the animation after the block. 

I'll explain why this trick has to be done and why it works doing so. This will be a key point if we are trying to write our own key frame block API 

Another very interesting example is the UIImageView API because the correlation between the API and the underlying keyframe animation. Good API doesn't have to be a wrapper. 

Depending on what other articles have written use this new knowledge to make your own block based animation API. Show for example how you can do your own keyframe that automatically reverses to the original value. That is a fairly good example because it needs to deal with saving values for keyframes but the rest of the implementation is simple. It may also be worth mentioning why I'm sizzling in the example. Changing the delegate would be very hard. 

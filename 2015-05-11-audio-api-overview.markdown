---
title: "Audio API Overview"
category: "24"
date: "2015-05-11 8:00:00"
tags: article
author: "<a href=\"https://twitter.com/danielboedewadt\">Daniel Eggert</a> and <a href=\"https://twitter.com/floriankugler\">Florian Kugler</a>"
---



Both iOS and OS X come with a wide array of audio APIs, ranging from very low level to very high level. The number of different APIs, developed over time as these platforms have grown and changed, can be quite overwhelming to say the least. This article gives a brief overview of the available APIs and the different purposes they serve.

## Media Player Framework

The Media Player framework on iOS is a high-level API for audio and video playback, and includes a stock user interface you can drop into your app. You can use it to play back items in the user's iPod library, or to play local files or network streams.

Additionally, this framework contains APIs to query the user's media library, as well as to configure system audio controls like on the lock screen or in the control center.

## AVFoundation

`AVFoundation` is Apple's modern media framework that includes several APIs for different purposes and on different levels of abstraction. Some of these are modern Objective-C wrappers for lower-level C APIs. With a few exceptions, it's available both on iOS and OS X.

### AVAudioSession

`AVAudioSession` is specific to iOS and coordinates audio playback between apps, so that, for example, audio is stopped when a call comes in, or music playback stops when the user starts a movie. This API is needed to make sure an app behaves correctly in response to such events.

### AVAudioPlayer

This high-level API gives you a simple interface to play audio from local files or memory. This is a headless audio player (i.e. no UI elements are provided), and it's very straightforward to use. It's not suitable for streaming audio from the network or for low-latency realtime audio applications. If those things are not a concern, this is probably the right choice. The audio player API also comes with a few extra features, such as looping, playback-level metering, etc.

### AVAudioRecorder

As the counterpart to `AVAudioPlayer`, the audio recorder API is the simplest way to record audio straight to a file. Beyond the possibility to receive peak and average power values for a level meter, the API is very bare bones, but might just be what you need if your use case is simple.

### AVPlayer

The `AVPlayer` API gives you more flexibility and control than the APIs mentioned above. Built around the `AVPlayerItem` and `AVAsset` classes, it gives you more granular access to assets, e.g. to pick a specific track. It also supports playlists via the `AVQueuePlayer` subclass, and lets you control whether the asset can be sent over AirPlay.

A major difference compared to, for example, `AVAudioPlayer`, is `AVPlayer`'s out-of-the-box support for streaming assets from the network. This increases the complexity of playback state handling, but you can observe all state parameters using KVO. 

### AVAudioEngine

`AVAudioEngine` is a modern Objective-C API for playback and recording. It provides a level of control for which you previously had to drop down to the C APIs of the Audio Toolbox framework (for example, with real-time audio tasks). The audio engine APIs are built to interface well with lower-level APIs, so you can still drop down to Audio Toolbox if you have to.

The basic concept of this API is to build up a graph of audio nodes, ranging from source nodes (players and microphones) and overprocessing nodes (mixers and effects) to destination nodes (hardware outputs). Each node has a certain number of input and output busses with well-defined data formats. This architecture makes it very flexible and powerful. And it even integrates with audio units.

## Audio Unit Framework

The Audio Unit framework is a low-level API; all audio technologies on iOS are built on top of it. Audio units are plug-ins that process audio data. A chain of audio units is called an audio processing graph. 

You may have to use audio units directly or write your own if you need very low latency (e.g. for VoIP or synthesized musical instruments), acoustic echo cancelation, mixing, or tonal equalization. But a lot of this can often be achieved with the `AVAudioEngine` API. If you have to write your own audio units, you can integrate them in an `AVAudioEngine` processing graph with the `AVAudioUnit` node.

### Inter-App Audio

The Audio Unit API allows for Inter-App Audio on iOS. Audio streams (and MIDI commands) can be sent between apps. For example, an app can provide an audio effect or filter. Another app can then send its audio to the first app to apply the audio effect. The filtered audio is sent back to the originating app in real time. CoreAudioKit provides a simple UI for Inter-App Audio.


## Other APIs

### OpenAL

[OpenAL](https://en.wikipedia.org/wiki/OpenAL) is a cross-platform API. It provides positional (3D) and low-latency audio services. It's mostly intended for cross-platform games. The API deliberately resembles the OpenGL API in style.

### MIDI

On iOS, Core MIDI and CoreAudioKit can be used to make an app behave as a MIDI instrument. On OS X, Music Sequencing Services gives access to playing MIDI-based control and music data. Core MIDI Server gives server and driver support.

### Even More

- The most basic of all audio APIs on OS X is the `NSBeep()` function that simply plays the system sound.
- On OS X, the `NSSound` class provides a simple API to play sounds, similar in concept to  `AVAudioPlayer`.
- All notification APIs — local and remote notifications on iOS, `NSUserNotification` on OS X, and CloudKit notifications — can play sounds.
- The Audio Toolbox framework is powerful, but very low level. It's historically C++ based, but most of its functionality is now available through the `AVFoundation` framework.
- The QTKit and QuickTime frameworks are on their way out and should not be used for new development anymore. Use `AVFoundation` (and AVKit) instead.

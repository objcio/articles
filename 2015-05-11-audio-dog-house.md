---
title:  "The Audio Processing Dog House"
category: "24"
date: "2015-05-11 11:00:00"
tags: article
stylesheets: "issue-24/style.css"
author:
  - name: Jack Schaedler
    url: https://twitter.com/JackSchaedler
illustrator:
  - name: Jack Schaedler
    url: https://twitter.com/JackSchaedler
---

I'm not sure if this concept is universal, but in North America, the archetypal project for a young and aspiring carpenter is the creation of a dog house; when children become curious about construction and want to fiddle around with hammers, levels, and saws, their parents will instruct them to make one. In many respects, the dog house is a perfect project for the enthusiastic novice. It's grand enough to be inspiring, but humble enough to preclude a sense of crushing defeat if the child happens to screw it up or lose interest halfway through. The dog house is appealing as an introductory project because it is a miniature "Gesamtwerk." It requires design, planning, engineering, and manual craftsmanship. It's easy to tell when the project is complete. When Puddles can overnight in the dog house without becoming cold or wet, the project is a success.

![](/images/issue-24/pic1.png)

I'm certain that most earnest and curious developers — the kind that set aside their valuable time on evenings and weekends to read a periodical like objc.io — often find themselves in a situation where they're attempting to evaluate tools and understand new and difficult concepts without having an inspiring or meaningful project handy for application. If you're like me, you've probably experienced that peculiar sense of dread that follows the completion of a "Hello World!" tutorial. The jaunty phase of editor configuration and project setup comes to a disheartening climax when you realize that you haven't the foggiest idea what you actually want to _make_ with your new tools. What was previously an unyielding desire to learn Haskell, Swift, or C++ becomes tempered by the utter absence of a compelling project to keep you engaged and motivated.

In this article, I want to propose a "dog house" project for audio signal processing. I'm making an assumption (based on the excellent track record of objc.io) that the other articles in this issue will address your precise technical needs related to Xcode and Core Audio configuration. I'm viewing my role in this issue of objc.io as a platform-agnostic motivator, and a purveyor of fluffy signal processing theory. If you're excited about digital audio processing but haven't a clue where to begin, read on.

## Before We Begin

Earlier this year, I authored a 30-part interactive essay on basic signal processing. You can find it [here](https://jackschaedler.github.io/circles-sines-signals/index.html). I humbly suggest that you look it over before reading the rest of this article. It will help to explicate some of the basic terminology and concepts you might find confusing if you have a limited background in digital signal processing. If terms like "Sample," "Aliasing," or "Frequency" are foreign to you, that's totally OK, and this resource will help get you up to speed on the basics.

## The Project

As an introductory project to learn audio signal processing, I suggest that you <b>write an application that can track the pitch of a _monophonic_ musical performance in real time</b>. 

Think of the game "Rock Band" and the algorithm that must exist in order to analyze and evaluate the singing player's vocal performance. This algorithm must listen to the device microphone and automatically compute the frequency at which the player is singing, in real time. Assuming that you have a plump opera singer at hand, we can only hope that the project will end up looking something like this:[^1a]

![](/images/issue-24/pic2.png)

I've italicized the word monophonic because it's an important qualifier. A musical performance is _monophonic_ if there is only ever a single note being played at any given time. A melodic line is monophonic. Harmonic and chordal performances are _not_ monophonic, but instead _polyphonic_. If you're singing, playing the trumpet, blowing on a tin whistle, or tapping on the keyboard of a Minimoog, you are performing a monophonic piece of music. These instruments do not allow for the production of two or more simultaneous notes. If you're playing a piano or guitar, it's quite likely that you are generating a polyphonic audio signal, unless you're taking great pains to ensure that only one string rings out at any given time.

The pitch detection techniques that we will discuss in this article are only suitable for _monophonic_ audio signals. If you're interested in the topic of polyphonic pitch detection, skip to the _resources_ section, where I've linked to some relevant literature. In general, monophonic pitch detection is considered something of a solved problem. Polyphonic pitch detection is still an active and energetic field of research.[^1b]

I will not be providing you with code snippets in this article. Instead, I'll give you some introductory theory on pitch estimation, which should allow you to begin writing and experimenting with your own pitch tracking algorithms. It's easier than you might expect to quickly achieve convincing results! As long as you've got buffers of audio being fed into your application from the microphone or line-in, you should be able to start fiddling around with the algorithms and techniques described in this article immediately.

In the next section, I'll introduce the notion of wave _frequency_ and begin to dig into the problem of pitch detection in earnest.

## Sound, Signals, and Frequency

![](/images/issue-24/pic3.png)

Musical instruments generate sound by rapidly vibrating. As an object vibrates, it generates a [longitudinal pressure wave](http://jackschaedler.github.io/circles-sines-signals/sound.html), which radiates into the surrounding air. When this pressure wave reaches your ear, your auditory system will interpret the fluctuations in pressure as a sound. Objects that vibrate regularly and periodically generate sounds which we interpret as tones or notes. Objects that vibrate in a non-regular or random fashion generate atonal or noisy sounds. The most simple tones are described by the sine wave.

<svg id="sinecycle" class="svgWithText" width="100%" height="100"></svg>

This figure visualizes an abstract sinusoidal sound wave. The vertical axis of the figure refers to the amplitude of the wave (intensity of air pressure), and the horizontal axis represents the dimension of time. This sort of visualization is usually called a _waveform drawing_, and it allows us to understand how the amplitude and frequency of the wave changes over time. The taller the waveform, the louder the sound. The more tightly packed the peaks and troughs, the higher the frequency. 

The frequency of any wave is measured in _hertz_. One hertz is defined as one _cycle_ per second. A _cycle_ is the smallest repetitive section of a waveform. If we knew that the width of the horizontal axis corresponded to a duration of one second, we could compute the frequency of this wave in hertz by simply counting the number of visible wave cycles.

<svg id="sinecycle2" class="svgWithText" width="100%" height="100"></svg>

In the figure above, I've highlighted a single cycle of our sine wave using a transparent box. When we count the number of cycles that are completed by this waveform in one second, it becomes clear that the frequency of the wave is exactly 4 hertz, or four cycles per second. The wave below completes eight cycles per second, and therefore has a frequency of 8 hertz.  

<svg id="sinecycle3" class="svgWithText" width="100%" height="100"></svg>

Before proceeding any further, we need some clarity around two terms I have been using interchangeably up to this point. _Pitch_ is an auditory sensation related to the human perception of sound. _Frequency_ is a physical, measurable property of a waveform. We relate the two concepts by noting that the pitch of a signal is very closely related to its frequency. For simple sinusoids, the pitch and frequency are more or less equivalent. For more complex waveforms, the pitch corresponds to the _fundamental_ frequency of the waveform (more on this later). Conflating the two concepts can get you into trouble. For example, given two sounds with the same fundamental frequency, humans will often perceive the louder sound to be higher in pitch. For the rest of this article, I will be sloppy and use the two terms interchangeably. If you find this topic interesting, continue your extracurricular studies [here](http://en.wikipedia.org/wiki/Pitch_%28music%29).


## Pitch Detection

Stated simply, algorithmic pitch detection is the task of automatically computing the frequency of some arbitrary waveform. In essence, this all boils down to being able to robustly identify a single cycle within a given waveform. This is an exceptionally easy task for humans, but a difficult task for machines. The CAPTCHA mechanism works precisely because it's quite difficult to write algorithms that are capable of robustly identifying structure and patterns within arbitrary sets of sample data. I personally have no problem picking out the repeating pattern in a waveform using my eyeballs, and I'm sure you don't either. The trick is to figure out how we might program a computer to do the same thing quickly, in a real-time, performance-critical environment.[^1c]


## The Zero-Crossing Method

As a starting point for algorithmic frequency detection, we might notice that any sine wave will cross the horizontal axis two times per cycle. If we count the number of zero-crossings that occur over a given time period, and then divide that number by two, we _should_ be able to easily compute the number of cycles present within a waveform. For example, in the figure below, we count eight zero-crossings over the duration of one second. This implies that there are four cycles present in the wave, and we can therefore deduce that the frequency of the signal is 4 hertz.

<svg id="zerocrossings" class="svgWithText" width="100%" height="100"></svg>

We might begin to notice some problems with this approach when fractional numbers of cycles are present in the signal under analysis. For example, if the frequency of our waveform increases slightly, we will now count nine zero-crossings over the duration of our one-second window. This will lead us to incorrectly deduce that the frequency of the purple wave is 4.5 hertz, when it's really more like _4.6_ hertz.

<svg id="zerocrossings2" class="svgWithText" width="100%" height="100"></svg>

We can alleviate this problem a bit by adjusting the size of our analysis window, performing some clever averaging, or introducing heuristics that remember the position of zero-crossings in previous windows and predict the position of future zero-crossings. I'd recommend playing around a bit with improvements to the naive counting approach until you feel comfortable working with a buffer full of audio samples. If you need some test audio to feed into your iOS device, you can load up the sine generator at the bottom of [this page](http://jackschaedler.github.io/circles-sines-signals/sound.html).

While the zero-crossing approach might be workable for very simple signals, it will fail in more distressing ways for complex signals. As an example, take the signal depicted below. This wave still completes one cycle every 0.25 seconds, but the number of zero-crossings per cycle is considerably higher than what we saw for the sine wave. The signal produces six zero-crossings per cycle, even though the fundamental frequency of the signal is still 4 hertz.

<svg id="zerocrossingscomplex" class="svgWithText" width="100%" height="100"></svg>

While the zero-crossing approach isn't really ideal for use as a hyper-precise pitch tracking algorithm, it can still be incredibly useful as a quick and dirty way to roughly measure the amount of noise present in a signal. The zero-crossing approach is appropriate in this context because noisy signals will produce more zero-crossings per unit time than cleaner, more tonal sounds. Zero-crossing counting is often used in voice recognition software to distinguish between voiced and unvoiced segments of speech. Roughly speaking, voiced speech usually consists of vowels, where unvoiced speech is produced by consonants. However, some consonants, like the English "Z," are voiced (think of saying "zeeeeee").

Before we move on to introducing a more robust approach to pitch detection, we first must understand what is meant by the term I bandied about in earlier sections. Namely, the _fundamental frequency_.

## The Fundamental Frequency

Most natural sounds and waveforms are _not_ pure sinusoids, but amalgamations of multiple sine waves. While [Fourier Theory](http://jackschaedler.github.io/circles-sines-signals/dft_introduction.html) is beyond the scope of this article, you must accept the fact that physical sounds are (modeled by) summations of many sinusoids, and each constituent sinusoid may differ in frequency and amplitude. When our algorithm is fed this sort of compound waveform, it must determine which sinusoid is acting as the _fundamental_ or foundational component of the sound and compute the frequency of _that_ wave.

I like to think of sounds as compositions of spinning, circular forms. A sine wave can be described by a spinning circle, and more complex wave shapes can be created by chaining or summing together additional spinning circles.[^1d] Experiment with the visualization below by clicking on each of the four buttons to see how various compound waveforms can be composed using many individual sinusoids.

<p id="phasorbuttons" class="buttonholder" style="text-align: center"></p>
<svg id="phasorSum2" class="svgWithText" width="100%" height="300" style="margin-left: 10px"></svg>

The blue spinning circle at the center of the diagram represents the _fundamental_, and the additional orbiting circles describe _overtones_ of the fundamental. It's important to notice that one rotation of the blue circle corresponds precisely to one cycle in the generated waveform. In other words, every full rotation of the fundamental generates a single cycle in the resulting waveform.[^1e]

I've again highlighted a single cycle of each waveform using a grey box, and I'd encourage you to notice that the fundamental frequency of all four waveforms is identical. Each has a fundamental frequency of 4 hertz. Even though there are multiple sinusoids present in the square, saw, and wobble waveforms, the fundamental frequency of the four waveforms is always tied to the blue sinusoidal component. The blue component acts as the foundation of the signal.

It's also very important to notice that the fundamental is not necessarily the largest or loudest component of a signal. If you take another look at the "wobble" waveform, you'll notice that the second overtone (orange circle) is actually the largest component of the signal. In spite of this rather dominant overtone, the fundamental frequency is still unchanged.[^1f]

In the next section, we'll revisit some university math, and then investigate another approach for fundamental frequency estimation that should be capable of dealing with these pesky compound waveforms.


## The Dot Product and Correlation

The _dot product_ is probably the most commonly performed operation in audio signal processing. The dot product of two signals is easily defined in pseudo-code using a simple _for_ loop. Given two signals (arrays) of equal length, their dot product can be expressed as follows:

```swift
func dotProduct(signalA: [Float], signalB: [Float]) -> Float {
	var sum:Float = 0.0
	for v in map(zip(signalA, signalB), *) {
		sum += v
	}
	return sum
}
```

Hidden in this rather pedestrian code snippet is a truly wonderful property. The dot product can be used to compute the similarity or _correlation_ between two signals. If the dot product of two signals resolves to a large value, you know that the two signals are positively correlated. If the dot product of two signals is zero, you know that the two signals are decorrelated — they are not similar. As always, it's best to scrutinize such a claim visually, and I'd like you to spend some time studying the figure below.

<svg id="sigCorrelationInteractive" class="svgWithText" width="100%" height="380"></svg>
<p class="controls">
  <label id="squareShift" for="squareCorrelationOffset">Shift</label><br/>
  <input type="range" min="0" max="100" value="0" id="squareCorrelationOffset" step="0.5" oninput="updateSquareCorrelationOffset(value);" onMouseDown="" onMouseUp="" style="width: 150px">
</p>

This visualization depicts the computation of the dot product of two different signals. On the topmost row, you will find a depiction of a square wave, which we'll call Signal A. On the second row, there is a sinusoidal waveform we'll refer to as Signal B. The waveform drawn on the bottommost row depicts the product of these two signals. This signal is generated by multiplying each point in Signal A with its vertically aligned counterpart in Signal B. At the very bottom of the visualization, we're displaying the final value of the dot product. The magnitude of the dot product corresponds to the integral, or the area underneath this third curve. 

As you play with the slider at the bottom of the visualization, notice that the absolute value of the dot product will be larger when the two signals are correlated (tending to move up and down together), and smaller when the two signals are out of phase or moving in opposite directions. The more that Signal A behaves like Signal B, the larger the resulting dot product. Amazingly, the dot product allows us to easily compute the similarity between two signals.

In the next section, we'll apply the dot product in a clever way to identify cycles within our waveforms and devise a simple method for determining the fundamental frequency of a compound waveform.

## Autocorrelation

![](/images/issue-24/pic5.png)

The autocorrelation is like an auto portrait, or an autobiography. It's the correlation of a signal with _itself_. We compute the autocorrelation by computing the dot product of a signal with a copy of itself at various shifts or time _lags_. Let's assume that we have a compound signal that looks something like the waveform shown in the figure below.

<svg id="autosignal" class="svgWithText" width="100%" height="100"></svg>

We compute the autocorrelation by making a copy of the signal and repeatedly shifting it alongside the original. For each shift (lag), we compute the dot product of the two signals and record this value into our _autocorrelation function_. The autocorrelation function is plotted on the third row of the following figure. For each possible lag, the height of the autocorrelation function tells us how much similarity there is between the original signal and its copy.

<svg id="sigCorrelationInteractiveTwoSines" class="svgWithText" width="100%" height="300" style=""></svg>
<p class="controls">
  <label id="phaseShift" for="simpleCorrelationOffset">Lag: <b> -60</b></label><br/>
  <input type="range" min="0" max="120" value="0" id="simpleCorrelationOffset" step="1" oninput="updateSimpleCorrelationOffset(value);"
  onMouseDown="" onMouseUp="" style="width: 150px">
</p>

Slowly move the slider at the bottom of this figure to the right to explore the values of the autocorrelation function for various lags. I'd like you to pay particular attention to the position of the peaks (local maxima) in the autocorrelation function. For example, notice that the highest peak in the autocorrelation will always occur when there is no lag. Intuitively, this should make sense because a signal will always be maximally correlated with itself. More importantly, however, we should notice that the secondary peaks in the autocorrelation function occur when the signal is shifted by a multiple of one cycle. In other words, we get peaks in the autocorrelation every time that the copy is shifted or lagged by one full cycle, since it once again "lines up" with itself.

The trick behind this approach is to determine the distance between consecutive prominent peaks in the autocorrelation function. This distance will correspond precisely to the length of one waveform cycle. The longer the distance between peaks, the longer the wave cycle and the lower the frequency. The shorter the distance between peaks, the shorter the wave cycle and the higher the frequency. For our waveform, we can see that the distance between prominent peaks is 0.25 seconds. This means that our signal completes four cycles per second, and the fundamental frequency is 4 hertz — just as we expected from our earlier visual inspection.

<svg id="autocorrelationinterpretation" class="svgWithText" width="100%" height="150"></svg>

The autocorrelation is a nifty signal processing trick for pitch estimation, but it has its drawbacks. One obvious problem is that the autocorrelation function tapers off at its left and right edges. The tapering is caused by fewer non-zero samples being used in the calculation of the dot product for extreme lag values. Samples that lie outside the original waveform are simply considered to be zero, causing the overall magnitude of the dot product to be attenuated. This effect is known as <i>biasing</i>, and can be addressed in a number of ways. In his excellent paper, <a href="http://miracle.otago.ac.nz/tartini/papers/A_Smarter_Way_to_Find_Pitch.pdf">"A Smarter Way to Find Pitch,"</a> Philip McLeod devises a strategy that cleverly removes this biasing from the autocorrelation function in a non-obvious but very robust way. When you've played around a bit with a simple implementation of the autocorrelation, I would suggest reading through this paper to see how the basic method can be refined and improved.

Autocorrelation as implemented in its naive form is an _O(N<sup>2</sup>)_ operation. This complexity class is less than desirable for an algorithm that we intend to run in real time. Thankfully, there is an efficient way to compute the autocorrelation in _O(N log(N))_ time. The theoretical justification for this algorithmic shortcut is far beyond the scope of this article, but if you're interested, you should know that it's possible to compute the autocorrelation function using two FFT (Fast Fourier Transform) operations. You can read more about this technique in the footnotes.[^1g] I would suggest writing the naive version first, and using this implementation as a ground truth to verify a fancier, FFT-based implementation. 

## Latency and the Waiting Game

![](/images/issue-24/pic4.png)

Real-time audio applications partition time into chunks or _buffers_. In the case of iOS and OS X development, Core Audio will deliver buffers of audio to your application from an input source like a microphone or input jack and expect you to regularly provide a buffer's worth of audio in the rendering callback. It may seem trivial, but it's important to understand the relationship of your application's audio buffer size to the sort of audio material you want to consider in your analysis algorithms.

Let's walk through a simple thought experiment. Pretend that your application is operating at a sampling rate of 128 hertz,[^1h] and your application is being delivered buffers of 32 samples. If you want to be able to detect fundamental frequencies as low as 2 hertz, it will be necessary to collect two buffers worth of input samples before you've captured a whole cycle of a 2 hertz input wave.

<svg id="buffer1" class="svgWithText" width="100%" height="100"></svg>
<svg id="buffer2" class="svgWithText" width="100%" height="100"></svg>

The pitch detection techniques discussed in this article actually need _two or more_ cycles worth of input signal to be able to robustly detect a pitch. For our imaginary application, this means that we'd have to wait for two _more_ buffers of audio to be delivered to our audio input callback before being able to accurately report a pitch for this waveform.

<svg id="buffer3" class="svgWithText" width="100%" height="100"></svg>

<svg id="buffer4" class="svgWithText" width="100%" height="100"></svg>

This may seem like stating the obvious, but it's a very important point. A classic mistake when writing audio analysis algorithms is to create an implementation that works well for high-frequency signals, but performs poorly on low-frequency signals. This can occur for many reasons, but it's often caused by not working with a large enough analysis window — by not waiting to collect enough samples before performing your analysis. High-frequency signals are less likely to reveal this sort of problem because there are usually enough samples present in a single audio buffer to fully describe many cycles of a high-frequency input waveform.

<svg id="buffer5" class="svgWithText" width="100%" height="100"></svg>

The best way to handle this situation is to push every incoming audio buffer into a secondary circular buffer. This circular buffer should be large enough to accommodate at least two full cycles of the lowest pitch you want to detect. Avoid the temptation to simply increase the buffer size of your application. This will cause the overall latency of your application to increase, even though you only require a larger buffer for particular analysis tasks.

You can reduce latency by choosing to exclude very bassy frequencies from your detectable range. For example, you'll probably be operating at a sample rate of 44,100 hertz in your OS X or iOS project, and if you want to detect pitches beneath 60 hertz, you'll need to collect at least 2,048 samples before performing the autocorrelation operation. If you don't care about pitches beneath 60 hertz, you can get away with an analysis buffer size of 1,024 samples.

The important takeaway from this section is that it's impossible to _instantly_ detect pitch. There's an inherent latency in any pitch tracking approach, and you must simply be willing to wait. The lower the frequencies you want to detect, the longer you'll have to wait. This tradeoff between frequency coverage and algorithmic latency is actually related to the Heisenberg Uncertainty Principle, and permeates all of signal processing theory. In general, the more you know about a signal's frequency content, the less you know about its placement in time.

## References and Further Reading

I hope that by now you have a sturdy enough theoretical toehold on the problem of fundamental frequency estimation to begin writing your own monophonic pitch tracker. Working from the cursory explanations in this article, you should be able to implement a simple monophonic pitch tracker and dig into some of the relevant academic literature with confidence. If not, I hope that you at least got a small taste for audio signal processing theory and enjoyed the visualizations and illustrations.

The approaches to pitch detection outlined in this article have been explored and refined to a great degree of finish by the academic signal processing community over the past few decades. In this article, we've only scratched the surface, and I suggest that you refine your initial implementations and explorations by digging deeper into two exceptional examples of monophonic pitch detectors: the SNAC and YIN algorithms.

Philip McLeod's SNAC pitch detection algorithm is a clever refinement of the autocorrelation method introduced in this article. McLeod has found a way to work around the inherent biasing of the autocorrelation function. His method is performant and robust. I highly recommend reading McLeod's paper titled <a href="http://miracle.otago.ac.nz/tartini/papers/A_Smarter_Way_to_Find_Pitch.pdf">"A Smarter Way to Find Pitch"</a> if you want to learn more about monophonic pitch detection. It's one of the most approachable papers on the subject. There is also a wonderful tutorial and evaluation of McLeod's method available <a href="http://www.katjaas.nl/helmholtz/helmholtz.html">here</a>. I <i>highly</i> recommend poking around this author's website. 

YIN was developed by Cheveigné and Kawahahara in the early 2000s, and remains a classic pitch estimation technique. It's often taught in graduate courses on audio signal processing. I'd definitely recommend reading <a href="http://audition.ens.fr/adc/pdf/2002_JASA_YIN.pdf">the original paper</a> if you find the topic of pitch estimation interesting. Implementing your own version of YIN is a fun weekend task.

If you're interested in more advanced techniques for <i>polyphonic</i> fundamental frequency estimation, I suggest that you begin by reading Anssi Klapuri's excellent Ph.D. thesis on <a href="http://www.cs.tut.fi/sgn/arg/klap/phd/klap_phd.pdf">automatic music transcription</a>. In his paper, he outlines a number of approaches to multiple fundamental frequency estimation, and gives a great overview of the entire automatic music transcription landscape.

If you're interested in more advanced techniques for _polyphonic_ fundamental frequency estimation, I suggest that you begin by reading Anssi Klapuri's excellent Ph.D. thesis on [automatic music transcription](http://www.cs.tut.fi/sgn/arg/klap/phd/klap_phd.pdf). In his paper, he outlines a number of approaches to multiple fundamental frequency estimation, and gives a great overview of the entire automatic music transcription landscape.

If you're feeling inspired enough to start on your own dog house, feel free to [contact me](https://twitter.com/JackSchaedler) on Twitter with any questions, complaints, or comments about the content of this article. Happy building!

![](/images/issue-24/pic6.png)

<style type="text/css">
  .controls {
    text-align: center;
    font-size: 0.8em;
  }

  .svgWithText {
    font-size: 0.7em;

    user-select: none;
    -moz-user-select: none;
    -webkit-user-select: none;
  }

  .axis path,
  .axis line {
      fill: none;
    stroke: #333333;
    shape-rendering: crispEdges;
  }
  .gridAxis path,
  .gridAxis line {
      fill: none;
    stroke: #dddddd;
    stroke-width: 1;
    shape-rendering: crispEdges;
  }

  .buttonholder {
    padding: 10px;
  }

  .buttonholder button {
    margin-left: 5px;
    margin-top: 5px;
    cursor: pointer;
    padding: 5px 10px;
    border-radius: 5px;
    border: solid 1px #ccc;
    color: #333;
    background: #fff;
    bottom: 20px;
    left: 20px;
    font-size: 0.8em;
  }

  .buttonholder button:hover {
    border-color: #777;
    color: #000;
  }

  .buttonholder button:focus {
    outline: none;
  }
</style>

<script src="//cdnjs.cloudflare.com/ajax/libs/d3/3.5.5/d3.min.js"></script>

<script>
  // sinecycle
  (function() {
    var canvasWidth = 600;
    var canvasHeight = 100;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    var vis = d3.select('#sinecycle');

    var plotWidth = canvasWidth - MARGINS.left - MARGINS.right;
    var plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var xRangeTime = d3.scale.linear().range([0, canvasWidth]);
    xRangeTime.domain([0, 8 * Math.PI]);

    var yRangeTime = d3.scale.linear().range([canvasHeight, 0]);
    yRangeTime.domain([-1, 1]);

    var data = d3.range(0, 8 * Math.PI, 0.01);

    var signal = d3.svg.line()
      .x(function (d, i) { return xRangeTime(d) + 1; })
      .y(function (d, i) { return yRangeTime(Math.sin(d)  * 0.9)} );

    var xAxis = d3.svg.axis()
      .scale(xRangeTime)
      .tickSize(0)
      .ticks(0)
      .tickSubdivide(true);

    var yAxis = d3.svg.axis()
      .scale(yRangeTime)
      .tickSize(0)
      .ticks(0)
      .orient('left')
      .tickSubdivide(true);

    vis.append('text')
      .attr("text-anchor", "left")
      .attr("x", 5)
      .attr("y", yRangeTime(-1))
      .attr("stroke", "none")
      .attr("fill", "grey")
      .attr("font-size", 11)
      .text("Amplitude");

    vis.append('text')
      .attr("text-anchor", "end")
      .attr("x", xRangeTime(Math.PI * 8))
      .attr("y", yRangeTime(0.1))
      .attr("stroke", "none")
      .attr("fill", "grey")
      .attr("font-size", 11)
      .text("Time");

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeTime(0) + ')')
      .style("opacity", 0.35)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'y axis')
      .attr('transform', 'translate(0,0)')
      .style("opacity", 0.35)
      .call(yAxis);

    var path = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", "steelblue")
      .attr("fill", "none")
      .attr("opacity", 1.0)
      .attr("d", signal(data));
  })();

  // sinecycle2
  (function() {
    var canvasWidth = 600;
    var canvasHeight = 100;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    var vis = d3.select('#sinecycle2');

    var plotWidth = canvasWidth - MARGINS.left - MARGINS.right;
    var plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var xRangeTime = d3.scale.linear().range([0, canvasWidth]);
    xRangeTime.domain([0, 8 * Math.PI]);

    var yRangeTime = d3.scale.linear().range([canvasHeight, 0]);
    yRangeTime.domain([-1, 1]);

    var data = d3.range(0, 8 * Math.PI, 0.01);

    var signal = d3.svg.line()
      .x(function (d, i) { return xRangeTime(d) + 1; })
      .y(function (d, i) { return yRangeTime(Math.sin(d) * 0.9)} );

    vis.append("svg:rect")
      .attr("fill", "grey")
      .style("opacity", 0.10)
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", xRangeTime(2*Math.PI))
      .attr("height", yRangeTime(-1) - yRangeTime(1));

    var xAxis = d3.svg.axis()
      .scale(xRangeTime)
      .tickSize(10)
      .tickValues([2*Math.PI, 4*Math.PI, 6*Math.PI, 8*Math.PI])
      .tickFormat(function(d) { return (d / (8*Math.PI)) + " s"; })
      .tickSubdivide(true);

    var yAxis = d3.svg.axis()
      .scale(yRangeTime)
      .tickSize(0)
      .ticks(0)
      .orient('left')
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeTime(0) + ')')
      .style("opacity", 0.35)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'y axis')
      .attr('transform', 'translate(0,0)')
      .style("opacity", 0.35)
      .call(yAxis);

    var path = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", "steelblue")
      .attr("fill", "none")
      .attr("opacity", 1.0)
      .attr("d", signal(data));
  })();

  // sinecycle3
  (function() {

    var canvasWidth = 600;
    var canvasHeight = 100;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    var vis = d3.select('#sinecycle3');

    var plotWidth = canvasWidth - MARGINS.left - MARGINS.right;
    var plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var xRangeTime = d3.scale.linear().range([0, canvasWidth]);
    xRangeTime.domain([0, 8 * Math.PI]);

    var yRangeTime = d3.scale.linear().range([canvasHeight, 0]);
    yRangeTime.domain([-1, 1]);

    var data = d3.range(0, 8 * Math.PI, 0.01);

    var signal = d3.svg.line()
      .x(function (d, i) { return xRangeTime(d) + 1; })
      .y(function (d, i) { return yRangeTime(Math.sin(2 * d) * 0.9)} );

    vis.append("svg:rect")
      .attr("fill", "grey")
      .style("opacity", 0.10)
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", xRangeTime(Math.PI))
      .attr("height", yRangeTime(-1) - yRangeTime(1));

    var xAxis = d3.svg.axis()
      .scale(xRangeTime)
      .tickSize(10)
      .tickValues([2*Math.PI, 4*Math.PI, 6*Math.PI, 8*Math.PI])
      .tickFormat(function(d) { return (d / (8*Math.PI)) + " s"; })
      .tickSubdivide(true);

    var yAxis = d3.svg.axis()
      .scale(yRangeTime)
      .tickSize(0)
      .ticks(0)
      .orient('left')
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeTime(0) + ')')
      .style("opacity", 0.35)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'y axis')
      .attr('transform', 'translate(0,0)')
      .style("opacity", 0.35)
      .call(yAxis);

    var path = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", "steelblue")
      .attr("fill", "none")
      .attr("opacity", 1.0)
      .attr("d", signal(data));
  })();

  // zerocrossings
  (function() {
    var canvasWidth = 600;
    var canvasHeight = 100;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    var vis = d3.select('#zerocrossings');

    var plotWidth = canvasWidth - MARGINS.left - MARGINS.right;
    var plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var xRangeTime = d3.scale.linear().range([0, canvasWidth]);
    xRangeTime.domain([0, 8 * Math.PI]);

    var yRangeTime = d3.scale.linear().range([canvasHeight, 0]);
    yRangeTime.domain([-1, 1]);

    var data = d3.range(0, 8 * Math.PI, 0.01);

    var signal = d3.svg.line()
      .x(function (d, i) { return xRangeTime(d) + 1; })
      .y(function (d, i) { return yRangeTime(Math.sin(d) * 0.9)} );

    vis.append("svg:rect")
      .attr("fill", "grey")
      .style("opacity", 0.10)
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", xRangeTime(2*Math.PI))
      .attr("height", yRangeTime(-1) - yRangeTime(1));

    var xAxis = d3.svg.axis()
      .scale(xRangeTime)
      .tickSize(10)
      .tickValues([2*Math.PI, 4*Math.PI, 6*Math.PI, 8*Math.PI])
      .tickFormat(function(d) { return (d / (8*Math.PI)) + " s"; })
      .tickSubdivide(true);

    var yAxis = d3.svg.axis()
      .scale(yRangeTime)
      .tickSize(0)
      .ticks(0)
      .orient('left')
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeTime(0) + ')')
      .style("opacity", 0.35)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'y axis')
      .attr('transform', 'translate(0,0)')
      .style("opacity", 0.35)
      .call(yAxis);

    var path = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", "steelblue")
      .attr("fill", "none")
      .attr("opacity", 1.0)
      .attr("d", signal(data));

    vis.append("defs").append("marker")
        .attr("id", "arrowhead")
        .attr("refX", 5)
        .attr("refY", 2)
        .attr("markerWidth", 10)
        .attr("markerHeight", 10)
        .attr("orient", "auto")
        .attr("fill", "black")
        .append("path")
            .attr("d", "M 0,0 V 4 L6,2 Z");

    for (var i = 0; i < 8; i++)
    {
      vis.append("circle")
        .attr("cx", xRangeTime(Math.PI * (i + 1)) + 1)
        .attr("cy", yRangeTime(0))
        .attr("r", 4)
        .attr("stroke-width", 0)
        .attr("stroke", "black")
        .style("opacity", 0.5)
        .attr("fill", "black");

      vis.append("line")
        .attr("x1", xRangeTime(Math.PI * (i + 1)) + 1)
        .attr("y1", yRangeTime(1))
        .attr("x2", xRangeTime(Math.PI * (i + 1)) + 1)
        .attr("y2", yRangeTime(0) - 5)
        .attr("stroke-width", 2)
        .attr("stroke", "black")
        .style("opacity", 0.25)
        .attr("marker-end", "url(#arrowhead)");
    }
  })();

  // zerocrossings2
  (function() {
    var canvasWidth = 600;
    var canvasHeight = 100;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    var vis = d3.select('#zerocrossings2');

    var plotWidth = canvasWidth - MARGINS.left - MARGINS.right;
    var plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var xRangeTime = d3.scale.linear().range([0, canvasWidth]);
    xRangeTime.domain([0, 8 * Math.PI]);

    var yRangeTime = d3.scale.linear().range([canvasHeight, 0]);
    yRangeTime.domain([-1, 1]);

    var data = d3.range(0, 8 * Math.PI, 0.01);

    var signal = d3.svg.line()
      .x(function (d, i) { return xRangeTime(d) + 1; })
      .y(function (d, i) { return yRangeTime(Math.sin(d * 1.22) * 0.9)} );

    vis.append("svg:rect")
      .attr("fill", "grey")
      .style("opacity", 0.10)
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", xRangeTime(2 * 0.82 * Math.PI))
      .attr("height", yRangeTime(-1) - yRangeTime(1));

    var xAxis = d3.svg.axis()
      .scale(xRangeTime)
      .tickSize(10)
      .tickValues([2*Math.PI, 4*Math.PI, 6*Math.PI, 8*Math.PI])
      .tickFormat(function(d) { return (d / (8*Math.PI)) + " s"; })
      .tickSubdivide(true);

    var yAxis = d3.svg.axis()
      .scale(yRangeTime)
      .tickSize(0)
      .ticks(0)
      .orient('left')
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeTime(0) + ')')
      .style("opacity", 0.35)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'y axis')
      .attr('transform', 'translate(0,0)')
      .style("opacity", 0.35)
      .call(yAxis);

    var path = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", "purple")
      .attr("fill", "none")
      .attr("opacity", 0.6)
      .attr("d", signal(data));

    vis.append("defs").append("marker")
        .attr("id", "arrowhead")
        .attr("refX", 5)
        .attr("refY", 2)
        .attr("markerWidth", 10)
        .attr("markerHeight", 10)
        .attr("orient", "auto")
        .attr("fill", "black")
        .append("path")
            .attr("d", "M 0,0 V 4 L6,2 Z");

    for (var i = 0; i < 9; i++)
    {
      vis.append("circle")
        .attr("cx", xRangeTime(0.82 * Math.PI * (i + 1)) + 1)
        .attr("cy", yRangeTime(0))
        .attr("r", 4)
        .attr("stroke-width", 0)
        .attr("stroke", "black")
        .style("opacity", 0.5)
        .attr("fill", "black");

      vis.append("line")
        .attr("x1", xRangeTime(0.82 * Math.PI * (i + 1)) + 1)
        .attr("y1", yRangeTime(1))
        .attr("x2", xRangeTime(0.82 * Math.PI * (i + 1)) + 1)
        .attr("y2", yRangeTime(0) - 5)
        .attr("stroke-width", 2)
        .attr("stroke", "black")
        .style("opacity", 0.25)
        .attr("marker-end", "url(#arrowhead)");
    }
  })();

  // zerocrossingscomplex
  (function() {
    var canvasWidth = 600;
    var canvasHeight = 100;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    var vis = d3.select('#zerocrossingscomplex');

    var plotWidth = canvasWidth - MARGINS.left - MARGINS.right;
    var plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var xRangeTime = d3.scale.linear().range([0, canvasWidth]);
    xRangeTime.domain([0, 8 * Math.PI]);

    var yRangeTime = d3.scale.linear().range([canvasHeight, 0]);
    yRangeTime.domain([-1, 1]);

    var data = d3.range(0, 8 * Math.PI, 0.01);

    var signal = d3.svg.line()
      .x(function (d, i) { return xRangeTime(d) + 1; })
      .y(function (d, i) { return yRangeTime((Math.sin(d) + Math.sin(d*2) + Math.sin(d*3)) * 0.35) } );

    vis.append("svg:rect")
      .attr("fill", "grey")
      .style("opacity", 0.10)
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", xRangeTime(2*Math.PI))
      .attr("height", yRangeTime(-1) - yRangeTime(1));

    var xAxis = d3.svg.axis()
      .scale(xRangeTime)
      .tickSize(10)
      .tickValues([2*Math.PI, 4*Math.PI, 6*Math.PI, 8*Math.PI])
      .tickFormat(function(d) { return (d / (8*Math.PI)) + " s"; })
      .tickSubdivide(true);

    var yAxis = d3.svg.axis()
      .scale(yRangeTime)
      .tickSize(0)
      .ticks(0)
      .orient('left')
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeTime(0) + ')')
      .style("opacity", 0.35)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'y axis')
      .attr('transform', 'translate(0,0)')
      .style("opacity", 0.35)
      .call(yAxis);

    var path = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", "green")
      .attr("fill", "none")
      .attr("opacity", 0.7)
      .attr("d", signal(data));

    vis.append("defs").append("marker")
        .attr("id", "arrowhead")
        .attr("refX", 5)
        .attr("refY", 2)
        .attr("markerWidth", 10)
        .attr("markerHeight", 10)
        .attr("orient", "auto")
        .attr("fill", "black")
        .append("path")
            .attr("d", "M 0,0 V 4 L6,2 Z");

    var zeroes = 
    [
      Math.PI,
      2 * Math.PI,
      3 * Math.PI,
      4 * Math.PI,
      5 * Math.PI,
      6 * Math.PI,
      7 * Math.PI,
      8 * Math.PI,
    ];

    var zero = Math.PI / 2;
    for (var i = 0; i < 8; i++)
    {
      zeroes.push(zero);
      zero += Math.PI;
    }

    zero = Math.PI / 2 + 0.5;
    for (var i = 0; i < 4; i++)
    {
      zeroes.push(zero);
      zero += Math.PI * 2;
    }

    zero = Math.PI + 1.0;
    for (var i = 0; i < 4; i++)
    {
      zeroes.push(zero);
      zero += Math.PI * 2;
    }

    for (var i = 0; i < zeroes.length; i++)
    {
      vis.append("circle")
        .attr("cx", xRangeTime(zeroes[i]) + 1)
        .attr("cy", yRangeTime(0))
        .attr("r", 4)
        .attr("stroke-width", 0)
        .attr("stroke", "black")
        .style("opacity", 0.5)
        .attr("fill", "black");

      vis.append("line")
        .attr("x1", xRangeTime(zeroes[i]) + 1)
        .attr("y1", yRangeTime(1))
        .attr("x2", xRangeTime(zeroes[i]) + 1)
        .attr("y2", yRangeTime(0) - 5)
        .attr("stroke-width", 2)
        .attr("stroke", "black")
        .style("opacity", 0.25)
        .attr("marker-end", "url(#arrowhead)");
    }
  })();

  // phasorSum2
  (function() {
    var canvasWidth = 300;
    var canvasHeight = 300;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    var plotWidth = canvasWidth - MARGINS.left - MARGINS.right;
    var plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var xRange = d3.scale.linear().range([MARGINS.left, plotWidth]);
    var yRange = d3.scale.linear().range([plotHeight, MARGINS.top]);

    xRange.domain([-1.25 * 2.0, 1.25 * 2.0]);
    yRange.domain([-1.25 * 2.0, 1.25 * 2.0]);

    var vis = d3.select('#phasorSum2');

    var xAxis = d3.svg.axis()
      .scale(xRange)
      .tickSize(0)
      .ticks(0)
      .tickSubdivide(true);

    var yAxis = d3.svg.axis()
      .scale(yRange)
      .tickSize(0)
      .ticks(0)
      .orient('left')
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + (plotHeight / 2) + ')')
      .style('opacity', 0.25)
      .call(xAxis);
     
    vis.append('svg:g')
      .attr('class', 'y axis')
      .attr('transform', 'translate(' + plotWidth / 2 + ',0)')
      .style('opacity', 0.25)
      .call(yAxis);

    var colorScale = d3.scale.category10();
    colorScale.domain[d3.range(0, 10, 1)];

    var vectors = [];
    var frequencyVectors = [];
    var circles = [];
    var amplitudes = [];
    var freqSamples = [];

    for (var i = 0; i < 5; i++)
    {
      vectors.push(vis.append("line")
        .attr("stroke-width", 2.0)
        .attr("stroke", colorScale(i))
        .style("stroke-linecap", "round")
        .style('opacity', 1.0)
        );

      circles.push(vis.append('svg:circle')
        .attr('stroke-width', 2.5)
        .attr('stroke', colorScale(i))
        .attr('fill', 'none')
        .attr('opacity', 0.30)
      );

      amplitudes.push(i === 0 ? 0.5 : 0.0);
    }

    var sineProjection = vis.append("line")
      .attr("x1", xRange(1))
      .attr("y1", yRange(0))
      .attr("x2", xRange(0))
      .attr("y2", yRange(0))
      .attr("stroke-width", 2.0)
      .attr("stroke", "grey")
      .style("stroke-linecap", "round")
      .style("stroke-dasharray", ("3, 3"))
      .style("opacity", 1.0);

    var axisExtension = vis.append("line")
      .attr("x1", xRange(2.5))
      .attr("y1", yRange(0))
      .attr("x2", 630)
      .attr("y2", yRange(0))
      .attr("stroke-width", 1.0)
      .attr("stroke", "black")
      .style("opacity", 0.5);

    var path = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", "grey")
      .attr("fill", "none")
      .style("opacity", 0.75);

    var traceCircle = vis.append('svg:circle')
      .attr('cx', xRange(0))
      .attr('cy', yRange(0))
      .attr('r', 2)
      .attr('stroke-width', 2.0)
      .attr('stroke', 'grey')
      .attr('fill', 'grey')
      .attr('opacity', 1);

    var time = 0.0;
    var data = d3.range(0, 6 * Math.PI + 0.05, 0.05);

    var xRangePlot = d3.scale.linear().range([xRange(0) + 150, xRange(0) + 450]);
    xRangePlot.domain([0, 6 * Math.PI + 0.05]);

    vis.append("line")
      .attr("x1", xRangePlot(2 * Math.PI))
      .attr("y1", yRange(-0.1))
      .attr("x2", xRangePlot(2 * Math.PI))
      .attr("y2", yRange(0))
      .attr("stroke-width", 1.0)
      .attr("stroke", "grey");

    vis.append("text")
      .attr("text-anchor", "middle")
      .attr("x", xRangePlot(2 * Math.PI))
      .attr("y", yRange(-0.3))
      .attr("font-size", 10)
      .attr("fill", "grey")
      .text("0.25 s");

    vis.append("line")
      .attr("x1", xRangePlot(4 * Math.PI))
      .attr("y1", yRange(-0.1))
      .attr("x2", xRangePlot(4 * Math.PI))
      .attr("y2", yRange(0))
      .attr("stroke-width", 1.0)
      .attr("stroke", "grey");

    vis.append("text")
      .attr("text-anchor", "middle")
      .attr("x", xRangePlot(4 * Math.PI))
      .attr("y", yRange(-0.3))
      .attr("font-size", 10)
      .attr("fill", "grey")
      .text("0.5 s");

    vis.append("svg:rect")
      .attr("fill", "grey")
      .style("opacity", 0.10)
      .attr("x", xRangePlot(0))
      .attr("y", yRange(2.5))
      .attr("width", xRangePlot(2*Math.PI) - xRangePlot(0))
      .attr("height", yRange(-2.5) - yRange(2.5));

    var sine = d3.svg.line()
      .x(function (d, i) { return xRangePlot(d)})
      .y(function (d, i) {

        return yRange(
           (
             (Math.sin(d) * amplitudes[0])
           + (Math.sin(d * 2) * amplitudes[1])
           + (Math.sin(d * 3) * amplitudes[2])
           + (Math.sin(d * 4) * amplitudes[3])
           + (Math.sin(d * 5) * amplitudes[4])
           )
        );
      });

    function onSine()
    {
      amplitudes[0] = 1.0;
      amplitudes[1] = 0.0;
      amplitudes[2] = 0.0;
      amplitudes[3] = 0.0;
      amplitudes[4] = 0.0;
    }

    function onSquare()
    {
      amplitudes[0] = 1.0;
      amplitudes[1] = 0.0;
      amplitudes[2] = 0.5;
      amplitudes[3] = 0.0;
      amplitudes[4] = 0.25;
    }

    function onSaw()
    {
      amplitudes[0] = 1.0;
      amplitudes[1] = 0.50;
      amplitudes[2] = 0.4;
      amplitudes[3] = 0.0;
      amplitudes[4] = 0.0;
    }

    function onWobble()
    {
      amplitudes[0] = 0.5;
      amplitudes[1] = 0.7;
      amplitudes[2] = 0.3;
      amplitudes[3] = 0.0;
      amplitudes[4] = 0.0;
    }

    onSine();

    d3.select('#phasorbuttons').insert("button")
      .style("height", 25)
      .text("Sine")
      .on("click", onSine);

    d3.select('#phasorbuttons').insert("button")
      .style("height", 25)
      .text("Square")
      .on("click", onSquare);

    d3.select('#phasorbuttons').insert("button")
      .style("height", 25)
      .text("Saw")
      .on("click", onSaw);

    d3.select('#phasorbuttons').insert("button")
      .style("height", 25)
      .text("Wobble")
      .on("click", onWobble);

    var xComponent = 0;
    var yComponent = 0;

    var cosComp = 0;
    var sinComp = 0;

    function draw() {

      cosComp = 0;
      sinComp = 0;

      for (var i = 0; i < 5; i++)
      {
        var xStart = xRange(cosComp);
        var yStart = yRange(sinComp);

        cosComp += Math.cos(time * (i + 1)) * amplitudes[i];
        sinComp += Math.sin(time * (i + 1)) * amplitudes[i];

        xComponent = xRange(cosComp);
        yComponent = yRange(sinComp);

        vectors[i]
          .attr('x1', xStart)
          .attr('y1', yStart)
          .attr('x2', xComponent)
          .attr('y2', yComponent);

        circles[i]
          .attr('cx', xStart)
          .attr('cy', yStart)
          .attr('r', xRange(amplitudes[i]) - xRange(0))
      }

      var leftX = xComponent;//Math.min(xComponent3, xRange(0));

      sineProjection
        .attr('x1', xRangePlot(time))
        .attr('y1', yComponent)
        .attr('x2', leftX)
        .attr('y2', yComponent)

      path
        .attr('d', sine(data));

      traceCircle
        .attr("cx", xRangePlot(time))
        .attr("cy", yComponent);

      time += 0.0125;
      if (time > Math.PI * 6)
      {
        time = 0.0;
      }
    }

    d3.timer(draw, 100);
  })();

  // sigCorrelationInteractive
  (function() {

    var canvasWidth = 590;
    var canvasHeight = 250;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    plotWidth = canvasWidth - MARGINS.left - MARGINS.right,
    plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var subPlotHeight = plotHeight / 3;

    var xRangeCorr = d3.scale.linear().range([MARGINS.left, plotWidth]);
    var yRangeCorr = d3.scale.linear().range([subPlotHeight, MARGINS.top]);

    var yRangeCorr1 = d3.scale.linear().range([subPlotHeight * 2 + 20, subPlotHeight + 20]);
    var yRangeCorr2 = d3.scale.linear().range([subPlotHeight * 3 + 40, subPlotHeight * 2 + 40]);

    xRangeCorr.domain([0, 4 * Math.PI]);
    yRangeCorr.domain([-1.25, 1.25]);
    yRangeCorr1.domain([-1.25, 1.25]);
    yRangeCorr2.domain([-1.25, 1.25]);

    var signalPhase = -1;
    var signalFreq = 1;

    var xAxis = d3.svg.axis()
      .scale(xRangeCorr)
      .tickSize(0)
      .ticks(0)
      .tickSubdivide(true);

    var xAxis1 = d3.svg.axis()
      .scale(xRangeCorr)
      .tickSize(0)
      .ticks(0)
      .tickSubdivide(true);

    var xAxis2 = d3.svg.axis()
      .scale(xRangeCorr)
      .tickSize(0)
      .ticks(0)
      .tickSubdivide(true);

    var vis = d3.select('#sigCorrelationInteractive');

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeCorr(0) + ')')
      .style('opacity', 0.25)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeCorr1(0) + ')')
      .style('opacity', 0.25)
      .call(xAxis1);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeCorr2(0) + ')')
      .style('opacity', 0.25)
      .call(xAxis2);

    var color1 = "black";
    var color2 = "green";
    var color3 = "rgb(86, 60, 50)";

    var corrSigPath1 = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", color1)
      .attr("fill", "none")
      .attr("opacity", 0.4);

    var corrSigPath2 = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", color2)
      .attr("fill", "none")
      .attr("opacity", 0.3);

    var corrSigPath3 = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", color3)
      .attr("fill", color3)
      .attr("fill-opacity", 0.20)
      .attr("opacity", 0.50);

    var corrSig1 = d3.svg.line()
      .x(function (d, i) { return xRangeCorr(d)})
      .y(function (d, i) { return yRangeCorr(inputSignal(d + signalPhase)); });

    var corrSig2 = d3.svg.line()
      .x(function (d, i) { return xRangeCorr(d)})
      .y(function (d, i) { return yRangeCorr1(Math.sin(d * signalFreq)); });

    var corrSig3 = d3.svg.line()
      .x(function (d, i) { return xRangeCorr(d)})
      .y(function (d, i) { return yRangeCorr2(inputSignal(d + signalPhase) * Math.sin(d * signalFreq)); });

    var corrSigData = d3.range(0, 4 * Math.PI, 0.05);

    corrSigPath1.attr("d", corrSig1(corrSigData));
    corrSigPath2.attr("d", corrSig2(corrSigData));
    corrSigPath3.attr("d", corrSig3(corrSigData));

    var corrSigSampleData = d3.range(0, 4 * Math.PI, 4 * Math.PI / 30);

    function inputSignal(d)
    {
      return Math.sin(d)
              + 0.3 * Math.sin(d * 3)
              //+ 0.25 * Math.sin(d * 5)
              //+ 0.10 * Math.sin(d * 10)
              ; 
    }

    var samples1 = vis.selectAll(".point1")
      .data(corrSigSampleData)
      .enter().append("svg:circle")
        .attr("stroke", "none")
        .attr("fill", color1)
        .attr("cx", function(d, i) { return xRangeCorr(d); })
        .attr("cy", function(d, i) { return yRangeCorr(inputSignal(d + signalPhase)); })
        .attr("r", function(d, i) { return 2.0 });

    var samples2 = vis.selectAll(".point2")
      .data(corrSigSampleData)
      .enter().append("svg:circle")
        .attr("stroke", "none")
        .attr("fill", color2)
        .attr("cx", function(d, i) { return xRangeCorr(d); })
        .attr("cy", function(d, i) { return yRangeCorr1(Math.sin(d * signalFreq)); })
        .attr("r", function(d, i) { return 2.0 });

    var connectors = vis.selectAll(".connectors")
      .data(corrSigSampleData)
      .enter().append("line")
        .attr("x1", function(d, i) { return xRangeCorr(d); })
        .attr("y1", function(d, i) { return yRangeCorr(inputSignal(d)); })
        .attr("x2", function(d, i) { return xRangeCorr(d); })
        .attr("y2", function(d, i) { return yRangeCorr2(inputSignal(d + signalPhase) * Math.sin(d * signalFreq)); })
        .attr("stroke-width", 1.0)
        .attr("stroke", "grey")
        .style("opacity", 0.20)
        .style("stroke-dasharray", ("3, 3"))
        ;

    var samples3 = vis.selectAll(".point3")
      .data(corrSigSampleData)
      .enter().append("svg:circle")
        .attr("stroke", "none")
        .attr("fill", color3)
        .attr("cx", function(d, i) { return xRangeCorr(d); })
        .attr("cy", function(d, i) { return yRangeCorr2(inputSignal(d + signalPhase) * Math.sin(d * signalFreq)); })
        .attr("r", function(d, i) { return 2.0 });

    var xRangeDotProduct = d3.scale.linear().range([140, 470]);
    xRangeDotProduct.domain([-20, 20]);

    var xAxisDotProduct = d3.svg.axis()
      .scale(xRangeDotProduct)
      .tickSize(4)
      .ticks(10)
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + (yRangeCorr2(0) + 60) + ')')
      .style('opacity', 0.45)
      .call(xAxisDotProduct);

    var corrText = vis.append('text')
      .attr("text-anchor", "middle")
      .attr("x", xRangeDotProduct(0))
      .attr("y", (yRangeCorr2(0) + 90))
      .attr("stroke", "none")
      .attr("fill", "#555")
      .attr("font-size", 12)
      .attr("font-weight", "bold")
      .text("Dot Product: ");

    vis.append("defs").append("marker")
        .attr("id", "arrowhead")
        .attr("refX", 5)
        .attr("refY", 2)
        .attr("markerWidth", 10)
        .attr("markerHeight", 10)
        .attr("orient", "auto")
        .attr("fill", color3)
        .append("path")
            .attr("d", "M 0,0 V 4 L6,2 Z");

    var dotProductLine = vis.append("line")
      .attr("x1", xRangeDotProduct(0))
      .attr("y1", (yRangeCorr2(0) + 60))
      .attr("x2", xRangeDotProduct(0))
      .attr("y2", (yRangeCorr2(0) + 60))
      .attr("stroke-width", 2)
      .attr("stroke", color3)
      //.attr("marker-end", "url(#arrowhead)")
      ;

    var dotProductCircle = vis.append("svg:circle")
      .attr("cx", xRangeDotProduct(0))
      .attr("cy", (yRangeCorr2(0) + 60))
      .attr("stroke", "#eee")
      .attr("stroke-width", 1.5)
      .attr("fill", color3)
      .attr("r", 3.0);

    var sigText = vis.append('text')
      .attr("text-anchor", "left")
      .attr("x", 0)
      .attr("y", yRangeCorr(0) + 13)
      .attr("stroke", "none")
      .attr("fill", "grey")
      .attr("font-size", 11)
      .text("Signal A");

    var sig2Text = vis.append('text')
      .attr("text-anchor", "left")
      .attr("x", 0)
      .attr("y", yRangeCorr1(0) + 13)
      .attr("stroke", "none")
      .attr("fill", "grey")
      .attr("font-size", 11)
      .text("Signal B");

    var prodText = vis.append('text')
      .attr("text-anchor", "left")
      .attr("x", 0)
      .attr("y", 210)
      .attr("stroke", "none")
      .attr("fill", "grey")
      .attr("font-size", 11)
      .text("A x B");

    var colorScale = d3.scale.category10();
    colorScale.domain[d3.range(0, 10, 1)];

    function draw() {
      if (SQUARE_CORRELATION_OFFSET == signalPhase && SQUARE_CORRELATION_FREQ == signalFreq)
        return;

      signalPhase = SQUARE_CORRELATION_OFFSET;
      signalFreq = SQUARE_CORRELATION_FREQ;

      document.getElementById("squareShift").innerHTML = "Phase Shift: &nbsp; <b>" + (signalPhase * 180 / Math.PI).toFixed(2) + "°</b>";

      samples1.data(corrSigSampleData)
        .attr("cx", function(d, i) { return xRangeCorr(d); })
        .attr("cy", function(d, i) { return yRangeCorr(inputSignal(d + signalPhase)); });
      
      samples2.data(corrSigSampleData)
        .attr("fill", colorScale(signalFreq))
        .attr("cx", function(d, i) { return xRangeCorr(d); })
        .attr("cy", function(d, i) { return yRangeCorr1(Math.sin(d * signalFreq)); });

      samples3.data(corrSigSampleData)
        .attr("cx", function(d, i) { return xRangeCorr(d); })
        .attr("cy", function(d, i) { return yRangeCorr2(inputSignal(d + signalPhase) * Math.sin(d * signalFreq)); });

      connectors.data(corrSigSampleData)
        .attr("x1", function(d, i) { return xRangeCorr(d); })
        .attr("y1", function(d, i) { return yRangeCorr(inputSignal(d + signalPhase)); })
        .attr("x2", function(d, i) { return xRangeCorr(d); })
        .attr("y2", function(d, i) { return yRangeCorr2(inputSignal(d + signalPhase) * Math.sin(d * signalFreq)); });

      corrSigPath1.attr("d", corrSig1(corrSigData));
      corrSigPath2
        .attr("stroke", colorScale(signalFreq))
        .attr("d", corrSig2(corrSigData));
      corrSigPath3.attr("d", corrSig3(corrSigData));

      var dotProduct = 0;
      for (i = 0; i < corrSigSampleData.length; i++)
      {
        var d = corrSigSampleData[i];
        dotProduct += inputSignal(d) * Math.sin(d * signalFreq + signalPhase);
      }

      corrText.text("Dot Product: " + dotProduct.toFixed(2));

      dotProductLine
        .attr("x2", xRangeDotProduct(dotProduct));

      dotProductCircle
        .attr("cx", xRangeDotProduct(dotProduct));
    };

    d3.timer(draw, 100);
  })();
  var SQUARE_CORRELATION_OFFSET     = 0.0;
  function updateSquareCorrelationOffset(value) { SQUARE_CORRELATION_OFFSET = Math.PI * 2 * (value / 100); }
  var SQUARE_CORRELATION_FREQ       = 1.0;

  // autosignal
  (function() {
    var canvasWidth = 600;
    var canvasHeight = 100;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    var vis = d3.select('#autosignal');

    var plotWidth = canvasWidth - MARGINS.left - MARGINS.right;
    var plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var xRangeTime = d3.scale.linear().range([0, canvasWidth]);
    xRangeTime.domain([0, 8 * Math.PI]);

    var yRangeTime = d3.scale.linear().range([canvasHeight, 0]);
    yRangeTime.domain([-1, 1]);

    var data = d3.range(0, 8 * Math.PI, 0.01);

    var signal = d3.svg.line()
      .x(function (d, i) { return xRangeTime(d) + 1; })
      .y(function (d, i) { return yRangeTime((Math.sin(d) + Math.sin(2 * d)) * 0.5)} );

    vis.append("svg:rect")
      .attr("fill", "grey")
      .style("opacity", 0.10)
      .attr("x", 0)
      .attr("y", 0)
      .attr("width", xRangeTime(2*Math.PI))
      .attr("height", yRangeTime(-1) - yRangeTime(1));

    var xAxis = d3.svg.axis()
      .scale(xRangeTime)
      .tickSize(10)
      .tickValues([2*Math.PI, 4*Math.PI, 6*Math.PI, 8*Math.PI])
      .tickFormat(function(d) { return (d / (8*Math.PI)) + " s"; })
      .tickSubdivide(true);

    var yAxis = d3.svg.axis()
      .scale(yRangeTime)
      .tickSize(0)
      .ticks(0)
      .orient('left')
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeTime(0) + ')')
      .style("opacity", 0.35)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'y axis')
      .attr('transform', 'translate(0,0)')
      .style("opacity", 0.35)
      .call(yAxis);

    var path = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", "steelblue")
      .attr("fill", "none")
      .attr("opacity", 1.0)
      .attr("d", signal(data));
  }) ();
  
  // sigCorrelationInteractiveTwoSines
  (function() {

    var vis = d3.select('#sigCorrelationInteractiveTwoSines');

    var signal = [];
    var numPoints = 20;
    for (var i = 0; i < numPoints; i++)
    {
      var phase = (i / numPoints) * 2 * Math.PI;

      signal.push(
        (Math.sin(phase) + Math.sin(2 * phase)) * 0.5
        );
    }

    signal = signal.concat(signal).concat(signal);

    function sigval(index)
    {
      var adjustedIndex = index - signal.length;
      if (adjustedIndex > 0 && adjustedIndex < signal.length)
        { return signal[adjustedIndex]; }
      else
        return 0.0;
    }

    var autocorrelation = [];

    for (var i = 0; i < 120; i++)
    {
      var val = 0;
      for (var j = 0; j < signal.length; j++)
      {
        val += signal[j] * sigval(j + i);
      }

      autocorrelation.push(val);
    }

    autocorrelation.push(0);

    var canvasWidth = 550;
    var canvasHeight = 250;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    plotWidth = canvasWidth - MARGINS.left - MARGINS.right,
    plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var subPlotHeight = plotHeight / 3;

    var xRangeCorr = d3.scale.linear().range([MARGINS.left, plotWidth]);
    var yRangeCorr = d3.scale.linear().range([subPlotHeight, MARGINS.top]);

    var yRangeCorr1 = d3.scale.linear().range([subPlotHeight * 2 + 20, subPlotHeight + 20]);
    var yRangeCorr2 = d3.scale.linear().range([subPlotHeight * 3 + 40, subPlotHeight * 2 + 40]);

    xRangeCorr.domain([0, signal.length * 3]);
    yRangeCorr.domain([-1.0, 1.0]);
    yRangeCorr1.domain([-1.0, 1.0]);
    yRangeCorr2.domain([-15.00, 15.00]);

    vis.append("svg:rect")
      .attr("fill", "grey")
      .style("opacity", 0.10)
      .attr("x", xRangeCorr(signal.length))
      .attr("y", 0)
      .attr("width", xRangeCorr(signal.length) / 3.0)
      .attr("height", 280);

    var lag = 60;

    var xAxis = d3.svg.axis()
      .scale(xRangeCorr)
      .tickSize(0)
      .ticks(0)
      .tickSubdivide(true);

    var xAxis1 = d3.svg.axis()
      .scale(xRangeCorr)
      .tickSize(0)
      .ticks(0)
      .tickSubdivide(true);

    var xAxis2 = d3.svg.axis()
      .scale(xRangeCorr)
      .tickSize(0)
      .ticks(0)
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeCorr(0) + ')')
      .style('opacity', 0.25)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeCorr1(0) + ')')
      .style('opacity', 0.25)
      .call(xAxis1);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeCorr2(0) + ')')
      .style('opacity', 0.25)
      .call(xAxis2);

    var color1 = "steelblue";
    var color2 = "green";
    var color3 = "#8c564b";

    var lag = 0;
    var laggedSamples = [];

    var corrSig1 = d3.svg.line()
      .x(function (d, i) { return xRangeCorr(d + signal.length)})
      .y(function (d, i) { return yRangeCorr(signal[i]); });

    var corrSig2 = d3.svg.line()
      .x(function (d, i) { return xRangeCorr(d + lag)})
      .y(function (d, i) { return yRangeCorr1(signal[i]); });

    var corrSig3 = d3.svg.line()
      .x(function (d, i) { return xRangeCorr(i)})
      .y(function (d, i) { return yRangeCorr2(autocorrelation[i]); });

    var connectors = vis.selectAll(".connectors")
      .data(d3.range(0, signal.length, 1))
      .enter().append("line")
        .attr("x1", function(d, i) { return xRangeCorr(d + lag); })
        .attr("y1", function(d, i) { return yRangeCorr(sigval(d + lag)); })
        .attr("x2", function(d, i) { return xRangeCorr(d + lag); })
        .attr("y2", function(d, i) { return yRangeCorr1(signal[d]); })
        .attr("stroke-width", 1.0)
        .attr("stroke", "grey")
        .style("opacity", 0.20)
        .style("stroke-dasharray", ("5, 2"));

    function drawOriginalSignal()
    { 
      var offset = signal.length;

        vis.append('svg:path')
          .attr("stroke-width", 2.0)
          .attr("stroke", color1)
          .attr("fill", "none")
          .attr("opacity", 0.4)
          .attr("d", corrSig1(d3.range(0, signal.length, 1)));

      for (var i = 0; i < signal.length; i++)
      {
        vis.append("svg:circle")
          .attr("stroke", "none")
          .attr("fill", color1)
          .attr("cx", xRangeCorr(i + offset))
          .attr("cy", yRangeCorr(signal[i]))
          .attr("r", 2.0);
      }
    }

    drawOriginalSignal();

    function drawAutocorrelation()
    { 
        vis.append('svg:path')
          .attr("stroke-width", 2.0)
          .attr("stroke", color3)
          .attr("fill", "none")
          .attr("opacity", 0.4)
          .attr("d", corrSig3(d3.range(0, autocorrelation.length, 1)));

      for (var i = 0; i < autocorrelation.length; i++)
      {
        vis.append("svg:circle")
          .attr("stroke", "none")
          .attr("fill", color3)
          .attr("cx", xRangeCorr(i))
          .attr("cy", yRangeCorr2(autocorrelation[i]))
          .attr("r", 2.0);
      }
    }

    drawAutocorrelation();

    for (var i = 0; i < signal.length; i++)
    {
      laggedSamples.push(
        vis.append("svg:circle")
        .attr("stroke", "none")
        .attr("fill", color2)
        .attr("cx", xRangeCorr(i + lag))
        .attr("cy", yRangeCorr1(signal[i]))
        .attr("r", 2.0));
    }

    var laggedPath = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", color1)
      .attr("fill", "none")
      .attr("opacity", 0.4)
      .attr("d", corrSig2(d3.range(0, signal.length, 1)));

    function updateSignals()
    {
      for (var i = 0; i < laggedSamples.length; i++)
      {
        laggedSamples[i].attr("cx", xRangeCorr(i + lag));
      }

      laggedPath
        .attr("d", corrSig2(d3.range(0, signal.length, 1)));

    }

    var AutoCorrLine = vis.append("line")
      .attr("x1", xRangeCorr(lag))
      .attr("y1", yRangeCorr2(autocorrelation[lag]))
      .attr("x2", xRangeCorr(lag))
      .attr("y2", yRangeCorr(sigval(lag)))
      .attr("stroke-width", 2)
      .attr("stroke", "grey")
      .style("opacity", 0.5)
      //.attr("marker-end", "url(#arrowhead)")
      ;

    var AutoCorrCircle = vis.append("svg:circle")
      .attr("cx", xRangeCorr(lag))
      .attr("cy", yRangeCorr2(autocorrelation[lag]))
      .attr("stroke", "grey")
      .attr("stroke-width", 2.0)
      .attr("fill", "none")
      .attr("r", 4.0);

    var sigText = vis.append('text')
      .attr("text-anchor", "end")
      .attr("x", xRangeCorr(180))
      .attr("y", yRangeCorr(0) + 13)
      .attr("stroke", "none")
      .attr("fill", "#555")
      .attr("font-weight", "bold")
      .attr("font-size", 11)
      .text("Original Waveform, x(n)");

    vis.append("svg:rect")
      .attr("fill", "white")
      .style("opacity", 1.0)
      .attr("x", xRangeCorr(150))
      .attr("y", yRangeCorr1(0) + 2)
      .attr("width", 100)
      .attr("height", 15);

    var sig2Text = vis.append('text')
      .attr("text-anchor", "end")
      .attr("x", xRangeCorr(180))
      .attr("y", yRangeCorr1(0) + 13)
      .attr("stroke", "none")
      .attr("fill", "#555")
      .attr("font-weight", "bold")
      .attr("font-size", 11)
      .text("Lagged Waveform, x(k + t)");

    var prodText = vis.append('text')
      .attr("text-anchor", "end")
      .attr("x", xRangeCorr(180))
      .attr("y", 265)
      .attr("stroke", "none")
      .attr("fill", "#555")
      .attr("font-weight", "bold")
      .attr("font-size", 11)
      .text("Auto Correlation Function");

    var colorScale = d3.scale.category10();
    colorScale.domain[d3.range(0, 10, 1)];

    function draw() {
      if (SIMPLE_CORRELATION_OFFSET == lag)
      {
        return;
      }

      lag = SIMPLE_CORRELATION_OFFSET;

      updateSignals();

      document.getElementById("phaseShift").innerHTML = "Lag: &nbsp; <b>" + (lag - 60).toFixed(0) + "</b>";

      connectors.data(d3.range(0, signal.length, 1))
        .attr("x1", function(d, i) { return xRangeCorr(d + lag); })
        .attr("y1", function(d, i) { return yRangeCorr(sigval(d + lag)); })
        .attr("x2", function(d, i) { return xRangeCorr(d + lag); })
        .attr("y2", function(d, i) { return yRangeCorr1(signal[d]); });

      AutoCorrLine
      .attr("x1", xRangeCorr(lag))
      .attr("y1", yRangeCorr2(autocorrelation[lag]))
      .attr("x2", xRangeCorr(lag))
      .attr("y2", yRangeCorr(sigval(lag)))
      //.attr("marker-end", "url(#arrowhead)")
      ;

      AutoCorrCircle
      .attr("cx", xRangeCorr(lag))
      .attr("cy", yRangeCorr2(autocorrelation[lag]));
    }

    d3.timer(draw, 100);
  }) ();
  var SIMPLE_CORRELATION_OFFSET = 0.0;
  function updateSimpleCorrelationOffset(value) { SIMPLE_CORRELATION_OFFSET = value * 1.0; }

  // autocorrelationinterpretation
  (function() {

    var autocorrelation =
    [
    0,
    0,
     -0.20106356740693337,
     -0.6900183776675255,
     -1.3812274365218544,
     -2.044255694669431,
     -2.4068828084493017,
     -2.2865494441493777,
     -1.6878630685231943,
     -0.8169335313590205,
     0,
     0.4618347265585053,
     0.4378630685231944,
     0.044543827480826276,
     -0.388202163425436,
     -0.45574430533056925,
     0.1312274365218541,
     1.3869390224613396,
     2.9961485392816702,
     4.400183776675253,
     5.000000000000001,
     4.400183776675253,
     2.5940214044678034,
     0.006902267126288608,
     -2.6312274365218546,
     -4.544255694669432,
     -5.20196778032404,
     -4.528555060817929,
     -2.937863068523195,
     -1.1720323361595355,
     0,
     0.10673592175799038,
     -0.8121369314768054,
     -2.1974617891877255,
     -3.183287135300174,
     -2.9557443053305694,
     -1.118772563478146,
     2.0838596672551537,
     5.791233511156407,
     8.800367553350505,
     10.000000000000002,
     8.800367553350505,
     5.38910637634254,
     0.7038229119201027,
     -3.8812274365218546,
     -7.044255694669432,
     -7.997052752198776,
     -6.770560677486481,
     -4.1878630685231935,
     -1.5271311409600505,
     0,
     -0.24836288304252463,
     -2.0621369314768057,
     -4.439467405856277,
     -5.978372107174911,
     -5.45574430533057,
     -2.368772563478146,
     2.7807803120489676,
     8.586318483031143,
     13.200551330025757,
     15.000000000000002,
     13.200551330025757,
     8.586318483031143,
     2.7807803120489676,
     -2.368772563478146,
     -5.45574430533057,
     -5.978372107174911,
     -4.439467405856277,
     -2.0621369314768057,
     -0.24836288304252463,
     0,
     -1.5271311409600505,
     -4.1878630685231935,
     -6.770560677486481,
     -7.997052752198776,
     -7.044255694669432,
     -3.8812274365218546,
     0.7038229119201027,
     5.38910637634254,
     8.800367553350505,
     10.000000000000002,
     8.800367553350505,
     5.791233511156407,
     2.0838596672551537,
     -1.118772563478146,
     -2.9557443053305694,
     -3.183287135300174,
     -2.1974617891877255,
     -0.8121369314768054,
     0.10673592175799038,
     0,
     -1.1720323361595355,
     -2.937863068523195,
     -4.528555060817929,
     -5.20196778032404,
     -4.544255694669432,
     -2.6312274365218546,
     0.006902267126288608,
     2.5940214044678034,
     4.400183776675253,
     5.000000000000001,
     4.400183776675253,
     2.9961485392816702,
     1.3869390224613396,
     0.1312274365218541,
     -0.45574430533056925,
     -0.388202163425436,
     0.044543827480826276,
     0.4378630685231944,
     0.4618347265585053,
     0,
     -0.8169335313590205,
     -1.6878630685231943,
     -2.2865494441493777,
     -2.4068828084493017,
     -2.044255694669431,
     -1.3812274365218544,
     -0.6900183776675255,
     -0.20106356740693337,
     0,
     0
    ]; 

    var canvasWidth = 600;
    var canvasHeight = 150;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    var vis = d3.select('#autocorrelationinterpretation');

    var plotWidth = canvasWidth - MARGINS.left - MARGINS.right;
    var plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var xRangeTime = d3.scale.linear().range([0, canvasWidth]);
    xRangeTime.domain([0, autocorrelation.length]);

    var yRangeTime = d3.scale.linear().range([canvasHeight, 0]);
    yRangeTime.domain([-18, 18]);

    var data = autocorrelation;

    var signal = d3.svg.line()
      .x(function (d, i) { return xRangeTime(i); })
      .y(function (d, i) { return yRangeTime(d); });

    vis.append("svg:rect")
      .attr("fill", "grey")
      .style("opacity", 0.10)
      .attr("x", xRangeTime(data.length / 2 - 0.5 ))
      .attr("y", 0)
      .attr("width", xRangeTime(data.length / 6))
      .attr("height", yRangeTime(-15) - yRangeTime(15));

    var xAxis = d3.svg.axis()
      .scale(xRangeTime)
      .tickSize(10)
      .tickValues([20, 40, 60, 80, 100])
      .tickFormat(function(d) { return ((d / (120)) * 1.5 - 0.75).toFixed(2) + " s"; })
      .tickSubdivide(true);

    var yAxis = d3.svg.axis()
      .scale(yRangeTime)
      .tickSize(0)
      .ticks(0)
      .orient('left')
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeTime(0) + ')')
      .style("opacity", 0.35)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'y axis')
      .attr('transform', 'translate(0,0)')
      .style("opacity", 0.35)
      .call(yAxis);

    var path = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", "#8c564b")
      .attr("fill", "none")
      .attr("opacity", 0.5)
      .attr("d", signal(data));

    for (var i = 0; i < autocorrelation.length; i++)
    {
      vis.append("svg:circle")
          .attr("stroke", "none")
          .attr("fill", "#8c564b")
          .attr("cx", xRangeTime(i))
          .attr("cy", yRangeTime(autocorrelation[i]))
          .attr("r", 2.5);  
    }

    vis.append("defs").append("marker")
        .attr("id", "arrowhead")
        .attr("refX", 5)
        .attr("refY", 2)
        .attr("markerWidth", 10)
        .attr("markerHeight", 10)
        .attr("orient", "auto")
        .attr("fill", "black")
        .append("path")
            .attr("d", "M 0,0 V 4 L6,2 Z");

    vis.append("line")
      .attr("x1", xRangeTime(data.length / 2 + 9))
      .attr("y1", yRangeTime(15))
      .attr("x2", xRangeTime(data.length / 2 + 1))
      .attr("y2", yRangeTime(15))
      .attr("stroke-width", 2)
      .attr("stroke", "black")
      .style("opacity", 0.25)
      .attr("marker-end", "url(#arrowhead)");

    vis.append("line")
      .attr("x1", xRangeTime(data.length / 2 + 9))
      .attr("y1", yRangeTime(15))
      .attr("x2", xRangeTime(data.length / 2 - 0.5) + xRangeTime(data.length / 6 - 1))
      .attr("y2", yRangeTime(15))
      .attr("stroke-width", 2)
      .attr("stroke", "black")
      .style("opacity", 0.25)
      .attr("marker-end", "url(#arrowhead)");

    vis.append("svg:circle")
      .attr("stroke", "grey")
      .attr("stroke-width", 2)
      .attr("fill", "none")
      .attr("cx", xRangeTime(60))
      .attr("cy", yRangeTime(autocorrelation[60]))
      .attr("r", 4.5); 

    vis.append("svg:circle")
      .attr("stroke", "grey")
      .attr("stroke-width", 2)
      .attr("fill", "none")
      .attr("cx", xRangeTime(80))
      .attr("cy", yRangeTime(autocorrelation[80]))
      .attr("r", 4.5);
  })();

  // Buffer 1
  (function() {
    var longsignal = []; 

    for (var i = 0; i < 128; i++)
    {
      var phase = (i / 128) * 4 * Math.PI;
      longsignal.push(Math.sin(phase));
    }

    var canvasWidth = 600;
    var canvasHeight = 100;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    var vis = d3.select('#buffer1');

    var plotWidth = canvasWidth - MARGINS.left - MARGINS.right;
    var plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var xRangeTime = d3.scale.linear().range([0, canvasWidth]);
    xRangeTime.domain([0, longsignal.length]);

    var yRangeTime = d3.scale.linear().range([canvasHeight, 0]);
    yRangeTime.domain([-1.6, 1.6]);

    var data = longsignal;

    var signal = d3.svg.line()
      .x(function (d, i) { return xRangeTime(i); })
      .y(function (d, i) { return yRangeTime(d); });

    vis.append("svg:rect")
      .attr("fill", "grey")
      .style("opacity", 0.10)
      .attr("x", xRangeTime(0))
      .attr("y", 0)
      .attr("width", xRangeTime(data.length / 4))
      .attr("height", 120);

    var xAxis = d3.svg.axis()
      .scale(xRangeTime)
      .tickSize(10)
      .tickValues([16, 32, 48, 64, 80, 96, 112, 128, 144, 160])
      .tickFormat(function(d) { return ((d / (data.length))).toFixed(2) + " s"; })
      .tickSubdivide(true);

    var yAxis = d3.svg.axis()
      .scale(yRangeTime)
      .tickSize(0)
      .ticks(0)
      .orient('left')
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeTime(0) + ')')
      .style("opacity", 0.35)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'y axis')
      .attr('transform', 'translate(0,0)')
      .style("opacity", 0.35)
      .call(yAxis);

    var path = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", " steelblue")
      .attr("fill", "none")
      .attr("opacity", 0.3)
      .attr("d", signal(data));

    for (var i = 0; i < data.length / 4; i++)
    {
      vis.append("svg:circle")
          .attr("stroke", "none")
          .attr("fill", " steelblue")
          .attr("cx", xRangeTime(i))
          .attr("cy", yRangeTime(data[i]))
          .attr("r", 2.5);  
    }

    vis.append('text')
      .attr("text-anchor", "middle")
      .attr("x", xRangeTime(16))
      .attr("y", 12)
      .attr("stroke", "none")
      .attr("fill", "#555")
      .attr("font-size", 12)
      .attr("font-weight", "bold")
      .text("First Input Buffer");
  })();

  // Buffer 2
  (function() {

    var longsignal = []; 

    for (var i = 0; i < 128; i++)
    {
      var phase = (i / 128) * 4 * Math.PI;
      longsignal.push(Math.sin(phase));
    }

    var canvasWidth = 600;
    var canvasHeight = 100;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    var vis = d3.select('#buffer2');

    var plotWidth = canvasWidth - MARGINS.left - MARGINS.right;
    var plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var xRangeTime = d3.scale.linear().range([0, canvasWidth]);
    xRangeTime.domain([0, longsignal.length]);

    var yRangeTime = d3.scale.linear().range([canvasHeight, 0]);
    yRangeTime.domain([-1.6, 1.6]);

    var data = longsignal;

    var signal = d3.svg.line()
      .x(function (d, i) { return xRangeTime(i); })
      .y(function (d, i) { return yRangeTime(d); });

    vis.append("svg:rect")
      .attr("fill", "grey")
      .style("opacity", 0.10)
      .attr("x", xRangeTime(32))
      .attr("y", 0)
      .attr("width", xRangeTime(data.length / 4))
      .attr("height", 120);

    var xAxis = d3.svg.axis()
      .scale(xRangeTime)
      .tickSize(10)
      .tickValues([16, 32, 48, 64, 80, 96, 112, 128, 144, 160])
      .tickFormat(function(d) { return ((d / (data.length))).toFixed(2) + " s"; })
      .tickSubdivide(true);

    var yAxis = d3.svg.axis()
      .scale(yRangeTime)
      .tickSize(0)
      .ticks(0)
      .orient('left')
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeTime(0) + ')')
      .style("opacity", 0.35)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'y axis')
      .attr('transform', 'translate(0,0)')
      .style("opacity", 0.35)
      .call(yAxis);

    var path = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", " steelblue")
      .attr("fill", "none")
      .attr("opacity", 0.3)
      .attr("d", signal(data));

    for (var i = 0; i < data.length / 2; i++)
    {
      vis.append("svg:circle")
          .attr("stroke", "none")
          .attr("fill", " steelblue")
          .attr("cx", xRangeTime(i))
          .attr("cy", yRangeTime(data[i]))
          .attr("r", 2.5);  
    }

    vis.append('text')
      .attr("text-anchor", "middle")
      .attr("x", xRangeTime(48))
      .attr("y", 12)
      .attr("stroke", "none")
      .attr("fill", "#555")
      .attr("font-size", 12)
      .attr("font-weight", "bold")
      .text("Second Input Buffer");
  })();

  // Buffer 3
  (function() {

    var longsignal = []; 

    for (var i = 0; i < 128; i++)
    {
      var phase = (i / 128) * 4 * Math.PI;
      longsignal.push(Math.sin(phase));
    }

    var canvasWidth = 600;
    var canvasHeight = 100;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    var vis = d3.select('#buffer3');

    var plotWidth = canvasWidth - MARGINS.left - MARGINS.right;
    var plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var xRangeTime = d3.scale.linear().range([0, canvasWidth]);
    xRangeTime.domain([0, longsignal.length]);

    var yRangeTime = d3.scale.linear().range([canvasHeight, 0]);
    yRangeTime.domain([-1.6, 1.6]);

    var data = longsignal;

    var signal = d3.svg.line()
      .x(function (d, i) { return xRangeTime(i); })
      .y(function (d, i) { return yRangeTime(d); });

    vis.append("svg:rect")
      .attr("fill", "grey")
      .style("opacity", 0.10)
      .attr("x", xRangeTime(64))
      .attr("y", 0)
      .attr("width", xRangeTime(data.length / 4))
      .attr("height", 120);

    var xAxis = d3.svg.axis()
      .scale(xRangeTime)
      .tickSize(10)
      .tickValues([16, 32, 48, 64, 80, 96, 112, 128, 144, 160])
      .tickFormat(function(d) { return ((d / (data.length))).toFixed(2) + " s"; })
      .tickSubdivide(true);

    var yAxis = d3.svg.axis()
      .scale(yRangeTime)
      .tickSize(0)
      .ticks(0)
      .orient('left')
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeTime(0) + ')')
      .style("opacity", 0.35)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'y axis')
      .attr('transform', 'translate(0,0)')
      .style("opacity", 0.35)
      .call(yAxis);

    var path = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", " steelblue")
      .attr("fill", "none")
      .attr("opacity", 0.3)
      .attr("d", signal(data));

    for (var i = 0; i < 96; i++)
    {
      vis.append("svg:circle")
          .attr("stroke", "none")
          .attr("fill", " steelblue")
          .attr("cx", xRangeTime(i))
          .attr("cy", yRangeTime(data[i]))
          .attr("r", 2.5);  
    }

    vis.append('text')
      .attr("text-anchor", "middle")
      .attr("x", xRangeTime(80))
      .attr("y", 12)
      .attr("stroke", "none")
      .attr("fill", "#555")
      .attr("font-size", 12)
      .attr("font-weight", "bold")
      .text("Third Input Buffer");
  })();
  
  // Buffer 4
  (function() {

    var longsignal = []; 

    for (var i = 0; i < 128; i++)
    {
      var phase = (i / 128) * 4 * Math.PI;
      longsignal.push(Math.sin(phase));
    }

    var canvasWidth = 600;
    var canvasHeight = 100;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    var vis = d3.select('#buffer4');

    var plotWidth = canvasWidth - MARGINS.left - MARGINS.right;
    var plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var xRangeTime = d3.scale.linear().range([0, canvasWidth]);
    xRangeTime.domain([0, longsignal.length]);

    var yRangeTime = d3.scale.linear().range([canvasHeight, 0]);
    yRangeTime.domain([-1.6, 1.6]);

    var data = longsignal;

    var signal = d3.svg.line()
      .x(function (d, i) { return xRangeTime(i); })
      .y(function (d, i) { return yRangeTime(d); });

    vis.append("svg:rect")
      .attr("fill", "grey")
      .style("opacity", 0.10)
      .attr("x", xRangeTime(96))
      .attr("y", 0)
      .attr("width", xRangeTime(data.length / 4))
      .attr("height", 120);

    var xAxis = d3.svg.axis()
      .scale(xRangeTime)
      .tickSize(10)
      .tickValues([16, 32, 48, 64, 80, 96, 112, 128, 144, 160])
      .tickFormat(function(d) { return ((d / (data.length))).toFixed(2) + " s"; })
      .tickSubdivide(true);

    var yAxis = d3.svg.axis()
      .scale(yRangeTime)
      .tickSize(0)
      .ticks(0)
      .orient('left')
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeTime(0) + ')')
      .style("opacity", 0.35)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'y axis')
      .attr('transform', 'translate(0,0)')
      .style("opacity", 0.35)
      .call(yAxis);

    var path = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", " steelblue")
      .attr("fill", "none")
      .attr("opacity", 0.3)
      .attr("d", signal(data));

    for (var i = 0; i < data.length; i++)
    {
      vis.append("svg:circle")
          .attr("stroke", "none")
          .attr("fill", " steelblue")
          .attr("cx", xRangeTime(i))
          .attr("cy", yRangeTime(data[i]))
          .attr("r", 2.5);  
    }

    vis.append('text')
      .attr("text-anchor", "middle")
      .attr("x", xRangeTime(112))
      .attr("y", 12)
      .attr("stroke", "none")
      .attr("fill", "#555")
      .attr("font-size", 12)
      .attr("font-weight", "bold")
      .text("Fourth Input Buffer");
  })();
  
  // Buffer 5
  (function() {

    var longsignal = []; 

    for (var i = 0; i < 128; i++)
    {
      var phase = (i / 128) * 4 * Math.PI;
      longsignal.push(Math.sin(4 * phase));
    }

    var canvasWidth = 600;
    var canvasHeight = 100;
    var MARGINS =
      {
        top: 0,
        right: 0,
        bottom: 0,
        left: 0
      };

    var vis = d3.select('#buffer5');

    var plotWidth = canvasWidth - MARGINS.left - MARGINS.right;
    var plotHeight = canvasHeight - MARGINS.top - MARGINS.bottom;

    var xRangeTime = d3.scale.linear().range([0, canvasWidth]);
    xRangeTime.domain([0, longsignal.length]);

    var yRangeTime = d3.scale.linear().range([canvasHeight, 0]);
    yRangeTime.domain([-1.6, 1.6]);

    var data = longsignal;

    var signal = d3.svg.line()
      .x(function (d, i) { return xRangeTime(i); })
      .y(function (d, i) { return yRangeTime(d); });

    vis.append("svg:rect")
      .attr("fill", "grey")
      .style("opacity", 0.10)
      .attr("x", xRangeTime(0))
      .attr("y", 0)
      .attr("width", xRangeTime(data.length / 4))
      .attr("height", 120);

    var xAxis = d3.svg.axis()
      .scale(xRangeTime)
      .tickSize(10)
      .tickValues([16, 32, 48, 64, 80, 96, 112, 128, 144, 160])
      .tickFormat(function(d) { return ((d / (data.length))).toFixed(2) + " s"; })
      .tickSubdivide(true);

    var yAxis = d3.svg.axis()
      .scale(yRangeTime)
      .tickSize(0)
      .ticks(0)
      .orient('left')
      .tickSubdivide(true);

    vis.append('svg:g')
      .attr('class', 'x axis')
      .attr('transform', 'translate(0,' + yRangeTime(0) + ')')
      .style("opacity", 0.35)
      .call(xAxis);

    vis.append('svg:g')
      .attr('class', 'y axis')
      .attr('transform', 'translate(0,0)')
      .style("opacity", 0.35)
      .call(yAxis);

    var path = vis.append('svg:path')
      .attr("stroke-width", 2.0)
      .attr("stroke", "grey")
      .attr("fill", "none")
      .attr("opacity", 0.3)
      .attr("d", signal(data));

    for (var i = 0; i < data.length / 4; i++)
    {
      vis.append("svg:circle")
          .attr("stroke", "none")
          .attr("fill", "grey")
          .attr("cx", xRangeTime(i))
          .attr("cy", yRangeTime(data[i]))
          .attr("r", 2.5);  
    }

    vis.append('text')
      .attr("text-anchor", "middle")
      .attr("x", xRangeTime(16))
      .attr("y", 12)
      .attr("stroke", "none")
      .attr("fill", "#555")
      .attr("font-size", 12)
      .attr("font-weight", "bold")
      .text("First Input Buffer");
  })();
</script>

[^1a]: Monophonic pitch tracking is a useful technique to have in your signal processing toolkit. It lies at the heart of applied products like [Auto-Tune](http://en.wikipedia.org/wiki/Auto-Tune), games like "Rock Band," guitar and instrument tuners, music transcription programs, audio-to-MIDI conversion software, and query-by-humming applications.

[^1b]: Every year, the best audio signal processing researchers algorithmically battle it out in the [MIREX](http://www.music-ir.org/mirex/wiki/MIREX_HOME) (Music Information Retrieval Evaluation eXchange) competition. Researchers from around the world submit algorithms designed to automatically transcribe, tag, segment, and classify recorded musical performances. If you become enthralled with the topic of audio signal processing after reading this article, you might want to submit an algorithm to the 2015 MIREX "K-POP Mood Classification" competition round. If cover bands are more your thing, you might instead choose to submit an algorithm that can identify the original title from a recording of a cover band in the "Audio Cover Song Identification" competition (this is much more difficult than you might expect).

[^1c]: I'm not sure if such a thing has been attempted, but I think an interesting weekend could be spent applying techniques in computer vision to the problem of pitch detection and automatic music transcription.

[^1d]: It's baffling to me why young students aren't shown the beautiful correspondence between circular movement and the trigonometric functions in early education. I think that most students first encounter sine and cosine in relation to right triangles, and this is an unfortunate constriction of a more generally beautiful and harmonious way of thinking about these functions.

[^1e]: You may be wondering if adding additional tones to a fundamental makes the resulting sound polyphonic. In the introductory section, I made a big fuss about excluding polyphonic signals from our allowed input, and now I'm asking you to consider waveforms that consist of many individual tones. As it turns out, pretty much every musical note is composed of a fundamental and [overtones](http://en.wikipedia.org/wiki/Overtone). Polyphony occurs only when you have _multiple fundamental_ frequencies present in a sound signal. I've written a bit about this topic [here](http://jackschaedler.github.io/circles-sines-signals/sound2.html) if you want to learn more.

[^1f]: It's actually often the case that the fundamental frequency of a given note is quieter than its overtones. In fact, humans are able to perceive fundamental frequencies that do not even exist. This curious phenomenon is known as the ["Missing Fundamental"](http://en.wikipedia.org/wiki/Missing_fundamental) problem.

[^1g]: The autocorrelation can be computed using an FFT and IFFT pair. In order to compute the style of autocorrelation shown in this article (linear autocorrelation), you must first [zero-pad](http://jackschaedler.github.io/circles-sines-signals/zeropadding.html) your signal by a factor of two before performing the FFT (if you fail to zero-pad the signal, you will end up implementing a so-called _circular_ autocorrelation). The formula for the linear autocorrelation can be expressed like this in MATLAB or Octave: `linear_autocorrelation = ifft(abs(fft(signal)) .^ 2);`

[^1h]: This sample rate would be ridiculous for audio. I'm using it as a toy example because it makes for easy visualizations. The normal sampling rate for audio is 44,000 hertz. In fact, throughout this whole article I've chosen frequencies and sample rates that make for easy visualizing.

---
title:  "Functional Signal Processing Using Swift"
category: "24"
date: "2015-05-11 10:00:00"
tags: article
author: "<a href=\"https://twitter.com/liscio\">Chris Liscio</a>"
---

As a long-time Core Audio programmer, Apple's introduction of Swift left me both excited and confused. I was excited by the prospect of a modern language built with performance in mind, but I wasn't entirely sure how functional programming could apply to "my world." Fortunately for me, many have [explored and conquered][faust] this problem set already, so I decided to apply some of what I learned from those projects to the Swift programming language.

Signals
-------

The basic unit of signal processing is, of course, a signal. In Swift, I would declare a signal as follows:

```swift
public typealias Signal = Int -> SampleType
```

You can think of the `Signal` type as a discrete function in time that returns the value of the signal at that instant in time. In most signal processing texts, this is often denoted as `x[t]`, so it fits my world view.

Let's define a sine wave at a given frequency:

```swift
public func sineWave(sampleRate: Int, frequency: ParameterType) -> Signal {
    let phi = frequency / ParameterType(sampleRate)
    return { i in
        return SampleType(sin(2.0 * ParameterType(i) * phi * ParameterType(M_PI)))
    }
}
```

The `sineWave` function returns a `Signal`, which itself is a function that converts sample indices into output samples. I refer to these "inputless" signals as generators, since they generate signals out of nothing. 

But I thought we were talking about signal _processing_? How do we modify a signal?

No high-level discussion about signal processing would be complete without demonstrating the application of gain (or a volume control):

```swift
public func scale(s: Signal, amplitude: ParameterType) -> Signal {
    return { i in
            return SampleType(s(i) * SampleType(amplitude))
    }
}
```

The `scale` function takes an input `Signal` called `s`, and returns a new `Signal` with the scalar applied. Every call to the `scale`d signal would return the same output of `s(i)`, scaled by the supplied `amplitude`. Pretty straightforward stuff, right? Well, you can only go so far with this construct before it starts to get messy. Consider the following:

```swift
public func mix(s1: Signal, s2: Signal) -> Signal {
    return { i in
        return s1(i) + s2(i)
    }
}
```

This allows us to compose two signals down to a single signal. We can even compose arbitrary signals:

```swift
public func mix(signals: [Signal]) -> Signal {
    return { i in
        return signals.reduce(SampleType(0)) { $0 + $1(i) }
    }
}
```

This can get us pretty far; however, a `Signal` is limited to a single "channel" of audio, and certain audio effects require much more complex combinations of operations to happen at once.

Processing Blocks
-----------------

What if we were able to make connections between signals and processors in a more flexible way, matching up more closely with the way we think about signal processing? There are popular environments, such as [Max][max] and [PureData][pd], which compose signal processing "blocks" to create powerful sound effects and performance tools.

[Faust][faust] is a functional programming language that was designed with this idea in mind, and it is an incredibly powerful tool for building highly complex (and performant!) signal processing code. Faust defines a set of operators that allows you to compose blocks (or processors) together in a way that mimics signal flow diagrams.

Similarly, I have created an environment that effectively works the same way.

Using our earlier definition of `Signal`, we can expand on this concept:

```swift
public protocol BlockType {
    typealias SignalType
    var inputCount: Int { get }
    var outputCount: Int { get }
    var process: [SignalType] -> [SignalType] { get }
                        
    init(inputCount: Int, outputCount: Int, process: [SignalType] -> [SignalType])
}
```

A `Block` has a number of inputs, a number of outputs, and a `process` function that transforms the `Signal`s on its inputs to a set of `Signal`s on its outputs. Blocks can have zero or more inputs, and zero or more outputs.

To compose blocks serially, you could do the following:

```swift
public func serial<B: BlockType>(lhs: B, rhs: B) -> B {
    return B(inputCount: lhs.inputCount, outputCount: rhs.outputCount, process: { inputs in
        return rhs.process(lhs.process(inputs))
    })
}
```

This function effectively takes the output of the `lhs` block as the input to the `rhs` block and returns the result. It's like connecting a wire between two blocks. Things get a little more interesting when you run blocks in parallel:

```swift
public func parallel<B: BlockType>(lhs: B, rhs: B) -> B {
    let totalInputs = lhs.inputCount + rhs.inputCount
    let totalOutputs = lhs.outputCount + rhs.outputCount
                
    return B(inputCount: totalInputs, outputCount: totalOutputs, process: { inputs in
        var outputs: [B.SignalType] = []
                                    
        outputs += lhs.process(Array(inputs[0..<lhs.inputCount]))
        outputs += rhs.process(Array(inputs[lhs.inputCount..<lhs.inputCount+rhs.inputCount]))
                                                            
        return outputs
    })
}
```

A pair of blocks running in parallel combines inputs and outputs to create a larger block. Consider a pair of `Block`s that produces sine waves together to create a [DTMF tone][dtmf], or a stereo delay `Block` that is a composition of two single-channel delay `Block`s. This concept can be quite powerful in practice.

But what about a mixer? How would we achieve a single-channel result from multiple inputs? We can merge blocks together using the following function:

```swift
public func merge<B: BlockType where B.SignalType == Signal>(lhs: B, rhs: B) -> B {
    return B(inputCount: lhs.inputCount, outputCount: rhs.outputCount, process: { inputs in
        let leftOutputs = lhs.process(inputs)
        var rightInputs: [B.SignalType] = []

        let k = lhs.outputCount / rhs.inputCount
        for i in 0..<rhs.inputCount  {
            var inputsToSum: [B.SignalType] = []
            for j in 0..<k {
                inputsToSum.append(leftOutputs[i+(rhs.inputCount*j)])
            }
            let summed = inputsToSum.reduce(NullSignal) { mix($0, $1) }
            rightInputs.append(summed)
        }

        return rhs.process(rightInputs)
    })
}
```

To borrow convention from Faust, inputs are multiplexed such that the inputs of the right-hand side block come from outputs on the left-hand side modulo the number of inputs. For instance, three stereo tracks with a total of six channels would go into a stereo output block such that output channels 0, 2, and 4 are mixed (i.e. added) into input channel 0, and 1, 3, and 5 are mixed into input channel 1.

Similarly, you can do the opposite and split the outputs of a block:

```swift
public func split<B: BlockType>(lhs: B, rhs: B) -> B {
    return B(inputCount: lhs.inputCount, outputCount: rhs.outputCount, process: { inputs in
        let leftOutputs = lhs.process(inputs)
        var rightInputs: [B.SignalType] = []
        
        // Replicate the channels from the lhs to each of the inputs
        let k = lhs.outputCount
        for i in 0..<rhs.inputCount {
            rightInputs.append(leftOutputs[i%k])
        }
        
        return rhs.process(rightInputs)
    })
}
```

Again, a similar convention is used with the outputs such that one stereo block being fed into three stereo blocks (accepting six total channels) would result in channel 0 going into the inputs 0, 2, and 4, with channel 1 going into inputs 1, 3, and 5.

Of course, we don't want to get stuck with having to write all of this with long-hand functions, so I came up with this collection of operators:

```swift
// Parallel
public func |-<B: BlockType>(lhs: B, rhs: B) -> B

// Serial
public func --<B: BlockType>(lhs: B, rhs: B) -> B

// Split
public func -<<B: BlockType>(lhs: B, rhs: B) -> B

// Merge
public func >-<B: BlockType where B.SignalType == Signal>(lhs: B, rhs: B) -> B
```

(I'm not quite happy with the "Parallel" operator definition, as it looks an awful lot like the symbol for "Perpendicular" in geometry, but I digress. Feedback is obviously welcome.)

Now, with these operators, you can build some interesting "graphs" of blocks and compose them together. For instance, consider this [DTMF tone][dtmf] generator:

```swift
let dtmfFrequencies = [
    ( 941.0, 1336.0 ),
    
    ( 697.0, 1209.0 ),
    ( 697.0, 1336.0 ),
    ( 697.0, 1477.0 ),
    
    ( 770.0, 1209.0 ),
    ( 770.0, 1336.0 ),
    ( 770.0, 1477.0 ),
    
    ( 852.0, 1209.0 ),
    ( 852.0, 1336.0 ),
    ( 852.0, 1477.0 ),
]

func dtmfTone(digit: Int, sampleRate: Int) -> Block {
    assert( digit < dtmfFrequencies.count )
    let (f1, f2) = dtmfFrequencies[digit]
    
    let f1Block = Block(inputCount: 0, outputCount: 1, process: { _ in [sineWave(sampleRate, f1)] })
    let f2Block = Block(inputCount: 0, outputCount: 1, process: { _ in [sineWave(sampleRate, f2)] })
    
    return ( f1Block |- f2Block ) >- Block(inputCount: 1, outputCount: 1, process: { return $0 })
}
```

The `dtmfTone` function runs two parallel sine generators and merges them into an "identity block," which just copies its input to its output. Remember, the return value of this function is itself a block, so you could now reference this block as part of a larger system.

As you can see, there is a lot of potential in this idea. By creating an environment in which we can build and describe increasingly complex systems with a more compact and understandable DSL (domain specific language), we can spend less time worrying about the details of each individual block and how everything fits together.

Practicality
------------

If I were starting a project today that required the best possible performance and most rich set of functionality, I would run straight to [Faust][faust] to get going. I highly recommend that you spend some time with Faust if you are interested in pursuing this idea of functional audio programming.

With that said, the practicality of my ideas above rests heavily on Apple's ability to advance its compiler such that it can identify patterns in the blocks we define and turn them into smarter output code. Effectively, Apple needs to get Swift compiling more like Haskell does, where functional programming patterns can be collapsed down into vectorized operations on a given target CPU.

Frankly, I feel that Swift is in the right hands at Apple and we will see the powerful kinds of ideas I presented above become commonplace and performant in the future.

Future Work
-----------

I will keep this "Functional DSP" project up at GitHub if you would like to follow along or contribute ideas as I play around with the concepts. I plan to investigate more complex blocks, such as those that require FFTs to calculate their output, or blocks that require "memory" in order to operate (such as FIR filters, etc.)

Bibliography
------------

While writing this article, I stumbled upon the following papers that I recommend you delve further into if you are interested in this area of research. There are many more out there, but in the limited time I had, these seemed like really good starting points.

* Thielemann, H. (2004). Audio Processing using Haskell.
* Cheng, E., & Hudak, P. (2009). Audio Processing and Sound Synthesis in Haskell.


[faust]: http://sourceforge.net/projects/faudiostream/
[max]: https://cycling74.com/products/max/
[pd]: http://puredata.info
[dtmf]: http://en.wikipedia.org/wiki/Dual-tone_multi-frequency_signaling

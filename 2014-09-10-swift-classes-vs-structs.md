---
layout: post
title:  "A Warm Welcome to Structs and Value Types"
category: "16"
date: "2014-09-10 10:00:00"
author: "<a href=\"https://twitter.com/andy_matuschak\">Andy Matuschak</a>"
tags: article
---


If you've stuck to Objective-C, and languages like Ruby, Python, or JavaScript, the prominence of structs in Swift might seem especially alien. Classes are the traditional unit of structure in object-oriented languages. Indeed, in contrast to structs, Swift classes support implementation inheritance, (limited) reflection, deinitializers, and multiple owners.

If classes are so much more powerful than structs, why use structs? Well, it's exactly their limited scope that makes them such flexible building blocks. In this article, you'll learn how structs and other value types can radically improve your code's clarity, flexibility, and reliability.

## Value Types and Reference Types

A small distinction in behavior drives the architectural possibilities at play here: structs are *value types* and classes are *reference types*.

Instances of value types are copied whenever they're assigned or used as a function argument. Numbers, strings, arrays, dictionaries, enums, tuples, and structs are value types. For example:

```swift
var a = "Hello"
var b = a
b.extend(", world")
println("a: \(a); b: \(b)") // a: Hello; b: Hello, world
```

Instances of reference types (chiefly: classes) can have multiple owners. When assigning a reference to a new variable or passing it to a function, those locations all point to the same instance. This is the behavior you're used to with objects. For instance:

```swift
var a = UIView()
var b = a
b.alpha = 0.5
println("a: \(a.alpha); b: \(b.alpha)") // a: 0.5; b: 0.5
```

The distinction between these two categories seems small, but the choice between values and references can have huge ramifications for your system's architecture.

### Building Our Intuition

Now that we understand the differences between how value and reference types *behave*, let's talk about the differences between how we might use them.

Swift might someday have reference types other than objects, but we'll focus on objects as the exemplar reference types for this discussion.

We reference objects in code the same way we reference objects in the real world. Books often use a real-world metaphor to teach people object-oriented programming: you can make a `Dog` class, then instantiate it to define `fido`. If you pass `fido` around to different parts of the system, they're all still talking about the same `fido`. That makes sense, since if you actually had a dog named Fido, whenever you would talk about him in conversation, you'd be transmitting his *name*—not the dog itself, whatever that would mean. You'd be relying on everyone else having some idea of who Fido is. When you use objects, you're passing "names" of instances around the system.

Values are like data. If you send someone a table of expenses, you're not sending them a label which represents that information—you're sending them *the information itself*. Without talking to anyone else, the listener could calculate a total, or write the expenses down to consult later. If the listener prints out the expenses and modifies them, that doesn't modify the table you still have.

A value can be a number, perhaps representing a price, or a string, like a description. It could be a selection among options—an enum: was this expense for a dinner, for travel, or for materials? It could contain several other values in named positions, like the `CLLocationCoordinate2D` struct, which specifies a latitude and longitude. Or it could be a list of other values... and so on.

Fido might run around and bark on his own accord. He might have special behavior that makes him different from every other dog. He might have relationships established with others. You can't just swap Fido out for another dog—your kids could tell the difference! But the table of expenses exists in isolation. Those strings and numbers don't *do* anything. They aren't going to change out from under you. No matter how many different ways you write the "6" in the first column, it's still just a "6."

And that's what's so great about value types.

## The Advantages of Value Types

Objective-C and C had value types, but Swift allows you to use them in previously impractical scenarios. For instance, the generics system permits abstractions that handle value and reference types interchangeably: `Array` works equally well for `Int`s as for `UIView`s. Enums are vastly more expressive in Swift, since they can now carry values and specify methods. Structs can conform to protocols and specify methods.

Swift's enhanced support for value types affords a tremendous opportunity: value types are an incredibly flexible tool for making your code simpler. You can use them to extract isolated, predictable components from fat classes. Value types enforce—or at least encourage—many properties that work together to create clarity by default.

In this section, I'll describe some of the properties that value types encourage. It's worth noting that you *can* make objects that have these properties, but the language provides no pressure to do that. If you see an object in some code, you have no reasonable expectation of these properties, whereas if you see a value type, you do. It's true that not *all* value types have these properties—we'll cover that shortly—but these are reasonable generalizations.

### Value Types Want to Be Inert

A value type does not, in general, *behave*. It is typically *inert*. It stores data and exposes methods that perform computations using that data. Some of those methods might cause the value type to mutate itself, but control flow is strictly controlled by the single owner of the instance.

And that's great! It's much easier to reason about code that will only execute when directly invoked by a single owner.

By contrast, an object might register itself as a target of a timer. It might receive events from the system. These kinds of interactions require reference types' multiple-owner semantics. Because value types can only have a single owner, and they don't have deinitializers, it's awkward to write value types that perform side effects on their own.

### Value Types Want to Be Isolated

A typical value type has no implicit dependencies on the behavior of any external components. Its interactions with its one owner are vastly easier to understand at a glance than a reference type's interactions with an unknowable number of owners. It is *isolated*.

If you're accessing a reference to a mutable instance, you have an implicit dependency on all its other owners: they could change it out from under you at any time.

### Value Types Want to Be Interchangeable

Because a value type is copied every time it's assigned to a new variable, all of those copies are completely interchangeable.

You can safely store a value that's passed to you, then later use that value as if it were 'new.' No one can compare that instance with another using anything but the data contained within it. Interchangeability also means that it doesn't matter *how* a given value was constructed: as long as it compares equal via `==`, it's equivalent for all purposes.

So if you use value types to communicate between components in your system, you can readily shift around your graph of components. Do you have a view that paints a sequence of touch samples? You can compensate for touch latency without touching the view's code by making a component that consumes a sequence of touch samples, appends an estimate of where the user's finger will move based on previous samples, and returns a new sequence. You can confidently give your new component's output to the view—it can't tell the difference.

There's no need for a fancy mocking framework to write unit tests that deal with value types. You can directly construct values indistinguishable from the 'live' instances flowing through your app. The touch-predicting component described above is easy to unit test: predictable value types in; predictable value types out; no side effects.

This is a huge advantage. In a traditional architecture of objects that behave, you have to test the interactions between the object you're testing and the rest of the system. That typically means awkward mocking or extensive setup code establishing those relationships. Value types want to be isolated, inert, and interchangeable, so you can directly construct a value, call a method, and examine the output. Simpler tests with greater coverage mean code that's easier to change.

### Not All Value Types Have These Properties

While the structure of value types encourages these properties, you can certainly make value types that violate them.

Value types containing code that executes without being called by its owner are often unpredictable and should generally be avoided. For example: a struct initializer might call `dispatch_after` to schedule some work. But passing an instance of this struct to a function would duplicate the scheduled effect, inexplicitly, since a copy would be made. Value types should be inert.

Value types containing references are not necessarily isolated and should generally be avoided: they carry a dependency on all other owners of that referent. These value types are also not readily interchangeable, since that external reference might be connected to the rest of your system in some complex way.

## The Object of Objects

I am emphatically not suggesting that we build everything out of inert values.

Objects are useful precisely because they do *not* have the properties I described above. An object is an acting entity in the system. It has identity. It can *behave*, often independently.

That behavior is often complex and difficult to reason about, but some of the details can usually be represented by simple values and isolated functions involving those values. Those details don't need to be entangled with the complex behavior of the object. By separating them, the behavior of the object becomes clearer itself.

Think of objects as a thin, imperative layer above the predictable, pure value layer:

Objects maintain state, defined by values, but those values can be considered and manipulated independently of the object. The value layer doesn't really have state; it just represents and transmutes data. That data may or may not have higher-level meaning as state, depending on the context in which the value's used.

Objects perform side effects like I/O and networking, but data, computations, and non-trivial decisions ultimately driving those side effects all exist at the value layer. The objects are like the membrane, channeling those pure, predictable results into the impure realm of side effects.

Objects can communicate with other objects, but they generally send values, not references, unless they truly intend to create a persistent connection at the outer, imperative layer.

## A Summarizing Pitch for Value Types

Value types enable you to make typical architectures significantly clearer, simpler, and more testable.

Value types typically have fewer or no dependencies on outside state, so there's less you have to consider when reasoning about them.

Value types are inherently more composable and reusable because they're interchangeable.

Finally, a value layer allows you to isolate the active, behaving elements from the inert business logic of your application. As you make more code inert, your system will become easier to test and change over time.

## References

* [Boundaries](https://www.destroyallsoftware.com/talks/boundaries), by Gary Bernhardt, proposes a similar two-level architecture and elaborates on its benefits for concurrency and testing.
* [Are We There Yet?](http://www.infoq.com/presentations/Are-We-There-Yet-Rich-Hickey), by Rich Hickey, elaborates on the distinctions between value, state, and identity.
* [The Structure and Interpretation of Computer Programs](http://mitpress.mit.edu/sicp/), by Harry Abelson and Gerald Sussman, illustrates just how much can be represented with simple values.

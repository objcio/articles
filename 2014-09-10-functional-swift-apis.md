---
layout: post
title:  "Functional APIs with Swift"
category: "16"
date: "2014-09-10 09:00:00"
tags: article
author: "<a href=\"https://twitter.com/floriankugler\">Florian Kugler</a>"
---


When it comes to designing APIs, a lot of common patterns and best practices have evolved over the years. If nothing else, we always had lots of examples to draw from in the form of Apple's Foundation, Cocoa, Cocoa Touch, and many other frameworks. Undoubtedly, there are still ambiguities, and there's always room for discussion about how an API for a certain use case should ideally look. Nevertheless, the general patterns have become pretty much second nature to many Objective-C developers.
       
With this year's emergence of Swift, designing an API poses many more questions than before. For the most part, we could just keep doing what we've been doing and translate existing approaches to Swift. But that's not doing justice to the added capabilities of Swift as compared to Objective-C. To quote Swift's creator, [Chris Lattner](https://twitter.com/clattner_llvm):     

> [...] Swift dramatically expands the design space through the introduction of generics and functional programming concepts.
 
In this article, we're going to explore how we can leverage these new tools at our disposal in the realm of API design. We're going to build a wrapper API around Core Image as an example. Core Image is a powerful image processing framework, but its API can be a bit clunky to use at times. The Core Image API is loosely typed—image filters are configured using key-value coding. It is all too easy to make mistakes in the type or name of arguments, which can result in runtime errors. The new API we develop will be safe and modular, exploiting *types* to guarantee the absence of such runtime errors.


## The Goal
 
The goal is to build an API that allows us to safely and easily compose custom filters. For example, at the end of this article, we'll be able to write something like this:

```swift
let myFilter = blur(blurRadius) >|> colorOverlay(overlayColor)
let result = myFilter(image)
```

This constructs a custom filter that first blurs the image and then applies a color overlay to it. To achieve this, we will make heavy use of Swift's first-class functions. The code we're going to develop is available [as a Playground](TODO). 


## The Filter Type

One of the key classes in Core Image is the `CIFilter` class, which is used to create image filters. When you instantiate a `CIFilter` object, you (almost) always provide an input image via the `kCIInputImageKey` key, and then retrieve the filtered result via the `kCIOutputImageKey` key. Then you can use this result as input for the next filter. 

In the API we will develop in this chapter, we'll encapsulate the exact details of these key-value pairs and present a safe, strongly typed API to our users. We define our own `Filter` type as a function that takes an image as its parameter and returns a new image:

```swift
typealias Filter = CIImage -> CIImage
```

Here we use the [`typealias`](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/TheBasics.html#//apple_ref/doc/uid/TP40014097-CH5-XID_479) keyword to define our own name for the type `CIImage -> CIImage`, which is the type of a function that takes a `CIImage` as its argument and returns a `CIImage`. This is the base type that we are going to build upon.
 
If you're not used to functional programming, it may seem strange to use the name `Filter` for a function type. Usually, we'd use such a name for a class, and the temptation to somehow denote the function nature of this type is high. We could name it `FilterFunction` or something similar. However, we consciously chose the name `Filter`, since the key philosophy underlying functional programming is that functions are just values. They're no different from structs, integers, tuples, or classes. It took me some getting used to as well, but after a while, it started to make a lot of sense. 


## Building Filters

Now that we have the `Filter` type defined, we can start defining functions that build specific filters. These are convenience functions that take the parameters needed for a specific filter and construct a value of type `Filter`. These functions will all have the following general shape:

```swift
func myFilter(/* parameters */) -> Filter
```

Note that the return value, `Filter`, is a function as well. Later on, this will help us compose multiple filters to achieve the image effects we want.

To make our lives a bit easier, we'll extend the `CIFilter` class with a [convenience initializer](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Initialization.html) and a computed property to retrieve the output image:

```swift
typealias Parameters = Dictionary<String, AnyObject>

extension CIFilter {

    convenience init(name: String, parameters: Parameters) {
        self.init(name: name)
        setDefaults()
        for (key, value : AnyObject) in parameters {
            setValue(value, forKey: key)
        }
    }

    var outputImage: CIImage { return self.valueForKey(kCIOutputImageKey) as CIImage }

}
```

The convenience initializer takes the name of the filter and a dictionary as parameters. The key-value pairs in the dictionary will be set as parameters on the new filter object. Our convenience initializer follows the Swift pattern of calling the designated initializer first.

The [computed property](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Properties.html#//apple_ref/doc/uid/TP40014097-CH14-XID_329), `outputImage`, provides an easy way to retrieve the output image from the filter object. It looks up the value for the `kCIOutputImageKey` key and casts the result to a value of type `CIImage`. By providing this computed property of type `CIImage`, users of our API no longer need to cast the result of such a lookup operation themselves.


### Blur

With these pieces in place, we can define our first simple filters. The Gaussian blur filter only has the blur radius as its parameter. As a result, we can write a blur `Filter` very easily:

```swift
func blur(radius: Double) -> Filter {
    return { image in
        let parameters : Parameters = [kCIInputRadiusKey: radius, kCIInputImageKey: image]
        let filter = CIFilter(name:"CIGaussianBlur", parameters:parameters)
        return filter.outputImage
    }
}
```

That's all there is to it. The `blur` function returns a function that takes an argument `image` of type `CIImage` and returns a new image (`return filter.outputImage`). Because of this, the return value of the `blur` function conforms to the `Filter` type we previously defined as `CIImage -> CIImage`.

This example is just a thin wrapper around a filter that already exists in Core Image. We can use the same pattern over and over again to create our own filter functions.


### Color Overlay

Let's define a filter that overlays an image with a solid color of our choice. Core Image doesn't have such a filter by default, but we can, of course, compose it from existing filters.

The two building blocks we're going to use for this are the color generator filter (`CIConstantColorGenerator`) and the source-over compositing filter (`CISourceOverCompositing`). Let's first define a filter to generate a constant color plane:

```swift
func colorGenerator(color: NSColor) -> Filter {
    return { _ in
        let filter = CIFilter(name:"CIConstantColorGenerator", parameters: [kCIInputColorKey: color])
        return filter.outputImage
    }
}
```

This looks very similar to the `blur` filter we've defined above, with one notable difference: the constant color generator filter does not inspect its input image. Therefore, we don't need to name the image parameter in the function being returned. Instead, we use an unnamed parameter, `_`, to emphasize that the image argument to the filter we are defining is ignored.

Next, we're going to define the composite filter:

```swift
func compositeSourceOver(overlay: CIImage) -> Filter {
    return { image in
        let parameters : Parameters = [ 
            kCIInputBackgroundImageKey: image, 
            kCIInputImageKey: overlay
        ]
        let filter = CIFilter(name:"CISourceOverCompositing", parameters: parameters)
        return filter.outputImage.imageByCroppingToRect(image.extent())
    }
}
```

Here we crop the output image to the size of the input image. This is not strictly necessary, and it depends on how we want the filter to behave. However, this choice works well in the examples we will cover.

Finally, we combine these two filters to create our color overlay filter:

```swift
func colorOverlay(color: NSColor) -> Filter {
    return { image in
        let overlay = colorGenerator(color)(image)
        return compositeSourceOver(overlay)(image)
    }
}
```

Once again, we return a function that takes an image parameter as its argument. The `colorOverlay` starts by calling the `colorGenerator` filter. The `colorGenerator` filter requires a `color` as its argument and returns a filter, hence the code snippet `colorGenerator(color)` has type `Filter`. The `Filter` type, however, is itself a function from `CIImage` to `CIImage`; we can pass an *additional* argument of type `CIImage` to `colorGenerator(color)` to compute a new overlay `CIImage`. This is exactly what happens in the definition of `overlay`—we create a filter using the `colorGenerator` function and pass the `image` argument to this filter to create a new image. Similarly, the value returned, `compositeSourceOver(overlay)(image)`, consists of a filter, `compositeSourceOver(overlay)`, being constructed and subsequently applied to the `image` argument.


## Composing Filters

Now that we have a blur and a color overlay filter defined, we can put them to use on an actual image in a combined way: first we blur the image, and then we put a red overlay on top. Let's load an image to work on:

```swift
let url = NSURL(string: "http://tinyurl.com/m74sldb");
let image = CIImage(contentsOfURL: url)
```

Now we can apply both filters to these by chaining them together:

```swift
let blurRadius = 5.0
let overlayColor = NSColor.redColor().colorWithAlphaComponent(0.2)
let blurredImage = blur(blurRadius)(image)
let overlaidImage = colorOverlay(overlayColor)(blurredImage)
```

Once again, we assemble images by creating a filter, such as `blur(blurRadius)`, and applying the resulting filter to an image.


### Function Composition

However, we can do much better than the example above. The first alternative that comes to mind is to simply combine the two filter calls into a single expression:

```swift
let result = colorOverlay(overlayColor)(blur(blurRadius)(image))
```

However, all the parentheses make this unreadable very quickly. A better approach is to compose filters by defining a custom function for this task:

```swift
func composeFilters(filter1: Filter, filter2: Filter) -> Filter {
    return { img in filter2(filter1(img)) }
}
```

The `composeFilters` function takes two filters as arguments and defines a new filter. This composite filter expects an argument `img` of type `CIImage`, and passes it through both `filter1` and `filter2`, respectively. We can now use function composition to define our own composite filter, like this:

```swift
let myFilter = composeFilters(blur(blurRadius), colorOverlay(overlayColor))
let result = myFilter(image)
```

But we can go one step further to make this even more readable by introducing an operator for filter composition: 

```swift
infix operator >|> { associativity left }

func >|> (filter1: Filter, filter2: Filter) -> Filter {
    return { img in filter2(filter1(img)) }
}
```

The operator definition starts with the keyword `infix`, which specifies that the operator takes a left and a right argument. `associativity left` specifies that an expression like `f1 >|> f2 >|> f3` will be evaluated as `(f1 >|> f2) >|> f3`. By making this a left-associative operator and applying the left-hand filter first, we can read the sequence of filters applies from left to right, just as Unix pipes. 

The rest is a simple function identical to the `composeFilters` function we've defined before, the only difference being its name `>|>`. 

Applying the filter composition operator turns the example we've used before into:

```swift
let myFilter = blur(blurRadius) >|> colorOverlay(overlayColor)
let result = myFilter(image)
```

Working with this operator makes it easier to read and understand the sequence the filters are applied in. It's also much more convenient if we want to reorder the filters. To use a simple analogy, `1 + 2 + 3 + 4` is much clearer and easier to change than `add(add(add(1, 2), 3), 4)`. 


## Custom Operators

Many Objective-C developers are very skeptical about defining custom operators. It was a feature that didn't receive a too warm welcome when Swift was first introduced. Lots of people have been burned by custom operator overuse (or abuse) in C++, either in personal experience or with stories from others.

You might look equally skeptical at the `>|>` operator for filter composition that we've defined above. After all, if everybody starts to define one's own operators, isn't this going to make code really hard to understand? The good thing is that in functional programming there are a bunch of operations that come back all the time, and defining a custom operator for those operations is not an uncommon thing to do at all. 

The filter composition operator we've defined above is just an example of [function composition](http://en.wikipedia.org/wiki/Function_composition_%28computer_science%29), a concept that's widely used in functional programming. In mathematics, the composition of the two functions `f` and `g`, sometimes written `f ∘ g`, defines a new function mapping an input to `x` to `f(g(x))`. This is precisely what our `>|>` operator does (apart from applying the functions in reverse order).


### Generics

With this in mind, we don't actually have to define a special operator to compose filters, but we can use a generic function composition operator. So far, our `>|>` operator was defined as:
 
```swift
func >|> (filter1: Filter, filter2: Filter) -> Filter
```

With this definition, we can only apply it to arguments of type `Filter`.
 
However, we can leverage Swift's [generics](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Generics.html) feature to define a generic function composition operator:
 
```swift
func >|> <A, B, C>(lhs: A -> B, rhs: B -> C) -> A -> C {
    return { x in rhs(lhs(x)) }
}
```

This is probably pretty hard to read at first—at least it was for me. But looking at all the pieces individually, it becomes clear what this does.

First we take a look at what's between the angled brackets after the function's name. This specifies the generic types this function is going to work with. In this case, we have specified three generic types: `A`, `B`, and `C`. Since we haven't restricted those types in any way, they can represent anything.

Next, let's inspect the function's arguments: the first argument, `lhs` (short for left-hand side), is a function of type `A -> B`, i.e. a function that takes an argument of type `A` and returns a value of type `B`. The second argument, `rhs` (right-hand side), is a function of type `B -> C`. The arguments are named `lhs` and `rhs` because they represent what's to the left and right of the operator, respectively. 

Rewriting our filter composition operator without using the `Filter` typealias, we quickly see that it was only a special case of the generic function composition operator:

```swift
func >|> (filter1: CIImage -> CIImage, filter2: CIImage -> CIImage) -> CIImage -> CIImage
```

Translating the generic types `A`, `B`, and `C` in our minds to all represent `CIImage` makes it clear that the generic operator is indeed capable of replacing the specific filter composition operator.     


## Conclusion

Hopefully the example of wrapping Core Image in a functional API was able to demonstrate that when it comes to API design patterns, there is an entirely different world out there than what we're used to as Objective-C developers. With Swift, we now have the tools in our hands to explore those other patterns and make use of them where it makes sense. 

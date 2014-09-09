---
layout: post
title:  "The Power of Swift"
category: "16"
date: "2014-09-10 11:00:00"
tags: article
author: "<a href=\"https://twitter.com/chriseidhof\">Chris Eidhof</a>"
---

Before writing anything else, I have to admit I'm very biased: I love Swift. I think it's the best thing that happened to the Cocoa ecosystem since I started. I want to let you know why I think this by sharing my experiences with Swift, Objective-C, and Haskell. This article is not really about any best practices (at the moment of writing, Swift is much too young to have any established best practices), but rather about showing some examples where Swift really shines.

To give some personal background: before being a full-time programmer on the iOS and Mac platforms, I spent a few years doing lots of Haskell (among other functional programming languages). I still think Haskell is one of the most beautiful languages I've worked with. However, I switched to Objective-C because I believed (and still believe) that the iOS platform is the most exciting platform to work on. In the beginning, it was a bit frustrating for me to be working in Objective-C, but I learned to love it.

When Apple announced Swift during WWDC, I got really excited. I haven't been so excited about any new technology announcement in years. After looking at the documentation, I realized that Swift allows us to use all the existing knowledge from functional languages, yet still integrate seamlessly with Cocoa APIs. I think the combination of these two features is very unique: there is no other language that melds both things together so well. Looking at a language like Haskell, it's rather hard to call Objective-C APIs, and looking at Objective-C, it's rather hard to do functional programming.

I learned functional programming during my time at Utrecht University. Because I learned it in the context of academia, I wasn't too overwhelmed by the complicated terminology used: monads, applicative functors, and lots of other things. I think the naming is one big stumbling block for people who want to get into functional programming.

Not only is the naming different, but also the style. Being Objective-C programmers, we're used to object-oriented programming. And because most languages are either using object-oriented programming or a similar style, we can read most code in most languages. Not so much when reading functional programming—it might look like complete gibberish when you're not used to it.

Why would you use functional programming, then? It's weird, people are not used to it, and it takes quite a while to learn. Also, you can already solve any problem with object-oriented programming, so there's no need to learn anything new.

For me, functional programming is just another tool in the toolbox. It's a very powerful tool that changed the way I think about programming. It can be extremely useful when solving problems. For most problems, object-oriented programming is great. But for others, solving the problem functionally might save you massive amounts of time and energy.

Getting started with functional programming might be a bit painful. For one, you have to let go of old patterns. Because a lot of us spent years thinking in an object-oriented way, this is very difficult. In functional programming, you think of immutable data structures and functions that convert them. In object-oriented programming, you think about objects that send messages to each other. If you don't immediately get functional programming, it's a good sign. Your brain is probably deeply wired to think of solving problems in the object-oriented way.

## Examples

One of my favorite features of Swift is optionals. Optionals allow us to deal with values that might or might not exist. In Objective-C, we have to be precise in our documentation about whether or not `nil` values are allowed. With optionals, we move this responsibility to the type system. If you have an optional value, it might be nil. If you have a value that's not of the optional type, you know it cannot be nil.

For example, consider the following snippet in Objective-C:

```objectivec
- (NSAttributedString *)attributedString:(NSString *)input 
{
    return [[NSAttributedString alloc] initWithString:input];
}
```

It looks harmless, but if `input` is nil, this will crash. This is something you can only find out at runtime. Depending on how it is used, you might find it out very quickly, but you might also find out only after you shipped the app, leading to crashes for your customers.

Contrast this with the same API in Swift:

```swift
extension NSAttributedString {
    init(string str: String)
}
```

It might look like an exact translation from Objective-C, but Swift does not allow `nil` values to be passed in. If that would have been the case, the API would look like this:

```swift
extension NSAttributedString {
    init(string str: String?)
}
```

Note that there is an added question mark. This means that you can pass in either a value, or nil. The type is very *precise*: just by looking at it, we can see which values are allowed. After working with optionals for a while, you will find that you can read the type instead of the documentation. And if you make a mistake, you will get a compile-time warning instead of a runtime error.

### Advice

If you can, avoid optionals. Optionals are an extra mental obstacle for consumers of your API. That said, there are definitely good uses for them. If you have a function that might not succeed for a clear reason, you can return an optional. For example, suppose you're parsing a string like `#00ff00` into a color. If the input doesn't conform to the format, you want to return `nil`:

```swift
func parseColorFromHexString(input: String) -> UIColor? {
    // ...
}
```

In case you need to specify an error message, you could also use an `Either` or `Result` type, which is not in the standard library. This is very useful when the reason for failure is important. A good example is found in the post [Error handling in Swift](http://nomothetis.svbtle.com/error-handling-in-swift).

## Enums

Enums are a new thing to Swift, and they are rather different from anything we're used to in Objective-C. In Objective-C, we have something called enums, but they're not much more than glorified integers.

Let's consider boolean types. A boolean can have exactly one of two possible values: true or false. It is important to realize that it's not possible to add another possible value—the boolean type is *closed*. The nice thing about booleans being closed is that in any function that uses the boolean type, we only have to take `true` and `false` into account. 

The same holds true for optionals. There are only two cases: the `nil` case, and the case where there's a value. Both optionals and booleans can be defined as an enum in Swift, with only one difference: in the optional enum, there is a case that has an associated value. Let's look at their respective definitions:

```swift
enum Boolean {
    case False
    case True
}

enum Optional<A> {
    case Nil
    case Some(A)
}
```

They are very similar. If you change the naming of the cases, the only thing that's different is the associated value. If you also add a value to the `Nil` case of the optional, you end up with the `Either` type:

```swift
enum Either<A,B> {
    case Left<A>
    case Right<B>
}
```

The `Either` type is used a lot in functional programming when you want to represent a choice between two things. For example, if you have function that returns either an integer or an error, you could use `Either<Int,NSError>`. If you would want to store either booleans or strings in a dictionary, you could use `Either<Bool,String>` as the key type.

> Theoretical aside: sometimes enums are so-called *sum types*, because they represent a sum of different types. In the case of `Either`, they represent the sum of `A` and `B`. Structs or tuples are called *product types* because they represent the product of different types. See also: [algebraic data types](http://en.wikipedia.org/wiki/Algebraic_data_type).

Knowing when to use enums and when to use other data-types (such as [classes or structs](TODO link to Andys article)) can be a bit difficult. They are most useful when you have a closed set of possible values. For example, if we design a Swift wrapper around the GitHub API, we could represent the endpoints with an enum. There's a `/zen` endpoint, which doesn't take any parameters. To fetch a user profile, we have to provide the username, and finally, to display a user's repositories, we provide the username and a key that shows whether or not to sort the result ascendingly:

```swift
enum Github {
    case Zen
    case UserProfile(String)
    case Repositories(username: String, sortAscending: Bool)
}
```

Defining API endpoints is a good use case for enums. The list of API endpoints is finite, and we can just define a case for each endpoint. If we do a switch statement on values of this endpoint, we will get a warning if we forget to include case. So if at some point we will add a case, we need to update every function or method that pattern-matches on this enum.

Other people who use our enum cannot just add extra cases to it, unless they have access to the source. This is a very useful limitation. Consider if you could add a case to `Bool` or `Optional`—then all the functions that use it would need to be rewritten.

Let's say we are building a currency converter. We could define our currencies as an enum:

```swift
enum Currency {
    case Eur
    case Usd
}
```

We can now write a function that gets the symbol for any currency:

```swift
func symbol(input: Currency) -> String {
    switch input {
        case .Eur: return "€"
        case .Usd: return "$"
    }
}
```

And finally, we can use our `symbol` function to produce a nicely formatted string according to the system's locale:

```swift
func format(amount: Double, currency: Currency) -> String {
    let formatter = NSNumberFormatter()
    formatter.numberStyle = .CurrencyStyle
    formatter.currencySymbol = symbol(currency)
    return formatter.stringFromNumber(amount)
}
```

There is one big limitation. For currencies, we might want to allow users of our API to add more cases later on. In Objective-C, a common way to add more types to an interface is by subclassing. In Objective-C, you can, in theory, subclass any class, and extend it that way. In Swift, you can still use subclassing, but only on classes, not on enums. However, we can use another technique (which works in both Objective-C and Swift protocols).

Let's suppose we define a protocol for currency symbols:

```swift
protocol CurrencySymbol {
    func symbol() -> String
}
```

Now, we can make our `Currency` type an instance of this protocol. Note that we can now remove the `input` parameter, as it is implicitly passed as self:

```swift
extension Currency : CurrencySymbol {
   func symbol() -> String {
        switch self {
            case .Eur: return "€"
            case .Usd: return "$"
        }
    }
}
```

And we can rewrite our `format` function to work on any type that conforms to the protocol:

```swift
func format(amount: Double, currency: CurrencySymbol) -> String {
    let formatter = NSNumberFormatter()
    formatter.numberStyle = .CurrencyStyle
    formatter.currencySymbol = currency.symbol()
    return formatter.stringFromNumber(amount)
}
```

Now we have made our code very extensible—any type that conforms to `CurrencySymbol` can now be formatted. For example, if we create a new type that stores bitcoins, we can immediately make it work with our `format` function:

```swift
struct Bitcoin : CurrencySymbol {
    func symbol() -> String {
        return "B⃦"
    }
}
```

This is a great way of writing functions that are open for extension. By taking in values that should conform to a protocol, rather than concrete types, you leave it up to the user of your API to add more types. You can still use the flexibility of enums, but by combining them with protocols, you can be even more expressive. Depending on your use-case, you can now easily choose whether you want an open or a closed API.

## Type Safety

I think one really big win of Swift is type safety. As we have seen with the optionals, we can move certain checks from runtime to compile time by using types in a smart way. Another example is how arrays work in Swift: an array is generic, and it can only hold elements of the same type. It's not possible to append an integer value to an array of strings. This eliminates an entire class of possible bugs. (Note that if you want an array of either strings or integers, you can use the `Either` type above.)

Suppose, again, that we are extending our currency converter to be a general unit converter. If we would use `Double` to represent the amounts, it could get a bit confusing. For example, 100.0 might mean 100 dollars, 100 kilograms, or anything else that's 100. What we can do is let the type system help us by creating different types for different physical quantities. For example, we can define a type that describes money:

```swift
struct Money {
    let amount : Double
    let currency: Currency
}
```

For mass, we could define another struct:

```swift
struct Mass {
    let kilograms: Double
}
```

Now there is no way we can accidentally add up `Money` and `Mass`. Depending on the domain of your application, it might be very useful to wrap simple types like this. In addition, reading code will become a lot simpler. Suppose we encounter a function `pounds`:

```swift
func pounds(input: Double) -> Double
```

It is rather difficult to see from the type signature what it does. Does it convert euros into pounds? Or does it convert kilograms into pounds? We could name the function differently, or we could write documentation (both are very good ideas), but there is a third alternative. We can make the type more specific:

```swift
func pounds(input: Mass) -> Double
```

Not only have we made it easier for consumers of this function to immediately understand what it does, but we also made it impossible to accidentally pass in values that are in other units. If you try to call this function with a `Money` value, the compiler just won't accept it. One possible improvement would be to have a more precise return type as well; now it's just `Double`.

## Immutability

Another really nice feature of Swift is the built-in support for immutability. In Cocoa, many of the APIs already show the value of immutability. For a good overview of why this is important, see also [Value Objects](/issue-7/value-objects.html). For example, as Cocoa developers, we use a lot of pairs of classes (`NSString` vs. `NSMutableString`, `NSArray` vs. `NSMutableArray`). When you receive an `NSString` value, you can assume it won't be changed. To be completely sure, you still have to `copy` it, and then you know that you have a unique immutable copy that won't be changed.

In Swift, immutability is built directly into the language. For example, if you want to create a mutable string, you would write the following code:

```swift
var myString = "Hello"
```

However, if you want to create an immutable string, you can do the following:

```swift
let myString = "Hello"
```

Having immutable data can greatly help when working with APIs that are called
by consumers you might not know. For example, if you have a function that takes
an array, it is very useful to know that the array will not be mutated while
you iterate over it. In Swift, this is the case by default. Writing
multithreaded code with immutable data is much easier, exactly because of this
reason.

There is another really big advantage. If you write functions and methods that only operate on immutable data, your type signature is a huge source of documentation. In Objective-C, this is often not the case. For example, suppose that you want to use a `CIFilter` on OS X. After instantiating it, you need to call the `setDefaults` method. This is described in the documentation. There are many other classes like this, where you instantiate it, and then you have to call one or more methods before you can use them. The problem is, without reading the documentation, often it is not clear which methods to call, and you might end up with very strange behavior.

When working with immutable data, it is immediately clear from the type signature what's happening. For example, consider the type signature for `map` on optionals. We know that there is an optional `T` value, and there is a function that converts `T`s into `U`s. The result is an optional `U` value. There is no way the original value has changed:

```swift
func map<T, U>(x: T?, f: T -> U) -> U?
```

It's the same with `map` on an array. It is defined as an extension on array, so the input array is `self`. We can see that it takes a function that transforms `T` into `U`, and produces an array of `U` values. Because it's an immutable function, we know that the original array can't change, and we know that the result is immutable too. Having these constraints encoded in the type system and enforced by the compiler takes away the burden of having to look up the documentation and remembering exactly what changes:

```swift
extension Array {
    func map<U>(transform: T -> U) -> [U]
}
```


## Conclusion

There are a lot of interesting new possibilities with Swift. I especially like that the compiler can now check things that we used to do manually or by reading the documentation. We can choose to use these possibilities as we see fit. We can still write code using our existing, proving techniques, but we can opt in to some of the new possibilities for specific parts of our code. 

Here is my prediction: I think Swift will dramatically change the way we write code, in a good way. It will take a few years to make the move from Objective-C, but I think that most of us will make the change and not look back. Some people will transition fast, and for some it might take a long time. However, I am confident that in due time, almost everybody will see the benefits that Swift provides us with.

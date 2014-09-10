---
layout: post
title:  "The Many Faces of Swift Functions"
category: "16"
date: "2014-09-10 08:00:00"
author: "<a href=\"https://twitter.com/NatashaTheRobot\">Natasha Murashev</a>"
tags: article
---


Although Objective-C has some strange-looking syntax compared to other programming languages, the method syntax is pretty straightforward once you get the hang of it. Here is a quick throwback:  

```objectivec

+ (void)mySimpleMethod
{
    // class method
    // no parameters 
    // no return values
}

- (NSString *)myMethodNameWithParameter1:(NSString *)param1 parameter2:(NSNumber *)param2
{
    // instance method
    // one parameter of type NSString pointer, one parameter of type NSNumber pointer
    // must return a value of type NSString pointer
    return @"hello, world!";
}
```

In contrast, while Swift syntax looks a lot more like other programming languages, it can also get a lot more complicated and confusing than Objective-C. 

Before I continue, I want to clarify the difference between a Swift *method* and *function*, as I'll be using both terms throughout this article. Here is the definition of Methods, according to Apple's [Swift Programming Language Book](https://developer.apple.com/library/prerelease/mac/documentation/Swift/Conceptual/Swift_Programming_Language/Methods.html):

> Methods are functions that are associated with a particular type. Classes, structures, and enumerations can all define instance methods, which encapsulate specific tasks and functionality for working with an instance of a given type. Classes, structures, and enumerations can also define type methods, which are associated with the type itself. Type methods are similar to class methods in Objective-C.

TL;DR: Functions are standalone, while methods are functions that are encapsulated in a class, struct, or enum. 

## Anatomy of Swift Functions

Let's start with a simple "Hello, World!" Swift function: 

```swift
func mySimpleFunction() {
    println("hello, world!")
}
```

If you've ever programmed in any other language aside from Objective-C, the above function should look very familiar. 

* The `func` keyword denotes that this is a function.
* The name of this function is `mySimpleFunction`.
* There are no parameters passed in—hence the empty `( )`.
* There is no return value.
* The function execution happens between the `{ }`.

Now on to a slightly more complex function: 

```swift
func myFunctionName(param1: String, param2: Int) -> String {
    return "hello, world!"
}
```

This function takes in one parameter named `param1` of type `String` and one parameter named `param2` of type `Int` and returns a `String` value. 

## Calling All Functions

One of the big differences between Swift and Objective-C is how parameters work when a Swift function is called. If you love the verbosity of Objective-C, like I do, keep in mind that parameter names are not included externally by default when a Swift function is called: 

```swift
func hello(name: String) {
    println("hello \(name)")
}

hello("Mr. Roboto")
```

This might not seem so bad until you add a few more parameters to your function: 

```swift
func hello(name: String, age: Int, location: String) {
    println("Hello \(name). I live in \(location) too. When is your \(age + 1)th birthday?")
}

hello("Mr. Roboto", 5, "San Francisco")
```

From reading just `hello("Mr. Roboto", 5, "San Francisco")`, you would have a hard time knowing what each parameter actually is. 

In Swift, there is a concept of an *external parameter name* to clarify this confusion: 

```swift
func hello(fromName name: String) {
    println("\(name) says hello to you!")
}

hello(fromName: "Mr. Roboto")
```

In the above function, `fromName` is an external parameter, which gets included when the function is called, while `name` is the internal parameter used to reference the parameter inside the function execution. 

If you want the external and internal parameter names to be the same, you don't have to write out the parameter name twice: 

```swift
func hello(name name: String) {
    println("hello \(name)")
}

hello(name: "Robot")
```

Instead, just add a `#` in front of the parameter name as a shortcut: 

```swift
func hello(#name: String) {
    println("hello \(name)")
}

hello(name: "Robot")
```

And of course, the rules for how parameters work are slightly different for Methods...

## Calling On Methods

When encapsulated in a class (or struct or enum), the first parameter name of a method is *not* included externally, while all following parameter names are included externally when the method is called:

```swift
class MyFunClass {
    
    func hello(name: String, age: Int, location: String) {
        println("Hello \(name). I live in \(location) too. When is your \(age + 1)th birthday?")
    }
    
}

let myFunClass = MyFunClass()
myFunClass.hello("Mr. Roboto", age: 5, location: "San Francisco")
```

It is therefore best practice to include your first parameter name in your method name, just like in Objective-C: 

```swift
class MyFunClass {
    
    func helloWithName(name: String, age: Int, location: String) {
        println("Hello \(name). I live in \(location) too. When is your \(age + 1)th birthday?")
    }
    
}

let myFunClass = MyFunClass()
myFunClass.helloWithName("Mr. Roboto", age: 5, location: "San Francisco")
```

Instead of calling my function "hello," I renamed it to `helloWithName` to make it very clear that the first parameter is a name. 

If for some special reason you want to skip the external parameter names in your function (I'd recommend having a very good reason for doing so), use an `_` for the external parameter name: 

```swift
class MyFunClass {
    
    func helloWithName(name: String, _ age: Int, _ location: String) {
        println("Hello \(name). I live in \(location) too. When is your \(age + 1)th birthday?")
    }
    
}

let myFunClass = MyFunClass()
myFunClass.helloWithName("Mr. Roboto", 5, "San Francisco")
```

### Instance Methods Are Curried Functions

One cool thing to note is that [instance methods are actually curried functions in Swift](http://oleb.net/blog/2014/07/swift-instance-methods-curried-functions/).

> The basic idea behind currying is that a function can be partially applied, meaning that some of its parameter values can be specified (bound) before the function is called. Partial function application yields a new function.

So given that I have a class: 

```swift
class MyHelloWorldClass {
    
    func helloWithName(name: String) -> String {
        return "hello, \(name)"
    }
}
```

I can create a variable that points to the class's `helloWithName` function: 

```swift
let helloWithNameFunc = MyHelloWorldClass.helloWithName
// MyHelloWorldClass -> (String) -> String
``` 
My new `helloWithNameFunc` is of type `MyHelloWorldClass -> (String) -> String`, a function that takes in an instance of my class and returns another function that takes in a String value and returns a String value. 

So I can actually call my function like this: 

```swift
let myHelloWorldClassInstance = MyHelloWorldClass()

helloWithNameFunc(myHelloWorldClassInstance)("Mr. Roboto") 
// hello, Mr. Roboto
```

## Init: A Special Note
A special `init` method is called when a class, struct, or enum is initialized. In Swift, you can define initialization parameters, just like with any other method: 

```swift
class Person {
    
    init(name: String) {
        // your init implementation
    }
    
}

Person(name: "Mr. Roboto")
```

Notice that, unlike other methods, the first parameter name of an init method is required externally when the class is instantiated. 

It is best practice in most cases to add a different external parameter name—`fromName` in this case—to make the initialization more readable: 

```swift
class Person {
    
    init(fromName name: String) {
        // your init implementation
    }
    
}

Person(fromName: "Mr. Roboto")
```

And of course, just like with other methods, you can add an `_` if you want your init method to skip the external parameter name. I love the readability and power of this initialization example from the [Swift Programming Language Book](https://developer.apple.com/library/prerelease/mac/documentation/Swift/Conceptual/Swift_Programming_Language/Initialization.html#//apple_ref/doc/uid/TP40014097-CH18-XID_306): 

```swift
struct Celsius {
    var temperatureInCelsius: Double
    init(fromFahrenheit fahrenheit: Double) {
        temperatureInCelsius = (fahrenheit - 32.0) / 1.8
    }
    init(fromKelvin kelvin: Double) {
        temperatureInCelsius = kelvin - 273.15
    }
    init(_ celsius: Double) {
        temperatureInCelsius = celsius
    }
}

let boilingPointOfWater = Celsius(fromFahrenheit: 212.0)
// boilingPointOfWater.temperatureInCelsius is 100.0

let freezingPointOfWater = Celsius(fromKelvin: 273.15)
// freezingPointOfWater.temperatureInCelsius is 0.0

let bodyTemperature = Celsius(37.0)
// bodyTemperature.temperatureInCelsius is 37.0
```

Skipping the external parameter can also be useful if you want to abstract how your class / enum / struct gets initialized. I love the use of this in [David Owen's](https://twitter.com/owensd) [json-swift library](https://github.com/owensd/json-swift/blob/master/src/JSValue.swift): 

```swift
public struct JSValue : Equatable {
    
    // ... truncated code

    /// Initializes a new `JSValue` with a `JSArrayType` value.
    public init(_ value: JSArrayType) {
        self.value = JSBackingValue.JSArray(value)
    }

    /// Initializes a new `JSValue` with a `JSObjectType` value.
    public init(_ value: JSObjectType) {
        self.value = JSBackingValue.JSObject(value)
    }

    /// Initializes a new `JSValue` with a `JSStringType` value.
    public init(_ value: JSStringType) {
        self.value = JSBackingValue.JSString(value)
    }

    /// Initializes a new `JSValue` with a `JSNumberType` value.
    public init(_ value: JSNumberType) {
        self.value = JSBackingValue.JSNumber(value)
    }

    /// Initializes a new `JSValue` with a `JSBoolType` value.
    public init(_ value: JSBoolType) {
        self.value = JSBackingValue.JSBool(value)
    }

    /// Initializes a new `JSValue` with an `Error` value.
    init(_ error: Error) {
        self.value = JSBackingValue.Invalid(error)
    }

    /// Initializes a new `JSValue` with a `JSBackingValue` value.
    init(_ value: JSBackingValue) {
        self.value = value
    }
}
```

## Fancy Parameters
Compared to Objective-C, Swift has a lot of extra options for what type of parameters can be passed in. Here are some of examples. 

### Optional Parameter Types

In Swift, there is a new concept of [optional types](https://developer.apple.com/library/prerelease/mac/documentation/Swift/Conceptual/Swift_Programming_Language/TheBasics.html): 

> Optionals say either “there is a value, and it equals x” or “there isn’t a value at all.” Optionals are similar to using nil with pointers in Objective-C, but they work for any type, not just classes. Optionals are safer and more expressive than nil pointers in Objective-C and are at the heart of many of Swift’s most powerful features.

To indicate that a parameter type is optional (can be nil), just add a question mark after the type specification: 

```swift
func myFuncWithOptionalType(parameter: String?) {
    // function execution
}

myFuncWithOptionalType("someString")
myFuncWithOptionalType(nil)
```

When working with optionals, don't forget to unwrap!

```swift
func myFuncWithOptionalType(optionalParameter: String?) {
    if let unwrappedOptional = optionalParameter {
        println("The optional has a value! It's \(unwrappedOptional)")
    } else {
        println("The optional is nil!")
    }
}

myFuncWithOptionalType("someString")
// The optional has a value! It's someString

myFuncWithOptionalType(nil)
// The optional is nil
```

Coming from Objective-C, getting used to working with optionals definitely takes some time!

### Parameters with Default Values
```swift
func hello(name: String = "you") {
    println("hello, \(name)")
}

hello(name: "Mr. Roboto")
// hello, Mr. Roboto

hello()
// hello, you
```

Note that a parameter with a default value automatically has an external parameter name. 

And since parameters with a default value can be skipped when the function is called, it is best practice to put all your parameters with default values at the end of a function's parameter list. Here is a note from the [Swift Programming Language Book](https://developer.apple.com/library/prerelease/mac/documentation/Swift/Conceptual/Swift_Programming_Language/Functions.html) on the topic:  

> Place parameters with default values at the end of a function’s parameter list. This ensures that all calls to the function use the same order for their non-default arguments, and makes it clear that the same function is being called in each case.

I'm a huge fan of default parameters, mostly because it makes code easy to change and backward compatible. You might start out with two parameters for your specific use case at the time, such as a function to configure a custom `UITableViewCell,` and if another use case comes up that requires another parameter (such as a different text color for your cell's label), just add a new parameter with a default value—all the other places where this function has already been called will be fine, and the new part of your code that needs the parameter can just pass in the non-default value!

### Variadic Parameters 

Variadic parameters are simply a more readable version of passing in an array of elements. In fact, if you were to look at the type of the internal parameter names in the below example, you'd see that it is of type `[String]` (Array of Strings): 

```swift
func helloWithNames(names: String...) {
    for name in names {
        println("Hello, \(name)")
    }
}

// 2 names
helloWithNames("Mr. Robot", "Mr. Potato")
// Hello, Mr. Robot
// Hello, Mr. Potato

// 4 names
helloWithNames("Batman", "Superman", "Wonder Woman", "Catwoman")
// Hello, Batman
// Hello, Superman
// Hello, Wonder Woman
// Hello, Catwoman
```

The catch here is to remember that it is possible to pass in 0 values, just like it is possible to pass in an empty array, so don't forget to check for the empty array if needed:

```swift
func helloWithNames(names: String...) {
    if names.count > 0 {
        for name in names {
            println("Hello, \(name)")
        }
    } else {
        println("Nobody here!")
    }
}

helloWithNames()
// Nobody here!
```

Another note about variadic parameters—the variadic parameter must be the *last* parameter in your function's parameter list! 

### Inout Parameters

With inout parameters, you have the ability to manipulate external variables (aka pass by reference):

```swift
var name1 = "Mr. Potato"
var name2 = "Mr. Roboto"

func nameSwap(inout name1: String, inout name2: String) {
    let oldName1 = name1
    name1 = name2
    name2 = oldName1
}

nameSwap(&name1, &name2)

name1
// Mr. Roboto

name2
// Mr. Potato
``` 

This is a very common pattern in Objective-C for handling error scenarios. `NSJSONSerialization` is just one example: 

```objectivec
- (void)parseJSONData:(NSData *)jsonData
{
    NSError *error = nil;
    id jsonResult = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    
    if (!jsonResult) {
        NSLog(@"ERROR: %@", error.description);
    }
}
```

Since Swift is so new, there aren't clear conventions on handling errors just yet, but there are definitely a lot of options beyond inout parameters! Take a look at David Owen's recent blog post on [error handling in Swift](http://owensd.io/2014/08/22/error-handling-take-two.html). More on this topic should also be covered in [Functional Programming in Swift](http://www.objc.io/books/). 

### Generic Parameter Types

I'm not going to get too much into generics in this post, but here is a very simple example for how you can make a function accept parameters of different types while making sure that both parameters are of the same type:

```swift
func valueSwap<T>(inout value1: T, inout value2: T) {
    let oldValue1 = value1
    value1 = value2
    value2 = oldValue1
}

var name1 = "Mr. Potato"
var name2 = "Mr. Roboto"

valueSwap(&name1, &name2)

name1 // Mr. Roboto
name2 // Mr. Potato

var number1 = 2
var number2 = 5

valueSwap(&number1, &number2)

number1 // 5
number2 // 2
```

For a lot more information on Generics, I recommend taking a look at the [Generics section](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Generics.html) of the Swift Programming Language book. 

### Variable Parameters

By default, parameters that are passed into a function are constants, so they cannot be manipulated within the scope of the function. If you would like to change that behavior, just use the var keyword for your parameters:

```swift
var name = "Mr. Roboto"

func appendNumbersToName(var name: String, #maxNumber: Int) -> String {
    for i in 0..<maxNumber {
        name += String(i + 1)
    }
    return name
}

appendNumbersToName(name, maxNumber:5)
// Mr. Robot12345

name
// Mr. Roboto
```

Note that this is different than an inout parameter—variable parameters do not change the external passed-in variable!

### Functions as Parameters

In Swift, functions can be passed around just like variables. For example, a function can have another function passed in as a parameter:

```swift
func luckyNumberForName(name: String, #lotteryHandler: (String, Int) -> String) -> String {
    let luckyNumber = Int(arc4random() % 100)
    return lotteryHandler(name, luckyNumber)
}

func defaultLotteryHandler(name: String, luckyNumber: Int) -> String {
    return "\(name), your lucky number is \(luckyNumber)"
}

luckyNumberForName("Mr. Roboto", lotteryHandler: defaultLotteryHandler)
// Mr. Roboto, your lucky number is 38
```

Note that only the function reference gets passed in—`defaultLotteryHandler` in this case. The function gets executed later as decided by the receiving function. 

Instance methods can also be passed in a similar way: 

```swift
func luckyNumberForName(name: String, #lotteryHandler: (String, Int) -> String) -> String {
    let luckyNumber = Int(arc4random() % 100)
    return lotteryHandler(name, luckyNumber)
}

class FunLottery {
    
    func defaultLotteryHandler(name: String, luckyNumber: Int) -> String {
        return "\(name), your lucky number is \(luckyNumber)"
    }
    
}

let funLottery = FunLottery()
luckyNumberForName("Mr. Roboto", lotteryHandler: funLottery.defaultLotteryHandler)
// Mr. Roboto, your lucky number is 38
```

To make your function definition a bit more readable, consider type-aliasing your function (similar to typedef in Objective-C): 

```swift
typealias lotteryOutputHandler = (String, Int) -> String

func luckyNumberForName(name: String, #lotteryHandler: lotteryOutputHandler) -> String {
    let luckyNumber = Int(arc4random() % 100)
    return lotteryHandler(name, luckyNumber)
}
```

You can also have a function without a name as a parameter type (similar to blocks in Objective-C): 

```swift
func luckyNumberForName(name: String, #lotteryHandler: (String, Int) -> String) -> String {
    let luckyNumber = Int(arc4random() % 100)
    return lotteryHandler(name, luckyNumber)
}

luckyNumberForName("Mr. Roboto", lotteryHandler: {name, number in
    return "\(name)'s' lucky number is \(number)"
})
// Mr. Roboto's lucky number is 74
```

In Objective-C, using blocks as parameters is popular for completion and error handlers in methods that execute an asynchronous operation. This should continue to be a popular pattern in Swift as well. 


## Access Controls

Swift has three levels of [Access Controls](https://developer.apple.com/library/prerelease/mac/documentation/Swift/Conceptual/Swift_Programming_Language/AccessControl.html): 

- **Public access** enables entities to be used within any source file from their defining module, and also in a source file from another module that imports the defining module. You typically use public access when specifying the public interface to a framework.
- **Internal access** enables entities to be used within any source file from their defining module, but not in any source file outside of that module. You typically use internal access when defining an app’s or a framework’s internal structure.
- **Private access** restricts the use of an entity to its own defining source file. Use private access to hide the implementation details of a specific piece of functionality.

By default, every function and variable is internal—if you want to change that, you have to use the `private` or `public` keyword in front of every single method and variable: 

```swift
public func myPublicFunc() {
    
}

func myInternalFunc() {
    
}

private func myPrivateFunc() {
    
}

private func myOtherPrivateFunc() {
    
}
```

Coming from Ruby, I prefer to put all my private functions at the bottom of my class, separated by a landmark: 

```swift 
class MyFunClass {
    
    func myInternalFunc() {
        
    }
    
    // MARK: Private Helper Methods
    
    private func myPrivateFunc() {
        
    }
    
    private func myOtherPrivateFunc() {
        
    }
}
```

Hopefully future releases of Swift will include an option to use one private keyword to indicate that all methods below it are private, similar to how access controls work in other programming languages.

## Fancy Return Types

In Swift, function return types and values can get a bit more complex than we're used to in Objective-C, especially with the introduction of optionals and multiple return types. 

### Optional Return Types

If there is a possibility that your function could return a nil value, you need to specify the return type as optional: 

```swift
func myFuncWithOptonalReturnType() -> String? {
    let someNumber = arc4random() % 100
    if someNumber > 50 {
        return "someString"
    } else {
        return nil
    }
}

myFuncWithOptonalReturnType()
```

And of course, when you're using the optional return value, don't forget to unwrap:

```swift
let optionalString = myFuncWithOptonalReturnType()

if let someString = optionalString {
    println("The function returned a value: \(someString)")
} else {
    println("The function returned nil")
}
```

The best explanation I've seen of optionals is from a [tweet by @Kronusdark](https://twitter.com/Kronusdark/status/496444128490967041): 

> I finally get @SwiftLang optionals, they are like Schrödinger's cat! You have to see if the cat is alive before you use it.

### Multiple Return Values

One of the most exciting features of Swift is the ability for a function to have multiple return values:

```swift 
func findRangeFromNumbers(numbers: Int...) -> (min: Int, max: Int) {

    var min = numbers[0]
    var max = numbers[0]
    
    for number in numbers {
        if number > max {
            max = number
        }
        
        if number < min {
            min = number
        }
    }
    
    return (min, max)
}

findRangeFromNumbers(1, 234, 555, 345, 423)
// (1, 555)
```

As you can see, the multiple return values are returned in a tuple, a very simple data structure of grouped values. There are two ways to use the multiple return values from the tuple: 

```swift
let range = findRangeFromNumbers(1, 234, 555, 345, 423)
println("From numbers: 1, 234, 555, 345, 423. The min is \(range.min). The max is \(range.max).")
// From numbers: 1, 234, 555, 345, 423. The min is 1. The max is 555.

let (min, max) = findRangeFromNumbers(236, 8, 38, 937, 328)
println("From numbers: 236, 8, 38, 937, 328. The min is \(min). The max is \(max)")
// From numbers: 236, 8, 38, 937, 328. The min is 8. The max is 937
```  

### Multiple Return Values and Optionals

The tricky part about multiple return values is when the return values can be optional, but there are two ways to handle dealing with optional multiple return values. 

In the above example function, my logic is flawed—it is possible that no values could be passed in, so my program would actually crash if that ever happened. If no values are passed in, I might want to make my whole return value optional: 

```swift
func findRangeFromNumbers(numbers: Int...) -> (min: Int, max: Int)? {

    if numbers.count > 0 {
        
        var min = numbers[0]
        var max = numbers[0]
        
        for number in numbers {
            if number > max {
                max = number
            }
            
            if number < min {
                min = number
            }
        }
        
        return (min, max)
    } else {
        return nil
    }
}

if let range = findRangeFromNumbers() {
    println("Max: \(range.max). Min: \(range.min)")
} else {
    println("No numbers!")
}
// No numbers!
```

In other cases, it might make sense to make each return value within a tuple optional, instead of making the whole tuple optional: 

```swift
func componentsFromUrlString(urlString: String) -> (host: String?, path: String?) {
    let url = NSURL(string: urlString)
    return (url.host, url.path)
}
``` 

If you decide that some of your tuple values could be optionals, things become a little bit more difficult to unwrap, since you have to consider every single combination of optional values: 

```swift
let urlComponents = componentsFromUrlString("http://name.com/12345;param?foo=1&baa=2#fragment")

switch (urlComponents.host, urlComponents.path) {
case let (.Some(host), .Some(path)):
    println("This url consists of host \(host) and path \(path)")
case let (.Some(host), .None):
    println("This url only has a host \(host)")
case let (.None, .Some(path)):
    println("This url only has path \(path). Make sure to add a host!")
case let (.None, .None):
    println("This is not a url!")
}
// This url consists of host name.com and path /12345
```

As you can see, this is not your average Objective-C way of doing things!

### Return a Function

Any function can also return a function in Swift: 

```swift
func myFuncThatReturnsAFunc() -> (Int) -> String {
    return { number in
        return "The lucky number is \(number)"
    }
}

let returnedFunction = myFuncThatReturnsAFunc()

returnedFunction(5) // The lucky number is 5
```

To make this more readable, you can of course use type-aliasing for your return function: 

```swift
typealias returnedFunctionType = (Int) -> String

func myFuncThatReturnsAFunc() -> returnedFunctionType {
    return { number in
        return "The lucky number is \(number)"
    }
}

let returnedFunction = myFuncThatReturnsAFunc()

returnedFunction(5) // The lucky number is 5
```

## Nested Functions
And in case you haven't had enough of functions from this post, it's always good to know that in Swift you can have a function inside a function:

```swift
func myFunctionWithNumber(someNumber: Int) {

    func increment(var someNumber: Int) -> Int {
        return someNumber + 10
    }
    
    let incrementedNumber = increment(someNumber)
    println("The incremeted number is \(incrementedNumber)")
}

myFunctionWithNumber(5)
// The incremeted number is 15
``` 

## @end
Swift functions have a lot of options and a lot of power. As you start writing in Swift, remember: with great power comes great responsibility. Optimize for READABILITY over cleverness! 

Swift best practices haven't been fully established yet, and the language is still constantly changing, so get your code reviewed by friends and co-workers. I've found that people who've never seen Swift before sometimes teach me the most about my Swift code.

Happy Swifting!

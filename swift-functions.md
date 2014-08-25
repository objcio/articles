The Many Faces of Swift Functions
=================================

Opening / Introduction

Swift Function Anatomy 
----------------------
Breakdown of what a basic hello world function looks like in Swift. 
* show example of basic no arguments / no return value function
* show example for basic return value type
* show example for passing in one argument
* emojis!

Parameter Names
---------------
* single parameter -> no external name
* single paramter -> diff external / internal name
* single parameter -> same external / internal name
* init -> same external / internal parameter name by defaulf. Use \_ to skip external parameter name. Show json-swift code as an example of great abstraction using _. 

Multiple Parameters
-------------------
* no external name - discuss how unreadable that is!
* using same external / internal parameter names to make functions with multiple params readable. 
* returning multiple parameters 

Using Optional Return Types
---------------------------
* Don't forget to unwrap!
* Examples for multipe return types with optionals - (foo, bar)? vs (foo?, bar?)

Default Parameter Values
------------------------
* example of function with default parameter
* examples of skipping default parameter when calling function
* note from apple: always put these in the end so it’s clear they’re all the same function

Variadic Parameters
-------------------
* example of variadic parameter
* point out that this is just a nicer looking array 
* don't forget the 0 elements use case!
* example of variadic parameter in function with multiple parameters

In/Out Parameters
-----------------
* example of inout parameter

Variable Parameters
-------------------
* use var keyword to manipulate your parameters internally (they're constants by default)

Generic Parameter Type
-----------------------
* example of function that uses a generic parameter type

Nested Functions
----------------
* example of using a nested function 

Closures
--------
* basic example of a closure in Swift
* point to more reading about closures

Variables as Functions
----------------------
* computed property example
* lazy property
* assigning function type to variable - include example with typealias. 

Access Controls
----------------
* internal by default
* use private / public keyword

Conclusion
----------
* With Great Power Comes Great Responsibility
* focus on READABILITY
* ask others to review your code - people come from diff programming backgrounds, so they might have some great insights even if they've never seen Swift!
* summary of best practices
---
title: "The Foundation Collection Classes"
category: "7"
date: "2013-12-09 11:00:00"
tags: article
author:
  - name: Peter Steinberger
    url: https://twitter.com/steipete
---


## NSArray, NSSet, NSOrderedSet, and NSDictionary

Foundation's collection classes are the basic building blocks of every Mac/iOS application. In this article, we're going to have an in-depth look at both the "old" (`NSArray`, `NSSet`) and the "new" (`NSMapTable`, `NSHashTable`, `NSPointerArray`) classes, explore detailed performance of each of them, and discuss when to use what.

Author Note: This article contains several benchmark results, however they are by no means meant to be exact and there's no variation/multiple runs applied. Their goal is to give you a direction of what's faster and general runtime statistics. All tests have been made on an iPhone 5s with Xcode 5.1b1 and iOS 7.1b1 and a 64-bit binary. Compiler settings were release built with -Ofast. Vectorize loops and unroll loops (default settings) have both been disabled .

### Big O Notation

First, we need some theoretical background. Performance is usually described with the [Big O Notation](https://en.wikipedia.org/wiki/Big_O_notation). It defines the *limiting behavior* of a function and is often used to characterize algorithms on their performance. O defines the upper bound of the growth rate of the function. To see just how big the difference is, see commonly used O notations and the number of operations needed.

![](/images/issue-7/big-o-notation.png)

For example, if you sort an array with 50 elements, and your sorting algorithm has a complexity of O(n^2), there will be 2,500 operations necessary to complete the task. Furthermore, there's also overhead in internal management and calling that method - so it's 2,500 operations times constant. O(1) is the ideal complexity, meaning constant time. [Good sorting algorithms usually need O(n\*log n) time.](http://en.wikipedia.org/wiki/Sorting_algorithm#Comparison_of_algorithms)

### Mutability

Most collection classes exist in two versions: mutable and immutable (default). This is quite different than most other frameworks and feels a bit weird at first. However, others are now adopting this as well: [.NET introduced immutable collections as an official extension](http://blogs.msdn.com/b/dotnet/archive/2013/09/25/immutable-collections-ready-for-prime-time.aspx) only a few months ago.

What's the big advantage? **Thread safety**. Immutable collections are fully thread safe and can be iterated from multiple threads at the same time, without any risk of mutation exceptions. Your API should *never* expose mutable collections.

Of course there's a cost when going from immutable and mutable and back - the object has to be copied twice, and all objects within will be retained/released. Sometimes it's more efficient to hold an internal mutable collection and return a copied, immutable object on access.

Unlike other frameworks, Apple does not provide thread-safe mutable variants of its collection classes, with the exception of `NSCache` - which really doesn't count since it's not meant to be a generic container. Most of the time, you really don't want synchronization at the collection level, but rather higher up in the hierarchy. Imagine some code that checks for the existence of a key in a dictionary, and depending on the result, sets a new key or returns something else - you usually want to group multiple operations together, and a thread-safe mutable variant would not help you here.

There are *some* valid use cases for a synchronized, thread-safe mutable collection, and it takes only a few lines to build something like that via subclassing and composition, e.g. for [`NSDictionary`](https://gist.github.com/steipete/7746843) or [NSArray](https://github.com/Cue/TheKitchenSync/blob/master/Classes/Collections/CueSyncArray.mm).

Notably, some of the more modern collection classes like `NSHashTable`, `NSMapTable`, and `NSPointerArray` are mutable by default and don't have immutable counterparts. They are meant for internal class use, and a use case where you would want those immutable would be quite unusual.

## NSArray

`NSArray` stores objects as ordered collections and is probably the most-used collection class. That's why it even got its own syntactic sugar syntax with the shorthand-literal `@[...]`, which is much shorter than the old `[NSArray arrayWithObjects:..., nil]`.

`NSArray` implements `objectAtIndexedSubscript:` and thus we can use a C-like syntax like `array[0]` instead of the older `[array objectAtIndex:0]`.

### Performance Characteristics

There's a lot more to `NSArray` than you might think, and it uses a variety of internal variants depending on how many objects are being stored. The most interesting part is that Apple doesn't guarantee O(1) access time on individual object access - as you can read in the note about Computational Complexity in the [CFArray.h CoreFoundation header](http://www.opensource.apple.com/source/CF/CF-855.11/CFArray.h):

>The access time for a value in the array is guaranteed to be at worst O(lg N) for any implementation, current and future, but will often be O(1) (constant time). Linear search operations similarly have a worst case complexity of O(N\*lg N), though typically the bounds will be tighter, and so on. Insertion or deletion operations will typically be linear in the number of values in the array, but may be O(N\*lg N) clearly in the worst case in some implementations. There are no favored positions within the array for performance; that is, it is not necessarily faster to access values with low indices, or to insert or delete values with high indices, or whatever.

When measuring, it turns out that `NSArray` has some [additional interesting performance characteristics](http://ridiculousfish.com/blog/posts/array.html). Inserting/deleting elements at the beginning/end is usually an O(1) operation, where random insertion/deletion usually will be O(N).

### Useful Methods

Most methods of `NSArray` use `isEqual:` to check against other objects (like `containsObject:`). There's a special method named `indexOfObjectIdenticalTo:` that goes down to pointer equality, and thus can speed up searching for objects a lot - if you can ensure that you're searching within the same set. 

With iOS 7, we finally got a public `firstObject` method, which joins `lastObject`, and both simply return `nil` for an empty array - regular access would throw an `NSRangeException`.

There's a nice detail about the construction of (mutable) arrays that can be used to save code. If you are creating a mutable array from a source that might be nil, you usually have some code like this:

```objc
NSMutableArray *mutableObjects = [array mutableCopy];
if (!mutableObjects) {
    mutableObjects = [NSMutableArray array];
}
```

or via the more concise [ternary operator](http://en.wikipedia.org/wiki/%3F:):
    
```objc
NSMutableArray *mutableObjects = [array mutableCopy] ?: [NSMutableArray array];
```

The better solution is to use the fact that `arrayWithArray:` will return an object in either way - even if the source array is nil:
    
```objc
NSMutableArray *mutableObjects = [NSMutableArray arrayWithArray:array];
```

The two operations are almost equal in performance. Using `copy` is a bit faster, but then again, it's highly unlikely that this will be your app bottleneck. **Side Note:** Please don't use `[@[] mutableCopy]`. The classic `[NSMutableArray array]` is a lot better to read.
    
Reversing an array is really easy: `array.reverseObjectEnumerator.allObjects`. We'll use the fact that `reverseObjectEnumerator` is pre-supplied and every `NSEnumerator` implements `allObjects`, which returns a new array. And while there's no native `randomObjectEnumerator`, you can write a custom enumerator that shuffles the array or use [some great open source options](https://github.com/mattt/TTTRandomizedEnumerator/blob/master/TTTRandomizedEnumerator/TTTRandomizedEnumerator.m).

### Sorting Arrays

There are various ways to sort an array. If it's string based, `sortedArrayUsingSelector:` is your first choice:

```objc
NSArray *array = @[@"John Appleseed", @"Tim Cook", @"Hair Force One", @"Michael Jurewitz"];
NSArray *sortedArray = [array sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
```

   
This works equally well for number-based content, since `NSNumber` implements `compare:` as well:
    
```objc
NSArray *numbers = @[@9, @5, @11, @3, @1];
NSArray *sortedNumbers = [numbers sortedArrayUsingSelector:@selector(compare:)];
```

For more control, you can use the function-pointer-based sorting methods:

```objc
- (NSData *)sortedArrayHint;
- (NSArray *)sortedArrayUsingFunction:(NSInteger (*)(id, id, void *))comparator 
                              context:(void *)context;
- (NSArray *)sortedArrayUsingFunction:(NSInteger (*)(id, id, void *))comparator 
                              context:(void *)context hint:(NSData *)hint;
```

Apple added an (opaque) way to speed up sorting using `sortedArrayHint`. 

>The hinted sort is most efficient when you have a large array (N entries) that you sort once and then change only slightly (P additions and deletions, where P is much smaller than N). You can reuse the work you did in the original sort by conceptually doing a merge sort between the N “old” items and the P “new” items. To obtain an appropriate hint, you use `sortedArrayHint` when the original array has been sorted, and keep hold of it until you need it (when you want to re-sort the array after it has been modified).

Since blocks are around, there are also the newer block-based sorting methods:

```objc
- (NSArray *)sortedArrayUsingComparator:(NSComparator)cmptr;
- (NSArray *)sortedArrayWithOptions:(NSSortOptions)opts 
                    usingComparator:(NSComparator)cmptr;
```

Performance-wise, there's not much difference between the different methods. Interestingly, the selector-based approach is actually the fastest. [You'll find the source code the benchmarks used here on GitHub.](https://github.com/steipete/PSTFoundationBenchmark):

`Sorting 1000000 elements. selector: 4947.90[ms] function: 5618.93[ms] block: 5082.98[ms].`
    
### Binary Search

`NSArray` has come with built-in [binary search](http://en.wikipedia.org/wiki/Binary_search_algorithm) since iOS 4 / Snow Leopard:

```objc
typedef NS_OPTIONS(NSUInteger, NSBinarySearchingOptions) {
        NSBinarySearchingFirstEqual     = (1UL << 8),
        NSBinarySearchingLastEqual      = (1UL << 9),
        NSBinarySearchingInsertionIndex = (1UL << 10),
};

- (NSUInteger)indexOfObject:(id)obj 
              inSortedRange:(NSRange)r 
                    options:(NSBinarySearchingOptions)opts 
            usingComparator:(NSComparator)cmp;
```

Why would you want to use this? Methods like `containsObject:` and `indexOfObject:` start at index 0 and search every object until the match is found - they don't require the array to be sorted but have a performance characteristic of O(n). Binary search, on the other hand, requires the array to be sorted, but only needs O(log n) time. Thus, for one million entries, binary search requires, at most, 21 comparisons, while the naive linear search would require an average of 500,000 comparisons.

Here's a simple benchmark of just how much faster binary search is:

`Time to search for 1000 entries within 1000000 objects. Linear: 54130.38[ms]. Binary: 7.62[ms]`

For comparison, the search for a specific index with `NSOrderedSet` took 0.23 ms - that's more than 30 times faster, even compared to binary search.

Keep in mind that sorting is expensive as well. Apple uses merge sort, which takes O(n\*log n), so if you just have to call `indexOfObject:` once, there's no need for binary search.

With specifying `NSBinarySearchingInsertionIndex`, you can find the correct insertion index to keep an already sorted array sorted after inserting new elements.

### Enumeration and Higher-Order Messaging

For a benchmark, we look at a common use case. Filter elements from an array into another array. This tests both the various enumeration ways, as well as the APIs specific to filtering:

```objc
// First variant, using `indexesOfObjectsWithOptions:passingTest:`.
NSIndexSet *indexes = [randomArray indexesOfObjectsWithOptions:NSEnumerationConcurrent 
                                                   passingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
    return testObj(obj);
}];
NSArray *filteredArray = [randomArray objectsAtIndexes:indexes];

// Filtering using predicates (block-based or text)    
NSArray *filteredArray2 = [randomArray filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, NSDictionary *bindings) {
    return testObj(obj);
}]];

// Block-based enumeration 
NSMutableArray *mutableArray = [NSMutableArray array];
[randomArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
    if (testObj(obj)) {
        [mutableArray addObject:obj];
    }
}];

// Classic enumeration
NSMutableArray *mutableArray = [NSMutableArray array];
for (id obj in randomArray) {
    if (testObj(obj)) {
        [mutableArray addObject:obj];
    }
}

// Using NSEnumerator, old school.
NSMutableArray *mutableArray = [NSMutableArray array];
NSEnumerator *enumerator = [randomArray objectEnumerator];
id obj = nil;
while ((obj = [enumerator nextObject]) != nil) {
    if (testObj(obj)) {
        [mutableArray addObject:obj];
    }
}

// Using objectAtIndex: (via subscripting)
NSMutableArray *mutableArray = [NSMutableArray array];
for (NSUInteger idx = 0; idx < randomArray.count; idx++) {
    id obj = randomArray[idx];
    if (testObj(obj)) {
        [mutableArray addObject:obj];
    }
}
```

<table><thead><tr><th style="text-align: left;padding-right:1em;">Enumeration Method / Time [ms]</th><th style="text-align:right;padding-right:1em;">10.000.000 elements</th><th style="text-align:right;padding-right:1em;">10.000 elements</th></tr></thead><tbody><tr><td style="text-align: left;"><code>indexesOfObjects:</code>, concurrent</td><td style="text-align: right;padding-right:1em;">1844.73</td><td style="text-align: right;padding-right:1em;">2.25</td>
</tr><tr><td style="text-align: left;padding-right:1em;"><code>NSFastEnumeration</code> (<code>for in</code>)</td><td style="text-align: right;padding-right:1em;">3223.45</td><td style="text-align: right;padding-right:1em;">3.21</td>
</tr><tr><td style="text-align: left;padding-right:1em;"><code>indexesOfObjects:</code></td><td style="text-align: right;padding-right:1em;">4221.23</td><td style="text-align: right;padding-right:1em;">3.36</td>
</tr><tr><td style="text-align: left;padding-right:1em;"><code>enumerateObjectsUsingBlock:</code></td><td style="text-align: right;padding-right:1em;">5459.43</td><td style="text-align: right;padding-right:1em;">5.43</td>
</tr><tr><td style="text-align: left;padding-right:1em;"><code>objectAtIndex:</code></td><td style="text-align: right;padding-right:1em;">5282.67</td><td style="text-align: right;padding-right:1em;">5.53</td>
</tr><tr><td style="text-align: left;padding-right:1em;"><code>NSEnumerator</code></td><td style="text-align: right;padding-right:1em;">5566.92</td><td style="text-align: right;padding-right:1em;">5.75</td>
</tr><tr><td style="text-align: left;padding-right:1em;"><code>filteredArrayUsingPredicate:</code></td><td style="text-align: right;padding-right:1em;">6466.95</td><td style="text-align: right;padding-right:1em;">6.31</td>
</tr></tbody></table>
    
    
To better understand the performance measured here, we first have to look at how the array is enumerated. 

`indexesOfObjectsWithOptions:passingTest:` has to call a block each time and thus is slightly less efficient than the classical for-based enumeration that uses the `NSFastEnumeration` technique. However, if we enable concurrent enumeration on the former, then it wins by a wide margin, and is almost twice as fast. Which makes sense, considering that the iPhone 5s has two cores. What's not visible here is that `NSEnumerationConcurrent` only makes sense for a large number of objects - if your data set is small, it really doesn't matter much what method you are going to use. Even worse, the additional thread management overhead for `NSEnumerationConcurrent` will actually make results slower than without.

The real "loser" here is `filteredArrayUsingPredicate:`. `NSPredicate` still has a reason to be mentioned here, since one can write [quite sophisticated expressions](http://nshipster.com/nspredicate/), especially with the non-block-based variant. People who use Core Data should be familiar with that.

For completeness, we also added a benchmark using `NSEnumerator` - however there really is no reason to use this anymore. While it is surprisingly fast (still faster than using the `NSPredicate`-based filtering), it certainly has more runtime overhead than fast enumeration - nowadays it only exists for backward compatibility. Even a non-optimized access for via `objectAtIndex:` is faster here.

### NSFastEnumeration

Apple added [`NSFastEnumeration`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/NSFastEnumeration_protocol/Reference/NSFastEnumeration.html) in OS X 10.5 and it has been in iOS ever since the first release. Before that, there was `NSEnumeration`, which returned one element at a time, and thus as quite a runtime overhead with each iteration. With fast enumeration, Apple returns a chunk of data with `countByEnumeratingWithState:objects:count:`. The chunk is parsed as a C array of `id`s. This is where the additional speed comes from; iterating a C array is much faster, and can potentially be even further optimized by the compiler. Manually implementing fast enumeration is quite tricky, so Apple's [FastEnumerationSample](https://developer.apple.com/library/ios/samplecode/FastEnumerationSample/Introduction/Intro.html) is a good starting point, and there's also [an excellent article by Mike Ash on this topic](http://www.mikeash.com/pyblog/friday-qa-2010-04-16-implementing-fast-enumeration.html).


### Should I Use arrayWithCapacity:?

When initializing `NSArray`, you can optionally specify the expected count. When benchmarking this, it turns out that there is no difference in performance - the measured timings are almost equal and within the statistical uncertainty. A little birdie at Apple told me that this hint is indeed not used. However, using `arrayWithCapacity:` can still be useful, as it can help understanding the code as part of an implicit documentation:

`Adding 10.000.000 elements to NSArray. no count 1067.35[ms] with count: 1083.13[ms].`


### Subclassing Notes
There is rarely a reason why you would want to subclass the basic collection classes. Most of the time, the better solution is going down to CoreFoundation level and using custom callbacks to customize the behavior.

To create a case-insensitive dictionary, one could subclass `NSDictionary` and write custom accessors that always lowercase (or uppercase) the string, and similar changes for storing. The better and faster solution is to instead provide a different set of `CFDictionaryKeyCallBacks` where you can provide custom `hash` and `isEqual:` callbacks. [You'll find an example in this gist](https://gist.github.com/steipete/7739473). The beauty is that - thanks to [toll-free bridging](https://developer.apple.com/library/ios/documentation/General/Conceptual/CocoaEncyclopedia/Toll-FreeBridgin/Toll-FreeBridgin.html) - it's still a simple dictionary and can be consumed by any API that takes an `NSDictionary`.

One example where a subclass is useful is the use case for an ordered dictionary. .NET has a `SortedDictionary`, Java has `TreeMap`, C++ has `std::map`. While you *could* use C++'s STL container, you won't get any automated `retain/release`, which would make using those much more cumbersome. Because `NSDictionary` is a [class cluster](https://developer.apple.com/library/ios/documentation/general/conceptual/CocoaEncyclopedia/ClassClusters/ClassClusters.html), subclassing is quite different than one would expect. It's outside of the boundaries of this article, but one [real-world example of an ordered dictionary is here](https://github.com/nicklockwood/OrderedDictionary/blob/master/OrderedDictionary/OrderedDictionary.m).

## NSDictionary

A dictionary stores arbitrary key/value pairs of objects. For historical reasons, the initializer uses the reversed object to key notation, `[NSDictionary dictionaryWithObjectsAndKeys:object, key, nil],` while the newer literal shorthand starts with key `@{key : value, ...}`.

Keys in `NSDictionary` are copied and they need to be constant. If the key changes after being used to put a value in the dictionary, the value may not be retrievable.
As an interesting detail, keys are copied when using an `NSDictionary`, but are only retained when using a toll-free bridged `CFDictionary`. There's no notion of a generic object copy for CoreFoundation-classes, thus copy wasn't possible at that time (\*). This only applies if you use `CFDictionarySetValue()`. If you use a toll-free bridged `CFDictionary` via `setObject:forKey`, Apple added additional logic that will still copy your key. This does not work the other way around - using an `NSDictionary` object casted to `CFDictionary` and used via `CFDictionarySetValue()` will call back to `setObject:forKey` and copy the key.

(\*) There is one prepared key callback `kCFCopyStringDictionaryKeyCallBacks` that will copy strings, and because `CFStringCreateCopy()` calls back to `[NSObject copy]` for an ObjC class we could abuse this callback to create a key-copying `CFDictionary`.

### Performance Characteristics

Apple is rather quiet when it comes to defining computational complexity. The only note around this can be found in the [CoreFoundation headers of `CFDictionary`](http://www.opensource.apple.com/source/CF/CF-855.11/CFDictionary.h):

>The access time for a value in the dictionary is guaranteed to be at worst O(N) for any implementation, current and future, but will often be O(1) (constant time). Insertion or deletion operations will typically be constant time as well, but are O(N\*lg N) in the worst case in some implementations. Access of values through a key is faster than accessing values directly (if there are any such operations). Dictionaries will tend to use significantly more memory than a array with the same number of values.

The dictionary - much like array - uses different implementations depending on the size and switches between them transparently.

### Enumeration and Higher-Order Messaging

Again, there are several ways how to best filter a dictionary:

```objc
// Using keysOfEntriesWithOptions:passingTest:,optionally concurrent
NSSet *matchingKeys = [randomDict keysOfEntriesWithOptions:NSEnumerationConcurrent 
                                               passingTest:^BOOL(id key, id obj, BOOL *stop) 
{
    return testObj(obj);
}];
NSArray *keys = matchingKeys.allObjects;
NSArray *values = [randomDict objectsForKeys:keys notFoundMarker:NSNull.null];
__unused NSDictionary *filteredDictionary = [NSDictionary dictionaryWithObjects:values 
                                                                        forKeys:keys];    
    
// Block-based enumeration.
NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
[randomDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    if (testObj(obj)) {
        mutableDictionary[key] = obj;
    }
}];

// NSFastEnumeration
NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
for (id key in randomDict) {
    id obj = randomDict[key];
    if (testObj(obj)) {
        mutableDictionary[key] = obj;
    }
}

 // NSEnumeration
 NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
 NSEnumerator *enumerator = [randomDict keyEnumerator];
 id key = nil;
 while ((key = [enumerator nextObject]) != nil) {
       id obj = randomDict[key];
       if (testObj(obj)) {
           mutableDictionary[key] = obj;
       }
 }

// C-based array enumeration via getObjects:andKeys:
NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionary];
id __unsafe_unretained objects[numberOfEntries];
id __unsafe_unretained keys[numberOfEntries];
[randomDict getObjects:objects andKeys:keys];
for (int i = 0; i < numberOfEntries; i++) {
    id obj = objects[i];
    id key = keys[i];
    if (testObj(obj)) {
       mutableDictionary[key] = obj;
    }
 }
```

<table><thead><tr><th style="text-align: left;min-width:22em;">Filtering/Enumeration Method</th><th style="text-align: right;">Time [ms], 50.000 elements</th><th style="text-align: right;">1.000.000 elements</th></tr></thead><tbody><tr><td style="text-align: left;"><code>keysOfEntriesWithOptions:</code>, concurrent</td><td style="text-align: right;">16.65</td><td style="text-align: right;">425.24</td>
</tr><tr><td style="text-align: left;"><code>getObjects:andKeys:</code></td><td style="text-align: right;">30.33</td><td style="text-align: right;">798.49*</td>
</tr><tr><td style="text-align: left;"><code>keysOfEntriesWithOptions:</code></td><td style="text-align: right;">30.59</td><td style="text-align: right;">856.93</td>
</tr><tr><td style="text-align: left;"><code>enumerateKeysAndObjectsUsingBlock:</code></td><td style="text-align: right;">36.33</td><td style="text-align: right;">882.93</td>
</tr><tr><td style="text-align: left;"><code>NSFastEnumeration</code></td><td style="text-align: right;">41.20</td><td style="text-align: right;">1043.42</td>
</tr><tr><td style="text-align: left;"><code>NSEnumeration</code></td><td style="text-align: right;">42.21</td><td style="text-align: right;">1113.08</td>
</tr></tbody></table>


(\*) There's a caveat when using `getObjects:andKeys:`. In the above code example, we're using a C99 feature called [variable-length arrays](http://gcc.gnu.org/onlinedocs/gcc/Variable-Length.html) (as normally, the array count needs to be a fixed variable). This will allocate memory on the stack, which is a bit more convenient, but also limited. The above code example will crash for a large number of elements, so use `malloc`/`calloc`-based allocation (and `free`) to be on the safe side.

Why is `NSFastEnumeration` so slow here? Iterating the dictionary usually requires both key and object; fast enumeration can only help for the key, and we have to fetch the object every time ourselves. Using the block-based `enumerateKeysAndObjectsUsingBlock:` is more efficient since both objects can be more efficiently prefetched. 

The winner - again - is concurrent iteration via `keysOfEntriesWithOptions:passingTest:` and `objectsForKeys:notFoundMarker:`. This is a bit more code, but this can be nicely encapsulated in a category. 

### Should I Use dictionaryWithCapacity:?

By now you already now how this test works, and the short answer is NO, the `count` parameter doesn't change anything:

`Adding 10000000 elements to `NSDictionary`. no count 10786.60[ms] with count: 10798.40[ms].`

### Sorting

There's not much to say about dictionary sorting. You can only sort the key array as a new object, thus you can use any of the regular `NSArray` sorting methods as well:

```objc
- (NSArray *)keysSortedByValueUsingSelector:(SEL)comparator;
- (NSArray *)keysSortedByValueUsingComparator:(NSComparator)cmptr;
- (NSArray *)keysSortedByValueWithOptions:(NSSortOptions)opts 
                          usingComparator:(NSComparator)cmptr;
```

### Shared Keys

Starting with iOS 6 and 10.8, it's possible to have a pre-generated key set for a new dictionary, using `sharedKeySetForKeys:` to create the key set from an array, and `dictionaryWithSharedKeySet:` to create the dictionary. Usually `NSDictionary` copies its keys. When using a shared key set it will instead reuse those objects, which saves memory. According to the [Foundation Release Notes](https://developer.apple.com/library/mac/releasenotes/Foundation/RN-FoundationOlderNotes/), `sharedKeySetForKeys:` will calculate a minimal perfect hash that eliminates any need for probe looping during a dictionary lookup, thus making keyed access even faster.

This makes it perfect for use cases like a JSON parser, although in our limited testing we couldn't see Apple using it in `NSJSONSerialization`. (Dictionaries created with shared key sets are of subclass `NSSharedKeyDictionary`; regular dictionaries are `__NSDictionaryI`/`__NSDictionaryM`, with I/M indicating mutability; and toll-free bridged dictionaries are of class `_NSCFDictionary`, both mutable and immutable variants.)

**Interesting detail**: Shared-key dictionaries are **always mutable**, even when calling 'copy' on them. This behavior is not documented but can be easily tested:

```objc
id sharedKeySet = [NSDictionary sharedKeySetForKeys:@[@1, @2, @3]]; // returns NSSharedKeySet
NSMutableDictionary *test = [NSMutableDictionary dictionaryWithSharedKeySet:sharedKeySet];
test[@4] = @"First element (not in the shared key set, but will work as well)";
NSDictionary *immutable = [test copy];
NSParameterAssert(immutable == 1);
((NSMutableDictionary *)immutable)[@5] = @"Adding objects to an immutable collection should throw an exception.";
NSParameterAssert(immutable == 2);
```

 

## NSSet

`NSSet` and its mutable variant `NSMutableSet` are an unordered collection of objects. Checking for existence is usually an O(1) operation, making this much faster for this use case than `NSArray`. `NSSet` can only work efficiently if the hashing method used is balanced; if all objects are in the same hash bucket, then `NSSet` is not much faster in object-existence checking than `NSArray`.

Variants of `NSSet` are also `NSCountedSet`, and the non-toll-free counter-variant `CFBag`/`CFMutableBag`.

`NSSet` retains its object, but per the set contract, that object needs to be immutable. Adding objects to a set and then later changing that object will result in weird bugs and will corrupt the state of the set.

`NSSet` has far less methods than `NSArray`. There is no sorting method but there are a few convenience enumeration methods. Some important methods are `allObjects` to convert the objects into an `NSArray` and `anyObject`, which returns either any object or nil, if the set is empty. 

### Set Manipulation

`NSMutableSet` has several powerful set methods like `intersectSet:`, `minusSet:`, and `unionSet:`.

![Set-Union](/images/issue-7/set.png)

### Should I Use setWithCapacity:?

Again, we test if there is any noticeable speed difference when we initialize a set with a given capacity:

`Adding 1.000.000 elements to `NSSet`. no count 2928.49[ms] with count: 2947.52[ms].`

This falls under measurement uncertainty - there's no noticeable time difference. There is [evidence that at least in the previous version of the runtime, this had much more of a performance impact](http://www.cocoawithlove.com/2008/08/nsarray-or-nsset-nsdictionary-or.html).

### Performance Characteristics of NSSet

Apple doesn't provide any notes about the computational complexity in the [CFSet headers](http://www.opensource.apple.com/source/CF/CF-855.11/CFSet.h): 

<table><thead><tr><th style="text-align: left;">Class / Time [ms]</th><th style="text-align: right;">1.000.000 elements</th></tr></thead><tbody><tr><td style="text-align: left;"><code>NSMutableSet</code>, adding</td><td style="text-align: right;">2504.38</td>
</tr><tr><td style="text-align: left;"><code>NSMutableArray</code>, adding</td><td style="text-align: right;">1413.38</td>
</tr><tr><td style="text-align: left;"><code>NSMutableSet</code>, random access</td><td style="text-align: right;">4.40</td>
</tr><tr><td style="text-align: left;"><code>NSMutableArray</code>, random access</td><td style="text-align: right;">7.95</td>
</tr></tbody></table>

This benchmark is pretty much what we expected: `NSSet` calls `hash` and `isEqual:` on each added object and manages a buckets of hashes, so it takes more time on adding elements. Random access is hard to test with a set, since all there is is `anyObject`.

There was no need for including `containsObject:` in the benchmark. It is magnitudes faster on a set - that's their speciality, after all.

## NSOrderedSet
`NSOrderedSet` was first introduced in iOS 5 and Mac OS X 10.7, and there's almost no API directly using it, except for CoreData. It seems like a great class with the best of both `NSArray` and `NSSet`: having the benefits of instant object-existence checking, uniqueness, and fast random access.

`NSOrderedSet` has great API methods, which makes it convenient to work with other set or ordered set objects. Union, intersection, and minus are supported just like in `NSSet`. It has most of the sort methods that are in `NSArray`, with the exception of the old function-based sort methods and binary search - after all, `containsObject:` is super fast, so there's no need for that.

The `array` and `set` accessors will respectively return an `NSArray` or `NSSet`, but with a twist! Those objects are facade objects that act like immutable objects and will update themselves as the ordered set is updated. This is good to know when you're planning to iterate those objects on different threads and get mutation exceptions. Internally, the classes used are are `__NSOrderedSetSetProxy` and `__NSOrderedSetArrayProxy`.

Side Note: If you're wondering why `NSOrderedSet` isn't a subclass of `NSSet`, there's [a great article on NSHipster explaining the downsides of mutable/immutable class clusters](http://nshipster.com/nsorderedset/).

### Performance Characteristics of NSOrderedSet

If you look at this benchmark, you see where `NSOrderedSet` starts getting expensive. All those benefits can't come for free:

<table><thead><tr><th style="text-align: left;">Class / Time [ms]</th><th style="text-align: right;">1.000.000 elements</th></tr></thead><tbody><tr><td style="text-align: left;"><code>NSMutableOrderedSet</code>, adding</td><td style="text-align: right;"><strong>3190.52</strong></td>
</tr><tr><td style="text-align: left;"><code>NSMutableSet</code>, adding</td><td style="text-align: right;">2511.96</td>
</tr><tr><td style="text-align: left;"><code>NSMutableArray</code>, adding</td><td style="text-align: right;">1423.26</td>
</tr><tr><td style="text-align: left;"><code>NSMutableOrderedSet</code>, random access</td><td style="text-align: right;"><strong>10.74</strong></td>
</tr><tr><td style="text-align: left;"><code>NSMutableSet</code>, random access</td><td style="text-align: right;">4.47</td>
</tr><tr><td style="text-align: left;"><code>NSMutableArray</code>, random access</td><td style="text-align: right;">8.08</td>
</tr></tbody></table>


This benchmark adds custom strings to each of these collection classes, and later randomly accesses those.

`NSOrderedSet` will also take up more memory than either `NSSet` or `NSArray`, since it needs to maintain both hashed values and indexes.

## NSHashTable

`NSHashTable` is modeled after `NSSet`, but is much more flexible when it comes to object/memory handling. While some of the features of `NSHashTable` can be achieved via custom callbacks on `CFSet`, hash table can hold objects weakly and will properly nil out itself when the object is deallocated - something that would be quite ugly when manually added to an `NSSet`. It's also mutable by default - there is no immutable counterpart.

`NSHashTable` has both an ObjC and a raw C API, where the C API can be used to store arbitrary objects. Apple introduced this class in 10.5 Leopard, but only added it quite recently in iOS 6. Interestingly enough, they only ported the ObjC API; the more powerful C API is excluded on iOS.

`NSHashTable` is wildly configurable via the `initWithPointerFunctions:capacity:` - we're only picking the most common use cases, which are also predefined using `hashTableWithOptions:`. The most useful option has its own convenience constructor via `weakObjectsHashTable`.

### NSPointerFunctions

These pointer functions are valid for `NSHashTable`, `NSMapTable`, and `NSPointerArray`, and define the acquisition and retention behavior for the objects saved in these collections. Here are the most useful options. For the full list, see `NSPointerFunctions.h`.

There are two groups of options. Memory options determine memory management, and personalities define hashing and equality.

`NSPointerFunctionsStrongMemory` creates a collection that retains/releases objects, much like a regular `NSSet` or `NSArray`.
     
`NSPointerFunctionsWeakMemory` uses an equivalent of `__weak` to store objects and will automatically evict deallocated objects.

`NSPointerFunctionsCopyIn` copies the objects before they are added to the collection. 


`NSPointerFunctionsObjectPersonality` uses `hash` and `isEqual:` from the object (default). 

`NSPointerFunctionsObjectPointerPersonality` uses direct-pointer comparison for `isEqual:` and `hash`.

### Performance Characteristics of NSHashTable

<table><thead><tr><th style="text-align: left;">Class / Time [ms]</th><th style="text-align: right;">1.000.000 elements</th></tr></thead><tbody><tr><td style="text-align: left;"><code>NSHashTable</code>, adding</td><td style="text-align: right;">2511.96</td>
</tr><tr><td style="text-align: left;"><code>NSMutableSet</code>, adding</td><td style="text-align: right;">1423.26</td>
</tr><tr><td style="text-align: left;"><code>NSHashTable</code>, random access</td><td style="text-align: right;">3.13</td>
</tr><tr><td style="text-align: left;"><code>NSMutableSet</code>, random access</td><td style="text-align: right;">4.39</td>
</tr><tr><td style="text-align: left;"><code>NSHashTable</code>, containsObject</td><td style="text-align: right;">6.56</td>
</tr><tr><td style="text-align: left;"><code>NSMutableSet</code>, containsObject</td><td style="text-align: right;">6.77</td>
</tr><tr><td style="text-align: left;"><code>NSHashTable</code>, NSFastEnumeration</td><td style="text-align: right;">39.03</td>
</tr><tr><td style="text-align: left;"><code>NSMutableSet</code>, NSFastEnumeration</td><td style="text-align: right;">30.43</td>
</tr></tbody></table>


If you just need the features of an `NSSet`, then stick at `NSSet`. `NSHashTable` takes almost twice as long to add objects, but has quite similar performance characteristics.

## NSMapTable

`NSMapTable` is similar to `NSHashTable`, but modeled after `NSDictionary`. Thus, we can control object acquisition/retention for both the keys and objects separately, via `mapTableWithKeyOptions:valueOptions:`. Since storing one part weak is again the most useful feature of `NSMapTable`, there are now four convenience constructors for this use case:

* `strongToStrongObjectsMapTable`
* `weakToStrongObjectsMapTable`
* `strongToWeakObjectsMapTable`
* `weakToWeakObjectsMapTable`

Note that - unless created with `NSPointerFunctionsCopyIn` - any of the defaults will retain (or weakly reference) the key object, and not copy it, thus matching the behavior of `CFDictionary` and not `NSDictionary`. This can be quite useful if you need a dictionary whose key does not implement `NSCopying`, like `UIView`.

If you're wondering why Apple "forgot" adding subscripting to `NSMapTable`, you now know why. Subscripting requires an `id<NSCopying>` as key, which is not necessary for `NSMapTable`. There's no way to add subscripting to it without having an invalid API contract or weakening subscripting globally with removing the `NSCopying` protocol.

You can convert the contents to an ordinary `NSDictionary` using `dictionaryRepresentation`. This returns a regular dictionary and not a proxy - unlike `NSOrderedSet`:

### Performance of NSMapTable

<table><thead><tr><th style="text-align: left;">Class / Time [ms]</th><th style="text-align: right;">1.000.000 elements</th></tr></thead><tbody><tr><td style="text-align: left;"><code>NSMapTable</code>, adding</td><td style="text-align: right;">2958.48</td>
</tr><tr><td style="text-align: left;"><code>NSMutableDictionary</code>, adding</td><td style="text-align: right;">2522.47</td>
</tr><tr><td style="text-align: left;"><code>NSMapTable</code>, random access</td><td style="text-align: right;">13.25</td>
</tr><tr><td style="text-align: left;"><code>NSMutableDictionary</code>, random access</td><td style="text-align: right;">9.18</td>
</tr></tbody></table>

`NSMapTable` is only marginally slower than `NSDictionary`. If you need a dictionary that doesn't retain its keys, go for it, and leave `CFDictionary` behind.

## NSPointerArray

The `NSPointerArray` class is a sparse array that works similar to an `NSMutableArray`, but can also hold `NULL` values, and the `count` method will reflect those empty spots. It can be configured with various options from `NSPointerFunctions`, and has convenience constructors for the common use cases, `strongObjectsPointerArray`, and `weakObjectsPointerArray`.

Before you can use `insertPointer:atIndex:`, we need to make space by directly setting the `count` property, or you will get an exception. Alternatively, using `addPointer:` will automatically increase array size if needed.

You can convert an `NSPointerArray` into a regular `NSArray` via `allObjects`. In that case, all `NULL` values are compacted, and only existing objects are added - thus the object indexes of this array will most likely be different than in the pointer array. Careful: if you are storing anything other than objects into the pointer array, attempting to call `allObjects` will crash with `EXC_BAD_ACCESS`, as it tries to retain the "objects" one by one.

From a debugging point of view, `NSPointerArray` didn't get much love. The `description` method simply returns `<NSConcretePointerArray: 0x17015ac50>`. To get to the objects you need to, call `[pointerArray allObjects]`, which, of course, will change the indexes if there are any `NULLs` in between.

### Performance of NSPointerArray

When it comes to performance, `NSPointerArray` is really, really slow, so think twice if you plan to use it on a large data set. In our benchmark we're comparing `NSMutableArray` with `NSNull` as an empty marker and `NSPointerArray` with a `NSPointerFunctionsStrongMemory` configuration (so that objects are properly retained). Then in an array of 10,000 elements, we fill every tenth entry with a string "Entry %d". The benchmark includes the total time it takes for `NSMutableArray` to be filled with `NSNull.null`. For `NSPointerArray`, we use `setCount:` instead:


<table><thead><tr><th style="text-align: left;">Class / Time [ms]</th><th style="text-align: right;">10.000 elements</th></tr></thead><tbody><tr><td style="text-align: left;"><code>NSMutableArray</code>, adding</td><td style="text-align: right;">15.28</td>
</tr><tr><td style="text-align: left;"><code>NSPointerArray</code>, adding</td><td style="text-align: right;"><strong>3851.51</strong></td>
</tr><tr><td style="text-align: left;"><code>NSMutableArray</code>, random access</td><td style="text-align: right;">0.23</td>
</tr><tr><td style="text-align: left;"><code>NSPointerArray</code>, random access</td><td style="text-align: right;">0.34</td>
</tr></tbody></table>

Notice that `NSPointerArray` requires more than **250x (!)** more time than `NSMutableArray`. This is really surprising and unexpected. Tracking memory is harder and it's likely that `NSPointerArray` is more efficient here, but since we use one shared instance for `NSNull` to mark empty objects, there shouldn't be much overhead except pointers.

## NSCache
`NSCache` is quite an odd collection. Added in iOS 4 / Snow Leopard, it's mutable by default, and also **thread safe**. This makes it perfect to cache objects that are expensive to create. It automatically reacts to memory warnings and will clean itself up based on a configurable "cost.” In contrast to `NSDictionary`, keys are retained and not copied.

The eviction method of `NSCache` is non-deterministic and not documented. It's not a good idea to put in super-large objects like images that might fill up your cache faster than it can evict itself. (This was the case of many memory-related crashes in [PSPDFKit](http://PSPDFKit.com), where we initially used `NSCache` for storing pre-rendered images of pages, before switching to custom caching code based on a LRU linked list.)

`NSCache` can also be configured to automatically evict objects that implement the `NSDiscardableContent` protocol. A popular class implementing this property is `NSPurgeableData`, which as been added at the same time, but was ["not fully thread safe" until OS X 10.9 (there's no information if this has affected iOS as well, or if this fix landed in iOS 7)](https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#//apple_ref/doc/uid/TP30000742).

### Performance of NSCache

So how does `NSCache` hold up compared to an `NSMutableDictionary`? The added thread safety surely takes some overhead. Out of curiosity, I've also added a custom, thread-safe dictionary subclass ([`PSPDFThreadSafeMutableDictionary`](https://gist.github.com/steipete/5928916)) that synchronizes access via an `OSSpinLock`:

<table><thead><tr><th style="text-align: left;min-width:28em;">Class / Time [ms]</th><th style="text-align: right;">1.000.000 elements</th><th style="text-align: right;">iOS 7x64 Simulator</th><th style="text-align: right;">iPad Mini iOS 6</th></tr></thead><tbody><tr><td style="text-align: left;"><code>NSMutableDictionary</code>, adding</td><td style="text-align: right;">195.35</td><td style="text-align: right;">51.90</td><td style="text-align: right;">921.02</td>
</tr><tr><td style="text-align: left;"><code>PSPDFThreadSafeMutableDictionary</code>, adding</td><td style="text-align: right;">248.95</td><td style="text-align: right;">57.03</td><td style="text-align: right;">1043.79</td>
</tr><tr><td style="text-align: left;"><code>NSCache</code>, adding</td><td style="text-align: right;">557.68</td><td style="text-align: right;">395.92</td><td style="text-align: right;">1754.59</td>
</tr><tr><td style="text-align: left;"><code>NSMutableDictionary</code>, random access</td><td style="text-align: right;">6.82</td><td style="text-align: right;">2.31</td><td style="text-align: right;">23.70</td>
</tr><tr><td style="text-align: left;"><code>PSPDFThreadSafeMutableDictionary</code>, random access</td><td style="text-align: right;">9.09</td><td style="text-align: right;">2.80</td><td style="text-align: right;">32.33</td>
</tr><tr><td style="text-align: left;"><code>NSCache</code>, random access</td><td style="text-align: right;">9.01</td><td style="text-align: right;"><strong>29.06</strong></td><td style="text-align: right;">53.25</td>
</tr></tbody></table>


`NSCache` holds up pretty well, and random access is equally fast as our custom thread-safe dictionary. Adding is slower, as expected, because `NSCache` also keeps an optional cost factor around, has to determine when to evict objects, and so on - it's not a very fair comparison in that regard. Interestingly, it performs almost ten times worse when run in the Simulator. This is true for all variants, 32 or 64 bit. It also looks like it has been optimized in iOS 7 or simply benefits from the 64-bit runtime. When testing with an older device, the performance overhead of using `NSCache` is far more noticeable.

The difference between iOS 6 (32 bit) and iOS 7 (64 bit) is also far more noticeable since the 64-bit runtime uses [tagged pointers](http://www.mikeash.com/pyblog/friday-qa-2012-07-27-lets-build-tagged-pointers.html), and thus our `@(idx)` boxing is much more efficient there.

## NSIndexSet

There are a few use cases where `NSIndexSet` (and its mutable variant, `NSMutableIndexSet`) really shines, and you will find various usages throughout Foundation. It can save a collection of unsigned integers in a very efficient way, especially if it's only one or a few ranges. As the name "set" already implies, each `NSUInteger` is either in the index set or isn't. If you need to store an arbitrary number of integers that are not unique, better use an `NSArray`. 

This is how you would convert an array of integers to an `NSIndexSet`:

```objc
NSIndexSet *PSPDFIndexSetFromArray(NSArray *array) {
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    for (NSNumber *number in array) {
        [indexSet addIndex:[number unsignedIntegerValue]];
    }
    return [indexSet copy];
}
```

Getting all indexes out of the index set was a bit fiddly before we had blocks, with `getIndexes:maxCount:inIndexRange:` being the fastest way, next to using `firstIndex` and iterating until `indexGreaterThanIndex:` returned `NSNotFound`. With the arrival of blocks, working with `NSIndexSet` has become a lot more convenient:

```objc
NSArray *PSPDFArrayFromIndexSet(NSIndexSet *indexSet) {
    NSMutableArray *indexesArray = [NSMutableArray arrayWithCapacity:indexSet.count];
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
       [indexesArray addObject:@(idx)];
    }];
    return [indexesArray copy];
}
```

### Performance of NSIndexSet

There's no equivalent to `NSIndexSet` in Core Foundation, and Apple doesn't make any promises to performance. A comparison between `NSIndexSet` and `NSSet` is also relatively unfair to begin with, since the regular set requires boxing for the numbers. To mitigate this, the benchmark will prepare pre-boxed `NSUInteger`s, and will call `unsignedIntegerValue` on both loops:

<table><thead><tr><th style="text-align: left;min-width:20em;">Class / Time per Entries [ms]</th><th style="text-align: right;">#1.000</th><th style="text-align: right;">#10.000</th><th style="text-align: right;">#1.000.000</th><th style="text-align: right;">#10.000.000</th><th style="text-align: right;">#1.000.000, iPad Mini iOS 6</th></tr></thead><tbody><tr><td style="text-align: left;"><code>NSIndexSet</code>, adding</td><td style="text-align: right;">0.28</td><td style="text-align: right;">4.58</td><td style="text-align: right;">98.60</td><td style="text-align: right;">9396.72</td><td style="text-align: right;">179.27</td>
</tr><tr><td style="text-align: left;"><code>NSSet</code>, adding</td><td style="text-align: right;">0.30</td><td style="text-align: right;">2.60</td><td style="text-align: right;">8.03</td><td style="text-align: right;">91.93</td><td style="text-align: right;">37.43</td>
</tr><tr><td style="text-align: left;"><code>NSIndexSet</code>, random access</td><td style="text-align: right;">0.10</td><td style="text-align: right;">1.00</td><td style="text-align: right;">3.51</td><td style="text-align: right;">58.67</td><td style="text-align: right;">13.44</td>
</tr><tr><td style="text-align: left;"><code>NSSet</code>, random access</td><td style="text-align: right;">0.17</td><td style="text-align: right;">1.32</td><td style="text-align: right;">3.56</td><td style="text-align: right;">34.42</td><td style="text-align: right;">18.60</td>
</tr></tbody></table>


We'll see that at around 1 million entries, `NSIndexSet` starts becoming slower than `NSSet`, but only because of the new runtime and tagged pointers. Running the same test on iOS 6 shows that `NSIndexSet` is faster, even with this high number of entries. Realistically, in most apps, you won't add that many integers into the index set. What's not measured here is that `NSIndexSet` certainly has a greatly optimized memory layout compared to `NSSet`

## Conclusion

This article provides you with some real-world benchmarks to make informed choices when using Foundation's collection classes. Next to the discussed classes, there are some less common but still useful ones, especially `NSCountedSet`, [`CFBag`](http://nshipster.com/cfbag/), [`CFTree`](https://developer.apple.com/library/mac/documentation/corefoundation/Reference/CFTreeRef/Reference/reference.html), [`CFBitVector`](https://developer.apple.com/library/mac/documentation/corefoundation/Reference/CFBitVectorRef/Reference/reference.html), and [`CFBinaryHeap`](https://developer.apple.com/library/mac/documentation/corefoundation/Reference/CFBinaryHeapRef/Reference/reference.html).    

---
title: Data Models and Model Objects
category: "4"
date: "2013-09-09 08:00:00"
author:
  - name: Florian Kugler
    url: http://twitter.com/floriankugler
tags: article
---



In this article we are going to have a closer look at Core Data models and managed object classes. It's not meant to be an introduction to the topic, but rather a collection of some lesser-known or often-forgotten aspects which can come in handy when working with Core Data. If you're looking for a more extensive and step-by-step overview, we recommend you read through [Apple's Core Data Programming Guide](https://developer.apple.com/library/mac/documentation/cocoa/Conceptual/CoreData/cdProgrammingGuide.html#//apple_ref/doc/uid/TP30001200-SW1). 



## Data Model

The Core Data data model (stored in the `*.xcdatamodel` file) is where the data types ("Entities" in Core Data) are defined. Mostly we will define a data model using Xcode's graphical interface, but it's equally possible to create the whole thing in code. You would start by creating an [`NSManagedObjectModel`](https://developer.apple.com/library/ios/documentation/cocoa/Reference/CoreDataFramework/Classes/NSManagedObjectModel_Class/Reference/Reference.html) object, then create entities represented by [`NSEntitiyDescription`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/CoreDataFramework/Classes/NSEntityDescription_Class/NSEntityDescription.html) objects, which in turn contain relationships and attributes represented by [`NSAttributeDescription`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/CoreDataFramework/Classes/NSAttributeDescription_Class/reference.html) and [`NSRelationshipDescription`](https://developer.apple.com/library/ios/documentation/cocoa/Reference/CoreDataFramework/Classes/NSRelationshipDescription_Class/NSRelationshipDescription.html) objects. You'll hardly ever need to do this, but it's good to know about these classes.


### Attributes

Once we have created an entity, we now have to define some attributes on it. Attribute definition is very straightforward, but there are some properties which we are going to look at in detail.


#### Default/Optional

Each attribute can be defined as optional or non-optional. A non-optional attribute will cause saving to fail if it's not set on one of the modified objects. At the same time, we can define a default value for each attribute. Nobody is stopping us from declaring an attribute as optional and defining a default value on it. But when you think about it, this doesn't make much sense and can be confusing. So we recommend to always uncheck *optional* for attributes with default values.


#### Transient

Another often-overlooked property of attributes is their *transient* option. Attributes declared as transient are never saved to the persistent store, but they otherwise behave just like normal attributes. This means they will participate in [validation][220], undo management, faulting, etc. Transient attributes can be very useful once you start moving more model logic into managed object subclasses. We'll talk more about this below and how it's better to [use transient attributes instead of ivars][230].

<a name="indexes"> </a>

#### Indexes

If you've worked with relational databases before, you will be familiar with indexes. If you haven't, you can think of an [index](http://en.wikipedia.org/wiki/Database_index) on an attribute as a way to speed up lookups on it dramatically. It's a trade-off though; indexes speed up reads and slow down writes, because the index has to be updated when the data changes. 

Setting the `indexed` property on an attribute will translate into an index on the underlying table column in SQLite. We can create indexes on any attribute we like, but be aware of write performance implications. Core Data also offers the possibility to create compound indexes (look for the Indexes section in the entity inspector), i.e. indexes which span more than one attribute. This can help performance when you typically use a predicate with conditions on multiple attributes to fetch data. Daniel has an example for this in his article about [fetching data][600].


#### Scalar Types

Core Data has support for many common data types like integers, floats, booleans, and so on. However, by default, the data model editor generates these attributes as `NSNumber` properties in the managed object subclasses. This often results in endless `floatValue`, `boolValue`, `integerValue`, or similar calls on these `NSNumber` objects in the application code. 

But we can also just specify those properties with their correct scalar type, e.g. as `int64_t`, `float_t`, or `BOOL`, and it will work with Core Data. Xcode even has a little checkbox in the save dialogue of the `NSManagedObject` generator ("Use scalar properties for primitive data types") which does this for you. Anyway, instead of:

```objc
@property (nonatomic, strong) NSNumber *myInteger;
```

the property would be declared as:

```objc
@property (nonatomic) int64_t myInteger;
```

That's all we have to do to retrieve and store scalar types in Core Data. The documentation still states that Core Data cannot automatically generate accessor methods for scalar values, but that seems to be outdated. 


#### Storing Other Objects

Core Data doesn't limit us to only storing values of the predefined types. In fact we can easily store any object which conforms to [`NSCoding`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Protocols/NSCoding_Protocol/Reference/Reference.html) and pretty much anything else including structs with some more work.

In order to store `NSCoding` compliant objects we use [transformable attributes](https://developer.apple.com/library/ios/documentation/cocoa/conceptual/CoreData/Articles/cdNSAttributes.html#//apple_ref/doc/uid/TP40001919-SW7). All we have to do is select the "Transformable" type in the drop-down menu and we are ready to go. If you generate the managed object subclasses you will see a property declared like this:

```objc
@property (nonatomic, retain) id anObject;
```

We can manually change the type from `id` to whatever we want to store in this attribute to get type checking from the compiler. However, there is one pitfall when using transformable attributes: we must not specify the name of the transformer if we want to use the default transformer (which we mostly want). Even specifying the default transformer's name, `NSKeyedUnarchiveFromDataTransformerName`, will result in [bad things](https://developer.apple.com/library/ios/documentation/cocoa/conceptual/CoreData/Articles/cdNSAttributes.html#//apple_ref/doc/uid/TP40001919-SW7).

But it doesn't stop there. We can also create our custom value transformers and use them to store arbitrary object types. We can store anything as long as we can transform it into one of the supported basic types. In order to store not supported non-object types like structs, the basic approach is to create a transient attribute of undefined type and a persistent "shadow attribute" of one of the supported types. Then the accessor methods of the transient attribute are overridden to transform the value from and to the persisted type. This is not trivial, because these accessor methods have to be KVC and KVO compliant and make correct use of Core Data's primitive accessor methods. Please read the [custom code](https://developer.apple.com/library/ios/documentation/cocoa/conceptual/CoreData/Articles/cdNSAttributes.html#//apple_ref/doc/uid/TP40001919-SW8) section in Apple's guide to [non-standard persistent attributes](https://developer.apple.com/library/ios/documentation/cocoa/conceptual/CoreData/Articles/cdNSAttributes.html#//apple_ref/doc/uid/TP40001919-SW1).


### Fetched Properties

Fetched properties are mostly used to create relationships across multiple persistent stores. Since having multiple persistent stores already is a very uncommon and advanced use case, fetched properties are rarely used either. 

Behind the scenes, Core Data executes a fetch request and caches the results when we access a fetched property. This fetch request can be configured directly in Xcode's data model editor by specifying a target entity type and a predicate. This predicate is not static though, but can be configured at runtime via the `$FETCH_SOURCE` and `$FETCHED_PROPERTY` variables. Please refer to Apple's [documentation](https://developer.apple.com/library/ios/documentation/cocoa/conceptual/CoreData/Articles/cdRelationships.html#//apple_ref/doc/uid/TP40001857-SW7) for more details.


### Relationships

Relationships between entities should always be defined in both directions. This gives Core Data enough information to fully manage the object graph for us. However, defining relationships bidirectionally is not a strict requirement, although it is strongly recommended. 

If you know what you're doing, you can define unidirectional relationships and Core Data will not complain. However, you just have taken on a lot of responsibilities normally managed by Core Data, including ensuring the consistency of the object graph, change tracking, and undo management. To take a simple example, if we have `Book` and `Author` entities and define a to-one relationship from book to author, deleting an author will not propagate the deletion to the affected books. We still can access the book's author relationship, but we'll get a fault pointing to nowhere.

It should become clear that unidirectional relationships are basically never what you want. Always define relationships in both ways to stay out of trouble. 


### Data Model Design

When designing a data model for Core Data, we have to remember that Core Data is not a relational database. Therefore, we shouldn't design the model like we would design a database schema, but think much more from the perspective of how the data should be used and presented. 

Often it makes sense to [denormalize](http://en.wikipedia.org/wiki/Denormalization) the data model, in order to avoid extensive fetching of related objects when displaying this data. For example, if we have an `Authors` entity with a to-many relationship to a  `Books` entity, it might make sense to store the number of books associated with one author in the Author entity, if that's something we want to show later on. 

Let's say we want to show a table view listing all authors and the number of books for each author. If the number of books per author can only be retrieved by counting the number of associated book objects, one fetch request per author cell is necessary to get this data. This is not going to perform very well. We could pre-fetch the book objects using [`relationshipKeyPathsForPrefetching`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/CoreDataFramework/Classes/NSFetchRequest_Class/NSFetchRequest.html#//apple_ref/occ/instm/NSFetchRequest/relationshipKeyPathsForPrefetching), but this might not be ideal either if we have large amounts of books stored. However, if we manage a book count attribute for each author, the author's fetch request gets all the data we need.

Naturally denormalization comes with the cost of being responsible to ensure that the duplicated data stays in sync. We have to weigh the benefits and drawbacks on a case-by-case basis, because sometimes it is trivial to do, and other times it can create major headaches. This very much depends on the specifics of the data model, if the app has to interact with a backend, or if the data even has to be synched between multiple clients either via a central authority or peer-to-peer. 

Often the data model will already be defined by some kind of backend service and we might just duplicate this model for client applications. However, even in this case we have the freedom to make some modifications to the model on the client side, as long as we can define an unambiguous mapping to the data model of the backend. For the simple example of books and authors, it would be trivial to add a book count property to the `Author` Core Data entity, which lives only on the client side to help with performance, but never gets sent to the server. If we make a change locally or receive new data from the server, we update this attribute and keep it in sync with the rest of the data.

It's not always as simple as that, but often small changes like this can alleviate serious performance bottlenecks that arise from dealing with a too normalized, relational, database-ish data model.


<a name="entity-vs-class-hierarchy"> </a>

### Entity Hierarchy vs. Class Hierarchy

Managed object models offer the possibility to create entity hierarchies, i.e. we can specify an entity as the parent of another entity. This might sound good, for example, if our entities share some common attributes. In practice, however, it's rarely what you would want to do.

What happens behind the scenes is that Core Data stores all entities with the same parent entity in the same table. This quickly creates tables with a large number of attributes, slowing down performance. Often the purpose of creating an entity hierarchy is solely to create a class hierarchy, so that we can put code shared between multiple entities into the base class. There is a much better way to achieve this though. 

The entity hierarchy is *independent* of the `NSManagedObject` subclass hierarchy. Or put differently, we don't need to have a hierarchy within our entities to create a class hierarchy.

Let's have a look at the `Author` and `Book` example again. Both of these entities have common fields, like an identifier, a `createdAt` date field, and a `changedAt` date field. For this case we could create the following structure:

```
Entity hierarchy            Class hierarchy
----------------            ---------------

   BaseEntity                 BaseEntity
    |      |                   |      |
 Authors  Books             Authors  Books
```

However, we can equally maintain this class hierarchy while flattening the entity hierarchy:
 
```
 Entity hierarchy            Class hierarchy
 ----------------            ---------------
```

 
```objc
  Authors  Books               BaseEntity
                                |      |
                             Authors  Books
```

 
The classes would be declared like this:
 
```objc
 @interface BaseEntity : NSManagedObject
 @property (nonatomic) int64_t identifier;
 @property (nonatomic, strong) NSDate *createdAt;
 @property (nonatomic, strong) NSDate *changedAt;
 @end

 @interface Author : BaseEntity
 // Author specific code...
 @end

 @interface Book : BaseEntity
 // Book specific code...
 @end
```

This gives us the benefit of being able to move common code into the base class without the performance overhead of storing all entities in a single table. We cannot create class hierarchies deviating from the entity hierarchy with Xcode's managed object generator though. But that's a small price to pay, since there are more benefits to not auto-generating managed object classes, as we will discuss [below][210].


### Configurations and Fetch Request Templates

Everybody who has used Core Data has worked with the entity-modeling aspect of data models. But data models also have two lesser-known or lesser-used aspects: configurations and fetch request templates.

Configurations are used to define which entity should be stored in which persistent store. Persistent stores are added to the persistent store coordinator using [`addPersistentStoreWithType:configuration:URL:options:error:`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/CoreDataFramework/Classes/NSPersistentStoreCoordinator_Class/NSPersistentStoreCoordinator.html#//apple_ref/occ/instm/NSPersistentStoreCoordinator/addPersistentStoreWithType:configuration:URL:options:error:), where the configuration argument defines this mapping. Now, in almost all cases, we will only use one persistent store, and therefore never deal with multiple configurations. The one default configuration we need for a single store setup is created for us. There are some rare use cases for multiple stores though, and one of those is outlined in the article, [Importing Large Data Sets][120], in this issue.

Fetch request templates are just what the name suggests: predefined fetch requests stored with the managed object model, which can be used later on using [`fetchRequestFromTemplateWithName:substitutionVariables`](https://developer.apple.com/library/ios/documentation/cocoa/Reference/CoreDataFramework/Classes/NSManagedObjectModel_Class/Reference/Reference.html#//apple_ref/occ/instm/NSManagedObjectModel/fetchRequestFromTemplateWithName:substitutionVariables:). We can define those templates in Xcode's data model editor or in code. Xcode's editor doesn't support all the features of `NSFetchRequest` though.

To be honest, I have a hard time coming up with convincing use cases of fetch request templates. One advantage is that the predicate of the fetch request will be pre-parsed, so this step doesn't have to happen each time you're performing a new fetch request. This will hardly ever be relevant though, and we are in trouble anyway if we have to fetch that frequently. But if you're looking for a place to define your fetch requests (and you should not define them in view controllers...), check if storing them with the managed object model might be a viable alternative.


<a name="managed-objects"> </a>

## Managed Objects

Managed objects are at the heart of any Core Data application. Managed objects live in a managed object context and represent our data. Managed objects are supposed to be passed around in the application, crossing at least the model-controller barrier, and potentially even the controller-view barrier. The latter is somewhat more controversial though, and can be [abstracted in a better way](/issue-1/table-views.html) by e.g. defining a protocol to which an object must conform in order to be consumed by a certain view, or by implementing configuration methods in a view category that bridge the gap from the model object to the specifics of the view.

Anyway, we shouldn't limit managed objects to the model layer and pull out their data into different structures as soon as we want to pass them around. Managed objects are first-class citizens in a Core Data app and we should use them accordingly. For example, managed objects should be passed between view controllers to provide them with the data they need. 

In order to access the managed object context we often see code like this in view controllers:

```objc
NSManagedObjectContext *context = 
  [(MyApplicationDelegate *)[[UIApplication sharedApplication] delegate] managedObjectContext];
```

If you already pass a model object to the view controller, it's much better to access the context directly via this object:

```objc
NSManagedObjectContext *context = self.myObject.managedObjectContext;
```

This removes the hidden dependency on the application delegate, and makes it much more readable and also easier to test. 


### Working with Managed Object Subclasses

Similarly, managed object subclasses are meant to be used. We can and should implement custom model logic, validation logic, and helper methods in these classes and create class hierarchies in order to pull out common code into super classes. The latter is easy to do because of the decoupling of the class and the entity hierarchy as [mentioned above][240]. 

You may wonder how to implement custom code in managed object subclasses if Xcode keeps overwriting these files when regenerating them. Well, the answer is pretty simple: don't generate them with Xcode. If you think about it, the generated code in these classes is trivial and very easy to write yourself, or generate once and then keep up to date manually. It's really just a bunch of property declarations. 

There are other solutions like putting the custom code in a category, or using tools like [mogenerator](https://github.com/rentzsch/mogenerator), which creates a base class for each entity and a subclass of it where the user-written code is supposed to go. But none of these solutions allow for a flexible class hierarchy independent of the entity hierarchy. So at the cost of writing a few lines of trivial code, our advice is to just write those classes manually.


<a name="ivars-in-managed-object-classes"> </a>

#### Instance Variables in Managed Object Subclasses

Once we start using our managed object subclasses to implement model logic, we might want to create some instance variables to cache computed values or something similar. It's much more convenient though to use transient properties for this purpose. The reason is that the lifecycle of managed objects is somewhat different from normal objects. Core Data often [faults](https://developer.apple.com/library/ios/documentation/cocoa/conceptual/CoreData/Articles/cdFaultingUniquing.html#//apple_ref/doc/uid/TP30001202-CJBDBHCB) objects that are no longer needed. If we would use instance variables, we would have to manually participate in this process and release our ivars. If we use transient properties instead, all this is done for us.

<a name="creating-objects"> </a>

#### Creating New Objects

One good example of implementing useful helper methods on our model classes is a class method to insert a new object into a managed object context. Core Data's API for creating new objects is not very intuitive: 

```objc
Book *newBook = [NSEntityDescription insertNewObjectForEntityForName:@"Book"
                                              inManagedObjectContext:context];
```

Luckily, we can easily solve this task in a much more elegant manner in our own subclass:

```objc
@implementation Book
// ...

+ (NSString *)entityName
{
    return @"Book"
}

+ (instancetype)insertNewObjectIntoContext:(NSManagedObjectContext *)context
{
    return [NSEntityDescription insertNewObjectForEntityForName:[self entityName]
                                         inManagedObjectContext:context];
}
@end
```

Now, creating a new book object is much easier:

```objc
Book *book = [Book insertNewObjectIntoContext:context];
```

Of course, if we subclass our actual model classes from a common base class, we should move the `insertNewObjectIntoContext:` and `entityName` class methods into the common super class. Then each subclass only needs to overwrite `entityName`.


#### To-Many Relationship Mutators

If you generate a managed object subclass with Xcode which has a to-many relationship, it will create methods like this to add and remove objects to and from this relationship:

```objc
- (void)addBooksObject:(Book *)value;
- (void)removeBooksObject:(Book *)value;
- (void)addBooks:(NSSet *)values;
- (void)removeBooks:(NSSet *)values;
```

Instead of using those four mutator methods, there is a much more elegant way of doing this, especially if we don't generate the managed object subclasses. We can simply use the [`mutableSetValueForKey:`](https://developer.apple.com/library/mac/documentation/cocoa/Reference/Foundation/Protocols/NSKeyValueCoding_Protocol/Reference/Reference.html#//apple_ref/occ/instm/NSObject/mutableSetValueForKey:) method to retrieve a mutable set of related objects (or [`mutableOrderedSetValueForKey:`](https://developer.apple.com/library/mac/documentation/cocoa/Reference/Foundation/Protocols/NSKeyValueCoding_Protocol/Reference/Reference.html#//apple_ref/occ/instm/NSObject/mutableOrderedSetValueForKey:) for ordered relationships). This can be encapsulated into a simple accessor method:

```objc
- (NSMutableSet *)mutableBooks
{
    return [self mutableSetValueForKey:@"books"];
}
```

Then we can use this mutable set like any other set. Core Data will pick up the changes and do the rest for us:

```objc
Book *newBook = [Book insertNewObjectIntoContext:context];
[author.mutableBooks addObject:newBook];
```

&nbsp;


<a name="validation"> </a>

#### Validation

Core Data supports various ways of data validation. Xcode's data model editor lets us specify some basic requirements on our attribute, like a string's minimum and maximum length or a minimum and maximum number of objects in a to-many relationship. But beyond that, there's much we can do in code.

The section ["Managed Object Validation"](https://developer.apple.com/library/ios/documentation/cocoa/conceptual/CoreData/Articles/cdValidation.html#//apple_ref/doc/uid/TP40004807-SW1) is the go-to place for in-depth information on this topic. Core Data supports property-level validation by implementing `validate<Key>:error:` methods, as well as inter-property validation via [`validateForInsert:`](https://developer.apple.com/library/ios/DOCUMENTATION/Cocoa/Reference/CoreDataFramework/Classes/NSManagedObject_Class/Reference/NSManagedObject.html#//apple_ref/occ/instm/NSManagedObject/validateForInsert:), [`validateForUpdate:`](https://developer.apple.com/library/ios/DOCUMENTATION/Cocoa/Reference/CoreDataFramework/Classes/NSManagedObject_Class/Reference/NSManagedObject.html#//apple_ref/occ/instm/NSManagedObject/validateForUpdate:), and [`validateForDelete:`](https://developer.apple.com/library/ios/DOCUMENTATION/Cocoa/Reference/CoreDataFramework/Classes/NSManagedObject_Class/Reference/NSManagedObject.html#//apple_ref/occ/instm/NSManagedObject/validateForDelete:). Validation happens automatically before saving, but we can also trigger it manually on the property level with [`validateValue:forKey:error:`](https://developer.apple.com/library/ios/DOCUMENTATION/Cocoa/Reference/CoreDataFramework/Classes/NSManagedObject_Class/Reference/NSManagedObject.html#//apple_ref/occ/instm/NSManagedObject/validateValue:forKey:error:).


## Conclusion

Data models and model objects are the bread and butter of any Core Data application. We would like to encourage you not to jump to convenience wrappers right away, but to embrace working with managed object subclasses and objects. With something like Core Data, it is very important to understand what's happening, otherwise it can backfire very easily once your application grows and becomes more complex. 

We hope to have demonstrated some simple techniques to make working with managed objects easier without introducing any magic. Additionally, we peeked into some very advanced stuff we can do with data models in order to give you an idea of what's possible. Use these techniques sparingly though, as at the end of the day, simplicity mostly wins.



[100]:/issue-4/importing-large-data-sets-into-core-data.html
[110]:/issue-4/importing-large-data-sets-into-core-data.html#efficient-importing
[120]:/issue-4/importing-large-data-sets-into-core-data.html#user-generated-data

[200]:/issue-4/core-data-models-and-model-objects.html
[210]:/issue-4/core-data-models-and-model-objects.html#managed-objects
[220]:/issue-4/core-data-models-and-model-objects.html#validation
[230]:/issue-4/core-data-models-and-model-objects.html#ivars-in-managed-object-classes
[240]:/issue-4/core-data-models-and-model-objects.html#entity-vs-class-hierarchy
[250]:/issue-4/core-data-models-and-model-objects.html#creating-objects
[260]:/issue-4/core-data-models-and-model-objects.html#indexes

[300]:/issue-4/core-data-overview.html
[310]:/issue-4/core-data-overview.html#complicated-stacks
[320]:/issue-4/core-data-overview.html#getting-to-objects

[400]:/issue-4/full-core-data-application.html

[500]:/issue-4/SQLite-instead-of-core-data.html

[600]:/issue-4/core-data-fetch-requests.html

[700]:/issue-4/core-data-migration.html
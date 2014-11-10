---
title: Importing Large Data Sets
category: "4"
date: "2013-09-09 07:00:00"
author: "<a href=\"http://twitter.com/floriankugler\">Florian Kugler</a>"
tags: article
---


Importing large data sets into a Core Data application is a common problem. There are several approaches you can take dependent on the nature of the data:

1. Downloading the data from a web server (for example as JSON) and inserting it into Core Data.
2. Downloading a pre-populated Core Data SQLite file from a web server.
3. Shipping a pre-populated Core Data SQLite file in the app bundle.

The latter two options especially are often overlooked as viable options for some use cases. Therefore, we are going to have a closer look at them in this article, but we will also outline how to efficiently import data from a web service into a live application.


## Shipping Pre-Populated SQLite files

Shipping or downloading pre-populated SQLite files is a viable option to seed Core Data with big amounts of data and is much more efficient then creating the database on the client side. If the seed data set consists of static data and can live relatively independently next to potential user-generated data, it might be a use case for this technique.

The Core Data framework is shared between iOS and OS X, therefore we can create an OS X command line tool to generate the SQLite file, even if it should be used in an iOS application.

In our example, (which you can [find on GitHub](https://github.com/objcio/issue-4-importing-and-fetching)), we created a command line tool which takes two files of a [transit data set](http://stg.daten.berlin.de/datensaetze/vbb-fahrplan-2013) for the city of Berlin as input and inserts them into a Core Data SQLite database. The data set consists of roughly 13,000 stop records and 3 million stop-time records.

The most important thing with this technique is to use exactly the same data model for the command line tool as for the client application. If the data model changes over time and you're shipping new seed data sets with application updates, you have to be very careful about managing data model versions. It's usually a good idea to not duplicate the .xcdatamodel file, but to link it into the client applications project from the command line tool project.

Another useful step is to perform a `VACUUM` command on the resulting SQLite file. This will bring down the file size and therefore the size of the app bundle or the database download, dependent on how you ship the file.

Other than that, there is really no magic to the process; as you can see in our [example project](), it's all just simple standard Core Data code. And since generating the SQLite file is not a performance-critical task, you don't even need to go to great lengths of optimizing its performance. If you want to make it fast anyway, the same rules apply as outlined below for [efficiently importing large data sets in a live application][110].


<a name="user-generated-data"> </a>

### User-Generated Data

Often we will have the case where we want to have a large seed data set available, but we also want to store and modify some user-generated data next to it. Again, there are several approaches to this problem.

The first thing to consider is if the user-generated data is really a candidate to be stored with Core Data. If we can store this data just as well e.g. in a plist file, then it's not going to interfere with the seeded Core Data database anyway. 

If we want to store it with Core Data, the next question is whether the use case might require updating the seed data set in the future by shipping an updated pre-populated SQLite file. If this will never happen, we can safely include the user-generated data in the same data model and configuration. However, if we might ever want to ship a new seed database, we have to separate the seed data from the user-generated data.

This can be done by either setting up a second, completely independent Core Data stack with its own data model, or by distributing the data of the same data model between two persistent stores. For this, we would have to create a second [configuration](https://developer.apple.com/library/ios/documentation/cocoa/conceptual/CoreData/Articles/cdMOM.html#//apple_ref/doc/uid/TP40002328-SW3) within the same data model that holds the entities of the user-generated data. When setting up the Core Data stack, we would then instantiate two persistent stores, one with the URL and configuration of the seed database, and the other one with the URL and configuration of the database for the user-generated data.

Using two independent Core Data stacks is the more simple and straightforward solution. If you can get away with it, we strongly recommend this approach. However, if you want to establish relationships between the user-generated data and the seed data, Core Data cannot help you with that. If you include everything in one data model spread out across two persistent stores, you still cannot define relationships between those entities as you would normally do, but you can use Core Data's [fetched properties](https://developer.apple.com/library/ios/documentation/cocoa/conceptual/CoreData/Articles/cdRelationships.html#//apple_ref/doc/uid/TP40001857-SW7) in order to automatically fetch objects from a different store when accessing a certain property.


### SQLite Files in the App Bundle

If we want to ship a pre-populated SQLite file in the application bundle, we have to detect the first launch of a newly updated application and copy the database file out of the bundle into its target directory:

    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSError *error;

    if([fileManager fileExistsAtPath:self.storeURL.path]) {
        NSURL *storeDirectory = [self.storeURL URLByDeletingLastPathComponent];
        NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:storeDirectory
                                              includingPropertiesForKeys:nil
                                                                 options:0
                                                            errorHandler:NULL];
        NSString *storeName = [self.storeURL.lastPathComponent stringByDeletingPathExtension];
        for (NSURL *url in enumerator) {
            if (![url.lastPathComponent hasPrefix:storeName]) continue;
            [fileManager removeItemAtURL:url error:&error];
        }
        // handle error
    }

    NSString* bundleDbPath = [[NSBundle mainBundle] pathForResource:@"seed" ofType:@"sqlite"];
    [fileManager copyItemAtPath:bundleDbPath toPath:self.storeURL.path error:&error];

    
Notice that we're first deleting the previous database files. This is not as straightforward as one may think though, because there can be different auxiliary files (e.g. journaling or write-ahead logging files) next to the main `.sqlite` file. Therefore we have to enumerate over the items in the directory and delete all files that match the store file name without its extension.

However, we also need a way to make sure that we only do this once. An obvious solution would be to delete the seed database from the bundle. However, while this works on the simulator, it will fail as soon as you try this on a real device because of restricted permissions. There are many options to solve this problem though, like setting a key in the user defaults which contains information about the latest seed data version imported:

    NSDictionary *infoDictionary = [NSBundle mainBundle].infoDictionary;
    NSString* bundleVersion = [infoDictionary objectForKey:(NSString *)kCFBundleVersionKey];
    NSString *seedVersion = [[NSUserDefaults standardUserDefaults] objectForKey:@"SeedVersion"];
    if (![seedVersion isEqualToString:bundleVersion]) {
        // Copy the seed database
    }

    // ... after the import succeeded
    [[NSUserDefaults standardUserDefaults] setObject:bundleVersion forKey:@"SeedVersion"];

Alternatively for example, we could also copy the existing database file to a path including the seed version and detect its presence to avoid doing the same import twice. There are many practicable solutions which you can choose from, dependent on what makes the most sense for your case.


## Downloading Pre-Populated SQLite Files

If for some reason we don't want to include a seed database in the app bundle (e.g. because it would push the bundle size beyond the cellular download threshold), we can also download it from a web server. The process is exactly the same as soon as we have the database file locally on the device. We need to make sure though, that the server sends a version of the database which is compatible with the data model of the client, if the data model might change across different app versions.

Beyond replacing a file in the app bundle with a download though, this option also opens up possibilities to deal with seeding more dynamic datasets without incurring the performance and energy cost of importing the data dynamically on the client side.

We can run a similar command line importer as we used before on a (OS X) server in order to generate the SQLite file on the fly. Admittedly, the computing resources required for this operation might not permit doing this fully on demand for each request, depending on the size of the data set and the number of request we would have to serve. A viable alternative though is to generate the SQLite file in regular intervals and to serve these readily available files to the clients.

This of course requires some additional logic on the server and the client, in order to provide an API next to the SQLite download which can provide the data to the clients which has changed since the last seed file generation. The whole setup becomes a bit more complex, but it enables easily seeding Core Data with dynamic data sets of arbitrary size without performance problems (other than bandwidth limitations).


## Importing Data from Web Services

Finally, let's have a look at what we have to do in order to live import large amounts of data from a web server that provides the data, for example, in JSON format.

If we are importing different object types with relationships between them, then we will need to import all objects independently first before attempting to resolve the relationships between them. If we could guarantee on the server side that the client receives the objects in the correct order in order to resolve all relationships immediately, we wouldn't have to worry about this. But mostly this will not be the case.

In order to perform the import without affecting user-interface responsiveness, we have to perform the import on a background thread. In a previous issue, Chris wrote about a simple way of [using Core Data in the background](/issue-2/common-background-practices.html). If we do this right, devices with multiple cores can perform the import in the background without affecting  the responsiveness of the user interface. Be aware though that using Core Data concurrently also creates the possibility of conflicts between different managed object contexts. You need to come up with a [policy](http://thermal-core.com/2013/09/07/in-defense-of-core-data-part-I.html) of how to prevent or handle these situations.

In this context, it is important to understand how concurrency works with Core Data. Just because we have set up two managed object contexts on two different threads does not mean that they both get to access the database at the same time. Each request issued from a managed object context will cause a lock on the objects from the context all the way down to the SQLite file. For example, if you trigger a fetch request in a child context of the main context, the main context, the persistent store coordinator, the persistent store, and ultimately the SQLite file will be locked in order to execute this request (although the [lock on the SQLite file will come and go faster](https://developer.apple.com/wwdc/videos/?id=211) than on the stack above). During this time, everybody else in the Core Data stack is stuck waiting for this request to finish.

In the example of mass-importing data on a background context, this means that the save requests of the import will repeatedly lock the persistent store coordinator. During this time, the main context cannot execute, for example, a fetch request to update the user interface, but has to wait for the save request to finish. Since Core Data's API is synchronous, the main thread will be stuck waiting and the responsiveness of the user interface might be affected.

If this is an issue in your use case, you should consider using a separate Core Data stack with its own persistent store coordinator for the background context. Since, in this case, the only shared resource between the background context and the main context is the SQLite file, lock contention will likely be lower than before. Especially when SQLite is operating in [write-ahead logging](http://www.sqlite.org/draft/wal.html) mode, (which it is by default on iOS 7 and OS X 10.9), you get true concurrency even on the SQLite file level. Multiple readers and a single writer are able to access the database at the same time (See [WWDC 2013 session "What's New in Core Data and iCloud"](https://developer.apple.com/wwdc/videos/?id=207)).

Lastly, it's mostly not a good idea to merge every change notification into the main context immediately while mass-importing data. If the user interface reacts to these changes automatically, (e.g. by using a `NSFetchedResultsController`), it will come to a grinding halt quickly. Instead, we can send a custom notification once the whole import is done to give the user interface a chance to reload its data. 

If the use case warrants putting additional effort into this aspect of live-updating the UI during the import, then we can consider filtering the save notifications for certain entity types, grouping them together in batches, or other means of reducing the frequency of interface updates, in order to keep it responsive. However, in most cases, it's not worth the effort, because very frequent updates to the user interface are more confusing then helpful to the user. 

After laying out the general setup and modus operandi of a live import, we'll now have a look at some specific aspects to make it as efficient as possible.


<a name="efficient-importing"> </a>

### Importing Efficiently

Our first recommendation for importing data efficiently is to read [Apple's guide on this subject](https://developer.apple.com/library/ios/documentation/cocoa/conceptual/CoreData/Articles/cdImporting.html). We would also like to highlight a few aspects described in this document, which are often forgotten.

First of all, you should always set the `undoManager` to `nil` on the context that you use for importing. This applies only to OS X though, because on iOS, contexts come without an undo manager by default. Nilling out the `undoManager` property will give a significant performance boost.

Next, accessing relationships between objects in *both directions* creates retain cycles. If you see growing memory usage during the import despite well-placed auto-release pools, watch out for this pitfall in the importer code.  [Here, Apple describes](https://developer.apple.com/library/ios/documentation/cocoa/conceptual/CoreData/Articles/cdMemory.html#//apple_ref/doc/uid/TP40001860-SW3) how to break these cycles using [`refreshObject:mergeChanges:`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/CoreDataFramework/Classes/NSManagedObjectContext_Class/NSManagedObjectContext.html#//apple_ref/occ/instm/NSManagedObjectContext/refreshObject:mergeChanges:).

When you're importing data which might already exist in the database, you have to implement some kind of find-or-create algorithm to prevent creating duplicates. Executing a fetch request for every single object is vastly inefficient, because every fetch request will force Core Data to go to disk and fetch the data from the store file. However, it's easy to avoid this by importing the data in batches and using the efficient find-or-create algorithm Apple outlines in the above-mentioned guide.

A similar problem often arises when establishing relationships between the newly imported objects. Using a fetch request to get each related object independently is vastly inefficient. There are two possible ways out of this: either we resolve relationships in batches similar to how we imported the objects in the first place, or we cache the objectIDs of the already-imported objects. 

Resolving relationships in batches allows us to greatly reduce the number of fetch requests required by fetching many related objects at once. Don't worry about potentially long predicates like:

    [NSPredicate predicateWithFormat:@"identifier IN %@", identifiersOfRelatedObjects];
    
Resolving a predicate with many identifiers in the `IN (...)` clause is always way more efficient than going to disk for each object independently. 

However, there is also a way to avoid fetch requests altogether (at least if you only need to establish relationships between newly imported objects). If you cache the objectIDs of all imported objects (which is not a lot of data in most cases really), you can use them later to retrieve faults for related objects using `objectWithID:`.

    // after a batch of objects has been imported and saved
    for (MyManagedObject *object in importedObjects) {
        objectIDCache[object.identifier] = object.objectID;
    }
    
    // ... later during resolving relationships 
    NSManagedObjectID objectID = objectIDCache[object.foreignKey];
    MyManagedObject *relatedObject = [context objectWithID:objectId];
    object.toOneRelation = relatedObject;
    
Note that this example assumes that the `identifier` property is unique across all entity types, otherwise we would have to account for duplicate identifiers for different types in the way we cache the object IDs. 


## Conclusion

When you face the challenge of having to import large data sets into Core Data, try to think out of the box first, before doing a live-import of massive amounts of JSON data. Especially if you're in control of the client and the server side, there are often much more efficient ways of solving this problem. But if you have to bite the bullet and do large background imports, make sure to operate as efficiently and as independently from the main thread as possible. 



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
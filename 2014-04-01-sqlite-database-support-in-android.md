---
layout: post
title:  "SQLite Database Support in Android"
category: "11"
date: "2014-04-01 07:00:00"
tags: article
author: "<a href=\"https://twitter.com/jwkelso\">James Kelso</a>"
---


## Out of the Box

Most of us are familiar with at least some of the persistence features Core Data offers us out of the box. Unfortunately, many of those things aren't automatic on the Android platform. For instance, Core Data abstracts away most of the SQL syntax and database normalization concerns facing database engineers every day. Since Android only provides a thin client to SQLite, you'll still need to write SQL and ensure your database tables are appropriately normalized.

Core Data allows us to think in terms of objects. In fact, it handles marshaling and unmarshaling objects automatically. It manages to perform very well on mobile devices because it provides record-level caching. It doesn't create a separate instance of an object each time the same piece of data is requested from the store. Observation of changes to an object are possible without requiring a refresh each time the object is inspected. 

This isn't the case for Android. You are completely responsible for writing objects into and reading them from the database. This means you must also implement object caching (if desired), manage object instantiation, and manually perform dirty checking of any objects already in existence.

With Android, you'll need to watch out for version-specific functionality. Different versions of Android ship with different implementations of SQLite. This means the exact same database instructions may give wildly different results across platform versions. A query may perform much differently based on which version of SQLite is executing it.

## Bridging the Gap

Many Android developers come from the enterprise world. For many years, [object-relational mapping](http://en.wikipedia.org/wiki/Object-relational_mapping) libraries have been available on server platforms to ease the pain of interfacing with databases. Sadly, these libraries are much too performance intensive to be used out of the box in a mobile setting. Recognizing this, a few developers set out to solve this issue by creating mobile-friendly ORM libraries.

One popular option for adding ORM support to SQLite on Android is [OrmLite](http://ormlite.com). OrmLite proffers automatic marshaling and unmarshaling of your persistent objects. It removes the need to write most SQL and provides a programmatic interface for querying, updating, and deleting objects. Another option in the ORM arena is [greenDAO](http://greendao-orm.com). It provides many of the same features as OrmLite, but promises better performance (according to its [website](http://greendao-orm.com/features/#performance)) at the cost of functionality, such as annotation-based setup.

A common complaint about third-party libraries is the extra layer of complexity and performance bloat they can add to a project. One developer felt this pain and decided to write [Cupboard](https://bitbucket.org/qbusict/cupboard), a thin wrapper around the Android SQLite framework. Its stated goals are to provide persistence of Java objects without using ContentValues and parsing Cursors, to be simple and lightweight, and to integrate with core Android classes without any hassle. You'll still need to manage creation of the database, but querying objects becomes a lot simpler.

Another developer decided to scrap SQLite entirely and created [Perst](http://www.mcobject.com/perst). It was designed from the beginning to interface with object-oriented languages. It's good at marshaling and unmarshaling objects and performs well in benchmarks. The concern for a solution like this is the fact that it's completely replacing a portion of the Android framework. This means you wouldn't be able to replace it in the future with a different solution.

With these options and many more available, why would anyone choose to develop with the plain vanilla Android database framework? Well, frameworks and wrappers can sometimes introduce more problems than they solve. For instance, in one project, we were simultaneously writing to the database and instantiating so many objects that it caused our ORM library to slow to a crawl. It wasn't designed to handle the kind of punishment we were putting it through. 

When evaluating frameworks and libraries, check to see whether they make use of Java reflection. Reflection in Java is comparatively expensive and should be used judiciously. Additionally, if your project is pre-Ice Cream Sandwich, evaluate whether your library is using Java annotations. A recently fixed [bug](https://code.google.com/p/android/issues/detail?id=7811) was present in the runtime that caused annotations to be a drag on performance. 

Finally, evaluate whether the addition of a framework will significantly increase the complexity level of your project. If you collaborate with other developers, remember that they'll have to work to learn the complexities of the library. It's extremely important to understand how stock Android handles data persistence before you decide whether or not to use a third-party solution.

### Opening the Database

Android has made creating and opening a database relatively easy. It provides this through the [SQLiteOpenHelper](http://developer.android.com/reference/android/database/sqlite/SQLiteOpenHelper.html) class, which you must subclass. In the default constructor, you'll specify a database name. If a file with the specified name already exists, it's opened. If not, it's created. An application may have any number of separate database files. Each should be represented by a separate subclass of `SQLiteOpenHelper`.

Database files are private to your application. They are stored in a subfolder of your application's section of the file system, and are protected by Linux file system permissions. Regrettably, the database files aren't encrypted.

Creating the database file isn't enough, though. In your `SQLiteOpenHelper` subclass, you'll have to override the `onCreate()` method to execute an SQL statement to create your database tables, views, and anything else in your database schema. You can override other methods such as `onConfigure()` to enable/disable database features like write-ahead logging or foreign key support.

### Changing the Schema

In addition to specifying database name in the constructor of your `SQLiteOpenHelper` subclass, you'll need to specify a database version number. This version number must be constant for any given release, and it's required by the framework to be monotonically increasing.

`SQLiteOpenHelper` will use the version number of your database to decide if it needs to be upgraded or downgraded. In the hooks for upgrade or downgrade, you'll use the provided `oldVersion` and `newVersion` arguments to determine which [ALTER](http://www.w3schools.com/sql/sql_alter.asp) statements need to be run to update your schema. It's good practice to provide a separate statement for each new database version, in order to handle upgrading across multiple database versions at the same time.

### Connecting to the Database

Database queries are managed by the  [SQLiteDatabase](http://developer.android.com/reference/android/database/sqlite/SQLiteDatabase.html) class. Calling `getReadableDatabase()` or `getWritableDatabase()` on your `SQLiteOpenHelper` subclass will return an instance of `SQLiteDatabase`. Note that both of these methods usually return the exact same object. The only exception is `getReadableDatabase()`, which will return a read-only database if there's a problem, such as a full disk, that would prevent writing to the database. Since disk problems are a rare occurrence, some developers only call `getWritableDatabase()` in their implementation. 

Database creation and database schema changes are lazy and don't occur until you obtain an `SQLiteDatabase` instance for the first time. Because of this, it's important you never request an instance of `SQLiteDatabase` on the main thread. Your `SQLiteOpenHelper` subclass will almost always return the exact same instance of `SQLiteDatabase`. This means a call to `SQLiteDatabase.close()` on any thread will close all `SQLiteDatabase` instances throughout your application. This can cause a number of difficult-to-diagnose bugs. In fact, some developers choose to open their `SQLiteDatabase` during application startup and only call `close()` when the application terminates.

### Querying the Data

`SQLiteDatabase` provides methods for querying, inserting, updating, and deleting from your database. For simple queries, this means you don't have to write any SQL. For more advanced queries, though, you'll find yourself writing SQL. SQLiteDatabase exposes `rawQuery()` and `execSQL()` methods, which take raw SQL as an argument to perform advanced queries, such as unions and joins. You can use an [SQLiteQueryBuilder](http://developer.android.com/reference/android/database/sqlite/SQLiteQueryBuilder.html) to assist in constructing the appropriate queries.

Both `query()` and `rawQuery()` return [Cursor](http://developer.android.com/reference/android/database/Cursor.html) objects. It's tempting to keep references to your Cursor objects and pass them around your application, but Cursor objects take many more system resources to keep around than a Plain Old Java Object (POJO). Because of this, Cursor objects should be unmarshaled into POJOs as soon as possible. After they are unmarshaled, you should call the `close()` method to free up the resources.

Database transactions are supported in SQLite. You can start a transaction by calling `SQLiteDatabase.beginTransaction()`. Transactions can be nested by calling `beginTransaction()` while inside a transaction. When the outer transaction has ended, all work done in the transaction and all the nested transactions will be committed or rolled back. Changes are rolled back if any transaction ends without being marked as clean, using `setTransactionSuccessful()`.

### Data Access Objects

As mentioned earlier, Android doesn't provide any method of marshaling or unmarshaling objects. This means we are responsible for writing the logic to take data from a Cursor to a POJO. This logic should be encapsulated by a [Data Access Object](http://en.wikipedia.org/wiki/Data_access_object) (DAO).

The DAO pattern is very familiar to practitioners of Java and, by extension, Android developers. Its main purpose is to abstract the application's interaction with the persistence layer without exposing the details of how persistence is implemented. This insulates the application from database schema changes. It also makes moving to a third-party database library less risky to the core application logic. All of your application's interaction with the database should be performed through a DAO.

### Loading Data Asynchronously

Acquiring a reference to `SQLiteDatabase` can be an expensive operation and should never be performed on the main thread. By extension, database queries shouldn't be performed on the main thread either. To assist with this, Android provides [Loaders](http://developer.android.com/guide/components/loaders.html). They allow an activity or a fragment to load data asynchronously. Loaders solve the issue of data persistence across configuration changes, and also monitor the data source to deliver new results when content changes. Android provides the [CursorLoader](http://developer.android.com/reference/android/content/CursorLoader.html) to provide for loading data from a database.

### Sharing Data with Other Applications

The database is private to the application that created it. Android, however, provides a method of sharing data with other applications. [Content Providers](http://developer.android.com/guide/topics/providers/content-providers.html) provide a structured interface with which other applications can read and possibly even modify your data. Much like `SQLiteDatabase`, Content Providers expose methods such as `query()`, `insert()`, `update()`, and `delete()` to work with the data. Data are returned in the form of a `Cursor`, and access to the Content Provider is synchronized by default to make access thread-safe.

## Conclusion

Android databases are much more implementation-heavy than their iOS counterparts. It's important, though, to avoid using a third-party library solely to avoid the boilerplate. A thorough understanding of the Android database framework will guide you in your choice of whether or not to use a third-party library, and if so, which library to choose. The [Android Developer Site](http://developer.android.com) provides two sample projects for working with SQLite databases. Check out the [NotePad](http://developer.android.com/resources/samples/NotePad/index.html) and [SearchableDictionary](http://developer.android.com/resources/samples/SearchableDictionary/index.html) projects for more information.

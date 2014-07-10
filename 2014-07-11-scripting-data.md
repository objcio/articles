---
layout: post
title: Making Your Mac App’s Data Scriptable
category: "14"
date: "2014-07-11 11:00:00"
author: "<a href=\"http://inessential.com/\">Brent Simmons</a>"
tags: article
---


When adding AppleScript support — which is also JavaScript support, as of OS X 10.10 — it’s best to start with your app’s data. Scripting isn’t a matter of automating button clicks; it’s about exposing the model layer to people who could use your app in their workflows.

While that’s usually a small minority of users, they’re power users — the kind of people who recommend apps to friends and family. They blog and tweet about apps, and people listen to them. They can be your app’s biggest evangelists.

Overall, the best reason to add scripting support is that it’s a matter of professionalism. But it doesn’t hurt that the effort is worth the reward.

## Noteland

Noteland is an app without any UI except for a blank window — but it has a model layer, and it’s scriptable. You can [find it on GitHub](https://github.com/objcio/issue-14-scriptable-apps) and follow along.

It supports AppleScript (and JavaScript on 10.10). It’s written in Objective-C in Xcode 5.1.1. We initially tried to use Swift and Xcode 6 Beta 2, but ran into snags, though it’s entirely likely they were our own fault, since we’re still learning Swift.

### Noteland’s Object Model

There are two classes: notes and tags. There may be multiple notes, and a note may have multiple tags.

NLNote.h declares several properties: `uniqueID`, `text`, `creationDate`, `archived`, `tags`, and a read-only `title` property.

Tags are simpler. NLTag.h declares two scriptable properties: `uniqueID` and `name`.

We want users to be able to create, edit, and delete notes and tags, and to be able to access and change all of their properties, with the exception of any that are read-only.

### Scripting Definition File (.sdef)

The first step is to define the scripting interface — it’s conceptually like creating a .h file for scripters, but in a format that AppleScript understands.

In the past, we’d create and edit an aete resource (“aete” stands for Apple Event Terminology.) These days it’s much easier: we create and edit an sdef (scripting definition) XML file.

You might think you’d prefer JSON or a plist, but XML is a decent match for this — beats an aete resource hands-down, at least. In fact, there was a plist version for a while, but it required *two* different plists that you had to keep in sync. It was a pain.

The original name of the resource points to a matter worth noting. An Apple event is the low-level message that AppleScript generates, sends, and receives. It’s an interesting technology on its own, and has uses outside of scripting support. Additionally, it’s been around since System 7 in the early ’90s, and has survived the transition to OS X.

(Speculation: Apple events survived because so many print publishers relied on AppleScript, and publishers were among Apple’s most loyal customers during the 'dark days,' in the middle and late ’90s.)

An sdef file always starts with the same header:

    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE dictionary SYSTEM "file://localhost/System/Library/DTDs/sdef.dtd">

The top-level item is a dictionary — “dictionary” is AppleScript’s word for a scripting interface. Inside the dictionary you'll find one or more suites.

(Tip: open AppleScript Editor and choose File > Open Dictionary… You’ll see a list of apps with scripting dictionaries. If you choose one — iTunes, for instance — you’ll see the classes, properties, and commands that iTunes understands.)

    <dictionary title="Noteland Terminology">

#### Standard Suite

The standard suite defines classes and commands all applications should support. It includes quitting, closing windows, making and deleting objects, querying objects, and so on.

To add it to your sdef file, copy and paste from the canonical copy of the standard suite at `/System/Library/ScriptingDefinitions/CocoaStandard.sdef`.

Copy everything from `<suite name="Standard Suite"`, through and including the closing `</suite>`.

Paste it right below the `dictionary` element in your sdef.

Then, in your sdef file, go through and delete everything that doesn’t apply. Noteland isn’t document-based and doesn’t print, so we removed the open and save commands, the document class, and everything to do with printing.

(Tip: Xcode does a good job indenting XML. To re-indent, select all the text and choose the Editor > Structure > Re-Indent command.)

Once you’ve finished editing, use the command-line xmllint program — `xmllint path/to/noteland.sdef` — to make sure your XML is okay. If it just displays the XML, without errors or warnings, then it’s fine. (Remember that you can drag the document proxy icon from a window title in Xcode into Terminal and it will paste in the path to the file.)

#### Noteland Suite

A single app-defined suite is usually best, though not mandated: you could have more than one when it makes sense. Noteland defines just one, the Noteland Suite:

    <suite name="Noteland Suite" code="Note" description="Noteland-specific classes.">

A scripting dictionary expects things to be contained by other things. The top-level container is the application object itself.

In Noteland, its class name is `NLApplication`. You should always use the code `capp` for the application class: it’s a standard Apple event code. (Note that it’s also present in the standard suite.)

    <class name="application" code="capp" description="Noteland’s top level scripting object." plural="applications" inherits="application">
        <cocoa class="NLApplication"/>

The application contains an array of notes. It’s important to differentiate elements (items there can be more than one of) and properties. In other words, an array in code should be an element in your dictionary:

    <element type="note" access="rw">
        <cocoa key="notes"/>
    </element>`

Cocoa scripting uses Key-Value Coding (KVC), and the dictionary specifies the key names.

#### Note Class

    <class name="note" code="NOTE" description="A note" inherits="item" plural="notes">
        <cocoa class="NLNote"/>`

The code is `NOTE`. It could be almost anything, but note that Apple reserves all lowercase codes for its own use, so `note` wouldn’t be allowed. It could be `NOT*`, or `NoTe`, or `XYzy`, or whatever you want. (Ideally the code wouldn’t collide with codes used by other apps. But there’s no way that we know of to ensure that, so we just, well, *guess*. That said, `NOTE` may not be all that great of a guess.)

Your classes should inherit from `item`. (In theory you could have a class the inherits from another of your classes, but we’ve never tried this.)

The note class has several properties:

    <property name="id" code="ID  " type="text" access="r" description="The unique identifier of the note.">
        <cocoa key="uniqueID"/>
    </property>
    <property name="name" code="pnam" type="text" description="The name of the note — the first line of the text." access="r">
        <cocoa key="title"/>
    </property>
    <property name="body" code="body" description="The plain text content of the note, including first line and subsequent lines." type="text" access="rw">
        <cocoa key="text"/>
    </property>
    <property name="creationDate" code="CRdt" description="The date the note was created." type="date" access="r"/>
    <property name="archived" code="ARcv" description="Whether or not the note has been archived." type="boolean" access="rw"/>

Whenever possible, it’s best to provide unique IDs for your objects. Otherwise, scripters have to rely on names and positions, which may change. Use the code 'ID  ' for unique IDs. (Note the two spaces; codes are four-character codes.) The name of the unique ID should always be `id`.

It’s also standard to provide a `name` property, whenever it makes sense, and the code should be `pnam`. Noteland makes this a read-only property, since the name is just the first line of the text of a note, and the text of the note is edited via the read-write `body` property.

For `creationDate` and `archived`, we don’t need to provide a Cocoa key element, since the key is the same as the property name.

Note the types: text, date, and boolean. AppleScript supports these and several more, as [listed in the documentation](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ScriptableCocoaApplications/SApps_about_apps/SAppsAboutApps.html#//apple_ref/doc/uid/TP40001976-SW12).

Notes can also have tags, and so there’s a tags element:

    <element type="tag" access="rw">
        <cocoa key="tags"/>
    </element>
    </class>`

#### Tag Class

Tags are `NLTag` objects:

    <class name="tag" code="TAG*" description="A tag" inherits="item" plural="tags">
        <cocoa class="NLTag"/>`

Tags have just two properties, `id` and `name`:

    <property name="id" code="ID  " type="text" access="r" description="The unique identifier of the tag.">
        <cocoa key="uniqueID"/>
    </property>
    <property name="name" code="pnam" type="text" access="rw">
        <cocoa key="name"/>
    </property>
    </class>

That ends the Noteland suite and the entire dictionary:

        </suite>
    </dictionary>

### App Configuration

Apps aren’t scriptable out of the box. In Xcode, edit the app’s Info.plist.

Since the app uses a custom `NSApplication` subclass — in order to provide the top-level container — we edit Principal Class (`NSPrincipalClass`) to say `NLApplication` (the name of Noteland’s `NSApplication` subclass).

We also add a Scriptable (`NSAppleScriptEnabled`) key and set it to YES. And finally, we add a Scripting definition file name (`OSAScriptingDefinition`) key and give it the name of the sdef file: noteland.sdef.

### Code

#### NSApplication subclass

You may be surprised by how little code there is to write.

See NLApplication.m in the Noteland project. It lazily creates a notes array and provides some dummy data. Lazily just because. It has no connection to scripting support.

(Note that there’s no object persistence, since I want Noteland to be as free as possible from things other than scripting support. You’d use Core Data or an archiver or something to persist data.)

It could have just skipped the dummy data and provided an array.

In this case, the array is an `NSMutableArray`. It wouldn’t have to be — if it’s an `NSArray`, then Cocoa scripting will just replace the notes array when changes are made. But if we make it an `NSMutableArray` *and* we provide the following two methods, then the array won’t be replaced. Instead, objects will be added and removed from the mutable array:

    - (void)insertObject:(NLNote *)object inNotesAtIndex:(NSUInteger)index {
        [self.notes insertObject:object atIndex:index];
    }

    - (void)removeObjectFromNotesAtIndex:(NSUInteger)index {
        [self.notes removeObjectAtIndex:index];
    }

Also note that the notes array property is declared in the .m file in the class extension. There’s no need to put it in the .h file. Since Cocoa scripting uses KVC and doesn’t care about your headers, it will find it.

#### NLNote Class

NLNote.h declares the various properties of a note: `uniqueID`, `text`, `creationDate`, `archived`, `title`, and `tags`.

The `init` method sets the `uniqueID` and `creationDate` and sets the tags array to an empty `NSArray`. We're using an `NSArray` this time, rather than an `NSMutableArray`, just to show it can be done.)

The `title` method returns a calculated value: the first line of the text of the note. (Recall that this becomes the `name` to the scripting dictionary.)

The method to note is the `objectSpecifier` method. This is critical to your classes; scripting support needs this so it understands your objects.

Luckily this method is easy to write. Though there are different types of object specifiers, it’s usually best to use `NSUniqueIDSpecifier`, since it’s stable. (Other options include `NSNameSpecifier`, `NSPositionalSpecifier`, and so on.)

The object specifier needs to know about the container, and the container is the top-level Application object.

The code looks like this:

    NSScriptClassDescription *appDescription = (NSScriptClassDescription *)[NSApp classDescription];
    return [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:appDescription containerSpecifier:nil key:@"notes" uniqueID:self.uniqueID];

`NSApp` is the global application object; we get its `classDescription`. The key is `@"notes"`, a nil `containerSpecifier` refers to the top-level (app) container, and the `uniqueID` is the note’s `uniqueID`.

#### Note as Container

We have to think ahead a little bit. Tags will need an `objectSpecifier` also, and tags are contained by notes — so a tag needs a reference to its containing note.

Cocoa scripting handles creating tags, but there’s a method we can override that lets us customize the behavior.

NSObjectScripting.h defines `-newScriptingObjectOfClass:forValueForKey: withContentsValue:properties:`. That’s what we need. In NLNote.m, it looks like this:

    NLTag *tag = (NLTag *)[super newScriptingObjectOfClass:objectClass forValueForKey:key withContentsValue:contentsValue properties:properties];
    tag.note = self;
    return tag;

We create the tag using super’s implementation, then set the tag’s `note` property to the note. To avoid a possible retain cycle, NLTag.h makes the note a weak property.

(You might think this is a bit inelegant, and we’d agree. We wish instead that containers were asked for the `objectSpecifiers` for their children. Something like `objectSpecifierForScriptingObject:` would be better. We filed a bug: [rdar://17473124](rdar://17473124).)

#### NLTag Class

`NLTag` has `uniqueID`, `name`, and `note` properties.

`NLTag`’s `objectSpecifier` is conceptually the same as the code in `NLNote`, except that the container is a note rather than the top-level application class.

It looks like this:

    NSScriptClassDescription *noteClassDescription = (NSScriptClassDescription *)[self.note classDescription];
    NSUniqueIDSpecifier *noteSpecifier = (NSUniqueIDSpecifier *)[self.note objectSpecifier];
    return [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:noteClassDescription containerSpecifier:noteSpecifier key:@"tags" uniqueID:self.uniqueID];

That’s it. Done. That’s not much code — most of the work is in designing the interface and editing the sdef file.

In the old days, you’d still be writing Apple event handlers and working with Apple event descriptors and all kinds of crazy jazz. In other words, you’d be a long way from done. Thankfully, these aren’t the old days.

The fun part is next.

### AppleScript Editor

Launch Noteland. Launch /Applications/Utilities/AppleScript Editor.app.

Run the following script:

    tell application "Noteland"
        every note
    end tell

In the Result pane at the bottom, you’ll see something like this:

    {note id "0B0A6DAD-A4C8-42A0-9CB9-FC95F9CB2D53" of application "Noteland", note id "F138AE98-14B0-4469-8A8E-D328B23C67A9" of application "Noteland"}

The IDs will be different, of course, but this is an indication that it’s working.

Try this script:

    tell application "Noteland"
        name of every note
    end tell

You’ll see `{"Note 0", "Note 1"}` in the Result pane.

Try this script:

    tell application "Noteland"
        name of every tag of note 2
    end tell

Result: `{"Tiger Swallowtails", "Steak-frites"}`.

(Note that AppleScript arrays are 1-based, so note 2 refers to the second note. Which doesn’t sound so crazy when we put it that way.)

You can also create notes:

    tell application "Noteland"
        set newNote to make new note with properties {body:"New Note" & linefeed & "Some text.", archived:true}
        properties of newNote
    end tell

The result will be something like this (with appropriate details changed):

    {creationDate:date "Thursday, June 26, 2014 at 1:42:08 PM", archived:true, name:"New Note", class:note, id:"49D5EE93-655A-446C-BB52-88774925FC62", body:"New Note\nSome text."}`

And you can create new tags:

    tell application "Noteland"
        set newNote to make new note with properties {body:"New Note" & linefeed & "Some text.", archived:true}
        set newTag to make new tag with properties {name:"New Tag"} at end of tags of newNote
        name of every tag of newNote
    end tell

The result will be: `{"New Tag"}`.

It works!

### More to Learn

Scripting the object model is just part of adding scripting support; you can add support for commands, too. For instance, Noteland could have an export command that writes notes to files on disk. An RSS reader might have a refresh command, a Mail app might have a download mail command, and so on.

Matt Neuburg’s [AppleScript: The Definitive Guide](http://www.amazon.com/AppleScript-Definitive-Guide-Matt-Neuburg/dp/0596102119/ref=la_B001H6OITU_1_1?s=books&ie=UTF8&qid=1403816403&sr=1-1) is worth checking out even though it was published in 2006, as things haven’t changed much since then. Matt also has a [tutorial on adding scripting support to Cocoa apps](http://www.apeth.net/matt/scriptability/scriptabilityTutorial.html). It's definitely worth reading, and it goes into more detail than this article.

There’s a session in the [WWDC 2014 videos](https://developer.apple.com/videos/wwdc/2014/) on JavaScript for Automation, which talks about the new JavaScript OSA language. (Years ago, Apple suggested that one day there would be a programmer’s dialect of AppleScript, since the natural language thing is a bit weird for people who write in C and C-like languages. JavaScript could be considered the programmer’s dialect.)

And of course, Apple has documentation on the various technologies:

- [Cocoa Scripting Guide](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/ScriptableCocoaApplications/SApps_intro/SAppsIntro.html#//apple_ref/doc/uid/TP40002164)
- [AppleScript Overview](https://developer.apple.com/library/mac/documentation/applescript/conceptual/applescriptx/AppleScriptX.html#//apple_ref/doc/uid/10000156-BCICHGIE)

Also, see Apple’s Sketch app for an example of an app that implements scripting.

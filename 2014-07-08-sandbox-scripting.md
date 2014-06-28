Scripting from a Sandbox
========================

Introduction
------------

Scripting between Mac applications has long been a part of the desktop ecosystem. It was originally [introduced](http://en.wikipedia.org/wiki/AppleScript) in October 1993 as a part of System 7 as a way to create complex workflows using publishing applications like QuarkXPress. Since then, many applications have supported AppleScript through the use of scripting dictionaries (Brent's article [in this issue](http://http://www.objc.io/issue-14/) shows you how to do this.) In this article, I'm going to explain how to communicate with another app using the commands in its scripting dictionary.

But before we do that, we need to take a look some recent events on the Mac platform. After opening the Mac App Store in late 2010, Apple announced the all developer submissions would need to run in a sandbox by November 2011. This deadline was pushed back several times until it eventually went into effect on June 1st, 2012.

That moving deadline should be your first clue that getting Mac apps to run in a sandbox was not exactly straightforward. Unlike their counterparts on iOS who had *always* run in a sandbox, many long-time developers realized that a secure execution environment would mean a lot of changes to their apps. As I heard one Apple security engineer put it, "We're putting the genie back into the bottle."

One of the major challenges with this effort to put apps into a sandbox was with AppleScript. Many functions that used to be easy were suddenly hard to do. Other things became outright impossible to accomplish. The main cause of this frustration was because apps could no longer arbitrarily control another app via scripting. From a security point-of-view, there are very good reasons why this is a bad idea.

Initially, Apple helped ease the transition by granting "temporary exceptions" in an application's entitlements. These exceptions allowed apps to retain functionality that would have otherwise been lost. And as the name indicates, many of these special cases are disappearing as alternative ways of controlling other apps have been made available in more recent versions of OS X.

This tutorial will show you the current best practices for controlling another app using AppleScript. I'll also show you some tricks that will help you and your customers get AppleScripts setup with a minimum amount of effort.


First steps
-----------

The first thing you need to learn is how to run an AppleScript from your own app. Typically the hardest part about this is writing AppleScript code. Behold:

	on chockify(inputString)
		set resultString to ""
	
		repeat with inputStringCharacter in inputString
			set asciiValue to (ASCII number inputStringCharacter)
			if (asciiValue > 96 and asciiValue < 123) then
				set resultString to resultString & (ASCII character (asciiValue - 32))
			else
				if ((asciiValue > 64 and asciiValue < 91) or (asciiValue = 32)) then
					set resultString to resultString & inputStringCharacter
				else
					if (asciiValue > 47 and asciiValue < 58) then
						set numberStrings to {"ZERO", "ONE", "TWO", "THREE", "FOR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE"}
						set itemIndex to asciiValue - 47
						set numberString to item itemIndex of numberStrings
						set resultString to resultString & numberString & " "
					else
						if (asciiValue = 33) then
							set resultString to resultString & " DUH"
						else
							if (asciiValue = 63) then
								set resultString to resultString & " IF YOU KNOW WHAT I MEAN"
							end if
						end if
					end if
				end if
			end if
		end repeat
	
		resultString
	end chockify

In my opinion, AppleScript's greatest strength is not its syntax. Nor is its ability to process strings, even when its making them AWESOME DUH

When developing scripts like this, I constantly refer to the [AppleScript Language Guide](https://developer.apple.com/library/mac/documentation/applescript/conceptual/applescriptlangguide/introduction/ASLR_intro.html#//apple_ref/doc/uid/TP40000983-CH208-SW1). The good news is that scripts that communicate with other apps are typically short and sweet. AppleScript can be thought of as a transport mechanism rather than a processing environment. The script shown above is atypical.

Once you have your script written and tested, you can get back to the comfortable environs of Objective-C. And the first line of code you'll write is a trip back in time to the Carbon era:

	#import <Carbon/Carbon.h> // for AppleScript definitions

Don't worry, you're not going to do anything crazy like add a framework to the project. You just need Carbon.h because it has a list of all the AppleEvent definitions. Remember, this code has been around for over 20 years!

Once you have the definitions, you can create an event descriptor. This is a chunk of data that is passed both to and from your script. At this point, you can think of it as an encapsulation of a target that will execute the event, a function to call, and a list of parameters for that function. Here is one for the "chockify" function above using an NSString as a parameter:

	- (NSAppleEventDescriptor *)chockifyEventDescriptorWithString:(NSString *)inputString
	{
		// parameter
		NSAppleEventDescriptor *parameter = [NSAppleEventDescriptor descriptorWithString:inputString];
		NSAppleEventDescriptor *parameters = [NSAppleEventDescriptor listDescriptor];
		[parameters insertDescriptor:parameter atIndex:1]; // you have to love a language with indices that start at 1 instead of 0
	
		// target
		ProcessSerialNumber psn = {0, kCurrentProcess};
		NSAppleEventDescriptor *target = [NSAppleEventDescriptor descriptorWithDescriptorType:typeProcessSerialNumber bytes:&psn length:sizeof(ProcessSerialNumber)];
	
		// function
		NSAppleEventDescriptor *function = [NSAppleEventDescriptor descriptorWithString:@"chockify"];
	
		// event
		NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite eventID:kASSubroutineEvent targetDescriptor:target returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
		[event setParamDescriptor:function forKeyword:keyASSubroutineName];
		[event setParamDescriptor:parameters forKeyword:keyDirectObject];
	
		return event;
	}

_Note:_ This code is available on [my GitHub account](https://github.com/chockenberry) as [Scriptinator](https://github.com/chockenberry/Scriptinator). The `Automation.scpt` file contains the "chockify" function and all the other scripts used in this tutorial. The Objective-C code is all in `AppDelegate.m`.

Now that you have an event descriptor that tells AppleScript what you want to do, you need to give it somewhere to do it. That means loading an AppleScript from your application bundle: 

	NSURL *URL = [[NSBundle mainBundle] URLForResource:@"Automation" withExtension:@"scpt"];
	if (URL) {
		NSAppleScript *appleScript = [[NSAppleScript alloc] initWithContentsOfURL:URL error:NULL];
	
		NSAppleEventDescriptor *event = [self chockifyEventDescriptorWithString:[self.chockifyInputTextField stringValue]];
		NSDictionary *error = nil;
		NSAppleEventDescriptor *resultEventDescriptor = [appleScript executeAppleEvent:event error:&error];
		if (! resultEventDescriptor) {
			NSLog(@"%s AppleScript run error = %@", __PRETTY_FUNCTION__, error);
		}
		else {
			NSString *string = [self stringForResultEventDescriptor:resultEventDescriptor];
			[self updateChockifyTextFieldWithString:string];
		}
	}

An instance of `NSAppleScript` is created using a URL from the application bundle. That script, in turn, is used with the "chockify" event descriptor created above. If everything goes according to plan, you end up with another event descriptor. If not, you get a dictionary back that contains information describing what went wrong. Although the pattern is similar to many other Foundation classes, the error _is not_ an instance of `NSError`.

All that's left to do now is extract the information you want from the descriptor:

	- (NSString *)stringForResultEventDescriptor:(NSAppleEventDescriptor *)resultEventDescriptor
	{
		NSString *result = nil;
	
		if (resultEventDescriptor) {
			if ([resultEventDescriptor descriptorType] != kAENullEvent) {
				if ([resultEventDescriptor descriptorType] == kTXNUnicodeTextData) {
					result = [resultEventDescriptor stringValue];
				}
			}
		}
	
		return result;
	}

Your inputString just got a FACE LIFT and you've seen everything you need to run AppleScripts from your app. Sort of.


The way it used to be
---------------------

There was a time when you could send AppleEvents to any application, not just to the currently running application as with "chockify" above.

Say you wanted to know what URL was loaded into the frontmost window of Safari. All you needed to do was `tell application "Safari"` what to do:

	on safariURL()
		tell application "Safari" to return URL of front document
	end safariURL

These days, all that's likely to produce is the following in your Debug Console:

	AppleScript run error = {
		NSAppleScriptErrorAppName = Safari;
		NSAppleScriptErrorBriefMessage = "Application isn\U2019t running.";
		NSAppleScriptErrorMessage = "Safari got an error: Application isn\U2019t running.";
		NSAppleScriptErrorNumber = "-600";
		NSAppleScriptErrorRange = "NSRange: {0, 0}";
	}

Even though Safari is running. What. The.


Sandbox restrictions
--------------------

You're trying to run this script from an application sandbox. As far as that sandbox is concerned, Safari is, in fact, not running.

The problem is that no one gave your app permission to talk to Safari. This turns out to be a pretty big security hole: a script can easily get the contents of the current page or even run JavaScript against any tab of any window in browser. Imagine how great that would be if one of those pages was for your bank account. Or a page that contained a form field with your credit card number. Ouch.

That, in a nutshell, is why arbitrary script execution was banned from the Mac App Store.

Luckily, things have gotten much better in recent releases of OS X. In 10.8 (Mountain Lion), Apple introduced a new abstract class called `NSUserScriptTask`. There are three concrete subclasses that let you run Unix shell commands (`NSUserUnixTask`), Automator workflows (`NSUserAutomatorTask`), and of course AppleScript (`NSUserAppleScriptTask`). The remainder of this tutorial will focus on that last class since it's the one most commonly used.

Apple's mantra for the application sandbox is "Driving security policy through user intent." In practice, this means a user has to decide they want to run your script, no matter where it came from. You need permission to run a script and once that permission is granted, the script is run in a way where its interaction with the rest of the system is limited. `NSUserScriptTask` makes all this possible.


Installing scripts
------------------

The "granting access" part of this system is that an application can only run scripts from a specific folder in the User's account. The only way scripts can get into that folder is if the user copies them there.

This presents a challenge: the folder is in User > Library > Application Scripts and is named using the application's bundle identifier. For [Scriptinator](https://github.com/chockenberry/Scriptinator) it's `com.iconfactory.Scriptinator`. None of this is very user friendly, especially since the Library folder is hidden by default on OS X.

One approach to this problem is to implement some code that makes is easy for your customer to open this hidden folder. For example:

	NSError *error;
	NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationScriptsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
	[[NSWorkspace sharedWorkspace] openURL:directoryURL];

That's a great solution for scripts actually written by a customer. But sometimes you'll want to help the end user install scripts that you've written to make a part of your app work better. How do you get scripts from your application bundle into the user's scripts folder?

The solution here is to get a permission to write into that folder. You need to update your app's Capabilities under App Sandbox > File Access to "User Selected File to Read/Write". Again, user intent is the guiding factor here:

	NSError *error;
	NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationScriptsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setDirectoryURL:directoryURL];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:NO];
	[openPanel setPrompt:@"Select Script Folder"];
	[openPanel setMessage:@"Please select the User > Library > Application Scripts > com.iconfactory.Scriptinator folder"];
	[openPanel beginWithCompletionHandler:^(NSInteger result) {
		if (result == NSFileHandlingPanelOKButton) {
			NSURL *selectedURL = [openPanel URL];
			if ([selectedURL isEqual:directoryURL]) {
				NSURL *destinationURL = [selectedURL URLByAppendingPathComponent:@"Automation.scpt"];
				NSFileManager *fileManager = [NSFileManager defaultManager];
				NSURL *sourceURL = [[NSBundle mainBundle] URLForResource:@"Automation" withExtension:@"scpt"];
				NSError *error;
				BOOL success = [fileManager copyItemAtURL:sourceURL toURL:destinationURL error:&error];
				if (success) {
					NSAlert *alert = [NSAlert alertWithMessageText:@"Script Installed" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"The Automation script was installed succcessfully."];
					[alert runModal];
				}
				else {
					NSLog(@"%s error = %@", __PRETTY_FUNCTION__, error);
					if ([error code] == NSFileWriteFileExistsError) {
						// this is where you could update the script, by removing the old one and copying in a new one
					}
					else {
						// the item couldn't be copied, try again
						[self performSelector:@selector(installAutomationScript:) withObject:self afterDelay:0.0];
					}
				}
			}
			else {
				// try again because the user changed the folder path
				[self performSelector:@selector(installAutomationScript:) withObject:self afterDelay:0.0];
			}
		}
	}];

That `Automation.scpt` file that we used to run from inside the application bundle is now exposed in the regular file system.

It's important throughout this entire process to let your customer know what's going on. You have to remember that they're the ones in control of the script, not you. If they decide to clear out all their scripts from the folder, you need to cope with that. Either disable an app feature that requires the script or prompt to install the script again.

_Note:_ The [Scriptinator](https://github.com/chockenberry/Scriptinator) sample code includes both of the approaches shown above. For a real world example, take a look at the [Overlay](http://xscopeapp.com/guide#overlay) tool in [xScope](http://xscopeapp.com/). It has a user-friendly setup procedure and sophisticated scripting that lets the app communicate with the customer's web browser. As a bonus, you may find that xScope is a great tool for doing web and app development!


Scripting tasks
---------------

Now that you have the automation scripts in the right place, you can start to use them.

In the code below, the event descriptors that we created above have not changed. The only thing that's different is how they're run: you'll be using an `NSUserAppleScriptTask` instead of `NSAppleScript`.

Since you'll presumably using these automation script tasks frequently. The documentation warns that `NSUserAppleScriptTask` "should be invoked no more than once for a given instance of the class" so it's a good idea to write a factory method that creates them as needed:

	- (NSUserAppleScriptTask *)automationScriptTask
	{
		NSUserAppleScriptTask *result = nil;
	
		NSError *error;
		NSURL *directoryURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationScriptsDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
		if (directoryURL) {
			NSURL *scriptURL = [directoryURL URLByAppendingPathComponent:@"Automation.scpt"];
			result = [[NSUserAppleScriptTask alloc] initWithURL:scriptURL error:&error];
			if (! result) {
				NSLog(@"%s no AppleScript task error = %@", __PRETTY_FUNCTION__, error);
			}
		}
		else {
			// NOTE: if you're not running in a sandbox, the directory URL will always be nil
			NSLog(@"%s no Application Scripts folder error = %@", __PRETTY_FUNCTION__, error);
		}

		return result;
	}

If you're writing a Mac app that has both a sandboxed and non-sandboxed version, you'll need to be careful getting the `directoryURL`. The `NSApplicationScriptsDirectory` is only available when sandboxed.

After creating the script task, you execute it with an AppleEvent and provide a completion handler:

	NSUserAppleScriptTask *automationScriptTask = [self automationScriptTask];
	if (automationScriptTask) {
		NSAppleEventDescriptor *event = [self safariURLEventDescriptor];
		[automationScriptTask executeWithAppleEvent:event completionHandler:^(NSAppleEventDescriptor *resultEventDescriptor, NSError *error) {
			if (! resultEventDescriptor) {
				NSLog(@"%s AppleScript task error = %@", __PRETTY_FUNCTION__, error);
			}
			else {
				NSURL *URL = [self URLForResultEventDescriptor:resultEventDescriptor];
				// NOTE: The completion handler for the script is not run on the main thread. Before you update any UI, you'll need to get
				// on that thread by using libdispatch or performing a selector.
				[self performSelectorOnMainThread:@selector(updateURLTextFieldWithURL:) withObject:URL waitUntilDone:NO];
			}
		}];
	}

For scripts that a user has written, they may expect your app to just "run" the script. In that case, you'll pass `nil` for the event parameter and everyone will be happy.

One of the nice things about `NSUserAppleScriptTask` is the completion handler. Scripts are run asynchronously, so your user interface doesn't need to block while a (potentially lengthy) script is run. Just be careful about what you do in that completion handler: it's not running on the main thread, so don't do updates to your user interface there.


Behind the scenes
-----------------

What's going on behind the scenes?

As you may have guessed by the fact that scripts are run asynchronously, 

If you sniff around in the sender process id for the events, you'll see they come from /usr/libexec/lsboxd

Scripts are run out of process using XPC
Same technology that lets iOS 8 implement extensions.
Explains why you can't reuse the NSUserScriptTask
"This method should be invoked no more than once for a given instance of the class."

WWDC Session...
The OS X App Sandbox - WWDC 2012 video: https://developer.apple.com/videos/wwdc/2012/
Ivan Krstić entertaining and explains security goals at a high-level.
36 minutes in: Automation changes

Secure Automation Techniques in OS X - WWDC 2012 video
Sal Soghoian & Chris Nebel explains app to app communication at 24 minutes in.
35 minutes in talks about Application-Run User Scripts. 41 minutes, Chris explains in detail.

Access Groups not discussed here, but you'll want to learn about them if you're scripting system apps like Mail or iTunes.

Synchronicity
-------------

One subtle difference between executing an NSAppleScript object and running an NSUserAppleScriptTask is that the former is synchronous. There's no completion handler, you just run the script and it returns after it's done.

For the most part, using the asynchronous handler is a much better way to deal with things: nothing to block your UI.
There are cases where your app may need to do some processing of the data before it starts another task.

Use a semaphore in this case.
In class or application initialization, use:

	self.appleScriptTaskSemaphore = dispatch_semaphore_create(1);

Then wait and signal on that semaphore when executing the task:

	// wait for any previous tasks to complete before starting a new one — remember that you're blocking the main thread here!
	dispatch_semaphore_wait(self.appleScriptTaskSemaphore, DISPATCH_TIME_FOREVER);
	
	// run the script task
	NSAppleEventDescriptor *event = [self openNetworkPreferencesEventDescriptor];
	[automationScriptTask executeWithAppleEvent:event completionHandler:^(NSAppleEventDescriptor *resultEventDescriptor, NSError *error) {
		if (! resultEventDescriptor) {
			NSLog(@"%s AppleScript task error = %@", __PRETTY_FUNCTION__, error);
		}
		else {
			[self performSelectorOnMainThread:@selector(showNetworkAlert) withObject:nil waitUntilDone:NO];
		}
		
		// the task has completed, so let any pending tasks proceed
		dispatch_semaphore_signal(self.appleScriptTaskSemaphore);
	}];

Wrapping up
-----------

TBD




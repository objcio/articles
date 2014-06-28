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

_Note:_ This code is available on [my GitHub account](https://github.com/chockenberry) as [Scriptinator](https://github.com/chockenberry/Scriptinator). The `Automation.scpt` file contains the "chockify" function and all the other scripts used in this tutorial.

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

An instance of `NSAppleScript` is created using a URL from application bundle. That script, in turn, is used with the "chockify" event descriptor created above. If everything goes according to plan, you end up with another event descriptor. If not, you get a dictionary back that contains information describing what went wrong. Although the pattern is similar to many other Foundation classes, the error _is not_ an instance of `NSErrror`.

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

Your inputString just got a FACE LIFT and you now know everything you need to run AppleScripts from your app. Sort of.


The way it used to be
---------------------

You could talk to other applications.

But if your script contains a "tell application", you're stuck:

	on safariURL()
		tell application "Safari" to return URL of front document
	end safariURL

You'll see something like this logged in your debug console:

	AppleScript run error = {
		NSAppleScriptErrorAppName = Safari;
		NSAppleScriptErrorBriefMessage = "Application isn\U2019t running.";
		NSAppleScriptErrorMessage = "Safari got an error: Application isn\U2019t running.";
		NSAppleScriptErrorNumber = "-600";
		NSAppleScriptErrorRange = "NSRange: {0, 0}";
	}

Even if Safari is, in fact, running.


Sandbox restrictions
--------------------

No one gave your app permission to talk to Safari.
It's a pretty big security hole.
A script can easily get the contents of the current page or even run JavaScript on any tab of any window.
Imagine how great you'd feel if one of those pages was your bank account.

Things got a lot better with the release of OS X 10.8 (Mountain Lion)
Apple introduced a new abstract class called NSUserScriptTask.
There are three concrete subclasses that let you run Unix shell commands (NSUserUnixTask), Automator workflows (NSUserAutomatorTask), and of course AppleScript (NSUserAppleScriptTask).
The remainder of this tutorial will focus on that last class since it's the most common use case.

"Driving security policy through user intent"
Tell the user why you're installing a script and what it's going to do.
Remember, they can also delete script at any time.

Installing Scripts
------------------

There is only one place where your automation script can be installed.
Application Scripts is in Library folder.
One that most people can't even get to because Library is hidden.
How do you get the script where it needs to be?

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

For this to work, you MUST update the Capbilities > App Sandbox > File Access > User Selected File to Read/Write.

Note: You can run this code using my Scriptinator project on GitHub. For a real world example, take a look at the Overlay tool in xScope. It has a user-friendly setup procedure and sophisticated scripting that lets the app communicate with the customer's web browser. As a bonus, you'll find that xScope is a great tool for doing development: that's why we wrote it!


Scripting Tasks
---------------

Now that you have the automation script in the right place, you can start to use it.

First, you'll need to create an automation script task:

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

Then give it an event descriptor:

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

Pass nil for event to -executeWithAppleEvent: and the script's default "run" handler is called.
Note: completion handler is not called on the main thread.
Get there before updating UI elements.

What's going on behind the scenes?
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




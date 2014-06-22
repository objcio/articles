Scripting from a Sandbox
========================

Introduction
------------

Scripting between apps has long been a part of the Mac ecosystem.
As Brent is showing in his article, you make your app scriptable so that people can do things you never dreamed of implementing.
This tutorial will show how your own app can communicate with another app using AppleScript.

History: Apple announced sandboxing for Mac apps on 10.7 in 2011. Initially for App Store submissions as o November 1st, 2011, but that deadline was pushed back several times until it eventually went into effect on June 1st, 2012.

Unlike iOS developers who have always run in this environment, it was quite a shock for many long-time developers.
As I heard one Apple security engineer put it, "we're putting the genie back into the bottle."

Scripting apps was one of the hardest changes. Initially, Apple dealt with this situation by granting "temporary exceptions" in the application entitlements.
Still, many things that used to be easy, were suddenly hard or outright impossible do to in a sandbox.
Luckily, things have gotten much better in the past couple of years.
This tutorial will guide you through the current best practices for controlling other apps with AppleScript.

This also fits in well with Brent's tutorial on adding AppleScript support to an app. Between the two of us, both sides of the fence are covered.


First steps
-----------

Before we get into the problems associated with running AppleScripts from an app, you need to first come up to speed on how these scripts are run.

The first thing to do is to write an AppleScript:

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

In my opinion, AppleScript's greatest strength is not its syntax.
Nor is its ability to process strings.
Even when it's making it strings AWESOME DUH

I'm constantly referring to this: https://developer.apple.com/library/mac/documentation/applescript/conceptual/applescriptlangguide/introduction/ASLR_intro.html#//apple_ref/doc/uid/TP40000983-CH208-SW1

Scripts will typically be short and sweet.
Mainly a transport mechanism, not much processing.

Before you write any Objective-C code, you need to take a quick step back in time.
To the Carbon era:

	#import <Carbon/Carbon.h> // for AppleScript definitions

Nothing crazy like adding a framework, just the header.

An event descriptor, with optional parameters, is created to call a function in that script.

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

The Automation.scpt file contains this code for the "chockify" function specified above:


NSAppleScript is loaded from a URL.

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

The script is executed using the event descriptor. After the script is run, another event descriptor is returned.
Any information you need is extracted from the result.

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

Note: You can run this code using my Scriptinator project on GitHub. For a real world example, take a look at the Overlay tool in xScope. It has a user-friendly setup procedure and sophisticated scripting that lets the app communicate with the customer's web browser. As a bonus, you'll find that xScope is a great tool for doing development: that's why we wrote it!


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




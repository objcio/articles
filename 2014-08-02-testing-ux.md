+---
 layout: post
 title: Testing user interaction
 category: "15"
 date: "2014-08-02 09:00:00"
 author: "<a href=\"http://annema.me">Klaas Pieter Annema</a>"
 tags: article
 +---

One question often asked about iOS (and I guess Mac, and every other UI driven platform) is how to test UIs. A lot of us don't do it all, often saying things like: “you should only test your business logic.” Others want to test the UI, but deem it too complex.

Whenever someone tells me UI testing is hard, I think back to something [Landon Fuller](https://twitter.com/landonfuller) said about testing the UI of [Paper (by 53)](https://www.fiftythree.com/paper) during a [panel about testing](http://www.meetup.com/CocoaPods-NYC/events/164278492/) we were both part of:

> What you see on the screen is the culmination of a variety of data and transforms applied to that data over time ... Being able to decompose those thing into testable units means you can break things down, that are relatively complex, into more easily understood elements.

Paper’s UI is relatively complex. Testability is not something usually taken into account when building such a UI. However, any action taken by the user is modeled in code somewhere. It’s always possible to fake the user’s action in a test. The problem is that most frameworks, including UIKit, often don’t expose the necessary lower level constructs publicly.

Knowing what to test is as important as knowing how to test. I've been referring to “UI testing,” because that's the accepted term for the type of testing I'm going to discuss. In truth I think you can split UI testing into two categories: 1) Behavior and 2) Aesthetics.

There is no way to deterministically say that aesthetics are correct and they tend to change very often. You don't want to have to change your tests every time you're tweaking the UI. That's not to say that you can't test the aesthetics at all. I have no experience with it but verifying aesthetics could be done with snapshots. Read Orta’s article to learn more [about it]().

The remainder of this article will be about testing user behavior. I've provided a project on [Github](https://github.com/klaaspieter/objc-io-issue-15-ux-testing) with some practical examples. It’s written for iOS using Objective-C, but the underlying principles can be applied to the Mac and other UI frameworks.

The number one principle I apply to testing user experience is to make it appear to your code as if the user has triggered the action. This can be tricky because, as said before, frameworks don't always expose all of the necessary lower level APIs.

Projects like [KIF][], [Frank][] and [Calabash][] solve this problem, but at the cost of introducing an additional layer of complexity. We should always use the simplest possible solution that gets the job done. You want your tests to be deterministic. They need to fail or pass consistently. The worst test suites are those that fail at random. I prefer not to use these solutions because, in my experience, they introduce too much complexity at the cost of reliability and stability.

[KIF]: https://github.com/kif-framework/KIF
[Frank]: http://www.testingwithfrank.com/
[Calabash]: http://calaba.sh/

There are cases where these projects are useful. A custom UI like [Clear][] for example. UIKit simply doesn't provide access to the right APIs to programmatically perform the gestures required to test Clear's UI.

[Clear]: http://realmacsoftware.com/clear

Note that I've used [Specta][] and [Expecta][] in the example project. Technically this isn't the simplest possible solution, XCTest is. There are various reasons why I [prefer them](http://www.annema.me/why-i-prefer-testing-with-specta-expecta-and-ocmockito) and I know from experience they don't affect the reliability and stability of my test. As a matter of fact I'd wager they make my tests better. A safe bet to make since _better_ is ambiguous.

[Specta]: https://github.com/specta/specta
[Expecta]: https://github.com/specta/expecta

Regardless of your method of testing, when testing user behavior you want to stay as close to the user as possible. You want to make it appear to your code as if the user is interacting with it. Imagine the user is looking at a view controller then taps a button which presents a new view controller. You'll want your test to present the initial view controller, tap the button and verify that the new view controller was presented.

By focussing on exercising your code as if the user had interacted with your app, you verify multiple things at once. Most importantly, you verify the expected behavior. As a side effect, you're also simultaneously testing that controls are initialized and their actions set.

For example, consider a test in which an action method is called directly. The action method has to be exposed to your test either by adding to the header, or by declaring it a test specific category. Your test is unnecessarily coupled to this specific method. If the target or action method for the button is changed your test will still pass. You want to verify that the button does what you expect. Which target and action the button has to perform the behavior is of no concern to your tests.

UIKit provides the very useful `sendActionsForControlEvents:` method on `UIControl` which we can use to fake user events. For example to tap a button:

    [_button sendActionsForControlEvent: UIControlEventTouchUpInside];

Similarly to change the selection of a `UISegmentedControl`:

    segments.selectedSegmentIndex = 1;
    [segments sendActionsForControlEvent: UIControlEventValueChanged];

Notice that it's not just sending `UIControlValueChanged`. When a user interacts with the control it will first change its selected index, then send the `UIControlEventValueChanged`. This is a good example of doing some extra work to make it appear to your code as if the user is interacting with the control. 

Not all controls in UIKit have an equivalent method to `sendActionsForControlEvents:`, but with a bit of creativity it's often possible to find a work around. As said before, the most important thing is to make it appear to your code as if the user triggered it.

For example, there is no method on UITableView to select a cell _and_ have it call its delegate or perform it's associated segue. The sample project shows two ways of working around this. 

The first method is specific to storyboards: it works by manually triggering the segue you want the table view cell to perform. Unfortunately, this does not verify that the table view cell is associated with that segue.

    [_tableViewController performSegueWithIdentifier:@"TableViewPushSegue" sender:nil];

Another option that does not require storyboards is to call the `tableView:didSelectRowAtIndexPath:` delegate method manually from your test code. If you're using storyboards you can still use segues, but you have to trigger them from the delegate method manually.

    [_viewController.tableView.delegate tableView:_viewController.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    expect(_viewController.navigationController.topViewController).to.beKindOf([PresentedViewController class]);

I prefer the second option. It completely decouples the test from how the view controller is presented. It could be a custom segue, a `presentViewController:animated:completion` or some way that Apple hasn't invented yet. All the tests cares about is that at the end the `topViewController` property is what it expects. The best option would be to ask the table view to select a row and perform the associated action, but that's not currently possible.

As a final example of testing controls, I want to present the special case of `UIBarButtonItem`s. They don't have a `sendActionsForControlEvent:` method, because they're not descendent from `UIControl`. Let's figure out how we can send the button action and, to our code, make it look like the user tapped it.

A UIBarButtonItem, unlike `UIControl`, can only have one target and one action associated with it. Performing the action can be as simple as:

    [_viewController.barButton.target  performSelector:_viewController.barButton.action
                                             withObject:_viewController.barButton];

If you're using ARC, the compiler will complain because it can't infer the memory management semantics from an unknown selector. This solution is unacceptable to me because I treat warnings as errors.

One option is to use [#pragma directive](http://nshipster.com/pragma/#inhibiting-warnings) to hide the warning. Another alternative is to use the runtime directly:

    #import <objc/message.h>

    objc_msgSend(_viewController.barButton.target, _viewController.barButton.action, _viewController.barButton);

I prefer the runtime method because I dislike cluttering my test code with pragma directives and secretly also because it gives me an excuse to use the runtime.

To be honest I'm not 100% certain these 'solutions' can't cause issues. This doesn't solve the underlying warning. Tests are usually short lived so any memory issues that do occur are unlikely to cause problems. It's been working well for me for quite some time, but this is a case I don't fully understand and it could turn into a bug that randomly fails at some point. I'm interested [in hearing](https://twitter.com/klaaspieter) about any potential issues.

I want to end with view controllers. View controllers are likely the most important component of any iPhone application. They're the abstraction used to mediate between the view and your business logic. In order to test the behavior as best as possible we're going to have to present them. Presenting view controllers in test cases quickly lead me to conclude they weren't built with testing in mind. 

Presenting and dismissing view controllers is the best way to make sure every test has a consistent start state. Unfortunately, doing so in rapid succession, like a test runner does, will quickly result in error messages like:

- Warning: Attempt to dismiss from view controller <UINavigationController: 0x109518bd0> while a presentation or dismiss is in progress!
- Warning: Attempt to present <PresentedViewController: 0x10940ba30> on <UINavigationController: 0x109518bd0> while a presentation is in progress!
- Unbalanced calls to begin/end appearance transitions for <UINavigationController: 0x109518bd0>.
- nested push animation can result in corrupted navigation bar

A test suite should be as fast as possible. Waiting for each presentation to finish is not an option. It turns out, the checks raising these warnings are on a per window basis. Presenting each view controller in its own window gives you a consistent start state for your test while also keeping them fast. By presenting each in it's own window, you never have to wait for a presentation or dismissal to finish.

There are more issues with view controllers. For example, pushing to a navigation controller happens on the next runloop, while presenting a view controller modally doesn't. If you're interested in trying out this way of testing I recommend you take a look at my [view controller test helper](https://github.com/klaaspieter/KPAViewControllerTestHelper) which solves these problems for you.

When testing behavior, often you need to ensure that, through some interaction, a new view controller was presented. In other words, you need to verify the current state of the view controller hierarchy. UIKit does a great job providing the methods needed to verify this. For example, this is how you would make sure that a view controller was modally presented:

    expect(_viewController.presentedViewController).to.beKindOf([PresentedViewController class]);

Or pushed to a navigation controller:

    expect(_viewController.navigationController.topViewController).to.beKindOf([PresentedViewController class]);

Testing the UI isn't hard. Just be aware of what you're testing. You want to test user behavior, not application aesthetics. With creativity and persistence, most of the framework shortcomings can be worked around without sacrificing the stability and maintainability of your test suite. Just always remember to write tests to exercise the code as if the user is performing the action.
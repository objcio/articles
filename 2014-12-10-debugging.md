# Debugging Code

Nobody writes perfect code, and debugging is something everyone of us should be able to do well. Instead of a random list of tips, I'll walk you through a bug that turned out to be a regression in UIKit, and show you the workflow I used to understand, isolate and ultimately work around the issue.

![](dismiss-issue-animated.gif)

### Backstory

We received a bug report where quickly tapping on a button that presented a popover dismissed the popover but also the *parent* view controller. The first part of reproducing the issue was covered since we got a sample that showed the exact issue.

### Understanding the bug

My first guess was that we might have code that dismisses the view controller, and we wrongfully dismiss the parent. However, when using Xcode's integrated view debugging feature, it was clear that there was a global `UIDimmingView` that was the first responder for touch input.

![](xcode-view-debugging.png)

Xcode added the "Debug View Hierarchy" feature in Xcode 6 and it's likely that Apple got inspired by the popular Reveal and SparkInspector, which basically do the same and are even better in many ways, like allowing to actually edit properties in the views.

Before there was visual debugging, the common way to inspect the hierarchy was using `po [[UIWindow keyWindow] recursiveDescription]` in *lldb*, which prints out [the whole view hierarchy in text form](https://gist.github.com/steipete/5a3c7a3b6e80d2b50c3b). 

Similar to inspecting the view hiararchy, we can also inspect the view controller hierarchy using `po [[[UIWindow keyWindow] rootViewController] _printHierarchy]`. This is a private helper on `UIViewController` that Apple silently added in iOS 8.

```
lldb) po [[[UIWindow keyWindow] rootViewController] _printHierarchy]
<PSPDFNavigationController 0x7d025000>, state: disappeared, view: <UILayoutContainerView 0x7b3218d0> not in the window
   | <PSCatalogViewController 0x7b3100d0>, state: disappeared, view: <UITableView 0x7c878800> not in the window
   + <UINavigationController 0x8012c5d0>, state: appeared, view: <UILayoutContainerView 0x8012b7a0>, presented with: <_UIFullscreenPresentationController 0x80116c00>
   |    | <PSPDFViewController 0x7d05ae00>, state: appeared, view: <PSPDFViewControllerView 0x80129640>
   |    |    | <PSPDFContinuousScrollViewController 0x7defa8e0>, state: appeared, view: <UIView 0x7def1ce0>
   |    + <PSPDFNavigationController 0x7d21a800>, state: appeared, view: <UILayoutContainerView 0x8017b490>, presented with: <UIPopoverPresentationController 0x7f598c60>
   |    |    | <PSPDFContainerViewController 0x8017ac40>, state: appeared, view: <UIView 0x7f5a1380>
   |    |    |    | <PSPDFStampViewController 0x8016b6e0>, state: appeared, view: <UIView 0x7f3dbb90>
```

lldb is quite powerful and can also be scripted. Facebook released [a collection of python scripts named Chisel](https://github.com/facebook/chisel) that help a lot with daily debugging. `pviews` and `pvc` are the equivalents for view and view controller hierarchy printing. Chisel's view controller tree is similar, but also displays the view rects. I often use it to inspect the [responder chain](https://developer.apple.com/library/ios/documentation/EventHandling/Conceptual/EventHandlingiPhoneOS/event_delivery_responder_chain/event_delivery_responder_chain.html), and while you could manually loop over `nextResponder` on the object you're intersted in or [add a category helper](https://gist.github.com/n-b/5420684), typing `presponder object` is by far the quickest way.


### Adding breakpoints

Let's first figure out what code is actually dismissing our view controller. The most obvious action is setting a breakpoint on `viewWillDisappear:` to see the stack trace:

```
(lldb) bt
* thread #1: tid = 0x1039b3, 0x004fab75 PSPDFCatalog`-[PSPDFViewController viewWillDisappear:](self=0x7f354400, _cmd=0x03b817bf, animated='\x01') + 85 at PSPDFViewController.m:359, queue = 'com.apple.main-thread', stop reason = breakpoint 1.1
  * frame #0: 0x004fab75 PSPDFCatalog`-[PSPDFViewController viewWillDisappear:](self=0x7f354400, _cmd=0x03b817bf, animated='\x01') + 85 at PSPDFViewController.m:359
    frame #1: 0x033ac782 UIKit`-[UIViewController _setViewAppearState:isAnimating:] + 706
    frame #2: 0x033acdf4 UIKit`-[UIViewController __viewWillDisappear:] + 106
    frame #3: 0x033d9a62 UIKit`-[UINavigationController viewWillDisappear:] + 115
    frame #4: 0x033ac782 UIKit`-[UIViewController _setViewAppearState:isAnimating:] + 706
    frame #5: 0x033acdf4 UIKit`-[UIViewController __viewWillDisappear:] + 106
    frame #6: 0x033c46a1 UIKit`-[UIViewController(UIContainerViewControllerProtectedMethods) beginAppearanceTransition:animated:] + 200
    frame #7: 0x03380ad8 UIKit`__56-[UIPresentationController runTransitionForCurrentState]_block_invoke + 594
    frame #8: 0x033b47ab UIKit`__40+[UIViewController _scheduleTransition:]_block_invoke + 18
    frame #9: 0x0327a0ce UIKit`___afterCACommitHandler_block_invoke + 15
    frame #10: 0x0327a079 UIKit`_applyBlockToCFArrayCopiedToStack + 415
    frame #11: 0x03279e8e UIKit`_afterCACommitHandler + 545
    frame #12: 0x060669de CoreFoundation`__CFRUNLOOP_IS_CALLING_OUT_TO_AN_OBSERVER_CALLBACK_FUNCTION__ + 30
    frame #20: 0x032508b6 UIKit`UIApplicationMain + 1526
    frame #21: 0x000a119d PSPDFCatalog`main(argc=1, argv=0xbffcd65c) + 141 at main.m:15
(lldb) 
```

With lldb's `bt` command you can print the breakpoint. `bt all` will do the same, but printing the state of all threads, not just the current one.

When we inspect the stack trace, we notice that it's actually too late, as we're called back from an already scheduled animation. We need to add our breakpoints earlier. In this case we are interested in calls to `-[UIViewController dismissViewControllerAnimated:completion:]`. We add a *symbolic breakpoint* to Xcode's breakpoint list and run the sample again. 

The Xcode breakpoint interface is very powerful, allowing you to add [conditions, skip counts or even custom actions like playing a sound effect and automatically continuing]((http://www.peterfriese.de/debugging-tips-for-ios-developers/)). We don't need these features here, but they can save quite some time.

```
(lldb) bt
* thread #1: tid = 0x1039b3, 0x033bb685 UIKit`-[UIViewController dismissViewControllerAnimated:completion:], queue = 'com.apple.main-thread', stop reason = breakpoint 7.1
  * frame #0: 0x033bb685 UIKit`-[UIViewController dismissViewControllerAnimated:completion:]
    frame #1: 0x03a7da2c UIKit`-[UIPopoverPresentationController dimmingViewWasTapped:] + 244
    frame #2: 0x036153ed UIKit`-[UIDimmingView handleSingleTap:] + 118
    frame #3: 0x03691287 UIKit`_UIGestureRecognizerSendActions + 327
    frame #4: 0x0368fb04 UIKit`-[UIGestureRecognizer _updateGestureWithEvent:buttonEvent:] + 561
    frame #5: 0x03691b4d UIKit`-[UIGestureRecognizer _delayedUpdateGesture] + 60
    frame #6: 0x036954ca UIKit`___UIGestureRecognizerUpdate_block_invoke661 + 57
    frame #7: 0x0369538d UIKit`_UIGestureRecognizerRemoveObjectsFromArrayAndApplyBlocks + 317
    frame #8: 0x03689296 UIKit`_UIGestureRecognizerUpdate + 3720
    frame #9: 0x032a226b UIKit`-[UIWindow _sendGesturesForEvent:] + 1356
    frame #10: 0x032a30cf UIKit`-[UIWindow sendEvent:] + 769
    frame #21: 0x032508b6 UIKit`UIApplicationMain + 1526
    frame #22: 0x000a119d PSPDFCatalog`main(argc=1, argv=0xbffcd65c) + 141 at main.m:15
```

Now we're talking! As expected, the fullscreen `UIDimmingView` receives our touch and processes it in `handleSingleTap:`, then forwarding it to `UIPopoverPresentationController`'s `dimmingViewWasTapped:`, which dismisses the controller (as it should). However, when we tap quickly, this breakpoint is called twice. Is there a second dimming view? Is it called on the same instance? We only have the assembly on this breakpoint, so calling `po self` will not work. With some basic knowledge of assembly and function calling conventions, we can still get it. The [iOS ABI Function Call Guide](http://developer.apple.com/library/ios/#documentation/Xcode/Conceptual/iPhoneOSABIReference/Introduction/Introduction.html) and the [Mac OS X ABI Function Call Guide](http://developer.apple.com/library/mac/#documentation/DeveloperTools/Conceptual/LowLevelABI/000-Introduction/introduction.html) that is used in the iOS Simulator are both great resources and will improve your debugging skills.

For the 32-bit architecture, the stack is saved in $esp, so you can use `po *(int*)($esp+4)` to get self, and `p (SEL)*(int*)($esp+8)` to get _cmd in Objective-C methods. The first value in $esp is the return address.

Another way is to hook into the function to add a log statement. We could swizzle the class and then call our own code on it. Manually swizzling just to be able to debug more conveniently however isn't really time efficent. A while back I wrote a small library called [*Aspects*](http://github.com/steipete/Aspects) that does exactly that. It can be used in production code but I mostly use it for debugging and to write test cases. (If you're curious about Aspects, you can [learn more here.](https://speakerdeck.com/steipete/building-aspects))

```objc
#import "Aspects.h"

[UIPopoverPresentationController aspect_hookSelector:NSSelectorFromString(@"dimmingViewWasTapped:") withOptions:0 usingBlock:^(id <AspectInfo> info, UIView *tappedView) {
    NSLog(@"%@ dimmingViewWasTapped:%@", info.instance, tappedView);
} error:NULL];
```

This hooks into `dimmingViewWasTapped:`, which is private - thus we use `NSSelectorFromString`. You can verify that this method exists and also look up all other private and public methods of pretty much every framework class by using the [iOS-Runtime-Headers](https://github.com/nst/iOS-Runtime-Headers). This project uses the fact that one can't really hide methods at runtime to query all classes and create a more complete header than what Apple gives us. (Of course, actually calling private API is not a good idea - this is just to better understand what's going on.)

With the log message in the hooked method, we get following output:

```
PSPDFCatalog[84049:1079574] <UIPopoverPresentationController: 0x7fd09f91c530> dimmingViewWasTapped:<UIDimmingView: 0x7fd09f92f800; frame = (0 0; 768 1024)>
PSPDFCatalog[84049:1079574] <UIPopoverPresentationController: 0x7fd09f91c530> dimmingViewWasTapped:<UIDimmingView: 0x7fd09f92f800; frame = (0 0; 768 1024)>
```

We see that the object address is the same, so our poor dimming view really is called twice. We can use Aspects again to see on what controller the dismiss is actually called:

```objc
[UIViewController aspect_hookSelector:@selector(dismissViewControllerAnimated:completion:) withOptions:0 usingBlock:^(id <AspectInfo> info) {
    NSLog(@"%@ dismissed.", info.instance);
} error:NULL];
```

```
2014-11-22 19:24:51.900 PSPDFCatalog[84210:1084883] <UINavigationController: 0x7fd673789da0> dismissed.
2014-11-22 19:24:52.209 PSPDFCatalog[84210:1084883] <UINavigationController: 0x7fd673789da0> dismissed.
```

Both times, the dimming view calls dismiss on our main navigation controller. Reading the documentation of `dismissViewControllerAnimated:completion:`, it's documented that it forwards the dismiss request to it's immediate presented child controller, if there is one. So the first time, the dismiss request goes to the popover, and the second time the navigation controller itself gets dismissed.

### Finding a workaround

We now know what is happening - now let's move to the *why*. Since UIKit is closed source, we have to use *Hopper* to disassemble UIKit and take a closer look what's going on in `UIPopoverPresentationController`. You'll find the binary under `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/Frameworks/UIKit.framework`. Use File ->  Read Executable to Disassemble... and select this in Hopper, and watch how it crawls through the binary and symbolicates code. The 32-bit disassembler is the most mature one, so you'll get the best results selecting the 32-bit file slice.

![](hopper-dimmingView.png)

Some basics in assembly are quite useful when reading through the code, however you can also use the Pseudo-Code view to get something more C-like.

![](pseudo-code.png)

Reading the pseudo-code is quite eye-opening. There are two code-paths, one if the delegate implements `popoverPresentationControllerShouldDismissPopover:` and one if it doesn't, and the code paths are actually quite different. While the one reacting to the delegate basically has an `if (controller.presented && !controller.dismissing)`, the other code path (that we currently fall into) doesn't and always dismisses. With that inside knowledge, we can attempt to work around this bug by implementing our own `UIPopoverPresentationControllerDelegate`.

```
- (BOOL)popoverPresentationControllerShouldDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    return YES;
}
```

My first attempt was to set this to the main view controller that creates the popover - however that broke `UIPopoverController`. While not documented, the popover controller sets itself as the delegate in `_setupPresentationController`, and taking the delegate away will break things. Instead, I used a `UIPopoverController` subclass and added the above method directly. We rely on undocumented behavior here that the delegate is set by the system, however since the method returns the documented default, and is purely to work around an UIKit regression, that's ok.

### Reporting a Radar

Now please don't stop here. You should always properly document such workarounds, and most importantly file a radar with Apple.

```
// The UIPopoverController is the default delegate for the UIPopoverPresentationController
// of it's contentViewController.
//
// There is a bug when someone double-taps on the dimming view, the presentation controller invokes
// dismissViewControllerAnimated:completion: twice, thus also potentially dismissing the parent controller.
//
// Simply implementing this delegate runs a different code path that properly checks for dismissing.
// rdar://problem/19053416
- (BOOL)popoverPresentationControllerShouldDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    return YES;
}
```

Writing radars is actually quite a fun challenge, and takes not as much time as you might think. With an example you'll help out the (overloaded) Apple engineers and without it, they most likely push back and don't even consider the radar. I managed to create a sample in about 50 LOC including some comments and the workaround. The "Single View Template" is usually the quickest way to create an example.

Now we all know that Apple's RadarWeb application isn't great, however you don't have to use it. (QuickRadar)[http://www.quickradar.com/] is a great Mac frontend that can submit the radar for you, and also automatically sending a copy to [OpenRadar](http://openradar.appspot.com). Furthermore, it makes duping radars extremely convenient. You should download it right away and dupe rdar://19053416, if you feel like this bug should be fixed.


Not every issue can be solved with such a simple workaround, however many of these steps will help you find better solutions to issues, or at least improve your understanding why something is happening. 

### References

*  [iOS Debugging Magic (TN2239)](https://developer.apple.com/library/ios/technotes/tn2239/_index.html)
*  [iOS Runtime Headers](https://github.com/nst/iOS-Runtime-Headers)
*  [Debugging Tips for iOS Developers](http://www.peterfriese.de/debugging-tips-for-ios-developers/)
*  [Hopper - a reverse engineering tool](http://www.hopperapp.com/)
*  [Aspects - Delightful, simple library for aspect oriented programming.](http://github.com/steipete/Aspects)
*  [Building Aspects](https://speakerdeck.com/steipete/building-aspects)
*  [Event Delivery: The Responder Chain](https://developer.apple.com/library/ios/documentation/EventHandling/Conceptual/EventHandlingiPhoneOS/event_delivery_responder_chain/event_delivery_responder_chain.html)
*  [Chisel - a collection of LLDB commands to assist debugging iOS apps](https://github.com/facebook/chisel)
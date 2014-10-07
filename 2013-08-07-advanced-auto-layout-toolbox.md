---
title: "Advanced Auto Layout Toolbox"
category: "3"
date: "2013-08-07 06:00:00"
author: "<a href=\"http://twitter.com/floriankugler\">Florian Kugler</a>"
tags: article
---


Auto Layout was introduced in OS X 10.7, and one year later it made its way into iOS 6. Soon apps on iOS 7 will be expected to honor the systemwide font size setting, thus requiring even more flexibility in the user interface layout next to different screen sizes and orientations. Apple is doubling down on Auto Layout, so now is a good time to get your feet wet if you haven't done so yet.

Many developers struggle with Auto Layout when first trying it, because of the often-frustrating experience of building constraint-based layouts with Xcode 4's Interface Builder. But don't let yourself be discouraged by that; Auto Layout is much better than Interface Builder's current support for it. Xcode 5 will bring some major relief in this area.

This article is not an introduction to Auto Layout. If you haven't worked with it yet, we encourage you to watch the Auto Layout sessions from WWDC 2012 ([202 -- Introduction to Auto Layout for iOS and OS X](https://developer.apple.com/videos/wwdc/2012/?id=202), [228 -- Best Practices for Mastering Auto Layout](https://developer.apple.com/videos/wwdc/2012/?id=228), [232 -- Auto Layout by Example](https://developer.apple.com/videos/wwdc/2012/?id=232)). These are excellent introductions to the topic which cover a lot of ground.

Instead, we are going to focus on several advanced tips and techniques, which enhance productivity with Auto Layout and make your (development) life easier. Most of these are touched upon in the WWDC sessions mentioned above, but they are the kind of things that are easy to oversee or forget while trying to get your daily work done. 


<a name="layout-process"> </a>

## The Layout Process

First we will recap the steps it takes to bring views on screen with Auto Layout enabled. When you're struggling to produce the kind of layout you want with Auto Layout, specifically with advanced use cases and animation, it helps to take a step back and to recall how the layout process works.

Compared to working with springs and struts, Auto Layout introduces two additional steps to the process before views can be displayed: updating constraints and laying out views. Each step is dependent on the one before; display depends on layout, and layout depends on updating constraints.

The first step -- updating constraints -- can be considered a "measurement pass." It happens bottom-up (from subview to super view) and prepares the information needed for the layout pass to actually set the views' frame. You can trigger this pass by calling `setNeedsUpdateConstraints`. Any changes you make to the system of constraints itself will automatically trigger this. However, it is useful to notify Auto Layout about changes in custom views that could affect the layout. Speaking of custom views, you can override `updateConstraints` to add the local constraints needed for your view in this phase.

The second step -- layout -- happens top-down (from super view to subview). This layout pass actually applies the solution of the constraint system to the views by setting their frames (on OS X) or their center and bounds (on iOS). You can trigger this pass by calling `setNeedsLayout`, which does not actually go ahead and apply the layout immediately, but takes note of your request for later. This way you don't have to worry about calling it too often, since all the layout requests will be coalesced into one layout pass.

To force the system to update the layout of a view tree immediately, you can call `layoutIfNeeded`/`layoutSubtreeIfNeeded` (on iOS and OS X respectively). This can be helpful if your next steps rely on the views' frame being up to date. In your custom views you can override `layoutSubviews`/`layout` to gain full control over the layout pass. We will show use cases for this later on.

Finally, the display pass renders the views to screen and is independent of whether you're using Auto Layout or not. It operates top-down and can be triggered by calling `setNeedsDisplay`, which results in a deferred redraw coalescing all those calls. Overriding the familiar `drawRect:` is how you gain full control over this stage of the display process in your custom views.

Since each step depends on the one before it, the display pass will trigger a layout pass if any layout changes are pending. Similarly, the layout pass will trigger updating the constraints if the constraint system has pending changes. 

It's important to remember that these three steps are not a one-way street. Constraint-based layout is an iterative process. The layout pass can make changes to the constraints based on the previous layout solution, which again triggers updating the constraints following another layout pass. This can be leveraged to create advanced layouts of custom views, but you can also get stuck in an infinite loop if every call of your custom implementation of `layoutSubviews` results in another layout pass.


## Enabling Custom Views for Auto Layout

When writing a custom view, you need to be aware of the following things with regard to Auto Layout: specifying an appropriate intrinsic content size, distinguishing between the view's frame and alignment rect, enabling baseline-aligned layout, and how to hook into the layout process. We will go through these aspects one by one.


### Intrinsic Content Size

The intrinsic content size is the size a view prefers to have for a specific content it displays. For example, `UILabel` has a preferred height based on the font, and a preferred width based on the font and the text it displays. A `UIProgressView` only has a preferred height based on its artwork, but no preferred width. A plain `UIView` has neither a preferred width nor a preferred height.

You have to decide, based on the content to be displayed, if your custom view has an intrinsic content size, and if so, for which dimensions.

To implement an intrinsic content size in a custom view, you have to do two things: override [`intrinsicContentSize`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSView_Class/Reference/NSView.html#//apple_ref/occ/instm/NSView/intrinsicContentSize) to return the appropriate size for the content, and call [`invalidateIntrinsicContentSize`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSView_Class/Reference/NSView.html#//apple_ref/occ/instm/NSView/invalidateIntrinsicContentSize) whenever something changes which affects the intrinsic content size. If the view only has an intrinsic size for one dimension, return `UIViewNoIntrinsicMetric`/`NSViewNoIntrinsicMetric` for the other one.

Note that the intrinsic content size must be independent of the view's frame. For example, it's not possible to return an intrinsic content size with a specific aspect ratio based on the frame's height or width.


#### Compression Resistance and Content Hugging

Each view has content compression resistance priorities and content hugging priorities assigned for both dimensions. These properties only take effect for views which define an intrinsic content size, otherwise there is no content size defined that could resist compression or be hugged.

Behind the scenes, the intrinsic content size and these priority values get translated into constraints. For a label with an intrinsic content size of `{ 100, 30 }`, horizontal/vertical compression resistance priority of `750`, and  horizontal/vertical content hugging priority of `250`, four constraints will be generated:

    H:[label(<=100@250)]
    H:[label(>=100@750)]
    V:[label(<=30@250)]
    V:[label(>=30@750)]

If you're not familiar with the visual format language for the constraints used above, you can read up about it in [Apple's documentation](https://developer.apple.com/library/ios/documentation/UserExperience/Conceptual/AutolayoutPG/VisualFormatLanguage/VisualFormatLanguage.html). Keeping in mind that these additional constraints are generated implicitly helps to understand Auto Layout's behavior and to make better sense of its error messages.


### Frame vs. Alignment Rect

Auto Layout does not operate on views' frame, but on their alignment rect. It's easy to forget the subtle difference, because in many cases they are the same. But alignment rects are actually a powerful new concept that decouple a view's layout alignment edges from its visual appearance.

For example, a button in the form of a custom icon that is smaller than the touch target we want to have would normally be difficult to lay out. We would have to know about the dimensions of the artwork displayed within a larger frame and adjust the button's frame accordingly, so that the icon lines up with other interface elements. The same happens if we want to draw custom ornamentation around the content, like badges, shadows, and reflections.

Using alignment rects we can easily define the rectangle which should be used for layout. In most cases you can just override the [`alignmentRectInsets`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSView_Class/Reference/NSView.html#//apple_ref/occ/instm/NSView/alignmentRectInsets) method, which lets you return edge insets relative to the frame. If you need more control you can override the methods [`alignmentRectForFrame:`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSView_Class/Reference/NSView.html#//apple_ref/occ/instm/NSView/alignmentRectForFrame:) and [`frameForAlignmentRect:`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSView_Class/Reference/NSView.html#//apple_ref/occ/instm/NSView/frameForAlignmentRect:). This can be useful if you want to calculate the alignment rect based on the current frame value instead of just subtracting fixed insets. But you have to make sure that these two methods are inverses of each other.

In this context it is also good to recall that the aforementioned intrinsic content size of a view refers to its alignment rect, not to its frame. This makes sense, because Auto Layout generates the compression resistance and content hugging constraints straight from the intrinsic content size.


### Baseline Alignment

To enable constraints using the `NSLayoutAttributeBaseline` attribute to work on a custom view, we have to do a little bit of extra work. Of course this only makes sense if the custom view in question has something like a baseline.

On iOS, baseline alignment can be enabled by implementing [`viewForBaselineLayout`](http://developer.apple.com/library/ios/documentation/UIKit/Reference/UIView_Class/UIView/UIView.html#//apple_ref/occ/instm/UIView/viewForBaselineLayout). The bottom edge of the view you return here will be used as baseline. The default implementation simply returns self, while a custom implementation can return any subview. On OS X you don't return a subview but an offset from the view's bottom edge by overriding [`baselineOffsetFromBottom`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSView_Class/Reference/NSView.html#//apple_ref/occ/instm/NSView/baselineOffsetFromBottom), which has the same default behavior as its iOS counterpart by returning 0 in its default implementation.


### Taking Control of Layout

In a custom view you have full control over the layout of its subviews. You can add local constraints, you can change local constraints if a change in content requires it, you can fine-tune the result of the layout pass for subviews, or you can opt out of Auto Layout altogether.

Make sure though that you use this power wisely. Most cases can be handled by simply adding local constraints for your subviews.


#### Local Constraints

If we want to compose a custom view out of several subviews, we have to lay out these subviews somehow. In an Auto Layout environment it is most natural to add local constraints for these views. However, note that this makes your custom view dependent on Auto Layout, and it cannot be used anymore in windows without Auto Layout enabled. It's best to make this dependency explicit by implementing [`requiresConstraintBasedLayout`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSView_Class/Reference/NSView.html#//apple_ref/occ/clm/NSView/requiresConstraintBasedLayout) to return `YES`.

The place to add local constraints is [`updateConstraints`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSView_Class/Reference/NSView.html#//apple_ref/occ/instm/NSView/updateConstraints). Make sure to invoke `[super updateConstraints]` in your implementation *after* you've added whatever constraints you need to lay out the subviews. In this method, you're not allowed to invalidate any constraints, because you are already in the first step of the [layout process][110] described above. Trying to do so will generate a friendly error message informing you that you've made a "programming error."

If something changes later on that invalidates one of your constraints, you should remove the constraint immediately and call [`setNeedsUpdateConstraints`](http://developer.apple.com/library/ios/documentation/UIKit/Reference/UIView_Class/UIView/UIView.html#//apple_ref/occ/instm/UIView/setNeedsUpdateConstraints). In fact, that's the only case where you should have to trigger a constraint update pass.


#### Control Layout of Subviews

If you cannot use layout constraints to achieve the desired layout of your subviews, you can go one step further and override [`layoutSubviews`](http://developer.apple.com/library/ios/documentation/UIKit/Reference/UIView_Class/UIView/UIView.html#//apple_ref/occ/instm/UIView/layoutSubviews) on iOS or [`layout`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSView_Class/Reference/NSView.html#//apple_ref/occ/instm/NSView/layout) on OS X. This way, you're hooking into the second step of the [layout process][110], when the constraint system has already been solved and the results are being applied to the view. 

The most drastic approach is to override `layoutSubviews`/`layout` without calling the super class's implementation. This means that you're opting out of Auto Layout for the view tree within this view. From this point on, you can position subviews manually however you like.

If you still want to use constraints to lay out subviews, you have to call `[super layoutSubviews]`/`[super layout]` and make fine-tuned adjustments to the layout afterwards. You can use this to create layouts which are not possible to define using constraints, for example layouts involving relationships between the size and the spacing between views.

Another interesting use case for this is to create a layout-dependent view tree. After Auto Layout has done its first pass and set the frames on your custom view's subviews, you can inspect the positioning and sizing of these subviews and make changes to the view hierarchy and/or to the constraints. WWDC session [228 -- Best Practices for Mastering Auto Layout](https://developer.apple.com/videos/wwdc/2012/?id=228) has a good example of this, where subviews are removed after the first layout pass if they are getting clipped. 

You could also decide to change the constraints after the first layout pass. For example, switch from lining up subviews in one row to two rows, if the views are becoming too narrow. 

    - layoutSubviews
    {
        [super layoutSubviews];
        if (self.subviews[0].frame.size.width <= MINIMUM_WIDTH) {
            [self removeSubviewConstraints];
            self.layoutRows += 1;
            [super layoutSubviews];
        }
    }
    
    - updateConstraints
    {
        // add constraints depended on self.layoutRows...
        [super updateConstraints];
    }


## Intrinsic Content Size of Multi-Line Text

The intrinsic content size of `UILabel` and `NSTextField` is ambiguous for multi-line text. The height of the text depends on the width of the lines, which is yet to be determined when solving the constraints. In order to solve this problem, both classes have a new property called [`preferredMaxLayoutWidth`](http://developer.apple.com/library/ios/documentation/uikit/reference/UILabel_Class/Reference/UILabel.html#//apple_ref/occ/instp/UILabel/preferredMaxLayoutWidth), which specifies the maximum line width for calculating the intrinsic content size. 

Since we usually don't know this value in advance, we need to take a two-step approach to get this right. First we let Auto Layout do its work, and then we use the resulting frame in the layout pass to update the preferred maximum width and trigger layout again.

    - (void)layoutSubviews
    {
        [super layoutSubviews];
        myLabel.preferredMaxLayoutWidth = myLabel.frame.size.width;
        [super layoutSubviews];
    }

The first call to `[super layoutSubviews]` is necessary for the label to get its frame set, while the second call is necessary to update the layout after the change. If we omit the second call we get a `NSInternalInconsistencyException` error, because we've made changes in the layout pass which require updating the constraints, but we didn't trigger layout again.

We can also do this in a label subclass itself:

    @implementation MyLabel
    - (void)layoutSubviews
    {
        self.preferredMaxLayoutWidth = self.frame.size.width;
        [super layoutSubviews];
    }
    @end

In this case, we don't need to call `[super layoutSubviews]` first, because when `layoutSubviews` gets called, we already have a frame on the label itself.

To make this adjustment from the view controller level, we hook into `viewDidLayoutSubviews`. At this point the frames of the first Auto Layout pass are already set and we can use them to set the preferred maximum width. 

    - (void)viewDidLayoutSubviews
    {
        [super viewDidLayoutSubviews];
        myLabel.preferredMaxLayoutWidth = myLabel.frame.size.width;
        [self.view layoutIfNeeded];
    }

Lastly, make sure that you don't have an explicit height constraint on the label that has a higher priority than the label's content compression resistance priority. Otherwise it will trump the calculated height of the content.


## Animation

When it comes to animating views laid out with Auto Layout, there are two fundamentally different strategies: Animating the constraints themselves, and changing the constraints to recalculate the frames and use Core Animation to interpolate between the old and the new position.

The difference between the two approaches is that animating constraints themselves results in a layout that conforms to the constraint system at all times. Meanwhile, using Core Animation to interpolate between old and new frames violates constraints temporarily.

Directly animating constraints is really only a feasible strategy on OS X, and it is limited in what you can animate, since only a constraint's constant can be changed after creating it. On iOS you would have to drive the animation manually, whereas on OS X you can use an animator proxy on the constraint's constant. Furthermore, this approach is significantly slower than the Core Animation approach, which also makes it a bad fit for mobile platforms for the time being.

When using the Core Animation approach, animation conceptually works the same way as without Auto Layout. The difference is that you don't set the views' target frames manually, but instead you modify the constraints and trigger a layout pass to set the frames for you. On iOS, instead of:

    [UIView animateWithDuration:1 animations:^{
        myView.frame = newFrame;
    }];

you now write:

    // update constraints
    [UIView animateWithDuration:1 animations:^{
        [myView layoutIfNeeded];
    }];

Note that with this approach, the changes you can make to the constraints are not limited to the constraints' constants. You can remove constraints, add constraints, and even use temporary animation constraints. Since the new constraints only get solved once to determine the new frames, even more complex layout changes are possible.

The most important thing to remember when animating views using Core Animation in conjunction with Auto Layout is to not touch the views' frame yourself. Once a view is laid out by Auto Layout, you've transferred the responsibility to set its frame to the layout system. Interfering with this will result in weird behavior.

This means also that view transforms don't always play nice with Auto Layout if they change the view's frame. Consider the following example:

    [UIView animateWithDuration:1 animations:^{
        myView.transform = CGAffineTransformMakeScale(.5, .5);
    }];

Normally we would expect this to scale the view to half its size while maintaining its center point. But the behavior with Auto Layout depends on the kind of constraints we have set up to position the view. If we have it centered within its super view, the result is as expected, because applying the transform triggers a layout pass which centers the new frame within the super view. However, if we have aligned the left edge of the view to another view, then this alignment will stick and the center point will move. 

Anyway, applying transforms like this to views laid out with constraints is not a good idea, even if the result matches our expectations at first. The view's frame gets out of sync with the constraints, which will lead to strange behavior down the road.

If you want to use transforms to animate a view or otherwise animate its frame directly, the cleanest technique to do this is to [embed the view into a container view](http://stackoverflow.com/a/14119154). Then you can override `layoutSubviews` on the container, either opting out of Auto Layout completely or only adjusting its result. For example, if we setup a subview in our container which is laid out within the container at its top and left edges using Auto Layout, we can correct its center after the layout happens to enable the scale transform from above:

    - (void)layoutSubviews
    {
        [super layoutSubviews];
        static CGPoint center = {0,0};
        if (CGPointEqualToPoint(center, CGPointZero)) {
            // grab the view's center point after initial layout
            center = self.animatedView.center;
        } else {
            // apply the previous center to the animated view
            self.animatedView.center = center;
        }
    }

If we expose the `animatedView` property as an IBOutlet, we can even use this container within Interface Builder and position its subview with constraints, while still being able to apply the scale transform with the center staying fixed.


## Debugging

When it comes to debugging Auto Layout, OS X still has a significant advantage over iOS. On OS X you can make use of Instrument's Cocoa Layout template, as well as `NSWindow`'s  [`visualizeConstraints:`](http://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSWindow_Class/Reference/Reference.html#//apple_ref/occ/instm/NSWindow/visualizeConstraints:) method. Furthermore, `NSView` has an [`identifier`](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/NSUserInterfaceItemIdentification_Protocol/Introduction/Introduction.html#//apple_ref/occ/intfp/NSUserInterfaceItemIdentification/identifier) property, which you can set from Interface Builder or in code, in order to get much more readable Auto Layout error messages.


### Unsatisfiable Constraints

If we run into unsatisfiable constraints on iOS, we only see the views' memory addresses in the printout. Especially in more complex layouts, it's sometimes difficult to identify the views which are part of the problem. However, there are several ways we can help ourselves in this situation.

First, whenever you see `NSLayoutResizingMaskConstraint`s in the unsatisfiable constraints error message, you almost certainly forgot to set `translatesAutoResizingMaskIntoConstraints` to `NO` for one of your views. While Interface Builder does this automatically, you have to do this manually for all views created in code.

If it's not obvious which views are causing the trouble, you have to identify the view by its memory address. The most straightforward option is to use the debugger console. You can print out the description of the view itself or its super view, or even the recursive description of the view tree. This mostly gives you lots of cues to identify which view you're dealing with.

    (lldb) po 0x7731880
    $0 = 124983424 <UIView: 0x7731880; frame = (90 -50; 80 100); 
    layer = <CALayer: 0x7731450>>
    
    (lldb) po [0x7731880 superview]
    $2 = 0x07730fe0 <UIView: 0x7730fe0; frame = (32 128; 259 604); 
    layer = <CALayer: 0x7731150>>
    
    (lldb) po [[0x7731880 superview] recursiveDescription]
    $3 = 0x07117ac0 <UIView: 0x7730fe0; frame = (32 128; 259 604); layer = <CALayer: 0x7731150>>
       | <UIView: 0x7731880; frame = (90 -50; 80 100); layer = <CALayer: 0x7731450>>
       | <UIView: 0x7731aa0; frame = (90 101; 80 100); layer = <CALayer: 0x7731c60>>
       
A more visual approach is to modify the view in question from the console so that you can spot it on screen. For example, you can do this by changing its background color:

    (lldb) expr ((UIView *)0x7731880).backgroundColor = [UIColor purpleColor]
    
Make sure to resume the execution of your app afterward or the changes will not show up on screen. Also note the cast of the memory address to `(UIView *)` and the extra set of round brackets so that we can use dot notation. Alternatively, you can of course also use message sending notation:

    (lldb) expr [(UIView *)0x7731880 setBackgroundColor:[UIColor purpleColor]]

Another approach is to profile the application with Instrument's allocations template. Once you've got the memory address from the error message (which you have to get out of the Console app when running Instruments), you can switch Instrument's detail view to the Objects List and search for the address with Cmd-F. This will show you the method which allocated the view object, which is often a pretty good hint of what you're dealing with (at least for views created in code).

You can also make deciphering unsatisfiable constraints errors on iOS easier by improving the error message itself. We can overwrite `NSLayoutConstraint`'s description method in a category to include the views' tags:

    @implementation NSLayoutConstraint (AutoLayoutDebugging)
    #ifdef DEBUG
    - (NSString *)description
    {
        NSString *description = super.description;
        NSString *asciiArtDescription = self.asciiArtDescription;
        return [description stringByAppendingFormat:@" %@ (%@, %@)", 
            asciiArtDescription, [self.firstItem tag], [self.secondItem tag]];
    }
    #endif
    @end
    
If the integer property `tag` is not enough information, we can also get a bit more adventurous and add our own nametag property to the view class, which we then print out in the error message. We can even assign values to this custom property in Interface Builder using the "User Defined Runtime Attributes" section in the identity inspector.

    @interface UIView (AutoLayoutDebugging)
    - (void)setAbc_NameTag:(NSString *)nameTag;
    - (NSString *)abc_nameTag;
    @end
    
    @implementation UIView (AutoLayoutDebugging)
    - (void)setAbc_NameTag:(NSString *)nameTag
    {
        objc_setAssociatedObject(self, "abc_nameTag", nameTag, 
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    - (NSString *)abc_nameTag
    {
        return objc_getAssociatedObject(self, "abc_nameTag");
    }
    @end
    
    @implementation NSLayoutConstraint (AutoLayoutDebugging)
    #ifdef DEBUG
    - (NSString *)description
    {
        NSString *description = super.description;
        NSString *asciiArtDescription = self.asciiArtDescription;
        return [description stringByAppendingFormat:@" %@ (%@, %@)", 
            asciiArtDescription, [self.firstItem abc_nameTag], 
            [self.secondItem abc_nameTag]];
    }
    #endif
    @end

This way the error message becomes much more readable and you don't have to find out which view belongs to which memory address. However, it requires some extra work on your part to consistently assign meaningful names to the views.

Another neat trick (via [Daniel](https://twitter.com/danielboedewadt)) that gives you better error messages without requiring extra work is to integrate call stack symbols into the error message for each layout constraint. This makes it easy to see where the constraints involved in the problem were created. To do this, you have to swizzle the `addConstraint:` and `addConstraints:` methods of `UIView` or `NSView`, as well as the layout constraint's `description` method. In the methods for adding constraints, you should then add an associated object to each constraint, which describes the first frame of the current call stack backtrace (or whatever information you would like to have from it):

    static void AddTracebackToConstraints(NSArray *constraints)
    {
        NSArray *a = [NSThread callStackSymbols];
        NSString *symbol = nil;
        if (2 < [a count]) {
            NSString *line = a[2];
            // Format is
            //               1         2         3         4         5
            //     012345678901234567890123456789012345678901234567890123456789
            //     8   MyCoolApp                           0x0000000100029809 -[MyViewController loadView] + 99
            //
            // Don't add if this wasn't called from "MyCoolApp":
            if (59 <= [line length]) {
                line = [line substringFromIndex:4];
                if ([line hasPrefix:@"My"]) {
                    symbol = [line substringFromIndex:59 - 4];
                }
            }
        }
        for (NSLayoutConstraint *c in constraints) {
            if (symbol != nil) {
                objc_setAssociatedObject(c, &ObjcioLayoutConstraintDebuggingShort, 
                    symbol, OBJC_ASSOCIATION_COPY_NONATOMIC);
            }
            objc_setAssociatedObject(c, &ObjcioLayoutConstraintDebuggingCallStackSymbols, 
                a, OBJC_ASSOCIATION_COPY_NONATOMIC);
        }
    }

    @end

Once you have this information available on each constraint object, you can simply modify `UILayoutConstraint`'s description method to include it in the output.

    - (NSString *)objcioOverride_description
    {
        // call through to the original, really
        NSString *description = [self objcioOverride_description];
        NSString *objcioTag = objc_getAssociatedObject(self, &ObjcioLayoutConstraintDebuggingShort);
        if (objcioTag == nil) {
            return description;
        }
        return [description stringByAppendingFormat:@" %@", objcioTag];
    }

Check [this GitHub repository](https://github.com/objcio/issue-3-auto-layout-debugging) for a full code example of this technique.


### Ambiguous Layout

Another common problem is ambiguous layout. If we forget to add a constraint, we are often left wondering why the layout doesn't look like what we expected. `UIView` and `NSView` provide three ways to detect ambiguous layouts: [`hasAmbiguousLayout`](http://developer.apple.com/library/ios/documentation/UIKit/Reference/UIView_Class/UIView/UIView.html#//apple_ref/occ/instm/UIView/hasAmbiguousLayout), [`exerciseAmbiguityInLayout`](http://developer.apple.com/library/ios/documentation/UIKit/Reference/UIView_Class/UIView/UIView.html#//apple_ref/occ/instm/UIView/exerciseAmbiguityInLayout), and the private method `_autolayoutTrace`.

As the name indicates, `hasAmbiguousLayout` simply returns YES if the view has an ambiguous layout. Instead of traversing through the view hierarchy ourselves and logging this value, we can make use of the private `_autolayoutTrace` method. This returns a string describing the whole view tree -- similar to the printout of [`recursiveDescription`](http://developer.apple.com/library/ios/#technotes/tn2239/_index.html#//apple_ref/doc/uid/DTS40010638-CH1-SUBSECTION34) -- which tells you when a view has an ambiguous layout.

Since this method is private, make sure to not ship any code which contains this call. One possible way to safeguard yourself against this is to create a method in a view category like this:

    @implementation UIView (AutoLayoutDebugging)
    - (void)printAutoLayoutTrace
    {
        #ifdef DEBUG
        NSLog(@"%@", [self performSelector:@selector(_autolayoutTrace)]);
        #endif
    }
    @end

`_autolayoutTrace` creates a printout like this:

    2013-07-23 17:36:08.920 FlexibleLayout[4237:907] 
    *<UIWindow:0x7269010>
    |   *<UILayoutContainerView:0x7381250>
    |   |   *<UITransitionView:0x737c4d0>
    |   |   |   *<UIViewControllerWrapperView:0x7271e20>
    |   |   |   |   *<UIView:0x7267c70>
    |   |   |   |   |   *<UIView:0x7270420> - AMBIGUOUS LAYOUT
    |   |   <UITabBar:0x726d440>
    |   |   |   <_UITabBarBackgroundView:0x7272530>
    |   |   |   <UITabBarButton:0x726e880>
    |   |   |   |   <UITabBarSwappableImageView:0x7270da0>
    |   |   |   |   <UITabBarButtonLabel:0x726dcb0>

As with the unsatisfiable constraints error message, we still have to figure out which view belongs to the memory address of the printout.

Another more visual way to spot ambiguous layouts is to use `exerciseAmbiguityInLayout`. This will randomly change the view's frame between valid values. However, calling this method once will also just change the frame once. So chances are that you will not see this change at all when you start your app. It's a good idea to create a helper method which traverses through the whole view hierarchy and makes all views that have an ambiguous layout "jiggle."

    @implementation UIView (AutoLayoutDebugging)
    - (void)exerciseAmbiguityInLayoutRepeatedly:(BOOL)recursive
    {
        #ifdef DEBUG
        if (self.hasAmbiguousLayout) {
            [NSTimer scheduledTimerWithTimeInterval:.5 
                                             target:self 
                                           selector:@selector(exerciseAmbiguityInLayout) 
                                           userInfo:nil 
                                            repeats:YES];
        }
        if (recursive) {
            for (UIView *subview in self.subviews) {
                [subview exerciseAmbiguityInLayoutRepeatedly:YES];
            }
        }
        #endif
    }
    @end


### NSUserDefault Options

There are a couple of helpful `NSUserDefault` options that help with debugging and testing Auto Layout. You can either set these [in code](http://stackoverflow.com/a/13044693/862060), or you can specify them as [launch arguments in the scheme editor](http://stackoverflow.com/a/13138933/862060).

As the names indicate, `UIViewShowAlignmentRects` and `NSViewShowAlignmentRects` make the alignment rects of all views visible. `NSDoubleLocalizedStrings` simply takes every localized string and doubles it in length. This is a great way to test your layout for more verbose languages. Lastly, setting `AppleTextDirection` and `NSForceRightToLeftWritingDirection` to `YES` simulates a right-to-left language.


## Constraint Code

The first thing to remember when setting up views and their constraints in code is to always set [`translatesAutoResizingMaskIntoConstraints`](http://developer.apple.com/library/ios/documentation/UIKit/Reference/UIView_Class/UIView/UIView.html#//apple_ref/occ/instm/UIView/translatesAutoresizingMaskIntoConstraints) to NO. Forgetting this will almost inevitably result in unsatisfiable constraint errors. It's something which is easy to miss even after working with Auto Layout for a while, so watch out for this pitfall.

When you use the [visual format language](http://developer.apple.com/library/ios/#documentation/UserExperience/Conceptual/AutolayoutPG/Articles/formatLanguage.html) to set up constraints, the `constraintsWithVisualFormat:options:metrics:views:` method has a very useful `options` argument. If you're not using it already, check out the [documentation](http://developer.apple.com/library/ios/documentation/AppKit/Reference/NSLayoutConstraint_Class/NSLayoutConstraint/NSLayoutConstraint.html#//apple_ref/occ/clm/NSLayoutConstraint/constraintsWithVisualFormat:options:metrics:views:). It allows you to align the views in a dimension other than the one affected by the format string. For example, if the format specifies the horizontal layout, you can use `NSLayoutFormatAlignAllTop` to align all views included in the format string along their top edges.

There is also a [neat little trick](https://github.com/evgenyneu/center-vfl) to achieve centering of a view within its superview using the visual format language, which takes advantage of inequality constraints and the options argument. The following code aligns a view horizontally in its super view:

    UIView *superview = theSuperView;
    NSDictionary *views = NSDictionaryOfVariableBindings(superview, subview);
    NSArray *c = [NSLayoutConstraint 
                    constraintsWithVisualFormat:@"V:[superview]-(<=1)-[subview]"]
                                        options:NSLayoutFormatAlignAllCenterX
                                        metrics:nil
                                          views:views];
    [superview addConstraints:c];

This uses the option `NSLayoutFormatAlignAllCenterX` to create the actual centering constraint between the super view and the subview. The format string itself is merely a dummy that results in a constraint specifying that there should be less than one point of space between the super view's bottom and the subview's top edge, which is always the case as long as the subview is visible. You can reverse the dimensions in the example to achieve centering in the vertical direction.

Another convenient helper when using the visual format language is the `NSDictionaryFromVariableBindings` macro, which we already used in the example above. You pass it a variable number of variables and get back a dictionary with the variable names as keys.

For layout tasks that you have to do over and over, it's very convenient to create your own helper methods. For example, if you often have to space out a couple of sibling views vertically with a fixed distance between them while aligning all of them horizontally at the leading edge, having a method like this makes your code less verbose:

    @implementation UIView (AutoLayoutHelpers)
    + leftAlignAndVerticallySpaceOutViews:(NSArray *)views 
                                 distance:(CGFloat)distance 
    {
        for (NSUInteger i = 1; i < views.count; i++) {
            UIView *firstView = views[i - 1];
            UIView *secondView = views[i];
            firstView.translatesAutoResizingMaskIntoConstraints = NO;
            secondView.translatesAutoResizingMaskIntoConstraints = NO;

            NSLayoutConstraint *c1 = constraintWithItem:firstView
                                              attribute:NSLayoutAttributeBottom
                                              relatedBy:NSLayoutRelationEqual
                                                 toItem:secondView
                                              attribute:NSLayoutAttributeTop
                                             multiplier:1
                                               constant:distance];
                                               
            NSLayoutConstraint *c2 = constraintWithItem:firstView
                                              attribute:NSLayoutAttributeLeading
                                              relatedBy:NSLayoutRelationEqual
                                                 toItem:secondView
                                              attribute:NSLayoutAttributeLeading
                                             multiplier:1
                                               constant:0];
                                                   
            [firstView.superview addConstraints:@[c1, c2]];
        }
    }
    @end

In the meantime there are also many different Auto Layout helper libraries out there taking different approaches to simplifying constraint code.


## Performance

Auto Layout is an additional step in the layout process. It takes a set of constraints and translates them into frames. Therefore it naturally comes with a performance hit. In the vast majority of cases, the time it takes to resolve the constraint system is negligible. However, if you're dealing with very performance critical view code, it's good to know about it.

For example, if you have a collection view which has to bring several new cells on screen when a new row appears, and each cell consists of several subviews laid out by Auto Layout, you may notice the effect. Luckily, we don't need to rely on our gut feeling when scrolling up and down. Instead we can fire up Instruments and actually measure how much time Auto Layout spends. Watch out for methods of the `NSISEngine` class.

Another scenario where you might run into performance issues with Auto Layout is when you are showing lots of views at once. The [constraint solving algorithm](http://www.cs.washington.edu/research/constraints/cassowary/), which translates the constraints into view frames, is of [super-linear complexity](http://en.wikipedia.org/wiki/P_%28complexity%29). This means that from a certain number of views on, performance will become pretty terrible. The exact number depends on your specific use case and view configuration. But to give you a rough idea, on current iOS devices it's in the order of a magnitude of 100. For more details, you can also read these two [blog](http://floriankugler.com/blog/2013/4/21/auto-layout-performance-on-ios) [posts](http://pilky.me/view/36).

Keep in mind that these are edge cases. Don't optimize prematurely and avoid Auto Layout for its potential performance impact. It will be fine for most use cases. But if you suspect it might cost you the decisive milliseconds to get the user interface completely smooth, profile your code and only then should you decide if it makes sense to go back to setting frames manually. Furthermore, hardware will become more and more capable, and Apple will continue tweaking the performance of Auto Layout. So the edge cases where it presents a real-world performance problem will decrease over time.


## Conclusion

Auto Layout is a powerful technique to create flexible user interfaces, and it's not going away anytime soon. Getting started with Auto Layout can be a bit rough, but there is light at the end of the tunnel. Once you get the hang of it and have all the little tricks to diagnose and fix problems up your sleeve, it actually becomes very logical to work with. 


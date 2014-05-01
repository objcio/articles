---
layout: post
title:  "UICollectionView animations"
category: "12"
date: "2014-05-01 10:00:00"
tags: article
author: "<a href=\"https://twitter.com/ekurutepe\">Engin Kurutepe</a>"
---

#Animating Collection Views

`UICollectionView` and the set of associated classes are extremely flexible and powerful. But with this flexibility comes a certain dose of complexity: a collection view is a good deal deeper and more capable than the good old `UITableView`.

So much deeper in fact, that [Ole Begeman](http://oleb.net) and [Ash Furrow](https://twitter.com/ashfurrow) have written about [Custom Collection View Layouts](http://www.objc.io/issue-3/collection-view-layouts.html) and [Collection Views with UIKit Dynamics](http://www.objc.io/issue-5/collection-views-and-uidynamics.html) in objc.io previously, and I still have something to write about that they have not covered. In this post, I will assume that you're familiar with the basics of collection view layouts and have read at least Apple's excellent [programming guide](https://developer.apple.com/library/ios/documentation/WindowsViews/Conceptual/CollectionViewPGforIOS/Introduction/Introduction.html#//apple_ref/doc/uid/TP40012334) and Ole's [post](http://www.objc.io/issue-3/collection-view-layouts.html).

In the first section of this article, I will try to show how exactly different classes and methods work together to animate of a collection view layout using a few common examples. In the second section, I will show how to build a custom view controller transition for cases where the useful but limited `useLayoutToLayoutNavigationTransitions` does not cut it.

The two example projects for this article are available on Github:


//TODO: upload the projects to github and insert links below
- [Layout Animations]()
- [Custom Collection View Transitions]()


##Collection View Layout Animations

Even though the standard `UICollectionViewFlowLayout` is very customizable, Apple opted for the safe approach and implemented a simple fade animation as default for all layout animations. If you would like to have custom animations the best way is to subclass the `UICollectionViewFlowLayout` and implement your animations at the appropriate locations. Let's go through a few examples to understand how various methods in your `UICollectionViewFlowLayout` subclasses should work with each other to deliver custom animations.

###Inserting and Removing Items

In the general case, layout attributes are linearly interpolated from the initial state to the final state to compute the collection view animations. However, for the newly inserted or removed items there are no initial and final attributes respectively to interpolate from. To compute the animations for such cells the collection view will ask your layout object to provide the initial and final attributes through the `initialLayoutAttributesForAppearingItemAtIndexPath:` and `finalLayoutAttributesForAppearingItemAtIndexPath:` methods. The default Apple implementation returns the layout attributes corresponding to the normal layout at the specific index path but with an `alpha` value of 0.0, resulting in a fade-in or fade-out animation. If you would like to have something fancier like your new cells to shoot up from the bottom of the screen and rotate while flying into place you could implement something like this in your layout subclass:

````objc
- (UICollectionViewLayoutAttributes*)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)itemIndexPath
{
    UICollectionViewLayoutAttributes *attr = [self layoutAttributesForItemAtIndexPath:itemIndexPath];

    attr.transform = CGAffineTransformRotate(CGAffineTransformMakeScale(0.2, 0.2), M_PI);
    attr.center = CGPointMake(CGRectGetMidX(self.collectionView.bounds), CGRectGetMaxY(self.collectionView.bounds));

    return attr;
}
````

Which results in this:

//TODO: insert GIF with insertion deletion animations

###Responding to Device Rotations

A device orientation change usually results in a bounds change for a collection view. The layout object is asked if the layout should be invalidated and recomputed with the method `shouldInvalidateLayoutForBoundsChange:`. The default implementation in `UICollectionViewFlowLayout` does the correct thing but if you are subclassing `UICollectionViewLayout` instead you should return `YES` on a bounds change:

````objc
- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    CGRect oldBounds = self.collectionView.bounds;
    if (!CGSizeEqualToSize(oldBounds.size, newBounds.size)) {
        return YES;
    }
    return NO;
}
````

In order to animate the bounds change the collection view acts as if the currently displayed items are removed and inserted again resulting in a series of `finalLayoutAttributesForAppearingItemAtIndexPath:` and `initialLayoutAttributesForAppearingItemAtIndexPath:` calls for each index path.

If you implemented fancy animations for the insertion and deletion of items in the collection view, by now you should be seeing why Apple went with simple fade animations:

//TODO: insert GIF with wrong animations

Oops…

To prevent such unwanted animations, for each item in the collection view the sequence of initial position -> removal animation -> insertion animation -> final position must be matched to result in one smooth animation from the initial attributes to the final attributes. In other words, the `finalLayoutAttributesForAppearingItemAtIndexPath:` and `initialLayoutAttributesForAppearingItemAtIndexPath:` should be able to return different attributes depending on if the item in question is really disappearing or appearing or the collection view is going through a bounds change animation.

Luckily, the collection view tells the layout object which kind of animation is about to be performed by invoking the `prepareForAnimatedBoundsChange:` or `prepareForCollectionViewUpdates:` for bounds changes and item updates respectively. We can use `prepareForCollectionViewUpdates:` to keep track of updated objects:

````objc
- (void)prepareForCollectionViewUpdates:(NSArray *)updateItems
{
    [super prepareForCollectionViewUpdates:updateItems];
    NSMutableArray *indexPaths = [NSMutableArray array];
    for (UICollectionViewUpdateItem *updateItem in updateItems) {
        switch (updateItem.updateAction) {
            case UICollectionUpdateActionInsert:
                [indexPaths addObject:updateItem.indexPathAfterUpdate];
                break;
            case UICollectionUpdateActionDelete:
                [indexPaths addObject:updateItem.indexPathBeforeUpdate];
                break;
            case UICollectionUpdateActionMove:
                [indexPaths addObject:updateItem.indexPathBeforeUpdate];
                [indexPaths addObject:updateItem.indexPathAfterUpdate];
                break;
            default:
                NSLog(@"unhandled case: %@", updateItem);
                break;
        }
    }  
    self.indexPathsToAnimate = indexPaths;
}
````
And modify our item insertion animation to only shoot the item if it is being inserted into the collection view:

````objc
- (UICollectionViewLayoutAttributes*)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)itemIndexPath
{
    UICollectionViewLayoutAttributes *attr = [self layoutAttributesForItemAtIndexPath:itemIndexPath];

    if ([_indexPathsToAnimate containsObject:itemIndexPath]) {
        attr.transform = CGAffineTransformRotate(CGAffineTransformMakeScale(0.2, 0.2), M_PI);
        attr.center = CGPointMake(CGRectGetMidX(self.collectionView.bounds), CGRectGetMaxY(self.collectionView.bounds));
        [_indexPathsToAnimate removeObject:itemIndexPath];
    }

    return attr;
}
````

If the item is not being inserted the normal attributes as reported by `layoutAttributesForItemAtIndexPath` will be returned, canceling any special appearance animations. Combined with the corresponding logic inside `finalLayoutAttributesForAppearingItemAtIndexPath:`, this will result in the items smoothly animating from their initial position to their final position in the case of a bounds change, creating a simple but cool animation:

//TODO: insert GIF with correct animations

###Interactive Layout Animations

Collection views make it quite easy to allow the user interact with the layout using gesture recognizers. As [suggested](https://developer.apple.com/library/ios/documentation/WindowsViews/Conceptual/CollectionViewPGforIOS/IncorporatingGestureSupport/IncorporatingGestureSupport.html#//apple_ref/doc/uid/TP40012334-CH4-SW1) by Apple, the general approach to add interactivity to a collection view layout follows these steps:

1. Create the gesture recognizer
2. Add the gesture recognizer to the collection view
3. Handle the recognized gestures to drive the layout animations  

Let's see how we can build something where the user can pinch an item to zoom and the item returns to original size as soon as the user releases their pinch.

Our handler method could look something like this:

````objc
- (void)handlePinch:(UIPinchGestureRecognizer *)sender {
    if ([sender numberOfTouches] != 2)
        return;


    if (sender.state == UIGestureRecognizerStateBegan ||
        sender.state == UIGestureRecognizerStateChanged) {
        // Get the pinch points.
        CGPoint p1 = [sender locationOfTouch:0 inView:[self collectionView]];
        CGPoint p2 = [sender locationOfTouch:1 inView:[self collectionView]];

        // Compute the new spread distance.
        CGFloat xd = p1.x - p2.x;
        CGFloat yd = p1.y - p2.y;
        CGFloat distance = sqrt(xd*xd + yd*yd);

        // Update the custom layout parameter and invalidate.
        FJAnimatedFlowLayout* layout = (FJAnimatedFlowLayout*)[[self collectionView] collectionViewLayout];

        NSIndexPath *pinchedItem = [self.collectionView indexPathForItemAtPoint:CGPointMake(0.5*(p1.x+p2.x), 0.5*(p1.y+p2.y))];
        [layout resizeItemAtIndexPath:pinchedItem withPinchDistance:distance];
        [layout invalidateLayout];

    }
    else if (sender.state == UIGestureRecognizerStateCancelled ||
             sender.state == UIGestureRecognizerStateEnded){
        FJAnimatedFlowLayout* layout = (FJAnimatedFlowLayout*)[[self collectionView] collectionViewLayout];
        [self.collectionView
         performBatchUpdates:^{
            [layout resetPinchedItem];
         }
         completion:nil];
    }
}
````

This pinch handler computes the pinch distance and figures out the pinched item and tells the layout to update itself while the user is pinching. As soon as the pinch gesture is over, the layout is reset in a batch update to animate the return to the original size.

Our layout on the other hand, keeps track of the pinched item and the desired size and provides the correct attributes for them when needed:

````objc
- (NSArray*)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSArray *attrs = [super layoutAttributesForElementsInRect:rect];

    if (_pinchedItem) {
        UICollectionViewLayoutAttributes *attr = [[attrs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"indexPath == %@", _pinchedItem]] firstObject];

        attr.size = _pinchedItemSize;
        attr.zIndex = 100;
    }
    return attrs;
}
````

###Summary

Using a few examples we looked at how to build custom animations in collection view layout. Even though the `UICollectionViewFlowLayout` does not directly allow customization of its animations, it is clear that Apple architected the class to be subclassed to implement various custom behavior. Essentially boundless custom layout and animations can be achieved by correctly reacting to signaling methods such as

- `prepareLayout`
- `prepareForCollectionViewUpdates:`
- `finalizeCollectionViewUpdates`
- `prepareForAnimatedBoundsChange:`
- `finalizeAnimatedBoundsChange`
- `shouldInvalidateLayoutForBoundsChange:`

in your `UICollectionViewLayout` subclass and returning the appropriate attributes from methods which return `UICollectionViewLayoutAttributes`.

## View Controller Transitions with Collection Views

One of the big improvements in iOS 7 was the custom view controller transitions as [Chris](https://twitter.com/chriseidhof) [wrote about](http://www.objc.io/issue-5/view-controller-transitions.html) back then in objc.io [issue #5](http://www.objc.io/issue-5/index.html). In parallel to the custom transitions, Apple also added the `useLayoutToLayoutNavigationTransitions` flag to `UICollectionViewController` to enable navigation transitions which re-use a single collection view. Apple's own Photos and Calendar apps on iOS show a great example of what can be achieved using such transitions.

### Transitions between UICollectionViewController Instances

Let's look at how we can achieve a similar effect using the same sample project from the previous section:

//TODO: insert GIF layout2layout transitions

In order for the layout to layout transitions to work the root view controller in the navigation controller must be a collection view controller where `useLayoutToLayoutNavigationTransitions` is set to `NO`. When another `UICollectionViewController` instance with `useLayoutToLayoutNavigationTransitions` set to `YES` is pushed on top of this root view controller, navigation controller replaces the standard push animation with a layout transition animation. One important detail to note here is that the same collection view instance from the root view controller is recycled for the collection view controller instances pushed on the navigation stack, i.e. these collection view controllers don't have their own collection views, if you try to set any collection view properties in methods like `viewDidLoad` they will not have any effect.

Probably the most common gotcha is to expect that the recycled collection view updates its data source and delegate to reflect the top collection view controller. It does not: the root collection view controller stays the data source and delegate unless we do something about it.

One approach to change this implement the navigation controller delegate method and correctly set the data source and delegate of the collection view as needed by the current view controller at the top of the navigation stack. In our simple example this can be achieved by:

````objc
- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if ([viewController isKindOfClass:[FJDetailViewController class]]) {
        FJDetailViewController *dvc = (FJDetailViewController*)viewController;
        dvc.collectionView.dataSource = dvc;
        dvc.collectionView.delegate = dvc;
        [dvc.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:_selectedItem inSection:0] atScrollPosition:UICollectionViewScrollPositionCenteredVertically animated:NO];
    }
    else if (viewController == self){
        self.collectionView.dataSource = self;
        self.collectionView.delegate = self;
    }
}
````

When the detail collection view is push onto the stack, we set the collection view's data source to the detail view controller, which makes sure that only the selected color of cells is shown in the detail collection view. If we were not to do this, the layout would correctly transition but the collection would still be showing all cells.

### Collection View Layout Animations for General Transitions

The layout to layout navigation animations using the `useLayoutToLayoutNavigationTransitions` flag are quite useful but only limited to transitions where both view controllers are `UICollectionViewController` instances. We need a custom view controller transition in order to achieve a similar transition between a collection view in the initial view controller and a collection view in the final view controller for the general case.

One approach to design the animation controller for our custom transition follow along the following steps:

- make snapshots of all visible items in the initial collection view
- add the snapshots to the transitioning context container view
- compute where the final positions using the layout of the target collection view
- animate to the correct positions
- remove the snapshots while making the target collection view visible

The downside of such an animator design is two-fold: it can only animate the items visible in the initial collection view since the [snapshot APIs](https://developer.apple.com/library/ios/documentation/uikit/reference/uiview_class/UIView/UIView.html#//apple_ref/doc/uid/TP40006816-CH3-SW198) only work for views already visible on the screen and depending on the number of visible items there could be a lot of views to correctly keep track of and to animate. But hey, that's why the computers are for right? On the other hand the big advantage of this design would be that it would work for all kinds of `UICollectionViewLayout` combinations. The implementation of such a system is left as an exercise for the reader.

Another approach, which we will discuss deeper in this post, relies on a few quirks of the `UICollectionViewFlowLayout` and is therefore only applicable to transitions between collection views with flow layouts it its current form.

The basic idea is that both the source and the destination collection views have valid flow layouts, if we could only use the layout attributes of the source layout as the initial layout attributes of the destination collection view to drive the transition animation, then the collection view machinery would take care of keeping track of all items and animate them for us. Even if they're not initially visible on the screen. Easier said than done…

````objc
    CGRect initialRect = [inView.window convertRect:_fromCollectionView.frame fromView:_fromCollectionView.superview];
    CGRect finalRect   = [transitionContext finalFrameForViewController:toVC];

    UICollectionViewFlowLayout *toLayout = (UICollectionViewFlowLayout*) _toCollectionView.collectionViewLayout;

    UICollectionViewFlowLayout *currentLayout = (UICollectionViewFlowLayout*) _fromCollectionView.collectionViewLayout;

    //make a copy of the original layout
    UICollectionViewFlowLayout *currentLayoutCopy = [[UICollectionViewFlowLayout alloc] init];

    currentLayoutCopy.itemSize = currentLayout.itemSize;
    currentLayoutCopy.sectionInset = currentLayout.sectionInset;
    currentLayoutCopy.minimumLineSpacing = currentLayout.minimumLineSpacing;
    currentLayoutCopy.minimumInteritemSpacing = currentLayout.minimumInteritemSpacing;
    currentLayoutCopy.scrollDirection = currentLayout.scrollDirection;

    //assign the copy to the source collection view
    [self.fromCollectionView setCollectionViewLayout:currentLayoutCopy animated:NO];

    UIEdgeInsets contentInset = _toCollectionView.contentInset;

    CGFloat oldBottomInset = contentInset.bottom;

    //force a very big bottom inset in the target collection view
    contentInset.bottom = CGRectGetHeight(finalRect)-(toLayout.itemSize.height+toLayout.sectionInset.bottom+toLayout.sectionInset.top);
    self.toCollectionView.contentInset = contentInset;

    //set the source layout for the destination collection view
    [self.toCollectionView setCollectionViewLayout:currentLayout animated:NO];

    toView.frame = initialRect;

    [inView insertSubview:toView aboveSubview:fromView];

    [UIView
     animateWithDuration:[self transitionDuration:transitionContext]
     delay:0
     options:UIViewAnimationOptionBeginFromCurrentState
     animations:^{
       //animate to the final frame
         toView.frame = finalRect;
         //set the final layout inside performUpdates
         [_toCollectionView
          performBatchUpdates:^{
              [_toCollectionView setCollectionViewLayout:toLayout animated:NO];
          }
          completion:^(BOOL finished) {
              _toCollectionView.contentInset = UIEdgeInsetsMake(contentInset.top,
                                                                contentInset.left,
                                                                oldBottomInset,
                                                                contentInset.right);
          }];

     } completion:^(BOOL finished) {
         [transitionContext completeTransition:YES];
     }];
````

These lines of code from the animation controller make sure that the destination collection view starts with the exact same frame and layout as the original. First assign the layout of the source collection view to the destination collection view, making sure that it does not get invalidated. At the same the layout is 'copied' into a new layout object which gets assigned to the original collection view. We also so force a large bottom content inset on the destination collection view to make sure that the layout stays single line before the animations start. Then the convoluted animation block does it magic by first setting the frame of the destination collection view to its final position and performing an non-animated layout change to the final layout inside the updates block of `performBatchUpdates:completion:` which is followed by the resetting of the content insets to the original values in the completion block.

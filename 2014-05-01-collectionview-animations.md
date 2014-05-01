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

### Transitions between UICollectionViewController Instances

`useLayoutToLayoutNavigationTransitions`

### Collection View Layout Animations for General Transitions

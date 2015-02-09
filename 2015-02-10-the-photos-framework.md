---
title:  "The Photos Framework"
category: "21"
date: "2015-02-10 08:00:00"
author: "<a href=\"https://twitter.com/saniul\">Saniul Ahmed</a>"
tags: article
---

## Introduction

Every day, [more photos are taken with the iPhone](https://www.flickr.com/cameras#brands) than any other camera. Displays on iOS devices get better every year, but even back in the pre-Retina era [when the iPad was introduced](http://youtu.be/_KN-5zmvjAo?t=17m7s), one of its killer uses was just displaying user photos and exploring the photo library. Since the camera is one of the iPhone's most important and popular features, there is a big demand for apps and utilities that make use of the wealth of users' photo libraries.

Until the summer of 2014, developers used the [AssetsLibrary Framework](https://developer.apple.com/library/ios/documentation/AssetsLibrary/Reference/ALAssetsLibrary_Class/#//apple_ref/doc/uid/TP40009722-CH1-SW57) to access the ever-growing photo libraries of users. Over the years Camera.app and Photos.app have changed significantly, adding new features and even a new way of organizing photos by moments. Meanwhile, the AssetsLibrary framework lagged behind.

With iOS 8, Apple has given us PhotoKit, a modern framework that's more performant than AssetsLibrary and provides features that allow applications to work seamlessly with a device's photo library.

## Outline

We'll start with a bird's-eye view of the [framework's object model](#PhotoKit-Object-Model): the entities and the relationships between them, fetching instances of those entities, and working with the fetch results.

Additionally, we'll cover [the asset metadata](#Photo-metadata) that wasn't available to developers when using AssetsLibrary.

Then we'll discuss [loading the assets' image data](#Photo-Loading): the process itself, multitudes of available options, some gotchas, and edge cases.

Finally, we'll talk about [observing changes](#The-Times-They-Are-A-Changin) made to the photo library by external actors and learn how to make and commit [our own changes](#Wind-of-Change).


<a name="PhotoKit-Object-Model"></a>
## PhotoKit Object Model

PhotoKit defines an entity graph that models the objects presented to the user in the stock Photos.app. These photo entities are lightweight and immutable. All the PhotoKit objects inherit from the abstract `PHObject` base class, whose public interface only provides a `localIdentifier` property.

`PHAsset` represents a single asset in the user's photo library, providing the [metadata](#Photo-metadata) for that asset.

Groups of assets are called asset collections and are represented by the `PHAssetCollection` class. A single asset collection can be an album or a moment in the photo library, as well as one of the special "smart albums." These include collections of all videos, recently added items, user favorites, all burst photos, [and more](https://developer.apple.com/library/prerelease/ios/documentation/Photos/Reference/PHAssetCollection_Class/index.html#//apple_ref/c/tdef/PHAssetCollectionSubtype). `PHAssetCollection` is a subclass of `PHCollection`.

`PHCollectionList` represents a group of `PHCollection`s. Since it is a `PHCollection` itself, a collection list can contain other collection lists, allowing for complex hierarchies of collections. In practice, this can be seen in the Moments tab in the Photos.app: Asset --- Moment --- Moment Cluster --- Moment Year.

### Fetching Photo Entities

#### Fetching vs. Enumerating

Those familiar with the AssetsLibrary framework might remember that to be able to find assets with specific properties, one has to *enumerate* through the user's library and collect the matching assets. Granted, the API provided some ways of [narrowing down the search domain](https://developer.apple.com/library/ios/documentation/AssetsLibrary/Reference/ALAssetsGroup_Class/index.html#//apple_ref/occ/instm/ALAssetsGroup/setAssetsFilter:), but it still remains quite unwieldy.

In contrast, PhotoKit entity instances are *fetched*. Those familiar with Core Data will recognize the approaches and concepts used and described here.

#### Fetch Request

Fetches are made using the class methods of the entities described above. Which class/method to use depends on the problem domain and how you're representing and traversing the photo library. All of the fetch methods are named similarly: `class func fetchXXX(..., options: PHFetchOptions) -> PHFetchResult`. The `options` parameter gives us a way of filtering and ordering the returned results, similar to `NSFetchRequest`'s `predicate` and `sortDescriptors` parameters.

#### Fetch Result

You may have noticed that these fetch methods aren't asynchronous. Instead, they return a `PHFetchResult` object, which allows access to the underlying collection of results with an interface similar to `NSArray`. It will dynamically load its contents as needed and cache contents around the most recently requested value. This behavior is similar to the result array of an `NSFetchRequest` with a set `batchSize` property. There is no way to parametrize this behavior for `PHFetchResult`, but the [documentation promises](https://developer.apple.com/library/prerelease/ios/documentation/Photos/Reference/PHFetchResult_Class/index.html) “optimal performance even when handling a large number of results.”

The `PHFetchResult`s returned by the fetch methods will not be updated automatically if the photo library contents match the request change. Observing changes and processing updates for a given `PHFetchResult` are [described in a later section](#The-Times-They-Are-A-Changin).


## Transient Collections

You might find that you have designed a component that operates on an asset collection, and yet you would like to be able to use it with an arbitrary set of assets. PhotoKit provides an easy way to do that using transient asset collections.

Transient asset collections are created explicitly by you from an array of `PHAsset` objects or from a `PHFetchResult` containing assets. This is done using the `transientAssetCollectionWithAssets(...)` and `transientAssetCollectionWithFetchResult(...)` factory methods on `PHAssetCollection`. The objects vended by these methods can be used just like any other `PHAssetCollection`. Despite that, these collections aren't saved to the user's photos library and thus aren't displayed in the Photos.app.

Similarly to asset collections, you can create transient collection lists by using the `transientCollectionListWithXXX(...)` factory methods on `PHCollectionList`.

This can turn out to be very useful when you need to combine results from two fetch requests.


<a name="Photo-metadata"></a>
## Photo Metadata

As mentioned in the beginning of this article, PhotoKit provides some additional metadata about user assets that wasn't available (or at least not as easily available) in the past when using ALAssetsLibrary.

### HDR and Panorama Photos

You can use a photo asset's `mediaSubtypes` property to find out if the underlying image was captured with HDR enabled and whether or not it was shot in the Camera.app's Panorama mode.

### Favorite and Hidden Assets

To find out if an asset was marked as favorite or was hidden by the user, just inspect the `favorite` and `hidden` properties of the `PHAsset` instance.

### Burst Mode Photos

`PHAsset`'s `representsBurst` property is true for assets that are representative of a burst photo sequence (multiple photos taken while the user held down the shutter). It will also have a `burstIdentifier` value which can then be used to fetch the rest of the assets in that burst sequence via `fetchAssetsWithBurstIdentifier(...)`.

The user can flag assets within a burst sequence; additionally, the system uses various heuristics to mark potential user picks automatically. This metadata is accessible via `PHAsset`'s `burstSelectionTypes` property. This property is a bitmask with three defined constants: `.UserPick` for assets marked manually by the user, `.AutoPick` for potential user picks, and `.None` for unmarked assets.

![.AutoPick Example](http://f.cl.ly/items/3A0f0e3D0m0K20330R04/IMG_1637.PNG) The screenshot shows how Photos.app automatically marks potential user picks in a burst sequence.


<a name="Photo-Loading"></a>
## Photo Loading

Over the years of working with user photo libraries, developers have created hundreds (if not thousands) of tiny pipelines for efficient photo loading and display. These pipelines dealt with request dispatching and cancelation, image resizing and cropping, caching, and more. PhotoKit provides a class that does all this with a convenient and modern API: `PHImageManager`.

### Requesting Images

Image requests are dispatched using the `requestImageForAsset(...)` method. The method takes in a `PHAsset`, desired sizing of the image and other options (via the `PHImageRequestOptions` parameter object), and a results handler. The returned value can be used to cancel the request if the requested data is no longer necessary.

#### Image Sizing and Cropping

Curiously, the parameters regarding the sizing and cropping of the result image are spread across two places. The `targetSize` and `contentMode` parameters are passed directly into the `requestImageForAsset(...)` method. The content mode describes whether the photo should be aspect-fitted or aspect-filled into the target size, similar to UIView's `contentMode`. Note: If the photo should not be resized or cropped, pass `PHImageManagerMaximumSize` and `PHImageContentMode.Default`.

Additionally, `PHImageRequestOptions` provides means of specifying *how* the image manager should resize. The `resizeMode` property can be set to .Exact (when the result image must match the target size), .Fast (more efficient than .Exact, but the resulting image might differ from the target size), or .None. Furthermore, the `normalizedCroppingMode` property lets us specify how the image manager should crop the image. Note: If `normalizedcroppingMode` is provided, set `resizeMode` to `.Exact`.

#### Request Delivery and Progress

By default, the image manager will deliver a lower-quality version of your image before delivering the high-quality version if it decides that's the optimal strategy to use. You can control this behavior through the `deliveryMode` property; the default behavior described above is .Opportunistic. Set it to .HighQualityFormat if you're only interested in the highest quality of the image available and if longer load times are acceptable. Use .FastFormat to load the image faster while sacrificing the quality.

You can make the `requestImage...` method synchronous using the `synchronous` property on `PHImageRequestOptions`. Note: When `synchronous` is set to true, the `deliveryMode` property is ignored and considered to be set to `.HighQualityFormat`.

When setting these parameters, it is important to always consider that some of your users might have iCloud Photo Library enabled. The PhotoKit API doesn't necessarily distinguish photos available on-device from those available in the cloud — they are all loaded using the same `requestImage` method. This means that every single one of your image requests may potentially be a slow network request over the cellular network. Keep this in mind when considering using .HighQualityFormat and/or making your requests synchronous. Note: If you want to make sure that the request doesn't hit the network, set `networkAccessAllowed` to `false`.

Another iCloud-related property is `progressHandler`. You can set it to a [`PHAssetImageProgressHandler`](https://developer.apple.com/library/ios/documentation/Photos/Reference/PHImageRequestOptions_Class/index.html#//apple_ref/doc/c_ref/PHAssetImageProgressHandler) block that will be called by the image manager when downloading the photo from iCloud.

#### Asset Versions

PhotoKit allows apps to make non-destructive adjustments to photos. For edited photos, the system keeps a separate copy of the original image and the app-specific adjustment data. When fetching assets using the image manager, you can specify which version of the image asset should be delivered via the result handler. This is done by setting the `version` property: `.Current` will deliver the image with all adjustments applied to it; `.Unadjusted` delivers the image before any adjustments are applied to it; and `.Original` delivers the image in its original, highest-quality format (e.g. the RAW data while `.Unadjusted` would deliver a JPEG).

You can read more about this aspect of the framework in Sam Davies' [article on Photo Extensions](/issue-21/photo-extensions.html).

#### Result Handler

The result handler is a block that takes in a `UIImage` and an `info` dictionary. It can be called by the image manager multiple times throughout the lifetime of the request, depending on the parameters and the request options.

The `info` dictionary provides information about the current status of the request, such as:

* Whether the image has to be requested from iCloud (in which case you're going to have to re-request the image if you initially set `networkAccessAllowed` to `false`) — `PHImageResultIsInCloudKey`.
* Whether the currently delivered `UIImage` is the degraded form of the final result. This lets you display a preview of the image to the user, while the higher-quality image is being downloaded — `PHImageResultIsDegradedKey`.
* The request ID (convenience for canceling the request) and whether the request has already been canceled — `PHImageResultRequestIDKey` and `PHImageCancelledKey`.
* An error, if an image wasn't provided to the result handler — `PHImageErrorKey`.

These values let you update your UI to inform your user and, together with the `progressHandler` discussed above, hint at the loading state of their images.

### Caching

At times it's useful to load some images into memory prior to the moment when they are going to be shown on the screen, for example when displaying a screen with a large numbers of asset thumbnails in a scrolling collection. PhotoKit provides a `PHImageManager` subclass that deals with that specific use case – `PHImageCachingManager`.

`PHImageCachingManager` provides a single key method – `startCachingImagesForAssets(...)`. You pass in an array of `PHAsset`s, the request parameters and options that should match those you're going to use later when requesting individual images. Additionally, there are methods that you can use to inform the caching manager to stop caching images for a list of specific assets and to stop caching all images.

The `allowsCachingHighQualityImages` property lets you specify whether the image manager should prepare images at high quality. When caching a short and unchanging list of assets, the default `true` value should work just fine. When caching while quickly scrolling in a collection view, it is better to set it to `false`.

Note: In my experience, using the caching manager can be detrimental to scrolling performance when the user is scrolling extremely fast through a large asset collection. It is extremely important to tailor the caching behavior for the specific use case. The size of the caching window, when and how often to move the caching window, the value of the `allowsCachingHighQualityImages` property — these parameters should be carefully tuned and the behavior tested with a real photo library and on target hardware. Furthermore, consider setting these parameters dynamically based on the user's actions.

### Requesting Image Data

Finally, in addition to requesting plain old `UIImages`, `PHImageManager` provides another method which returns the asset data as an `NSData` object, its universal type identifier, and the display orientation of the image. This method returns the largest available representation of the asset.


<a name="The-Times-They-Are-A-Changin"></a>
## The Times They Are A-Changin'

We have discussed requesting metadata of assets in the user's photo library, but we haven't covered how to keep our fetched data up to date. The photo library is essentially a big bag of mutable state, and yet the photo entities covered in the first section are immutable. PhotoKit lets you receive notifications about changes to the photo library together with all the information you need to correctly update your cached state.

### Change Observing
First, you need to register a change observer (conforming to the `PHPhotoLibraryChangeObserver` protocol) with the shared `PHPhotoLibrary` object using the `registerChangeObserver(...)` method. The change observer's `photoLibraryDidChange(...)` method will be called whenever another app or the user makes a change in the photo library **that affects any assets or collections that you fetched prior to the change**. The method has a single parameter of type `PHChange`, which you can use to find out if the changes are related to any of the fetched objects that you are interested in.

### Updating Fetch Results

`PHChange` provides methods you can call with any `PHObject`s or `PHFetchResult`s whose changes you are interested in tracking – `changeDetailsForObject(...)` and `changeDetailsForFetchResult(...)`. If there are no changes, these methods will return `nil`, otherwise you will be vended a `PHObjectChangeDetails` or `PHFetchResultChangeDetails` object.

`PHObjectChangeDetails` provides a reference to an updated photo entity object, as well as boolean flags telling you whether the object's image data was changed and whether the object was deleted.

`PHFetchResultChangeDetails` encapsulates information about changes to a `PHFetchResult` that you have previously received after a fetch. `PHFetchResultChangeDetails` is designed to make updates to a collection view or table view as simply as possible. Its properties map exactly to the information you need to provide in a typical collection view update handler. Note that to update `UITableView`/`UICollectionView` correctly, you must process the changes in the correct order: **RICE** – **r**emovedIndexes, **i**nsertedIndexes, **c**hangedIndexes, **e**numerateMovesWithBlock (if `hasMoves` is `true`). Furthermore, the `hasIncrementalChanges` property of the change details can be set to `false`, meaning that the old fetch result should just be replaced by the new value as a whole. You should call `reloadData` on your `UITableView`/`UICollectionView` in such cases.

Note: There is no need to make change processing centralized. If there are multiple components of your application that deal with photo entities, then each of them could have have its own `PHPhotoLibraryChangeObserver`. The components can then query the `PHChange` objects on their own to find out if (and how) they need to update their own state.


<a name="Wind-of-Change"></a>
## Wind of Change

Now that we know how to observe changes made by the user and other applications, we should try making our own!

### Changing Existing Objects

Performing changes on the photo library using PhotoKit boils down to creating a change request object linked to one of the assets or asset collections and setting relevant properties on the request object or calling appropriate methods describing the changes you want to commit. This has to happen within a block submitted to the shared `PHPhotoLibrary` via the `performChanges(...)` method. Note: You should be prepared to handle failure in the completion block passed to the `performChanges` method. This approach provides safety and relative ease of use while working with state that can be changed by multiple actors, such as your application, the user, other applications, and photo extensions.

To modify assets, create a [`PHAssetChangeRequest`](https://developer.apple.com/library/ios/documentation/Photos/Reference/PHAssetChangeRequest_Class/index.html#//apple_ref/occ/cl/PHAssetChangeRequest). You can then modify the creation date, the asset's location, and whether or not it should be hidden and considered a user's favorite. Additionally, you can delete the asset from the user's library.

Similarly, to modify asset collections or collection lists, create a [`PHAssetCollectionChangeRequest`](https://developer.apple.com/library/ios/documentation/Photos/Reference/PHAssetCollectionChangeRequest_Class/index.html#//apple_ref/occ/cl/PHAssetCollectionChangeRequest) or a [`PHCollectionListChangeRequest`](https://developer.apple.com/library/ios/documentation/Photos/Reference/PHCollectionListChangeRequest_Class/index.html#//apple_ref/occ/cl/PHCollectionListChangeRequest). You can then modify the collection title, add or remove members of the collection, or delete the collection altogether.

Note that before your changes are committed to the user's library, an alert might be shown to acquire explicit authorization from the user.

### Creating New Objects

Creating new assets is done similarly to changing existing assets. Just use the appropriate `creationRequestForAssetFromXXX(...)` factory method when creating the change request and pass the asset image data (or a URL) into it. If you need to make additional changes related to the newly created asset, you can use the creation change request's `placeholderForCreatedAsset` property. It returns a placeholder which can be used in lieu of a reference to a "real" `PHAsset`.


## Conclusion

We have discussed the basics of PhotoKit, but there is still a lot to be discovered. You should learn more by [poking around the sample code](https://developer.apple.com/library/ios/samplecode/UsingPhotosFramework/Introduction/Intro.html#//apple_ref/doc/uid/TP40014575), watching the [WWDC session video](https://developer.apple.com/videos/wwdc/2014/?id=511), and just diving in and writing some code of your own! PhotoKit enabled a new world of possibilities for iOS developers and we are sure to see more creative and clever products built on its foundation in the coming months and years.







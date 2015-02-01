PhotosKit
============

# Introduction 
iOS devices are defined by their single most prominent feature - the screen.
**!Tie in with iPhones being the most pervasive photo cameras in the world!**
Until last summer, developers have been using ALAssetsLibrary to access the users' ever-growing photo libraries. Over the years Camera.app and Photos.app have changed significantly, adding new features and even a new way of organizing photos by moments. Meanwhile the Assets Library Framework lagged behind. With iOS 8 Apple have given us PhotosKit, a more modern framework to access the wealth of information stored which provides more features and better performance than AssetsLibrary.

#Outline (and quick comparison with AssetsLibrary)
**!A sentence or two for each of the sections in the body. This will serve as a tiny Table of Contents for this article, so those who aren't reading deck-to-deck can jump to whatever they're interested in!**

#PhotosKit Object Model
PhotosKit defines an entity graph that models the objects presented to the user in the stock Photos.app. These *photo entities* are lightweight and immutable. All the PhotosKit objects inherit from the abstract `PHObject` base class, whose public interface only provides a `localIdentifier` property.

`PHAsset` represents a single asset in the users photo library, providing the metadata for that asset.

Groups of assets are called asset collections and are represented by the `PHAssetCollection` class. A single asset collection can be an album or a moment in the photo library, as well as one of the special "smart albums". These include collections of all videos, "recently added", user's favorites, all burst photos [and more](https://developer.apple.com/library/prerelease/ios/documentation/Photos/Reference/PHAssetCollection_Class/index.html#//apple_ref/c/tdef/PHAssetCollectionSubtype). `PHAssetCollection` is a subclass of `PHCollection`.

`PHCollectionList` represents a group of `PHCollection`s. Since it itself is a `PHCollection` a collection list can contain other collection lists, allowing for complex hierarchies of collections. In practice, this can be seen in the Moments tab in the Photos.app: Asset --- Moment --- Moment Cluster --- Moment Year.

##Fetching

###vs. Enumerating
Those familiar with the AssetsLibrary framework might remember that to be able to find assets with specific properties one has to **enumerate** through the users library and collect the matching assets. Granted, the API provided some ways of [narrowing down the search domain](https://developer.apple.com/library/ios/documentation/AssetsLibrary/Reference/ALAssetsGroup_Class/index.html#//apple_ref/occ/instm/ALAssetsGroup/setAssetsFilter:), but it still remains quite unwieldy.

In contrast, PhotosKit entity instances are **fetched**. Those familiar with Core Data will recognize the approaches and concepts used and described here. 

###Request
Fetches are made using the class methods of the entities described above. Which class/method to use depends on the problem domain and how you're representing and traversing the photo library. All of the fetch methods are named similarly: `class func fetchXXX(..., options: PHFetchOptions) -> PHFetchResult`. The `options` parameter gives us a way of filtering and ordering the returned results, similar to `NSFetchRequest`'s `predicate` and `sortDescriptors` parameters.

###Result

You may have noticed that these fetch methods aren't asynchronous. Instead, they return a `PHFetchResult` object, which allows access to the underlying collection of results with an interface similar to `NSArray`. It will dynamically load its contents as needed and cache contents around the most recently requested value. This behavior is similar to the result array of a `NSFetchRequest` with a set `batchSize` property. There is no way to parametrize this behavior for `PHFetchResult`, but the documentation promises "*optimal performance even when handling a large number of results*".

The `PHFetchResult`s returned by the fetch methods will not be updated automatically if the photo library contents that match the request change. Observing changes and processing updates for a given `PHFetchResult` is described in a later chapter - *![LINK TO CHANGE OBSERVING CHAPTER]!*.

#Photo Loading

Over the years of working with the user's photo libraries developers have created hundreds if not thousands of tiny pipelines for efficient photo loading and display. These pipelines would deal with request dispatching and cancellation, image resizing and cropping, caching and more. PhotosKit provides a class that does all this with a convienent and modern API - `PHImageManager`. 

##Requesting images

Image requests are dispatched using the `requestImageForAsset(...)` method. The method takes in a `PHAsset`, desired sizing of the image and other options (via the `PHImageRequestOptions` parameter object), and a results handler. The returned value can be used to cancel the request if the requested data is no longer necessary. 

###Image Sizing and Cropping
Curiously, the parameters regarding the sizing and cropping of the result image are spread across two places. The `targetSize` and and `contentMode` parameters are passed directly into the `requestImageForAsset(...)` method. The content mode describes whether the photo should be aspect-fitted or aspect-filled into the target size, similar to UIView's contentMode. **NB. If the photo should not be resized or cropped - pass PHImageManagerMaximumSize and PHImageContentMode.Default**

Additionally, `PHImageRequestOptions` provides means of specifying *how* the image manager should resize. The `resizeMode` property can be set to .Exact (when the result image must match the target size), .Fast (more efficient than .Exact, but result image might differ from the target size) or .None. Furthermore, the `normalizedCroppingMode` property lets us specify how the image manager should crop the image. **NB. If `normalizedcroppingMode` is provided – set `resizeMode` to .Exact**

###Request Delivery and Progress
By default the image manager will deliver a lower-quality version of your image before delivering the high-quality version if it decides that's the optimal strategy to use. You can control this behaviour through the `deliveryMode` property - the default behavior is .Opportunistic. Set it to .HighQualityFormat if you're only interested in the highest-quality of the image available and longer load times are acceptable. Use .FastFormat to load the image faster sacrificing the quality.

You can make the `requestImage...` method synchronous using the `synchronous` property on `PHImageRequestOptions`. **NB. When `synchronous` is set to YES/true, the `deliveryMode` property is ignored and considered to be set to .HighQualityFormat**. 

When setting these parameters it is important to always consider that some of your users might have iCloud Photo Library enabled. The PhotosKit API practically doesn't distinguish photos available on-device from those available in the cloud – they are all loaded using the same `requestImage` method. This means, that every single of your image requests may potentially be a slow network request over the cellular network. Keep this in mind when considering using .HighQualityFormat and/or making your requests synchronous. **NB. If you want to make sure that the request doesn't hit the network – set networkAccessAllowed**

Another iCloud-related property is `progressHandler`. You can set it to a [`PHAssetImageProgressHandler`](https://developer.apple.com/library/ios/documentation/Photos/Reference/PHImageRequestOptions_Class/index.html#//apple_ref/doc/c_ref/PHAssetImageProgressHandler) block to that will be called by the image manager when downloading the photo from iCloud.


###Asset Versions
PhotosKit provides a framework for applying non-destructive adjustments to the original asset image data. This lets developers build non-filters and various other editing tools, photo editing extensions that live right within the standard Photos.app and gives users the peace of mind that they can always go back to the original image.

When fetching assets using the image manager, you can specify which version of the image asset should be delivered via the result handler. This is done by setting the `version` property:
.Current will deliver the image with all adjustments applied to it; .Unadjusted delivers the image before any adjustments are applied to it; and .Original delivers the image in its original, highest-quality format (e.g. RAW vs JPEG delivered when using .Unadjusted).

... **!possibly link to the relevant article in this issue!**

##Result Handler
The result handler is a block that takes in a `UIImage` and an `info` dictionary. It can be called by the image manager multiple times throughout the lifetime of the request, depending on the parameters and the request options.

The `info` dictionary provides information about the current status of the request:
* whether the image has to be requested from iCloud (in which case you're going to have to re-request the image if you initially set `networkAccessAllowed` to false) – `PHImageResultIsInCloudKey`.
* whether the currently delivered `UIImage` is the degraded form of the final result. This lets you display a preview of the image to the user, while the higher-quality image is being downloaded - `PHImageResultIsDegradedKey`.
* the request ID (convenience for cancelling the request) and whether the request was already cancel – `PHImageResultRequestIDKey` and `PHImageCancelledKey`.
* an error, if an image wasn't provided to the result handler – PHImageErrorKey

These values let you update your UI to inform your user and, together with the `progressHandler` discussed above, hint at the loading state of their images.


##Caching
At times it's useful to load some images into memory prior to the moment that they are going to be shown on the screen, for example when displaying a screen with a large numbers of asset thumbnails in a scrolling collection. PhotosKit provides a `PHImageManager` subclass that deals with that specific use case – `PHImageCachingManager`. 

`PHImageCachingManager` provides a single key method – `startCachingImagesForAssets(...)`. You pass in an array of PHAssets and parameters and options that should match those you're going to use later when requesting individual images. Additionally, there are methods that you can use to inform the caching manager to stop caching images for a list of specific assets and to stop caching all images. 

The `allowsCachingHighQualityImages` property lets you specify whether the image manager should perpare images at high quality. When caching a relatively short and unchanging list of assets the default `true` value should work just fine. For large collections and when you're trying to precache images while the user is scrolling quickly - it might be better to only cache lower quality images.

##Requesting Image Data
Finally, in addition to requesting plain old UIImages, `PHImageManager` provides another method with returns the asset data as an NSData object, its universal type identifier and the display orientation of the image. This method returns the largest available representation of the asset.

#Wind of Change
We have discussed requesting metadata of assets in the user's photo library, but we haven't covered how to keep our fetched data up-to-date. The photo library is essentially a big bag of mutable state and yet the photo entities covered in the first section are immutable. PhotosKit has a special process for receiving notifications about changes to the photo library and subsequently update your cached state.

## Change observing
Firstly, you need to register a change observer (conforming to the `PHPhotoLibraryChangeObserver` protocol) with the shared `PHPhotoLibrary` object using the `registerChangeObserver(...)` method. The change observer's `photoLibraryDidChange(...)` method will be called whenever another app or the user makes a change in the photo library **that affects any assets or collections that you fetched prior to the change**. The method has a single parameter of type `PHChange` which you can use to find out if the changes are related to any of the fetched objects that you are interested in.

## Updating your cached state
`PHChange` provides methods you can call with any `PHObject`s or `PHFetchResult`s whose changes you are interested in tracking – `changeDetailsForObject(...)` and `changeDetailsForFetchResult(...)`. If there are no changes these methods will return `nil`, otherwise you will be vended a `PHObjectChangeDetails` or `PHFetchResultChangeDetails` object.

`PHObjectChangeDetails` provides a reference to an updated photo entity object as well as boolean flags telling you whether the object's image data was changed and whether the object was deleted.

`PHFetchResultChangeDetails` encapsulates information about changes to a `PHFetchResult` that you have previously received after a fetch. Its properties map well to updating such UI as a collection view or a table view. *Note that to update `UITableView`/`UICollectionView` correctly you **must** process the changes in the correct order: **RICE** – *r*emovedIndexes, *i*nsertedIndexes, *c*hangedIndexes, *e*numerateMovesWithBlock (if `hasMoves` is true).* Furthermore, the `hasIncrementalChanges` property of the change details can be set to `false`, meaning that the old fetch result should just be replaced by the change value as a whole. You should call `reloadData` on your `UITableView`/`UICollectionView` in such cases.

There is no need to make change processing centralized. If there are multiple components of your application that deal with photo entities each of them could have have its own `PHPhotoLibraryChangeObserver`. The components then query the `PHChange` objects on their own to find out if (and how) they need to update their own state.

#Making your own changes
...
## Change request
...
## PHObjectPlaceholder
...

#Photo metadata
	* HDR
	* Panoramas
	* favorites
	* Burst mode photos
	* iCloud Photo Library
	* HFR **!Tease the next objc.io!**
* Moments hierarchy
* Transient collections (maybe?)
* Asset content editing **!LINK TO THE RELEVANT ARTICLE IN THIS ISSUE!**

#Asides

##Photo adjustments
<!--In theory it should be possible for apps to be able to parse each other's adjustments, but I haven't seen that in practive-->
##Swift
**!Annoyances when using the PhotosKit API from Swift (namely PHFetchResult)!**

#Conclusion
**!Recap. An inspiring paragraph about new possibilities**!
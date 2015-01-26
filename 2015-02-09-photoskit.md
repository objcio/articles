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
//PhotosKit provides a way of applying undoable 
... **!possibly link to the relevant article in this issue!**

##Result Handler
...

##Caching
...

##Requesting Image Data
...

#Wind of Changes
...
## Change observing
...
## Updating your cached state
...

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

##A Swift Aside
**!Annoyances when using the PhotosKit API from Swift (namely PHFetchResult)!**

#Conclusion
**!Recap. An inspiring paragraph about new possibilities**!
PhotosKit
============

# Introduction 
iOS devices are defined by their single most prominent feature - the screen.
**!Tie in with iPhones being the most pervasive photo cameras in the world!**
Until last summer, developers have been using ALAssetsLibrary to access the users' ever-growing photo libraries. Over the years Camera.app and Photos.app have changed significantly, adding new features and even a new way of organizing photos by moments. Meanwhile the Assets Library Framework lagged behind. With iOS 8 Apple have given us PhotosKit, a more modern framework to access the wealth of information stored which provides more features and better performance than AssetsLibrary.

#Outline (and quick comparison with AssetsLibrary)
**!A sentence or two for each of the sections in the body. This will serve as a tiny Table of Contents for this article, so those who aren't reading deck-to-deck can jump to whatever they're interested in!**

#Body

* Enumerating (vs. fetching)
	* The PHObject hierarchy
* Wind of Changes
	* Change observing
	* Updating your cached state
* Loading
	* **!Wax poetic about PHImageManager and hundreds of developers writing their own classes in the past to do what PHImageManager does.**!
	* Requesting images
		* Asset versions (original vs edited in other apps) **!possibly link to the relevant article in this issue!**
		* Sizes
		* Other options
		* Thumbnails
	* Caching
	* Working with videos **!Tease the next objc.io!**
* Photo metadata
	* HDR
	* Panoramas
	* favorites
	* Burst mode photos
	* iCloud Photo Library
	* HFR **!Tease the next objc.io!**
* Moments hierarchy
* Transient collections (maybe?)
* Asset content editing **!LINK TO THE RELEVANT ARTICLE IN THIS ISSUE!**


#Aside
##Bugs
* Bug with image loading of burst photos when requesting resized images

##Swift
Annoyances when using the PhotosKit API from Swift (namely PHFetchResult)

#Conclusion
Recap. An inspiring paragraph about new possibilities
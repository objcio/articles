---
title:  "Photo Extensions"
category: "21"
date: "2015-02-10 07:30:00"
tags: article
author:
  - name: Sam Davies
    url: https://twitter.com/iwantmyrealname
---


When iOS 8 came out, Apple introduced extensions to the world, with
[six extension points](https://developer.apple.com/library/ios/documentation/General/Conceptual/ExtensibilityPG/index.html#//apple_ref/doc/uid/TP40014214-CH20-SW2)
available. These offer unprecedented access to the operating system, with the
Photo Editing extension allowing developers to build functionality into the
system Photos app.

The user workflow for Photo Editing extensions is not entirely simple. From
selecting the photo you want to edit, it takes three taps to launch the
extension, one of which is on a tiny, unintuitive button:

![Image Editing Extension User Workflow](/images/issue-21/user_workflow.png)

Nevertheless, these kinds of extensions offer a fantastic opportunity for
developers to offer a seamless experience to users, thereby creating a consistent
approach to managing photos.

This article will talk briefly about how to create extensions, and their
lifecycle, before moving on to look at the editing workflow in more
details. It will conclude by looking at some common concerns and scenarios
associated with creating Photo Editing extensions.

The _Filtster_ project, which accompanies this article, demonstrates how you
can set up your own image editing extension. It represents a really simple image
filtering process using a couple of Core Image filters. You can access the
[complete _Filtster_ project on GitHub](https://github.com/objcio/issue-21-photo-extensions-Filtster).

## Creating an Extension

All types of iOS extensions have to be contained in a fully functional iOS app,
and this includes Photo Editing extensions. This can mean that you have to
do a lot of work to get your amazing new custom Core Image filter in the hands of
some users. It remains to be seen how strict Apple is on this, since most apps
in the App Store with custom image editing extensions existed before the
introduction of iOS 8.

To create a new image editing extension, add a new target to an existing iOS
app project. There is a template target for the extension:

![Image Editing Extension Template](/images/issue-21/xcode-target-template-photo-extension.png)

This template consists of three components:

1. __Storyboard.__ Image editing extensions can have an almost completely custom UI. The system provides only a toolbar across the top, containing _Cancel_ and
_Done_ buttons:

    ![Cancel/Done Buttons](/images/issue-21/cancel_done.png)

    Although the storyboard doesn't have size classes enabled by default, the system will respect them should you choose to activate them. Apple highly recommends using Auto Layout for building Photo Editing extensions, although there is no obvious reason why you couldn't perform manual layout. Still, you're flying in the face of danger if you decide to ignore Apple's advice.

2. __Info.plist.__ This specifies the extension type and accepted media types,
and is common to all extension types. The `NSExtension` key has a
dictionary containing all the extension-related configurations:

    ![Extension plist](/images/issue-21/extension_plist.png)

    The  `NSExtensionPointIdentifier` entry informs the system that this is a Photo Editing extension with a value of `com.apple.photo-editing`. The only key that is specific to photo editing is `PHSupportedMediaTypes`, and this is related to what types of media the extension can operate on. By default, this is an array with a single entry of `Image`, but you have the option of adding `Video`.

3. __View Controller.__ This adopts the `PHContentEditingController` protocol,
which contains methods that form the lifecycle of an image editing extension.
See the next section for further detail.

Notably missing from this list is the ability to provide the imagery for the
icon that appears in the extension selection menu:

![Extension Icon](/images/issue-21/extension_icon.png)

This icon is provided by the App Icon image set in the host app's asset catalog.
The documentation is a little confusing here, as it implies that you have to
provide an icon in the extension itself. However, although this is possible, the
extension will not honor the selection. This point is somewhat moot, as Apple
specifies that the icon associated with an extension should be identical to that
of the container app.

## Extension Lifecycle

The Photo Editing extension is built on top of the Photos framework, which means
that edits aren't destructive. When a photo asset is edited, the original file
remains untouched, while a rendered copy is saved. It addition, semantic
details about how to recreate the edit are saved as adjustment data. This data
means that the edit can be completely recreated from the original image. When
you implement image editing extensions, you are responsible for constructing your
own adjustment data objects.

The `PHAdjustmentData` class represents these edit parameters, and has two
format properties (`formatIdentifier` and `formatVersion`) that are used to
determine compatibility of an editing extension with a previously edited image.
Both properties are strings, and the `formatIdentifier` should be in reverse-DNS
form. These two properties give you the flexibility to create a suite of image
editing apps and extensions, each of which can interpret the editing results from
the others. There is also a `data` property that is of type `NSData`. This can
be used however you wish to store the details of how your extension can resume
editing.

### Beginning Editing

When a user chooses to edit an image using your extension, the system will instantiate your view controller and initiate the photo editing lifecycle. If the photo has previously been edited, this will first call the `canHandleAdjustmentData(_:)` method, at which point you are provided a `PHAdjustmentData` object. As such, it's important to figure out in advance whether or not your extension can handle the previous edit data. This determines what the framework will send to the next method in the lifecycle.

Once the system has decided to supply either the original image or one
containing the rendered output from previous edits, it then calls the
`startContentEditingWithInput(_:, placeholderImage:)`. The input is an object of
type `PHContentEditingInput`, which contains metadata such as location, creation
data, and media type about the original asset, alongside the details you need to
edit the asset. In addition to the path of the full-size input
image, the input object also contains a `displaySizedImage` that represents the
same image data, but is scaled appropriately for the screen. This means that the
interactive editing phase can operate at a lower resolution, ensuring that your
extension remains responsive and energy efficient.

The following shows an implementation of this method:

```swift
func startContentEditingWithInput(contentEditingInput: PHContentEditingInput?,
                                  placeholderImage: UIImage) {
  input = contentEditingInput
  filter.inputImage = CIImage(image: input?.displaySizeImage)
  if let adjustmentData = contentEditingInput?.adjustmentData {
    filter.importFilterParameters(adjustmentData.data)
  }

  vignetteIntensitySlider.value = Float(filter.vignetteIntensity)
  ...
}
```

The above implementation stores the `contentEditingInput`, since it's required to
complete the edit, and imports the filter parameters from the
adjustment data.

If your `canHandleAdjustmentData(_:)` method returned `true`, then the images
provided to `startContentEditingWithInput(_:, placeholderImage:)` will be
original, and the extension will have to recreate the edited image from the
previous adjustment data. If this is a time-consuming process, then the
`placeholderImage` is an image of the rendered previous edit that can be used
temporarily.

At this stage, the user interacts with the UI of the extension to control the
editing process. Since the extension has a view controller, you can use any of
the features of UIKit to implement this. The sample project uses a Core Image
filter chain to facilitate editing, so the UI is handled with a custom `GLKView`
subclass to reduce the load on the CPU.

### Cancellation

To finish editing, users can select either the _Cancel_ or _Done_ buttons
provided by the Photos UI. If the user decides to cancel with unsaved edits,
then the `shouldShowCancelConfirmation` property should be overridden to return
`true`:

![Confirm Cancellation](/images/issue-21/confirm_cancel.png)

If the cancellation is requested, then the `cancelContentEditing` method is
called to allow you to clear up any temporary data that you've created.

### Commit Changes

Once the user is happy with his or her edits and taps the _Done_ button, a call is
made to `finishContentEditingWithCompletionHandler(_:)`. At this point, the full-size image needs to be edited with the settings that are currently applied to
the display-sized image, and the new adjustment data needs saving.

At this point, you can obtain the full-size image using the `fullSizeImageURL` on
the `PHContentEditingInput` object provided at the beginning of the editing
process.

To complete editing, the supplied callback should be invoked with a
`PHContentEditingOutput` object, which can be created from the input. This
output object also includes a `renderedContentURL` property that specifies
where you should write the output JPEG data:

```swift
func finishContentEditingWithCompletionHandler(completionHandler: ((PHContentEditingOutput!) -> Void)!) {
  // Render and provide output on a background queue.
  dispatch_async(dispatch_get_global_queue(CLong(DISPATCH_QUEUE_PRIORITY_DEFAULT), 0)) {
    // Create editing output from the editing input.
    let output = PHContentEditingOutput(contentEditingInput: self.input)

    // Provide new adjustments and render output to given location.
    let adjustmentData = PHAdjustmentData(formatIdentifier: self.filter.filterIdentifier,
      formatVersion: self.filter.filterVersion, data: self.filter.encodeFilterParameters())
    output.adjustmentData = adjustmentData

    // Write the JPEG data
    let fullSizeImage = CIImage(contentsOfURL: self.input?.fullSizeImageURL)
    UIGraphicsBeginImageContext(fullSizeImage.extent().size);
    self.filter.inputImage = fullSizeImage
    UIImage(CIImage: self.filter.outputImage)?.drawInRect(fullSizeImage.extent())

    let outputImage = UIGraphicsGetImageFromCurrentImageContext()
    let jpegData = UIImageJPEGRepresentation(outputImage, 1.0)
    UIGraphicsEndImageContext()

    jpegData.writeToURL(output.renderedContentURL, atomically: true)

    // Call completion handler to commit edit to Photos.
    completionHandler?(output)
  }
}
```

Once the call to the `completionHandler` has returned, you can clear up any
temporary data and files ready for the extension to return.


## Common Concerns

There are a few areas associated with creating an image editing extension that
can be a little complicated. The topics in this section address the most
important of these.

### Adjustment Data

The `PHAdjustmentData` is a simple class with just three properties, but to get
the best use from it, discipline is required. Apple suggests using reverse-DNS
notation to specify the `formatIdentifier`, but then you are left to decide how
to use the `formatVersion` and `data` properties yourself.

It's important that you can determine compatibility between different versions
of your image editing framework, so an approach such as [semantic versioning](http://semver.org/)
offers the flexibility to manage this over the lifetime of your products. You
could implement your own parser, or look to a third-party framework such as
[SemverKit](https://github.com/nomothetis/SemverKit) to provide this
functionality.

The final aspect of the adjustment data is the `data` property itself,
which is just an `NSData` blob. The only advice that Apple offers here is that
it should represent the settings to recreate the edit, rather than the edit
itself, since the size of the `PHAdjustmentData` object is limited by the Photos
framework.

For non-complex extensions (such as _Filtster_), this can be as simple as an
archived dictionary, which can be written as follows:

```swift
public func encodeFilterParameters() -> NSData {
  var dataDict = [String : AnyObject]()
  dataDict["vignetteIntensity"] = vignetteIntensity
  ...
  return NSKeyedArchiver.archivedDataWithRootObject(dataDict)
}
```

This is then reinterpreted with the following:

```swift
public func importFilterParameters(data: NSData?) {
  if let data = data {
    if let dataDict = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? [String : AnyObject] {
      vignetteIntensity = dataDict["vignetteIntensity"] as? Double ?? vignetteIntensity
      ...
    }
  }
}
```

Here, these two methods are on the shared `FiltsterFilter` class, which is also
responsible for determining compatibility of the adjustment data:

```swift
public func supportsFilterIdentifier(identifier: String, version: String) -> Bool {
  return identifier == filterIdentifier && version == filterVersion
}
```

If you have more complex requirements, you could create a custom settings
class, which adopts the `NSCoding` protocol to allow it to be archived in a
similar manner.

A user can chain incompatible photo edits together — if the adjustment
data is not understood by the current extension, the pre-rendered image will be
used as input. For example, you can crop an image using the system crop tool
before using your custom Photo Editing extension. Once you have saved the edited
image, the associated adjustment data will only contain details of the most
recent edit. You could store adjustment data from the previous, incompatible edit
in your output adjustment data, allowing you to implement a revert function for
just your phase of the filter chain. The revert function provided by the Photos
app will remove all the edits, returning the photo to its original state:

![Revert Edits](/images/issue-21/revert.png)


### Code/Data Sharing

Photo Editing extensions are distributed as an embedded binary inside a
container app, which Apple has stated must be a functioning app. Since you're
creating a Photo Editing extension, it is likely that the app will offer the
same functionality. You're therefore likely to want to share code and data
between the app extension and the container app.

Sharing code is achieved by creating a Cocoa Touch Framework target, a new
functionality available in iOS 8. Then you can add shared functionality, such as
the filter chain and custom view classes, and use them from both the app and
the extension.

Note that since the framework will be used from an app extension, you must
restrict the APIs it can use on the Target Settings page:

![Restrict Framework API](/images/issue-21/app_extension_api.png)

Sharing data is a less obvious requirement, and in many cases it won't exist.
However, if necessary, you can create a shared container, which is
achieved by adding both the app and extension to an app group associated with
your developer profile. The shared container represents a shared space on disk
that you can use in any way you wish, e.g. `NSUserDefaults`, `SQLite`, or file
writing.

### Debugging and Profiling

Debugging is reasonably well-supported in Xcode, although there are some
potential sticking points. Selecting the extension's scheme and selecting run
should build it and then let you select which app to run. Since photo
editing extensions can only be activated from within the system Photos app, you
should select the Photos app:

![Select App](/images/issue-21/select_app.png)

If this instead launches your container app, then you can edit the extension's
scheme to set the executable to _Ask on Launch_.

Xcode then waits for you to start the Photo Editing extension before attaching
to it. At this point, you can debug as you do with standard iOS apps. The
process of attaching the debugger to the extension can take quite a long time,
so when you activate the extension, it can appear to hang. Running in release mode
will allow you to evaluate the extension startup time.

Profiling is similarly supported, with the profiler attaching as the extension
begins to run. You might once again need to update the scheme associated with
the extension to specify that Xcode should ask which app should run as profiling
begins.


### Memory Restrictions

Extensions are not full iOS apps and therefore are permitted restricted access
to system resources. More specifically, the OS will kill an extension if it uses
too much memory. It's not possible to determine the exact memory limit, since memory management is handled privately by iOS, however it is definitely dependent on factors such as the device, the host app, and the memory pressure from other apps. As such, there are no hard
limits, but instead a general recommendation to minimize the memory footprint.

Image processing is a memory-hungry operation, particularly with the resolution
of the photos from an iPhone camera. There are several things you can do to keep
the memory usage of your Photo Editing extension to a minimum.

- __Work with the display-sized image:__ When beginning the edit process, the
system provides an image suitably scaled for the screen. Using this instead of
the original for the interactive editing phase will require significantly less
memory.
- __Limit the number of Core Graphics contexts:__ Although it might seem like the way
to work with images, a Core Graphics context is essentially just a big chunk of
memory. If you need to use contexts, then keep the number to a minimum. Reuse them
where possible, and decide whether you're using the best approach.
- __Use the GPU:__ Whether it be through Core Image or a third-party framework such
as GPUImage, you can keep memory down by chaining filters together and
eliminating the requirement for intermediate buffers.

Since image editing is expected to have high memory requirements, it seems that
the extensions are given a little more leeway than other extension types. During
ad hoc testing, it appears to be possible for an image editing extension to use
more than 100 MB. Given that an uncompressed image from an 8-megapixel camera is
approximately 22 MB, most image editing should be achievable.


## Conclusion

Prior to iOS 8, there was no way for a third-party developer to provide
functionality to the user anywhere other than within his or her own app. Extensions
have changed this, with the Photo Editing extension in particular allowing you
to put your code right into the heart of the Photos app. Despite the slightly
convoluted multi-tap workflow, the Photo Editing extension uses the power of the
Photos framework to provide a coherent and integrated user experience.

Resumable editing has traditionally been reserved for use in desktop photo
collection applications such as Aperture or Lightroom. Creating a common
architecture for this on iOS with the Photos framework offers great
potential, and allowing the creation of Photo Editing extensions takes this even
further.

There are some complexities associated with creating Photo Editing extensions,
but few of these are unique. Creating an intuitive interface and designing image processing algorithms are both as challenging for image editing extensions as they are for complete image editing apps.

It remains to be seen how many users are aware of these third-party image editing
extensions, but they have the potential to increase your app's exposure.

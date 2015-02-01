---
title:  "Photo Extension"
category: "21"
date: "2015-02-09 09:00:00"
tags: article
author: "<a href=\"https://twitter.com/iwantmyrealname\">Sam Davies</a>"
---


iOS 8 introduced extensions to the world - with six extension points available.
These offer unprecedented access to the operating system and the photo editing
extension allows developers to build functionality into the system Photos app.

The user workflow for photo editing extensions is not the most intuitive. From
selecting the photo you want to edit, it takes three taps to launch the
extension, one of which is on a tiny, unintuitive button.

![Image Editing Extension User Workflow](http://f.cl.ly/items/2C1V2t1x04402v1K3Q3m/user_workflow.png)

Nevertheless, image editing extensions offer a fantastic opportunity for
developers to offer a seamless experience to users - creating a consistent
approach to managing photos.

This article will talk briefly about how to create extensions and their
lifecycle before moving on to look at the photo editing workflow in more
details. It will conclude by looking at some common concerns and scenarios
associated with creating photo editing extensions.

The __Filtster__ project, which accompanies this article, demonstrates how you
can set up your own image editing extension. It represents a really simple image
filtering process, using a couple of CoreImage filters. You can get hold of the
complete __Filtster__ project on Github at 
[github.com/sammyd/Filtster](https://github.com/sammyd/Filtster).

## Creating an extension

All types of iOS extension have to be contained by a fully-functional iOS app,
and this includes photo editing extensions. This can mean that you would have to
do a lot of work to get your amazing new custom CoreImage filter in the hands of
some users. It remains to be seen how strict Apple is on this, since most apps
in the App Store with custom image editing extensions existed before the
introduction of iOS 8.

To create a new image editing extension you add a new target to an existing iOS
app project. There is a template target for the image editing extension:

![Image Editing Extension Template](http://f.cl.ly/items/2t433C2Z0q1W17313a1B/Screen%20Shot%202015-01-31%20at%2017.42.36.png)

This template consists of three components:

1. __Storyboard__ Image editing extensions can have an almost completely custom
UI. The system provides just a toolbar across the top, containing __Cancel__ and
__Done__ buttons.
![Cancel/Done Buttons](http://cl.ly/image/2x0D1z1q3q08/cancel_done.png)
Although the storyboard doesn't have size classes enabled by
default, the system will respect them should you choose to activate them. Apple
highly recommends using Auto Layout for building photo editing extensions,
although there is no obvious reason why you couldn't perform manual layout at
the current time. You're flying in the face of danger if you decide to ignore
Apple's advice.
2. __Info.plist__ This specifies the extension type and accepted media types,
and is common to all extension types. The `NSExtension` key contains a
dictionary containing all the extension-related configuration.
![Extension plist](http://cl.ly/image/3s0u1y2G1S2Q/extension_plist.png)
The  `NSExtensionPointIdentifier` entry informs the system that this is a photo
editing extension with its value of `com.apple.photo-editing`. The only key that
is specific to photo editing is `PHSupportedMediaTypes` and this is related to
what types of media the extension can operate on. By default this is an array
with a single entry of `Image`, but you have the option of adding `Video`.
3. __View Controller__ This adopts the `PHContentEditingController` protocol,
which contains methods that form the lifecycle of an image editing extension.
See the next section for further detail.

Notably missing from this list is the ability to provide the imagery for the
icon that appears in the extension selection menu:

![Extension Icon](http://cl.ly/image/1h2m3o040H3I/extension_icon.png)

This icon is provided by the AppIcon image set in the host app's asset catalog.
The documentation is a little confusing here as it implies that you have to
provide an icon in the extension itself but, although this is possible, the
extension will not honor the selection. This point is somewhat moot as Apple
specifies that the icon associated with an extension should be identical to that
of the container app.

## Extension Lifecycle

The photo editing extension is built on top of the Photos framework, which means
that edits aren't destructive. When a photo asset is edited, the original file
remains untouched, whilst a rendered copy is saved. It addition, semantic
details about how to recreate the edit are saved as adjustment data. This data
means that the edit can be completely recreated from the original image. When
you implement image editing extensions you are responsible for constructing your
own adjustment data objects.

The `PHAdjustmentData` class represents these edit parameters, and has two
format properties (`formatIdentifier` and `formatVersion`) that are used to
determine compatibility of an editing extension with an previously edited image.
Both properties are strings, and the `formatIdentifier` should be in reverse-DNS
form. These two properties give you the flexibility to create a suite of image
editing apps and extensions each of which can interpret the editing results from
the others. There is also a `data` property that is of type `NSData`. This can
be used however you wish to store the details of how your extension can resume
editing.

### Beginning Editing

When a user chooses to edit an image using your extension, the system will
instantiate your view controller and initiates the photo editing lifecycle. If
the photo has previously been edited, this will first call the 
`canHandleAdjustmentData(_:)` method, in which you are provided a
`PHAdjustmentData` object. From this you have to determine whether or not your
extension can handle the previous edit data. This determines what the framework
will send to the next method in the lifecycle.

Once the system has decided whether to supply the original image, or one
containing the rendered output from previous edits, it then calls the
`startContentEditingWithInput(_:, placeholderImage:)`. The input is an object of
type `PHContentEditingInput` which contains metadata such as location, creation
data and media type about the original asset, alongside the details you need to
edit the asset. Importantly, in addition to the path of the full-size input
image, the input object also contains a `displaySizedImage`, that represents the
same image data, but scaled appropriately for the screen. This means that the
interactive editing phase can operate at a lower resolution, ensuring that your
extension remains responsive and energy efficient.

The below shows and implementation of this method:

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

The above implementation stores the `contentEditingInput` since it's required to
complete the edit, as well as importing the filter parameters from the
adjustment data.

If your `canHandleAdjustmentData(_:)` method returned `true` then the images
provided to `startContentEditingWithInput(_:, placeholderImage:)` will be
original, and the extension will have to recreate the edited image from the
previous adjustment data. If this is a time-consuming process then the
`placeholderImage` is an image of the rendered previous edit that can be used
temporarily.

At this stage the user interacts with the UI of the extension to control the
editing process. Since the extension has a view controller, you can use any of
the features of UIKit to implement this. The sample project uses a CoreImage
filter chain to facilitate editing, so the UI is handled with a custom `GLKView`
subclass to reduce the load on the CPU.

### Cancellation

To finish editing users can select either the __Cancel__ or __Done__ buttons
provided by the Photos UI. If the user decides to cancel with unsaved edits,
then the `shouldShowCancelConfirmation` property should be overridden to return
`true`.

![Confirm Cancellation](http://cl.ly/image/3I3J3t1C2I3K/confirm_cancel.png)
 
If the cancellation is requested then the `cancelContentEditing` method is
called to allow you to clear up any temporary data that you've created.

### Commit Changes

Once the user is happy with their edits and tap the __Done__ button, a call is
made to `finishContentEditingWithCompletionHandler(_:)`. At this point, the full
size image needs to be edited with the settings that are currently applied to
the display-sized image, and the new adjustment data needs saving.

At this point you can obtain the full size image using the `fullSizeImageURL` on
the `PHContentEditingInput` object provided at the beginning of the editing
process.

To complete editing, the supplied callback should be invoked with a
`PHContentEditingOutput` object, which can be created from the input. This
output object also includes a `renderedContentURL` property which specifies
where you should write the output JPEG data.

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

Once the call to the `completionHandler` has returned then you can clear up any
temporary data and files ready for the extension to return.


## Common concerns

- Handling memory restrictions
- Sharing code with the container app
- Developing and debugging
- Profiling
- Advanced adjustment data usage


## Conclusion
- Put your code right in the heart of the Photos app
- Still a little fiddly to get to (screen taps)
- Resumable editing
- Great potential


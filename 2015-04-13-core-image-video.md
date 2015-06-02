---
title:  "Core Image and Video"
category: "23"
date: "2015-04-13 10:00:00"
tags: article
author:
  - name: Daniel Eggert
    url: https://twitter.com/danielboedewadt
  - name: Chris Eidhof
    url: https://twitter.com/chriseidhof

---

In this article, we'll look into applying Core Image effects to live video. We'll look at two examples: first, we'll apply effects to the camera image. Second, we'll apply effects to an existing movie file. It's also possible to do offline rendering, where you render the result back into a video instead of directly on the screen. The full code of both examples is available [here](https://github.com/objcio/core-image-video).

## Quick Recap

Performance is very important when it comes to video. And it's important to understand how things work under the hood — how Core Image does its work — in order to be able to deliver that performance. It's important to do as much work on the GPU as possible, and minimize the transferring of data between GPU and CPU. After the examples, we'll look into the details of this.

To get a feeling for Core Image, it's good to read Warren's article: [An Introduction to Core Image](/issues/21-camera-and-photos/core-image-intro/). We'll use the functional wrappers around `CIFilter` as described in [Functional Core Image](/issues/16-swift/functional-swift-apis/). To understand more about AVFoundation, have a look at [Adriaan's article](/issues/23-video/capturing-video/) in this issue and the [Camera Capture](/issues/21-camera-and-photos/camera-capture-on-ios/) article in Issue #21.

## Harnessing OpenGL ES

Core Image can run on both the CPU and the GPU. We'll go into more detail about what to be aware of [below](#cpuvsgpu). In our case, we want to use the GPU, and we do that as follows.

We start by creating a custom `UIView` that allows us to render Core Image's results directly into OpenGL. We can use a `GLKView` and initialize it with a new `EAGLContext`. We need to specify OpenGL ES 2 as the rendering API. In both examples, we want to trigger the drawing ourselves (rather than having `-drawRect:` called for us), so when initializing the `GLKView`, we need to set `enableSetNeedsDisplay` to false. This then puts the burden on us to call `-display` when we have a new image available.

In this view, we also keep a reference to a `CIContext`. This context provides the connection between our Core Image objects and the OpenGL context. We create it once and keep it around. The context allows Core Image to do behind-the-scenes optimizations, such as caching and reusing resources like textures. It is therefore important to reuse the same context.

The context has a method, `-drawImage:inRect:fromRect:`, which draws a `CIImage`. If you want to draw an entire image, it's easiest to use the image's `extent`. Note however, that it might be infinitely large, so make sure you either crop it beforehand or provide a finite rectangle. A caveat: Because we're dealing with Core Image, the drawing's destination rectangle is specified in pixels, not in points. As most new iOS devices are in Retina, we need to account for this when drawing. If we want to fill up our entire view, it's easiest to take the bounds and scale it up by the screen's scale.

For a full code example, take a look at [CoreImageView.swift](https://github.com/objcio/core-image-video/blob/master/CoreImageVideo/CoreImageView.swift) in our sample project.

## Getting Pixel Data from the Camera

For an overview of how AVFoundation works, see [Adriaan's article](/issues/23-video/capturing-video/) and the [Camera Capture](/issues/21-camera-and-photos/camera-capture-on-ios/) article by Matteo. For our purposes, we want to get raw sample buffers from the camera. Given a camera, we do this by creating an `AVCaptureDeviceInput` object. Using an `AVCaptureSession`, we can connect it to an `AVCaptureVideoDataOutput`. This video data output has a delegate object that conforms to the `AVCaptureVideoDataOutputSampleBufferDelegate` protocol. This delegate will receive a message for each frame:

    func captureOutput(captureOutput: AVCaptureOutput!,
                       didOutputSampleBuffer: CMSampleBuffer!,
                       fromConnection: AVCaptureConnection!) {

We will use this to drive our image rendering. In our sample code, we have wrapped up the configuration, initialization, and delegate object into a simple interface called `CaptureBufferSource`. You can initialize it with a camera position (either front or back), and a callback, which, for each sample buffer, gets a callback with the buffer and the transform for that camera:

```swift
source = CaptureBufferSource(position: AVCaptureDevicePosition.Front) {
   (buffer, transform) in
   ...
}
```

We need to transform the image data from the camera. The pixel data from the camera is always in the same orientation, no matter how we turn the iPhone. In our case, we lock the UI in portrait orientation, and we want the image onscreen to align with the image the camera sees. For that, we need the back-facing camera's image to be rotated by -π/2. The front-facing camera needs to be both rotated by -π/2 and mirrored. We express this as a `CGAffineTransform`. Note that our transform would be different if the UI had a different orientation (e.g. landscape). Note also that this transformation is very cheap, because it is done inside the Core Image rendering pipeline.

Next, to convert a `CMSampleBuffer` into a `CIImage`, we first need to convert it into a `CVPixelBuffer`. We can write a convenience initializer that does this for us:

```swift
extension CIImage {
    convenience init(buffer: CMSampleBuffer) {
        self.init(CVPixelBuffer: CMSampleBufferGetImageBuffer(buffer))
    }
}
```

Now, we can process our image in three steps. First, we convert our `CMSampleBuffer` into a `CIImage`, and apply a transform so the image is rotated correctly. Next, we apply a `CIFilter` to get a new `CIImage` out. We use the style in [Florian's article](/issues/16-swift/functional-swift-apis/) for creating filters. In this case, we use a hue adjust filter, and pass in an angle that depends on time. Finally, we use our custom view defined in the previous section to render our `CIImage` using a `CIContext`. This flow is very simple, and looks like this:

```swift
source = CaptureBufferSource(position: AVCaptureDevicePosition.Front) {
  [unowned self] (buffer, transform) in
    let input = CIImage(buffer: buffer).imageByApplyingTransform(transform)
    let filter = hueAdjust(self.angleForCurrentTime)
    self.coreImageView?.image = filter(input)
}
```

When you run this, you might be surprised by the lack of CPU usage. The great thing about this setup is that all the hard work happens on the GPU. Even though we create a `CIImage`, apply a filter, and create a new `CIImage` out of it, the resulting image is a *promise*: it is not computed until it actually renders. A `CIImage` object can be many things under the hood: it can be pixel data on the GPU, it can be a description of how to create pixel data (for example, when using a generator filter), or it can be created directly from OpenGL textures.

Here's a video of the result:

<video controls="1">
  <source src="/images/issue-23/camera.m4v"></source>
</video>

## Getting Pixel Data from a Movie File

Another thing we can do is filter a movie through Core Image. Instead of camera frames, we now generate pixel buffers from each movie frame. We will take a slightly different approach here. While the camera pushed frames to us, we use a pull-driven approach for the movie: using a display link, we ask AVFoundation for a frame at a specific time.

A display link is an object that sends us messages every time a frame needs to be drawn, and sends this synchronously with the display's refresh rate. This is often used for [custom animations](/issues/12-animations/interactive-animations/), but can be used to play and manipulate video as well. The first thing we will do is create an `AVPlayer` and a video output:

```swift
player = AVPlayer(URL: url)
videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: pixelBufferDict)
player.currentItem.addOutput(videoOutput)
```

Then we set up our display link. Doing that is as simple as creating a `CADisplayLink` object and adding it to the run loop:

```swift
let displayLink = CADisplayLink(target: self, selector: "displayLinkDidRefresh:")
displayLink.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
```

Now, the only thing left to do is to fetch a video frame on each `displayLinkDidRefresh:` invocation. First, we take the current time and convert it into a timescale in terms of the item we're currently playing. Then we ask the `videoOutput` if there's a new pixel buffer available for the current time, and if there is one, we copy it over and call our callback method:

```swift
func displayLinkDidRefresh(link: CADisplayLink) {
    let itemTime = videoOutput.itemTimeForHostTime(CACurrentMediaTime())
    if videoOutput.hasNewPixelBufferForItemTime(itemTime) {
        let pixelBuffer = videoOutput.copyPixelBufferForItemTime(itemTime, itemTimeForDisplay: nil)
        consumer(pixelBuffer)
    }
}
```

The pixel buffer that we get from a video output is a `CVPixelBuffer`, which we can directly convert into a `CIImage`. Like in the sample above, we will filter this image. In this case, we'll combine multiple filters: we use a kaleidoscope effect, and then use gradient mask to combine the original image with the filtered image. The result is slightly funky:

<video controls="1">
  <source src="/images/issue-23/video.m4v"></source>
</video>

## Getting Creative with Filters

Everybody knows the popular photo effects. While we can apply these to video, too, Core Image can do much more.

The thing that Core Image calls a *filter* comes in different categories. Some of these are of the traditional type that take an input image and produce an output image. But others take two (or more) input images and combine them to generate the output image. Others again take no input images at all, but generate an image based on parameters.

By combining these various types, we can created unexpected effects.

### Combining Images

In our example, we use something like this:

![Combining filters](/images/issue-23/combining-filters.svg)

The example above pixelates a circular part of an image.

It’s possible to create interaction, too. We could use touch events to change to position of the generated circle.

The [Core Image Filter Reference](https://developer.apple.com/library/mac/documentation/GraphicsImaging/Reference/CoreImageFilterReference/index.html) lists all available filters by category. Note that some of these are only available on OS X.

The generators and gradient filters produce images without an input. They are rarely useful on their own, but can be very powerful when used as masks, such as with `CIBlendWithMask` in our example.

The composite operation and `CIBlendWithAlphaMask` and `CIBlendWithMask` allow combining two images into one.

<a name="cpuvsgpu"></a>
## CPU vs. GPU

Our article from Issue #3, [Getting Pixels onto the Screen](/issues/3-views/moving-pixels-onto-the-screen/), describes the *graphics stack* of both iOS and OS X. The important thing to note is the notion of the CPU vs. the GPU, and how data moves between the two.

When working on live video, we face performance challenges.

First, we need to be able to process all image data within the time we have for each frame. The 24 fps (frames per second) cat movie we are using in our samples gives us 41 ms (1/24 seconds) to decode, process, and render all 1 million pixels in each frame.

Second, we need to be able to get all these pixels from the CPU to the GPU. The bytes from the movie file that we read off disk will end up in the CPU's domain. But the data needs to be on the GPU in order to be visible on the display.

### Avoiding Roundtrips

One very fatal yet easily overseen problem happens when the code moves the image data back and forth between the CPU and GPU multiple times during the render pipeline. It is important to make sure that the pixel data moves in one direction only: from the CPU to the GPU. Even better is if the data stays on the GPU entirely.

If we want to render at 24 fps, we have 41 ms; if we render at the full 60 fps, we only have 16 ms. If we accidentally download a pixel buffer from the GPU to the CPU, and then upload it back to the GPU, we are moving 3.8 MB of data in each direction for a fullscreen iPhone 6 image. That's going to break our frame rate.

When we're using a CVPixelBuffer, we want a flow like this:

![Flow of image data](/images/issue-23/flow.svg)

The `CVPixelBuffer` is CPU based (see below). We wrap it with a `CIImage`. Building our filter chain does not move any data around; it simply builds a recipe. Once we draw the image, we're using a Core Image context based on the same EAGL context as the GLKView that will display the image. The EAGL context is GPU based. Note how we only cross the GPU-CPU boundary once. That's the crucial part.

### Work and Target

The Core Image context can be created in two ways: as a GPU context using an `EAGLContext` or as a CPU-based context.

This defines where Core Image will do its work — where pixel data will be processed. Independent of that, both GPU- and CPU-based contexts can render to the CPU using the `createCGImage(…)`, `render(_, toBitmap, …)` and `render(_, toCVPixelBuffer, …)`, methods, as well as related methods.

It's important to understand how this moves pixel data between the CPU and GPU, or keeps all data on either the CPU and GPU. Moving data across this boundary comes at a cost.

### Buffers and Images

In our sample, we are using a few different *buffers* and *images*. This can be a bit confusing. The reason for this is quite simply that different frameworks have different uses for these “images.” Here's a very quick overview to show which ones are CPU- and GPU-based, respectively:


| Class          | Description    |
|----------------|----------------|
| CIImage        | These can represent two things: image data or a recipe to generate image data. |
|                | The output of a CIFilter is very lightweight. It's just a description of how it is generated and does not contain any actual pixel data.
|                | If the output is image data, it can be either raw pixel `NSData`, a `CGImage`, a `CVPixelBuffer`, or an OpenGL texture. |
| CVImageBuffer  | This is an abstract superclass of `CVPixelBuffer` (CPU) and `CVOpenGLESTexture` (GPU). |
| CVPixelBuffer  | A Core Video pixel buffer is CPU based. |
| CMSampleBuffer | A Core Media sample buffer wraps either a `CMBlockBuffer` or a `CVImageBuffer`, in addition to metadata.
| CMBlockBuffer  | A Core Media block buffer is CPU based. |

Note that `CIImage` has quite a few convenience methods to, for example, load an image from JPEG data or a `UIImage` directly. Behind the scenes, these will use a `CGImage`-based `CIImage`.

## Conclusion

Core Image is a great tool for manipulating live video. When you have the proper setup, the performance is great — just make sure there are no roundtrips between the GPU and CPU. By using filters creatively, you can achieve very interesting effects that go way beyond a simple hue or sepia filter. All this code can be easily abstracted, and a solid understanding of where the different objects live (on the GPU or CPU) helps in getting the necessary performance.

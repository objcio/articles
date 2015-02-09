---
title: "Camera Capture on iOS"
category: "21"
date: "2015-02-10 09:00:00"
tags: article
author: "<a href=\"http://twitter.com/matteo\">Matteo Caldari</a>"
---

The iPhone has shipped with a camera since its first model. In the first SDKs, the only way to integrate the camera within an app was by using `UIImagePickerController`, but iOS 4 introduced the AVFoundation framework, which allowed more flexibility.

In this article, we'll see how image capture with AVFoundation works, how to control the camera, and the new features recently introduced in iOS 8.

## Overview

### AVFoundation vs. `UIImagePickerController`

`UIImagePickerController` provides a very simple way to take a picture. It supports all the basic features, such as switching to the front-facing camera, toggling the flash, tapping on an area to lock focus and exposure, and, on iOS8, adjusting the exposure just as in the system camera app.

However, when direct access to the camera is necessary, the AVFoundation framework allows full control, for example, for changing the hardware parameters programmatically, or manipulating the live preview.

### AVFoundation's Building Blocks

An image capture implemented with the AVFoundation framework is based on a few classes. These classes give access to the raw data coming from the camera device and can control its components.

- `AVCaptureDevice` is the interface to the hardware camera. It is used to control the hardware features such as the position of the lens, the exposure, and the flash.
- `AVCaptureDeviceInput` provides the data coming from the device.
- `AVCaptureOutput` is an abstract class describing the result of a capture session. There are three concrete subclasses of interest to still-image capture:
  - `AVCaptureStillImageOutput` is used to capture a still image.
  - `AVCaptureMetadataOutput` enables detection of faces and QR codes.
  - `AVCaptureVideoOutput` provides the raw frames for a live preview.
- `AVCaptureSession` manages the data flow between the inputs and the outputs, and generates runtime errors in case something goes wrong.
- The `AVCaptureVideoPreviewLayer` is a subclass of `CALayer`, and can be used to automatically display the live feed generated from the camera. It also has some utility methods for converting points from layer coordinates to those of the device. It looks like an output, but it's not. Additionally, it *owns* a session (the outputs are *owned by* a session).

## Setup

Let's start building the capture. First we need an `AVCaptureSession` object:

```
let session = AVCaptureSession()
```

Now we need a camera device input. On most iPhones and iPads, we can choose between the back camera and the front camera — aka the selfie camera. So first we have to iterate over all the devices that can provide video data (the microphone is also an `AVCaptureDevice`, so we'll skip it) and check for the `position` property:

```swift
let availableCameraDevices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
for device in availableCameraDevices as [AVCaptureDevice] {
  if device.position == .Back {
    backCameraDevice = device
  }
  else if device.position == .Front {
    frontCameraDevice = device
  }
}
```

Then, once we found the proper camera device, we can get the corresponding `AVCaptureDeviceInput` object. We'll set this as the session's input:

```swift
var error:NSError?
let possibleCameraInput: AnyObject? = AVCaptureDeviceInput.deviceInputWithDevice(backCameraDevice, error: &error)
if let backCameraInput = possibleCameraInput as? AVCaptureDeviceInput {
  if self.session.canAddInput(backCameraInput) {
    self.session.addInput(backCameraInput)
  }
}
```

Note that the first time the app is executed, the first call to  `AVCaptureDeviceInput.deviceInputWithDevice()` triggers a system dialog, asking the user to allow usage of the camera. This was introduced in some countries with iOS 7, and was extended to all regions with iOS 8. Until the user accepts the dialog, the camera input will send a stream of black frames.

A more appropriate way to handle the camera permissions is to first check the current status of the authorization, and in case it's still not determined, i.e. the user hasn't seen the dialog, to explicitly request it:

```swift
let authorizationStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
switch authorizationStatus {
case .NotDetermined:
  // permission dialog not yet presented, request authorization
  AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo,
    completionHandler: { (granted:Bool) -> Void in
    if granted {
      // go ahead
    }
    else {
      // user denied, nothing much to do
    }
  })
case .Authorized:
  // go ahead
case .Denied, .Restricted:
  // the user explicitly denied camera usage or is not allowed to access the camera devices
}
```

At this point, we have two ways to display the video stream that comes from the camera. The simplest is to create a view with an `AVCaptureVideoPreviewLayer` and attach it to the capture session:

```swift
previewLayer = AVCaptureVideoPreviewLayer.layerWithSession(session) as AVCaptureVideoPreviewLayer
previewLayer.frame = view.bounds
view.layer.addSublayer(previewLayer)
```

The `AVCaptureVideoPreviewLayer` will automatically display the output from the camera. It also comes in handy when we need to translate a tap on the camera preview to the coordinate system of the device, e.g. when tapping on an area to focus. We'll see the details later.

The second method is to capture the single frames from the output data stream and to manually display them in a view, using OpenGL. This is a bit more complicated, but necessary in case we want to manipulate or filter the live preview.
To get the data stream, we just create an `AVCaptureVideoDataOutput`, so when the camera is running, we get all the frames (except the ones that will be dropped if our processing is too slow) via the delegate method, `captureOutput(_:didOutputSampleBuffer:fromConnection:)`, and draw them in a `GLKView`. Without going too deep into the OpenGL framework, we could setup the `GLKView` like this:

```swift
glContext = EAGLContext(API: .OpenGLES2)
glView = GLKView(frame: viewFrame, context: glContext)
ciContext = CIContext(EAGLContext: glContext)
```

Now the `AVCaptureVideoOutput`:

```swift
videoOutput = AVCaptureVideoDataOutput()
videoOutput.setSampleBufferDelegate(self, queue: dispatch_queue_create("sample buffer delegate", DISPATCH_QUEUE_SERIAL))
if session.canAddOutput(self.videoOutput) {
  session.addOutput(self.videoOutput)
}
```

And the delegate method:

```swift
func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
  let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
  let image = CIImage(CVPixelBuffer: pixelBuffer)
  if glContext != EAGLContext.currentContext() {
    EAGLContext.setCurrentContext(glContext)
  }
  glView.bindDrawable()
  ciContext.drawImage(image, inRect:image.extent(), fromRect: image.extent())
  glView.display()
}
```

One caveat: the samples sent from the camera are rotated 90 degrees, because that's how the camera sensor is oriented. The `AVCaptureVideoPreviewLayer` handles this automatically, so in this case, we should apply a rotation transform to the `GLKView`.

We're almost done. The last component — the `AVCaptureStillImageOutput` — is actually the most important, as it allows us to capture a still image. This is just a matter of creating an instance and adding it to the session:

```swift
stillCameraOutput = AVCaptureStillImageOutput()
if self.session.canAddOutput(self.stillCameraOutput) {
  self.session.addOutput(self.stillCameraOutput)
}
```


### Configuration

Now that we have all the necessary objects in place, we should find the best configuration for our needs. Again, there are two ways to accomplish this.
The simplest — and the most recommended — is to use a session preset:

```swift
session.sessionPreset = AVCaptureSessionPresetPhoto
```

The `AVCaptureSessionPresetPhoto` selects the best configuration for the capture of a photo, i.e. it enables the maximum ISO and exposure duration ranges, the phase detection autofocus (TODO: link to camera article), and a full resolution, JPEG-compressed still image output.

However, if you need more control, the `AVCaptureDeviceFormat` class describes the parameters applicable to the device, such as still image resolution, video preview resolution, which autofocus system, ISO and exposure duration limits. Every device supports a set of formats, listed in the `AVCaptureDevice.formats` property, and the proper format can be set as the  `activeFormat` of the `AVCaptureDevice` (note that you cannot modify a format).

## Controlling the Camera

The camera built into iPhones and iPads has more or less the same controls as other cameras, with some exceptions: parameters such as focus, exposure duration (the analog of the shutter speed on DSLR cameras), and ISO sensitivity can be adjusted, but the lens aperture is fixed. Since iOS 8, we have access to full manual control of all the adjustments.

We'll look at the details later, but first, it's time to start the camera:

```swift
sessionQueue = dispatch_queue_create("com.example.camera.capture\_session", DISPATCH_QUEUE_SERIAL)
dispatch_async(sessionQueue) { () -> Void in
  self.session.startRunning()
}
```

All the actions and configurations done on the session or the camera device are blocking calls. For this reason, it's recommended to dispatch them to a background serial queue. Furthermore, the camera device must be locked before changing any of its parameters, and unlocked afterwards For example:

```swift
var error:NSError?
if currentDevice.lockForConfiguration(&error) {
  // locked successfully, go on with configuration
  // currentDevice.unlockForConfiguration()
}
else {
  // something went wrong, the device was probably already locked
}
```


### Focus

Focus on an iOS camera is achieved by moving the lens closer to, or further from, the sensor.

Autofocus is implemented with phase detection or contrast detection (TODO: link to the camera article). The latter, however, is available only for low-resolution, high-FPS video capture (slow motion).

The enum `AVCaptureFocusMode` describes the available focus modes:

- `Locked` means the lens is at a fixed position.
- `AutoFocus` means setting this will cause the camera to focus once automatically, and then return back to `Locked`.
- `ContinuousAutoFocus` means the camera will automatically refocus on the center of the frame when the scene changes.

Setting the desired focus mode must be done after acquiring a lock:

```swift
let focusMode:AVCaptureFocusMode = ...
if currentCameraDevice.isFocusModeSupported(focusMode) {
  ... // lock for configuration
  currentCameraDevice.focusMode = focusMode
  ... // unlock
  }
}
```

By default, the `AutoFocus` mode tries to get the center of the screen as the sharpest area, but it is possible to set another area by changing the "point of interest." This is a `CGPoint`, with values ranging from `{ 0.0 , 0.0 }`(top left) to `{ 1.0, 1.0 }` (bottom right), and `{ 0.5, 0.5 }` being the center of the frame.
Usually this can be implemented with a tap gesture recognizer on the video preview, and to help with translating the point from the coordinate of the view to the device's normalized coordinates, we can use  `AVVideoCaptureVideoPreviewLayer.captureDevicePointOfInterestForPoint()`:

```swift
var pointInPreview = focusTapGR.locationInView(focusTapGR.view)
var pointInCamera = previewLayer.captureDevicePointOfInterestForPoint(pointInPreview)
... // lock for configuration

// set the new point of interest:
currentCameraDevice.focusPointOfInterest = pointInCamera
// trigger auto-focus on the new point of interest
currentCameraDevice.focusMode = .AutoFocus

... // unlock
```

New in iOS 8 is the option to move the lens to a position from `0.0`, focusing near objects, to `1.0`, focusing far objects (although that doesn't mean "infinity"):

```swift
... // lock for configuration
var lensPosition:Float = ... // some float value between 0.0 and 1.0
currentCameraDevice.setFocusModeLockedWithLensPosition(lensPosition) {
  (timestamp:CMTime) -> Void in
  // timestamp of the first image buffer with the applied lens position
}
... // unlock
```

This means that the focus can be set with a `UISlider`, for example, which would be the equivalent of rotating the focusing ring on a DSLR. When focusing manually with these kinds of cameras, there is usually a visual aid that indicates the sharp areas. There is no such built-in mechanism in AVFoundation, but it could be interesting to display, for instance, a sort of "focus peaking" (TODO link to article or wikipedia). We won't go into details here, but focus peaking could be easily implemented by applying a threshold edge detect filter (with a custom `CIFilter` or [`GPUImageThresholdEdgeDetectionFilter`](https://github.com/BradLarson/GPUImage/blob/master/framework/Source/GPUImageThresholdEdgeDetectionFilter.h)), and overlaying it onto the live preview in the `AVCaptureAudioDataOutputSampleBufferDelegate.captureOutput(_:didOutputSampleBuffer:fromConnection:)` method seen above.

### Exposure

On iOS devices, the aperture of the lens is fixed (at f/2.2 for iPhones after 5s, and at f/2.4 for previous models), so only the exposure duration and the sensor sensibility can be tweaked to accomplish the most appropriate image brightness. As for the focus, we can have continuous auto exposure, one-time auto exposure on the point of interest, or manual exposure.
Other than specifying a point of interest, we can modify the auto exposure by setting a compensation, known as target bias, expressed in *f-stops*, whose values range between `minExposureTargetBias` and `maxExposureTargetBias`, with 0 being the default (no compensation):

```swift
var exposureBias:Float = ... // a value between minExposureTargetBias and maxExposureTargetBias
... // lock for configuration
currentDevice.setExposureTargetBias(exposureBias) { (time:CMTime) -> Void in
}
... // unlock
```

To use manual exposure, instead we can set the ISO and the duration. Both values must be in the ranges specified in the device's active format:

```swift
var activeFormat = currentDevice.activeFormat
var duration:CTime = ... // a value between activeFormat.minExposureDuration and activeFormat.maxExposureDuration or AVCaptureExposureDurationCurrent for no change
var iso:Float = ... // a value between activeFormat.minISO and activeFormat.maxISO or AVCaptureISOCurrent for no change
... // lock for configuration
currentDevice.setExposureModeCustomWithDuration(duration, ISO: iso) { (time:CMTime) -> Void in
}
... // unlock
```

How do we know that the picture is correctly exposed? We can observe the `exposureTargetOffset` property of the `AVCaptureDevice` object and check that it's around zero.

### White Balance

Digital cameras need to compensate for different types of lighting. This means that the sensor should increase the red component, for example, in case of a cold light, and the blue component in case of a warm light. On an iPhone camera, the proper compensation can be automatically determined by the device, but sometimes, as it happens with any camera, it gets tricked by the colors in the scene. Luckily, iOS 8 made manual controls available for the white balance as well.

The automatic modes work in the same way as the focus and exposure, but there's no point of interest; the whole image is considered. In manual mode, we can compensate for the temperature, expressed in Kelvin degrees. Lower values (around 3000) will look good in warm light, higher values (8000) with a blue sky, and the tint, from a minimum of -150 (shift to green) to a maximum of 150 (shift to magenta).

Temperature and tint will be used to calculate the proper RGB gain of the camera sensor, thus they have to be normalized for the device before they can be set.

This is the whole process:

```swift
var incandescentLightCompensation = 3_000
var tint = 0 // no shift
let temperatureAndTintValues = AVCaptureWhiteBalanceTemperatureAndTintValues(temperature: incandescentLightCompensation, tint: tint)
var deviceGains = currentCameraDevice.deviceWhiteBalanceGainsForTemperatureAndTintValues(temperatureAndTintValues)
... // lock for configuration
currentCameraDevice.setWhiteBalanceModeLockedWithDeviceWhiteBalanceGains(deviceGains) {
        (timestamp:CMTime) -> Void in
    }
  }
... // unlock
```

### Real-Time Face Detection

The `AVCaptureMetadataOutput` has the ability to detect two types of objects: faces and QR codes. Apparently [no one uses QR codes](http://picturesofpeoplescanningqrcodes.tumblr.com), so let's see how we can detect faces. We just need to catch the metadata objects the `AVCaptureMetadataOutput` is providing to its delegate:

```swift
var metadataOutput = AVCaptureMetadataOutput()
metadataOutput.setMetadataObjectsDelegate(self, queue: self.sessionQueue)
if session.canAddOutput(metadataOutput) {
  session.addOutput(metadataOutput)
}
metadataOutput.metadataObjectTypes = [AVMetadataObjectTypeFace]
```

```swift
func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
    for metadataObject in metadataObjects as [AVMetadataObject] {
      if metadataObject.type == AVMetadataObjectTypeFace {
        var transformedMetadataObject = previewLayer.transformedMetadataObjectForMetadataObject(metadataObject)
      }
    }
```

### Capturing a Still Image

Finally, we want to capture the high-resolution image, so we call the `captureStillImageAsynchronouslyFromConnection(connection, completionHandler)` method on the camera device. When the data is read, the completion handler will be called on an unspecified thread.

If the still image output was set up to use the JPEG codec, either via the session `.Photo` preset or via the device's output settings, the `sampleBuffer` returned contains the image's metadata, i.e. EXIF data and also the detected faces — if enabled in the `AVCaptureMetadataOutput`:

```swift
dispatch_async(sessionQueue) { () -> Void in

  let connection = self.stillCameraOutput.connectionWithMediaType(AVMediaTypeVideo)

  // update the video orientation to the device one
  connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIDevice.currentDevice().orientation.rawValue)!

  self.stillCameraOutput.captureStillImageAsynchronouslyFromConnection(connection) {
    (imageDataSampleBuffer, error) -> Void in

    if error == nil {

      // if the session preset .Photo is used, or if explicitly set in the device's outputSettings
      // we get the data already compressed as JPEG

      let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)

      // the sample buffer also contains the metadata, in case we want to modify it
      let metadata:NSDictionary = CMCopyDictionaryOfAttachments(nil, imageDataSampleBuffer, CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)).takeUnretainedValue()

      if let image = UIImage(data: imageData) {
        // save the image or do something interesting with it
        ...
      }
    }
    else {
      NSLog("error while capturing still image: \(error)")
    }
  }
}
```

It's nice to have a sort of visual feedback when the photo is being captured. To know when it starts and when it's finished, we can use KVO with the `isCapturingStillImage` property of the `AVCaptureStillImageOutput`.


#### Bracketed Capture

An interesting feature also introduced in iOS 8 is "bracketed capture," which means taking several photos in succession with different exposure settings. This can be useful when taking a picture in mixed light, for example, by configuring three different exposures with biases at −1, 0, +1, and then merging them with an HDR algorithm.

Here's how it looks in code:

```swift
dispatch_async(sessionQueue) { () -> Void in
  let connection = self.stillCameraOutput.connectionWithMediaType(AVMediaTypeVideo)
  connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIDevice.currentDevice().orientation.rawValue)!

  var settings = [-1.0, 0.0, 1.0].map {
    (bias:Float) -> AVCaptureAutoExposureBracketedStillImageSettings in

    AVCaptureAutoExposureBracketedStillImageSettings.autoExposureSettingsWithExposureTargetBias(bias)
  }

  var counter = settings.count

  self.stillCameraOutput.captureStillImageBracketAsynchronouslyFromConnection(connection, withSettingsArray: settings) {
    (sampleBuffer, settings, error) -> Void in

    ...
    // save the sampleBuffer(s)

    // when the counter reaches 0 the capture is complete
    counter--

  }
}
```

It looks quite similar to the single image capture, but the completion handler is called as many times as the number of elements in the settings array.


### Conclusion

We've seen in detail the basics of how taking a picture in an iPhone app could be implemented (hmm... what about [taking photos with an iPad](http://ipadtography.tumblr.com/)?). You can also check them in action in this [sample project](https://github.com/objcio/issue-21-camera-controls-demo). Finally, iOS 8 is allowing a more accurate capture, especially for power users, thus making the gap between iPhones and dedicated cameras a little bit narrower, at least in terms of manual controls. Anyway, not everybody would like to be using a complicated manual interface for the everyday photo, so use these features responsibly!

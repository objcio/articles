---
title:  Capturing Video on iOS
category: "23"
date: "2015-04-13 11:00:00"
tags: article
author:
  - name: Adriaan Stellingwerff
    url: https://twitter.com/astellingwerff

---

With processing power and camera hardware improving with every new release, using iPhones to capture video is getting more and more interesting. They’re small, light, and inconspicuous, and the quality gap with professional video cameras has been narrowing to the point where, in certain situations, an iPhone is a real alternative.
This article discusses the different options to configure a video capture pipeline and get the most out of the hardware.
A sample app with implementations of the different pipelines is available on [GitHub](https://github.com/objcio/VideoCaptureDemo).


## `UIImagePickerController`

By far the easiest way to integrate video capture in your app is by using `UIImagePickerController`. It’s a view controller that wraps a complete video capture pipeline and camera UI.

Before instantiating the camera, first check if video recording is supported on the device:

```objc
if ([UIImagePickerController
       isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
    NSArray *availableMediaTypes = [UIImagePickerController
      availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
    if ([availableMediaTypes containsObject:(NSString *)kUTTypeMovie]) {
        // Video recording is supported.
    }
}
```

Then create a `UIImagePickerController` object, and define a delegate to further process recorded videos (e.g. to save them to the camera roll) and respond to the user dismissing the camera:

```objc
UIImagePickerController *camera = [UIImagePickerController new];
camera.sourceType = UIImagePickerControllerSourceTypeCamera;
camera.mediaTypes = @[(NSString *)kUTTypeMovie];
camera.delegate = self;
```

That’s all the code you need for a fully functional video camera.

### Camera Configuration

`UIImagePickerController` does provide some additional configuration options.

A specific camera can be selected by setting the `cameraDevice` property. This takes a `UIImagePickerControllerCameraDevice` enum. By default, this is set to `UIImagePickerControllerCameraDeviceRear`, but it can also be set to `UIImagePickerControllerCameraDeviceFront`. Always check first to make sure the camera you want to set is actually available:

```objc
UIImagePickerController *camera = …
if ([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront]) {
    [camera setCameraDevice:UIImagePickerControllerCameraDeviceFront];
}
```

The `videoQuality` property gives some control over the quality of the recorded video. It allows you to set a specific encoding preset, which affects both the bitrate and the resolution of the video. There are six presets:

```objc
enum {
   UIImagePickerControllerQualityTypeHigh             = 0,
   UIImagePickerControllerQualityTypeMedium           = 1,  // default  value
   UIImagePickerControllerQualityTypeLow              = 2,
   UIImagePickerControllerQualityType640x480          = 3,
   UIImagePickerControllerQualityTypeIFrame1280x720   = 4,
   UIImagePickerControllerQualityTypeIFrame960x540    = 5
};
typedef NSUInteger  UIImagePickerControllerQualityType;
```
The first three are relative presets (low, medium, and high). The encoding configuration for these presets can be different for different devices, with high giving you the highest quality available for the selected camera. The other three are resolution-specific presets (640x480 VGA, 960x540 iFrame, and 1280x720 iFrame).

### Custom UI

As mentioned before, `UIImagePickerController` comes with a complete camera UI right out of the box. However, it is possible to customize the camera with your own controls by hiding the default controls and providing a custom view with the controls, which will be overlaid on top of the camera preview:

```objc
UIView *cameraOverlay = …
picker.showsCameraControls = NO;
picker.cameraOverlayView = cameraOverlay;
```

You then need to hook up the controls in your overlay to the control methods of the `UIImagePickerController` (e.g. `startVideoCapture` and `stopVideoCapture`).


## AVFoundation

If you want more control over the video capture process than `UIImagePickerController` provides, you will need to use AVFoundation.

The central AVFoundation class for video capture is `AVCaptureSession`. It coordinates the flow of data between audio and video inputs and outputs:

![AVCaptureSession setup](/images/issue-23/AVCaptureSession.svg)

To use a capture session, you instantiate it, add inputs and outputs, and start the flow of data from the connected inputs to the connected outputs:

```objc
AVCaptureSession *captureSession = [AVCaptureSession new];
AVCaptureDeviceInput *cameraDeviceInput = …
AVCaptureDeviceInput *micDeviceInput = …
AVCaptureMovieFileOutput *movieFileOutput = …
if ([captureSession canAddInput:cameraDeviceInput]) {
    [captureSession addInput:cameraDeviceInput];
}
if ([captureSession canAddInput:micDeviceInput]) {
    [captureSession addInput:micDeviceInput];
}
if ([captureSession canAddOutput:movieFileOutput]) {
    [captureSession addOutput:movieFileOutput];
}

[captureSession startRunning];
```

(For simplicity, dispatch queue-related code has been omitted from the above snippet. Because all calls to a capture session are blocking, it’s recommended to dispatch them to a background serial queue.)

A capture session can be further configured with a `sessionPreset`, which indicates the quality level of the output. There are 11 different presets:

```objc
NSString *const  AVCaptureSessionPresetPhoto;
NSString *const  AVCaptureSessionPresetHigh;
NSString *const  AVCaptureSessionPresetMedium;
NSString *const  AVCaptureSessionPresetLow;
NSString *const  AVCaptureSessionPreset352x288;
NSString *const  AVCaptureSessionPreset640x480;
NSString *const  AVCaptureSessionPreset1280x720;
NSString *const  AVCaptureSessionPreset1920x1080;
NSString *const  AVCaptureSessionPresetiFrame960x540;
NSString *const  AVCaptureSessionPresetiFrame1280x720;
NSString *const  AVCaptureSessionPresetInputPriority;
```
The first one is for high-resolution photo output.
The next nine are very similar to the `UIImagePickerControllerQualityType` options we saw for the `videoQuality` setting of `UIImagePickerController`, with the exception that there are a few additional presets available for a capture session.
The last one (`AVCaptureSessionPresetInputPriority`) indicates that the capture session does not control the audio and video output settings. Instead, the `activeFormat` of the connected capture device dictates the quality level at the outputs of the capture session. In the next section, we will look at devices and device formats in more detail.

### Inputs

The inputs for an `AVCaptureSession` are one or more `AVCaptureDevice` objects connected to the capture session through an `AVCaptureDeviceInput`.

We can use `[AVCaptureDevice devices]` to find the available capture devices. For an iPhone 6, they are:

```
(
    “<AVCaptureFigVideoDevice: 0x136514db0 [Back Camera][com.apple.avfoundation.avcapturedevice.built-in_video:0]>”,
    “<AVCaptureFigVideoDevice: 0x13660be80 [Front Camera][com.apple.avfoundation.avcapturedevice.built-in_video:1]>”,
    “<AVCaptureFigAudioDevice: 0x174265e80 [iPhone Microphone][com.apple.avfoundation.avcapturedevice.built-in_audio:0]>”
)
```

#### Video Input

To configure video input, create an `AVCaptureDeviceInput` object with the desired camera device and add it to the capture session:

```objc
AVCaptureSession *captureSession = …
AVCaptureDevice *cameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
NSError *error;
AVCaptureDeviceInput *cameraDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:cameraDevice error:&error];
if ([captureSession canAddInput:input]) {
    [captureSession addInput:cameraDeviceInput];
}
```

If any of the capture session presets discussed in the previous section are sufficient, that’s all you need to do. If they aren’t, because, for instance, you want to capture at high frame rates, you will need to configure a specific device format. A video capture device has a number of device formats, each with specific properties and capabilities. Below are a few examples (out of a total of 22 available formats) from the back-facing camera of an iPhone 6:

| Format | Resolution | FPS     | HRSI      | FOV    | VIS | Max Zoom  | Upscales | AF | ISO        | SS                | HDR |
|--------|------------|---------|-----------|--------|-----|----------|----------|----|------------|-------------------|-----|
| 420v   | 1280x720   | 5 - 240 | 1280x720  | 54.626 | YES |49.12 | 1.09     | 1  | 29.0 - 928 | 0.000003-0.200000 | NO  |
| 420f   | 1280x720   | 5 - 240 | 1280x720  | 54.626 | YES |49.12 | 1.09     | 1  | 29.0 - 928 | 0.000003-0.200000 | NO  |
| 420v   | 1920x1080  | 2 - 30  | 3264x1836 | 58.040 | YES | 95.62 | 1.55     | 2  | 29.0 - 464 | 0.000013-0.500000 | YES |
| 420f   | 1920x1080  | 2 - 30  | 3264x1836 | 58.040 | YES | 95.62 | 1.55     | 2  | 29.0 - 464 | 0.000013-0.500000 | YES |
| 420v   | 1920x1080  | 2 - 60  | 3264x1836 | 58.040 | YES | 95.62 | 1.55     | 2  | 29.0 - 464 | 0.000008-0.500000 | YES |
| 420f   | 1920x1080  | 2 - 60  | 3264x1836 | 58.040 | YES | 95.62 | 1.55     | 2  | 29.0 - 464 | 0.000008-0.500000 | YES |

- Format = pixel format
- FPS = the supported frame rate range
- HRSI = high-res still image dimensions
- FOV = field of view
- VIS = the format supports video stabilization
- Max Zoom = the max video zoom factor
- Upscales = the zoom factor at which digital upscaling is engaged
- AF = autofocus system (1 = contrast detect, 2 = phase detect)
- ISO = the supported ISO range
- SS = the supported exposure duration range
- HDR = supports video HDR

From the above formats, you can see that for recording 240 frames per second, we would need the first or the second format, depending on the desired pixel format, and that 240 frames per second isn’t available if we want to capture at a resolution of 1920x1080.

To configure a specific device format, you first call `lockForConfiguration:` to acquire exclusive access to the device’s configuration properties. Then you simply set the capture format on the capture device using `setActiveFormat:`. This will also automatically set the preset of your capture session to `AVCaptureSessionPresetInputPriority`.

Once you set the desired device format, you can configure specific settings on the capture device within the constraints of the device format.

Focus, exposure, and white balance for video capture are managed in the same way as for image capture described in [“Camera Capture on iOS”](http://www.objc.io/issue-21/camera-capture-on-ios.html) from Issue #21. Aside from those, there are some video-specific configuration options.

You set the **frame rate** using the capture device’s `activeVideoMinFrameDuration` and `activeVideoMaxFrameDuration` properties, where the frame duration is the inverse of the frame rate. To set the frame rate, first make sure the desired frame rate is supported by the device format, and then lock the capture device for configuration. To ensure a constant frame rate, set the minimum and maximum frame duration to the same value:

```objc
NSError *error;
CMTime frameDuration = CMTimeMake(1, 60);
NSArray *supportedFrameRateRanges = [device.activeFormat videoSupportedFrameRateRanges];
BOOL frameRateSupported = NO;
for (AVFrameRateRange *range in supportedFrameRateRanges) {
    if (CMTIME_COMPARE_INLINE(frameDuration, >=, range.minFrameDuration) &&
        CMTIME_COMPARE_INLINE(frameDuration, <=, range.maxFrameDuration)) {
        frameRateSupported = YES;
    }
}

if (frameRateSupported && [device lockForConfiguration:&error]) {
    [device setActiveVideoMaxFrameDuration:frameDuration];
    [device setActiveVideoMinFrameDuration:frameDuration];
    [device unlockForConfiguration];
}
```

**Video stabilization** was first introduced on iOS 6 and the iPhone 4S. With the iPhone 6, a second, more aggressive and fluid stabilization mode — called cinematic video stabilization — was added. This also changed the video stabilization API (which so far hasn’t been reflected in the class references; check the header files instead). Stabilization is not configured on the capture device, but on the `AVCaptureConnection`. As not all stabilization modes are supported by all device formats, the availability of a specific stabilization mode needs to be checked before it is applied:

```objc
AVCaptureDevice *device = ...;
AVCaptureConnection *connection = ...;

AVCaptureVideoStabilizationMode stabilizationMode = AVCaptureVideoStabilizationModeCinematic;
if ([device.activeFormat isVideoStabilizationModeSupported:stabilizationMode]) {
    [connection setPreferredVideoStabilizationMode:stabilizationMode];
}
```

Another new feature introduced with the iPhone 6 is **video HDR** (High Dynamic Range), which is “streaming high-dynamic-range video as opposed to the more traditional method of fusing a bracket of still images with differing EV values into a single high dynamic range photo.”[^1] It is built right into the sensor. There are two ways to configure video HDR: by directly enabling or disabling it through the capture device’s `videoHDREnabled` property, or by leaving it up to the system by using the `automaticallyAdjustsVideoHDREnabled` property.


[^1]: [Technical Note: New AV Foundation Camera Features for the iPhone 6 and iPhone 6 Plus](https://developer.apple.com/library/ios/technotes/tn2409/_index.html#//apple_ref/doc/uid/DTS40015038-CH1-OPTICAL_IMAGE_STABILIZATION)

#### Audio Input

The list of capture devices presented earlier only contained one audio device, which seems a bit strange given that an iPhone 6 has three microphones. The microphones are probably treated as one device because they are sometimes used together to optimize performance. For example, when recording video on an iPhone 5 or newer, the front and back microphones will be used together to provide directional noise reduction.[^2]

In most cases, the default microphone configurations will be the desired option. The back microphone will automatically be used with the rear-facing camera (with noise reduction using the front microphone), and the front microphone with the front-facing camera.

But it is possible to access and configure individual microphones, for example, to allow the user to record live commentary through the front-facing microphone while capturing a scene with the rear-facing camera. It is done through `AVAudioSession`.
To be able to reroute the audio, the audio session first needs to be set to a category that supports this. Then we need to iterate through the audio session’s input ports and through the port’s data sources to find the microphone we want:

```objc
// Configure the audio session
AVAudioSession *audioSession = [AVAudioSession sharedInstance];
[audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
[audioSession setActive:YES error:nil];

// Find the desired input port
NSArray* inputs = [audioSession availableInputs];
AVAudioSessionPortDescription *builtInMic = nil;
for (AVAudioSessionPortDescription* port in inputs) {
    if ([port.portType isEqualToString:AVAudioSessionPortBuiltInMic]) {
        builtInMic = port;
        break;
    }
}

// Find the desired microphone
for (AVAudioSessionDataSourceDescription* source in builtInMic.dataSources) {
    if ([source.orientation isEqual:AVAudioSessionOrientationFront]) {
        [builtInMic setPreferredDataSource:source error:nil];
        [audioSession setPreferredInput:builtInMic error:&error];
        break;
    }
}
```

In addition to setting up a non-default microphone configuration, you can also use the `AVAudioSession` to configure other audio settings, like the audio gain and sample rate.

[^2]: [Technical Q&A: AVAudioSession - Microphone Selection](https://developer.apple.com/library/ios/qa/qa1799/_index.html)

#### Permissions

One thing to keep in mind when accessing cameras and microphones is that you will need the user’s permission. iOS will do this once automatically when you create your first `AVCaptureDeviceInput` for audio or video, but it’s cleaner to do it yourself. You can then use the same code to alert users when the required permissions have not been granted. Trying to record video and audio when the user hasn’t given permission will result in black frames and silence.

### Outputs

With the inputs configured, we now focus our attention on the outputs of the capture session.

#### `AVCaptureMovieFileOutput`

The easiest option to write video to file is through an `AVCaptureMovieFileOutput` object. Adding it as an output to a capture session will let you write audio and video to a QuickTime file with a minimum amount of configuration:

```objc
AVCaptureMovieFileOutput *movieFileOutput = [AVCaptureMovieFileOutput new];
if([captureSession canAddOutput:movieFileOutput]){
    [captureSession addOutput:movieFileOutput];
}

// Start recording
NSURL *outputURL = …
[movieFileOutput startRecordingToOutputFileURL:outputURL recordingDelegate:self];
```

A recording delegate is required to receive callbacks when actual recording starts and stops. When recording is stopped, the output usually still has some data to write to file and will call the delegate when it’s done.

An `AVCaptureMovieFileOutput` object has a few other configuration options, such as stopping recording after a certain duration, when a certain file size is reached, or when the device is crossing a minimum disk space threshold. If you need more than that, e.g. for custom audio and video compression settings, or because you want to process the audio or video samples in some way before writing them to file, you will need something a little more elaborate.


#### `AVCaptureDataOutput` and `AVAssetWriter`

To have more control over the video and audio output from our capture session, you can use an `AVCaptureVideoDataOutput` object and an`AVCaptureAudioDataOutput` object instead of the `AVCaptureMovieFileOutput` discussed in the previous section.

These outputs will capture video and audio sample buffers respectively, and vend them to their delegates. The delegate can either apply some processing to the sample buffer (e.g. add a filter to the video) or pass them on unchanged. The sample buffers can then be written to file using an `AVAssetWriter` object:

![Using an AVAssetWriter](/images/issue-23/AVAssetWriter.svg)

You configure an asset writer by defining an output URL and file format and adding one or more inputs to receive sample buffers. Because the writer inputs will be receiving data from the capture session’s outputs in real time, we also need to set the `expectsMediaInRealTime` attribute to YES:

```objc
NSURL *url = …;
AVAssetWriter *assetWriter = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeMPEG4 error:nil];
AVAssetWriterInput *videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:nil];
videoInput.expectsMediaDataInRealTime = YES;
AVAssetWriterInput *audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:nil];
audioInput.expectsMediaDataInRealTime = YES;
if ([assetWriter canAddInput:videoInput]) {
    [assetWriter addInput:videoInput];
}
if ([assetWriter canAddInput:audioInput]) {
    [assetWriter addInput:audioInput];
}
```

(As with the capture session, it is recommended to dispatch asset writer calls to a background serial queue.)

In the code sample above, we passed in `nil` for the output settings of the asset writer inputs. This means that the appended samples will not be re-encoded. If we do want to re-encode the samples, we need to provide a dictionary with specific output settings. Keys for audio output settings are defined [here](https://developer.apple.com/library/prerelease/ios/documentation/AVFoundation/Reference/AVFoundationAudioSettings_Constants/index.html), and keys for video output settings are defined [here](https://developer.apple.com/library/prerelease/ios/documentation/AVFoundation/Reference/AVFoundation_Constants/index.html#//apple_ref/doc/constant_group/Video_Settings).

To make things a bit easier, both the `AVCaptureVideoDataOutput` class and the `AVCaptureAudioDataOutput` class have methods called `recommendedVideoSettingsForAssetWriterWithOutputFileType:` and `recommendedAudioSettingsForAssetWriterWithOutputFileType:`, respectively, that produce a fully populated dictionary of keys and values that are compatible with an asset writer. An easy way to define your own output settings is to start with this fully populated dictionary and adjust the properties you want to override. For example, increase the video bitrate to improve the quality of the video.

As an alternative, you can also use the `AVOutputSettingsAssistant` class to configure output settings dictionaries, but in my experience, using the above methods is preferable; the output settings they provide are more realistic for things like video bitrates. Additionally, the output assistant appears to have some other shortcomings, e.g. it doesn’t change the video bitrate when you change the expected video frame rate.


#### Live Preview

When using `AVFoundation` for video capture, we will have to provide a custom user interface.
A key component of any camera interface is the live preview. This is most easily implemented through an `AVCaptureVideoPreviewLayer` object added as a sublayer to the camera view:

```objc
AVCaptureSession *captureSession = ...;
AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
UIView *cameraView = ...;
previewLayer.frame = cameraView.bounds;
[cameraView.layer addSublayer:previewLayer];
```

If you need more control, e.g. to apply filters to the live preview, you will instead need to add an `AVCaptureVideoDataOutput` object to the capture session and display the frames onscreen using OpenGL, as discussed in [“Camera Capture on iOS”](http://www.objc.io/issue-21/camera-capture-on-ios.html) from Issue #21.


## Summary

There are a number of different ways to configure a pipeline for video capture on iOS — from the straightforward `UIImagePickerController`, to the more elaborate combination of  `AVCaptureSession` and `AVAssetWriter`. The correct option for your project will depend on your requirements, such as the desired video quality and compression, or the camera controls you want to expose to your app’s users.

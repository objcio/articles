---
title:  "Image Formats"
category: "21"
date: "2015-02-10 10:00:00"
tags: article
author: "<a href=\"https://twitter.com/ojmason\">Oliver Mason</a>"
---


Storing Data
------------

Storing text on a computer is easy. We have letters/characters as a fundamental unit, and there is a fairly straightforward mapping from a number to the character it encodes. This is not the case with graphical information. There are different ways to represent images, all with different pros and cons.

Text is also linear, and one-dimensional. Leaving aside the question of what the text direction is, all we need is to know what the next item in the sequence is.

Images are more complicated. For a start, they are two-dimensional, so we need to think about identifying where in our image a particular value is. Then, what is a value? Depending on what we want to capture, there are different ways of encoding graphical data. The most intuitive way these days seems to be as bitmap data, but that would not be very efficient if you wanted to deal with a collection of geometrical figures. A circle can be represented by three values (two coordinates and the radius), whereas a bitmap would not only be much larger in size, but also a rough approximation only.

This, then, leads us to the first distinction between different image formats: bitmaps versus vector images. While bitmaps store values in a grid, vector formats store instructions for drawing an image. This is obviously much more efficient when dealing with sparse images which can be reduced to a few geometric shapes. It does not really work well for photographic data. An architect designing a house would want to use a vector format. Vector formats do not have to be restricted to line drawings, as gradient or pattern fills can also be represented, so a realistic rendering of the resulting house could still be produced from a line drawing fairly efficiently.

A brick pattern would be more easily stored as a bitmap, so in this case we might have a hybrid format. An example for a very common hybrid format is [PostScript](https://en.wikipedia.org/wiki/PostScript) (or the nowadays more popular follow-up, [PDF](https://en.wikipedia.org/wiki/Portable_Document_Format)), which is basically a description language for drawing images. The target is mainly paper, but NeXT and Adobe developed [Display Postscript](http://en.wikipedia.org/wiki/Display_PostScript) as an instruction set for drawing on screens. PostScript is also capable of placing letters, and even bitmaps, which makes it a very versatile format.

Vector Images
-------------

A big advantage of vector formats is scaling. As the image is a set of drawing instructions, it is generally independent of size. If you want to enlarge your circle, you simply scale up the radius before drawing it. With a bitmap this is not easily possible. For a start, scaling to any factor that is not a multiple of two involves mangling the image, and the individual elements would simply increase in size, leading to a blocky image. As we do not know that the image is a circle, we cannot smooth the circular lines properly, and it will not look as good as a line drawn to scale. This is why vector images are very useful as graphical assets on devices with different pixel density. The same icon which looks alright on a pre-retina iOS device will not look as crisp when scaled up twice for display on a retina iPhone. Just like an iPhone-only app does not look as good when run in 2x mode on an iPad.

There is support for PDF assets in Xcode 6, but it seems to be rather sketchy at the moment, and still creates bitmap images at compile time on iOS. The most common vector image format is [SVG](https://en.wikipedia.org/wiki/Scalable_Vector_Graphics), and there is a library for rendering SVG files on iOS, [SVGKit](https://github.com/SVGKit/SVGKit).

Bitmaps
-------

Most image work deals with bitmaps; and from now on we will focus on how they can be handled. The first question is how to represent the two dimensions: and all formats use a sequence of rows for that, where pixels are stored in a horizontal sequence. Most formats then store rows sequentially, but that is by no means the only way: interleaved formats, where the rows are not in strict sequential order, are also common. Their advantage is that a better preview of the image can be shown when it is partially loaded. With increasing data transmission speeds that is now less of an issue than it was in the early days of the web.

The simplest way to represent bitmaps is as binary pixels: a pixel is either on, or off. We can then store 8 pixels in a byte, which is very efficient. However, we can only have two colors then, one for each state of a bit. While this does not sound very useful in the age of millions of colors, there is one application where this is still all that is needed: masking. Image masks can e.g. be used for transparency, and in iOS they are used in tab bar icons (even though the actual icons are not 1-pixel bitmaps).

For adding more colors there are two basic options: a look-up table, or actual color values. [GIF](https://en.wikipedia.org/wiki/GIF) images have a color table (or a palette) which can store up to 256 colors. The pixels in the actual image are then values into this look-up table. As a consequence, GIFs are limited to 256 colors only. This is fine for simple line drawings or diagrams with filled colors, but not really enough for photos, which would require a greater color depth. A further improvement are [PNG](https://en.wikipedia.org/wiki/Portable_Network_Graphics) files, which can either use a palette or separate channels, both supporting a variety of color depths. In a channel, the color components of each pixel (red, green, and blue, RGB, sometimes adding opacity/alpha, RGBA) are specified directly.

GIF and PNG are best for images which have large areas of identical color, as they use compression algorithms (mainly based on run-length encoding) to reduce the storage requirements. The compression is lossless, which means that the image quality is not affected by the process.

An example for an immage format that has lossy compression is [JPEG](https://en.wikipedia.org/wiki/JPEG). When creating JPEG images it is often possible to specify a parameter for quality/compression ratio, and here a better compression leads to a deterioration in the image quality. JPEG is not suited for images with sharp contrasts (such as line drawings), as the compression leads to artifacts around such areas. This can clearly be seen when a screenshot containing rendered text is saved in JPEG format: the resulting image will have stray pixels around the letters. This is not a problem with most photos, and photos are the main use case for JPEGs.

Summary
-------

To summarize: for scalability, vector formats (such as SVG) are best. Line drawings with sharp contrast and limited amount of colors work best for GIF of PNG (where PNG is the more powerful format), and for photos you should use JPEG. Of course, these are not unbreakable laws, but generally lead to the best results in terms of quality/image size.



Handling Image Data
-------------------

There are several classes for handling bitmap data in iOS: `UIImage` (UIKit), `CGImage` (Core Graphics) and `CIImage` (Core Image). There is also `NSData` for holding the actual data before creating one of those classes. Getting a `UIImage` is easy enough, using the `imageWithContentsOfFile:` method, and for other sources there are `imageWithCGImage:`, `imageWithCIImage:`, and `imageWithData:`. This seems somewhat superfluous, but this is partly caused by optimising aspects of image storage for different purposes across the different frameworks, and it is generally possible to easily convert between the different types.


Capturing an Image From the Camera
----------------------------------

To get an image from the camera, we need to set up an `AVCaptureStillImageOutput` object. We can then use the `captureStillImageAsynchronouslyFromConnection:completionHandler:` method. Its handler is a block which is called with a `CMSampleBufferRef` parameter. This we can convert into an `NSData` object with `AVCaptureStillImageOutput`'s `jpegStillImageNSDataRepresentation:` class method, and then, in turn, we use the method `imageWithData:` (mentioned above) to get to a `UIImage`. There are a number of parameters that can be tweaked in the process, such as exposure control or the focus setting, low light boost, flash, and even the ISO setting (from iOS 8 only). The settings are applied to an `AVCaptureDevice`, which represents the camera on devices which have got one.

Manipulating Images Programmatically
------------------------------------

A straightforward way to manipulate images is to use UIKit's `UIGraphicsBeginImageContext` function. You can then draw in the current graphics context, and also include images directly. In one of my own apps, Stereogram, I use this to place two square images next to each other, and add a region above them with two dots for focusing. The code for that is as follows:

```objc
-(UIImage*)composeStereogramLeft:(UIImage *)leftImage right:(UIImage *)rightImage
{
    float w = leftImage.size.width;
    float h = leftImage.size.height;
    UIGraphicsBeginImageContext(CGSizeMake(w * 2.0, h + 32.0));
    [leftImage drawAtPoint:CGPointMake(0.0, 32.0)];
    [rightImage drawAtPoint:CGPointMake(w, 32.0)];
    float leftCircleX = (w / 2.0) - 8.0;
    float rightCircleX = leftCircleX + w;
    float circleY = 8.0;
    [[UIColor blackColor] setFill];
    UIRectFill(CGRectMake(0.0, 0.0, w * 2.0, 32.0));

    [[UIColor whiteColor] setFill];
    CGRect leftRect = CGRectMake(leftCircleX, circleY, 16.0, 16.0);
    CGRect rightRect = CGRectMake(rightCircleX, circleY, 16.0, 16.0);
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:leftRect];
    [path appendPath:[UIBezierPath bezierPathWithOvalInRect:rightRect]];
     [path fill];
    UIImage *savedImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return savedImg;
}
```

After placing the images on the canvas and adding two filled circles, we can turn the graphics context into a `UIImage` with a single method call. The output of that method looks as follows:

![Stereogram output](/images/issue-21/stereogram-output.jpg)

It is composed of the two photos taken from slightly different camera positions, and a black strip with two centered white dots to aid the viewing process.

It is a bit more complex if we want to mess with the actual pixel values. If we don't want to have two photos next two each other as a sterogram, but instead want a so-called anaglyph (a red/green image that you use colored 3D glasses to look at), we have to create a context with `CGBitmapContextCreate`, which includes a color space (such as RGB). We can then iterate over the bitmaps (left and right photos), and get at the individual color channel values. For example, we keep the green and blue values of one image as they were, and merge in the green and blue values of the other photo into the red value:

```objc
UInt8 *rightPtr = rightBitmap;
UInt8 *leftPtr = leftBitmap;
UInt8 r1, g1, b1;
UInt8 r2, g2, b2;
UInt8 ra, ga, ba;

for (NSUInteger idx = 0; idx < bitmapByteCount; idx += 4) {
    r1 = rightPtr[0]; g1 = rightPtr[1]; b1 = rightPtr[2];
    r2 = leftPtr[0]; g2 = leftPtr[1]; b2 = leftPtr[2];

    // r1/g1/b1 is the right hand side photo, which is merged in
    // r2/g2/b2 is the left hand side photo which the other is merged into
    // ra/ga/ba is the merged pixel

    ra = 0.7 * g1 + 0.3 * b1;
    ga = b2;
    ba = b2;

    leftPtr[0] = ra;
    leftPtr[1] = ga;
    leftPtr[2] = ba;
    rightPtr += 4; // move to the next pixel (4 bytes, includes alpha value)
    leftPtr += 4;
}
CGImageRef composedImage = CGBitmapContextCreateImage(_leftContext);
UIImage *retval = [UIImage imageWithCGImage:composedImage];
CGImageRelease(composedImage);
return retval;
```

With this method we have full access to the actual pixels, and can do with them whatever we like. It is worth, however, checking whether there are already filters available via [Core Image](/issue-21/core-image-intro.html), as they will be much easier to use and generally more optimized than any processing of individual pixel values. [Learn more about anaglyphs](http://www.3dtv.at/knowhow/anaglyphcomparison_en.aspx). The function listed above implements the Optimized Anaglyphs method on that page.


Metadata
--------

The standard format for storing information about an image is [Exif](https://en.wikipedia.org/wiki/Exchangeable_image_file_format) ("Exchangable image file format"). With photos this generally captures date and time, shutter speed and aperture, but also GPS coordinates if available. It is a tag-based system, based on [TIFF](https://en.wikipedia.org/wiki/Tagged_Image_File_Format) (tagged image file format). It has a lot of faults, but as it's the de facto standard, there isn't really a better alternative. As is often the case, there are other methods available which are better designed, but not supported by the cameras we all use.

Under iOS it is possible to access the Exif information using `CGImageSourceCopyPropertiesAtIndex`. This returns a dictionary containing all the relevant information. However, do not rely on any information being attached. Due to the complexities of vendor-specific extensions to the convention (it's not a proper standard), the data is often missing or corrupted, especially when the image has passed through a number of different applications (such as image editors etc). Usually the information is also stripped when an image is uploaded to a webserver: some of it can be sensitive, for example GPS data. For privacy reasons this is often removed. Apparently the NSA is harvesting Exif data in their [XKeyscore program](https://en.wikipedia.org/wiki/XKeyscore).


Summary
-------

Handling images can be a fairly complex issue. Image processing has been around for some time, so there are many different frameworks concerned with different aspects of it. Sometimes you have to dig down into C function calls, with the associated manual memory management. Then there are many different sources for images, and they can all handle certain edge cases differently. The biggest problem on iOS, however, is memory: as cameras and screen resolutions get better, images grow in size. The iPhone 5s has got an 8 megapixel camera; if each pixel is stored in 4 bytes (one each for the three color channels plus one for opacity), we have 32 MB. Add a few working copies or previews of the image, and we quickly run into trouble when handling multiple images or slideshows. Writing to the file system is also not very fast, so there are a lot of optimizations necessary to ensure your iOS app runs smoothly.

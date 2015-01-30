---
layout: post
title:  "GPU-Accelerated Machine Vision Operations"
category: "21"
date: "2015-02-09 12:00:00"
author: "<a href=\"https://twitter.com/bradlarson\">Brad Larson</a>"
tags: article
---


While the proliferation of cameras attached to mobile computers has been a boon for photography, there is much more that this can enable. Beyond simply capturing the outside world, the right software running on ever more powerful hardware can allow these computers to understand the things their cameras see. 

This small bit of understanding can enable some truly powerful applications, such as barcode scanning, document recognition and imaging, translation of written words, realtime image stabilization, and augmented reality. As processing power, camera fidelity, and algorithms advance, this machine vision will be able to solve even more important problems.

Many people regard machine vision as a complex discipline, far outside the reach of everyday programmers. I don't believe that's the case. I created an open source framework called [GPUImage](https://github.com/BradLarson/GPUImage) in large part because I wanted to explore high-performance machine vision and make it more accessible.

GPUs are ideally suited to operate on images and video because they are tuned to work on large collections of data in parallel, such as the pixels in an image or video frame. Depending on the operation, GPUs can process images hundreds or even thousands of times faster than CPUs can.

One of the things I learned while working on GPUImage is how even seemingly complex image processing operations can be built from smaller, simpler ones. I'd like to break down the components of some common machine vision processes, and show how these processes can be accelerated to run on modern GPUs.

Every operation analyzed here has a full implementation within GPUImage, and you can try them yourself by grabbing the project and building the FilterShowcase sample application either for Mac or iOS.

## Sobel edge detection

The first operation I'll describe may actually be used more frequently for cosmetic image effects than machine vision, but it's a good place to start. Sobel edge detection<sup>1</sup> is a process where edges (sharp transitions from light to dark, or vice versa) are found within an image. The strength of an edge around a pixel is reflected in how bright that pixel is in the processed image.

For example, let's see a scene before and after Sobel edge detection:

<img src="http://sunsetlakesoftware.com/sites/default/files/Objcio/MV-Chair.png" style="width:240px" alt="Original image"/>
<img src="http://sunsetlakesoftware.com/sites/default/files/Objcio/MV-Sobel.png" style="width:240px" alt="Sobel edge detection image"/>

As I mentioned, this is often used for visual effects. If the colors of the above are inverted, with strongest edges represented in black instead of white, we get an image that resembles a pencil sketch:

<img src="http://sunsetlakesoftware.com/sites/default/files/Objcio/MV-Sketch.png" style="width:240px" alt="Sketch filtered image"/>

So how are these edges calculated? The first step in this process is a reduction of a color image to a luminance (grayscale) image. Janie Clayton explains how this is calculated in a fragment shader within [her article](TODO: link to Janie's article), but basically the red, green, and blue components of each pixel are weighted and summed to arrive at a single value for how bright that pixel is.

Some video sources and cameras provide YUV-format images, rather than RGB. The YUV color format splits luminance information (Y) from chrominance (UV), so for inputs like that a color conversion step can be avoided. The luminance part of the image can be used directly.

Once an image is reduced to its luminance, the edge strength near a pixel is calculated by looking at a 3x3 array of neighboring pixels. An image processing calculation performed over a block of pixels involves what is called a convolution kernel. Convolution kernels consist of a matrix of weights that are multiplied with the values of the pixels surrounding a central pixel, with the sum of those weighted values determining the final pixel value. 

These kernels are applied once per pixel, across the entire image. The order in which pixels are processed doesn't matter, so a convolution across an image is an easy operation to parallelize. As a result, this can be performed 

For example, this is the horizontal kernel of the Sobel operator:

<table border="1" width="125">
  <tr>
    <td>-1</td><td>0</td><td>+1</td>
  </tr>
  <tr>
    <td>-2</td><td>0</td><td>+2</td>
  </tr>
  <tr>
    <td>-1</td><td>0</td><td>+1</td>
  </tr>
</table>

To apply this to a pixel, the luminance is read from each surrounding pixel. If the input image has been converted to grayscale, this can be sampled from any of the red, green, or blue color channels. The luminance of a particular surrounding pixel is multiplied by the corresponding weight from the above matrix and added to the total.

The Sobel operator has two stages, the horizontal kernel being the first. A vertical kernel is applied at the same time, with the following matrix of weights:

<table border="1" width="125">
  <tr>
    <td>-1</td><td>-2</td><td>-1</td>
  </tr>
  <tr>
    <td>0</td><td>0</td><td>0</td>
  </tr>
  <tr>
    <td>+1</td><td>+2</td><td>+1</td>
  </tr>
</table>

The final weighted sum from each operator is tallied, and the square root of the sums of their squares obtained. That combined value is then used as the luminance for the final output image. Sharp transitions from light to dark (or vice versa) become bright pixels in the result, due to the kernels emphasizing differences between pixels on either side of the center.

There are slight variations to Sobel edge detection, such as Prewitt edge detection<sup>2</sup>, that use different weights for the horizontal and vertical kernels, but rely on the same basic process.

As an example for how this can be implemented in code, the following is a fragment shader that performs Sobel edge detection. As described in [Janie's article](TODO: link to Janie's article), fragment shaders are C-like programs run once per pixel on a programmable GPU.

```glsl
precision mediump float;

varying vec2 textureCoordinate;
varying vec2 leftTextureCoordinate;
varying vec2 rightTextureCoordinate;

varying vec2 topTextureCoordinate;
varying vec2 topLeftTextureCoordinate;
varying vec2 topRightTextureCoordinate;

varying vec2 bottomTextureCoordinate;
varying vec2 bottomLeftTextureCoordinate;
varying vec2 bottomRightTextureCoordinate;

uniform sampler2D inputImageTexture;
uniform float edgeStrength;

void main()
{
   float bottomLeftIntensity = texture2D(inputImageTexture, bottomLeftTextureCoordinate).r;
   float topRightIntensity = texture2D(inputImageTexture, topRightTextureCoordinate).r;
   float topLeftIntensity = texture2D(inputImageTexture, topLeftTextureCoordinate).r;
   float bottomRightIntensity = texture2D(inputImageTexture, bottomRightTextureCoordinate).r;
   float leftIntensity = texture2D(inputImageTexture, leftTextureCoordinate).r;
   float rightIntensity = texture2D(inputImageTexture, rightTextureCoordinate).r;
   float bottomIntensity = texture2D(inputImageTexture, bottomTextureCoordinate).r;
   float topIntensity = texture2D(inputImageTexture, topTextureCoordinate).r;
   float h = -topLeftIntensity - 2.0 * topIntensity - topRightIntensity + bottomLeftIntensity + 2.0 * bottomIntensity + bottomRightIntensity;
   float v = -bottomLeftIntensity - 2.0 * leftIntensity - topLeftIntensity + bottomRightIntensity + 2.0 * rightIntensity + topRightIntensity;
   
   float mag = length(vec2(h, v)) * edgeStrength;
   
   gl_FragColor = vec4(vec3(mag), 1.0);
}
```

## Canny edge detection

Sobel edge detection can give you a good visual measure of edge strength in a scene, but it doesn't provide a yes/no indication of whether a pixel lies on an edge or not. 

For such a decision, you could apply a threshold of some sort, where pixels above a certain edge strength were considered to be part of an edge. However, this isn't ideal, because it tends to produce edges that are many pixels wide and choosing an appropriate threshold can vary with the contents of an image.

A more involved form of edge detection, called Canny edge detection<sup>3</sup>, might be what you want here. Canny edge detection can produce single-pixel-wide connected edges of objects in a scene:

<img src="http://sunsetlakesoftware.com/sites/default/files/Objcio/MV-Canny.png" style="width:240px" alt="Canny edge detection image"/>

The Canny edge detection process consists of a sequence of steps:

- // First pass: convert image to luminance

- // Second pass: apply a variable Gaussian blur

- // Third pass: run the Sobel edge detection, with calculated gradient directions, on this blurred image

- // Fourth pass: apply non-maximum suppression    

- // Fifth pass: include weak pixels to complete edges



## Harris corner detection

- First pass: reduce to luminance and take the derivative of the luminance texture (GPUImageXYDerivativeFilter)

- Second pass: blur the derivative (GPUImageGaussianBlurFilter)

- Third pass: apply the Harris corner detection calculation

- Mention FAST corner detection

## Hough transform line detection

- Canny edge detection

- Extract the white points and draw representative lines in parallel coordinate space

- Apply non-maximum suppression


- potential for use in detecting barcodes from any orientation
	-The challenge this presents to blind users
- Document edge recognition



## References:

<sup>1</sup> Sobel, I., An Isotropic 3x3 Gradient Operator, Machine Vision for Three-Dimensional Scenes, Academic Press, 1990.

<sup>2</sup> Prewitt, J.M.S. Object Enhancement and Extraction, Picture processing and Psychopictorics, Academic Press, 1970.

<sup>3</sup> Canny, J., A Computational Approach To Edge Detection, IEEE Trans. Pattern Analysis and Machine Intelligence, 8(6):679–698, 1986.

<sup>4</sup> A. Ensor, S. Hall. GPU-based Image Analysis on Mobile Devices. Proceedings of Image and Vision Computing New Zealand 2011.

<sup>5</sup> C. Harris and M. Stephens. A Combined Corner and Edge Detector. Proc. Alvey Vision Conf., Univ. Manchester, pp. 147-151, 1988.

<sup>6</sup> J. Shi and C. Tomasi. Good features to track. Proceedings of the IEEE Conference on Computer Vision and Pattern Recognition, pages 593-600, June 1994.

<sup>7</sup> Alison Noble, "Descriptions of Image Surfaces", PhD thesis, Department of Engineering Science, Oxford University 1989, p45.  

<sup>8</sup> M. Dubská, J. Havel, and A. Herout. [Real-Time Detection of Lines using Parallel Coordinates and OpenGL](http://medusa.fit.vutbr.cz/public/data/papers/2011-SCCG-Dubska-Real-Time-Line-Detection-Using-PC-and-OpenGL.pdf). Proceedings of SCCG 2011, Bratislava, SK, p. 7.

<sup>9</sup> M. Dubská, J. Havel, and A. Herout. [PClines — Line detection using parallel coordinates](http://medusa.fit.vutbr.cz/public/data/papers/2011-CVPR-Dubska-PClines.pdf). 2011 IEEE Conference on Computer Vision and Pattern Recognition (CVPR), p. 1489- 1494.

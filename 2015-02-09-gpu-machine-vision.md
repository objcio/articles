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

As an example for how this can be implemented in code, the following is an OpenGL ES fragment shader that performs Sobel edge detection. As described in [Janie's article](TODO: link to Janie's article), fragment shaders are C-like programs that run once per pixel on a programmable GPU.

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
   float mag = length(vec2(h, v));
   
   gl_FragColor = vec4(vec3(mag), 1.0);
}
```

The above shader has manual names for the pixels around the center one, passed in from a custom vertex shader, due to an optimization to reduce dependent texture reads on mobile devices. After these named pixels are sampled in a 3x3 grid, the horizontal and vertical Sobel kernels are applied using hand-coded calculations. The 0-weight entries are left out in order to simplify these calculations. The GLSL length() function calculates a Pythagorean hypotenuse between the results of the horizontal and vertical kernels. That magnitude value is then copied into the red, green, and blue channels of the output pixel to produce a grayscale indication of edge strength.

## Canny edge detection

Sobel edge detection can give you a good visual measure of edge strength in a scene, but it doesn't provide a yes/no indication of whether a pixel lies on an edge or not. For such a decision, you could apply a threshold of some sort, where pixels above a certain edge strength were considered to be part of an edge. However, this isn't ideal, because it tends to produce edges that are many pixels wide and choosing an appropriate threshold can vary with the contents of an image.

A more involved form of edge detection, called Canny edge detection<sup>3</sup>, might be what you want here. Canny edge detection can produce connected, single-pixel-wide edges of objects in a scene:

<img src="http://sunsetlakesoftware.com/sites/default/files/Objcio/MV-Canny.png" style="width:240px" alt="Canny edge detection image"/>

The Canny edge detection process consists of a sequence of steps. First, like with Sobel edge detection (and the other techniques we'll discuss), the image needs to be converted to luminance before edge detection is applied to it. Once a grayscale luminance image has been obtained, a slight [Gaussian blur](http://www.sunsetlakesoftware.com/2013/10/21/optimizing-gaussian-blurs-mobile-gpu) is used to reduce the effect of sensor noise on the edges being detected.

Once the image has been prepared, the edge detection can be performed. The specific GPU-accelerated process used here was originally described by Ensor and Hall in "GPU-based Image Analysis on Mobile Devices"<sup>4</sup>.

First, both the edge strength at a given pixel and the direction of the edge gradient is determined. The edge gradient is the direction in which the greatest change in luminance is occurring. This is perpendicular to the direction the edge itself is running. 

To find this, we use the Sobel kernel described in the previous section. The magnitude of the combined horizontal and vertical results gives the edge gradient strength, which is encoded in the red component of the output pixel. The horizontal and vertical Sobel results are then clamped to one of eight directions (corresponding to the eight pixels surrounding the central pixel) and the X component of that direction is encoded in the green component of the pixel. The Y component is placed into the blue component.

The shader used for this looks like the Sobel edge detection one above, only with the final calculation replaced with this code:

```glsl
	vec2 gradientDirection;
	gradientDirection.x = -bottomLeftIntensity - 2.0 * leftIntensity - topLeftIntensity + bottomRightIntensity + 2.0 * rightIntensity + topRightIntensity;
	gradientDirection.y = -topLeftIntensity - 2.0 * topIntensity - topRightIntensity + bottomLeftIntensity + 2.0 * bottomIntensity + bottomRightIntensity;

	float gradientMagnitude = length(gradientDirection);
	vec2 normalizedDirection = normalize(gradientDirection);
	normalizedDirection = sign(normalizedDirection) * floor(abs(normalizedDirection) + 0.617316); // Offset by 1-sin(pi/8) to set to 0 if near axis, 1 if away
	normalizedDirection = (normalizedDirection + 1.0) * 0.5; // Place -1.0 - 1.0 within 0 - 1.0

	gl_FragColor = vec4(gradientMagnitude, normalizedDirection.x, normalizedDirection.y, 1.0);
```

To refine the Canny edges to be a single pixel wide, only the strongest parts of the edge are kept. For that, we need to find the local maximum of the edge gradient at each slice along its width. 

This is where the gradient direction we calculated in the last step comes into play. For each pixel, we look at the nearest neighboring pixels both forwards and backwards along this length, and compare their calculated gradient strength (edge intensity). If the current pixel's gradient strength is greater than those of the ones forward and backward along the gradient, we keep that pixel. If the strength is less than either of the neighboring pixels, we reject that pixel and turn it to black.

A shader to do this looks like the following:

```glsl
precision mediump float;

varying highp vec2 textureCoordinate;

uniform sampler2D inputImageTexture;
uniform highp float texelWidth; 
uniform highp float texelHeight; 
uniform mediump float upperThreshold; 
uniform mediump float lowerThreshold; 

void main()
{
    vec3 currentGradientAndDirection = texture2D(inputImageTexture, textureCoordinate).rgb;
    vec2 gradientDirection = ((currentGradientAndDirection.gb * 2.0) - 1.0) * vec2(texelWidth, texelHeight);
    
    float firstSampledGradientMagnitude = texture2D(inputImageTexture, textureCoordinate + gradientDirection).r;
    float secondSampledGradientMagnitude = texture2D(inputImageTexture, textureCoordinate - gradientDirection).r;
    
    float multiplier = step(firstSampledGradientMagnitude, currentGradientAndDirection.r);
    multiplier = multiplier * step(secondSampledGradientMagnitude, currentGradientAndDirection.r);
    
    float thresholdCompliance = smoothstep(lowerThreshold, upperThreshold, currentGradientAndDirection.r);
    multiplier = multiplier * thresholdCompliance;
    
    gl_FragColor = vec4(multiplier, multiplier, multiplier, 1.0);
}
```

where texelWidth and texelHeight are the distances between neighboring pixels in the input texture, and lowerThreshold and upperThreshold set limits on the range of edge strengths we want to examine in this.

As a last step in the Canny edge detection process, pixel gaps in the edges are filled in to complete edges that might have had a few points failing the threshold or non-maximum suppression tests. This cleans up the edges and helps to make them continuous.

This last step looks at all the pixels around a central pixel. If the center was a strong pixel from the previous non-maximum suppression step, it remains a white pixel. If it was a completely suppressed pixel, it stays as a black pixel. For middling grey pixels, the neighborhood around them is evaluated. If they are touched by more than one white pixel, they become a white pixel. If not, they go to black. This fills in the gaps in detected edges.

As you can tell, the Canny edge detection process is much more involved than Sobel edge detection, but it can yield nice, clean lines tracing around the edges of objects. This gives a good starting point for line detection, contour detection, or other image analysis, and can also be used to produce some interesting aesthetic effects.

## Harris corner detection

While the previous edge detection techniques can extract some information about an image, the result is an image with visual clues about the locations of edges, not higher-level information about what is present in a scene. For that, we need algorithms that process the pixels within a scene and return more descriptive information about what is shown.

A popular starting point for object detection and matching is feature detection. Features are points of interest in a scene, locations that can be used to uniquely identify structure or objects. Corners are commonly used as features, due to the information contained in the pattern of abrupt changes in lighting and / or color around a corner.

One technique for detecting corners was proposed by Harris and Stephens in "A Combined Corner and Edge Detector"<sup>5</sup>. This so-called Harris corner detector uses a multi-step process to identify corners within scenes.

As with the other processes we've talked about, the image is first reduced to luminance. The X and Y gradients around a pixel are determined using a Sobel, Prewitt, or related kernel, but they aren't combined to yield a total edge magnitude. Instead, the X gradient strength is passed along in the red color component, the Y gradient strength in the green, and the product of the X and Y  gradient strengths in the blue component.

A Gaussian blur is then applied to the result of that calculation. The red, green, and blue components are extracted from that blurred image and a calculation performed from them to determine the likelihood a pixel is a corner point. The equation for this is the following:

R = I<sub>x</sub><sup>2</sup> * I<sub>y</sub><sup>2</sup> - I<sub>xy</sub> * I<sub>xy</sub> - k * (I<sub>x</sub><sup>2</sup> + I<sub>y</sub><sup>2</sup>)<sup>2</sup>

<img src="http://sunsetlakesoftware.com/sites/default/files/Objcio/MV-HarrisEquation.png" alt="R = Ix^2 * Iy^2 - Ixy * Ixy - k * (Ix^2 + Iy^2)^2"/>

where I<sub>x</sub> is the gradient intensity in the X direction, I<sub>y</sub> the gradient intensity in Y,  I<sub>xy</sub> the product of these intensities 

drawn from [this question on the Signal Processing Stack Exchange site](http://dsp.stackexchange.com/questions/401/how-to-detect-corners-in-a-binary-images-with-opengl).





<img src="http://sunsetlakesoftware.com/sites/default/files/Objcio/MV-HarrisSquares.png" alt="Harris corner detector test image"/>

<img src="http://sunsetlakesoftware.com/sites/default/files/Objcio/MV-HarrisCornerness.png" alt="Harris cornerness intermediate image"/>

<img src="http://sunsetlakesoftware.com/sites/default/files/Objcio/MV-HarrisCorners.png" alt="Harris corners"/>

- First pass: reduce to luminance and take the derivative of the luminance texture (GPUImageXYDerivativeFilter)

- Second pass: blur the derivative (GPUImageGaussianBlurFilter)

- Third pass: apply the Harris corner detection calculation

The Harris corner detector is but one means of finding corners within a scene. Edward Rosten's FAST corner detector, as described in "Machine learning for high-speed corner detection"<sup>8</sup>, a higher-performance corner detector that may also outpace the Harris detector for GPU-bound feature detection.

## Hough transform line detection

- Canny edge detection

- Extract the white points and draw representative lines in parallel coordinate space

- Apply non-maximum suppression


- potential for use in detecting barcodes from any orientation
	-The challenge this presents to blind users
- Document edge recognition



## References:

<sup>1</sup> I. Sobel. An Isotropic 3x3 Gradient Operator, Machine Vision for Three-Dimensional Scenes, Academic Press, 1990.

<sup>2</sup> J.M.S. Prewitt. Object Enhancement and Extraction, Picture processing and Psychopictorics, Academic Press, 1970.

<sup>3</sup> J. Canny. A Computational Approach To Edge Detection, IEEE Trans. Pattern Analysis and Machine Intelligence, 8(6):679–698, 1986.

<sup>4</sup> A. Ensor, S. Hall. GPU-based Image Analysis on Mobile Devices. Proceedings of Image and Vision Computing New Zealand 2011.

<sup>5</sup> C. Harris and M. Stephens. A Combined Corner and Edge Detector. Proc. Alvey Vision Conf., Univ. Manchester, pp. 147-151, 1988.

<sup>6</sup> J. Shi and C. Tomasi. Good features to track. Proceedings of the IEEE Conference on Computer Vision and Pattern Recognition, pages 593-600, June 1994.

<sup>7</sup> A. Noble, "Descriptions of Image Surfaces", PhD thesis, Department of Engineering Science, Oxford University 1989, p45.  

<sup>8</sup> E. Rosten and T. Drummond. Machine learning for high-speed corner detection. European Conference on Computer Vision 2006.

<sup>9</sup> M. Dubská, J. Havel, and A. Herout. [Real-Time Detection of Lines using Parallel Coordinates and OpenGL](http://medusa.fit.vutbr.cz/public/data/papers/2011-SCCG-Dubska-Real-Time-Line-Detection-Using-PC-and-OpenGL.pdf). Proceedings of SCCG 2011, Bratislava, SK, p. 7.

<sup>10</sup> M. Dubská, J. Havel, and A. Herout. [PClines — Line detection using parallel coordinates](http://medusa.fit.vutbr.cz/public/data/papers/2011-CVPR-Dubska-PClines.pdf). 2011 IEEE Conference on Computer Vision and Pattern Recognition (CVPR), p. 1489- 1494.

/*
Copyright (c) 2016 Carl Sherrell

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

#include <Foundation/Foundation.h>
#include <UIKit/UIImage.h>

#include "GIFCobblePalette.h"
#include "GIFCobbleAdaptivePalette.h"

typedef unsigned long long GIFCobbleFileSize;

typedef NS_ENUM(UInt8, GIFCobbleDitherMethod) {
  kGIFCobbleDitherMethodNone = 0,
  kGIFCobbleDitherMethodOrdered8x8,
  kGIFCobbleDitherMethodFloydSteinberg
};


@interface GIFCobbleEncoder : NSObject 

@property (nonatomic, readonly) NSString *destinationFilename;
@property (nonatomic, readonly) GIFCobblePalette *globalPalette;
@property (nonatomic, readonly) NSUInteger imagesEncoded;
@property (nonatomic, assign) CGInterpolationQuality scalingInterpolationQuality;
@property (nonatomic, assign) GIFCobbleDitherMethod ditherMethod;

- (id) initWithDestinationFilename:(NSString *)destFilename
                   destinationSize:(CGSize)destSize
                  andGlobalPalette:(GIFCobblePalette *)globPalette;


//
// encode an image using the global palette. scales image to destination size.
// returns the scaled image on success, nil otherwise
//
- (UIImage *) encodeImage:(UIImage *)image delaySeconds:(NSTimeInterval)delaySeconds;


//
// encode an image using an alternate palette. scales image to destination size
// returns the scaled image on success, nil otherwise
//
- (UIImage *) encodeImage:(UIImage *)image delaySeconds:(NSTimeInterval)delaySeconds withPalette:(GIFCobblePalette *)palette;


//
// encode an image using an adaptive palette built from the image after scaling to destination size
// returns the scaled image on success, nil otherwise
//
- (UIImage *) encodeImage:(UIImage *)image delaySeconds:(NSTimeInterval)delaySeconds withAdaptivePaletteOfSize:(GIFCobbleAdaptivePaletteSize)pSize;


- (GIFCobbleFileSize) currentFileSize;
- (GIFCobbleFileSize) finalizeGIFEncoding;

@end



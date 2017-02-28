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


#import <Foundation/Foundation.h>
#import "GIFCobbleColor.h"

typedef UInt8 GIFCobblePaletteIndex;

typedef NS_ENUM(UInt8, GIFCobblePaletteSearch) {
  kGIFCobblePaletteSearchExact = 0,
  kGIFCobblePaletteSearchApproximate
};

@interface GIFCobblePalette : NSObject <NSCoding> {
  @protected
  NSArray *_palette;
  BOOL _hasTransparentColor;
}

@property (nonatomic, assign) GIFCobblePaletteSearch paletteSearch;

- (NSUInteger) numberOfColors;
- (GIFCobbleColor *) colorAtPaletteIndex:(GIFCobblePaletteIndex)paletteIndex;

- (BOOL) hasTransparentColor;
- (GIFCobblePaletteIndex) transparentColorPaletteIndex;

- (GIFCobblePaletteIndex) indexOfPaletteColorNearestToColorWithR:(UInt8)R G:(UInt8)G B:(UInt8)B A:(UInt8)A;

@end

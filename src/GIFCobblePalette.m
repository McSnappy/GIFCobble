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


#import "GIFCobblePalette.h"

@implementation GIFCobblePalette

static const double APPROX_PALETTE_SEARCH_TOL = 5.0; // distance^2 less than this satifies approximate search


#pragma mark - Initialization

- (id) init {
  self = [super init];
  if(self) {
    _palette = [NSArray array];
    _hasTransparentColor = NO;
    _paletteSearch = kGIFCobblePaletteSearchExact;
  }
  
  return(self);
}


#pragma mark - Init With Coder

- (id) initWithCoder:(NSCoder *)coder {
  self = [self init];
  if(self) {
    _hasTransparentColor = [coder decodeBoolForKey:@"hastransparent"];
    _paletteSearch = (GIFCobblePaletteSearch) [coder decodeIntegerForKey:@"palettesearch"];
    
    NSMutableArray *pal = [NSMutableArray array];
    NSUInteger pcount = [coder decodeIntegerForKey:@"numcolors"];
    for(NSUInteger ii = 0; ii < pcount; ++ii) {
      NSString *pkey = [NSString stringWithFormat:@"color%@", @(ii)];
      UInt8 R = (UInt8) [coder decodeIntegerForKey:[pkey stringByAppendingString:@"-r"]];
      UInt8 G = (UInt8) [coder decodeIntegerForKey:[pkey stringByAppendingString:@"-g"]];
      UInt8 B = (UInt8) [coder decodeIntegerForKey:[pkey stringByAppendingString:@"-b"]];
      GIFCobbleColor *color = [[GIFCobbleColor alloc] initWithR:R G:G B:B];
      [pal addObject:color];
    }
    
    _palette = [NSArray arrayWithArray:pal];
  }
  
  return(self);
}


#pragma mark - Encode With Coder

- (void) encodeWithCoder:(NSCoder *)coder {

  NSUInteger pcount = [_palette count];
  [coder encodeInteger:pcount forKey:@"numcolors"];
  for(NSUInteger ii=0; ii < pcount; ++ii) {
    GIFCobbleColor *color = [_palette objectAtIndex:ii];
    NSString *pkey = [NSString stringWithFormat:@"color%@", @(ii)];
    [coder encodeInteger:color.R forKey:[pkey stringByAppendingString:@"-r"]];
    [coder encodeInteger:color.G forKey:[pkey stringByAppendingString:@"-g"]];
    [coder encodeInteger:color.B forKey:[pkey stringByAppendingString:@"-b"]];
  }
  
  [coder encodeBool:_hasTransparentColor forKey:@"hastransparent"];
  [coder encodeInteger:_paletteSearch forKey:@"palettesearch"];
  
}


#pragma mark - Number Of Colors

- (NSUInteger) numberOfColors {
  return([_palette count]);
}


#pragma mark - Color At Palette Index

- (GIFCobbleColor *) colorAtPaletteIndex:(GIFCobblePaletteIndex)paletteIndex {
  GIFCobbleColor *paletteColor = nil;
  if(paletteIndex < [_palette count]) {
    paletteColor = [_palette objectAtIndex:paletteIndex];
  }
  
  return(paletteColor);
}


#pragma mark - Has Transparent Color

- (BOOL) hasTransparentColor {
  return(_hasTransparentColor);
}


#pragma mark - Transparent Color Palette Index

- (GIFCobblePaletteIndex) transparentColorPaletteIndex {
  return(0);
}


#pragma mark - Nearest Palette Color

- (GIFCobblePaletteIndex) indexOfPaletteColorNearestToColorWithR:(UInt8)R G:(UInt8)G B:(UInt8)B A:(UInt8)A {
  
  //
  // use euclidean distance between colors to determine the best match
  //
  
  if((A < 255) && [self hasTransparentColor]) {
    return([self transparentColorPaletteIndex]);
  }
  
  double nearestDist = DBL_MAX;
  GIFCobblePaletteIndex nearestIndex = 0, paletteIndex = 0;
  
  for(GIFCobbleColor *paletteColor in _palette) {
  
    if(!_hasTransparentColor ||
       (_hasTransparentColor && (paletteIndex != [self transparentColorPaletteIndex]))) {
      
      double diffR = ((NSInteger)R - (NSInteger)paletteColor.R);
      double diffG = ((NSInteger)G - (NSInteger)paletteColor.G);
      double diffB = ((NSInteger)B - (NSInteger)paletteColor.B);
      double dist = (diffR * diffR) + (diffG * diffG) + (diffB * diffB);
      
      if((_paletteSearch == kGIFCobblePaletteSearchApproximate) && (dist < APPROX_PALETTE_SEARCH_TOL)) {
        return(paletteIndex);
      }
      
      if(dist < nearestDist) {
        nearestDist = dist;
        nearestIndex = paletteIndex;
      }
    }
    
    ++paletteIndex;
  }
  
  return(nearestIndex);

}


#pragma mark - Description 

- (NSString *) description {
  NSMutableString *desc = [NSMutableString string];
  [desc appendFormat:@"\n%@: %@ colors\n", NSStringFromClass([self class]), @([self numberOfColors])];
  for(GIFCobbleColor *color in _palette) {
    [desc appendFormat:@"%@\n", color];
  }
  
  return(desc);
}


@end

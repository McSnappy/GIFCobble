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


#import "GIFCobbleGrayPalette.h"

@interface GIFCobbleGrayPalette() {

}
@end


@implementation GIFCobbleGrayPalette

static const int GRAYsize = 128;
static UInt8 GRAYvals[GRAYsize];


#pragma mark - Initialization

+ (void) initialize {
  if(self == [GIFCobbleGrayPalette class]) {
    for(int ii = 0; ii < GRAYsize; ++ii) {
      GRAYvals[ii] = ii * 2;
    }
  }
}

- (id) init {
  return([self initAndIncludeTransparentColor:NO]);
}

- (id) initAndIncludeTransparentColor:(BOOL)includeTransparentColor {

  self = [super init];
  if(self) {
    _hasTransparentColor = includeTransparentColor;
    [self generateGrayPalette];
  }

  return(self);
}


#pragma mark - Init With Coder

- (id) initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if(self) {

  }
  
  return(self);
}


#pragma mark - Encode With Coder

- (void) encodeWithCoder:(NSCoder *)coder {
  
  [super encodeWithCoder:coder];
  
}


#pragma mark - Generate Gray Palette

- (void) generateGrayPalette {
  
  NSMutableArray *pal = [NSMutableArray array];
  
  //
  // designate transparent color, if selected
  //
  if(_hasTransparentColor) {
    [pal addObject:[[GIFCobbleColor alloc] initWithR:255 G:255 B:254]];
  }
  
  //
  // add a the gray colors to the palette
  //
  for(int ii=0; ii < GRAYsize; ++ii) {
    UInt8 gray = GRAYvals[ii];
    [pal addObject:[[GIFCobbleColor alloc] initWithR:gray G:gray B:gray]];
  }
  
  _palette = [NSArray arrayWithArray:pal];
}


#pragma mark - Nearest Palette Color

- (GIFCobblePaletteIndex) indexOfPaletteColorNearestToColorWithR:(UInt8)R G:(UInt8)G B:(UInt8)B A:(UInt8)A {

  //
  // handle transparent color, if applicable
  //
  if((A < 255) && [self hasTransparentColor]) {
    return([self transparentColorPaletteIndex]);
  }
  
  
  //
  // find the nearest gray color to target 
  //
  UInt8 avg = (UInt8) round((R+G+B) / 3.0);

  int grayindex, graydiff = abs(avg - GRAYvals[0]);
  for(grayindex=0; grayindex < GRAYsize; ++grayindex) {
    int tmp = abs(avg - GRAYvals[grayindex]);
    if(tmp > graydiff) {
      grayindex -= 1;
      break;
    }
    
    graydiff = tmp;
  }
    
  grayindex = (grayindex >= GRAYsize) ? (GRAYsize - 1) : grayindex;
  GIFCobblePaletteIndex gpindex = grayindex + ([self hasTransparentColor] ? 1 : 0);

  return(gpindex);
}

 
@end

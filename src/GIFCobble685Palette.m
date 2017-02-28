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


#import "GIFCobble685Palette.h"

@interface GIFCobble685Palette() {

}
@end


@implementation GIFCobble685Palette

static const int Rsize = 6;
static const UInt8 Rvals[Rsize] = { 0x0, 0x33, 0x66, 0x99, 0xCC, 0xFF };

static const int Gsize = 8;
static const UInt8 Gvals[Gsize] = { 0x0, 0x20, 0x40, 0x60, 0x80, 0xA0, 0xC0, 0xE0 };
  
static const int Bsize = 5;
static const UInt8 Bvals[Bsize] = { 0x0, 0x40, 0x80, 0xC0, 0xFF };

static const int GRAYsize = 13;
static const UInt8 GRAYvals[GRAYsize] = { 25, 45, 65, 85, 105, 125, 145, 165, 185, 205, 225, 245, 255 };

static const UInt8 RxGxB = 240;
static const UInt8 GxB = 40;

#pragma mark - Initialization

- (id) init {
  return([self initAndIncludeTransparentColor:NO]);
}

- (id) initAndIncludeTransparentColor:(BOOL)includeTransparentColor {

  self = [super init];
  if(self) {
    _hasTransparentColor = includeTransparentColor;
    [self generate685Palette];
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


#pragma mark - Generate 685 Palette

- (void) generate685Palette {
  
  NSMutableArray *pal = [NSMutableArray array];
  
  //
  // designate transparent color, if selected
  //
  if(_hasTransparentColor) {
    [pal addObject:[[GIFCobbleColor alloc] initWithR:255 G:255 B:254]];
  }
  
  //
  // add the rgb combinations (240 colors)
  //
  for(int rindex = 0; rindex < Rsize; ++rindex) {
    for(int gindex = 0; gindex < Gsize; ++gindex) {
      for(int bindex = 0; bindex < Bsize; ++bindex) {
        [pal addObject:[[GIFCobbleColor alloc] initWithR:Rvals[rindex] G:Gvals[gindex] B:Bvals[bindex]]];
      }
    }
  }
  
  //
  // add gray colors
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
  // This palette is constructed using all combinations of the channel values defined above (plus a few grays).
  // Nearest palette color search is reduced to finding the closest channel value and backing out the palette index.
  //
  
  
  //
  // handle transparent color, if applicable
  //
  if((A < 255) && [self hasTransparentColor]) {
    return([self transparentColorPaletteIndex]);
  }
  
  
  //
  // see if the target color is close to gray
  //
  int val = abs(R-B) + abs(R-G) + abs(B-G);
  if((val < 5) && (G > 10)) { // all close, but not too dark
    int grayindex, graydiff = abs(G - GRAYvals[0]);
    for(grayindex=0; grayindex < GRAYsize; ++grayindex) {
      int tmp = abs(G - GRAYvals[grayindex]);
      if(tmp > graydiff) {
        grayindex -= 1;
        break;
      }
      
      graydiff = tmp;
    }
    
    grayindex = (grayindex >= GRAYsize) ? (GRAYsize - 1) : grayindex;
    GIFCobblePaletteIndex gpindex = grayindex + ([self hasTransparentColor] ? 1 : 0) + (RxGxB);
    return(gpindex);
  }
  
  
  //
  // match against the 6-8-5 buckets
  //
  int rindex, rdiff = abs(R - Rvals[0]);
  for(rindex = 1; rindex < Rsize; ++rindex) {
    int tmp = abs(R - Rvals[rindex]);
    if(tmp > rdiff) {
      rindex -= 1;
      break;
    }
    
    rdiff = tmp;
  }
  
  rindex = (rindex >= Rsize) ? (Rsize - 1) : rindex;
  
  int gindex, gdiff = abs(G - Gvals[0]);
  for(gindex = 1; gindex < Gsize; ++gindex) {
    int tmp = abs(G - Gvals[gindex]);
    if(tmp > gdiff) {
      gindex -= 1;
      break;
    }
    
    gdiff = tmp;
  }
  
  gindex = (gindex >= Gsize) ? (Gsize - 1) : gindex;
  
  int bindex, bdiff = abs(B - Bvals[0]);
  for(bindex = 1; bindex < Bsize; ++bindex) {
    int tmp = abs(B - Bvals[bindex]);
    if(tmp > bdiff) {
      bindex -= 1;
      break;
    }
    
    bdiff = tmp;
  }
  
  bindex = (bindex >= Bsize) ? (Bsize - 1) : bindex;
  
  
  //
  // back out the palette index
  //
  GIFCobblePaletteIndex pindex = (rindex * (GxB)) + (gindex * Bsize) + bindex + ([self hasTransparentColor] ? 1 : 0);
  
  return(pindex);
}

 
@end

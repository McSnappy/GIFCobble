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


#import "GIFCobbleAdaptivePalette.h"

//
// NOTE: This code assumes the pixel data is in RGB8888.
// Automatically handled when called from GIFCobbleEncoder:encodeImage(...)
// see GIFCobbleEncoder:resizeImage()
//

typedef struct {
  UInt8 Rmin, Rmax;
  UInt8 Gmin, Gmax;
  UInt8 Bmin, Bmax;
} bucket_stats;


@interface GIFCobbleAPHelper : NSObject
@property (nonatomic, strong) GIFCobbleColor *color;
@property (nonatomic, assign) NSUInteger duplicateCount;
@end

@implementation GIFCobbleAPHelper
@end


@interface GIFCobbleAdaptivePalette() {
  GIFCobbleAdaptivePaletteSize _paletteSize;
}
@end


@implementation GIFCobbleAdaptivePalette

#pragma mark - Initialization

- (id) init {
  return([self initWithImage:nil paletteSize:kGIFCobbleAdaptivePaletteSize256 includeTransparentColor:NO]);
}

- (id) initWithImage:(UIImage *)imageToSample
         paletteSize:(GIFCobbleAdaptivePaletteSize)pSize
         includeTransparentColor:(BOOL)includeTransparentColor {

  self = [super init];
  if(self) {
    _hasTransparentColor = includeTransparentColor;
    _paletteSize = pSize;
    self.paletteSearch = kGIFCobblePaletteSearchApproximate;
    [self generateAdaptivePaletteFromImage:imageToSample];
  }

  return(self);
}


#pragma mark - Init With Coder

- (id) initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if(self) {
    _paletteSize = (GIFCobbleAdaptivePaletteSize) [coder decodeIntegerForKey:@"palettesize"];
  }
  
  return(self);
}


#pragma mark - Encode With Coder

- (void) encodeWithCoder:(NSCoder *)coder {
  
  [super encodeWithCoder:coder];
  [coder encodeInteger:_paletteSize forKey:@"palettesize"];
  
}


#pragma mark - Generate Adaptive Palette From Image

- (void) generateAdaptivePaletteFromImage:(UIImage *)imageToSample {
  
  if(!imageToSample) {
    return;
  }
  
  NSMutableDictionary *initialBucket = [self fetchInitialPixelBucketFromImage:imageToSample];
  NSMutableArray *bucketList = [NSMutableArray arrayWithObject:initialBucket];
  
  for(int ii=0; ii < _paletteSize; ++ii) {
    
    NSMutableArray *tempList = [NSMutableArray array];
    
    for(NSMutableDictionary *bucket in bucketList) {
      
      NSMutableDictionary *topHalf = [NSMutableDictionary dictionary];
      NSMutableDictionary *bottomHalf = [NSMutableDictionary dictionary];
      [self medianCutForBucket:bucket topHalf:topHalf bottomHalf:bottomHalf];
      
      [tempList addObject:topHalf];
      [tempList addObject:bottomHalf];
    }
    
    bucketList = [NSMutableArray arrayWithArray:tempList];
  }
  
  [self paletteColorsFromBuckets:bucketList];
}


#pragma mark - Median Cut For Bucket

- (void) medianCutForBucket:(NSMutableDictionary *)bucket topHalf:(NSMutableDictionary *)topHalf bottomHalf:(NSMutableDictionary *)bottomHalf {

  NSMutableArray *colors = [bucket objectForKey:@"colors"];
  GIFCobbleColorChannel widestChannel = [[bucket objectForKey:@"widestchannel"] unsignedShortValue];
  
  [colors sortUsingComparator:^NSComparisonResult (id a, id b) {
    
    GIFCobbleColor *colorA = (GIFCobbleColor *) a;
    GIFCobbleColor *colorB = (GIFCobbleColor *) b;
    
    UInt8 channelValueA = [colorA valueForColorChannel:widestChannel];
    UInt8 channelValueB = [colorB valueForColorChannel:widestChannel];
    
    if(channelValueA == channelValueB) {
      return(NSOrderedSame);
    }
    
    return(channelValueA > channelValueB);
  }];

  bucket_stats bstatsTop, bstatsBottom;
  NSMutableArray *colorsTop = [NSMutableArray array];
  NSMutableArray *colorsBottom = [NSMutableArray array];
  [self initBucketStats:&bstatsTop];
  [self initBucketStats:&bstatsBottom];
  
  NSUInteger cutSize = [colors count] / 2;
  NSUInteger bindex = 0;
  for(GIFCobbleColor *color in colors) {
    if(bindex < cutSize) {
      [colorsTop addObject:color];
      [self updateBucketStats:&bstatsTop forColor:color];
    }
    else {
      [colorsBottom addObject:color];
      [self updateBucketStats:&bstatsBottom forColor:color];
    }
    
    ++bindex;
  }
  
  [self fillBucket:topHalf withColors:colorsTop andBucketStats:&bstatsTop];
  [self fillBucket:bottomHalf withColors:colorsBottom andBucketStats:&bstatsBottom];
}


#pragma mark - Palette Colors From Buckets

- (void) paletteColorsFromBuckets:(NSMutableArray *)bucketList {
  
  NSMutableDictionary *colorDict = [NSMutableDictionary dictionary];
  
  for(NSMutableDictionary *bucket in bucketList) {

    NSMutableArray *colors = [bucket objectForKey:@"colors"];
    
    double Rsum = 0, Gsum = 0, Bsum = 0;
    for(GIFCobbleColor *color in colors) {
      Rsum += color.R;
      Gsum += color.G;
      Bsum += color.B;
    }
    
    UInt8 R = (UInt8) round(Rsum / [colors count]);
    UInt8 G = (UInt8) round(Gsum / [colors count]);
    UInt8 B = (UInt8) round(Bsum / [colors count]);
    
    //
    // we reserve 255,255,254 for the transparent color
    //
    if((R == 255) && (G == 255) && (B == 254)) {
      B = 255;
    }
    
    NSString *colorKey = [NSString stringWithFormat:@"%d %d %d", R, G, B];
    GIFCobbleAPHelper *helper = [colorDict objectForKey:colorKey];
    if(helper) {
      helper.duplicateCount = helper.duplicateCount + 1;
    }
    else {
      helper = [[GIFCobbleAPHelper alloc] init];
      helper.color = [[GIFCobbleColor alloc] initWithR:R G:G B:B];
      helper.duplicateCount = 0;
      [colorDict setObject:helper forKey:colorKey];
    }
  }
  
  NSMutableArray *helpers = [NSMutableArray arrayWithArray:[colorDict allValues]];
  [helpers sortUsingComparator:^NSComparisonResult (id a, id b) {
    
    GIFCobbleAPHelper *helperA = (GIFCobbleAPHelper *) a;
    GIFCobbleAPHelper *helperB = (GIFCobbleAPHelper *) b;
    
    if(helperA.duplicateCount == helperB.duplicateCount) {
      return(NSOrderedSame);
    }
    
    return(helperB.duplicateCount > helperA.duplicateCount);
  }];

  NSMutableArray *pal = [NSMutableArray array];
  
  if(_hasTransparentColor) {
    [pal addObject:[[GIFCobbleColor alloc] initWithR:255 G:255 B:254]];
  }
  
  for(GIFCobbleAPHelper *helper in helpers) {
    
    // NSLog(@"adding %@ %@ %@ with %@ duplicates to palette",
    //      @(helper.color.R), @(helper.color.G), @(helper.color.B), @(helper.duplicateCount));
    
    [pal addObject:helper.color];
    if([pal count] == 256) {
      break;
    }
  }
  
  //NSLog(@"adaptive palette has %@ colors", @([pal count]));
  
  _palette = [NSArray arrayWithArray:pal];
}


#pragma mark - Fetch Initial Pixel Bucket From Image

- (NSMutableDictionary *) fetchInitialPixelBucketFromImage:(UIImage *)image {
  
  const double pixelsToSampleTarget = 3072;
  NSUInteger sampleCutoff = (NSUInteger) round((pixelsToSampleTarget / (image.size.width * image.size.height)) * 10000);
  sampleCutoff = (sampleCutoff == 0) ? 1 : sampleCutoff;
  
  CGDataProviderRef provider = CGImageGetDataProvider(image.CGImage);
  CFDataRef pixelData = CGDataProviderCopyData(provider);
  const UInt8 *data = CFDataGetBytePtr(pixelData);
  const int numberOfColorComponents = 4;
  
  NSUInteger width = image.size.width;
  NSUInteger height = image.size.height;
  NSMutableArray *colors = [NSMutableArray array];
  
  bucket_stats bstats;
  [self initBucketStats:&bstats];
  
  for(NSUInteger y = 0; y < height; ++y) {
    for(NSUInteger x = 0; x < width; ++x) {
      
      if((arc4random() % 10000) > sampleCutoff) {
          continue;
      }
      
      NSUInteger pixelOffset = ((width * y) + x) * numberOfColorComponents;
      UInt8 R = data[pixelOffset];
      UInt8 G = data[(pixelOffset + 1)];
      UInt8 B = data[pixelOffset + 2];
      
      GIFCobbleColor *color = [[GIFCobbleColor alloc] initWithR:R G:G B:B];
      [colors addObject:color];
      [self updateBucketStats:&bstats forColor:color];
      
    }
  }
  
  CFRelease(pixelData);
  
  //NSLog(@"initial bucket has %@ pixels", @([colors count]));
  
  NSMutableDictionary *bucket = [NSMutableDictionary dictionary];
  [self fillBucket:bucket withColors:colors andBucketStats:&bstats];
  
  return(bucket);
}


#pragma mark - Fill Bucket With Colors And Bucket Stats

- (void) fillBucket:(NSMutableDictionary *)bucket withColors:(NSMutableArray *)colors andBucketStats:(bucket_stats *)bstats {

  [bucket setObject:colors forKey:@"colors"];
  GIFCobbleColorChannel widestChannel = [self channelWithMaxRange:bstats];
  [bucket setObject:@(widestChannel) forKey:@"widestchannel"];

}


#pragma mark - Update Bucket Stats For Color

- (void) updateBucketStats:(bucket_stats *)bstats forColor:(GIFCobbleColor *)color {
  
  if(!bstats) {
    return;
  }
  
  if(color.R < bstats->Rmin) {
    bstats->Rmin = color.R;
  }
  
  if(color.R > bstats->Rmax) {
    bstats->Rmax = color.R;
  }
  
  if(color.G < bstats->Gmin) {
    bstats->Gmin = color.G;
  }
  
  if(color.G > bstats->Gmax) {
    bstats->Gmax = color.G;
  }
  
  if(color.B < bstats->Bmin) {
    bstats->Bmin = color.B;
  }
  
  if(color.B > bstats->Bmax) {
    bstats->Bmax = color.B;
  }
}


#pragma mark - Init Bucket Stats 

- (void) initBucketStats:(bucket_stats *)bstats {
  
  if(!bstats) {
    return;
  }
  
  bstats->Rmax = bstats->Gmax = bstats->Bmax = 0;
  bstats->Rmin = bstats->Gmin = bstats->Bmin = 255;
}


#pragma mark - Channel With Max Range

- (GIFCobbleColorChannel) channelWithMaxRange:(bucket_stats *)bstats {
  
  if(!bstats) {
    return(kGIFCobbleColorRedChannel);
  }

  GIFCobbleColorChannel widestChannel = kGIFCobbleColorRedChannel;
  UInt8 widestRange = bstats->Rmax - bstats->Rmin;

  int gRange = bstats->Gmax - bstats->Gmin;
  if(gRange > widestRange) {
    widestChannel = kGIFCobbleColorGreenChannel;
    widestRange = gRange;
  }
  
  int bRange = bstats->Bmax - bstats->Bmin;
  if(bRange > widestRange) {
    widestChannel = kGIFCobbleColorBlueChannel;
  }
  
  return(widestChannel);
}


@end

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

#import <UIKit/UIKit.h>
#import "GIFCobbleEncoder.h"
#import "GIFCobbleGrayPalette.h"


@interface GIFCobbleEncoder() {
  NSFileHandle *_destinationFileHandle;
  UInt16 _destinationWidth;
  UInt16 _destinationHeight;
  NSUInteger _imagesEncoded;
}

@property (nonatomic, copy) NSString *destinationFilename;
@property (nonatomic, strong) GIFCobblePalette *globalPalette;

@end


@implementation GIFCobbleEncoder

static const UInt16 GIFCobble_CLEAR_CODE = 256;
static const UInt16 GIFCobble_END_CODE = 257;

static const double ordered_dither[][8] = {
  {1, 49, 13, 61, 4, 52, 16, 64},
  {33, 17, 45, 29, 36, 20, 48, 32},
  {9, 57, 5, 53, 12, 60, 8, 56},
  {41, 25, 37, 21, 44, 28, 40, 24},
  {3, 51, 15, 63, 2, 50, 14, 62},
  {35, 19, 47, 31, 34, 18, 46, 30},
  {11, 59, 7, 55, 10, 58, 6, 54},
  {43, 27, 39, 23, 42, 26, 38, 22}
};

#pragma mark - Initialization

- (id) init {
  return([self initWithDestinationFilename:nil destinationSize:CGSizeMake(0,0) andGlobalPalette:nil]);
}

- (id) initWithDestinationFilename:(NSString *)destFilename
                   destinationSize:(CGSize)destSize
                  andGlobalPalette:(GIFCobblePalette *)globPalette {

  self = [super init];
  if(self) {
    _imagesEncoded = 0;
    _destinationFilename = [NSString stringWithString:destFilename];
    _destinationWidth = (UInt16) round(destSize.width);
    _destinationHeight = (UInt16) round(destSize.height);
    _globalPalette = globPalette;
    _scalingInterpolationQuality = kCGInterpolationMedium;
    _ditherMethod = kGIFCobbleDitherMethodFloydSteinberg;
    
    if(![self prepareDestinationForEncoding]) {
      return(nil);
    }
    
    [self writeGIFHeader];
    [self writeLogicalScreenDescriptor];
    [self writeColorTable:_globalPalette];
    [self writeAnimatedGIFAppExtension];
  }

  return(self);
}


#pragma mark - Prepare Destination For Encoding

- (BOOL) prepareDestinationForEncoding {
  
  [[NSFileManager defaultManager] createFileAtPath:_destinationFilename contents:[NSData data] attributes:nil];
  
  _destinationFileHandle = [NSFileHandle fileHandleForWritingAtPath:_destinationFilename];
  if(!_destinationFileHandle) {
    //NSLog(@"couldn't initialize %@ for gif encoding...", _destinationFilename);
    return(NO);
  }
  
  //NSLog(@"creating gif at %@", _destinationFilename);
  
  return(YES);
}


#pragma mark - Write GIF Header

- (void) writeGIFHeader {
  const char *GIF_HEADER = "GIF89a";
  [_destinationFileHandle writeData:[NSData dataWithBytes:GIF_HEADER length:strlen(GIF_HEADER)]];
}


#pragma mark - Write Logical Screen Descriptor

- (void) writeLogicalScreenDescriptor {
  
  // Canvas Width - 2 bytes, Little Endian
  // Canvas Height - 2 bytes, Little Endian
  // Control Bitfield - 1 byte
  //    * Global Color Table Flag (1 bit), 1 if present
  //    * Color Resolution (3 bits), bits per pixel
  //    * Sort Flag (1 bit), [ignored by decoders]
  //    * Size of Global Color Table (3 bits) (# bits per table entry minus one)
  // Background Color Index - 1 byte [ignored by decoders]
  // Pixel Aspect - 1 byte, [ignored by decoders]
  
  NSMutableData *lsd = [NSMutableData data];
  
  
  UInt16 widthLE = NSSwapHostShortToLittle(_destinationWidth);
  [lsd appendBytes:&widthLE length:2];  // Canvas Width
  
  UInt16 heightLE = NSSwapHostShortToLittle(_destinationHeight);
  [lsd appendBytes:&heightLE length:2];  // Canvas Height

  UInt8 bitfield = 0;
  if(_globalPalette) {
    bitfield = (1 << 7) | (7 << 4) | 7; // have a global table, 8 bits per pixel, 256 colors
  }

  [lsd appendBytes:&bitfield length:1]; // Control Bitfield
  
  UInt8 zeroByte = 0;
  [lsd appendBytes:&zeroByte length:1]; // Background Color Index
  [lsd appendBytes:&zeroByte length:1]; // Pixel Aspect
  
  [_destinationFileHandle writeData:lsd];
  
}


#pragma mark - Write Color Table

- (void) writeColorTable:(GIFCobblePalette *)palette {
  
  if(!palette) {
    return;
  }
  
  NSMutableData *ctable = [NSMutableData data];
  
  //
  // write a table with 256 colors, filled with 0,0,0 for unused slots
  //
  for(NSUInteger paletteIndex = 0; paletteIndex < 256; ++paletteIndex) {
    if (paletteIndex >= [palette numberOfColors]) { // add an empty entry to the mapping
      UInt8 zeroBytes[3] = { 0, 0, 0 };
      [ctable appendBytes:zeroBytes length:3];
    }
    else {
      GIFCobbleColor *color = [palette colorAtPaletteIndex:paletteIndex];
      UInt8 channels[3] = { color.R, color.G, color.B };
      [ctable appendBytes:channels length:3];
    }
  }
  
  [_destinationFileHandle writeData:ctable];
}


#pragma mark - Write Animated GIF Application Extension

- (void) writeAnimatedGIFAppExtension {
  
  NSMutableData *appext = [NSMutableData data];
  
  UInt8 extIntroducer = 0x21;
  [appext appendBytes:&extIntroducer length:1];
  
  UInt8 appExtLabel = 0xFF;
  [appext appendBytes:&appExtLabel length:1];

  const char *appIdAndAuthCode = "NETSCAPE2.0";
  UInt8 blockLen = strlen(appIdAndAuthCode);
  [appext appendBytes:&blockLen length:1];
  [appext appendBytes:appIdAndAuthCode length:blockLen];
  
  UInt8 loopCommand[4] = { 0x03, 0x01, 0x0, 0x0 }; // 3 bytes to follow, sub block id (always 1), loop control (2 bytes, 0 = loop forever)
  [appext appendBytes:loopCommand length:4];
  
  UInt8 terminator = 0;
  [appext appendBytes:&terminator length:1];

  [_destinationFileHandle writeData:appext];
}


#pragma mark - _Encode Image With Local Palette

- (BOOL) _encodeImage:(UIImage *)image delaySeconds:(NSTimeInterval)delaySeconds withPalette:(GIFCobblePalette *)localPalette {
  
  if(!image) {
    //NSLog(@"ERROR: trying to encode a nil image...");
    return(NO);
  }
  
  GIFCobblePalette *paletteForEncoding = localPalette ? localPalette : _globalPalette;
  if(!paletteForEncoding) {
    //NSLog(@"ERROR: trying to encode an image without a palette...");
    return(NO);
  }
  
  [self writeGraphicsControlExtensionWithDelaySeconds:delaySeconds withPalette:paletteForEncoding];
  [self writeImageDescriptor:localPalette];
  [self writeColorTable:localPalette];
  [self writeDataForImage:image withPalette:paletteForEncoding];
  ++_imagesEncoded;
  
  return(YES);
}


#pragma mark - Encode Image With Adaptive Palette

- (UIImage *) encodeImage:(UIImage *)image delaySeconds:(NSTimeInterval)delaySeconds withAdaptivePaletteOfSize:(GIFCobbleAdaptivePaletteSize)pSize {
  
  image = [self resizeImage:image];
  GIFCobbleAdaptivePalette *palette = [[GIFCobbleAdaptivePalette alloc] initWithImage:image paletteSize:pSize includeTransparentColor:YES];
  if([self _encodeImage:image delaySeconds:delaySeconds withPalette:palette]) {
    return(image);
  }
  
  return(nil);
}


#pragma mark - Encode Image With Local Palette

- (UIImage *) encodeImage:(UIImage *)image delaySeconds:(NSTimeInterval)delaySeconds withPalette:(GIFCobblePalette *)localPalette {
  image = [self resizeImage:image];
  if([self _encodeImage:image delaySeconds:delaySeconds withPalette:localPalette]) {
    return(image);
  }
  
  return(nil);
}


#pragma mark - Encode Image

- (UIImage *) encodeImage:(UIImage *)image delaySeconds:(NSTimeInterval)delaySeconds {
  return([self encodeImage:image delaySeconds:delaySeconds withPalette:nil]);
}


#pragma mark - Write Data For Image With Palette

- (void) writeDataForImage:(UIImage *)image withPalette:(GIFCobblePalette *)palette {
  
  // blinded by the magic #s, ha
  
  bool disableDither = [palette isKindOfClass:[GIFCobbleGrayPalette class]] ? YES : NO;
  
  NSMutableDictionary *encodingDict = [NSMutableDictionary dictionaryWithCapacity:4096];
  [self resetEncodingDictionary:encodingDict];
  
  CGDataProviderRef provider = CGImageGetDataProvider(image.CGImage);
  CFDataRef pixelData = CGDataProviderCopyData(provider);
  const UInt8 *data = CFDataGetBytePtr(pixelData);
  
  const int numberOfColorComponents = 4;
  UInt8 encodingSizeInBits = 9, spareBits = 0;
  UInt16 nextCode = GIFCobble_END_CODE + 1;
  NSMutableData *encoded = [NSMutableData dataWithCapacity:16384];
  NSMutableString *indexBufferKey = [NSMutableString stringWithCapacity:1024];
  spareBits = [self packBitsFromCode:GIFCobble_CLEAR_CODE intoData:encoded spareBits:spareBits encodingSizeInBits:encodingSizeInBits];

  double *qerrR = 0, *qerrG = 0, *qerrB = 0;
  
  if(!disableDither && (_ditherMethod == kGIFCobbleDitherMethodFloydSteinberg)) {
    qerrR = (double *) calloc(_destinationWidth * _destinationHeight, sizeof(double));
    qerrG = (double *) calloc(_destinationWidth * _destinationHeight, sizeof(double));
    qerrB = (double *) calloc(_destinationWidth * _destinationHeight, sizeof(double));
  }
  
  for(NSUInteger y = 0; y < _destinationHeight; ++y) {
    for(NSUInteger x = 0; x < _destinationWidth; ++x) {

      NSUInteger pixelOffset = ((_destinationWidth * y) + x) * numberOfColorComponents;
      UInt8 R = data[pixelOffset];
      UInt8 G = data[(pixelOffset + 1)];
      UInt8 B = data[pixelOffset + 2];
      UInt8 A = data[pixelOffset + 3];
            
      if(!disableDither && (_ditherMethod == kGIFCobbleDitherMethodOrdered8x8)) {
        // don't have proper gamma correction, so we will just scale the ordered dither using 260 instead of 65
        double dither_factor = ordered_dither[x % 8][y % 8] / 260.0;
        R = (UInt8) fmin(255, R + (R * dither_factor));
        G = (UInt8) fmin(255, G + (G * dither_factor));
        B = (UInt8) fmin(255, B + (B * dither_factor));
      }
      
      if(!disableDither && (_ditherMethod == kGIFCobbleDitherMethodFloydSteinberg)) {
        double adjR = (double)R + qerrR[(_destinationWidth * y) + x];
        R = (adjR < 0) ? 0 : (UInt8) round(fmin(255, adjR));
        
        double adjG = (double)G + qerrG[(_destinationWidth * y) + x];
        G = (adjG < 0) ? 0 : (UInt8) round(fmin(255, adjG));
        
        double adjB = (double)B + qerrB[(_destinationWidth * y) + x];
        B = (adjB < 0) ? 0 : (UInt8) round(fmin(255, adjB));
        
      }
      
      GIFCobblePaletteIndex paletteIndex = [palette indexOfPaletteColorNearestToColorWithR:R G:G B:B A:A];
      
      if(!disableDither && (_ditherMethod == kGIFCobbleDitherMethodFloydSteinberg) &&
         (y < (_destinationHeight - 1))) {
        
        if(![palette hasTransparentColor] ||
           ([palette hasTransparentColor] && (paletteIndex != [palette transparentColorPaletteIndex]))) {
          
          GIFCobbleColor *palColor = [palette colorAtPaletteIndex:paletteIndex];
          
          double Rerr = (double)R - (double)palColor.R;
          double Gerr = (double)G - (double)palColor.G;
          double Berr = (double)B - (double)palColor.B;
          
          qerrR[(_destinationWidth * y) + x + 1] += ((7.0/16.0) * Rerr);
          qerrG[(_destinationWidth * y) + x + 1] += ((7.0/16.0) * Gerr);
          qerrB[(_destinationWidth * y) + x + 1] += ((7.0/16.0) * Berr);
          
          qerrR[(_destinationWidth * (y+1)) + x + 1] += ((1.0/16.0) * Rerr);
          qerrG[(_destinationWidth * (y+1)) + x + 1] += ((1.0/16.0) * Gerr);
          qerrB[(_destinationWidth * (y+1)) + x + 1] += ((1.0/16.0) * Berr);
          
          qerrR[(_destinationWidth * (y+1)) + x] += ((5.0/16.0) * Rerr);
          qerrG[(_destinationWidth * (y+1)) + x] += ((5.0/16.0) * Gerr);
          qerrB[(_destinationWidth * (y+1)) + x] += ((5.0/16.0) * Berr);
          
          qerrR[(_destinationWidth * (y+1)) + x - 1] += ((3.0/16.0) * Rerr);
          qerrG[(_destinationWidth * (y+1)) + x - 1] += ((3.0/16.0) * Gerr);
          qerrB[(_destinationWidth * (y+1)) + x - 1] += ((3.0/16.0) * Berr);
        }
      }
      
      [indexBufferKey appendFormat:@"%03d", paletteIndex];
      if([encodingDict objectForKey:indexBufferKey]) {
        continue;
      }
      
      [indexBufferKey deleteCharactersInRange:NSMakeRange([indexBufferKey length] - 3, 3)];
      UInt16 code = [[encodingDict objectForKey:indexBufferKey] unsignedShortValue];
      spareBits = [self packBitsFromCode:code intoData:encoded spareBits:spareBits encodingSizeInBits:encodingSizeInBits];

      [indexBufferKey appendFormat:@"%03d", paletteIndex];
      [encodingDict setObject:@(nextCode) forKey:indexBufferKey];
      
      indexBufferKey = [NSMutableString stringWithCapacity:1024];
      [indexBufferKey appendFormat:@"%03d", paletteIndex];
      
      ++nextCode;
      
      switch(nextCode) {
        case 513: encodingSizeInBits = 10; break;
        case 1025: encodingSizeInBits = 11; break;
        case 2049: encodingSizeInBits = 12; break;
        case 4097:
          spareBits = [self packBitsFromCode:GIFCobble_CLEAR_CODE intoData:encoded spareBits:spareBits encodingSizeInBits:encodingSizeInBits];
          encodingSizeInBits = 9;
          nextCode = GIFCobble_END_CODE + 1;
          [self resetEncodingDictionary:encodingDict];
          break;
      }
      
    } // y
  } // x
  
  if(!disableDither && (_ditherMethod == kGIFCobbleDitherMethodFloydSteinberg)) {
    free(qerrR);
    free(qerrG);
    free(qerrB);
  }
  
  UInt16 finalCode = [[encodingDict objectForKey:indexBufferKey] unsignedShortValue];
  spareBits = [self packBitsFromCode:finalCode intoData:encoded spareBits:spareBits encodingSizeInBits:encodingSizeInBits];
  [self packBitsFromCode:GIFCobble_END_CODE intoData:encoded spareBits:spareBits encodingSizeInBits:encodingSizeInBits];
  
  CFRelease(pixelData);
  
  UInt8 lzwMinimumEncoding = 8; // we assume all palettes are 256 colors
  [_destinationFileHandle writeData:[NSData dataWithBytes:&lzwMinimumEncoding length:1]];
  
  NSUInteger length = [encoded length];
  const char *bytes = (const char *)[encoded bytes];
  
  for(NSUInteger index = 0; index < length; index += 255) {
    UInt8 blockLen = 255;
    if ((length - index) < blockLen) {
      blockLen = length - index;
    }
    
    NSData *blockData = [NSData dataWithBytes:&bytes[index] length:blockLen];
    [_destinationFileHandle writeData:[NSData dataWithBytes:&blockLen length:1]];
    [_destinationFileHandle writeData:blockData];
  }
  
  UInt8 terminator = 0;
  [_destinationFileHandle writeData:[NSData dataWithBytes:&terminator length:1]];
}


#pragma mark - Reset Encoding Dictionary

- (void) resetEncodingDictionary:(NSMutableDictionary *)encodingDict {
  
  [encodingDict removeAllObjects];
  
  //
  // we assume 256 colors for all palettes even though some may be unused.
  // the key to our encoding dictionary is a list of 3 digit palette index
  // numbers stored as a string...
  //
  for(NSInteger paletteIndex = 0; paletteIndex < 256; ++paletteIndex) {
    [encodingDict setObject:@(paletteIndex) forKey:[NSString stringWithFormat:@"%03ld", (long)paletteIndex]];
  }
  
  [encodingDict setObject:@(GIFCobble_CLEAR_CODE) forKey:[NSString stringWithFormat:@"%03d", GIFCobble_CLEAR_CODE]];
  [encodingDict setObject:@(GIFCobble_END_CODE) forKey:[NSString stringWithFormat:@"%03d", GIFCobble_END_CODE]];
  
}


#pragma mark - Pack Bits From Code Into Data

- (UInt8) packBitsFromCode:(UInt16)code intoData:(NSMutableData *)encoded spareBits:(UInt8)spareBits encodingSizeInBits:(UInt8)encodingSizeInBits {
  
  //
  // Here we pack 'encodingSizeInBits' number of bits from 'code' into 'encoded'.
  // 'Sparebits' tells us how many bits of the last byte of 'encoded' were left unused.
  //
  // We pack the least significant bits of code first as required by the GIF format.
  //
  // Returns the sparebits count of unused bits once we are done packing 'code'.
  //
  
  UInt8 bitsLeftToEncode = encodingSizeInBits;
  
  //
  // use remaining sparebits, if any
  //
  if(spareBits > 0) {
    NSUInteger encodedLen = [encoded length];
    UInt8 *bytes = [encoded mutableBytes];
    UInt8 sbmask = [self maskForSpareBitSize:spareBits];
    UInt8 val = (code & sbmask);
    val <<= (8 - spareBits);
    bytes[encodedLen - 1] |= val;
    UInt8 spareBitsUsed = (bitsLeftToEncode >= spareBits) ? spareBits : bitsLeftToEncode;
    spareBits -= spareBitsUsed;
    bitsLeftToEncode -= spareBitsUsed;
    code >>= spareBitsUsed;
  }
  
  if(bitsLeftToEncode == 0) {
    return(spareBits);
  }
  
  // add a byte to encoded
  UInt8 aByte = (code & 0xFF);
  [encoded appendBytes:&aByte length:1];
  UInt8 bitsUsed = (bitsLeftToEncode >= 8) ? 8 : bitsLeftToEncode;
  spareBits = 8 - bitsUsed;
  bitsLeftToEncode -= bitsUsed;
  code >>= bitsUsed;
  
  if(bitsLeftToEncode == 0) {
    return(spareBits);
  }
  
  // add another byte to encoded (max of 12 bits to encode per GIF standard)
  aByte = (code & 0xFF);
  [encoded appendBytes:&aByte length:1];
  bitsUsed = (bitsLeftToEncode >= 8) ? 8 : bitsLeftToEncode;
  spareBits = 8 - bitsUsed;
  
  return(spareBits);
}

- (UInt8) maskForSpareBitSize:(UInt8)spareBits {
  switch(spareBits) {
    case 1: return(1); break;
    case 2: return(3); break;
    case 3: return(7); break;
    case 4: return(15); break;
    case 5: return(31); break;
    case 6: return(63); break;
    case 7: return(127); break;
  }
  
  return(0);
}


#pragma mark - Write Image Descriptor

- (void) writeImageDescriptor:(GIFCobblePalette *)localPalette {
  
  NSMutableData *imgdesc = [NSMutableData data];
  
  UInt8 imageSeparator = 0x2C;
  [imgdesc appendBytes:&imageSeparator length:1];
  
  UInt8 ignored[4] = { 0, 0, 0, 0}; // image offset top & left (ignored)
  [imgdesc appendBytes:ignored length:4];
  
  UInt16 widthLE = NSSwapHostShortToLittle(_destinationWidth); // don't assume we are Little Endian
  [imgdesc appendBytes:&widthLE length:2];
  
  UInt16 heightLE = NSSwapHostShortToLittle(_destinationHeight);
  [imgdesc appendBytes:&heightLE length:2];
  
  UInt8 packed = 0;
  if(localPalette) {
    packed = (1 << 7); // high bit indicates use of local palette
    packed |= 7; // The lower 3 bits specifies size of the color table, 2^(n+1).
                 // As with the global color table we force 256 and fill
                 // with unused colors as needed.
  }
  
  [imgdesc appendBytes:&packed length:1];

  [_destinationFileHandle writeData:imgdesc];
}


#pragma mark - Write Graphics Control Extension

- (void) writeGraphicsControlExtensionWithDelaySeconds:(NSTimeInterval)delaySeconds withPalette:(GIFCobblePalette *)palette {
  
  NSMutableData *gce = [NSMutableData data];
  
  UInt8 extIntroducer = 0x21;
  [gce appendBytes:&extIntroducer length:1];
  
  UInt8 graphicControlLabel = 0xF9;
  [gce appendBytes:&graphicControlLabel length:1];
  
  UInt8 blockLen = 4;
  [gce appendBytes:&blockLen length:1];
  
  UInt8 packed = (1 << 2); // disposal method 1
  packed |= [palette hasTransparentColor] ? 1 : 0; // signal whether we are using a transparent color
  [gce appendBytes:&packed length:1];
  
  UInt16 delayTime = (UInt16) round(delaySeconds * 100);
  UInt16 delayTimeLE = NSSwapHostShortToLittle(delayTime); // don't assume we are little endian
  [gce appendBytes:&delayTimeLE length:2];
  
  UInt8 transparentColorIndex = [palette hasTransparentColor] ? [palette transparentColorPaletteIndex] : 0;
  [gce appendBytes:&transparentColorIndex length:1];
  
  UInt8 terminator = 0;
  [gce appendBytes:&terminator length:1];

  [_destinationFileHandle writeData:gce];
}


#pragma mark - Finalize GIF Encoding

- (GIFCobbleFileSize) finalizeGIFEncoding {
  
  UInt8 gifTrailer = 0x3B;
  [_destinationFileHandle writeData:[NSData dataWithBytes:&gifTrailer length:1]];
  [_destinationFileHandle synchronizeFile];
  [_destinationFileHandle closeFile];
  _destinationFileHandle = nil;
  
  GIFCobbleFileSize filesize = [[NSFileManager defaultManager] attributesOfItemAtPath:_destinationFilename error:nil].fileSize;
  return(filesize);
}


#pragma mark - Current File Size

- (GIFCobbleFileSize) currentFileSize {
  return([_destinationFileHandle offsetInFile]);
}


#pragma mark - Resize Image If Needed

- (UIImage *) resizeImage:(UIImage *)image {
  //
  // we always resize/redraw to ensure RGB8888 image data
  //
  size_t bitsPerComponent = 8;
  size_t bytesPerRow = _destinationWidth * 4;
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast;
  CGContextRef context = CGBitmapContextCreate(NULL, _destinationWidth, _destinationHeight,
                                               bitsPerComponent, bytesPerRow, colorSpace, bitmapInfo);
  CGContextSetInterpolationQuality(context, _scalingInterpolationQuality);
  CGContextDrawImage(context, CGRectMake(0, 0, _destinationWidth, _destinationHeight), image.CGImage);
  CGImageRef scaledCGImage = CGBitmapContextCreateImage(context);
  UIImage *scaledImage = [[UIImage alloc] initWithCGImage:scaledCGImage];
  
  CGColorSpaceRelease(colorSpace);
  CGContextRelease(context);
  CGImageRelease(scaledCGImage);
  
  return(scaledImage);
}

@end





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


#import "GIFCobbleColor.h"

@interface GIFCobbleColor() {

} 

@property (nonatomic, assign) UInt8 R;
@property (nonatomic, assign) UInt8 G;
@property (nonatomic, assign) UInt8 B;

@end


@implementation GIFCobbleColor 

#pragma mark - Initialization

- (id) initWithR:(UInt8)R G:(UInt8)G B:(UInt8)B {
  self = [super init];
  if(self) {
    _R = R;
    _G = G;
    _B = B;
  }

  return(self);
}


#pragma mark - Value For Color Channel

- (UInt8) valueForColorChannel:(GIFCobbleColorChannel)channel {
  
  switch(channel) {
    case kGIFCobbleColorRedChannel: return(_R); break;
    case kGIFCobbleColorGreenChannel: return(_G); break;
    case kGIFCobbleColorBlueChannel: return(_B); break;
  }
  
}


#pragma mark - Description

- (NSString *) description {
  return([NSString stringWithFormat:@"GIFCobbleColor: %@ %@ %@", @(_R), @(_G), @(_B)]);
}

@end

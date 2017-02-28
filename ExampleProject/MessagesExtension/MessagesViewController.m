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


#import "MessagesViewController.h"
#import "GIFCobbleEncoder.h"


@interface MessagesViewController () {
  MSConversation *_conversation;
}

@property (nonatomic, weak) IBOutlet UIButton *createGIFButton;
- (IBAction) createGIFButtonTapped:(id)sender;

@end

@implementation MessagesViewController

- (void)viewDidLoad {
  [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
}


#pragma mark - Conversation Handling

-(void)didBecomeActiveWithConversation:(MSConversation *)conversation {
  _conversation = conversation;
}

-(void)willResignActiveWithConversation:(MSConversation *)conversation {
  _conversation = nil;
}


#pragma mark - IBActions

- (void)createGIFButtonTapped:(id)sender {
  [self createAnimatedGIF];
}


#pragma mark - Create Animated GIF

- (void) createAnimatedGIF {
  
  _createGIFButton.enabled = NO;
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    GIFCobbleEncoder *gifEncoder = [[GIFCobbleEncoder alloc] initWithDestinationFilename:[NSTemporaryDirectory() stringByAppendingPathComponent:@"test.gif"]
                                                                         destinationSize:CGSizeMake(150, 100)
                                                                        andGlobalPalette:nil];
    gifEncoder.scalingInterpolationQuality = kCGInterpolationMedium;
    gifEncoder.ditherMethod = kGIFCobbleDitherMethodFloydSteinberg;
    
    UIImage *image1 = [UIImage imageNamed:@"image1"];
    [gifEncoder encodeImage:image1 delaySeconds:0.25 withAdaptivePaletteOfSize:kGIFCobbleAdaptivePaletteSize256];
    
    UIImage *image2 = [UIImage imageNamed:@"image2"];
    [gifEncoder encodeImage:image2 delaySeconds:0.25 withAdaptivePaletteOfSize:kGIFCobbleAdaptivePaletteSize256];

    UIImage *image3 = [UIImage imageNamed:@"image3"];
    [gifEncoder encodeImage:image3 delaySeconds:0.25 withAdaptivePaletteOfSize:kGIFCobbleAdaptivePaletteSize256];
    
    GIFCobbleFileSize filesize = [gifEncoder finalizeGIFEncoding];
    NSString *fileSizeStr = (filesize > 1000000) ? [NSString stringWithFormat:@"%.1f mb", filesize / 1048576.0] : [NSString stringWithFormat:@"%@ kb", @(round(filesize / 1024.0))];
    NSLog(@"created gif (%@): %@", fileSizeStr, gifEncoder.destinationFilename);
    
    dispatch_async(dispatch_get_main_queue(), ^{
      _createGIFButton.enabled = YES;
      [_conversation insertAttachment:[NSURL fileURLWithPath:gifEncoder.destinationFilename] withAlternateFilename:nil completionHandler:^(NSError *error) {
        if(error) {
          NSLog(@"error while trying to insert gif: %@", error);
        }
      }];
    });
    
  });
  
}

@end

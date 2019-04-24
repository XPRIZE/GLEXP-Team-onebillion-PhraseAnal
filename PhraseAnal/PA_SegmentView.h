//
//  PA_SegmentView.h
//  PhraseAnal
//
//  Created by alan on 23/11/13.
//  Copyright (c) 2013 Alan C Smith. All rights reserved.
//

#import "VirtualView.h"
#import "WaveView.h"

@class AudioContainer;

@interface PA_SegmentView : VirtualView<CALayerDelegate>
{
}

@property (nonatomic) float magnification;
@property (assign) 	IBOutlet AudioContainer *controller;
@property (assign) 	IBOutlet WaveView *waveView;
@property (retain) 	NSMutableArray *segments;

-(void)waveFormLoaded;
-(void)processSegmentsForLayer:(CALayer*)mainLayer;
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
-(IBAction)splitSegment:(id)sender;
-(IBAction)addSegment:(id)sender;
-(IBAction)deleteSegment:(id)sender;
-(int)segmentIndexForFrame:(UInt64)f;
-(BOOL)splitSegmentAtFrame:(SInt64)fr;
-(BOOL)addSegmentAtFrame:(SInt64)fr;
-(IBAction)deleteSegmentsFromHere:(id)sender;
-(IBAction)mergeSegment:(id)sender;

@end

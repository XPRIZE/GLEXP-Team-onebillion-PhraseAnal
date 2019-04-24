//
//  PA_SegmentClipView.h
//  PhraseAnal
//
//  Created by alan on 23/11/13.
//  Copyright (c) 2013 Alan C Smith. All rights reserved.
//

#import "ClipView.h"
@class AudioContainer;
@interface PA_SegmentClipView : ClipView<CALayerDelegate>
{
	CALayer *mainLayer;
}

@property (assign,nonatomic) AudioContainer *controller;
@property NSPoint rightMousePoint;

-(IBAction)splitSegment:(id)sender;
-(IBAction)addSegment:(id)sender;
-(IBAction)deleteSegment:(id)sender;
-(IBAction)deleteSegmentsFromHere:(id)sender;
-(IBAction)mergeSegment:(id)sender;

@end

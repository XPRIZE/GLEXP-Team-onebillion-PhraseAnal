//
//  WaveView.h
//  playaudiofile
//
//  Created by alan on 29/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VirtualView.h"
#import "RuleView.h"

@class AudioContainer;
@class WaveScroller;
@class PlayPosition;
@class PA_SegmentView;

struct FRange
{
	float origin,width;
	FRange(){origin=0.0;width=0.0;};
	FRange(float o,float w){origin=o;width=w;};
	float Maximum(){return origin + width;};
};

Float32 MaxAudioValue(Float32 *data,UInt64 pos,UInt64 stride);

@interface WaveView : VirtualView<RuleViewSourceView>
{
	IBOutlet AudioContainer *controller;
    NSColor *selColour,*markedColour;
	PlayPosition *playPosition;
	float magnification;	
}


@property (assign) AudioContainer *controller;
@property float magnification;
@property (retain) PlayPosition *playPosition;
@property (assign) IBOutlet PA_SegmentView *segmentView;

-(void)waveFormLoaded;
-(WaveScroller*)scroller;
-(void)movePlayPosition:(float)pos scrollToVisible:(BOOL)scrollToVisible;
-(void)updatePlayPositionScrollToVisible:(BOOL)scrollToVisible;
-(float)maximumMagnification;
-(float)minimumMagnification;
-(void)adjustForSizeChange;
-(void)selectionChanged;
-(void)movePlayPositionX:(double)x;

@end

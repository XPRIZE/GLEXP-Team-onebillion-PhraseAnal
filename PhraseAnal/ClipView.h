//
//  ClipView.h
//  playaudiofile
//
//  Created by alan on 25/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VirtualView.h"

float clamp1(float f);
float clamp0(float f);
float clamp01(float f);

@interface ClipView : NSView 
{
	IBOutlet NSScroller *horizScroller,*vertScroller;
	IBOutlet VirtualView *clientView;
	NSPoint offset;
	BOOL bordered;
	float hScrollerPageIncrement,vScrollerPageIncrement;
}

@property (nonatomic) NSPoint offset;
@property (retain) VirtualView *clientView;
@property (assign) IBOutlet ClipView *nextClipView;

-(NSRect)rectInClientView:(NSRect)r;
-(NSRect)clientVisibleRect;
-(NSRect)clientRectInRect:(NSRect)cr;
-(NSPoint)clientPointFromClipPoint:(NSPoint)clipPoint;
-(NSPoint)clientPointFromWindowPoint:(NSPoint)winPoint;
-(NSPoint)clipPointFromClientPoint:(NSPoint)clientPoint;
-(void)invalidateClientRect:(NSRect)cr;
//- (void)drawRect:(NSRect)dirtyRect;
-(float)xOffsetForHScrollPosition:(float)hpos;
-(float)yOffsetForVScrollPosition:(float)vpos;
-(NSPoint)offsetForHScrollPosition:(float)hpos vScrollPosition:(float)vpos;
-(VirtualView*)clientView;
-(void)refreshScrollers;
-(void)refreshClientView;
-(void)scrollClientPoint:(NSPoint)clientPoint toClipPoint:(NSPoint)clipPoint;
-(void)otherScrollUpdates;
-(void)otherDisplays;
-(IBAction)horizScrollerHit:(id)sender;
-(IBAction)vertScrollerHit:(id)sender;
-(NSScroller*)horizontalScroller;
-(NSScroller*)verticalScroller;
-(float)fractionForXPositionInClientView:(float)x;

@end

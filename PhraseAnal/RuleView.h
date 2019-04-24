//
//  RuleView.h
//  playaudiofile
//
//  Created by alan on 06/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ClipView.h"

@class TrackClipView;
@class PlayPosition;
@class ToolTipView;

@protocol RuleViewSourceView

-(SInt64)frameDuration;
-(long)sampleRate;

@end

@interface RuleView : NSView 
{
	IBOutlet ClipView *clipView;
	PlayPosition *playPosition;
	NSTrackingArea *trackingArea;
	IBOutlet ToolTipView *toolView;
}

@property (assign)PlayPosition *playPosition;
-(void)mouseMovedWindowPoint:(NSPoint)point;

@end

//
//  RuleView.mm
//  playaudiofile
//
//  Created by alan on 06/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "RuleView.h"
#import "PlayPosition.h"
#import "WaveClipView.h"
#import "ToolTipView.h"
#import <QuartzCore/QuartzCore.h>
#import "AudioContainer.h"


@implementation RuleView

@synthesize playPosition;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

-(void)dealloc
{
	[trackingArea release];
	[super dealloc];
}

-(void)awakeFromNib
{
//	[self addToolTipRect:[self bounds]owner:self userData:nil];
	trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds]
												options: (NSTrackingMouseEnteredAndExited | NSTrackingInVisibleRect | NSTrackingActiveInKeyWindow |NSTrackingMouseMoved)
												  owner:self userInfo:nil];
	[self addTrackingArea:trackingArea];
	[[toolView window]setStyleMask:NSBorderlessWindowMask];
}

-(void)drawRuler
{
	VirtualView<RuleViewSourceView> *sourceView = (VirtualView<RuleViewSourceView> *)[clipView clientView];
	NSRect clientBounds = [sourceView bounds];
	NSRect rect = [clipView clientVisibleRect];
	float totalDurationinSeconds = [sourceView frameDuration] * 1.0 / [sourceView sampleRate];
	float timeStart = rect.origin.x / clientBounds.size.width * totalDurationinSeconds;
	float timeEnd = NSMaxX(rect) / clientBounds.size.width * totalDurationinSeconds;
	float minStart = ((int)timeStart) / 60 * 60;
	NSRect b = [self bounds];
	float w = b.size.width;
	while (minStart < timeEnd)
	{
		float px = (minStart - timeStart)/(timeEnd - timeStart) * w;
		if (px >= 0)
			[NSBezierPath strokeLineFromPoint:NSMakePoint(px,0.3 * b.size.height) toPoint:NSMakePoint(px,b.size.height)];
		for (int i = 0;i < 3;i++)
		{
			minStart += 15;
			px = (minStart - timeStart)/(timeEnd - timeStart) * w;
			if (px >= 0)
				[NSBezierPath strokeLineFromPoint:NSMakePoint(px,0.5 * b.size.height) toPoint:NSMakePoint(px,b.size.height)];
		}
			
		minStart += 15;
	}
}

- (void)drawRect:(NSRect)dirtyRect 
{
    [[NSColor colorWithCalibratedRed:1.0 green:1.0 blue:0.7 alpha:1.0]set];
	NSRectFill(dirtyRect);
	[[NSColor blackColor]set];
	[NSBezierPath setDefaultLineWidth:1.0];
	[NSBezierPath strokeRect:[self bounds]];
	[self drawRuler];
	NSPoint offPoint = [clipView offset];
	[[NSGraphicsContext currentContext]saveGraphicsState];
	NSAffineTransform *transform = [NSAffineTransform transform];
	[transform translateXBy:-offPoint.x yBy:0];
	[transform concat];
	[playPosition drawRect:[clipView rectInClientView:dirtyRect]];
	[[NSGraphicsContext currentContext]restoreGraphicsState];
}

- (void)mouseDown:(NSEvent *)theEvent
{
//	[(TrackTableView*)[clipView clientView] trackPlayPositionWithEvent:theEvent];
}

/*- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)userData
{
	VirtualView<RuleViewSourceView> *sourceView = (VirtualView<RuleViewSourceView> *)[clipView clientView];
	NSRect clientBounds = [sourceView bounds];
	NSRect rect = [clipView clientVisibleRect];
	float totalDurationinSeconds = [sourceView frameDuration] * 1.0 / [sourceView sampleRate];
	float timeStart = rect.origin.x / clientBounds.size.width * totalDurationinSeconds;
	float timeEnd = NSMaxX(rect) / clientBounds.size.width * totalDurationinSeconds;
	float time = timeStart + (point.x / [self bounds].size.width * (timeEnd-timeStart));
	return [NSString stringWithFormat:@"%f",time];
}*/

-(float)timeForPoint:(NSPoint)point
{
	VirtualView<RuleViewSourceView> *sourceView = (VirtualView<RuleViewSourceView> *)[clipView clientView];
	NSRect clientBounds = [sourceView bounds];
	NSRect rect = [clipView clientVisibleRect];
	float totalDurationinSeconds = [sourceView frameDuration] * 1.0 / [sourceView sampleRate];
	float timeStart = rect.origin.x / clientBounds.size.width * totalDurationinSeconds;
	float timeEnd = NSMaxX(rect) / clientBounds.size.width * totalDurationinSeconds;
	float time = timeStart + (point.x / [self bounds].size.width * (timeEnd-timeStart));
	return time;
}

-(void)mouseMovedo:(NSEvent *)theEvent
{
	NSPoint point = [theEvent locationInWindow];
	toolView.time = [self timeForPoint:[self convertPoint:point fromView:nil]];
	point = [[self window]convertBaseToScreen:point];
	point.x += 20;
	point.y -= 40;
	[[toolView window]setFrameOrigin:point];
}

-(CATextLayer*)toolTipLayer
{
	return ((WaveClipView*)clipView).toolTipLayer;
}

-(void)adjustToolTipWidth
{
	CATextLayer *toolTip = [self toolTipLayer];
	toolTip.superlayer.zPosition = 10;
	float w = [((WaveClipView*)clipView)toolTipWidth:toolTip.string];
	if (w != toolTip.frame.size.width)
	{
		CGRect f = toolTip.frame;
		float diff = f.origin.x;
		f.size.width = w;
		toolTip.frame = f;
		f = toolTip.superlayer.frame;
		f.size.width =w + diff;
		toolTip.superlayer.frame = f;
	}
}

-(void)mouseMoved:(NSEvent *)theEvent
{
	NSPoint point = [self convertPoint:[theEvent locationInWindow]fromView:nil];
	[self toolTipLayer].string = DurationFromTime([self timeForPoint:point],3);
	[self adjustToolTipWidth];
	point.x += 20;
	point.y -= 40;
	point = [self convertPoint:point toView:clipView];
	point.x = floor(point.x);
	point.y = floor(point.y);
	[self toolTipLayer].superlayer.position = NSPointToCGPoint(point);
}

-(void)mouseMovedWindowPoint:(NSPoint)point
{
	[self toolTipLayer].string = DurationFromTime([self timeForPoint:[self convertPoint:point fromView:nil]],2);
	point.x += 20;
	point.y -= 40;
	point = [self convertPoint:point toView:clipView];
	[self toolTipLayer].superlayer.position = NSPointToCGPoint(point);
}

-(void)mouseMovedWindowPointo:(NSPoint)point
{
	toolView.time = [self timeForPoint:[self convertPoint:point fromView:nil]];
	point = [[self window]convertBaseToScreen:point];
	point.x += 20;
	point.y -= 40;
	[[toolView window]setFrameOrigin:point];
}

-(void)showToolTip:(BOOL)show
{
	[self toolTipLayer].superlayer.hidden = !show; 
}
-(void)mouseEntered:(NSEvent *)theEvent
{
	//[[toolView window]orderFront:self];
	[self mouseMoved:theEvent];
	[self showToolTip:YES];
}

-(void)mouseExited:(NSEvent *)theEvent
{
	//[[toolView window]orderOut:self];
	[self showToolTip:NO];

}
@end

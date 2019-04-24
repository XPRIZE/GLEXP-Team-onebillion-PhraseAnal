//
//  WaveScroller.mm
//  wave
//
//  Created by alan on 29/03/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "WaveScroller.h"
#import "AudioContainer.h"


@implementation WaveScroller

@synthesize bitmap;

+ (CGFloat)scrollerWidth //doesn't get called
{
	return 40.0;
}

+ (CGFloat)scrollerWidthForControlSize:(NSControlSize)controlSize
{
	return [self scrollerWidth];
}

+ (Class)_verticalScrollerClass 
{
	return [WaveScroller class];
}

+ (Class)_horizontalScrollerClass 
{
	return [WaveScroller class];
}

-(void)dealloc
{
	[bitmap release];
	[super dealloc];
}

- (void)drawRect:(NSRect)rect
{
	[self drawKnobSlotInRect:rect highlight:NO];
	[self drawKnob];
	[self drawArrow:NSScrollerIncrementArrow highlight:NO];
	[self drawArrow:NSScrollerDecrementArrow highlight:NO];
}

- (void)drawKnob
{
	NSRect rect = [self rectForPart:NSScrollerKnob];
//	rect.origin.y = 0;rect.size.height = 40;
//	[[NSImage imageNamed:@"transparentbutton"]drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	rect = NSInsetRect(rect,1.0,1.0);
	[[NSColor colorWithCalibratedRed:1.0 green:1.0 blue:0.8 alpha:0.6]set];
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:8 yRadius:8];
	[path fill];
	[path setLineWidth:1.0];
	[[NSColor blackColor]set];
	[path stroke];
}

- (void)drawArrow:(NSScrollerArrow)arrow highlight:(BOOL)flag
{
	if (arrow == NSScrollerIncrementArrow)
	{
		NSRect rect = NSInsetRect([self rectForPart:NSScrollerIncrementLine],1,1);
		[[NSImage imageNamed:@"rightscrollbutton2"]drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
	else if (arrow == NSScrollerDecrementArrow)
	{
		NSRect rect = NSInsetRect([self rectForPart:NSScrollerDecrementLine],1,1);
		[[NSImage imageNamed:@"leftscrollbutton2"]drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
}

- (void)drawKnobSlotInRect:(NSRect)slotRect highlight:(BOOL)flag
{
	NSRect rect = [self rectForPart:NSScrollerKnobSlot];
	[[NSColor colorWithCalibratedWhite:0.9 alpha:1] set];
	NSRectFill(rect);
/*	Track *t = [controller selectedTrack];
	if (t)
	{
		float tf = [t normalisedStartFrame];
		if (tf > 0.0)
		{
			float endf = tf * rect.size.width;
			NSRect r = rect;
			r.size.width = endf;
			[[NSColor grayColor] set];
			NSRectFill(r);
		}
		tf = [t normalisedEndFrame];
		if (tf < 1.0)
		{
			float endf = tf * rect.size.width;
			NSRect r = rect;
			r.origin.x += endf;
			r.size.width = rect.size.width - endf;
			[[NSColor grayColor] set];
			NSRectFill(r);
		}
	}*/
	
	rect = NSInsetRect(rect, 0,1);
	[[NSColor blackColor] set];
	[NSBezierPath strokeRect:rect];
	rect = NSInsetRect(rect, 0,1);
	[bitmap drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
}

- (NSRect)rectForPart:(NSScrollerPart)aPart
{
	NSRect rect = [super rectForPart:aPart];
//	if (aPart == NSScrollerKnob || aPart == NSScrollerKnobSlot)
		rect.origin.y = 0;rect.size.height = 40;
	return rect;
}

- (void)setKnobProportion:(CGFloat)proportion
{
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnob]];
	[super setKnobProportion:proportion];
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnob]];
}

- (void)setFloatValue:(float)aFloat knobProportion:(CGFloat)knobProp
{
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnob]];
	[super setFloatValue:aFloat knobProportion:knobProp];			//just to suppress deprecation warning
	[self setNeedsDisplayInRect:[self rectForPart:NSScrollerKnob]];
}

- (NSScrollerPart)testPart:(NSPoint)aPoint
{
	NSPoint currentPoint = [self convertPoint:aPoint fromView:nil];
	if (NSPointInRect(currentPoint,[self rectForPart:NSScrollerKnob]))
		return NSScrollerKnob;
	if (NSPointInRect(currentPoint,[self rectForPart:NSScrollerDecrementLine]))
		return NSScrollerDecrementLine;
	if (NSPointInRect(currentPoint,[self rectForPart:NSScrollerIncrementLine]))
		return NSScrollerIncrementLine;
	if (NSPointInRect(currentPoint,[self rectForPart:NSScrollerDecrementPage]))
		return NSScrollerDecrementPage;
	if (NSPointInRect(currentPoint,[self rectForPart:NSScrollerIncrementPage]))
		return NSScrollerIncrementPage;
	return [super testPart:aPoint];
}

@end

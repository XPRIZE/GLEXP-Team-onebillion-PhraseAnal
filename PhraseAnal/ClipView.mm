//
//  ClipView.mm
//  playaudiofile
//
//  Created by alan on 25/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ClipView.h"

float clamp1(float f)
{
	if (f > 1.0)
		return 1.0;
	return f;
}

float clamp0(float f)
{
	if (f < 0.0)
		return 0.0;
	return f;
}

float clamp01(float f)
{
	if (f < 0.0)
		return 0.0;
	if (f > 1.0)
		return 1.0;
	return f;
}


@implementation ClipView

@synthesize offset,clientView;

-(void)dealloc
{
 	[clientView release];
	[super dealloc];
}

-(NSRect)rectInClientView:(NSRect)r
{
	return NSOffsetRect(r,offset.x, offset.y);
}

-(NSRect)clientVisibleRect
{
	if (clientView)
		return [self rectInClientView:[self bounds]];
	return NSZeroRect;
}

-(NSRect)clientRectInRect:(NSRect)cr
{
	return NSOffsetRect(cr, -offset.x, -offset.y);
}

-(void)invalidateClientRect:(NSRect)cr
{
	NSRect r = [self clientRectInRect:cr];
	if (NSIntersectsRect(r,[self bounds]))
		[self setNeedsDisplayInRect:r];
}

-(NSPoint)clientPointFromClipPoint:(NSPoint)clipPoint
{
	NSPoint pt;
	pt.x = offset.x + clipPoint.x;
	pt.y = offset.y + clipPoint.y;
	return pt;
}

-(NSPoint)clientPointFromWindowPoint:(NSPoint)winPoint
{
	NSPoint pt = [self convertPoint:winPoint fromView:nil];
	return [self clientPointFromClipPoint:pt];
}

-(NSPoint)clipPointFromClientPoint:(NSPoint)clientPoint
{
	NSPoint pt;
	pt.x = (clientPoint.x - offset.x);
	pt.y = (clientPoint.y - offset.y);
	return pt;
}

/*- (void)drawRect:(NSRect)dirtyRect 
{
	if (clientView)
	{
		[[NSGraphicsContext currentContext]saveGraphicsState];
		NSAffineTransform *transform = [NSAffineTransform transform];
		[transform translateXBy:-offset.x yBy:-offset.y];
		[transform concat];
		[clientView drawRect:[self rectInClientView:dirtyRect]];
		[[NSGraphicsContext currentContext]restoreGraphicsState];
	}
	if (bordered)
	{
		[[NSColor blackColor]set];
		[NSBezierPath setDefaultLineWidth:1.0];
		NSRect b = [self bounds];
//		[NSBezierPath strokeLineFromPoint:NSMakePoint(0.0,NSMaxY(b))toPoint:b.origin]; 
//		[NSBezierPath strokeLineFromPoint:b.origin toPoint:NSMakePoint(NSMaxX(b),0.0)]; 
//		[NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(b),0.0) toPoint:NSMakePoint(NSMaxX(b),NSMaxY(b))]; 
		[NSBezierPath strokeRect:b];
	}
}*/

-(void)setOffset:(NSPoint)pt
{
	if (!NSEqualPoints(pt,offset))
	{
		offset = pt;
		[self setNeedsDisplay:YES];
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	[clientView mouseDown:theEvent];
}

-(float)xOffsetForHScrollPosition:(float)hpos
{
	float scrollpixelwidth = [clientView bounds].size.width - [self bounds].size.width;
	return floor(hpos * scrollpixelwidth);
}

-(float)yOffsetForVScrollPosition:(float)vpos
{
	float scrollpixelheight = [clientView bounds].size.height - [self bounds].size.height;
	return floor((1.0 - vpos) * scrollpixelheight);
}

-(NSPoint)offsetForHScrollPosition:(float)hpos vScrollPosition:(float)vpos
{
	NSPoint f;
	f.x = [self xOffsetForHScrollPosition:hpos];
	f.y = [self yOffsetForVScrollPosition:vpos]; 
	return f;
}

-(float)fractionForXPositionInClientView:(float)x
{
	float pos = x + offset.x;
	return pos / [clientView bounds].size.width;
}

-(void)refreshScrollers
{
	if (horizScroller)
	{
		[horizScroller setKnobProportion:[self bounds].size.width / [clientView bounds].size.width];
		hScrollerPageIncrement = [self bounds].size.width / [clientView bounds].size.width;
		[horizScroller setEnabled:([horizScroller knobProportion] < 1.0)];
	}
	if (vertScroller)
	{
		[vertScroller setKnobProportion:[self bounds].size.height / [clientView bounds].size.height];
		vScrollerPageIncrement = [self bounds].size.height / [clientView bounds].size.height;
		[vertScroller setEnabled:([vertScroller knobProportion] < 1.0)];
	}
}

-(void)refreshClientView
{
	[self setNeedsDisplay:YES];
	if (horizScroller)
		offset.x = [self xOffsetForHScrollPosition:[horizScroller floatValue]];
	if (vertScroller)
		offset.y = [self yOffsetForVScrollPosition:[vertScroller floatValue]];
	[self refreshScrollers];
	[self otherDisplays];
	[self otherScrollUpdates];
}

-(void)frameChanged:(NSNotification *)notification
{
	if ([notification object] == self)
	{
		if (horizScroller)
			offset.x = [self xOffsetForHScrollPosition:[horizScroller floatValue]];
		if (vertScroller)
			offset.y = [self yOffsetForVScrollPosition:[vertScroller floatValue]];
		NSRect clientFrame = clientView.frame;
		if (clientView.autoresizingMask & NSViewHeightSizable)
		{
			clientFrame.origin.x = 0;
			clientFrame.origin.y = 0;
			clientFrame.size.height = [self bounds].size.height;
			//clientFrame.size.width = [self bounds].size.width;
		}
		[clientView setFrame:clientFrame];
		[clientView clipViewFrameChanged];
	}
	[self refreshScrollers];
	[self otherScrollUpdates];
}

-(void)scrollWheel:(NSEvent *)theEvent
{
	float hscrollamount = 0.0,vscrollamount = 0.0;
	if (horizScroller && [horizScroller isEnabled])
	{
		float deltaX = -[theEvent deltaX] * 2;
		hscrollamount = deltaX/[clientView bounds].size.width;
		[horizScroller setFloatValue:clamp01([horizScroller floatValue] + hscrollamount)];
	}
	if (vertScroller && [vertScroller isEnabled])
	{
		float deltaY = -[theEvent deltaY] * 2;
		vscrollamount = deltaY/[clientView bounds].size.height;
		[vertScroller setFloatValue:clamp01([vertScroller floatValue] + vscrollamount)];
	}
	if (hscrollamount != 0.0 || vscrollamount != 0.0)
		[self updateScrolls];
}

-(void)updateFromScrollValues
{
	[self refreshClientView];
	[self otherDisplays];
	[self otherScrollUpdates];
}

-(void)updateScrolls
{
	[self updateFromScrollValues];
	if (_nextClipView)
		[_nextClipView updateFromScrollValues];
}

-(IBAction)horizScrollerHit:(id)sender
{
	float inc = 0.0;
	switch ([horizScroller hitPart]) 
	{
		case NSScrollerIncrementLine:
			inc = hScrollerPageIncrement / 10.0;
			break;
		case NSScrollerIncrementPage:
			inc = hScrollerPageIncrement;
			break;
		case NSScrollerDecrementLine:
			inc = -hScrollerPageIncrement / 10.0;
			break;
		case NSScrollerDecrementPage:
			inc = -hScrollerPageIncrement;
			break;
		case NSScrollerKnob:
			break;
		default:
			break;
	}
	if (inc != 0.0)
		[horizScroller setFloatValue:clamp01([horizScroller floatValue] + inc)];
	[self updateScrolls];
/*	offset.x = [self xOffsetForHScrollPosition:[horizScroller floatValue]];
	[self setNeedsDisplay:YES];
	[self otherDisplays];
	[self otherScrollUpdates];
	if (_nextClipView)
		[_nextClipView horizScrollerHit:sender];*/
}

-(IBAction)vertScrollerHit:(id)sender
{
	float inc = 0.0;
	switch ([vertScroller hitPart]) 
	{
		case NSScrollerIncrementLine:
			inc = vScrollerPageIncrement / 10.0;
			break;
		case NSScrollerIncrementPage:
			inc = vScrollerPageIncrement;
			break;
		case NSScrollerDecrementLine:
			inc = -vScrollerPageIncrement / 10.0;
			break;
		case NSScrollerDecrementPage:
			inc = -vScrollerPageIncrement;
			break;
		case NSScrollerKnob:
			break;
		default:
			break;
	}
	if (inc != 0.0)
		[vertScroller setFloatValue:clamp01([vertScroller floatValue] + inc)];
	[self updateScrolls];
}


-(void)scrollClientPoint:(NSPoint)clientPoint toClipPoint:(NSPoint)clipPoint
{
	if (horizScroller)
	{
		float xOffset = clientPoint.x - clipPoint.x;
		float hVal = xOffset / ([clientView bounds].size.width - [self bounds].size.width);
		[horizScroller setFloatValue:clamp01(hVal)];
	}
	if (vertScroller)
	{
		float yOffset = clientPoint.y - clipPoint.y;
		float vVal = yOffset / ([clientView bounds].size.height - [self bounds].size.height);
		[vertScroller setFloatValue:1.0 - clamp01(vVal)];
	}
	[self updateScrolls];
}

-(NSScroller*)horizontalScroller
{
	return horizScroller;
}

-(NSScroller*)verticalScroller
{
	return vertScroller;
}

-(void)otherScrollUpdates
{
}

-(void)otherDisplays
{
}

-(BOOL)mouseDownCanMoveWindow
{
    return NO;
}

@end

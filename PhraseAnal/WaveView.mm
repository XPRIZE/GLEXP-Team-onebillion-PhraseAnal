//
//  WaveView.mm
//  playaudiofile
//
//  Created by alan on 29/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "WaveView.h"
#import "WaveClipView.h"
#import "AudioContainer.h"
#import "WaveScroller.h"
#import "PlayPosition.h"
#import "PA_SegmentView.h"
#import <Accelerate/Accelerate.h>
#include <string.h>

@implementation WaveView

@synthesize controller,magnification,playPosition;

-(id)init
{
	if ((self = [super init]))
	{
		magnification = 0.1;
		NSRect r = NSMakeRect(0,0,800,400);
		[self setFrame:r];
		autoresizingMask = NSViewMinXMargin|NSViewMaxXMargin|NSViewHeightSizable;
	}
	return self;
}

-(void)dealloc
{
	[playPosition release];
    [selColour release];
    [markedColour release];
	[super dealloc];
}

-(void)awakeFromNib
{
	if (clipView)
	{
		NSRect r = [self frame];
		r.size = [clipView bounds].size;
		[self setFrame:r];
	}
	playPosition = [[PlayPosition alloc]initWithParent:self ruleView:nil];
	[((WaveClipView*)clipView)addPosLayer];
	selColour = [[NSColor colorWithCalibratedRed:0.8 green:0.8 blue:1.0 alpha:0.7]retain];
	markedColour = [[NSColor colorWithCalibratedRed:0.8 green:1.0 blue:0.8 alpha:0.7]retain];
}

-(SInt64)dataWidth
{
	return [controller totalFrames];
}

-(WaveScroller*)scroller
{
	return (WaveScroller*)[clipView horizontalScroller];
}

-(void)adjustMagAndScrollers
{
    
	[NSBezierPath setDefaultLineWidth:1.0];
	WaveScroller *scroller = [self scroller];
	scroller.bitmap = [controller imageRepOfSize:NSInsetRect([scroller rectForPart:NSScrollerKnobSlot],0,1).size];
	[clipView refreshClientView];
	[clipView refreshScrollers];
	[[self scroller]setNeedsDisplay];
    CALayer *l = playPosition.positionLayer;
    CGPoint pos = l.position;
    CGRect f = l.frame;
    CGRect fs = [[l superlayer]bounds];
    f.size.height = fs.size.height;
    f.size.width = 4;
    f.origin.y = 0;
    l.frame = f;
    l.position = pos;
    
}

-(void)adjustForSizeChange
{
    if ([self dataWidth] * magnification < [self frame].size.width)
    {
        magnification = [self frame].size.width / [self dataWidth];
    }
    [self adjustMagAndScrollers];
}

-(void)waveFormLoaded
{
	magnification =  [self frame].size.width / [self dataWidth];
    //[self adjustMagAndScrollers];
	[controller sizeChanged];
}

-(void)clipViewFrameChanged
{
	NSRect cframe = [clipView bounds];
	NSRect f = [self frame];
	f.size.height = cframe.size.height;
	if (cframe.size.width > f.size.width)
		f.size.width = cframe.size.width;
	[self setFrame:f];
	[self adjustForSizeChange];
}

UInt64 ClampInt(UInt64 val,UInt64 minval,UInt64 maxval)
{
	if (val < minval)
		return minval;
	if (val > maxval)
		return maxval;
	return val;
}

-(SInt64)frameForX:(double)x
{
    double pos = x / [self bounds].size.width;
    return pos * [controller totalFrames];
}

-(SInt64)xForFrame:(SInt64)frame
{
    double f = frame * 1.0 / [controller totalFrames];
    return f * [self bounds].size.width;
}


-(void)drawGreyRectFrom:(UInt64)fromx length:(UInt64)len dirtyRect:(NSRect)dirtyRect colour:(NSColor*)col
{
	if (fromx > NSMaxX(dirtyRect) || fromx+len < NSMinX(dirtyRect))
		return;
	NSRect b = [self bounds];
	b.origin.x = fromx;
	b.size.width = len;
	b = NSIntersectionRect(b, dirtyRect);
	[col set];
    [NSBezierPath fillRect:b];
}


Float32 MaxAudioValue(Float32 *data,UInt64 pos,UInt64 stride)
{
	if (stride <= 1)
		return data[pos];
	Float32 res;
	vDSP_maxv(&data[pos], 1, &res, stride);
	return res;
}

Float32 MinAudioValue(Float32 *data,UInt64 pos,UInt64 stride)
{
	if (stride <= 1)
		return data[pos];
	Float32 res;
	vDSP_minv(&data[pos], 1, &res, stride);
	return res;
}

-(void)drawRect:(NSRect)dirtyRect
{
	[[NSColor colorWithDeviceRed:245.0/255 green:245.0/255 blue:245.0/255 alpha:1.0]set];
	NSRectFill(dirtyRect);
	if (controller == nil)
		return;
	int startx = floor(NSMinX(dirtyRect));
	int endx = ceil(NSMaxX(dirtyRect));
	double dataPos = startx /magnification;
	double stride = 1.0 / magnification;
	UInt64 dataWidth = [self dataWidth];
	Float32 *leftData = [controller leftData];
	Float32 *rightData = [controller rightData];
	float middle = NSMidY([self bounds]),q1 = middle / 2,q3 = middle + q1;
	if (rightData)
	{
		NSRect r = NSMakeRect(0,0,[self bounds].size.width,floor(q1)-1);
		[[NSColor colorWithDeviceRed:234.0/255 green:235.0/255 blue:1.0 alpha:1.0]set];
		[[NSBezierPath bezierPathWithRect:r]fill];
		r = NSMakeRect(0,middle,[self bounds].size.width,floor(q1)-1);
		NSRectFill(r);
		[[NSColor colorWithDeviceRed:191.0/255 green:194.0/255 blue:216.0/155 alpha:1.0]set];
		[NSBezierPath strokeLineFromPoint:NSMakePoint(0,middle) toPoint:NSMakePoint([self bounds].size.width,middle)];
		[NSBezierPath strokeLineFromPoint:NSMakePoint(0,q1) toPoint:NSMakePoint([self bounds].size.width,q1)];
		[NSBezierPath strokeLineFromPoint:NSMakePoint(0,q3) toPoint:NSMakePoint([self bounds].size.width,q3)];
	}
	else
	{
		NSRect r = NSMakeRect(0,0,[self bounds].size.width,floor(middle)-1);
		[[NSColor colorWithDeviceRed:234.0/255 green:235.0/255 blue:1.0 alpha:1.0]set];
		[[NSBezierPath bezierPathWithRect:r]fill];
		[[NSColor colorWithDeviceRed:191.0/255 green:194.0/255 blue:216.0/155 alpha:1.0]set];
		[NSBezierPath strokeLineFromPoint:NSMakePoint(0,middle) toPoint:NSMakePoint([self bounds].size.width,middle)];
	}
	[[NSGraphicsContext currentContext]setCompositingOperation:NSCompositeSourceOver];
    selection seln = controller.frameSelection;
    if (seln.length > 0)
    {
        SInt64 st = [self xForFrame:seln.location];
        SInt64 en = [self xForFrame:seln.location + seln.length];
        [self drawGreyRectFrom:st length:en - st dirtyRect:dirtyRect colour:selColour];
    }
    selection marked = controller.markedRange;
    if (marked.length > 0)
    {
        SInt64 st = [self xForFrame:marked.location];
        SInt64 en = [self xForFrame:marked.location + marked.length];
        [self drawGreyRectFrom:st length:en - st dirtyRect:dirtyRect colour:markedColour];
    }
	[[NSColor blackColor]set];
	[NSBezierPath setDefaultLineWidth:1.0];
	NSBezierPath *p1Up=nil,*p2Up=nil;
	NSMutableArray *arr1=[NSMutableArray arrayWithCapacity:100],*arr2=[NSMutableArray arrayWithCapacity:100];
	for (int i = startx;i <= endx;i++)
	{
        if (dataPos < dataWidth)
        {
            UInt64 pos = ClampInt(dataPos,0,dataWidth-1);
            float volume = pow([controller volumeForFrame:pos],3.0);
            Float32 leftval=0,rightval=0;
			SInt64 str = stride;
			if (pos + str > dataWidth)
				str = dataWidth - pos;
            if (rightData)
            {
				//                leftval = fabs(leftData[pos]) * middle;
				//                rightval = fabs(rightData[pos]) * middle;
				leftval = MaxAudioValue(leftData, pos, str)*q1;
				rightval = MinAudioValue(leftData, pos, str)*q1;
				//				[NSBezierPath strokeLineFromPoint:NSMakePoint(i+0.5,q3 + leftval*volume) toPoint:NSMakePoint(i+0.5, q3 + rightval*volume)];
				if (p1Up == nil)
				{
					p1Up = [NSBezierPath bezierPath];
					//					p1Down = [NSBezierPath bezierPath];
					[p1Up moveToPoint:NSMakePoint(i+0.5,q3 + leftval*volume)];
					//					[p1Down moveToPoint:NSMakePoint(i+0.5,q3 + rightval*volume)];
				}
				else
				{
					[p1Up lineToPoint:NSMakePoint(i+0.5,q3 + leftval*volume)];
					//					[p1Down lineToPoint:NSMakePoint(i+0.5,q3 + rightval*volume)];
				}
				[arr1 addObject:[NSValue valueWithPoint:NSMakePoint(i+0.5,q3 + rightval*volume)]];
				leftval = MaxAudioValue(rightData, pos, str)*q1;
				rightval = MinAudioValue(rightData, pos, str)*q1;
				if (p2Up == nil)
				{
					p2Up = [NSBezierPath bezierPath];
					//					p2Down = [NSBezierPath bezierPath];
					[p2Up moveToPoint:NSMakePoint(i+0.5,q1 + leftval*volume)];
					//					[p2Down moveToPoint:NSMakePoint(i+0.5,q1 + rightval*volume)];
				}
				else
				{
					[p2Up lineToPoint:NSMakePoint(i+0.5,q1 + leftval*volume)];
					//					[p2Down lineToPoint:NSMakePoint(i+0.5,q1 + rightval*volume)];
				}
				[arr2 addObject:[NSValue valueWithPoint:NSMakePoint(i+0.5,q1 + rightval*volume)]];
				//				[NSBezierPath strokeLineFromPoint:NSMakePoint(i+0.5,q1 + leftval*volume) toPoint:NSMakePoint(i+0.5, q1 + rightval*volume)];
            }
            else
            {
				//                if (leftData[pos] > 0)
				//                    leftval = (leftData[pos]) * middle;
				//                else
				//                    rightval = fabs(leftData[pos]) * middle;
				leftval = MaxAudioValue(leftData, pos, str) * middle;
				rightval = MinAudioValue(leftData, pos, str) * middle;
				if (p1Up == nil)
				{
					p1Up = [NSBezierPath bezierPath];
					//					p1Down = [NSBezierPath bezierPath];
					[p1Up moveToPoint:NSMakePoint(i+0.5,middle + leftval*volume)];
					//					[p1Down moveToPoint:NSMakePoint(i+0.5,middle + rightval*volume)];
				}
				else
				{
					[p1Up lineToPoint:NSMakePoint(i+0.5,middle + leftval*volume)];
					//					[p1Down lineToPoint:NSMakePoint(i+0.5,middle + rightval*volume)];
				}
				[arr1 addObject:[NSValue valueWithPoint:NSMakePoint(i+0.5,middle + rightval*volume)]];
				//				[NSBezierPath strokeLineFromPoint:NSMakePoint(i+0.5,middle + leftval*volume) toPoint:NSMakePoint(i+0.5, middle + rightval*volume)];
            }
        }
		dataPos += stride;
	}
	if (((int)stride) > 1)
	{
		for (NSValue *v in [arr1 reverseObjectEnumerator])
			[p1Up lineToPoint:[v pointValue]];
		[p1Up setWindingRule:NSEvenOddWindingRule];
		[p1Up fill];
		if (p2Up)
		{
			for (NSValue *v in [arr2 reverseObjectEnumerator])
				[p2Up lineToPoint:[v pointValue]];
			[p2Up setWindingRule:NSEvenOddWindingRule];
			[p2Up fill];
		}
	}
	else
	{
		[p1Up stroke];
		if (p2Up)
			[p2Up stroke];
	}
	//	if (NSIntersectsRect(dirtyRect, playPosition.frame))
	//		[playPosition drawRect:dirtyRect];
}

-(void)selectionChanged
{
	[clipView refreshClientView];
}

-(void)movePlayPosition:(float)pos scrollToVisible:(BOOL)scrollToVisible
{
	float ppos = [self bounds].size.width * pos;
	playPosition.position = NSMakePoint(ppos,playPosition.position.y);
	if (scrollToVisible)
	{
		NSRect visR = [self visibleRect];
		if (ppos >= NSMinX(visR) && ppos < NSMaxX(visR))
			return;
		NSPoint desiredPoint = playPosition.position;
		desiredPoint.x = 0;
		[clipView scrollClientPoint:playPosition.position toClipPoint:desiredPoint];
	}
}

-(void)movePlayPositionX:(double)x
{
	double pos = x / [self bounds].size.width;
	[controller setNormalisedPlayPosition:pos];
	[self updatePlayPositionScrollToVisible:YES];
}

-(void)updatePlayPositionScrollToVisible:(BOOL)scrollToVisible
{
	[self movePlayPosition:[controller normalisedCurrentFrame] scrollToVisible:scrollToVisible];
}

-(float)maximumMagnification
{
	return 10.0;
}

-(float)minimumMagnification
{
	return [clipView bounds].size.width/[self dataWidth];
}


-(void)magnifiWithEvent:(NSEvent *)theEvent
{
	NSUInteger modifierFlags = [theEvent modifierFlags];
	NSPoint clipViewPoint = [[self clipView]convertPoint:[theEvent locationInWindow] fromView:nil];
    NSPoint myPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	//float xfrac = [[self clipView]fractionForXPositionInClientView:desiredPoint.x];
	float xfrac = myPoint.x / [self frame].size.width;
	float mag;
	if ((modifierFlags & NSShiftKeyMask)!=0)
		mag = magnification / 2.0;
	else
		mag = magnification * 2.0;
	if (mag > [self maximumMagnification] || mag < [self minimumMagnification])
		return;
	magnification = mag;
	NSRect f = [self frame];
	f.size.width = [self dataWidth] * magnification;
	[self setFrame:f];
	[clipView refreshClientView];
	//	[controller updatePlayPositionScrollToVisible:YES];
    [clipView scrollClientPoint:NSMakePoint(xfrac*f.size.width,0) toClipPoint:clipViewPoint];
    [[self window] invalidateCursorRectsForView:clipView];
	
	_segmentView.magnification = magnification;
}

-(NSPoint)constrainPointToView:(NSPoint)pt
{
	if (pt.x < 0.0)
		pt.x = 0.0;
	else if (pt.x > NSMaxX([self bounds]))
		pt.x = NSMaxX([self bounds]);
	return pt;
}

-(void)scrub:(NSEvent *)theEvent
{
	NSPoint currentPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSPoint lastPoint = currentPoint;
	[[self window]makeFirstResponder:clipView];
	BOOL wasPlaying = [controller playing];
	if (wasPlaying)
    {
        controller.abort = YES;
		[controller finishPlay];
    }
	[self movePlayPositionX:currentPoint.x];
	BOOL commandDown = (([theEvent modifierFlags] & NSCommandKeyMask)!=0);
	controller.burstBefore = commandDown;
	[controller playBursts];
	while (1)
	{
		theEvent = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask | NSFlagsChangedMask)];
		if ([theEvent type] == NSLeftMouseUp)
			break;
		else if ([theEvent type] == NSFlagsChanged)
		{
			if ((([theEvent modifierFlags] & NSCommandKeyMask)!=0)!=commandDown)
			{
				commandDown = (([theEvent modifierFlags] & NSCommandKeyMask)!=0);
				controller.burstBefore = commandDown;
			}
		}
		else
		{
			currentPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
			currentPoint = [self constrainPointToView:currentPoint];
			if (!NSEqualPoints(currentPoint,lastPoint))
				[self movePlayPositionX:currentPoint.x];
		}
	}
	[controller stopBursts];
	if (wasPlaying)
		[controller play];
}

selection selectionForAnchor(SInt64 anchor,SInt64 length)
{
    selection s;
    if (length < 0)
    {
        s.location = anchor + length;
        s.length = -length;
    }
    else
    {
        s.location = anchor;
        s.length = length;
    }
    return s;
}

-(void)selectWithEvent:(NSEvent *)theEvent
{
	NSPoint currentPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	NSPoint lastPoint = currentPoint;
	[[self window]makeFirstResponder:clipView];
	BOOL wasPlaying = [controller playing];
	if (wasPlaying)
		[controller finishPlay];
    SInt64 anchorFrame = [controller currentFrame];
    selection seln = controller.frameSelection;
    if (seln.length > 0)
    {
        SInt64 mid = seln.location + (seln.length / 2);
        SInt64 currFrame = [self frameForX:currentPoint.x];
        if (currFrame > mid)
            anchorFrame = seln.location;
        else
            anchorFrame = seln.location + seln.length;
    }
    SInt64 selectionLength = [self frameForX:currentPoint.x] - anchorFrame;
    selection s = selectionForAnchor(anchorFrame, selectionLength);
    [controller uSetSelectionTo:s];
	[self movePlayPositionX:currentPoint.x];
	BOOL commandDown = (([theEvent modifierFlags] & NSCommandKeyMask)!=0);
	controller.burstBefore = commandDown;
	[controller playBursts];
	while (1)
	{
		theEvent = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask | NSFlagsChangedMask)];
		if ([theEvent type] == NSLeftMouseUp)
			break;
		else
		{
			currentPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
			currentPoint = [self constrainPointToView:currentPoint];
			if (!NSEqualPoints(currentPoint,lastPoint))
            {
                selectionLength = [self frameForX:currentPoint.x] - anchorFrame;
                s = selectionForAnchor(anchorFrame, selectionLength);
                [controller uSetSelectionTo:s];
				[self movePlayPositionX:currentPoint.x];
            }
		}
	}
	[controller stopBursts];
	if (wasPlaying)
		[controller play];
}

- (void)mouseDown:(NSEvent *)theEvent
{
	NSUInteger modifierFlags = [theEvent modifierFlags];
	if ((modifierFlags & NSAlternateKeyMask)!=0)
	{
		[self magnifiWithEvent:theEvent];
		return;
	}
	else if ((modifierFlags & NSShiftKeyMask)!=0)
	{
		[self selectWithEvent:theEvent];
		return;
	}
	[self scrub:theEvent];
}

-(IBAction)selectAll
{
    
}

-(void)frameChanged
{
    [self adjustForSizeChange];
}

-(SInt64)frameDuration
{
	return [controller totalFrames];
}

-(long)sampleRate
{
	return [controller sampleRate];
}


@end

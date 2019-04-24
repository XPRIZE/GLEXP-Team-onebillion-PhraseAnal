//
//  PA_SegmentView.m
//  PhraseAnal
//
//  Created by alan on 23/11/13.
//  Copyright (c) 2013 Alan C Smith. All rights reserved.
//

#import "PA_SegmentView.h"
#import "PA_SegmentClipView.h"
#import "AudioContainer.h"
#import "PA_Document.h"
#import "Segment.h"

@implementation PA_SegmentView

-(void)dealloc
{
    [_segments release];
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
}

- (id < CAAction >)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
	return (id < CAAction >)[NSNull null];
}

-(SInt64)dataWidth
{
	return [_controller totalFrames];
}

-(void)adjustMagAndScrollers
{
	[clipView refreshClientView];
}

-(SInt64)frameForX:(double)x
{
    double pos = x / [self bounds].size.width;
    return pos * [_controller totalFrames];
}

-(SInt64)xForFrame:(SInt64)frame
{
    double f = frame * 1.0 / [_controller totalFrames];
    return f * [self bounds].size.width;
}


-(void)adjustForSizeChange
{
    if ([self dataWidth] * _magnification < [self frame].size.width)
    {
        _magnification = [self frame].size.width / [self dataWidth];
    }
    [self adjustMagAndScrollers];
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

-(void)setMagnification:(float)magnification
{
	_magnification = magnification;
	NSRect f = [self frame];
	f.size.width = [self dataWidth] * magnification;
	[self setFrame:f];
	[self adjustForSizeChange];
}

-(void)waveFormLoaded
{
	_magnification =  [self frame].size.width / [self dataWidth];
}

-(void)positionArrow:(CALayer*)l toFrame:(UInt64)fr
{
	float x = [self xForFrame:fr] - clipView.offset.x;
	float y = self.frame.size.height / 2.0;
	l.position = CGPointMake(x, y);
}

NSFont *segFont()
{
	return [NSFont systemFontOfSize:16];
}

-(void)drawRect:(NSRect)dirtyRect
{
	for (Segment *s in _segments)
	{
		[self positionArrow:s.beginArrow toFrame:s.range.location];
		[self positionArrow:s.endArrow toFrame:s.range.location + s.range.length];
		CGFloat leftx = MAX([self xForFrame:s.range.location],NSMinX(dirtyRect));
		CGFloat rightx = MIN([self xForFrame:s.range.location + s.range.length],NSMaxX(dirtyRect));
		if (leftx < rightx)
		{
			CGRect f = dirtyRect;
			f.origin.x = leftx;
			f.size.width = rightx - leftx;
			[[NSColor colorWithDeviceRed:255.0/255 green:179.0/255 blue:173.0/255 alpha:1.0]set];
			NSRectFill(f);
			if (s.text != nil)
			{
				CGFloat textleft = [self xForFrame:s.range.location] + 20;
				CGFloat textright = [self xForFrame:s.range.location + s.range.length];
				NSRect bbox = NSMakeRect(textleft, 0, textright - textleft, [self bounds].size.height);
				[[NSGraphicsContext currentContext]saveGraphicsState];
				[[NSBezierPath bezierPathWithRect:bbox]addClip];
				NSDictionary *attrs = [NSDictionary dictionaryWithObject:segFont() forKey:NSFontAttributeName];
				NSSize sz = [s.text sizeWithAttributes:attrs];
				CGFloat y = ([self frame].size.height - sz.height) / 2.0;
				[s.text drawAtPoint:NSMakePoint(textleft, y) withAttributes:attrs];
				[[NSGraphicsContext currentContext]restoreGraphicsState];
			}
			
		}
	}
}

-(void)processSegments:(NSArray*)segs layer:(CALayer*)mainLayer
{
	NSImage *startImage = [NSImage imageNamed:@"leftarrow2"];
	CGRect strect = CGRectZero;
	strect.size = [startImage size];
	NSImage *endImage = [NSImage imageNamed:@"rightarrow2"];
	for (Segment *s in segs)
	{
		CALayer *layer = [CALayer layer];
		layer.contents = (id)[startImage CGImageForProposedRect:NULL context:nil hints:nil];
		layer.frame = strect;
		layer.anchorPoint = CGPointMake(0.0, 0.5);
		layer.delegate = self;
		[mainLayer addSublayer:layer];
		s.beginArrow = layer;
		layer = [CALayer layer];
		layer.contents = (id)[endImage CGImageForProposedRect:NULL context:nil hints:nil];
		layer.frame = strect;
		layer.anchorPoint = CGPointMake(1.0, 0.5);
		layer.delegate = self;
		[mainLayer addSublayer:layer];
		s.endArrow = layer;
	}

}
-(void)processSegmentsForLayer:(CALayer*)mainLayer
{
	self.segments = _controller.doc.segments;
	[self processSegments:_segments layer:mainLayer];
    [self adjustSegmentText];
}

-(BOOL)splitSegmentAtFrame:(SInt64)fr
{
	int idx = [self segmentIndexForFrame:fr];
	if (idx >= 0)
	{
		Segment *olds = [_segments objectAtIndex:idx];
		selection range = olds.range;
		SInt64 endFrame = range.location + range.length;
		range.length = fr - range.location;
		[self uChangeSegment:olds range:range];
		Segment *news = [[[Segment alloc]init]autorelease];
		range.location = fr;
		range.length = endFrame - range.location;
		news.range = range;
		[self uInsertSegment:news atIndex:idx+1];
		[clipView setNeedsDisplay:YES];
        return YES;
	}
    return NO;
}

-(IBAction)mergeSegment:(id)sender
{
    NSPoint pt = [(PA_SegmentClipView*)clipView rightMousePoint];
    int idx = [self segmentIndexForFrame:[self frameForX:pt.x]];
    if (idx > -1 && idx < [_segments count]-1)
    {
        Segment *s1 = [_segments objectAtIndex:idx];
        Segment *s2 = [_segments objectAtIndex:idx+1];
        selection range = s1.range;
        SInt64 endFrame = s2.range.location + s2.range.length;
        range.length = endFrame - range.location;
        [self uChangeSegment:s1 range:range];
        [self uDeleteSegmentAtIndex:idx+1];
        [[self undoManager]setActionName:@"Merge Segment"];
    }
}

-(IBAction)splitSegment:(id)sender
{
	NSPoint pt = [(PA_SegmentClipView*)clipView rightMousePoint];
    if ([self splitSegmentAtFrame:[self frameForX:pt.x]])
		[[self undoManager]setActionName:@"Split Segment"];
}

-(int)indexToFitRange:(selection*)range
{
	for (int i = 0;i < [_segments count];i++)
	{
		Segment *s = _segments[i];
		if (s.range.location > range->location)
		{
			if (range->location + range->length > s.range.location)
				range->length = s.range.location - range->location;
			return i;
		}
		if (s.range.location + s.range.length > range->location)
			return -1;
	}
	return (int)[_segments count];
}

-(BOOL)addSegmentAtFrame:(SInt64)fr
{
	int idx = [self segmentIndexForFrame:fr];
	if (idx == -1)
	{
		Segment *s = [[[Segment alloc]init]autorelease];
		selection r;
		r.location = fr;
		r.length = [_controller sampleRate] / 10.0;
		[self uInsertSegment:s atIndex:[self indexToFitRange:&r]];
		s.range = r;
        return YES;
	}
    return NO;
}

-(IBAction)addSegment:(id)sender
{
	NSPoint pt = [(PA_SegmentClipView*)clipView rightMousePoint];
	int idx = [self segmentIndexForFrame:[self frameForX:pt.x]];
	if (idx == -1)
	{
		Segment *s = [[[Segment alloc]init]autorelease];
		selection r;
		r.location = [self frameForX:pt.x];
		r.length = [_controller sampleRate] / 10.0;
		[self uInsertSegment:s atIndex:[self indexToFitRange:&r]];
		s.range = r;
		[[self undoManager]setActionName:@"Insert Segment"];
	}
}

-(IBAction)deleteSegment:(id)sender
{
	NSPoint pt = [(PA_SegmentClipView*)clipView rightMousePoint];
	int idx = [self segmentIndexForFrame:[self frameForX:pt.x]];
	if (idx > -1)
	{
		[self uDeleteSegmentAtIndex:idx];
		[[self undoManager]setActionName:@"Delete Segment"];
	}
}

-(IBAction)deleteSegmentsFromHere:(id)sender
{
    NSPoint pt = [(PA_SegmentClipView*)clipView rightMousePoint];
    int idx = [self segmentIndexForFrame:[self frameForX:pt.x]];
    if (idx > -1)
    {
        for (int i = (int)[_segments count] - 1;i >= idx;i--)
        {
            [self uDeleteSegmentAtIndex:i];
        }
        [[self undoManager]setActionName:@"Delete Segments"];
    }
}

-(int)segmentIndexForFrame:(UInt64)f
{
	int idx = 0;
	for (Segment *s in _segments)
	{
		if (f < s.range.location)
			return -1;
		if (f < s.range.location + s.range.length)
			return idx;
		idx ++;
	}
	return -1;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	NSPoint pt = [(PA_SegmentClipView*)clipView rightMousePoint];
	int idx = [self segmentIndexForFrame:[self frameForX:pt.x]];
    if (action == @selector(splitSegment:) || action == @selector(deleteSegment:) || action == @selector(deleteSegmentsFromHere:))
    {
        return idx >= 0;
    }
    if (action == @selector(mergeSegment:))
    {
        return idx >= 0 && idx < [_segments count]-1;
    }
	if (action == @selector(addSegment:))
	{
		return idx == -1;
	}
	return NO;

}

enum
{
	SEG_IN_BEGIN_ARROW=1,
	SEG_IN_END_ARROW,
	SEG_IN_SEGMENT
};

-(int)segmentIndexForClipPoint:(NSPoint)pt where:(int*)where
{
	int idx = 0;
	for (Segment *s in _segments)
	{
		*where = 0;
		if (NSPointInRect(pt, s.beginArrow.frame))
			*where = SEG_IN_BEGIN_ARROW;
		else if (NSPointInRect(pt, s.endArrow.frame))
			*where = SEG_IN_END_ARROW;
		else if (pt.x >= s.beginArrow.frame.origin.x && pt.x <= s.endArrow.frame.origin.x + s.endArrow.frame.size.width)
			*where = SEG_IN_SEGMENT;
		if (*where != 0)
			return idx;
		idx ++;
	}
	return -1;
}

#pragma mark
#pragma mark segment moves

-(SInt64)knockOnMovesToLeft:(SInt64)proposedFrame segmentIndex:(int)idx portion:(int)where movedSet:(NSMutableSet*)movedSet
{
    Segment *s = _segments[idx];
    SInt64 lbound = 0;
    if (proposedFrame < lbound)
        return lbound;
    SInt64 significantFrame = proposedFrame;
    if (where == SEG_IN_END_ARROW)
    {
        SInt64 st = s.range.location;
        SInt64 en = st + s.range.length;
        if (st > proposedFrame)
        {
            st = proposedFrame;
            selection range;
            range.location = st;
            range.length = en - st;
            s.range = range;
        }
    }
    int i = idx - 1;
    while (i >= 0)
    {
        Segment *nextseg = _segments[i];
        SInt64 st = nextseg.range.location;
        SInt64 en = st + nextseg.range.length;
        BOOL changed = NO;
        if (st > significantFrame)
        {
            st = significantFrame;
            changed = YES;
        }
        if (en > significantFrame)
        {
            en = significantFrame;
            changed = YES;
        }
        if (changed)
        {
            selection range;
            range.location = st;
            range.length = en - st;
            if (![movedSet containsObject:nextseg])
            {
                [movedSet addObject:nextseg];
                nextseg.oldRange = nextseg.range;
            }
            nextseg.range = range;
            i--;
        }
        else
            break;
    }
    return proposedFrame;
}

-(SInt64)totalLengthsToLeftOfIndex:(int)idx
{
    SInt64 tot = 0;
    for (int i = 0;i < idx;i++)
        tot += ((Segment*)_segments[i]).range.length;
    return tot;
}

-(SInt64)totalLengthsToRightOfIndex:(int)idx
{
    SInt64 tot = 0;
    for (int i = idx+1;i < [_segments count];i++)
        tot += ((Segment*)_segments[i]).range.length;
    return tot;
}

-(SInt64)knockOnRigidMovesToLeft:(SInt64)proposedFrame segmentIndex:(int)idx movedSet:(NSMutableSet*)movedSet
{
    if (idx < 0)
        return proposedFrame;
    Segment *s = _segments[idx];
    if (proposedFrame >= s.range.location + s.range.length)
        return proposedFrame;
    selection range = s.range;
    range.location = proposedFrame - s.range.length;
    if (![movedSet containsObject:s])
    {
        [movedSet addObject:s];
        s.oldRange = s.range;
    }
    s.range = range;
    int i = idx - 1;
    if (i < 0)
        return proposedFrame;
    [self knockOnRigidMovesToLeft:s.range.location segmentIndex:i movedSet:movedSet];
    return proposedFrame;
}

-(SInt64)knockOnRigidMovesToLeft:(SInt64)proposedFrame segmentIndex:(int)idx portion:(int)where movedSet:(NSMutableSet*)movedSet
{
    Segment *s = _segments[idx];
    SInt64 offset = 0;
    if (where == SEG_IN_END_ARROW)
        offset = s.range.length;
    if (proposedFrame >= s.range.location + offset)
        return proposedFrame;
    SInt64 significantFrame = proposedFrame - offset;
    SInt64 lbound = [self totalLengthsToLeftOfIndex:idx];
    if (significantFrame < lbound)
    {
        if (where == SEG_IN_END_ARROW)
        {
            selection range = s.range;
            range.location = lbound;
            range.length = 0;
            s.range = range;
        }
        return lbound + offset;
    }
    if (where == SEG_IN_SEGMENT)
    {
        selection range = s.range;
        range.location = significantFrame;
        s.range = range;
    }
    if (where == SEG_IN_END_ARROW)
    {
        selection range = s.range;
        if (range.location > proposedFrame)
            range.location = proposedFrame;
        range.length = proposedFrame - range.location;
        s.range = range;
    }
    [self knockOnRigidMovesToLeft:significantFrame segmentIndex:idx - 1 movedSet:movedSet];
    return proposedFrame;
}

-(SInt64)knockOnRigidMovesToRight:(SInt64)proposedFrame segmentIndex:(int)idx movedSet:(NSMutableSet*)movedSet
{
    if (idx == [_segments count])
        return proposedFrame;
    Segment *s = _segments[idx];
    if (proposedFrame <= s.range.location)
        return proposedFrame;
    selection range = s.range;
    range.location = proposedFrame;
    if (![movedSet containsObject:s])
    {
        [movedSet addObject:s];
        s.oldRange = s.range;
    }
    s.range = range;
    int i = idx + 1;
    if (i == [_segments count])
        return proposedFrame;
    [self knockOnRigidMovesToRight:s.range.location + s.range.length segmentIndex:i movedSet:movedSet];
    return proposedFrame;
}

-(SInt64)knockOnRigidMovesToRight:(SInt64)proposedFrame segmentIndex:(int)idx portion:(int)where movedSet:(NSMutableSet*)movedSet
{
    Segment *s = _segments[idx];
    SInt64 offset = 0;
    if (where == SEG_IN_END_ARROW)
        offset = s.range.length;
    if (proposedFrame <= s.range.location + offset)
        return proposedFrame;
    SInt64 significantFrame = proposedFrame - offset + s.range.length;
    SInt64 rbound = [self dataWidth] - [self totalLengthsToRightOfIndex:idx];
    if (significantFrame > rbound)
    {
        if (where == SEG_IN_BEGIN_ARROW)
        {
            selection range = s.range;
            range.location = rbound;
            range.length = 0;
            s.range = range;
        }
        return rbound - s.range.length + offset;
    }
    if (where == SEG_IN_SEGMENT)
    {
        selection range = s.range;
        range.location = significantFrame - offset;
        s.range = range;
    }
    if (where == SEG_IN_BEGIN_ARROW)
    {
        selection range = s.range;
        SInt64 en = range.location + range.length;
        if (en < proposedFrame)
            en = proposedFrame;
        range.location = proposedFrame;
        range.length = en - range.location;
        s.range = range;
        //NSLog(@"%lld %lld",s.range.location,s.range.length);
    }
    [self knockOnRigidMovesToRight:significantFrame segmentIndex:idx + 1 movedSet:movedSet];
    return proposedFrame;
}

-(SInt64)knockOnMovesToRight:(SInt64)proposedFrame segmentIndex:(int)idx portion:(int)where movedSet:(NSMutableSet*)movedSet
{
    Segment *s = _segments[idx];
    SInt64 rbound = [self dataWidth];
    if (proposedFrame > rbound)
        return rbound;
    SInt64 significantFrame = proposedFrame;
    if (where == SEG_IN_SEGMENT)
    {
        SInt64 st = proposedFrame;
        SInt64 en = st + s.range.length;
        if (en > rbound)
            return s.range.location;
        selection range = s.range;
        range.location = st;
        s.range = range;
        significantFrame = en;
    }
    else if (where == SEG_IN_BEGIN_ARROW)
    {
        SInt64 st = s.range.location;
        SInt64 en = st + s.range.length;
        if (en < proposedFrame)
        {
            en = proposedFrame;
            selection range;
            range.location = st;
            range.length = en - st;
            s.range = range;
        }
    }
    int i = idx + 1;
    while (i < [_segments count])
    {
        Segment *nextseg = _segments[i];
        SInt64 st = nextseg.range.location;
        SInt64 en = st + nextseg.range.length;
        BOOL changed = NO;
        if (st < significantFrame)
        {
            st = significantFrame;
            changed = YES;
        }
        if (en < significantFrame)
        {
            en = significantFrame;
            changed = YES;
        }
        if (changed)
        {
            selection range;
            range.location = st;
            range.length = en - st;
            if (![movedSet containsObject:nextseg])
            {
                [movedSet addObject:nextseg];
                nextseg.oldRange = nextseg.range;
            }
            nextseg.range = range;
            i++;
        }
        else
            break;
    }
    return proposedFrame;
}

-(void)mouseDown:(NSEvent *)theEvent
{
	BOOL shiftDown = (([theEvent modifierFlags] & NSShiftKeyMask)!=0);
	NSPoint clipPoint = [clipView convertPoint:[theEvent locationInWindow] fromView:nil];
	int where = 0;
	int idx = [self segmentIndexForClipPoint:clipPoint where:&where];
	if (idx >= 0)
	{
		BOOL wasPlaying = [_controller playing];
		if (wasPlaying)
		{
			_controller.abort = YES;
			[_controller finishPlay];
		}
		Segment *s = [_segments objectAtIndex:idx];
		s.oldRange = s.range;
        NSMutableSet *segset = [NSMutableSet setWithCapacity:10];
        [segset addObject:s];
		CGFloat offset;
		SInt64 playPos;
		SInt64 rbound = [self dataWidth],lbound = 0;
		if (where == SEG_IN_END_ARROW)
		{
			offset = s.endArrow.position.x - clipPoint.x;
			playPos = [self xForFrame:s.range.location + s.range.length];
			lbound = s.range.location;
			if (idx < [_segments count] - 1)
				rbound = [_segments[idx + 1] range].location;
		}
		else
		{
			offset = s.beginArrow.position.x - clipPoint.x;
			playPos = [self xForFrame:s.range.location];
			if (idx > 0)
				lbound = [_segments[idx - 1] range].location + [_segments[idx - 1] range].length;
			if (where == SEG_IN_BEGIN_ARROW)
				rbound = s.range.location + s.range.length;
			else
			{
				if (idx < [_segments count] - 1)
					rbound = [_segments[idx + 1] range].location - s.range.length;
				else
					rbound = [self dataWidth] - s.range.length;
			}
		}
		[_waveView movePlayPositionX:playPos];
		BOOL startedPlaying = NO;
		while (1)
		{
			theEvent = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask/* | NSFlagsChangedMask*/)];
			if ([theEvent type] == NSLeftMouseUp)
				break;
			else
			{
                BOOL commandDown = (([theEvent modifierFlags] & NSCommandKeyMask)!=0);
                BOOL altDown = (([theEvent modifierFlags] & NSAlternateKeyMask)!=0);
				clipPoint = [clipView convertPoint:[theEvent locationInWindow] fromView:nil];
				if (where == SEG_IN_END_ARROW)
				{
					CALayer *l = s.endArrow;
					NSPoint pt = l.position;
					pt.x = clipPoint.x + offset + clipView.offset.x;
					SInt64 fr = [self frameForX:pt.x];
					if (fr > rbound)
                    {
                        if (commandDown)
                        {
                            if (altDown)
                                fr = [self knockOnRigidMovesToRight:fr segmentIndex:idx portion:where movedSet:segset];
                            else
                                fr = [self knockOnMovesToRight:fr segmentIndex:idx portion:where movedSet:segset];
                        }
                        else
                            fr = rbound;
                    }
					else if (fr < lbound)
                        {
                            if (commandDown)
                            {
                                if (altDown)
                                    fr = [self knockOnRigidMovesToLeft:fr segmentIndex:idx portion:where movedSet:segset];
                                else
                                    fr = [self knockOnMovesToLeft:fr segmentIndex:idx portion:where movedSet:segset];
                            }
                            else
                                fr = lbound;
                        }
					selection r = s.range;
					r.length = fr - r.location;
					s.range = r;
					playPos = [self xForFrame:fr];
				}
				else if (where == SEG_IN_BEGIN_ARROW)
				{
					CALayer *l = s.beginArrow;
					NSPoint pt = l.position;
					pt.x = clipPoint.x + offset + clipView.offset.x;
					SInt64 fr = [self frameForX:pt.x];
					if (fr > rbound)
                    {
                        if (commandDown)
                        {
                            if (altDown)
                                fr = [self knockOnRigidMovesToRight:fr segmentIndex:idx portion:where movedSet:segset];
                            else
                                fr = [self knockOnMovesToRight:fr segmentIndex:idx portion:where movedSet:segset];
                        }
                        else
                            fr = rbound;
                    }
					else if (fr < lbound)
                    {
                        if (commandDown)
                        {
                            if (altDown)
                                fr = [self knockOnRigidMovesToLeft:fr segmentIndex:idx portion:where movedSet:segset];
                            else
                                fr = [self knockOnMovesToLeft:fr segmentIndex:idx portion:where movedSet:segset];
                        }
                        else
                            fr = lbound;
                    }
					selection r = s.range;
					SInt64 endr = r.location + r.length;
					r.location = fr;
					r.length = endr - r.location;
					s.range = r;
					playPos = [self xForFrame:fr];
				}
				else if (where == SEG_IN_SEGMENT)
				{
					CALayer *l = s.beginArrow;
					NSPoint pt = l.position;
					pt.x = clipPoint.x + offset + clipView.offset.x;
					SInt64 fr = [self frameForX:pt.x];
					if (fr > rbound)
                    {
                        if (commandDown)
                        {
                            if (altDown)
                                fr = [self knockOnRigidMovesToRight:fr segmentIndex:idx portion:where movedSet:segset];
                            else
                                fr = [self knockOnMovesToRight:fr segmentIndex:idx portion:where movedSet:segset];
                        }
                        else
                            fr = rbound;
                    }
					else if (fr < lbound)
                    {
                        if (commandDown)
                        {
                            if (altDown)
                                fr = [self knockOnRigidMovesToLeft:fr segmentIndex:idx portion:where movedSet:segset];
                            else
                                fr = [self knockOnMovesToLeft:fr segmentIndex:idx portion:where movedSet:segset];
                        }
                        else
                            fr = lbound;
                    }
					selection r = s.range;
					r.location = fr;
					s.range = r;
					playPos = [self xForFrame:fr];
				}
				[_waveView movePlayPositionX:playPos];
				if (!startedPlaying)
				{
					startedPlaying = YES;
					_controller.burstBefore = (where != SEG_IN_END_ARROW);
					[_controller playBursts];
				}
				[clipView setNeedsDisplay:YES];
			}
		}
		if (startedPlaying)
		{
			[_controller stopBursts];
            for (Segment *ss in segset)
                [[[self undoManager] prepareWithInvocationTarget:self] uChangeSegment:ss range:ss.oldRange];
			NSString *title;
			if (where == SEG_IN_END_ARROW)
				title = @"Move Segment End";
			else if (where == SEG_IN_BEGIN_ARROW)
				title = @"Move Segment Start";
			else
				title = @"Move Segment";
			[[self undoManager]setActionName:title];
		}
		else
		{
			if (!shiftDown)
				[_controller playRange:s.range];
		}
	}
	[[self window]makeFirstResponder:[_waveView clipView]];
}

#pragma mark
#pragma mark segment changes

-(void)adjustSegmentText
{
	[_controller.doc applyText];
}

-(BOOL)uDeleteSegmentAtIndex:(int)idx
{
	Segment *s = _segments[idx];
	[s.beginArrow removeFromSuperlayer];
	s.beginArrow.delegate = nil;
	s.beginArrow = nil;
	[s.endArrow removeFromSuperlayer];
	s.endArrow.delegate = nil;
	s.endArrow = nil;
	[[[self undoManager] prepareWithInvocationTarget:self] uInsertSegment:s atIndex:idx];
	[_segments removeObjectAtIndex:idx];
	[self adjustSegmentText];
	[clipView setNeedsDisplay:YES];
	return YES;
}

-(BOOL)uInsertSegment:(Segment*)s atIndex:(int)idx
{
	[[[self undoManager] prepareWithInvocationTarget:self] uDeleteSegmentAtIndex:idx];
	[self processSegments:@[s] layer:((PA_SegmentClipView*)clipView).layer];
	[_segments insertObject:s atIndex:idx];
	[self adjustSegmentText];
    [clipView setNeedsDisplay:YES];
    return YES;
}

-(BOOL)uChangeSegment:(Segment*)s range:(selection)range
{
	[[[self undoManager] prepareWithInvocationTarget:self] uChangeSegment:s range:s.range];
	s.range = range;
    [clipView setNeedsDisplay:YES];
	return YES;
}
@end

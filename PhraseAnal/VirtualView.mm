//
//  VirtualView.mm
//  playaudiofile
//
//  Created by alan on 27/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "VirtualView.h"
#import "ClipView.h"

NSRect rectFromPoints(NSPoint pt1,NSPoint pt2)
{
	float minX = MIN(pt1.x,pt2.x);
	float minY = MIN(pt1.y,pt2.y);
	float maxX = MAX(pt1.x,pt2.x);
	float maxY = MAX(pt1.y,pt2.y);
	return NSMakeRect(minX,minY,maxX-minX,maxY-minY);
}

@implementation VirtualView

@synthesize clipView,autoresizingMask;

-(id)init
{
	if ((self = [super init]))
	{
		_frame = NSMakeRect(0,0, 1200, 40);
		_bounds = _frame;
	}
	return self;
}

- (id)initWithFrame:(NSRect)frame 
{
	if ((self = [super init]))
	{
		_frame = frame;
		_bounds = frame;
		_bounds.origin.x = 0.0;
		_bounds.origin.y = 0.0;
	}
	return self;
}

-(void)dealloc
{
	[super dealloc];
}

-(NSRect)frame
{
	return _frame;
}

-(void)setFrame:(NSRect)f
{
    if (!NSEqualRects(f, _frame))
    {
        _frame = f;
        _bounds = _frame;
        _bounds.origin.x = 0.0;
        _bounds.origin.y = 0.0;
        [self frameChanged];
    }
}

-(void)frameChanged
{
    
}

-(void)clipViewFrameChanged
{
}

-(NSRect)bounds
{
	return _bounds;
}

-(void)setBounds:(NSRect)f
{
	_bounds = f;
}

- (void)mouseDown:(NSEvent *)theEvent
{
}

- (void)drawRect:(NSRect)dirtyRect
{
}

-(NSUndoManager*)undoManager
{
	return [clipView undoManager];
}

-(NSRect)visibleRect
{
	return [clipView clientVisibleRect];
}

-(void)setNeedsDisplayInRect:(NSRect)invalidRect
{
	[clipView invalidateClientRect:invalidRect];
}

-(void)setNeedsDisplay
{
	[self  setNeedsDisplayInRect:[self bounds]];
}

-(void)setNeedsDisplay:(BOOL)b
{
	[self  setNeedsDisplay];
}

- (NSPoint)convertPoint:(NSPoint)aPoint fromView:(NSView *)aView
{
	return [clipView clientPointFromWindowPoint:aPoint];
}

- (NSPoint)convertPointToBase:(NSPoint)aPoint
{
	NSPoint pt = [clipView clipPointFromClientPoint:aPoint];
	return [clipView convertPointToBase:pt];
}

-(NSWindow*)window
{
	return [clipView window];
}


@end

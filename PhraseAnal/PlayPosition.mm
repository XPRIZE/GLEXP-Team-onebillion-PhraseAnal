//
//  PlayPosition.mm
//  playaudiofile
//
//  Created by alan on 05/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PlayPosition.h"
#import "VirtualView.h"
#import "RuleView.h"


@implementation PlayPosition

@synthesize width,ruleView,positionLayer;

-(id)initWithParent:(VirtualView*)ttv ruleView:(NSView*)rv
{
	if ((self = [super init]))
	{
		mainView = ttv;
		width = 4.0;
		ruleView = rv;
		if (rv && [rv isKindOfClass:[RuleView class]])
			((RuleView*)rv).playPosition = self;
		positionLayer = [[CALayer layer]retain];
		CGRect f = NSRectToCGRect([ttv.clipView bounds]);
		f.size.width = width;
		positionLayer.frame=f;
		CGFloat cols[4] = {1.0,0.0,0.0,1.0};
		positionLayer.backgroundColor = CGColorCreate([[NSColorSpace genericRGBColorSpace]CGColorSpace], cols);
		CGColorRelease(positionLayer.backgroundColor);
		//positionLayer.autoresizingMask = kCALayerHeightSizable|kCALayerMinXMargin|kCALayerMaxXMargin;
		positionLayer.autoresizingMask = kCALayerHeightSizable;
		[positionLayer setDelegate:self];
	}
	return self;
}

-(void)dealloc
{
    positionLayer.delegate = nil;
	[positionLayer release];
	[super dealloc];
}

-(NSRect)frame
{
	NSRect f = [mainView bounds];
	f.origin = position;
	f.origin.x -= width / 2;
	f.size.width = width;
	return f;
}

- (id < CAAction >)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
	//return nil;
	return (id < CAAction >)[NSNull null];
}

-(void)setNeedsDisplay
{
	[mainView setNeedsDisplayInRect:self.frame];
	if (ruleView)
	{
		NSPoint off = [mainView visibleRect].origin;
		NSRect offRect = NSOffsetRect(self.frame, -off.x, 0);
		offRect = NSInsetRect(offRect, -1.0, -1.0);
		[ruleView setNeedsDisplayInRect:offRect];
	}
}

- (void)drawRect:(NSRect)dirtyRect
{
	[[NSColor redColor]set];
	NSRectFill(self.frame);
}

-(NSPoint)position
{
	return position;
}

-(void)setPosition:(NSPoint)pt
{
	//[self setNeedsDisplay];
	position = pt;
	//[self setNeedsDisplay];
	NSPoint offset = mainView.clipView.offset;
	CGPoint actualPoint = NSPointToCGPoint(position);
	actualPoint.x -= offset.x;
	actualPoint.y = positionLayer.position.y;
	positionLayer.position = actualPoint;
}

-(id)hitTest:(NSPoint)aPoint
{
	if (NSPointInRect(aPoint,self.frame))
		return self;
	return nil;
}


@end

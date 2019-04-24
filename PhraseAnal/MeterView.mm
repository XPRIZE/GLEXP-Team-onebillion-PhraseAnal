//
//  MeterView.mm
//  playaudiofile
//
//  Created by alan on 23/03/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MeterView.h"

#define GREEN_LEVEL 0.6
#define YELLOW_LEVEL 0.8

@implementation MeterView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
		leftLevel = rightLevel = -100;
    }
    return self;
}

-(void)awakeFromNib
{
	CALayer *rootLayer = [CALayer layer];
	[self setLayer:rootLayer];
	NSRect b = [self bounds];
	rootLayer.frame=NSRectToCGRect(b);
	[rootLayer setDelegate:self];
	[self setWantsLayer:YES];
	[rootLayer setNeedsDisplay];
	b.size.width /= 2;
	leftLayer = [CALayer layer];
	leftLayer.frame=NSRectToCGRect(b);
	[leftLayer setDelegate:self];
	[leftLayer setNeedsDisplay];
	[rootLayer addSublayer:leftLayer];
	b.origin.x = NSMaxX(b);
	rightLayer = [CALayer layer];
	rightLayer.frame=NSRectToCGRect(b);
	[rightLayer setDelegate:self];
	[rightLayer setNeedsDisplay];
	[rootLayer addSublayer:rightLayer];
}

- (void)drawRect:(NSRect)dirtyRect 
{
}

-(void)drawBlock:(int)blockNo colour:(NSColor*)col
{
	NSRect r = [self bounds];
	r.size.height /= 20;
	r.origin.y = r.size.height * blockNo;
	r.size.width /= 2;
	NSRect s = r;
	s.origin.x = NSMaxX(r);
	[col set];
	[[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(r,2,2) xRadius:2.0 yRadius:2.0]fill];
	[[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(s,2,2) xRadius:2.0 yRadius:2.0]fill];
	[[NSColor colorWithCalibratedWhite:1.0 alpha:0.7] set];
	r.origin.y += (r.size.height - 8);
	r.size.height -= (r.size.height - 8);
	s.origin.y += (s.size.height - 8);
	s.size.height -= (s.size.height - 8);
	[[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(r,2,2) xRadius:2.0 yRadius:2.0]fill];
	[[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(s,2,2) xRadius:2.0 yRadius:2.0]fill];
//	NSRectFill(NSInsetRect(r,2,2));
//	NSRectFill(NSInsetRect(s,2,2));
}

-(void)drawRootLayer:(CGContextRef)theContext
{
	NSGraphicsContext *oldContext = [NSGraphicsContext currentContext];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:theContext flipped:NO]];
	NSRect b = [self bounds];
	[[NSColor blackColor] set];
	NSRectFill(b);
	int i;
	for (i = 0;i < 12;i++)
		[self drawBlock:i colour:[NSColor greenColor]];
	for (;i < 18;i++)
		[self drawBlock:i colour:[NSColor yellowColor]];
	for (;i < 20;i++)
		[self drawBlock:i colour:[NSColor redColor]];
	[NSGraphicsContext setCurrentContext:oldContext];
}

float FrigAndClamp(float val)
{
//	val = (val + 17) / 20.0;
	val = (val + 37) / 40.0;
	if (val > 1.0)
		val = 1.0;
	else if (val < 0.0)
		val = 0.0;
	return val;
}

-(void)drawOtherLayer:(CALayer*)layer context:(CGContextRef)theContext
{
	NSGraphicsContext *oldContext = [NSGraphicsContext currentContext];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:theContext flipped:NO]];
	NSRect b = NSRectFromCGRect(layer.bounds);
	float level = (layer == leftLayer)?leftLevel:rightLevel;
	b.origin.y = (b.size.height) * FrigAndClamp(level);
	b.size.height -= b.origin.y;
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.8] set];
	NSRectFill(b);
	[NSGraphicsContext setCurrentContext:oldContext];
}

- (void)drawLayer:(CALayer *)theLayer inContext:(CGContextRef)theContext
{
	if (theLayer == [self layer])
		[self drawRootLayer:theContext];
	else
		[self drawOtherLayer:theLayer context:theContext];
}

-(void)setLevelLeft:(AudioUnitParameterValue)l right:(AudioUnitParameterValue)r
{
	if (leftLevel != l || rightLevel != r)
	{
		leftLevel = l;
		rightLevel = r;
		[leftLayer setNeedsDisplay];
		[rightLayer setNeedsDisplay];
	}
}


@end

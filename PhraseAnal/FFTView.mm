//
//  FFTView.m
//  AuEd
//
//  Created by Alan on 08/11/2012.
//
//

#import "FFTView.h"

@implementation FFTView

@synthesize audioContainer;

- (void)drawRect:(NSRect)dirtyRect
{
    double *data0 =[audioContainer fftData0];
    if (data0 == nil)
        return;
    double *data1 =[audioContainer fftData1];
    [[NSColor blackColor]set];
    float width = [self bounds].size.width;
	float height;
	if (data1)
		height = [self bounds].size.height / 2;
	else
		height = [self bounds].size.height;
	[[NSGraphicsContext currentContext]saveGraphicsState];
	NSBezierPath *clipPath = [NSBezierPath bezierPathWithRect:NSMakeRect(0, 0, width, height)];
	[clipPath addClip];
    float xscale = width / (FFT_BUFFER_SIZE / 2);
	float yscale = 1.0;
    NSAffineTransform *t = [NSAffineTransform transform];
    [t scaleXBy:xscale yBy:yscale /*[self bounds].size.height/10.0*/];
    [t concat];
	[NSBezierPath setDefaultLineWidth:1.0];
    for (int i = 0;i < FFT_BUFFER_SIZE / 2;i++)
	{
		double val =  (data0[i] + 60)/100.0 * height/2;
        [NSBezierPath strokeLineFromPoint:NSMakePoint(i, 0) toPoint:NSMakePoint(i,val)];
	}
	[[NSGraphicsContext currentContext]restoreGraphicsState];
    if (data1 == nil)
        return;
	clipPath = [NSBezierPath bezierPathWithRect:NSMakeRect(0, height, width, height+height)];
	[clipPath addClip];
    t = [NSAffineTransform transform];
	[t translateXBy:0.0 yBy:height];
	[t concat];
    t = [NSAffineTransform transform];
    [t scaleXBy:xscale yBy:yscale /*[self bounds].size.height/10.0*/];
    [t concat];
	[NSBezierPath setDefaultLineWidth:1.0];
    for (int i = 0;i < FFT_BUFFER_SIZE / 2;i++)
	{
		double val =  (data0[i] + 60)/100.0 * height/2;
        [NSBezierPath strokeLineFromPoint:NSMakePoint(i, 0) toPoint:NSMakePoint(i,val)];
	}
}

@end

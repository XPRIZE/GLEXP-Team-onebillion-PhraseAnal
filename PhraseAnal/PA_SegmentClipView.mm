//
//  PA_SegmentClipView.m
//  PhraseAnal
//
//  Created by alan on 23/11/13.
//  Copyright (c) 2013 Alan C Smith. All rights reserved.
//

#import "PA_SegmentClipView.h"
#import "AudioContainer.h"
#import "PA_SegmentView.h"

@implementation PA_SegmentClipView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
	{
		mainLayer = [CALayer layer];
		[self setLayer:mainLayer];
		mainLayer.frame=NSRectToCGRect([self bounds]);
		CGFloat blackColour[4] = {0.0,0.0,0.0,1.0};
		CGFloat back2Colour[4] = {178/255.0,203/255.0,213/255.0,1.0};
		
		CGColorSpaceRef cref = CGColorSpaceCreateDeviceRGB();
		CGColorRef bordercol = CGColorCreate(cref,blackColour);
		mainLayer.borderColor = bordercol;
		CGColorRef back2col = CGColorCreate(cref,back2Colour);
		mainLayer.backgroundColor = back2col;
		mainLayer.borderColor = bordercol;
		mainLayer.borderWidth = 1.0;
		
		[mainLayer setDelegate:self];
		mainLayer.autoresizingMask = kCALayerWidthSizable|kCALayerHeightSizable;
		[self setWantsLayer:YES];
		[mainLayer setNeedsDisplay];
		
		/*CALayer *frameLayer = [CALayer layer];
		frameLayer.frame=CGRectMake(0,0,58,22);
		CGFloat backColour[4] = {1.0,1.0,0.7,1.0};
		CGColorRef backcol = CGColorCreate(cref,backColour);
		frameLayer.backgroundColor = backcol;
		frameLayer.borderColor = bordercol;
		frameLayer.borderWidth = 1.0;
		frameLayer.delegate = self;*/
		CGColorRelease(bordercol);
		CGColorRelease(back2col);
		//CGColorRelease(backcol);
		CGColorSpaceRelease(cref);
		
    }
    return self;
}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter]removeObserver:self];
	mainLayer.delegate = nil;
    for (CALayer *layer in [mainLayer sublayers])
        layer.delegate = nil;
	[super dealloc];
}

-(BOOL)acceptsFirstResponder
{
	return YES;
}

-(void)awakeFromNib
{
	[super awakeFromNib];
	bordered = YES;
	[self setPostsFrameChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(frameChanged:) name:NSViewFrameDidChangeNotification object:self];
}

-(void)setNeedsDisplay:(BOOL)flag
{
	[mainLayer setNeedsDisplay];
}

-(void)setController:(AudioContainer *)c
{
	_controller = c;
	((PA_SegmentView*)clientView).controller = c;
	[((PA_SegmentView*)clientView) waveFormLoaded];
	[((PA_SegmentView*)clientView) processSegmentsForLayer:mainLayer];
	[self setNeedsDisplay:YES];
}


- (void)drawLayer:(CALayer *)theLayer inContext:(CGContextRef)theContext
{
	if (theLayer == mainLayer)
	{
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:theContext flipped:NO]];
		[[NSGraphicsContext currentContext]saveGraphicsState];
		CGRect dirtyRect = CGContextGetClipBoundingBox(theContext);
		NSAffineTransform *transform = [NSAffineTransform transform];
		[transform translateXBy:-offset.x yBy:-offset.y];
		[transform concat];
		[clientView drawRect:[self rectInClientView:NSRectFromCGRect(dirtyRect)]];
		
		[[NSGraphicsContext currentContext]restoreGraphicsState];
		[NSGraphicsContext restoreGraphicsState];
	}
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
	_rightMousePoint = [self clientPointFromClipPoint:[self convertPoint:[theEvent locationInWindow]fromView:nil]];
	[super rightMouseDown:theEvent];
}

-(IBAction)mergeSegment:(id)sender
{
    [(PA_SegmentView*)clientView mergeSegment:sender];
}

-(IBAction)splitSegment:(id)sender
{
	[(PA_SegmentView*)clientView splitSegment:sender];
}

-(IBAction)addSegment:(id)sender
{
	[(PA_SegmentView*)clientView addSegment:sender];
}

-(IBAction)deleteSegment:(id)sender
{
    [(PA_SegmentView*)clientView deleteSegment:sender];
}

-(IBAction)deleteSegmentsFromHere:(id)sender
{
    [(PA_SegmentView*)clientView deleteSegmentsFromHere:sender];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	return [clientView validateMenuItem:menuItem];
}
@end

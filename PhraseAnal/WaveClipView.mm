//
//  WaveClipView.mm
//  playaudiofile
//
//  Created by alan on 29/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "WaveClipView.h"
#import "WaveView.h"
#import "AudioContainer.h"
#import "PlayViewCursor.h"
#import "RuleView.h"
#import "PlayPosition.h"
#import "PA_Document.h"

@implementation WaveClipView

@synthesize controller,toolTipLayer;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) 
	{
		mainLayer = [CALayer layer];
		[self setLayer:mainLayer];
		mainLayer.frame=NSRectToCGRect([self bounds]);
		CGFloat blackColour[4] = {0.0,0.0,0.0,1.0};
		
		CGColorSpaceRef cref = CGColorSpaceCreateDeviceRGB();
		CGColorRef bordercol = CGColorCreate(cref,blackColour);
		mainLayer.borderColor = bordercol;
		mainLayer.borderWidth = 1.0;

		[mainLayer setDelegate:self];
		mainLayer.autoresizingMask = kCALayerWidthSizable|kCALayerHeightSizable;
		[self setWantsLayer:YES];
		[mainLayer setNeedsDisplay];
		
		CALayer *frameLayer = [CALayer layer];
		frameLayer.frame=CGRectMake(0,0,58,22);
		CGFloat backColour[4] = {1.0,1.0,0.7,1.0};
		CGColorRef backcol = CGColorCreate(cref,backColour);
		frameLayer.backgroundColor = backcol;
		frameLayer.borderColor = bordercol;
		frameLayer.borderWidth = 1.0;
		//frameLayer.shadowColor = bordercol;
		//frameLayer.shadowOffset = CGSizeMake(5, 5);
		frameLayer.shadowOpacity = 0.3;
		frameLayer.delegate = self;
		
		toolTipLayer = [CATextLayer layer];
		toolTipLayer.frame=CGRectMake(4,0,54,18);
		
		toolTipLayer.foregroundColor = bordercol;
		toolTipLayer.fontSize = 14;
		CGColorRelease(bordercol);
		CGColorRelease(backcol);
		CGColorSpaceRelease(cref);
		[mainLayer addSublayer:frameLayer];
		[frameLayer addSublayer:toolTipLayer];
		toolTipLayer.superlayer.hidden = YES;
    }
    return self;
}

-(float)toolTipWidth:(NSString*)str
{
	NSUInteger ct = [str length];
	if (toolTipWidth[ct] == 0)
	{
		NSFont *f = [NSFont systemFontOfSize:toolTipLayer.fontSize];
		NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:f,NSFontAttributeName, nil];
		toolTipWidth[ct] = ceil([str sizeWithAttributes:dict].width);
	}
	return toolTipWidth[ct];
}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter]removeObserver:self];
	[super dealloc];
}

-(void)addPosLayer
{
	CALayer *posLayer = ((WaveView*)clientView).playPosition.positionLayer;
	[mainLayer addSublayer:posLayer];

}
-(void)awakeFromNib
{
	[super awakeFromNib];
	//[self performSelector:@selector(addPosLayer) withObject:nil afterDelay:0.01];
	//[self addPosLayer];
	bordered = YES;
	[self setPostsFrameChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(frameChanged:) name:NSViewFrameDidChangeNotification object:self];
    [self registerForDraggedTypes:@[NSURLPboardType]];
}

-(void)otherScrollUpdates
{
	[ruleView setNeedsDisplay:YES];
	[((WaveView*)clientView)updatePlayPositionScrollToVisible:NO];
}

-(void)setController:(AudioContainer *)c
{
	controller = c;
	((WaveView*)clientView).controller = c;
	[((WaveView*)clientView) waveFormLoaded];
}

- (void)resetCursorRects
{
	NSUInteger modifierFlags = [[[self window]currentEvent]modifierFlags];
	WaveView *waveView = (WaveView*)clientView;
	if ((modifierFlags & NSAlternateKeyMask)!=0)
	{
		if ((modifierFlags & NSShiftKeyMask)!=0)
			if (waveView.magnification / 2 < [waveView minimumMagnification])
				[self addCursorRect:[self visibleRect] cursor:[NSCursor magNoneCursor]];
			else
				[self addCursorRect:[self visibleRect] cursor:[NSCursor magMinusCursor]];
		else
			if (waveView.magnification * 2 > [waveView maximumMagnification])
				[self addCursorRect:[self visibleRect] cursor:[NSCursor magNoneCursor]];
			else
				[self addCursorRect:[self visibleRect] cursor:[NSCursor magPlusCursor]];
		return;
	}
}

- (void)flagsChanged:(NSEvent *)theEvent
{
    [[self window] invalidateCursorRectsForView:self];
}

- (void)keyDown:(NSEvent *)event
{
	NSString *str = [event charactersIgnoringModifiers];
	if ([str isEqualToString:@" "])
	{
	    [[(WaveView*)clientView controller] spaceHit];
	} 
	else
		[super keyDown:event];
}

-(void)selectAll:(id)sender
{
    [controller selectAll];
}

-(void)selectNone:(id)sender
{
    [controller selectNone];
}

-(void)setInPoint:(id)sender
{
	[controller setInPoint];
}

-(void)setOutPoint:(id)sender
{
	[controller setOutPoint];
}

-(void)goToInPoint:(id)sender
{
	[controller goToInPoint];
}

-(void)goToOutPoint:(id)sender
{
	[controller goToOutPoint];
}

-(void)selectMarked:(id)sender
{
	[controller selectMarked];
}

-(BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	if (action == @selector(exportSelection:)||action == @selector(clear:)||action == @selector(cut:))
	{
		if (controller == nil)
			return NO;
		return controller.frameSelection.length > 0;
	}
	if (action == @selector(goToInPoint:)||action == @selector(goToOutPoint:)||action == @selector(selectMarked:))
	{
		if (controller == nil)
			return NO;
		return controller.markedRange.length > 0;
	}
	if (action == @selector(goToPreviousPosition:))
	{
		if (controller == nil)
			return NO;
		return [controller.previousPositions count] > 1;
	}
	if (action == @selector(goToNextPosition:))
	{
		if (controller == nil)
			return NO;
		return [controller.nextPositions count] > 0;
	}
	return YES;
}

-(void)selectToStart:(id)sender
{
	[controller selectToStart] ;
}

-(void)selectToEnd:(id)sender
{
	[controller selectToEnd] ;
}

-(void)goToPreviousPosition:(id)sender
{
	[controller goToPreviousPosition];
}


-(void)goToNextPosition:(id)sender
{
	[controller goToNextPosition];
}

-(void)setNeedsDisplay:(BOOL)flag
{
	[mainLayer setNeedsDisplay];
}

-(void)setNeedsDisplayInRect:(NSRect)invalidRect
{
	[mainLayer setNeedsDisplayInRect:NSRectToCGRect(invalidRect)];
}

- (id < CAAction >)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
	return (id < CAAction >)[NSNull null];
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

#pragma mark
#pragma mark dragging

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard;
    NSDragOperation sourceDragMask;
	
    sourceDragMask = [sender draggingSourceOperationMask];
    pboard = [sender draggingPasteboard];
	
    if ( [[pboard types] containsObject:NSURLPboardType] )
	{
		if (sourceDragMask & NSDragOperationCopy)
            return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *pboard = [sender draggingPasteboard];
	
    if ( [[pboard types] containsObject:NSURLPboardType] )
	{
        NSURL *fileURL = [NSURL URLFromPasteboard:pboard];
        [document importAudioFromURL:fileURL];
    }
    return YES;
}
@end


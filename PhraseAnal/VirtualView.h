//
//  VirtualView.h
//  playaudiofile
//
//  Created by alan on 27/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class ClipView;

NSRect rectFromPoints(NSPoint pt1,NSPoint pt2);

@interface VirtualView : NSObject 
{
	NSRect _frame,_bounds;
	IBOutlet ClipView *clipView;
	NSUInteger autoresizingMask;
}

@property (assign) ClipView *clipView;
@property NSUInteger autoresizingMask;

- (id)initWithFrame:(NSRect)frame; 
-(NSRect)frame;
-(NSRect)bounds;
-(void)setFrame:(NSRect)f;
-(void)setBounds:(NSRect)f;
- (void)mouseDown:(NSEvent *)theEvent;
- (void)drawRect:(NSRect)dirtyRect;
-(void)setNeedsDisplayInRect:(NSRect)invalidRect;
-(void)setNeedsDisplay:(BOOL)b;
-(void)setNeedsDisplay;
-(NSUndoManager*)undoManager;
- (NSPoint)convertPoint:(NSPoint)aPoint fromView:(NSView *)aView;
- (NSPoint)convertPointToBase:(NSPoint)aPoint;
-(NSWindow*)window;
-(NSRect)visibleRect;
-(void)frameChanged;
-(void)clipViewFrameChanged;

@end

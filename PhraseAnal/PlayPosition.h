//
//  PlayPosition.h
//  playaudiofile
//
//  Created by alan on 05/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class VirtualView;

@interface PlayPosition : NSObject 
{
	NSPoint position;
	float width;
	VirtualView *mainView;
	NSView *ruleView;
	CALayer *positionLayer;
}

@property NSPoint position;
@property float width;
@property (readonly)NSRect frame;
@property (assign)NSView *ruleView;
@property (retain)CALayer *positionLayer;

-(void)setNeedsDisplay;
- (void)drawRect:(NSRect)dirtyRect;
-(void)setPosition:(NSPoint)pt;
-(id)hitTest:(NSPoint)aPoint;
-(id)initWithParent:(VirtualView*)ttv ruleView:(NSView*)rv;

@end

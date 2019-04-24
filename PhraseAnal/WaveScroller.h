//
//  WaveScroller.h
//  wave
//
//  Created by alan on 29/03/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class SelectedTrackController;

@interface WaveScroller : NSScroller 
{
	NSBitmapImageRep *bitmap;
	IBOutlet SelectedTrackController *controller;
}

@property (retain) NSBitmapImageRep *bitmap;
@end

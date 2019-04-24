//
//  MeterView.h
//  playaudiofile
//
//  Created by alan on 23/03/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <AudioToolbox/AudioToolbox.h>

@interface MeterView : NSView<CALayerDelegate>
{
	IBOutlet id controller;
	CALayer *leftLayer,*rightLayer;
	float leftLevel,rightLevel;
}

-(void)setLevelLeft:(AudioUnitParameterValue)l right:(AudioUnitParameterValue)r;

@end

//
//  WaveClipView.h
//  playaudiofile
//
//  Created by alan on 29/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ClipView.h"
#import <QuartzCore/QuartzCore.h>

@class AudioContainer;
@class RuleView;
@class PA_Document;

@interface WaveClipView : ClipView<CALayerDelegate>
{
	IBOutlet RuleView *ruleView;
	AudioContainer *controller;
	CALayer *mainLayer;
	CATextLayer *toolTipLayer;
	float toolTipWidth[20];
	IBOutlet PA_Document *document;
}

@property (assign,nonatomic) AudioContainer *controller;
@property (retain) CATextLayer *toolTipLayer;

-(float)toolTipWidth:(NSString*)str;
-(void)addPosLayer;

@end

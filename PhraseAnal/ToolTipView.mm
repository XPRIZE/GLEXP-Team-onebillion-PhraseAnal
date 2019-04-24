//
//  ToolTipView.mm
//  playaudiofile
//
//  Created by alan on 09/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ToolTipView.h"

NSString* DurationFromTime(float seconds,int places);

@implementation ToolTipView

@synthesize time;

-(void)awakeFromNib
{
	[self setBackgroundColor:[NSColor colorWithCalibratedRed:1.0 green:1.0 blue:0.8 alpha:1.0]];
	[self setEditable:NO];
}

-(void)setTime:(float)f
{
	time = f;
	[self setObjectValue:DurationFromTime(time,2)];
}
@end

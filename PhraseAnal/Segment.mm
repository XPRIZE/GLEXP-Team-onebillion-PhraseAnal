//
//  Segment.m
//  PhraseAnal
//
//  Created by alan on 23/11/13.
//  Copyright (c) 2013 Alan C Smith. All rights reserved.
//

#import "Segment.h"

@implementation Segment

-(void)dealloc
{
    [_beginArrow setDelegate:nil];
    [_endArrow setDelegate:nil];
    [_beginArrow removeFromSuperlayer];
    [_endArrow removeFromSuperlayer];
    [_beginArrow release];
    [_endArrow release];
	[_text release];
	[super dealloc];
}
@end

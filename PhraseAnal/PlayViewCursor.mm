//
//  PlayViewCursor.mm
//  playaudiofile
//
//  Created by alan on 28/03/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PlayViewCursor.h"


@implementation NSCursor(PlayViewCursor)

+(NSCursor*)magNoneCursor
{
    static NSCursor *cursor = nil;
    if (!cursor)
	{
        NSImage *image = [NSImage imageNamed:@"magnifiernone16a"];
        cursor = [[NSCursor allocWithZone:[self zone]] initWithImage:image hotSpot:NSMakePoint(6.0,6.0)];
	}
	return cursor;
}

+(NSCursor*)magPlusCursor
{
    static NSCursor *cursor = nil;
    if (!cursor)
	{
        NSImage *image = [NSImage imageNamed:@"magnifierplus16a"];
        cursor = [[NSCursor allocWithZone:[self zone]] initWithImage:image hotSpot:NSMakePoint(6.0,6.0)];
	}
	return cursor;
}

+(NSCursor*)magMinusCursor
{
    static NSCursor *cursor = nil;
    if (!cursor)
	{
        NSImage *image = [NSImage imageNamed:@"magnifierminus16a"];
        cursor = [[NSCursor allocWithZone:[self zone]] initWithImage:image hotSpot:NSMakePoint(6.0,6.0)];
	}
	return cursor;
}

@end

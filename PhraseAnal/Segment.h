//
//  Segment.h
//  PhraseAnal
//
//  Created by alan on 23/11/13.
//  Copyright (c) 2013 Alan C Smith. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioContainer.h"

@interface Segment : NSObject

@property 	struct selection range,oldRange;

@property (retain) CALayer *beginArrow,*endArrow;
@property (retain) NSString *text;

@property int firstEntry,lastEntry;

@end

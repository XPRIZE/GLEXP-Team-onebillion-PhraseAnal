//
//  FFTView.h
//  AuEd
//
//  Created by Alan on 08/11/2012.
//
//

#import <Cocoa/Cocoa.h>
#import "AudioContainer.h"

@interface FFTView : NSView
{
    AudioContainer *audioContainer;
}

@property (assign) AudioContainer *audioContainer;
@end

//
//  PA_Document.h
//  PhraseAnal
//
//  Created by alan on 23/11/13.
//  Copyright (c) 2013 Alan C Smith. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ErrorHandler.h"

@class AudioContainer;
@class WaveClipView;
@class PA_SegmentClipView;
@class PanelController;
@class ExportSoundFileController;
@class MeterView;
@class ET_XMLNode;

enum
{
	NIB_NOT_LOADED = 1,
	NIB_LOADED
};

@interface PA_Document : NSDocument<NSTextDelegate>
{
	IBOutlet NSButton *playButton;
	IBOutlet NSTextField *currentTimeField,*remainingTimeField;
	IBOutlet WaveClipView *waveClipView;
	IBOutlet ErrorHandler *errorHandler;
	IBOutlet PanelController *panelController;
    IBOutlet MeterView *meterView;
	IBOutlet NSTextView *phraseText;
	ExportSoundFileController *exportSoundFileController;
    BOOL needsSaveAs,isLoading;
@private
}

@property (retain) NSConditionLock *nibLock;
@property (retain) NSMutableArray *segments;
@property (assign) NSTextField *currentTimeField,*remainingTimeField;
@property (assign) WaveClipView *waveClipView;
@property (assign) IBOutlet PA_SegmentClipView *segmentClipView;
@property (assign) NSButton *playButton;
@property (retain) AudioContainer *audioContainer;
@property (retain) ErrorHandler *errorHandler;
@property (retain) PanelController *panelController;
@property (assign) MeterView *meterView;
@property (retain) NSURL *audioURL;
@property (retain) ET_XMLNode *xml;
@property (retain) NSString *displayFileName;
@property BOOL isLoading;

-(IBAction)playButtonHit:(id)sender;
-(IBAction)goToStart:(id)sender;
-(IBAction)goToEnd:(id)sender;
-(NSWindow*)window;
-(void)postLoad;
-(void)applyText;
-(void)importAudioFromURL:(NSURL*)url;
-(IBAction)autoSplit:(id)sender;


@end

//
//  PanelController.mm
//  playaudiofile
//
//  Created by alan on 23/03/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PanelController.h"
#import "PA_Document.h"

PanelController *_sharedPanelController;

@implementation PanelController

@synthesize abort,savedURL,progressPanelMessage;

-(void)dealloc
{
	self.savedURL = nil;
	[super dealloc];
}

- (IBAction)closeDurationSheet:(id)sender
{
/*    int reply = [sender tag];
	if (reply == 1) //OK
	{
		[selectedTrackController setFadeDuration:[fadeInOutDurationTextField floatValue]alignment:[fadeInOutRadioButtons selectedColumn]-1];
	}
	[NSApp endSheet:fadeInOutPanel];*/
}

- (void)durationSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
	[fadeInOutPanel orderOut:self];
}

/*- (void)showDurationDialog:(NSString*)title controller:(SelectedTrackController*)c tracks:(NSSet*)tracks mode:(int)fadeMode
{
	selectedTrackController = c;
	[fadeInOutTitle setStringValue:title];
	if ([tracks count] == 1)
	{
		float duration;
		int alignment;
		Track *t = ((TrackItem*)[tracks anyObject]).track;
		if (fadeMode == FADE_IN)
		{
			duration = t.fadeInDuration;
			alignment = t.fadeInAlignment;
		}
		else
		{
			duration = t.fadeOutDuration;
			alignment = t.fadeOutAlignment;
		}
		[fadeInOutDurationTextField setFloatValue:duration];
		[fadeInOutRadioButtons selectCellAtRow:0 column:alignment + 1];
	}
	else
	{
		[fadeInOutDurationTextField setObjectValue:nil];
		[[fadeInOutDurationTextField cell] setPlaceholderString:@"Multiple Selection"];
	}
    [NSApp beginSheet: fadeInOutPanel
	   modalForWindow: [[c stringView] window]
		modalDelegate: self
	   didEndSelector: @selector(durationSheetDidEnd:returnCode:contextInfo:)
		  contextInfo: nil];
}*/

- (void)progressSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode  contextInfo:(void  *)contextInfo
{
	[progressPanel orderOut:self];
}

-(void)showProgressPanelForWindow:(NSWindow*)window
{
	abort = NO;
	self.progressPanelMessage = @"";
    [progressIndicator setDoubleValue:0.0];
	[NSApp beginSheet: progressPanel
	   modalForWindow: window
		modalDelegate: self
	   didEndSelector: @selector(progressSheetDidEnd:returnCode:contextInfo:)
		  contextInfo: nil];
}
-(void)hideProgressPanel
{
	[NSApp endSheet:progressPanel];
}
-(void)updateProgress:(float)progress
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [progressIndicator setDoubleValue:progress];
        [progressIndicator displayIfNeeded];
    });
}

-(void)progressCancelHit:(id)sender
{
	abort = YES;
}

-(void)showMessagePanelWithMessage:(NSString*)message
{
	[messagePanelMessage setStringValue:message];
	[NSApp beginSheet: messagePanel
	   modalForWindow: [document window]
		modalDelegate: nil
	   didEndSelector: nil
		  contextInfo: nil];
}

-(void)hideProgressPanelAndShowMessage:(NSString*)message
{
	[self hideProgressPanel];
	[self showMessagePanelWithMessage:message];
}

-(void)messageButtonHit:(id)sender
{
	[NSApp endSheet:messagePanel];
	[messagePanel orderOut:self];
}

-(void)showRevealPanelWithMessage:(NSString*)message url:(NSURL*)url
{
	self.savedURL = url;
	[revealPanelMessage setStringValue:message];
	[NSApp beginSheet: revealPanel
	   modalForWindow: [document window]
		modalDelegate: nil
	   didEndSelector: nil
		  contextInfo: nil];
}

-(void)hideProgressPanelAndShowReveal:(NSArray*)arr
{
	NSString *message = [arr objectAtIndex:0];
	NSURL *url = [arr objectAtIndex:1];
	[self hideProgressPanel];
	[self showRevealPanelWithMessage:message url:url];
}

-(IBAction)revealButtonHit:(id)sender
{
	[NSApp endSheet:revealPanel];
	[revealPanel orderOut:self];
	if ([sender tag] == 2)
		[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:[NSArray arrayWithObject:savedURL]];
	self.savedURL = nil;
}


@end

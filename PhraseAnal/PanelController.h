//
//  PanelController.h
//  playaudiofile
//
//  Created by alan on 23/03/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PA_Document;

@interface PanelController : NSObject 
{	
	IBOutlet NSPanel *fadeInOutPanel;
	IBOutlet NSTextField *fadeInOutTitle;
	IBOutlet NSTextField *fadeInOutDurationTextField;
	IBOutlet NSMatrix *fadeInOutRadioButtons;
	IBOutlet NSPanel *progressPanel;
	IBOutlet NSProgressIndicator *progressIndicator;
	IBOutlet NSPanel *messagePanel,*revealPanel;
	IBOutlet NSTextField *messagePanelMessage,*revealPanelMessage;
	IBOutlet PA_Document *document;
	BOOL abort;
	NSURL *savedURL;
	NSString *progressPanelMessage;
}

@property BOOL abort;
@property (retain)NSURL *savedURL;
@property (copy) NSString *progressPanelMessage;


- (IBAction)closeDurationSheet:(id)sender;
//- (void)showDurationDialog:(NSString*)title controller:(SelectedTrackController*)c tracks:(NSSet*)tracks mode:(int)fadeMode;
-(void)showProgressPanelForWindow:(NSWindow*)window;
-(void)hideProgressPanel;
-(void)updateProgress:(float)progress;
-(void)progressCancelHit:(id)sender;
-(void)messageButtonHit:(id)sender;
-(void)showMessagePanelWithMessage:(NSString*)message;
-(void)hideProgressPanelAndShowMessage:(NSString*)message;
-(void)showRevealPanelWithMessage:(NSString*)message url:(NSURL*)url;
-(void)hideProgressPanelAndShowReveal:(NSArray*)arr;
-(IBAction)revealButtonHit:(id)sender;

@end

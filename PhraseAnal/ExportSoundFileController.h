//
//  ExportSoundFileController.h
//  playaudiofile
//
//  Created by alan on 31/03/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ExportSoundFileController : NSObject 
{
	IBOutlet NSView *accessoryView;
	IBOutlet NSPopUpButton *fileTypeMenu,*fileFormatMenu;
	IBOutlet NSPopUpButton *bitRateMenu;
	IBOutlet NSPopUpButton *qualityMenu;
	IBOutlet NSPopUpButton *extensionMenu;
	NSInteger selectedUTI,selectedQuality;
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel;
- (IBAction)fileTypeMenuHit:(id)sender;
- (IBAction)bitRateMenuHit:(id)sender;
-(IBAction)formatMenuHit:(id)sender;
-(IBAction)extensionMenuHit:(id)sender;

-(UInt32)selectedFileType;
-(NSInteger)selectedBitRate;
-(NSInteger)selectedQuality;
-(NSDictionary*)attributes;
-(UInt32)selectedFormat;

@end

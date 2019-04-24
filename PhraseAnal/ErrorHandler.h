//
//  ErrorHandler.h
//  playaudiofile
//
//  Created by alan on 15/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum
{
	EH_NO_ERROR,
	EH_INFO,
	EH_WARNING,
	EH_COULDNT_COMPLETE,
	EH_FATAL
};

@protocol ErrorHandlerDelegate

-(NSWindow*)window;

@end

@interface ErrorHandler : NSObject 
{
	NSMutableArray *errors;
	int maxSeverity;
	IBOutlet NSTableView *tableView;
	IBOutlet NSTextField *message;
	IBOutlet NSPanel *errorPanel;
	IBOutlet id<ErrorHandlerDelegate> delegate;
}

@property int maxSeverity;
@property (retain) NSMutableArray *errors;

-(void)reset;
-(void)addError:(NSString*)errorMsg severity:(int)severity;
-(void)addError:(NSString*)errorMsg status:(OSStatus)status severity:(int)severity;
-(IBAction)dismissErrorPanel:(id)sender;
-(void)showMessagePanelWithMessage:(NSString*)msg;

@end

NSString* stringFromStatus(OSStatus status);


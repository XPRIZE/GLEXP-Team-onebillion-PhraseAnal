//
//  ErrorHandler.mm
//  playaudiofile
//
//  Created by alan on 15/04/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ErrorHandler.h"

@implementation ErrorHandler

@synthesize maxSeverity,errors;

-(id)init
{
	if ((self = [super init]))
	{
		errors = [[NSMutableArray alloc]initWithCapacity:5];
	}
	return self;
}

-(void)dealloc
{
	[errors release];
	[super dealloc];
}

-(void)reset
{
	[errors removeAllObjects];
	maxSeverity = 0;
}

-(void)addError:(NSString*)errorMsg severity:(int)severity
{
	[errors addObject:[NSDictionary dictionaryWithObjectsAndKeys:errorMsg,@"msg",
					   [NSNumber numberWithInt:severity],@"sev",
					   nil]];
}

NSString* stringFromStatus(OSStatus status)
{
	unichar s[4];
	s[0] = status >> 24; 
	s[1] = ((status & 0x00FF0000) >> 16); 
	s[2] = (status & 0x0000ff00) >> 8; 
	s[3] = (status & 0x000000ff);
	return [NSString stringWithCharacters:s length:4];
}

-(void)addError:(NSString*)errorMsg status:(OSStatus)status severity:(int)severity
{
	if (severity > maxSeverity)
		maxSeverity = severity;
	NSString *code;
	if (status > 0)
		code = stringFromStatus(status); 
	else
		code = [NSString stringWithFormat:@"%d",status];
	[errors addObject:[NSDictionary dictionaryWithObjectsAndKeys:errorMsg,@"msg",
					   [NSNumber numberWithInt:severity],@"sev",
					   code,@"code",
					   nil]];
}

-(IBAction)dismissErrorPanel:(id)sender
{
	[NSApp endSheet:errorPanel];
	[errorPanel orderOut:self];
}

-(void)showMessagePanelWithMessage:(NSString*)msg
{
	[message setStringValue:msg];
	[NSApp beginSheet: errorPanel
	   modalForWindow: [delegate window]
		modalDelegate: nil
	   didEndSelector: nil
		  contextInfo: nil];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [errors count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSDictionary *dict = [errors objectAtIndex:rowIndex];
	if ([[aTableColumn identifier]isEqual:@"code"])
	{
		id code = [dict objectForKey:@"code"];
		if (!code)
			code = [dict objectForKey:@"sev"];
		return code;
	}
	else
		return [[errors objectAtIndex:rowIndex]objectForKey:@"msg"];
}

@end

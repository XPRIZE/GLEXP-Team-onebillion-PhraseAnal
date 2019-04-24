//
//  ExportSoundFileController.mm
//  playaudiofile
//
//  Created by alan on 31/03/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ExportSoundFileController.h"
#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#include <AudioUnit/AudioUnit.h>
#include <CoreAudio/CoreAudioTypes.h>
#include <CoreFoundation/CoreFoundation.h>
#include "ErrorHandler.h"

NSMutableSet *_encodableformats;
NSMutableArray *_fileTypes;
NSMutableArray *_file_extensions;
NSMutableArray *_filetypenames;
//int _bitrates[] = {128,192,256,320,0};

@implementation ExportSoundFileController

- (id)init
{
	if ((self = [super init]))
	{
		[NSBundle loadNibNamed:@"ExportSoundFile" owner:self];
	}
	return self;
}

-(NSSet*)encodableFormats
{
	if (!_encodableformats)
	{
		_encodableformats = [[NSMutableSet alloc]initWithCapacity:5];
		UInt32 size;
		OSStatus err = AudioFormatGetPropertyInfo(kAudioFormatProperty_EncodeFormatIDs, 0, NULL, &size);
		UInt32 *_formats = (UInt32*)malloc(size);
		err = AudioFormatGetProperty(kAudioFormatProperty_EncodeFormatIDs, 0, NULL, &size, _formats);
		if (!err)
		{
			int noFileTypes = size / sizeof(UInt32);
			for (int i=0;i < noFileTypes;i++)
				[_encodableformats addObject:[NSNumber numberWithUnsignedInt:_formats[i]]];
		}
		free(_formats);
	}
	return _encodableformats;
}

-(BOOL)isEncodableFormat:(UInt32)f
{
	return [[self encodableFormats]containsObject:[NSNumber numberWithUnsignedInt:f]];
}

-(NSArray*)encodableFormatsForFileType:(UInt32)fileType
{
	NSMutableArray *writableFormats = [NSMutableArray arrayWithCapacity:5];
	UInt32 fsize;
	AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableFormatIDs,sizeof(UInt32),&fileType, &fsize);
	UInt32 *_formatsforfiletype = (UInt32*)malloc(fsize);
	OSStatus err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableFormatIDs,sizeof(UInt32),&fileType, &fsize, _formatsforfiletype);
	if (!err)
	{
		int noFormats = fsize / sizeof(UInt32);
		for (int i=0;i < noFormats;i++)
			if ([self isEncodableFormat:_formatsforfiletype[i]])
				[writableFormats addObject:[NSNumber numberWithUnsignedInt:_formatsforfiletype[i]]];
	}
	free(_formatsforfiletype);
	return writableFormats;
}

NSString* extensionForFileType(UInt32 fileType)
{
	UInt32 iosize = sizeof(CFArrayRef);
	CFArrayRef extensions;
	OSStatus err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_ExtensionsForType,
										  sizeof(UInt32), &fileType,
										  &iosize, &extensions);
	if (err)
		NSLog(@"Error getting file extensions - %d",err);
	NSArray *arr = (NSArray*)extensions;
	NSString *str = [[arr objectAtIndex:0]copy];
	CFRelease (extensions);
	return str;
	
}

NSArray* extensionsForFileType(UInt32 fileType)
{
	UInt32 iosize = sizeof(CFArrayRef);
	CFArrayRef extensions;
	OSStatus err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_ExtensionsForType,
										  sizeof(UInt32), &fileType,
										  &iosize, &extensions);
	if (err)
		NSLog(@"Error getting file extensions - %d",err);
	NSArray *arr = (NSArray*)extensions;
    NSArray *result = [[arr copy]autorelease];
	CFRelease (extensions);
	return result;
	
}

NSString* nameForFileType(UInt32 fileType)
{
	UInt32 iosize = sizeof(CFStringRef);
	CFStringRef cfstringref;
	OSStatus err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_FileTypeName,
								 sizeof(fileType), &fileType,
								 &iosize, &cfstringref);
	NSString *result=nil;
	if (err)
		NSLog(@"Error getting file name - %d",err);
	else 			
		result = [(NSString*)cfstringref copy];
	CFRelease(cfstringref);
	return result;
}

NSArray* bitratesForFormat(UInt32 fileType)
{
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:10];
	UInt32 size;
	OSStatus err = AudioFormatGetPropertyInfo(kAudioFormatProperty_AvailableEncodeBitRates,sizeof(fileType),&fileType,&size);
	AudioValueRange *_bitrates = (AudioValueRange*)malloc(size);
	err = AudioFormatGetProperty(kAudioFormatProperty_AvailableEncodeBitRates,sizeof(fileType),&fileType, &size, _bitrates);
	if (!err)
	{
		int noBitrates = size / sizeof(AudioValueRange);
		for (int i=0;i < noBitrates;i++)
			[result addObject:[NSNumber numberWithUnsignedInt:_bitrates[i].mMaximum]];
	}
	free(_bitrates);
	return result;
}

-(NSArray*)fileTypes
{
	if (_fileTypes)
		return _fileTypes;
	_fileTypes = [[NSMutableArray alloc]initWithCapacity:6];
	OSStatus err;
	UInt32 size;
	AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_WritableTypes, 0, NULL, &size);
	UInt32 * _writablefileTypes = (UInt32*)malloc(size);
	err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_WritableTypes,
										  0, NULL,
										  &size, _writablefileTypes);
	if (!err)
	{
		int noFileTypes = size / sizeof(UInt32);
		for (int i = 0;i < noFileTypes;i++)
		{
			NSArray *arr = [self encodableFormatsForFileType:_writablefileTypes[i]];
			if ([arr count] > 0)
			{
				NSMutableDictionary *mdict = [NSMutableDictionary dictionaryWithCapacity:7];
				[mdict setObject:[NSNumber numberWithUnsignedInteger:_writablefileTypes[i]]forKey:@"filetype"];
				[mdict setObject:arr forKey:@"formats"];
				[mdict setObject:nameForFileType(_writablefileTypes[i]) forKey:@"name"];
				[mdict setObject:extensionsForFileType(_writablefileTypes[i]) forKey:@"extensions"];
				[_fileTypes addObject:mdict];
			}
		}
	}
	return _fileTypes;
}

-(void)setFormatMenuForFileType
{
	[fileFormatMenu removeAllItems];
	NSDictionary *fType = [[self fileTypes] objectAtIndex:selectedUTI];
	NSArray *arr = [fType objectForKey:@"formats"];
	int index = [[fType objectForKey:@"selformat"]intValue];
	for (NSNumber *n in arr)
	{
		UInt32 u = (UInt32)[n unsignedIntegerValue];
		[fileFormatMenu addItemWithTitle:stringFromStatus(u)];
	}
	[fileFormatMenu selectItemAtIndex:index];
}

-(void)setExtensionMenuForFileType
{
 	[extensionMenu removeAllItems];
	NSDictionary *fType = [[self fileTypes] objectAtIndex:selectedUTI];
	NSArray *arr = [fType objectForKey:@"extensions"];
	int index = [[fType objectForKey:@"selextension"]intValue];
	for (NSString *s in arr)
	{
		[extensionMenu addItemWithTitle:s];
	}
	[extensionMenu selectItemAtIndex:index];
	[(NSSavePanel*)[accessoryView window] setAllowedFileTypes:[NSArray arrayWithObject:[arr objectAtIndex:index]]];
   
}
-(void)setBitrateMenuForFormat
{
	int currentBitrate = [[[NSUserDefaults standardUserDefaults] objectForKey:@"outputbitrate"]intValue];
	int index = 0;
	[bitRateMenu removeAllItems];
	NSArray *arr =  bitratesForFormat([self selectedFormat]);
	for (int i = 0;i < [arr count];i++)
	{
		
		NSUInteger u = [[arr objectAtIndex:i] unsignedIntegerValue];
		if (u == currentBitrate)
			index = i;
		[bitRateMenu addItemWithTitle:[NSString stringWithFormat:@"%ld",u]];
	}
	[bitRateMenu selectItemAtIndex:index];
}

- (IBAction)fileTypeMenuHit:(id)sender
{
	selectedUTI = [sender indexOfSelectedItem];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInt:[self selectedFileType]] forKey:@"outputfiletype"];
    [self setFormatMenuForFileType];
	[self setExtensionMenuForFileType];
	[self setBitrateMenuForFormat];
}

-(IBAction)formatMenuHit:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInt:[self selectedFormat]] forKey:@"outputformat"];
	[self setBitrateMenuForFormat];
	NSMutableDictionary *dict = [[self fileTypes]objectAtIndex:selectedUTI];
	[dict setObject:[NSNumber numberWithInt:(int)[sender indexOfSelectedItem]]forKey:@"selformat"];
}

-(IBAction)extensionMenuHit:(id)sender
{
    int index = (int)[extensionMenu indexOfSelectedItem];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInt:index] forKey:@"extension"];
	NSMutableDictionary *dict = [[self fileTypes]objectAtIndex:selectedUTI];
	[dict setObject:[NSNumber numberWithInt:index]forKey:@"selextension"];
	[(NSSavePanel*)[accessoryView window] setAllowedFileTypes:[NSArray arrayWithObject:[[dict objectForKey:@"extensions"] objectAtIndex:index]]];
}

- (IBAction)bitRateMenuHit:(id)sender
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedLong:[self selectedBitRate]] forKey:@"outputbitrate"];
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
	UInt32 lastFileType = [[[NSUserDefaults standardUserDefaults] objectForKey:@"outputfiletype"]unsignedIntValue];
	selectedUTI = 0;
	[fileTypeMenu removeAllItems];
	for (int i = 0;i < [[self fileTypes]count];i++)
	{
		NSDictionary *dict = [[self fileTypes]objectAtIndex:i];
		[fileTypeMenu addItemWithTitle:[NSString stringWithFormat:@"%@",
										[dict objectForKey:@"name"]]];
		if ([[dict objectForKey:@"filetype"]unsignedIntValue] == lastFileType)
			selectedUTI = i;
	}
	[fileTypeMenu selectItemAtIndex:selectedUTI];
	selectedQuality = 3;
	[qualityMenu selectItemAtIndex:-1];
	[qualityMenu selectItemAtIndex:selectedQuality];
	[savePanel setAccessoryView:accessoryView];
	[savePanel setAllowedFileTypes:[[[self fileTypes] objectAtIndex:selectedUTI]objectForKey:@"extensions"]];
	[self setFormatMenuForFileType];
	[self setBitrateMenuForFormat];
	[self setExtensionMenuForFileType];
    return YES;
}

-(UInt32)selectedFileType
{
	return (UInt32)[[[[self fileTypes]objectAtIndex:selectedUTI]objectForKey:@"filetype"]unsignedIntegerValue];
}

-(UInt32)selectedFormat
{
	NSArray *arr = [[[self fileTypes]objectAtIndex:selectedUTI]objectForKey:@"formats"];
	NSNumber *u = [arr objectAtIndex:[fileFormatMenu indexOfSelectedItem]];
	return (UInt32)[u unsignedIntegerValue];
}

-(NSInteger)selectedBitRate
{
	NSArray *rates = bitratesForFormat([self selectedFormat]);
	if (rates && [rates count] > 0)
		return [[rates objectAtIndex:[bitRateMenu indexOfSelectedItem]]unsignedIntegerValue];
	return -1;
}

-(NSInteger)selectedQuality
{
	return selectedQuality;
}

-(NSDictionary*)attributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithUnsignedInteger:[self selectedFileType]],@"outputfiletype",
			[NSNumber numberWithUnsignedInteger:[self selectedFormat]],@"outputformat",
			[NSNumber numberWithInt:(int)[self selectedBitRate]],@"bitRate",
			[NSNumber numberWithInt:(int)[self selectedQuality]],@"quality",
			nil];
	
}
@end

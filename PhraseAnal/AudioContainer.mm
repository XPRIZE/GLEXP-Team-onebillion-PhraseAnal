//
//  AudioContainer.mm
//  AuEd
//
//  Created by alan on 03/04/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "AudioContainer.h"
#import "WaveView.h"
#import "WaveClipView.h"
#import "PA_SegmentClipView.h"
#import "PanelController.h"
#import "MeterView.h"
#import <Accelerate/Accelerate.h>

enum
{
	USE_CALLBACKS = 1,
	USE_FADES = 2,
	BURSTING = 4
};


NSString *AuEdSoundPasteboardType = @"AuEdSound";

NSImage *playImage,*pauseImage;

NSString* DurationFromTime(float seconds,int places)
{
	int min = floor(seconds / 60);
	float sec = seconds - (min * 60);
	return [NSString stringWithFormat:@"%d:%0*.*f",min,places+3,places,sec];
}

OSStatus BurstRenderCallback(
							 void *							inRefCon,
							 AudioUnitRenderActionFlags *      ioActionFlags,
							 const AudioTimeStamp *			inTimeStamp,
							 UInt32							inBusNumber,
							 UInt32							inNumberFrames,
							 AudioBufferList *                 ioData)
{
	if (*ioActionFlags & kAudioUnitRenderAction_PreRender)
	{
		AudioData *audioData = (AudioData*) inRefCon;
        SInt64 currFrame = audioData->startFrame;// + inTimeStamp->mSampleTime;
        for (int i = 0;i < ioData->mNumberBuffers;i++)
        {
            if (ioData->mBuffers[i].mData == nil)
            {
                ioData->mBuffers[i].mData = audioData->burstBufferList->mBuffers[i].mData;
                ioData->mBuffers[i].mDataByteSize = audioData->burstBufferList->mBuffers[i].mDataByteSize;
                ioData->mBuffers[i].mNumberChannels = audioData->burstBufferList->mBuffers[i].mNumberChannels;
            }
            memcpy(ioData->mBuffers[i].mData,audioData->audioData[i]+currFrame,inNumberFrames * sizeof(Float32));
        }
	}
	return 0;
}

OSStatus PlayerRenderCallback(
							  void *							inRefCon,
							  AudioUnitRenderActionFlags *	ioActionFlags,
							  const AudioTimeStamp *			inTimeStamp,
							  UInt32							inBusNumber,
							  UInt32							inNumberFrames,
							  AudioBufferList *				ioData)
{
	if (*ioActionFlags & kAudioUnitRenderAction_PostRender)
	{
		AudioData *audioData = (AudioData*) inRefCon;
        
        if (audioData->startFrame + inTimeStamp->mSampleTime > audioData->endFrame)
        {
            audioData->playTime.mFlags = kAudioTimeStampSampleTimeValid;
            audioData->playTime.mSampleTime = audioData->endFrame - audioData->startFrame;
        }
        else
            audioData->playTime = *inTimeStamp;
	}
	return 0;
}

void DoFade(SInt64 currentFrame,SInt64 noFrames,ScheduleEvent &se,AudioUnit auUnit)
{
	AudioUnitParameterEvent event = {kAudioUnitScope_Input,0,kStereoMixerParam_Volume,kParameterEvent_Ramped};
	SInt64 start = se.startFrame - currentFrame;
	if (start < 0)
		start = 0;
	SInt64 end = se.endFrame - currentFrame;
	if (end > noFrames)
		end = noFrames;
	event.eventValues.ramp.startBufferOffset = (UInt32)start;
	event.eventValues.ramp.durationInFrames = (UInt32)(end - start);
	SInt64 totalDuration = se.endFrame - se.startFrame;
	float volDiff = se.endVol - se.startVol;
	event.eventValues.ramp.startValue = se.startVol + ((start + currentFrame)-se.startFrame)*1.0/totalDuration*volDiff;
	event.eventValues.ramp.endValue = se.startVol + ((end + currentFrame)-se.startFrame)*1.0/totalDuration*volDiff;
	OSErr err = AudioUnitScheduleParameters(auUnit,&event,1);
	if (err)
		NSLog(@"schedule ramped parameter: error %ld\n", (long int)err);
	
}

OSStatus VolumeRenderCallback(
							  void *							inRefCon,
							  AudioUnitRenderActionFlags *	ioActionFlags,
							  const AudioTimeStamp *			inTimeStamp,
							  UInt32							inBusNumber,
							  UInt32							inNumberFrames,
							  AudioBufferList *				ioData)
{
	if (*ioActionFlags & kAudioUnitRenderAction_PreRender)
	{
		UInt64 currentFrame = inTimeStamp->mSampleTime;
		UInt64 lastFrame = currentFrame + inNumberFrames;
		AudioData *audioData = (AudioData*) inRefCon;
		UInt64 relStartFrame = (audioData->fadeInSE.startFrame - audioData->startFrame);
		UInt64 relEndFrame = (audioData->fadeInSE.endFrame - audioData->startFrame);
		if (audioData->fadeInActive && relStartFrame <= lastFrame && relEndFrame >= currentFrame)
		{
			ScheduleEvent se = audioData->fadeInSE;
			se.startFrame -= audioData->startFrame;
			se.endFrame -= audioData->startFrame;
			DoFade(currentFrame, inNumberFrames,se,audioData->mixerUnit);
		}
		else
		{
			relStartFrame = (audioData->fadeOutSE.startFrame - audioData->startFrame);
			relEndFrame = (audioData->fadeOutSE.endFrame - audioData->startFrame);
			if (audioData->fadeOutActive && relStartFrame <= lastFrame && relEndFrame >= currentFrame)
			{
				ScheduleEvent se = audioData->fadeOutSE;
				se.startFrame -= audioData->startFrame;
				se.endFrame -= audioData->startFrame;
				DoFade(currentFrame, inNumberFrames,se,audioData->mixerUnit);
			}
		}
	}
	return 0;
}

void SliceCompletionProc(void *userData,ScheduledAudioSlice *scheduledAudioSlice)
{
	AudioContainer *cont = (AudioContainer*)userData;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [cont sliceFinished];
    });
    //[cont performSelectorOnMainThread:@selector(sliceFinished) withObject:nil waitUntilDone:NO];
}

@interface AudioContainer(_private)

-(void)updateButton;
-(void)uClearSelection:(selection)seln archiveName:(NSString*)archiveName;
-(void)setPosition:(SInt64)frame;
-(void)getBitrateAndQuality:(ExtAudioFileRef)file;

@end

@implementation AudioContainer

@synthesize playing,playButton,doc,burstBefore,frameSelection,markedRange,abort,fadeIn,fadeOut,previousPositions,nextPositions,pitch,rate,displaySampleRate,
displayDuration,displaySelnStart,displaySelnEnd,displaySelnLengthMode,displayChannels,displayFormat;

+(void)initialize
{
	playImage = [[NSImage imageNamed:@"gobutton"]retain];
	pauseImage = [[NSImage imageNamed:@"stopbutton"]retain];
}

-(id)init
{
	if ((self = [super init]))
	{
		playing = NO;
		for (int i = 0;i < 5;i++)
			audioData.audioData[i] = nil;
		audioData.playTime.mFlags = kAudioTimeStampSampleTimeValid;
		audioData.playTime.mSampleTime = 0;
		audioData.startFrame = 0;
		audioData.container = self;
		audioData.volume = 1.0;
        frameSelection.location = frameSelection.length = 0;
        markedRange.location = frameSelection.length = 0;
		self.previousPositions = [NSMutableArray arrayWithCapacity:50];
		self.nextPositions = [NSMutableArray arrayWithCapacity:20];
		rate = 1.0;
	}
	return self;
}

-(void)dealloc
{
    if (playing)
        [self stopPlay];
	for (int i = 0;i < 2;i++)
		if (audioData.audioData[i])
			free(audioData.audioData[i]);
	if (updateTimer)
		[updateTimer invalidate];
	[previousPositions release];
	[nextPositions release];
	self.displayDuration = nil;
	self.displaySelnStart = nil;
	self.displaySelnEnd = nil;
	self.displayChannels = nil;
	self.displayFormat = nil;
    [super dealloc];
}

#pragma mark accessors

-(SInt64)totalFrames
{
	return audioData.totalFrames;
}

-(Float32*)leftData
{
	return audioData.audioData[0];
}

-(Float32*)rightData
{
	return audioData.audioData[1];
}

-(UInt64)currentFrame
{
	return audioData.startFrame + audioData.playTime.mSampleTime;
}

-(double)normalisedCurrentFrame
{
	return ([self currentFrame] * 1.0) / audioData.totalFrames;
}

-(WaveView*)waveView
{
	return (WaveView*)[[doc waveClipView]clientView];
}

#pragma mark buffers

void CopyFloats(Float32 *from,Float32 *to,UInt64 totalLength,selection exclude)
{
	if (exclude.location > 0)
	{
		unsigned char *fromPtr = (unsigned char*)from;
		unsigned char *toPtr = (unsigned char*)to;
		UInt64 datalen = exclude.location * sizeof(Float32);
		memcpy(toPtr, fromPtr, datalen);
	}
	from = from + exclude.location  + exclude.length;
	to = to + exclude.location;
	unsigned char *fromPtr = (unsigned char*)from;
	unsigned char *toPtr = (unsigned char*)to;
	UInt64 datalen = (totalLength - (exclude.location  + exclude.length)) * sizeof(Float32);
	memcpy(toPtr, fromPtr, datalen);
}

void CopyFloatsInc(Float32 *from,Float32 *to,Float32 *include,UInt64 includeLength,UInt64 totalLength,UInt64 atPoint)
{
	if (atPoint > 0)
	{
		unsigned char *fromPtr = (unsigned char*)from;
		unsigned char *toPtr = (unsigned char*)to;
		UInt64 datalen = atPoint * sizeof(Float32);
		memcpy(toPtr, fromPtr, datalen);
	}
	to = to + atPoint;
	unsigned char *fromPtr = (unsigned char*)include;
	unsigned char *toPtr = (unsigned char*)to;
	memcpy(toPtr, fromPtr, includeLength * sizeof(Float32));
	to = to + includeLength;
	from = from + atPoint;
	fromPtr = (unsigned char*)from;
	toPtr = (unsigned char*)to;
	UInt64 datalen = (totalLength - atPoint) * sizeof(Float32);
	memcpy(toPtr, fromPtr, datalen);
}

-(BOOL)reallocBufferWithoutRange:(selection)seln
{
	if (seln.length == 0)
		return NO;
	UInt64 newNoFrames = audioData.totalFrames - seln.length;
	UInt64 newDataLength = newNoFrames * sizeof(Float32);
    for (int i = 0;i < audioData.noChannels;i++)
    {
        Float32 *newi = (Float32*)malloc(newDataLength);
        CopyFloats(audioData.audioData[i], newi,audioData.totalFrames, seln);
        free(audioData.audioData[i]);
        audioData.audioData[i]= newi;
    }
	audioData.totalFrames = newNoFrames;
	audioData.dataLength = newDataLength;
	return YES;
}

-(BOOL)reallocBufferWithData:(NSArray*)dataArray atPoint:(UInt64)atPoint
{
	UInt64 len = [[dataArray objectAtIndex:0] length] / sizeof(Float32);
	UInt64 newNoFrames = audioData.totalFrames + len;
	UInt64 newDataLength = newNoFrames * sizeof(Float32);
    for (int i = 0;i < audioData.noChannels;i++)
    {
        NSData *datai = [dataArray objectAtIndex:i];
        Float32 *newi = (Float32*)malloc(newDataLength);
        CopyFloatsInc(audioData.audioData[i],newi,(Float32*)[datai bytes],len,audioData.totalFrames,atPoint);
        free(audioData.audioData[i]);
        audioData.audioData[i] = newi;
    }
	audioData.totalFrames = newNoFrames;
	audioData.dataLength = newDataLength;
	return YES;
}

-(BOOL)reverseBuffersStartFrame:(SInt64)startFrame length:(SInt64)length
{
    for (int i = 0;i < audioData.noChannels;i++)
    {
        vDSP_vrvrs(audioData.audioData[i] + startFrame,1,length);
    }
    return YES;
}

-(void)processBuffer:(char**)bufferData noFrames:(UInt32)framesRead
{
    for (int i = 0;i < audioData.noChannels;i++)
    {
        char *srcBuffer;
        srcBuffer = (char*)bufferData[i];
        UInt32 noFloats = framesRead;
        memcpy(audioData.dataPosition[i],srcBuffer,noFloats * sizeof(Float32));
        audioData.dataPosition[i] += noFloats;
    }
}

#pragma mark -
#pragma mark graphs

-(void)setUpBurstGraph
{
	AudioStreamBasicDescription theAudioFormat;
	UInt32 propertySize = sizeof(theAudioFormat);
	burstGraph = new AUGraph;
	OSStatus err;
	if ((err = NewAUGraph(burstGraph)))
		NSLog(@"NewAUGraph failed %d",err);
	if ((err = AUGraphOpen(*burstGraph)))
		NSLog(@"couldn't open graph %d",err);
	// add an output unit
	AudioComponentDescription outputDesc = {kAudioUnitType_Output, kAudioUnitSubType_DefaultOutput, kAudioUnitManufacturer_Apple,0,0};
	AUNode lastNode;
	if ((err = AUGraphAddNode(*burstGraph, &outputDesc, &lastNode)))
		NSLog(@"couldn't create node for output unit %d",err);
	if ((err = AUGraphNodeInfo(*burstGraph, lastNode, NULL, &bOutputUnit)))
		NSLog(@"couldn't get output unit from node %d",err);
	err = AudioUnitGetProperty(bOutputUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Input, 0, &theAudioFormat, &propertySize);
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	if ((err = AudioUnitSetProperty(bOutputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set output unit's output stream format %d",err);
	err = AudioUnitGetProperty(bOutputUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output, 0, &theAudioFormat, &propertySize);
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	if ((err = AudioUnitSetProperty(bOutputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set output unit's output stream format %d",err);
	
	// add timepitch units
	for (int i = 0;i < BURST_NO_TIMEPITCHUNITS;i++)
	{
		AudioComponentDescription timepitchDesc = {kAudioUnitType_FormatConverter, kAudioUnitSubType_TimePitch, kAudioUnitManufacturer_Apple,0,0};
		AUNode tpNode;
		if ((err = AUGraphAddNode(*burstGraph, &timepitchDesc, &tpNode)))
			NSLog(@"couldn't create node for timepitch unit %d",err);
		if ((err = AUGraphNodeInfo(*burstGraph, tpNode, NULL, &bTimePitchUnit[i])))
			NSLog(@"couldn't get timepitch unit from node %d",err);
		if ((err = AUGraphConnectNodeInput(*burstGraph, tpNode, 0, lastNode, 0)))
			NSLog(@"couldn't connect timepitch to output unit %d",err);
		//		err = AudioUnitGetProperty(bTimePitchUnit[i],kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output, 0, &theAudioFormat, &propertySize);
		//		theAudioFormat.mSampleRate = clientFormat.mSampleRate;
		//		if ((err = AudioUnitSetProperty(bTimePitchUnit[i], kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		//			NSLog(@"couldn't set timepitch's output stream format %d",err);
		lastNode = tpNode;
	}
	// add a mixer unit
	AudioComponentDescription mixerDesc = {kAudioUnitType_Mixer, kAudioUnitSubType_StereoMixer, kAudioUnitManufacturer_Apple,0,0};
	AUNode mNode;
	if ((err = AUGraphAddNode(*burstGraph, &mixerDesc, &mNode)))
		NSLog(@"couldn't create node for mixer unit %d",err);
	if ((err = AUGraphNodeInfo(*burstGraph, mNode, NULL, &bMixerUnit)))
		NSLog(@"couldn't get mixer unit from node %d",err);
	// connect the mixer to the timepitch unit (stream format will propagate)
	if ((err = AUGraphConnectNodeInput(*burstGraph, mNode, 0, lastNode, 0)))
		NSLog(@"couldn't connect mixer to timepitch unit %d",err);
	err = AudioUnitGetProperty(bMixerUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Input, 0, &theAudioFormat, &propertySize);
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	if ((err = AudioUnitSetProperty(bMixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set mixer's output stream format %d",err);
	err = AudioUnitGetProperty(bMixerUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output, 0, &theAudioFormat, &propertySize);
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	if ((err = AudioUnitSetProperty(bMixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set mixer's output stream format %d",err);
	
	// add a player
	AudioComponentDescription playerDesc = {kAudioUnitType_Generator, kAudioUnitSubType_ScheduledSoundPlayer, kAudioUnitManufacturer_Apple,0,0};
	AUNode pNode;
	if ((err = AUGraphAddNode(*burstGraph, &playerDesc, &pNode)))
		NSLog(@"couldn't create node for file player %d",err);
	if ((err = AUGraphNodeInfo(*burstGraph, pNode, NULL, &bPlayerUnit)))
		NSLog(@"couldn't get player unit from node %d",err);
	
	err = AudioUnitGetProperty(bPlayerUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Global, 0, &theAudioFormat, &propertySize);
	
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	SetCanonical(theAudioFormat,audioData.noChannels, false /* deinterleaved */);
	if ((err = AudioUnitSetProperty(bPlayerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Global, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set player's output stream format %d",err);
	
	// connect the player to the mixer unit (stream format will propagate)
	if ((err = AUGraphConnectNodeInput(*burstGraph, pNode, 0, mNode, 0)))
		NSLog(@"couldn't connect player to mixer unit %d",err);
	
	// initialize the AUGraph
	if ((err = AUGraphInitialize(*burstGraph)))
		NSLog(@"couldn't initialize graph %d",err);
	for (int i = 0;i < BURST_NO_TIMEPITCHUNITS;i++)
		if ((err = AudioUnitSetParameter(bTimePitchUnit[i], kTimePitchParam_Rate, kAudioUnitScope_Global, 0, 0.25, 0)))
			NSLog(@"SetRate AudioUnitSetParameter kTimePitchParam_Rate %d",err);
	
	
}

-(void)setUpGraph
{
	AUNode thePlayerNode;
	auGraph = new AUGraph;
	OSStatus err;
	if ((err = NewAUGraph(auGraph)))
		NSLog(@"NewAUGraph failed %d",err);
	if ((err = AUGraphOpen(*auGraph)))
		NSLog(@"couldn't open graph %d",err);
	// add an output unit
	AudioComponentDescription outputDesc = {kAudioUnitType_Output, kAudioUnitSubType_DefaultOutput, kAudioUnitManufacturer_Apple,0,0};
	if ((err = AUGraphAddNode(*auGraph, &outputDesc, &theOutputNode)))
		NSLog(@"couldn't create node for output unit %d",err);
	if ((err = AUGraphNodeInfo(*auGraph, theOutputNode, NULL, &outputUnit)))
		NSLog(@"couldn't get output unit from node %d",err);
	
	// add a timepitch unit
	AudioComponentDescription timepitchDesc = {kAudioUnitType_FormatConverter, kAudioUnitSubType_TimePitch, kAudioUnitManufacturer_Apple,0,0};
	if ((err = AUGraphAddNode(*auGraph, &timepitchDesc, &timePitchNode)))
		NSLog(@"couldn't create node for timepitch unit %d",err);
	if ((err = AUGraphNodeInfo(*auGraph, timePitchNode, NULL, &timePitchUnit)))
		NSLog(@"couldn't get timepitch unit from node %d",err);
	
	// add a mixer unit
	AudioComponentDescription mixerDesc = {kAudioUnitType_Mixer, kAudioUnitSubType_StereoMixer, kAudioUnitManufacturer_Apple,0,0};
	if ((err = AUGraphAddNode(*auGraph, &mixerDesc, &theMixerNode)))
		NSLog(@"couldn't create node for mixer unit %d",err);
	if ((err = AUGraphNodeInfo(*auGraph, theMixerNode, NULL, &mixerUnit)))
		NSLog(@"couldn't get mixer unit from node %d",err);
	
	UInt32 meteringMode = 1;
	if ((err = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_MeteringMode, kAudioUnitScope_Global, 0, &meteringMode, sizeof(meteringMode))))
		NSLog(@"couldn't set mixer's output stream format %d",err);
	// add a player
	AudioComponentDescription playerDesc = {kAudioUnitType_Generator, kAudioUnitSubType_ScheduledSoundPlayer, kAudioUnitManufacturer_Apple,0,0};
	if ((err = AUGraphAddNode(*auGraph, &playerDesc, &thePlayerNode)))
		NSLog(@"couldn't create node for file player %d",err);
	if ((err = AUGraphNodeInfo(*auGraph, thePlayerNode, NULL, &playerUnit)))
		NSLog(@"couldn't get player unit from node %d",err);
	
	AudioStreamBasicDescription theAudioFormat;
	UInt32 propertySize = sizeof(theAudioFormat);
	err = AudioUnitGetProperty(playerUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Global, 0, &theAudioFormat, &propertySize);
	
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	SetCanonical(theAudioFormat,audioData.noChannels, false /* deinterleaved */);
	if ((err = AudioUnitSetProperty(playerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Global, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set player's output stream format %d",err);
	
	
	// connect the player to the mixer unit (stream format will propagate)
	if ((err = AUGraphConnectNodeInput(*auGraph, thePlayerNode, 0, theMixerNode, 0)))
		NSLog(@"couldn't connect player to mixer unit %d",err);
	
	
	// connect the mixer to the timepitch unit (stream format will propagate)
	if ((err = AUGraphConnectNodeInput(*auGraph, theMixerNode, 0, timePitchNode, 0)))
		NSLog(@"couldn't connect mixer to timepitch unit %d",err);
	
	// connect the timepitch to the output unit (stream format will propagate)
	if ((err = AUGraphConnectNodeInput(*auGraph, timePitchNode, 0, theOutputNode, 0)))
		NSLog(@"couldn't connect timepitch to output unit %d",err);
	
	err = AudioUnitGetProperty(mixerUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Input, 0, &theAudioFormat, &propertySize);
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	if ((err = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set mixer's output stream format %d",err);
	err = AudioUnitGetProperty(mixerUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output, 0, &theAudioFormat, &propertySize);
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	if ((err = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set mixer's output stream format %d",err);
	err = AudioUnitGetProperty(outputUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Input, 0, &theAudioFormat, &propertySize);
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	if ((err = AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set output's output stream format %d",err);
	err = AudioUnitGetProperty(timePitchUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output, 0, &theAudioFormat, &propertySize);
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	if ((err = AudioUnitSetProperty(timePitchUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set timepitch's output stream format %d",err);
	err = AudioUnitGetProperty(outputUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output, 0, &theAudioFormat, &propertySize);
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	if ((err = AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set output's output stream format %d",err);
	
	// initialize the AUGraph
	if ((err = AUGraphInitialize(*auGraph)))
		NSLog(@"couldn't initialize graph %d",err);
	
}

-(void)stopAndResetGraph
{
	if (auGraph)
	{
		OSErr err = AUGraphStop(*auGraph);
		if (err)
			NSLog(@"AUGraphStop %d",err);
		err = AudioUnitReset(playerUnit, kAudioUnitScope_Global, 0);
		err = AudioUnitReset(mixerUnit, kAudioUnitScope_Global, 0);
		err = AudioUnitReset(outputUnit, kAudioUnitScope_Global, 0);
		err = AudioUnitReset(timePitchUnit, kAudioUnitScope_Global, 0);
	}
}

-(void)stopAndResetBurstGraph
{
	if (burstGraph)
	{
		OSErr err = AUGraphStop(*burstGraph);
		if (err)
			NSLog(@"AUGraphStop %d",err);
		err = AudioUnitReset(bPlayerUnit, kAudioUnitScope_Global, 0);
		err = AudioUnitReset(bMixerUnit, kAudioUnitScope_Global, 0);
		err = AudioUnitReset(bOutputUnit, kAudioUnitScope_Global, 0);
		for (int i = 0;i < BURST_NO_TIMEPITCHUNITS;i++)
			err = AudioUnitReset(bTimePitchUnit[i], kAudioUnitScope_Global, 0);
	}
}


-(void)setUpBurstScheduleStartFrame:(SInt64)st frames:(SInt64)framesToPlay
{
	if (!burstGraph)
		[self setUpBurstGraph];
	burstSlice.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
	burstSlice.mTimeStamp.mSampleTime = 0;
	burstSlice.mCompletionProc = nil;
	burstSlice.mCompletionProcUserData = nil;
	burstSlice.mReserved = 0;
	burstSlice.mReserved2 = 0;
	burstSlice.mNumberFrames = (UInt32)framesToPlay;
	AudioBufferList *aBL = (AudioBufferList*)calloc(1, sizeof(*aBL) + 1 *sizeof(aBL->mBuffers[0]));
	aBL->mNumberBuffers = 2;
	int framesInBuffer = scheduledSlice.mNumberFrames;
	int bufSz = framesInBuffer * clientFormat.mBytesPerFrame;
	for (int i = 0; i < 2; i++)
	{
		aBL->mBuffers[i].mDataByteSize = bufSz;
		aBL->mBuffers[i].mData = audioData.audioData[i] + audioData.startFrame;
		aBL->mBuffers[i].mNumberChannels = 1;
	}
	burstSlice.mBufferList = aBL;
	OSErr err = AudioUnitSetProperty(bPlayerUnit, kAudioUnitProperty_ScheduleAudioSlice, kAudioUnitScope_Global, 0, &burstSlice, sizeof(ScheduledAudioSlice));
	if (err)
		NSLog(@"schedule region: error %ld\n", (long int)err);
	
	err = AudioUnitSetParameter(bMixerUnit, kStereoMixerParam_Volume, kAudioUnitScope_Input, 0, audioData.volume, 0);
	if (err)
		NSLog(@"SetVolume AudioUnitSetParameter kStereoMixerParam_Volume %d",err);
	AudioTimeStamp startTime;
	startTime.mFlags = kAudioTimeStampSampleTimeValid;
	startTime.mSampleTime = -1;
	err = AudioUnitSetProperty(bPlayerUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTime, sizeof(startTime));
	if (err)
		NSLog(@"AudioUnitSetProperty %d",err);
	//CAShow(*burstGraph);
}

-(void)setUpScheduleStartFrame:(SInt64)st frames:(SInt64)framesToPlay flags:(unsigned)schedFlags
{
	abort = NO;
	if (!auGraph)
		[self setUpGraph];
	scheduledSlice.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
	scheduledSlice.mTimeStamp.mSampleTime = 0;
	if (schedFlags & USE_CALLBACKS)
	{
		scheduledSlice.mCompletionProc = SliceCompletionProc;
		scheduledSlice.mCompletionProcUserData = self;
	}
	else
	{
		scheduledSlice.mCompletionProc = nil;
		scheduledSlice.mCompletionProcUserData = nil;
	}
	scheduledSlice.mReserved = 0;
	scheduledSlice.mReserved2 = 0;
	audioData.startFrame = st;
	audioData.playTime.mFlags = kAudioTimeStampSampleTimeValid;
	audioData.playTime.mSampleTime = 0;
	if (framesToPlay < 0)
		scheduledSlice.mNumberFrames = (UInt32)(audioData.totalFrames - st);
	else
		scheduledSlice.mNumberFrames = (UInt32)framesToPlay;
    audioData.endFrame = audioData.startFrame + scheduledSlice.mNumberFrames;
	AudioBufferList *aBL = (AudioBufferList*)calloc(1, sizeof(*aBL) + 1 *sizeof(aBL->mBuffers[0]));
	aBL->mNumberBuffers = audioData.noChannels;
	int framesInBuffer = scheduledSlice.mNumberFrames;
	int bufSz = framesInBuffer * clientFormat.mBytesPerFrame;
	for (int i = 0; i < audioData.noChannels; i++)
	{
		aBL->mBuffers[i].mDataByteSize = bufSz;
		aBL->mBuffers[i].mData = audioData.audioData[i] + audioData.startFrame;
		aBL->mBuffers[i].mNumberChannels = 1;
	}
	scheduledSlice.mBufferList = aBL;
	OSErr err = AudioUnitSetProperty(playerUnit, kAudioUnitProperty_ScheduleAudioSlice, kAudioUnitScope_Global, 0, &scheduledSlice, sizeof(ScheduledAudioSlice));
	if (err)
		NSLog(@"schedule region: error %ld\n", (long int)err);
	for (int i = 0; i < audioData.noChannels; i++)
        audioData.dataPosition[i] = audioData.audioData[i];
	audioData.fadeInActive = NO;
	audioData.fadeOutActive = NO;
    err = AudioUnitRemoveRenderNotify(mixerUnit, VolumeRenderCallback,&audioData);
    if (err)
        NSLog(@"AudioUnitRemoveRenderNotify mixerunit %d",err);
	if ((schedFlags & USE_FADES) && (fadeIn > 0 || fadeOut > 0))
    {
        err = AudioUnitAddRenderNotify(mixerUnit, VolumeRenderCallback,&audioData);
        if (err)
            NSLog(@"AudioUnitAddRenderNotify mixerUnit %d",err);
		else
		{
			if (frameSelection.length > 0)
			{
				audioData.mixerUnit = mixerUnit;
				if (fadeIn > 0.0)
				{
					audioData.fadeInActive = YES;
					audioData.fadeInSE.startFrame = frameSelection.location;
					audioData.fadeInSE.endFrame = audioData.fadeInSE.startFrame + (fadeIn * clientFormat.mSampleRate);
					audioData.fadeInSE.startVol = 0.0;
					audioData.fadeInSE.endVol = audioData.volume;
				}
				if (fadeOut > 0.0)
				{
					audioData.fadeOutActive = YES;
					audioData.fadeOutSE.endFrame = frameSelection.location + frameSelection.length;
					audioData.fadeOutSE.startFrame = audioData.fadeOutSE.endFrame - (fadeOut * clientFormat.mSampleRate);
					audioData.fadeOutSE.endVol = 0.0;
					audioData.fadeOutSE.startVol = audioData.volume;
				}
			}
		}
	}
    err = AudioUnitRemoveRenderNotify(playerUnit, PlayerRenderCallback,&audioData);
    if (err)
        NSLog(@"AudioUnitRemoveRenderNotify playerUnit %d",err);
	if (schedFlags & USE_CALLBACKS)
	{
        err = AudioUnitAddRenderNotify(playerUnit, PlayerRenderCallback,&audioData);
        if (err)
            NSLog(@"AudioUnitAddRenderNotify playerUnit %d",err);
    }
	
	err = AudioUnitSetParameter(mixerUnit, kStereoMixerParam_Volume, kAudioUnitScope_Input, 0, audioData.volume, 0);
	if (err)
		NSLog(@"SetVolume AudioUnitSetParameter kStereoMixerParam_Volume %d",err);
	err = AudioUnitSetParameter(timePitchUnit, kTimePitchParam_Pitch, kAudioUnitScope_Global, 0, pitch, 0);
	if (err)
		NSLog(@"SetVolume AudioUnitSetParameter kTimePitchParam_Pitch %d",err);
	float r;
	if (schedFlags & BURSTING)
		r = 0.25;
	else
		r = rate;
	err = AudioUnitSetParameter(timePitchUnit, kTimePitchParam_Rate, kAudioUnitScope_Global, 0, r, 0);
	if (err)
		NSLog(@"SetVolume AudioUnitSetParameter kTimePitchParam_Rate %d",err);
	AudioTimeStamp startTime;
	startTime.mFlags = kAudioTimeStampSampleTimeValid;
	startTime.mSampleTime = -1;
	err = AudioUnitSetProperty(playerUnit, kAudioUnitProperty_ScheduleStartTimeStamp, kAudioUnitScope_Global, 0, &startTime, sizeof(startTime));
	if (err)
		NSLog(@"AudioUnitSetProperty %d",err);
}

-(void)playTrackStartFrame:(SInt64)st frames:(SInt64)framesToPlay
{
	
}

-(void)updateCurrentAndRemainingTime
{
	if (self.displayFrames)
	{
		[doc.currentTimeField setObjectValue:[NSString stringWithFormat:@"%lld",[self currentFrame]]];
		[doc.remainingTimeField setObjectValue:[NSString stringWithFormat:@"-%lld",(audioData.totalFrames-[self currentFrame])]];
	}
	else
	{
		[doc.currentTimeField setObjectValue:DurationFromTime([self currentFrame] * 1.0 / clientFormat.mSampleRate,3)];
		[doc.remainingTimeField setObjectValue:
     [NSString stringWithFormat:@"-%@",DurationFromTime((audioData.totalFrames-[self currentFrame]) * 1.0 / clientFormat.mSampleRate,3)]];
	}
}

-(void)updatePlayPositionScrollToVisible:(BOOL)scrollToVisible
{
	double frac = ([self currentFrame] * 1.0) / audioData.totalFrames;
	if (frac > 1.0)
	{
		frac = 1.0;
		/*if (playing)
			[self stop];*/
		[self updateButton];
	}
	[self updateCurrentAndRemainingTime];
	[[self waveView] movePlayPosition:frac scrollToVisible:YES];
}

-(void)updatePlay
{
	[self updatePlayPositionScrollToVisible:YES];
	if (mixerUnit != 0)
	{
		AudioUnitParameterValue l,r;
		OSStatus err = AudioUnitGetParameter(mixerUnit, kStereoMixerParam_PostAveragePower, kAudioUnitScope_Output, 0, &l);
		if (err)
			NSLog(@"AudioUnitGetParameter left channel level %d",err);
		err = AudioUnitGetParameter(mixerUnit, kStereoMixerParam_PostAveragePower+1, kAudioUnitScope_Output, 0, &r);
		if (err)
			NSLog(@"AudioUnitGetParameter right channel level %d",err);
		[doc.meterView setLevelLeft:l right:r];
	}
}

-(void)updatePlay:(id)stuff
{
	[self updatePlay];
}

-(void)scheduleTimer
{
	updateTimer = [[NSTimer alloc] initWithFireDate:[NSDate date]
										   interval:0.020
											 target:self
										   selector:@selector(updatePlay:)
										   userInfo:nil
											repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:updateTimer forMode:NSRunLoopCommonModes];
	[updateTimer release];
}

-(void)updateButton
{
	if (playing)
		[playButton setImage:pauseImage];
	else
		[playButton setImage:playImage];
}

-(void)resetTime
{
	audioData.startFrame = [self currentFrame];
	audioData.playTime.mFlags = kAudioTimeStampSampleTimeValid;
	audioData.playTime.mSampleTime = 0;
}

-(void)play
{
	[self resetTime];
    SInt64 currFrame = [self currentFrame];
    if (currFrame >= audioData.totalFrames - 1)
	{
        [self goToStart];
		currFrame = 0;
	}
    if (frameSelection.length > 0)
    {
        SInt64 endSel = frameSelection.location + frameSelection.length;
        if (currFrame > frameSelection.location && currFrame < endSel)
            [self setUpScheduleStartFrame:currFrame frames:endSel - currFrame flags:USE_CALLBACKS|USE_FADES];
        else
            [self setUpScheduleStartFrame:frameSelection.location frames:frameSelection.length flags:USE_CALLBACKS|USE_FADES];
    }
    else
        [self setUpScheduleStartFrame:currFrame frames:-1 flags:USE_CALLBACKS];
	playing = YES;
	OSErr err = AUGraphStart(*auGraph);
	if (err)
		NSLog(@"AUGraphStart %d",err);
	[self updateButton];
	[self scheduleTimer];
}

-(void)playRange:(selection)range
{
	[self setUpScheduleStartFrame:range.location frames:range.length flags:USE_CALLBACKS];
	playing = YES;
	OSErr err = AUGraphStart(*auGraph);
	if (err)
		NSLog(@"AUGraphStart %d",err);
	[self updateButton];
	[self scheduleTimer];
}

-(void)stop
{
	[self stopAndResetGraph];
	playing = NO;
	[self updateButton];
	[updateTimer invalidate];
	updateTimer = nil;
	[self setPosition:[self currentFrame]];
	[self updatePlayPositionScrollToVisible:YES];
}

-(void)stopPlay
{
	abort = YES;
	[self stop];
}

-(void)sliceFinished
{
	if (!abort)
	{
        UInt64 st = audioData.startFrame;
		[self stop];
		audioData.startFrame = st + scheduledSlice.mTimeStamp.mSampleTime + scheduledSlice.mNumberFrames;
		audioData.playTime.mFlags = kAudioTimeStampSampleTimeValid;
		audioData.playTime.mSampleTime = 0;
        [self setPosition:[self currentFrame]];
        [self updatePlayPositionScrollToVisible:YES];
	}
}

-(void)finishPlay
{
	[self stop];
	audioData.startFrame = 0;
	audioData.playTime.mFlags = kAudioTimeStampSampleTimeValid;
	audioData.playTime.mSampleTime = 0;
	[self updatePlay];
}

-(void)goToStart
{
	BOOL b = playing;
	[self stop];
	if (frameSelection.length > 0)
	{
		SInt64 currFrame = [self currentFrame];
		if (currFrame > frameSelection.location)
			currFrame = frameSelection.location;
		else
			currFrame = 0;
		//		audioData.startFrame = currFrame;
		[self setPosition:currFrame];
	}
	else
		[self setPosition:0];
	//		audioData.startFrame = 0;
	//	audioData.playTime.mFlags = kAudioTimeStampSampleTimeValid;
	//	audioData.playTime.mSampleTime = 0;
	//	[self updatePlay];
	if (b)
		[self play];
}

-(void)goToEnd
{
	BOOL b = playing;
	[self stop];
	if (frameSelection.length > 0)
	{
		SInt64 currFrame = [self currentFrame];
		if (currFrame < frameSelection.location + frameSelection.length)
			currFrame = frameSelection.location + frameSelection.length;
		else
			currFrame = audioData.totalFrames;
		//		audioData.startFrame = currFrame;
		[self setPosition:currFrame];
	}
	else
		[self setPosition:audioData.totalFrames];
	//		audioData.startFrame = audioData.totalFrames;
	//	audioData.playTime.mFlags = kAudioTimeStampSampleTimeValid;
	//	audioData.playTime.mSampleTime = 0;
	//	[self updatePlay];
	if (b)
		[self play];
	
}

-(void)spaceHit
{
	if (self.playing)
		[self stopPlay];
	else
		[self play];
}

-(void)setNormalisedPlayPosition:(double)f
{
	BOOL isPlaying = playing;
	if (isPlaying)
		[self stop];
	//	audioData.startFrame = f * audioData.totalFrames;
	[self setPosition:f * audioData.totalFrames];
	//	[self updatePlay];
	if (isPlaying)
		[self play];
}

-(NSBitmapImageRep*)imageRepOfSize:(NSSize)sz
{
	int width = sz.width;
	int height = sz.height;
	NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL
																	  pixelsWide:width pixelsHigh:height
																   bitsPerSample:8
																 samplesPerPixel:4
																		hasAlpha:YES
																		isPlanar:NO
																  colorSpaceName:NSCalibratedRGBColorSpace
																	 bytesPerRow:0
																	bitsPerPixel:0];
	if (bitmap == nil)
		return nil;
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
	[[NSColor clearColor]set];
	NSRectFill(NSMakeRect(0,0,width,height));
	[[NSColor blackColor]set];
	float midY = height / 2.0;
	float stride = audioData.totalFrames * 1.0 / width;
    for (int i = 0;i < width;i++)
	{
		Float32 val1 = audioData.audioData[0][(int)(i * stride)] * midY;
		Float32 val2 = 0;
        if (audioData.noChannels > 1)
            val2 = audioData.audioData[1][(int)(i * stride)] * midY;
		[NSBezierPath strokeLineFromPoint:NSMakePoint(i+0.5, midY-val1) toPoint:NSMakePoint(i+0.5, midY+val2)];
	}
	if (self.leftJumps)
	{
		[[NSColor redColor]set];
		for (NSNumber *n in self.leftJumps)
		{
			SInt64 i = [n integerValue];
			int x = i * 1.0 / audioData.totalFrames * width;
			[NSBezierPath strokeLineFromPoint:NSMakePoint(x+0.5, 0) toPoint:NSMakePoint(x+0.5, height)];
		}
		for (NSNumber *n in self.rightJumps)
		{
			SInt64 i = [n integerValue];
			int x = i * 1.0 / audioData.totalFrames * width;
			[NSBezierPath strokeLineFromPoint:NSMakePoint(x+0.5, 0) toPoint:NSMakePoint(x+0.5, height)];
		}
	}
	[NSGraphicsContext restoreGraphicsState];
	return [bitmap autorelease];
}

-(float)volume
{
	return audioData.volume;
}

-(BOOL)uSetRate:(float)r
{
	if (r == rate)
		return NO;
	[[[doc undoManager] prepareWithInvocationTarget:self] uSetRate:rate];
	rate = r;
	self.rate = r;
	if (playing)
	{
		OSStatus err = AudioUnitSetParameter(timePitchUnit, kTimePitchParam_Rate, kAudioUnitScope_Global, 0, rate, 0);
		if (err)
			NSLog(@"SetVolume AudioUnitSetParameter kTimePitchParam_Rate %d",err);
	}
	return YES;
}

-(void)setRate:(float)r
{
	if ([self uSetRate:r])
		[[doc undoManager] setActionName:@"Set Rate"];
}

-(BOOL)uSetPitch:(float)p
{
	if (p == pitch)
		return NO;
	[[[doc undoManager] prepareWithInvocationTarget:self] uSetPitch:pitch];
	pitch = p;
	self.pitch = p;
	if (playing)
	{
		OSStatus err = AudioUnitSetParameter(timePitchUnit, kTimePitchParam_Pitch, kAudioUnitScope_Global, 0, pitch, 0);
		if (err)
			NSLog(@"SetVolume AudioUnitSetParameter kTimePitchParam_Pitch %d",err);
	}
	return YES;
}

-(void)setPitch:(float)p
{
	if ([self uSetPitch:p])
		[[doc undoManager] setActionName:@"Set Pitch"];
}

-(BOOL)uSetVolume:(float)vol
{
	if (vol == audioData.volume)
		return NO;
	[[[doc undoManager] prepareWithInvocationTarget:self] uSetVolume:audioData.volume];
	audioData.volume = vol;
	self.volume = vol;
	if (playing)
	{
		OSStatus err = AudioUnitSetParameter(mixerUnit, kStereoMixerParam_Volume, kAudioUnitScope_Input, 0, vol, 0);
		if (err)
			NSLog(@"SetVolume AudioUnitSetParameter kStereoMixerParam_Volume %d",err);
	}
    [doc.waveClipView setNeedsDisplay:YES];
    [doc.waveClipView becomeFirstResponder];
	return YES;
}

-(void)setVolume:(float)vol
{
	if ([self uSetVolume:vol])
		[[doc undoManager] setActionName:@"Set Volume"];
}

-(BOOL)uSetFadeIn:(float)f
{
	if (f == fadeIn)
		return NO;
	[[[doc undoManager] prepareWithInvocationTarget:self] uSetFadeIn:f];
	fadeIn = f;
	self.fadeIn = f;
	return YES;
}

-(void)setFadeIn:(float)f
{
	if ([self uSetFadeIn:f])
		[[doc undoManager] setActionName:@"Set Fade In"];
}

-(BOOL)uSetFadeOut:(float)f
{
	if (f == fadeOut)
		return NO;
	[[[doc undoManager] prepareWithInvocationTarget:self] uSetFadeOut:f];
	fadeOut = f;
	self.fadeOut = f;
	return YES;
}

-(void)setFadeOut:(float)f
{
	if ([self uSetFadeOut:f])
		[[doc undoManager] setActionName:@"Set Fade Out"];
}

#define BURST_TIME_INTERVAL 0.25

-(void)stopBursts
{
	if (burstTimer)
	{
		[burstTimer invalidate];
		burstTimer = nil;
	}
    if (burstGraph)
    {
        [self stopAndResetBurstGraph];
    }
}

-(void)playBurst:(NSTimer*)timer
{
	if (burstGraph)
	{
		[self stopAndResetBurstGraph];
	}
	SInt64 startingFrame = [self currentFrame];
	SInt64 framesToPlay = clientFormat.mSampleRate * BURST_TIME_INTERVAL;
    if (startingFrame + framesToPlay > audioData.totalFrames)
        framesToPlay = audioData.totalFrames - startingFrame;
    if (framesToPlay > 12)
    {
        [self setUpBurstScheduleStartFrame:startingFrame frames:framesToPlay];
        AUGraphStart(*burstGraph);
    }
}


-(void)playBursts
{
	if (burstTimer)
		[burstTimer invalidate];
	burstTimer = [[NSTimer alloc] initWithFireDate:[NSDate date]
										  interval:BURST_TIME_INTERVAL
											target:self
										  selector:@selector(playBurst:)
										  userInfo:nil
										   repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer:burstTimer forMode:NSRunLoopCommonModes];
	[burstTimer release];
}

-(void)displaySelection
{
	if (frameSelection.length == 0)
		self.displaySelnEnd = nil;
	else
		if (self.displayFrames)
		{
			self.displaySelnStart = [NSString stringWithFormat:@"%lld",frameSelection.location];
			if (displaySelnLengthMode == 0)
				self.displaySelnEnd = [NSString stringWithFormat:@"%lld",frameSelection.location + frameSelection.length];
			else
				self.displaySelnEnd = [NSString stringWithFormat:@"%lld",frameSelection.length];
		}
		else
		{
			self.displaySelnStart = DurationFromTime(frameSelection.location * 1.0 / clientFormat.mSampleRate, 3);
			if (displaySelnLengthMode == 0)
				self.displaySelnEnd = DurationFromTime((frameSelection.location + frameSelection.length) * 1.0 / clientFormat.mSampleRate, 3);
			else
				self.displaySelnEnd = DurationFromTime(frameSelection.length * 1.0 / clientFormat.mSampleRate, 3);
		}
}

-(void)setDisplaySelnLengthMode:(int)i
{
	displaySelnLengthMode = i;
	[self displaySelection];
}

-(void)setDisplayFrames:(int)d
{
	_displayFrames = d;
	[self updateCurrentAndRemainingTime];
	[self displaySelection];
	[self updateDurationDisplay];
}

-(BOOL)uSetSelectionTo:(selection)seln
{
    if (seln.location == frameSelection.location && seln.length == frameSelection.length)
        return NO;
	[[[doc undoManager] prepareWithInvocationTarget:self] uSetSelectionTo:frameSelection];
    frameSelection = seln;
	[self displaySelection];
    [doc.waveClipView setNeedsDisplay:YES];
    return YES;
}

-(BOOL)uReverseSelection
{
    [[[doc undoManager] prepareWithInvocationTarget:self] uReverseSelection];
    [self reverseBuffersStartFrame:frameSelection.location length:frameSelection.length];
    [doc.waveClipView setNeedsDisplay:YES];
    return YES;
}

-(void)reverseSelection
{
    [self uReverseSelection];
    [[doc undoManager] setActionName:@"Select All"];
}

-(void)selectAll
{
    selection f;
    f.location = 0;
    f.length = audioData.totalFrames;
    [self uSetSelectionTo:f];
    [[doc undoManager] setActionName:@"Select All"];
}

-(void)selectNone
{
    selection f;
    f.location = 0;
    f.length = 0;
    [self uSetSelectionTo:f];
    [[doc undoManager] setActionName:@"Select None"];
}

-(void)updateDurationDisplay
{
	if (self.displayFrames)
		self.displayDuration = [NSString stringWithFormat:@"%lld frames", audioData.totalFrames];
	else
		self.displayDuration = [NSString stringWithFormat:@"%@",DurationFromTime(audioData.totalFrames * 1.0 / clientFormat.mSampleRate, 3)];
}
-(void)sizeChanged
{
	[[self waveView]adjustForSizeChange];
	[self updateDurationDisplay];
}

-(void)uInsertArchive:(NSString*)archiveName selection:(selection)seln
{
	[[[doc undoManager] prepareWithInvocationTarget:self] uClearSelection:seln archiveName:archiveName];
	NSArray *arr = [NSKeyedUnarchiver unarchiveObjectWithFile:archiveName];
	if (arr)
		[self reallocBufferWithData:arr atPoint:seln.location];
    [self sizeChanged];
}

-(void)uClearSelection:(selection)seln archiveName:(NSString*)archiveName
{
	[[[doc undoManager] prepareWithInvocationTarget:self] uInsertArchive:archiveName selection:seln];
	[self reallocBufferWithoutRange:seln];
    [self sizeChanged];
}

-(void)adjustGraphForFileOutput
{
	if (auGraph == nil)
		[self setUpGraph];
	OSStatus err = AUGraphRemoveNode(*auGraph,theOutputNode);
	if (err)
		NSLog(@"couldn't remove node");
	
	AudioComponentDescription genericIODesc = {kAudioUnitType_Output, kAudioUnitSubType_GenericOutput, kAudioUnitManufacturer_Apple,0,0};
	err = AUGraphAddNode(*auGraph, &genericIODesc, &theGenericIONode);
	if (err)
		NSLog(@"couldn't create node for io");
	err = AUGraphNodeInfo(*auGraph, theGenericIONode, NULL, &genericIOUnit);
	if (err)
		NSLog(@"couldn't get io unit from node");
	err = AUGraphConnectNodeInput(*auGraph, timePitchNode, 0, theGenericIONode, 0);
	if (err)
		NSLog(@"couldn't connect imepitch to output unit");
	
	AudioStreamBasicDescription theAudioFormat;
	UInt32 propertySize = sizeof(theAudioFormat);
	err = AudioUnitGetProperty(genericIOUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Input, 0, &theAudioFormat, &propertySize);
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	if ((err = AudioUnitSetProperty(genericIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set io's input stream format %d",err);
	err = AudioUnitGetProperty(genericIOUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Input, 0, &theAudioFormat, &propertySize);
	err = AudioUnitGetProperty(genericIOUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output, 0, &theAudioFormat, &propertySize);
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	if ((err = AudioUnitSetProperty(genericIOUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set io's output stream format %d",err);
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	if ((err = AudioUnitSetProperty(timePitchUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set timepitch's output stream format %d",err);
	err = AudioUnitGetProperty(genericIOUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output, 0, &theAudioFormat, &propertySize);
	err = AudioUnitReset(genericIOUnit, kAudioUnitScope_Global, 0);
	
	err = AUGraphUpdate(*auGraph,NULL);
	if (err)
		NSLog(@"couldn't update graph");
}

-(void)resetGraph
{
	OSStatus err = AUGraphRemoveNode(*auGraph,theGenericIONode);
	if (err)
		NSLog(@"couldn't remove node");
	
	AudioComponentDescription outputDesc = {kAudioUnitType_Output, kAudioUnitSubType_DefaultOutput, kAudioUnitManufacturer_Apple,0,0};
	err = AUGraphAddNode(*auGraph, &outputDesc, &theOutputNode);
	if (err)
		NSLog(@"couldn't create node for output unit");
	err = AUGraphNodeInfo(*auGraph, theOutputNode, NULL, &outputUnit);
	if (err)
		NSLog(@"couldn't get output unit from node");
	err = AUGraphConnectNodeInput(*auGraph, timePitchNode, 0, theOutputNode, 0);
	if (err)
		NSLog(@"couldn't connect mixer to output unit");
	AudioStreamBasicDescription theAudioFormat;
	UInt32 propertySize = sizeof(theAudioFormat);
	err = AudioUnitGetProperty(outputUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Input, 0, &theAudioFormat, &propertySize);
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	if ((err = AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set io's input stream format %d",err);
	err = AudioUnitGetProperty(outputUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output, 0, &theAudioFormat, &propertySize);
	theAudioFormat.mSampleRate = clientFormat.mSampleRate;
	if ((err = AudioUnitSetProperty(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &theAudioFormat, sizeof(AudioStreamBasicDescription))))
		NSLog(@"couldn't set io's output stream format %d",err);
	
	err = AudioUnitReset(outputUnit, kAudioUnitScope_Global, 0);
	
	err = AUGraphUpdate(*auGraph,NULL);
	if (err)
		NSLog(@"couldn't update graph");
}

-(void)updatePositions
{
    [self setPosition:[self currentFrame]];
    [self updatePlayPositionScrollToVisible:YES];
}

#pragma mark import/export

-(void)getBitrateAndQuality:(ExtAudioFileRef)file
{
	UInt32 propertySize;
	AudioConverterRef converter;
	OSStatus status;
    originalBitRate = 0;
	propertySize = sizeof(converter);
	if ((status = ExtAudioFileGetProperty(file, kExtAudioFileProperty_AudioConverter, &propertySize, &converter)))
	{
		[doc.errorHandler addError:@"Error getting converter" status:status severity:EH_INFO];
        return;
	}
	Boolean writable;
   	if ((status = AudioConverterGetPropertyInfo(converter, kAudioConverterEncodeBitRate,&propertySize,&writable)))
        return;
    UInt32 bitrate;
 	if ((status = AudioConverterGetProperty(converter, kAudioConverterEncodeBitRate,&propertySize,&bitrate)))
        return;
    originalBitRate = bitrate;
}

-(BOOL)setExtAudioFile:(ExtAudioFileRef)file bitRate:(int)bitRate quality:(int)quality
{
	UInt32 propertySize;
	AudioConverterRef converter;
	OSStatus status;
	propertySize = sizeof(converter);
	status = ExtAudioFileGetProperty(file, kExtAudioFileProperty_AudioConverter, &propertySize, &converter);
	if (status)
	{
		[doc.errorHandler addError:@"Error getting converter" status:status severity:EH_INFO];
		return YES;
	}
	AudioValueRange *bitrates;
	Boolean writable;
	status = AudioConverterGetPropertyInfo(converter, kAudioConverterApplicableEncodeBitRates,&propertySize,&writable);
	bitrates = (AudioValueRange*)malloc(propertySize);
	status = AudioConverterGetProperty(converter, kAudioConverterApplicableEncodeBitRates,&propertySize,bitrates);
	int noBitrates = propertySize / sizeof(AudioValueRange);
	UInt32 bitk = bitRate;
	if (bitk < bitrates[0].mMinimum)
		bitk = bitrates[0].mMinimum;
	if (bitk > bitrates[noBitrates - 1].mMaximum)
		bitk = bitrates[noBitrates - 1].mMaximum;
	free(bitrates);
	status = AudioConverterSetProperty(converter, kAudioConverterEncodeBitRate, sizeof(bitk), &bitk);
	if (status)
	{
		[doc.errorHandler addError:@"Couldn't set bitrate" status:status severity:EH_INFO];
		//		return YES;
	}
	// set quality
	
	UInt32 q;
	switch (quality)
	{
		case 0:
			q = kAudioConverterQuality_Min;
			break;
		case 1:
			q = kAudioConverterQuality_Low;
			break;
		case 2:
			q = kAudioConverterQuality_Medium;
			break;
		case 3:
			q = kAudioConverterQuality_High;
			break;
		case 4:
			q = kAudioConverterQuality_Max;
			break;
	}
	status = AudioConverterSetProperty(converter, kAudioConverterSampleRateConverterQuality, sizeof(q), &q);
	if (status)
	{
		[doc.errorHandler addError:@"Couldn't set quality" status:status severity:EH_INFO];
	}
	
	CFArrayRef config = NULL;
	status = ExtAudioFileSetProperty(file, kExtAudioFileProperty_ConverterConfig, sizeof(config), &config);
	if (status)
	{
		[doc.errorHandler addError:@"Couldn't resync config" status:status severity:EH_INFO];
		return YES;
	}
	return YES;
}

-(BOOL)writeToURL:(NSURL*)url
{
    return YES;
}

-(void)postLoadSuccess:(id)success
{
	doc.isLoading = NO;
	[[doc panelController]hideProgressPanel];
	self.playButton = doc.playButton;
	doc.waveClipView.controller = self;
	[doc postLoad];
	doc.segmentClipView.controller = self;
    [self updatePlayPositionScrollToVisible:YES];
}

-(long)sampleRate
{
	return inputFormat.mSampleRate;
}

void    SetCanonical(AudioStreamBasicDescription &asbd, UInt32 nChannels, bool interleaved)
// note: leaves sample rate untouched
{
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagsCanonical;
    asbd.mBitsPerChannel = 8 * sizeof(AudioSampleType);
    asbd.mChannelsPerFrame = nChannels;
    asbd.mFramesPerPacket = 1;
    if (interleaved)
        asbd.mBytesPerPacket = asbd.mBytesPerFrame = nChannels * sizeof(AudioSampleType);
    else {
        asbd.mBytesPerPacket = asbd.mBytesPerFrame = sizeof(AudioSampleType);
        asbd.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
    }
}

-(void)importTrackFromUrlInBackground:(NSURL*)url
{
	//NSAutoreleasePool *pool =[[NSAutoreleasePool alloc] init];
	ExtAudioFileRef audioFileRef;
	OSStatus err = ExtAudioFileOpenURL((CFURLRef)url,&audioFileRef);
	if (err)
    {
		NSLog(@"ExtAudioFileOpenURL %d",err);
		[self postLoadSuccess:@NO];
        return;
    }
	// get the input file format
	UInt32 size = sizeof(inputFormat);
	err = ExtAudioFileGetProperty(audioFileRef, kExtAudioFileProperty_FileDataFormat, &size, &inputFormat);
	if (err)
		NSLog(@"ExtAudioFileGetProperty kExtAudioFileProperty_FileDataFormat %d",err);
	//	printf ("Source File format: "); inputFormat.Print();
	//self.displayFormat = [[[NSString alloc]initWithBytes:&inputFormat.mFormatID length:4 encoding:NSASCIIStringEncoding]autorelease];
	self.displayFormat = (NSString*)UTCreateStringForOSType(inputFormat.mFormatID);
	AudioFileID afID;
	size = sizeof(afID);
	err = ExtAudioFileGetProperty(audioFileRef, kExtAudioFileProperty_AudioFile, &size, &afID);
	if (err)
		NSLog(@"ExtAudioFileGetProperty kExtAudioFileProperty_AudioFile %d",err);
	
	
	
	size = sizeof(fileFormat);
	err = AudioFileGetProperty(afID, kAudioFilePropertyFileFormat, &size, &fileFormat);
	if (err)
		NSLog(@"get file format: err=%ld\n", (long int)err);
    
	SInt64 npackets;
	size = sizeof(UInt64);
	err = AudioFileGetProperty(afID, kAudioFilePropertyAudioDataPacketCount, &size, &npackets);
	if (err || npackets == 0)
		NSLog(@"get data packet count: err=%ld npackets=%qd\n", (long int)err,npackets);
	
    clientFormat = inputFormat;
	//	FillOutASBDForLPCM(clientFormat,inputFormat.mSampleRate,2,32,32,YES,NO);
	audioData.noChannels = inputFormat.mChannelsPerFrame;
	SetCanonical(clientFormat,audioData.noChannels, false);
	//	printf ("Client File format: "); clientFormat.Print();
	
	size = sizeof(clientFormat);
	err = ExtAudioFileSetProperty(audioFileRef, kExtAudioFileProperty_ClientDataFormat, size, &clientFormat);
	if (err)
		NSLog(@"ExtAudioFileSetProperty kExtAudioFileProperty_ClientDataFormat %d",err);
	UInt64 frameUpperLimit = npackets * inputFormat.mFramesPerPacket;
	
	audioData.totalFrames = 0;
	// set up buffers
	UInt32 kSrcBufSize = 32768;
	char *srcBuffer[2];
    for (int i = 0;i < audioData.noChannels;i++)
    {
        srcBuffer[i] = (char*)malloc(kSrcBufSize);
        audioData.audioData[i] = (Float32*)malloc(frameUpperLimit * clientFormat.mBytesPerFrame);
        
        audioData.dataPosition[i] = audioData.audioData[i];
    }
	AudioBufferList *fillBufList = (AudioBufferList*)calloc(1, sizeof(*fillBufList) + 1 *sizeof(fillBufList->mBuffers[0]));
	fillBufList->mNumberBuffers = audioData.noChannels;
	for (int i = 0;i < audioData.noChannels;i++)
	{
		fillBufList->mBuffers[i].mNumberChannels = 1;
		fillBufList->mBuffers[i].mDataByteSize = kSrcBufSize;
		fillBufList->mBuffers[i].mData = srcBuffer[i];
	}
	float lastProgress = 0.0;
	while (1)
	{
		UInt32 numFrames = (kSrcBufSize / clientFormat.mBytesPerFrame);
		err = ExtAudioFileRead (audioFileRef, &numFrames, fillBufList);
		if (err)
			NSLog(@"ExtAudioFileRead %d",err);
		audioData.totalFrames += numFrames;
		if (numFrames)
		{
			[self processBuffer:srcBuffer noFrames:numFrames];
			float progress = audioData.totalFrames * 1.0 / frameUpperLimit;
			if (progress - lastProgress > 0.1)
			{
				[[doc panelController]updateProgress:progress];
				[doc panelController].progressPanelMessage = [NSString stringWithFormat:@"Read %lld of %lld frames",audioData.totalFrames,frameUpperLimit];
				lastProgress = progress;
				/*if ([[doc panelController]abort])
				 {
				 aborted = YES;
				 break;
				 }*/
			}
		}
		else
		{
			// this is our termination condition
			[[doc panelController]updateProgress:1.0];
			[doc panelController].progressPanelMessage = [NSString stringWithFormat:@"Read %lld of %lld frames",audioData.totalFrames,audioData.totalFrames];
			audioData.dataLength = audioData.dataPosition[0] - audioData.audioData[0];
			break;
		}
		
		//		err = ExtAudioFileWrite(outfile, numFrames, &fillBufList);
		//		XThrowIfError (err, "ExtAudioFileWrite");
	}
	for (int i = 0;i < 2;i++)
	{
		free(fillBufList->mBuffers[i].mData);
	}
	[self getBitrateAndQuality:audioFileRef];
	
	ExtAudioFileDispose(audioFileRef);
	[doc.nibLock lockWhenCondition:NIB_LOADED];
	[doc.nibLock unlock];
	self.displaySampleRate = inputFormat.mSampleRate;
    self.displayChannels = [NSString stringWithFormat:@"%d ch",audioData.noChannels];
	[self performSelectorOnMainThread:@selector(postLoadSuccess:) withObject:@YES waitUntilDone:NO];
	//[pool release];
}

-(void)importTrackFromUrl:(NSURL*)url
{
	[doc performSelector:@selector(showProgress) withObject:nil afterDelay:0.5];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[self importTrackFromUrlInBackground:url];
	});

	/*[NSThread detachNewThreadSelector:@selector(importTrackFromUrlInBackground:)
							 toTarget:self
						   withObject:url];*/
	
}


-(void)exportSoundFileToURL:(NSURL*)url fileType:(UInt32)outputFileType format:(UInt32)formatID bitRate:(int)bitRate quality:(int)quality frameRange:(selection)frameRange fades:(BOOL)fades
{
	[self adjustGraphForFileOutput];
	UInt32 propertySize;
	OSStatus status;
	AudioStreamBasicDescription ioFormat,outputFormat;
	propertySize = sizeof(ioFormat);
	status = AudioUnitGetProperty(genericIOUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output, 0, &ioFormat, &propertySize);
	if (formatID == kAudioFormatLinearPCM)
	{
		outputFormat.mFormatID = kAudioFormatLinearPCM;
		outputFormat.mSampleRate = ioFormat.mSampleRate;
		outputFormat.mChannelsPerFrame = 2;
		
		outputFormat.mBytesPerPacket = ioFormat.mChannelsPerFrame * 2;
		outputFormat.mFramesPerPacket = 1;
		outputFormat.mBytesPerFrame = ioFormat.mBytesPerPacket;
		outputFormat.mBitsPerChannel = 16;
		if (outputFileType == kAudioFileWAVEType)
			outputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger
			| kLinearPCMFormatFlagIsPacked;
		else
			outputFormat.mFormatFlags = kLinearPCMFormatFlagIsBigEndian
			| kLinearPCMFormatFlagIsSignedInteger
			| kLinearPCMFormatFlagIsPacked;
	}
	else
	{
		outputFormat.mFormatID = formatID;
		outputFormat.mSampleRate = ioFormat.mSampleRate;
		outputFormat.mChannelsPerFrame = ioFormat.mChannelsPerFrame;
		status = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &propertySize, &outputFormat);
		if (status)
			[doc.errorHandler addError:@"Couldn't get output format property" status:status severity:EH_WARNING];
	}
	ExtAudioFileRef outputFile;
	status = ExtAudioFileCreateWithURL((CFURLRef)url, outputFileType, &outputFormat, NULL, kAudioFileFlags_EraseFile, &outputFile);
	if (status)
	{
		[doc.errorHandler addError:@"Error opening output file" status:status severity:EH_COULDNT_COMPLETE];
		[self resetGraph];
		return;
	}
	
	propertySize = sizeof(ioFormat);
	if ((status = ExtAudioFileSetProperty(outputFile, kExtAudioFileProperty_ClientDataFormat, propertySize, &ioFormat)))
	{
		[doc.errorHandler addError:@"Error setting client format - probably no codec" status:status severity:EH_COULDNT_COMPLETE];
		[self resetGraph];
		return;
	}
	SInt64 maxFrames = frameRange.length / rate;
	unsigned schedflags = fades?USE_FADES:0;
    SInt64 savedStartFrame = audioData.startFrame;
    AudioTimeStamp savedTimestamp = audioData.playTime;
	
	[self setUpScheduleStartFrame:frameRange.location frames:frameRange.length flags:schedflags];
	status = AUGraphStart(*auGraph);
	if (status)
		NSLog(@"couldn't start graph %d",status);
	
	// Set bitrate
	[self setExtAudioFile:outputFile bitRate:bitRate quality:quality];
	
	// set up buffers
	UInt32 kSrcBufSize = 32768;
	//	char srcBuffer[kSrcBufSize];
	
	AudioTimeStamp ts;
	ts.mSampleTime = 0;
	ts.mFlags = kAudioTimeStampSampleTimeValid;
	propertySize = sizeof(UInt32);
	UInt32 maxFramesPerSlice;
	if ((status = AudioUnitGetProperty(genericIOUnit,kAudioUnitProperty_MaximumFramesPerSlice,kAudioUnitScope_Global, 0, &maxFramesPerSlice, &propertySize)))
		NSLog(@"AudioUnitGetProperty %d",status);
	UInt32 numFrames = (kSrcBufSize / clientFormat.mBytesPerFrame);
	if (numFrames > maxFramesPerSlice)
		numFrames = maxFramesPerSlice;
	AudioBufferList *outputABL = (AudioBufferList*)calloc(1, sizeof(*outputABL) + (clientFormat.mChannelsPerFrame - 1)*sizeof(outputABL->mBuffers[0]));
    outputABL->mNumberBuffers = clientFormat.mChannelsPerFrame;
    for (int channelIndex = 0; channelIndex < clientFormat.mChannelsPerFrame; channelIndex++)
	{
        UInt32 dataSize = numFrames * clientFormat.mBytesPerFrame;
        outputABL->mBuffers[channelIndex].mDataByteSize = dataSize;
        outputABL->mBuffers[channelIndex].mData = malloc(dataSize);
        outputABL->mBuffers[channelIndex].mNumberChannels = 1;
    }
	AudioUnitRenderActionFlags flags = 0;
	float lastProgress = 0.0;
	BOOL aborted = NO;
	while (1)
	{
		if (numFrames + ts.mSampleTime > maxFrames)
			numFrames = maxFrames - ts.mSampleTime;
		if (numFrames <= 0)
		{
			[[doc panelController]updateProgress:1.0];
			break;
		}
		if ((status = AudioUnitRender(genericIOUnit,&flags,&ts,0,numFrames,outputABL)))
			NSLog(@"AudioUnitRender %d",status);
		ts.mSampleTime += numFrames;
		if ((status = ExtAudioFileWrite(outputFile, numFrames, outputABL)))
			NSLog(@"ExtAudioFileWrite %d",status);
		float progress = ts.mSampleTime * 1.0 / maxFrames;
		if (progress - lastProgress > 0.1)
		{
			[[doc panelController]updateProgress:progress];
			lastProgress = progress;
			if ([[doc panelController]abort])
			{
				aborted = YES;
				break;
			}
		}
	}
	ExtAudioFileDispose(outputFile);
	if ((status = AUGraphStop(*auGraph)))
		NSLog(@"couldn't stop graph %d",status);
	[self resetGraph];
	[self stopAndResetGraph];
    for (int channelIndex = 0; channelIndex < clientFormat.mChannelsPerFrame; channelIndex++)
		free(outputABL->mBuffers[channelIndex].mData);
	free(outputABL);
	if (aborted)
		[[doc panelController]performSelectorOnMainThread:@selector(hideProgressPanelAndShowMessage:)
											   withObject:@"Export aborted"
											waitUntilDone:NO];
	else
	{
		NSString *message = [NSString stringWithFormat:@"%@ exported successfully",[url path]];
		[[doc panelController]performSelectorOnMainThread:@selector(hideProgressPanelAndShowReveal:)
											   withObject:[NSArray arrayWithObjects:message,url,nil]
											waitUntilDone:NO];
	}
    audioData.startFrame = savedStartFrame;
    audioData.playTime = savedTimestamp;
    [self performSelectorOnMainThread:@selector(updatePositions) withObject:nil waitUntilDone:NO];
}

-(void)saveSoundFileToURL:(NSURL*)url
{
	[self adjustGraphForFileOutput];
	UInt32 propertySize;
	OSStatus status;
	AudioStreamBasicDescription ioFormat,outputFormat;
    outputFormat = inputFormat;
	propertySize = sizeof(ioFormat);
	status = AudioUnitGetProperty(genericIOUnit,kAudioUnitProperty_StreamFormat,kAudioUnitScope_Output, 0, &ioFormat, &propertySize);
	
	ExtAudioFileRef outputFile;
	status = ExtAudioFileCreateWithURL((CFURLRef)url, fileFormat, &outputFormat, NULL, kAudioFileFlags_EraseFile, &outputFile);
	if (status)
	{
		[doc.errorHandler addError:@"Error opening output file" status:status severity:EH_COULDNT_COMPLETE];
		[self resetGraph];
		return;
	}
	
	propertySize = sizeof(ioFormat);
	if ((status = ExtAudioFileSetProperty(outputFile, kExtAudioFileProperty_ClientDataFormat, propertySize, &ioFormat)))
	{
		[doc.errorHandler addError:@"Error setting client format - probably no codec" status:status severity:EH_COULDNT_COMPLETE];
		[self resetGraph];
		return;
	}
	[self setUpScheduleStartFrame:0 frames:audioData.totalFrames flags:0];
	status = AUGraphStart(*auGraph);
	if (status)
		NSLog(@"couldn't start graph %d",status);
	
	// Set bitrate
    if (originalBitRate > 0)
        [self setExtAudioFile:outputFile bitRate:originalBitRate quality:4];
	
	// set up buffers
	UInt32 kSrcBufSize = 32768;
	//	char srcBuffer[kSrcBufSize];
	
	AudioTimeStamp ts;
	ts.mSampleTime = 0;
	ts.mFlags = kAudioTimeStampSampleTimeValid;
	propertySize = sizeof(UInt32);
	UInt32 maxFramesPerSlice;
	if ((status = AudioUnitGetProperty(genericIOUnit,kAudioUnitProperty_MaximumFramesPerSlice,kAudioUnitScope_Global, 0, &maxFramesPerSlice, &propertySize)))
		NSLog(@"AudioUnitGetProperty %d",status);
	UInt32 numFrames = (kSrcBufSize / clientFormat.mBytesPerFrame);
	if (numFrames > maxFramesPerSlice)
		numFrames = maxFramesPerSlice;
	AudioBufferList *outputABL = (AudioBufferList*)calloc(1, sizeof(*outputABL) + (clientFormat.mChannelsPerFrame - 1)*sizeof(outputABL->mBuffers[0]));
    outputABL->mNumberBuffers = clientFormat.mChannelsPerFrame;
    for (int channelIndex = 0; channelIndex < clientFormat.mChannelsPerFrame; channelIndex++)
	{
        UInt32 dataSize = numFrames * clientFormat.mBytesPerFrame;
        outputABL->mBuffers[channelIndex].mDataByteSize = dataSize;
        outputABL->mBuffers[channelIndex].mData = malloc(dataSize);
        outputABL->mBuffers[channelIndex].mNumberChannels = 1;
    }
	AudioUnitRenderActionFlags flags = 0;
	float lastProgress = 0.0;
	BOOL aborted = NO;
	while (1)
	{
		if (numFrames + ts.mSampleTime > audioData.totalFrames)
			numFrames = audioData.totalFrames - ts.mSampleTime;
		if (numFrames <= 0)
		{
			[[doc panelController]updateProgress:1.0];
			break;
		}
		if ((status = AudioUnitRender(genericIOUnit,&flags,&ts,0,numFrames,outputABL)))
			NSLog(@"AudioUnitRender %d",status);
		ts.mSampleTime += numFrames;
		if ((status = ExtAudioFileWrite(outputFile, numFrames, outputABL)))
			NSLog(@"ExtAudioFileWrite %d",status);
		float progress = ts.mSampleTime * 1.0 / audioData.totalFrames;
		if (progress - lastProgress > 0.1)
		{
			[[doc panelController]updateProgress:progress];
			lastProgress = progress;
			if ([[doc panelController]abort])
			{
				aborted = YES;
				break;
			}
		}
	}
	ExtAudioFileDispose(outputFile);
	if ((status = AUGraphStop(*auGraph)))
		NSLog(@"couldn't stop graph %d",status);
	[self resetGraph];
    for (int channelIndex = 0; channelIndex < clientFormat.mChannelsPerFrame; channelIndex++)
		free(outputABL->mBuffers[channelIndex].mData);
	free(outputABL);
	if (aborted)
		[[doc panelController]performSelectorOnMainThread:@selector(hideProgressPanelAndShowMessage:)
                                               withObject:@"Export aborted"
                                            waitUntilDone:NO];
}

-(void)exportSoundFileWithAttributes2:(NSDictionary*)dict
{
	NSAutoreleasePool *pool =[[NSAutoreleasePool alloc] init];
	[doc.errorHandler reset];
	NSURL *url = [dict objectForKey:@"url"];
	UInt32 outputfiletype = [[dict objectForKey:@"outputfiletype"]unsignedIntValue];
    if (outputfiletype == 0)
        outputfiletype = fileFormat;
	UInt32 outputformat = [[dict objectForKey:@"outputformat"]unsignedIntValue];
    if (outputformat == 0)
        outputformat = inputFormat.mFormatID;
	int bitRate = [[dict objectForKey:@"bitRate"]intValue];
	int quality = [[dict objectForKey:@"quality"]intValue];
	BOOL useSelection = [[dict objectForKey:@"useSelection"]boolValue];
	BOOL fades = [[dict objectForKey:@"fades"]boolValue];
	selection fs;
	if (useSelection)
		fs = frameSelection;
	else
	{
		fs.location = 0;
		fs.length = audioData.totalFrames;
	}
	[self exportSoundFileToURL:url fileType:outputfiletype format:outputformat bitRate:bitRate quality:quality frameRange:fs fades:fades];
	if (doc.errorHandler.maxSeverity > 0)
	{
		[[doc panelController]performSelectorOnMainThread:@selector(hideProgressPanel)
											   withObject:nil
											waitUntilDone:YES];
		[doc.errorHandler performSelectorOnMainThread:@selector(showMessagePanelWithMessage:)withObject:@"Some Errors Occurred" waitUntilDone:NO];
	}
	[pool release];
	
	
}

-(void)exportSoundFileWithAttributes:(NSDictionary*)dict
{
	[[doc panelController]showProgressPanelForWindow:[doc window]];
	[NSThread detachNewThreadSelector:@selector(exportSoundFileWithAttributes2:)
							 toTarget:self
						   withObject:dict];
}

-(float)volumeForFrame:(SInt64)f
{
	return audioData.volume;
}

#pragma mark mark/selection

-(BOOL)uSetMarkedTo:(selection)mk
{
    if (mk.location == markedRange.location && mk.length == markedRange.length)
        return NO;
	[[[doc undoManager] prepareWithInvocationTarget:self] uSetMarkedTo:markedRange];
    markedRange = mk;
    [doc.waveClipView setNeedsDisplay:YES];
    return YES;
}

-(void)setInPoint
{
    SInt64 outpt=0;
    selection mk = markedRange;
    if (mk.length > 0)
        outpt = mk.location + mk.length;
    mk.location = [self currentFrame];
    if (outpt <= mk.location)
        mk.length = 0;
    else
        mk.length = outpt - mk.location;
    if ([self uSetMarkedTo:mk])
        [[doc undoManager] setActionName:@"Set In Point"];
}

-(void)setOutPoint
{
    SInt64 outpt = [self currentFrame];
    selection mk = markedRange;
    if (outpt <= mk.location)
        mk.length = 0;
    else
        mk.length = outpt - mk.location;
    if ([self uSetMarkedTo:mk])
        [[doc undoManager] setActionName:@"Set Out Point"];
}

-(void)setPos:(SInt64)frame
{
	audioData.startFrame = frame;
	audioData.playTime.mFlags = kAudioTimeStampSampleTimeValid;
	audioData.playTime.mSampleTime = 0;
	[self updatePlay];
}

-(void)setPosition:(SInt64)frame
{
	[self setPos:frame];
	[nextPositions removeAllObjects];
	if ([previousPositions count] > 0)
	{
		NSNumber *n = [previousPositions lastObject];
		if ([n longLongValue] == frame)
			return;
	}
	[previousPositions addObject:[NSNumber numberWithLongLong:frame]];
	
}

-(void)goToInPoint
{
	BOOL wasPlaying = [self playing];
	if (wasPlaying)
    {
        self.abort = YES;
		[self finishPlay];
    }
	[self setPosition:markedRange.location];
	if (wasPlaying)
		[self play];
	
}

-(void)goToPreviousPosition
{
	if ([previousPositions count] > 1)
	{
		NSNumber *n = [previousPositions lastObject];
		[nextPositions addObject:n];
		[previousPositions removeLastObject];
		n = [previousPositions lastObject];
		[self setPos:[n longLongValue]];
	}
}

-(void)goToNextPosition
{
	if ([nextPositions count] > 0)
	{
		NSNumber *n = [nextPositions lastObject];
		[self setPos:[n longLongValue]];
		[previousPositions addObject:n];
		[nextPositions removeLastObject];
	}
}

-(void)goToOutPoint
{
   	BOOL wasPlaying = [self playing];
	if (wasPlaying)
    {
        self.abort = YES;
		[self finishPlay];
    }
	[self setPosition:markedRange.location + markedRange.length];
	if (wasPlaying)
		[self play];
}

-(void)selectMarked
{
    [self uSetSelectionTo:markedRange];
    [[doc undoManager] setActionName:@"Select Marked"];
}

-(void)selectToStart
{
	selection seln;
	seln.location = 0;
	if (frameSelection.length > 0)
		seln.length = frameSelection.location + frameSelection.length;
	else
		seln.length = [self currentFrame];
    [self uSetSelectionTo:seln];
    [[doc undoManager] setActionName:@"Select To Start"];
}

-(void)selectToEnd
{
	selection seln;
	if (frameSelection.length > 0)
		seln.location = frameSelection.location;
	else
		seln.location = [self currentFrame];
	seln.length = audioData.totalFrames - seln.location;
    [self uSetSelectionTo:seln];
    [[doc undoManager] setActionName:@"Select To End"];
}

@end

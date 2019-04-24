//
//  AudioContainer.h
//  AuEd
//
//  Created by alan on 03/04/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
//#include <vecLib/vDSP.h>
#include <AudioToolbox/AudioToolbox.h>
#include <CoreAudio/CoreAudioTypes.h>
#include <CoreFoundation/CoreFoundation.h>

#include "PA_Document.h"

#define	AUDIO_PLAYBACK_RATE	44100
#define BURST_NO_TIMEPITCHUNITS 1

NSString* DurationFromTime(float seconds,int places);

struct selection
{
    UInt64 location,length;
};

struct ScheduleEvent
{
	SInt64 startFrame,endFrame;
	float startVol,endVol;
};

struct AudioData
{
	int noChannels;
    Float32 *audioData[5],*dataPosition[5];
	UInt64 totalFrames;
    UInt64 dataLength;
	id container;
	AudioTimeStamp playTime;
	UInt64 startFrame,endFrame;
	ScheduleEvent fadeInSE,fadeOutSE;
	BOOL fadeInActive,fadeOutActive;
	AudioUnit mixerUnit;
	float volume;
    AudioBufferList *burstBufferList;
} ;

@interface AudioContainer : NSObject
{
	AUGraph *auGraph,*burstGraph;
	AUNode theMixerNode,theOutputNode,theGenericIONode,timePitchNode;
	AudioUnit playerUnit,outputUnit,mixerUnit,genericIOUnit,timePitchUnit;
	AudioUnit bPlayerUnit,bMixerUnit,bOutputUnit,bTimePitchUnit[BURST_NO_TIMEPITCHUNITS];
	AudioData audioData;
	AudioStreamBasicDescription inputFormat,clientFormat;
	ScheduledAudioSlice scheduledSlice,burstSlice;
	BOOL playing,burstBefore;
	NSButton *playButton;
	NSTimer *updateTimer,*burstTimer;
	PA_Document *doc;
    selection frameSelection,markedRange;
	BOOL abort;
	int nextTempFile;
	float fadeIn,fadeOut,pitch,rate;
	NSMutableArray *previousPositions,*nextPositions;
    UInt32 originalBitRate,fileFormat;
	int displaySampleRate,displaySelnLengthMode;
	NSString *displayDuration,*displaySelnStart,*displaySelnEnd,*displayChannels,*displayFormat;
}

@property BOOL playing,burstBefore,abort;
@property (assign) NSButton *playButton;
@property (assign) PA_Document *doc;
@property (nonatomic) float volume,fadeIn,fadeOut,pitch,rate;
@property selection frameSelection,markedRange;
@property (retain) NSMutableArray *previousPositions,*nextPositions,*leftJumps,*rightJumps;
@property (nonatomic) int displaySampleRate,displaySelnLengthMode,displayFrames;
@property (retain) NSString *displayDuration,*displaySelnStart,*displaySelnEnd,*displayChannels,*displayFormat;



-(void)importTrackFromUrl:(NSURL*)url;
-(void)play;
-(void)playRange:(selection)range;
-(void)stop;
-(void)stopPlay;

-(void)finishPlay;
-(void)scheduleTimer;
-(void)goToStart;
-(void)goToEnd;
-(SInt64)totalFrames;
-(void)spaceHit;
-(Float32*)leftData;
-(Float32*)rightData;
-(double)normalisedCurrentFrame;
-(void)playBursts;
-(void)stopBursts;
-(void)setNormalisedPlayPosition:(double)f;
-(NSBitmapImageRep*)imageRepOfSize:(NSSize)sz;
-(void)selectAll;
-(void)selectNone;
-(UInt64)currentFrame;
-(BOOL)uSetSelectionTo:(selection)seln;
-(float)volumeForFrame:(SInt64)f;
-(void)updatePlayPositionScrollToVisible:(BOOL)scrollToVisible;
-(void)setInPoint;
-(void)setOutPoint;
-(void)goToInPoint;
-(void)goToOutPoint;
-(void)selectMarked;
-(void)selectToStart;
-(void)selectToEnd;
-(void)goToPreviousPosition;
-(void)goToNextPosition;
-(void)exportSoundFileWithAttributes:(NSDictionary*)dict;
-(void)sizeChanged;
-(void)reverseSelection;
-(long)sampleRate;
-(void)sliceFinished;



@end

//
//  PA_Document.m
//  PhraseAnal
//
//  Created by alan on 23/11/13.
//  Copyright (c) 2013 Alan C Smith. All rights reserved.
//

#import "PA_Document.h"
#import "AudioContainer.h"
#import "WaveClipView.h"
#import "WaveView.h"
#import "ExportSoundFileController.h"
#import "PanelController.h"
#import "Segment.h"
#import "PA_SegmentClipView.h"
#import "PA_SegmentView.h"
#import "ET_XMLManager.h"
#import <Accelerate/Accelerate.h>

@implementation PA_Document

@synthesize currentTimeField,waveClipView,errorHandler,panelController,remainingTimeField,meterView,
playButton,isLoading;

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName
{
    return YES;
}

- (id)init
{
    self = [super init];
    if (self)
	{
		_segments = [[NSMutableArray alloc]initWithCapacity:6];
		self.nibLock = [[[NSConditionLock alloc]initWithCondition:NIB_NOT_LOADED]autorelease];
    }
    return self;
}

-(void)dealloc
{
    [_segments release];
    self.audioContainer = nil;
    self.xml = nil;
    self.displayFileName = nil;
	[errorHandler release];
    self.audioURL = nil;
	self.nibLock = nil;
    [super dealloc];
}

- (NSString *)windowNibName
{
	return @"PA_Document";
}

-(void)showProgress
{
	if (isLoading)
		[[self panelController]showProgressPanelForWindow:[self window]];
	
}
- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
	[super windowControllerDidLoadNib:aController];
	[self.nibLock lock];
	[self.nibLock unlockWithCondition:NIB_LOADED];
    //[aController.window setMovableByWindowBackground:YES];
	if (isLoading)
		[self performSelector:@selector(showProgress) withObject:nil afterDelay:1.0];
}

- (void)saveDocument:(id)sender
{
	if (needsSaveAs)
    {
        needsSaveAs = NO;
		[self saveDocumentAs:sender];
    }
	else
		[super saveDocument:sender];
}

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    if ([typeName isEqualToString:@"xmltype"])
    {
        NSString *str = [self xmlStringURL:self.fileURL audio:self.audioURL ];
        [str writeToURL:absoluteURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
        return YES;
    }
    return NO;
}

-(void)importAudioFromURL:(NSURL*)url
{
    self.audioContainer = [[[AudioContainer alloc]init]autorelease];
	self.audioContainer.doc = self;
	isLoading = YES;
    self.audioURL = url;
    [self.audioContainer importTrackFromUrl:url];
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
		contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertSecondButtonReturn)
	{
		[self importAudio:self];
    }
}

-(void)showFileErrorAlert:(NSString*)path
{
	NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"Cancel"];
	[alert addButtonWithTitle:@"Locate…"];
	[alert setMessageText:@"Can't locate file."];
	[alert setInformativeText:[NSString stringWithFormat:@"Can't find file %@",path]];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)contextInfo:nil];
}

static NSString* OtherAudioExtension(NSString *s)
{
    if ([s isEqualToString:@"aif"])
        return @"m4a";
    return @"aif";
}

-(void)tryToImportAudioFromURL:(NSURL*)url docURL:(NSURL*)docURL relPath:(NSString*)relPath
{
	if ([[NSFileManager defaultManager]fileExistsAtPath:[url path]])
		[self importAudioFromURL:url];
	else
	{
        if (relPath)
        {
            NSString *dir = [[docURL path]stringByDeletingLastPathComponent];
            NSString *fname = [dir stringByAppendingPathComponent:relPath];
            if ([[NSFileManager defaultManager]fileExistsAtPath:fname])
            {
                [self importAudioFromURL:[NSURL fileURLWithPath:fname]];
                return;
            }
            NSString *ext = [fname pathExtension];
            ext = OtherAudioExtension(ext);
            fname = [[fname stringByDeletingPathExtension]stringByAppendingPathExtension:ext];
            if ([[NSFileManager defaultManager]fileExistsAtPath:fname])
            {
                [self importAudioFromURL:[NSURL fileURLWithPath:fname]];
                return;
            }
        }
		dispatch_async(dispatch_get_main_queue(), ^{
			[self showFileErrorAlert:[url path]];
		});
	}
}

- (IBAction)importAudio:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setAllowsMultipleSelection:NO];
	[panel setAllowedFileTypes:@[@"public.audio"]];
	[panel beginSheetModalForWindow:[self window]
				  completionHandler:^(NSInteger result)
	 {
		 if (result == NSFileHandlingPanelOKButton)
		 {
			 for (NSURL *url in [panel URLs])
				 [self importAudioFromURL:url];
		 }
	 }];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    if ([typeName isEqualToString:@"xmltype"])
    {
        ET_XMLNode  *node = [[[[ET_XMLManager alloc]init]autorelease]parseFile:[absoluteURL path]];
        NSURL *url = nil;
        NSString *relpath = nil;
        NSArray *arr = [node childrenOfType:@"url"];
        if ([arr count] > 0)
        {
            NSString *fn = [arr[0] contents];
            url = [NSURL URLWithString:fn];
        }
        arr = [node childrenOfType:@"relurl"];
        if ([arr count] > 0)
        {
            relpath = [arr[0] contents];
        }
        if (url || relpath)
            [self tryToImportAudioFromURL:url docURL:absoluteURL relPath:relpath];
        self.xml = node;
		needsSaveAs = NO;
        return YES;
    }
    else if ([typeName isEqualToString:@"audiotype"])
    {
		[self importAudioFromURL:absoluteURL];
		[self setFileType:@"xmltype"];
		[self setFileURL:[NSURL fileURLWithPath:[[[absoluteURL path]stringByDeletingPathExtension]stringByAppendingPathExtension:@"etpa"]]];
		needsSaveAs = YES;
        return YES;
    }
	return NO;
}

-(void)postLoad
{
    if (self.xml)
    {
        ET_XMLNode *timings = [self findTimings:self.xml];
        if (timings)
        {
            [phraseText setString:[timings attributeStringValue:@"text"]];
            NSMutableArray *segs = [NSMutableArray arrayWithCapacity:10];
            UInt64 totalFrames = self.audioContainer.totalFrames;
            for (ET_XMLNode *xmlseg in [timings childrenOfType:@"timing"])
            {
                float st = [xmlseg attributeFloatValue:@"startframe"];
                float len = [xmlseg attributeFloatValue:@"framelength"];
                Segment *seg = [[[Segment alloc]init]autorelease];
                selection range;
                range.location = st;
                range.length = len;
                if (range.location < totalFrames)
                {
                    if (range.location + range.length > totalFrames)
                        range.length = totalFrames - range.location;
                    
                    seg.range = range;
                    seg.text = [xmlseg attributeStringValue:@"text"];
                    [segs addObject:seg];
                }
            }
            self.segments = segs;
        }
        self.displayFileName = [self.audioURL path];
    }
    else
    {
        Segment *s = [[[Segment alloc]init]autorelease];
        struct selection se;
        se.location = 0;
        se.length = [self.audioContainer totalFrames];
        s.range = se;
        [_segments addObject:s];
    }
	self.displayFileName = [self.audioURL path];
	[[waveClipView window]makeFirstResponder:waveClipView];
}

-(IBAction)playButtonHit:(id)sender
{
	if (self.audioContainer.playing)
		[self.audioContainer stopPlay];
	else
		[self.audioContainer play];
}

-(IBAction)goToStart:(id)sender
{
	[self.audioContainer goToStart];
}

-(IBAction)goToEnd:(id)sender
{
	[self.audioContainer goToEnd];
}

-(NSWindow*)window
{
	return [waveClipView window];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	[[waveClipView window] makeFirstResponder:waveClipView];
}


-(IBAction)reverseSelection:(id)sender
{
    [self.audioContainer reverseSelection];
}

- (void)windowWillClose:(NSNotification *)notification
{
    if (self.audioContainer.playing)
        [self.audioContainer stopPlay];
}

#pragma mark

NSCharacterSet *WordCharacterSet()
{
    static NSMutableCharacterSet *charset = nil;
    if (charset == nil)
    {
        charset = [[NSMutableCharacterSet alphanumericCharacterSet]retain];
        [charset addCharactersInString:@"-"];
        [charset addCharactersInString:@"/"];
        [charset addCharactersInString:@"'"];
        [charset addCharactersInString:@" "];
    }
    return charset;
}

BOOL AllPunctuation(NSString *str)
{
    for (int i = 0;i < [str length];i++)
    {
        unichar ch = [str characterAtIndex:i];
        if (![[NSCharacterSet punctuationCharacterSet]characterIsMember:ch])
            return NO;
    }
    return YES;
}

void RemoveSinglePunctuation(NSMutableArray*words)
{
    for (NSInteger i = [words count] - 1;i >= 0;i--)
    {
        NSString *str = words[i];
        if (AllPunctuation(str))
            [words removeObjectAtIndex:i];
    }
}

NSArray* WordsFromString(NSString* str)
{
    NSMutableArray *words = [NSMutableArray arrayWithCapacity:10];
    int startidx = 0;
    BOOL processingWord = YES,betweenQuotes = NO;
    for (int i = 0;i < [str length];i++)
    {
        unichar ch = [str characterAtIndex:i];
        BOOL isPartOfWord=YES;
        if (ch == '\'' || ch == 0x2019)
        {
            BOOL isApost = i > 0 && i < [str length] - 1 && [WordCharacterSet() characterIsMember:[str characterAtIndex:i-1]] && [WordCharacterSet() characterIsMember:[str characterAtIndex:i+1]];
            if (isApost)
                isPartOfWord = YES;
            else
            {
                isPartOfWord = NO;
                if (i < [str length] - 1 && ![WordCharacterSet() characterIsMember:[str characterAtIndex:i+1]])
                {
                    if (betweenQuotes)
                        betweenQuotes = NO;
                    else
                        isPartOfWord = YES;
                }
                else
                {
                    if ((i == 0) || (i > 0 && [WordCharacterSet() characterIsMember:[str characterAtIndex:i-1]]))
                        betweenQuotes = YES;
                }
            }
        }
        else
            isPartOfWord = [WordCharacterSet() characterIsMember:ch];
        if (isPartOfWord != processingWord)
        {
			if (i - startidx > 0)
			{
				NSString *text = [str substringWithRange:NSMakeRange(startidx, i - startidx)];
				if (processingWord)
					[words addObject:text];
				startidx = i;
			}
            processingWord = !processingWord;
        }
    }
    if ([str length] - startidx > 0)
    {
		NSString *text = [str substringWithRange:NSMakeRange(startidx, [str length] - startidx)];
		if (processingWord)
			[words addObject:text];
    }
    RemoveSinglePunctuation(words);
    return words;
}

-(void)applyTextToSegments:(NSString*)text
{
	NSArray *words = WordsFromString(text);
	for (int i = 0;i < [_segments count];i++)
	{
		Segment *s = [_segments objectAtIndex:i];
		if (i < [words count])
			s.text = words[i];
		else
			s.text = nil;
	}
	[_segmentClipView setNeedsDisplay:YES];
}

-(void)applyText
{
	[self applyTextToSegments:[phraseText string]];
}

- (void)textDidChange:(NSNotification *)aNotification
{
	[self applyText];
}

NSString *DeQuote(NSString *str)
{
    if (str == nil)
        return nil;
    return [str stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
}

-(NSString*)xmlStringURL:(NSURL*)url audio:(NSURL*)audioURL
{
	NSMutableString *string = [NSMutableString stringWithCapacity:100];
    [string appendString:@"<xml>\n"];
    
    NSString *version = [[[NSBundle mainBundle]infoDictionary]objectForKey:@"CFBundleVersion"];
    NSString *creator;
    if (version)
        creator = [NSString stringWithFormat:@"PhraseAnal %@",version];
    else
        creator = @"PhraseAnal";
    [string appendFormat:@"\t<creator program=\"%@\" user=\"%@\" />\n",creator,NSFullUserName()];
    if (audioURL)
    {
        NSDictionary *attrs = [[NSFileManager defaultManager]attributesOfItemAtPath:[url path] error:nil];
        NSString *atstring = @"";
        if (attrs)
        {
            NSDate *chdate = attrs[NSFileModificationDate];
            NSLocale *enUSPOSIXLocale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease];
            
            NSDateFormatter *df = [[[NSDateFormatter alloc]init]autorelease];
            [df setLocale:enUSPOSIXLocale];
            [df setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
            [df setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
            NSUInteger fsz = [attrs[NSFileSize]unsignedIntegerValue];
            atstring = [NSString stringWithFormat:@"chdate=\"%@\" filesize=\"%ld\" ",[df stringFromDate:chdate],fsz];
        }
        [string appendFormat:@"\t<url %@>%@</url>\n",atstring,[audioURL path]];
        NSString *urlDir = [[url path]stringByDeletingLastPathComponent];
        NSString *audioUrlDir = [[audioURL path]stringByDeletingLastPathComponent];
        if ([urlDir isEqual:audioUrlDir])
        {
            [string appendFormat:@"\t<relurl>%@</relurl>\n",[[audioURL path]lastPathComponent]];
        }
    }
    SInt64 noFrames = self.audioContainer.totalFrames;
	[string appendFormat:@"\t<timings text=\"%@\" frames=\"%lld\">\n",DeQuote([phraseText string]),noFrames];
	long samplerate = [self.audioContainer sampleRate];
	int i = 0;
	for (Segment *s in _segments)
	{
        if (s.range.location < noFrames)
        {
            NSString *startsecs = [NSString stringWithFormat:@"%0*.*f",2+3,3,s.range.location * 1.0 / samplerate];
            NSString *endsecs = [NSString stringWithFormat:@"%0*.*f",2+3,3,(s.range.location + s.range.length) * 1.0 / samplerate];
            NSString *tx = DeQuote(s.text);
            [string appendFormat:@"\t\t<timing id=\"%d\" start=\"%@\" end=\"%@\" startframe=\"%lld\" framelength=\"%lld\" text=\"%@\"/>\n",i,startsecs,endsecs,s.range.location,s.range.length,tx];
        }
		i++;
	}
	[string appendString:@"\t</timings>\n"];
    [string appendString:@"</xml>\n"];
	return string;
}	


-(IBAction)copyXML:(id)sender
{
	[[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObjects:NSPasteboardTypeString,nil] owner:self];
	[[NSPasteboard generalPasteboard] setString:[self xmlStringURL:nil audio:nil] forType:NSPasteboardTypeString];

}

-(ET_XMLNode*)findTimings:(ET_XMLNode*)node
{
    if ([node.nodeName isEqual:@"timings"])
        return node;
    for (ET_XMLNode *ch in [node children])
    {
        ET_XMLNode *n = [self findTimings:ch];
        if (n)
            return n;
    }
    return nil;
}

-(void)uSetSegments:(NSMutableArray*)segs
{
    [[[self undoManager] prepareWithInvocationTarget:self] uSetSegments:_segments];
    for (Segment *s in _segments)
    {
        s.beginArrow.delegate = nil;
        s.endArrow.delegate = nil;
        [s.beginArrow removeFromSuperlayer];
        [s.endArrow removeFromSuperlayer];
    }
    self.segments = segs;
    [(PA_SegmentView*)[_segmentClipView clientView] processSegmentsForLayer:_segmentClipView.layer];
    [_segmentClipView setNeedsDisplay:YES];
}

-(IBAction)pasteXML:(id)sender
{
    NSData *xmlData = [[NSPasteboard generalPasteboard]dataForType:NSPasteboardTypeString];
    if (xmlData)
    {
        ET_XMLNode *xmlNode = nil;
        ET_XMLManager *xmlman = [[[ET_XMLManager alloc]init]autorelease];
        xmlNode = [xmlman parseData:xmlData];
        ET_XMLNode *timings = [self findTimings:xmlNode];
        if (timings)
        {
            if ([timings attributeStringValue:@"text"])
                [phraseText setString:[timings attributeStringValue:@"text"]];
            NSMutableArray *segs = [NSMutableArray arrayWithCapacity:10];
            for (ET_XMLNode *xmlseg in [timings childrenOfType:@"timing"])
            {
                SInt64 st=0,len=0;
                if ([xmlseg.attributes objectForKey:@"startframe"] != nil)
                {
                    st = [xmlseg attributeIntValue:@"startframe"];
                    len = [xmlseg attributeIntValue:@"framelength"];
                }
                else
                {
                    if ([xmlseg.attributes objectForKey:@"start"] != nil)
                    {
                        float fst = [xmlseg attributeFloatValue:@"start"];
                        float fend = [xmlseg attributeFloatValue:@"end"];
                        st = [_audioContainer sampleRate] * fst;
                        len = [_audioContainer sampleRate] * fend - st;
                        if (st > [_audioContainer totalFrames])
                            st = [_audioContainer totalFrames];
                        if (st + len > [_audioContainer totalFrames])
                            len = [_audioContainer totalFrames] - st;
                    }
                }
                Segment *seg = [[[Segment alloc]init]autorelease];
                selection range;
                range.location = st;
                range.length = len;
                seg.range = range;
                seg.text = [xmlseg attributeStringValue:@"text"];
                [segs addObject:seg];
            }
            [self uSetSegments:segs];
        }
    }
}

Float32 MaxMagAudioValue(Float32 *data,UInt64 pos,UInt64 len)
{
	if (len <= 1)
		return data[pos];
	Float32 res;
	vDSP_maxmgv(&data[pos], 1, &res, len);
	return res;
}

#define samplesPerSec 50

int SegsForThreshold(int noEntries,Float32 maxes[],Float32 threshold)
{
    Float32 *maxouts = new Float32[noEntries];
    vDSP_vthres(maxes, 1, &threshold, maxouts, 1, noEntries);
    int segCount = 0;
    BOOL underthreshold = (maxes[0] < threshold);
    for (int i = 1;i < noEntries;i++)
    {
        Float32 currval = maxes[i];
        BOOL currunderthreshold = (currval < threshold);
        if (currunderthreshold != underthreshold)
        {
            if (!underthreshold)
            {
                segCount++;
            }
            underthreshold = currunderthreshold;
        }
    }
    return segCount;
}

int SoundCount(NSString *s)
{
    NSString *vowels = @"aeiouy";
    int tot = 0;
    BOOL inVowelSeq = NO;
    for (int i = 0;i < [s length];i++)
    {
        NSString *ch = [[s substringWithRange:NSMakeRange(i, 1)]lowercaseString];
        BOOL isVowel = [vowels rangeOfString:ch].length > 0;
        if (isVowel)
        {
            if (!inVowelSeq)
            {
                tot++;
                inVowelSeq = YES;
            }
        }
        else
            inVowelSeq = NO;
    }
    if (tot == 0)
        return 1;
    return tot;
}

Float32 bestThreshold(int noEntries,Float32 maxes[],Float32 maxmax,NSInteger targCt)
{
    NSInteger minDiff = 1000;
    Float32 minVal = 0.0;
    for (Float32 thr = 0.05;thr < 0.4;thr+=0.05)
    {
        NSInteger ct = SegsForThreshold(noEntries, maxes,  thr);
        NSInteger diff = abs(targCt - ct);
        if (diff < minDiff)
        {
            minDiff = diff;
            minVal = thr;
        }
    }
    
    return minVal;
}

#define lowestThreshold  0.01

-(NSArray*)blankSegmentsMaxes:(Float32*)maxes noEntries:(int)noEntries
{
    NSMutableArray *blanks = [NSMutableArray array];
    Float32 maxmax = MaxMagAudioValue(maxes, 0, noEntries);
    if (maxmax == 0)
        return @[];
    Float32 threshold = 0.1 * maxmax;
    BOOL underthreshold = (maxes[0] < threshold);
    NSInteger st = 0;
    for (int i = 1;i < noEntries;i++)
    {
        Float32 currval = maxes[i];
        BOOL currunderthreshold = (currval < threshold);
        if (currunderthreshold != underthreshold)
        {
            if (underthreshold)
            {
                Segment *s = [[[Segment alloc]init]autorelease];
                s.firstEntry = (int)st;
                s.lastEntry = i;
                [blanks addObject:s];
            }
            st = i;
            underthreshold = currunderthreshold;
        }
    }

    for (NSInteger i = [blanks count] - 1;i >= 0;i--)
    {
        Segment *s = blanks[i];
        if (s.lastEntry - s.firstEntry < 3)
            [blanks removeObjectAtIndex:i];
    }
    return blanks;
}
-(void)adjustSegs:(NSArray<Segment*>*)segs maxes:(Float32*)maxes noEntries:(int)noEntries
{
    if ([segs count] == 0)
        return;
    for (NSInteger i = 0;i < [segs count];i++)
    {
        Segment *s = segs[i];
        int limit = -1;
        if (i > 0)
            limit = segs[i-1].lastEntry;
        int mini = s.firstEntry;
        while (mini > limit && maxes[mini] > lowestThreshold)
        {
            s.firstEntry = mini;
            mini--;
        }
    }
    for (NSInteger i = 0;i < [segs count];i++)
    {
        Segment *s = segs[i];
        int limit = noEntries;
        if (i < [segs count] - 1)
            limit = segs[i + 1].firstEntry;
        int maxi = s.lastEntry;
        while (maxi < limit && (maxes[maxi] > lowestThreshold || maxes[maxi] < maxes[maxi-1]))
        {
            s.lastEntry = maxi;
            maxi++;
        }
    }
}

BOOL badFit(int target,int actual)
{
    float ratio = target * 1.0 / actual;
    float threshold = 2.0;
    return (ratio > threshold || ratio < 1/threshold);
}

BOOL containsInnerPunc(NSString *str)
{
    str = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([str length] > 3)
    {
        NSInteger idx = [str rangeOfCharacterFromSet:[NSCharacterSet alphanumericCharacterSet]options:NSBackwardsSearch].location;
        if (idx != NSNotFound)
            str = [str substringToIndex:idx];
        if ([str rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@".,?!;"]].length > 0)
        {
            return YES;
        }
    }
    return NO;
}

-(NSInteger)indexOfShortestSeg:(NSMutableArray*)segs
{
    int minlen = 100000000;
    int minidx = -1;
    int i = 0;
    for (Segment *s in segs)
    {
        int len = s.lastEntry - s.firstEntry;
        if (len < minlen)
        {
            minlen = len;
            minidx = i;
        }
        i++;
    }
    return minidx;
}

-(void)loseShortestGap:(NSMutableArray<Segment*>*)segs
{
    NSInteger mingap = 10000000;
    NSInteger minidx = -1;
    for (NSInteger i = 1;i < [segs count];i++)
    {
        NSInteger j = i - 1;
        NSInteger gap = segs[i].firstEntry - segs[j].lastEntry;
        if (gap < mingap)
        {
            mingap = gap;
            minidx = i;
        }
    }
    if (minidx > -1)
    {
        Segment *si = segs[minidx];
        Segment *sj = segs[minidx - 1];
        sj.lastEntry = si.lastEntry;
        [segs removeObjectAtIndex:minidx];
    }
}

-(void)loseShortestPhrase:(NSMutableArray<NSString*>*)phrases
{
    NSInteger minlen = 10000000;
    NSInteger minidx = -1;
    for (NSInteger i = 1;i < [phrases count];i++)
    {
        NSInteger j = i - 1;
        NSInteger totlen = [phrases[j]length] + [phrases[j]length];
        if (totlen < minlen)
        {
            minlen = totlen;
            minidx = i;
        }
    }
    if (minidx > -1)
    {
        NSString *si = phrases[minidx];
        NSString *sj = phrases[minidx - 1];
        [phrases replaceObjectAtIndex:minidx withObject:[sj stringByAppendingString:si]];
        [phrases removeObjectAtIndex:minidx];
    }
}

-(NSArray*)applyThreshold:(float)threshold maxes:(Float32*)maxes noEntries:(int)noEntries
{
    NSMutableArray *segs = [NSMutableArray array];
    BOOL underthreshold = (maxes[0] < threshold);
    for (int i = 1;i < noEntries;i++)
    {
        Float32 currval = maxes[i];
        BOOL currunderthreshold = (currval < threshold);
        if (currunderthreshold != underthreshold)
        {
            if (!underthreshold)
            {
                Segment *s = [[[Segment alloc]init]autorelease];
                s.firstEntry = s.lastEntry = i;
                [segs addObject:s];
            }
            else
            {
                if ([segs count] > 0)
                {
                    Segment *s = [segs lastObject];
                    s.lastEntry = i;
                }
            }
            underthreshold = currunderthreshold;
        }
    }
    return segs;
}

-(void)cullSegments:(NSMutableArray*)arr
{
    for (NSInteger i = [arr count]-1;i >= 0;i--)
    {
        Segment *se = arr[i];
        if (se.lastEntry <= se.firstEntry)
            [arr removeObjectAtIndex:i];
    }
}

int interpolatevalueFromSegs(NSArray<Segment*>*segs,float f)
{
    int tot = 0;
    for (Segment *s in segs)
        tot += (s.lastEntry - s.firstEntry);
    float val = f * tot;
    tot = 0;
    for (Segment *s in segs)
    {
        if (val > (tot + (s.lastEntry - s.firstEntry)))
        {
            tot+= (s.lastEntry - s.firstEntry);
        }
        else
        {
            float r = val - tot;
            return s.firstEntry + r;
        }
    }
    return [segs lastObject].lastEntry;
}
-(NSArray*)selectionsFromData:(Float32*)data length:(SInt64)length targetNo:(NSInteger)targNo text:(NSString*)text
{
	if (data == NULL || length == 0)
		return nil;
	SInt64 stride = ([self.audioContainer sampleRate] + samplesPerSec - 1) / samplesPerSec;
	SInt64 totalFrames = [self.audioContainer totalFrames];
	SInt64 noEntries = (totalFrames + stride - 1) / stride;
	Float32 *maxes = new Float32[noEntries];
	for (int i= 0;i < noEntries;i++)
	{
		UInt64 pos = i * stride;
		UInt64 len = stride;
		if (pos + len > length)
			len = length - pos;
		maxes[i] = MaxMagAudioValue(data, pos, len);
	}
	Float32 maxmax = MaxMagAudioValue(maxes, 0, noEntries);
	if (maxmax == 0)
		return nil;
	Float32 threshold = 0.01;
    NSArray<Segment*>*blanks = [self blankSegmentsMaxes:maxes noEntries:(int)noEntries];
    
	NSMutableArray *segs = [NSMutableArray arrayWithCapacity:20];
    int lastblank = 0;
    for (Segment *bl in blanks)
    {
        if (bl.firstEntry - lastblank > 1)
        {
            Segment *s = [[[Segment alloc]init]autorelease];
            s.firstEntry = lastblank;
            s.lastEntry = bl.firstEntry;
            lastblank = bl.lastEntry;
            [segs addObject:s];
        }
    }
    if (lastblank < noEntries)
    {
        Segment *s = [[[Segment alloc]init]autorelease];
        s.firstEntry = lastblank;
        s.lastEntry = (int)noEntries;
        lastblank = (int)noEntries;
        [segs addObject:s];
    }
    [self adjustSegs:segs maxes:maxes noEntries:(int)noEntries];
    if (badFit((int)targNo,(int)[segs count]))
    {
        if (containsInnerPunc(text))
        {
            NSArray *phs = [text componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@".,?!;"]];
            NSMutableArray *phrases = [NSMutableArray array];
            for (NSString *ph in phs)
            {
                NSString *phrase = [ph stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if ([phrase length] > 0)
                    [phrases addObject:phrase];
            }
            while ([segs count] > [phrases count])
            {
                [self loseShortestGap:segs];
            }
            while ([phrases count] > [segs count])
            {
                [self loseShortestPhrase:phrases];
            }
            if ([segs count] > 1)
            {
                NSMutableArray *newSegments = [NSMutableArray array];
                for (int i = 0;i < [segs count];i++)
                {
                    NSString *phrase = phrases[i];
                    Segment *seg = segs[i];
                    NSArray *words = [phrase componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    int wordct = (int)[words count];
                    int soundct = 0;
                    for (NSString *word in words)
                        soundct += SoundCount(word);
                    float thr = bestThreshold(seg.lastEntry - seg.firstEntry, maxes + seg.firstEntry, maxmax, soundct);
                    NSArray *ssegs = [self applyThreshold:thr maxes:maxes + seg.firstEntry noEntries:seg.lastEntry - seg.firstEntry];
                    float segspersoundct = [ssegs count] * 1.0 / soundct;
                    NSMutableArray *newsegs = [NSMutableArray array];
                    int accumsoundct = 0;
                    for (NSString *word in words)
                    {
                        float startsoundct = accumsoundct;
                        float endsoundct = startsoundct + SoundCount(word);
                        
                        Segment *s = [[[Segment alloc]init]autorelease];
                        s.firstEntry = interpolatevalueFromSegs(ssegs,startsoundct/soundct);
                        s.lastEntry = interpolatevalueFromSegs(ssegs, endsoundct/soundct) - 1;
                        if (s.lastEntry > s.firstEntry)
                            [newsegs addObject:s];
                        accumsoundct = endsoundct;
                    }
                    [self adjustSegs:newsegs maxes:maxes + seg.firstEntry noEntries:(int)seg.lastEntry - seg.firstEntry];
                    for (Segment *newseg in newsegs)
                    {
                        newseg.firstEntry += seg.firstEntry;
                        newseg.lastEntry += seg.firstEntry;
                    }
                    [newSegments addObjectsFromArray:newsegs];
                }
                segs = newSegments;
            }
            else
            {
                if (targNo > 0)
                    threshold = bestThreshold((int)noEntries, maxes, maxmax,targNo);
                BOOL underthreshold = (maxes[0] < threshold);
                for (int i = 1;i < noEntries;i++)
                {
                    Float32 currval = maxes[i];
                    BOOL currunderthreshold = (currval < threshold);
                    if (currunderthreshold != underthreshold)
                    {
                        if (!underthreshold)
                        {
                            Segment *s = [[[Segment alloc]init]autorelease];
                            s.firstEntry = s.lastEntry = i;
                            [segs addObject:s];
                        }
                        underthreshold = currunderthreshold;
                    }
                }
                [self adjustSegs:segs maxes:maxes noEntries:(int)noEntries];
            }
        }
        else
        {
            if (targNo > 0)
                threshold = bestThreshold((int)noEntries, maxes, maxmax,targNo);
            BOOL underthreshold = (maxes[0] < threshold);
            for (int i = 1;i < noEntries;i++)
            {
                Float32 currval = maxes[i];
                BOOL currunderthreshold = (currval < threshold);
                if (currunderthreshold != underthreshold)
                {
                    if (!underthreshold)
                    {
                        Segment *s = [[[Segment alloc]init]autorelease];
                        s.firstEntry = s.lastEntry = i;
                        [segs addObject:s];
                    }
                    underthreshold = currunderthreshold;
                }
            }
            [self adjustSegs:segs maxes:maxes noEntries:(int)noEntries];

        }
    }
        
	delete[] maxes;
    for (Segment *s in segs)
    {
        selection r;
        r.location = s.firstEntry * stride;
        r.length = ((s.lastEntry + 1) - s.firstEntry) * stride;
        s.range = r;
    }
	return segs;
}

-(IBAction)addSegmentAtPlayPosition:(id)sender
{
    if ([((PA_SegmentView*)[_segmentClipView clientView]) addSegmentAtFrame:[self.audioContainer currentFrame]])
		[[self undoManager]setActionName:@"Add Segment"];
}

-(IBAction)splitSegmentAtPlayPosition:(id)sender
{
    if ([((PA_SegmentView*)[_segmentClipView clientView]) splitSegmentAtFrame:[self.audioContainer currentFrame]])
		[[self undoManager]setActionName:@"Split Segment"];
}

-(IBAction)autoSplit:(id)sender
{
    NSInteger noWords = 0;
    if ([[[phraseText string]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]length]>0)
        noWords = [[[phraseText string]componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]count];
	NSArray *segs = [self selectionsFromData:[self.audioContainer leftData] length:[self.audioContainer totalFrames]targetNo:noWords  text:[phraseText string]];
	[self uSetSegments:[[segs mutableCopy]autorelease]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	if (action == @selector(splitSegmentAtPlayPosition:))
	{
        int idx = [((PA_SegmentView*)[_segmentClipView clientView]) segmentIndexForFrame:[self.audioContainer currentFrame]];
		return idx >= 0;
	}
	return YES;
    
}

@end


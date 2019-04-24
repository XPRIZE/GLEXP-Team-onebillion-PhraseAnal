//
//  PA_AppDelegate.m
//  PhraseAnal
//
//  Created by Alan on 29/11/2013.
//  Copyright (c) 2013 Alan C Smith. All rights reserved.
//

#import "PA_AppDelegate.h"
#import "PA_Document.h"
#import <Foundation/Foundation.h>

@implementation PA_AppDelegate

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    return NO;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    for (NSString *fn in filenames)
    {
        NSURL *url = [NSURL fileURLWithPath:fn];
        NSString *doctype = [[NSDocumentController sharedDocumentController]typeForContentsOfURL:url error:nil];
        if ([doctype isEqualToString:@"xmltype"])
            [[NSDocumentController sharedDocumentController]openDocumentWithContentsOfURL:url display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
            }];
        else
        {
            PA_Document *doc = [[NSDocumentController sharedDocumentController]openUntitledDocumentAndDisplay:YES error:nil];
            [doc importAudioFromURL:url];
        }
    }
}

- (BOOL)application:(id)sender openFileWithoutUI:(NSString *)filename
{
    return NO;
}
@end

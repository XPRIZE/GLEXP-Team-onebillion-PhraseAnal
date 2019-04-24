//
//  ET_XMLManager.h
//  p-1-phonics
//
//  Created by Alan on 11/10/2013.
//  Copyright (c) 2013 Eurotalk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ET_XMLNode.h"

@interface ET_XMLManager : NSObject<NSXMLParserDelegate>
{
    
}
@property (retain) NSMutableArray *nodes,*nodeStack;
@property (retain) NSXMLParser *xmlParser;
@property (retain) NSString *fileName;

-(ET_XMLNode*)parseFile:(NSString*)filename;
-(ET_XMLNode*)parseData:(NSData*)data;

@end

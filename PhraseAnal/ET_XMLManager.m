//
//  ET_XMLManager.m
//  p-1-phonics
//
//  Created by Alan on 11/10/2013.
//  Copyright (c) 2013 Eurotalk. All rights reserved.
//

#import "ET_XMLManager.h"
#import "ET_XMLNode.h"

#define PROCESSING 0
#define FINISHED 1

@implementation ET_XMLManager

-(void)dealloc
{
	self.nodes = nil;
	self.nodeStack = nil;
	self.xmlParser = nil;
	self.fileName = nil;
	[super dealloc];
}

- (void)parserDidStartDocument:(NSXMLParser *)parser
{
    
}

- (void)parserDidEndDocument:(NSXMLParser *)parser
{
	if ([_nodeStack count] > 0)
		NSLog(@"XMLManager: document ended but stack contains %@",_nodeStack);
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	ET_XMLNode *stnode = [_nodeStack lastObject];
	[stnode.contents appendString:string];
}

- (void)parser:(NSXMLParser *)parser foundIgnorableWhitespace:(NSString *)whitespaceString
{
	
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	ET_XMLNode *node = [[ET_XMLNode alloc]init];
	node.nodeName = elementName;
	node.attributes = attributeDict;
	[_nodeStack addObject:node];
	[node release];
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	ET_XMLNode *stnode = [_nodeStack lastObject];
	if ([elementName isEqualToString:stnode.nodeName])
	{
		[stnode retain];
		[_nodeStack removeLastObject];
		if ([_nodeStack count] > 0)
		{
			ET_XMLNode *parentnode = [_nodeStack lastObject];
			[parentnode.children addObject:stnode];
		}
		else
			[_nodes addObject:stnode];
		[stnode release];
	}
	else
		NSLog(@"XMLManager: %@ element %@ ended but top of stack is %@",_fileName,elementName,stnode.nodeName);
		
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	NSLog(@"XMLManager: %@ error %@",_fileName,[parseError localizedDescription]);
}

- (void)parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validError
{
	NSLog(@"XMLManager: %@ parse error %@",_fileName,[validError localizedDescription]);
}

-(ET_XMLNode*)parseFile:(NSString*)filename
{
	if (![[NSFileManager defaultManager]fileExistsAtPath:filename])
	{
		NSLog(@"File doesn't exist at %@",filename);
		return nil;
	}
    self.xmlParser = [[[NSXMLParser alloc]initWithContentsOfURL:[NSURL fileURLWithPath:filename]]autorelease];
	self.fileName = [filename lastPathComponent];
    self.nodes = [NSMutableArray arrayWithCapacity:10];
    self.nodeStack = [NSMutableArray arrayWithCapacity:10];
    [self.xmlParser setDelegate:self];
    [self.xmlParser parse];
	if ([self.nodes count] == 0)
		return nil;
	if ([self.nodes count] == 1)
		return [self.nodes lastObject];
	ET_XMLNode *node = [[[ET_XMLNode alloc]init]autorelease];
	node.nodeName = @"root";
	node.children = self.nodes;
    return node;
}

-(ET_XMLNode*)parseData:(NSData*)data
{
    self.xmlParser = [[[NSXMLParser alloc]initWithData:data]autorelease];
    self.nodes = [NSMutableArray arrayWithCapacity:10];
    self.nodeStack = [NSMutableArray arrayWithCapacity:10];
    [self.xmlParser setDelegate:self];
    [self.xmlParser parse];
	if ([self.nodes count] == 0)
		return nil;
	if ([self.nodes count] == 1)
		return [self.nodes lastObject];
	ET_XMLNode *node = [[[ET_XMLNode alloc]init]autorelease];
	node.nodeName = @"root";
	node.children = self.nodes;
    return node;
}

@end

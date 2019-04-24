//
//  ET_XMLNode.m
//  p-1-phonics
//
//  Created by Alan on 11/10/2013.
//  Copyright (c) 2013 Eurotalk. All rights reserved.
//

#import "ET_XMLNode.h"

@implementation ET_XMLNode

-(id)init
{
	if (self = [super init])
	{
		self.contents = [NSMutableString stringWithCapacity:32];
		self.children = [NSMutableArray arrayWithCapacity:8];
	}
	return self;
}

-(void)dealloc
{
	[_contents release];
	[_attributes release];
	[_children release];
	[_nodeName release];
	[super dealloc];
}

-(NSArray*)childrenOfType:(NSString*)typeName
{
	NSIndexSet *ixs = [_children indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop)
					   {
						   return ([[obj nodeName]isEqualToString:typeName]);
					   }];
	return [_children objectsAtIndexes:ixs];
}

-(NSString*)attributeStringValue:(NSString*)attrname
{
	return [_attributes objectForKey:attrname];
}

-(float)attributeFloatValue:(NSString*)attrname
{
	return [[_attributes objectForKey:attrname]floatValue];
}

-(NSInteger)attributeIntValue:(NSString*)attrname
{
	return [[_attributes objectForKey:attrname]integerValue];
}

-(BOOL)attributeBoolValue:(NSString*)attrname
{
	NSString *attr = [[[_attributes objectForKey:attrname]lowercaseString]stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	return [attr isEqualToString:@"yes"] ||[attr isEqualToString:@"true"] ||[attr isEqualToString:@"y"] ;
}

@end

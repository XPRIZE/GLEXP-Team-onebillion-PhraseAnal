//
//  ET_XMLNode.h
//  p-1-phonics
//
//  Created by Alan on 11/10/2013.
//  Copyright (c) 2013 Eurotalk. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ET_XMLNode : NSObject

@property (retain) NSString *nodeName;
@property (retain) NSMutableString *contents;
@property (retain) NSDictionary *attributes;
@property (retain) NSMutableArray *children;

-(NSArray*)childrenOfType:(NSString*)typeName;
-(NSString*)attributeStringValue:(NSString*)attrname;
-(float)attributeFloatValue:(NSString*)attrname;
-(NSInteger)attributeIntValue:(NSString*)attrname;
-(BOOL)attributeBoolValue:(NSString*)attrname;

@end

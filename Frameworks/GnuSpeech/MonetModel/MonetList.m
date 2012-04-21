//  This file is part of Gnuspeech, an extensible, text-to-speech package, based on real-time, articulatory, speech-synthesis-by-rules. 
//  Copyright 1991-2012 David R. Hill, Leonard Manzara, Craig Schock

#import "MonetList.h"

#import "NSObject-Extensions.h"
#import "NSString-Extensions.h"

@implementation MonetList
{
    NSMutableArray *ilist;
}

- (id)init;
{
    return [self initWithCapacity:2];
}

- (id)initWithCapacity:(NSUInteger)numItems;
{
    if ((self = [super init])) {
        ilist = [[NSMutableArray alloc] initWithCapacity:numItems];
    }

    return self;
}

- (void)dealloc;
{
    [ilist release];

    [super dealloc];
}

#pragma mark - Debugging

- (NSString *)description;
{
    return [ilist description];
}

#pragma mark -

@synthesize ilist;

- (void)_warning;
{
    //NSLog(@"%s", _cmd);
}

- (id)objectAtIndex:(NSUInteger)index;
{
    if (index >= [ilist count]) {
        //NSLog(@"Warning: index out of range in %s, returning nil for compatibility with List from NS3.3", _cmd);
        [self _warning];
        return nil;
    }
    return [ilist objectAtIndex:index];
}

- (void)_addNilWarning;
{
    NSLog(@"Tried to add nil.");
}

- (void)addObject:(id)anObject;
{
    if (anObject == nil) {
        NSLog(@"Warning: trying to insert nil into MonetList.  Ignoring, for compatibility with List from NS3.3");
        [self _addNilWarning];
        return;
    }
    [ilist addObject:anObject];
}

- (void)removeAllObjects;
{
    [ilist removeAllObjects];
}

- (void)removeLastObject;
{
    [ilist removeLastObject];
}

- (BOOL)containsObject:(id)anObject;
{
    return [ilist containsObject:anObject];
}

- (void)appendXMLToString:(NSMutableString *)resultString elementName:(NSString *)elementName level:(NSUInteger)level;
{
    NSUInteger count, index;

    count = [self.ilist count];
    if (count == 0)
        return;

    [resultString indentToLevel:level];
    [resultString appendFormat:@"<%@>\n", elementName];

    for (index = 0; index < count; index++)
        [[self objectAtIndex:index] appendXMLToString:resultString level:level+1];

    [resultString indentToLevel:level];
    [resultString appendFormat:@"</%@>\n", elementName];
}

- (void)appendXMLForObjectPointersToString:(NSMutableString *)resultString elementName:(NSString *)elementName level:(NSUInteger)level;
{
    NSUInteger count, index;

    count = [self.ilist count];
    if (count == 0)
        return;

    [resultString indentToLevel:level];
    [resultString appendFormat:@"<%@>\n", elementName];

    for (index = 0; index < count; index++) {
        id anObject;

        anObject = [self objectAtIndex:index];
        [resultString indentToLevel:level + 1];
        [resultString appendFormat:@"<object ptr=\"%p\" class=\"%@\"/>\n", anObject, NSStringFromClass([anObject class])];
    }

    [resultString indentToLevel:level];
    [resultString appendFormat:@"</%@>\n", elementName];
}

@end

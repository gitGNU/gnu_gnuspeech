//
// $Id: NSString-Extensions.h,v 1.3 2004/03/06 03:13:26 nygard Exp $
//

//  This file is part of class-dump, a utility for examining the
//  Objective-C segment of Mach-O files.
//  Copyright (C) 1997-1998, 2000-2001, 2004  Steve Nygard

#import <Foundation/NSString.h>

@interface NSString (CDExtensions)

+ (NSString *)stringWithFileSystemRepresentation:(const char *)str;
+ (NSString *)spacesIndentedToLevel:(int)level;
+ (NSString *)spacesIndentedToLevel:(int)level spacesPerLevel:(int)spacesPerLevel;
+ (NSString *)stringWithUnichar:(unichar)character;

- (BOOL)isFirstLetterUppercase;

+ (NSString *)stringWithASCIICString:(const char *)bytes;

@end

@interface NSMutableString (Extensions)

- (void)indentToLevel:(int)level;

@end

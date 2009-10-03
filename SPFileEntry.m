/*
 SuperSFV is the legal property of its developers, whose names are 
 listed in the copyright file included with this source distribution.
 
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License along
 with this program; if not, write to the Free Software Foundation, Inc.,
 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#import "SPFileEntry.h"


@implementation SPFileEntry

- (id) init
{
    if (self = [super init]) {
        NSImage *img = [[NSImage alloc] init];
        NSArray *values = [NSArray arrayWithObjects: img, @"/", @"", @"", nil];
        keys   = [NSArray arrayWithObjects: @"status", @"filepath", @"expected", @"result", nil]; 
        
        [img release];
        properties = [[NSMutableDictionary alloc] initWithObjects: values forKeys: keys];
    }
    return self;
}

- (void) setProperties: (NSDictionary *)newProperties
{
    if (properties != newProperties)
    {
        [properties autorelease];
        properties = [[NSMutableDictionary alloc] initWithDictionary: newProperties];
    }    
}

- (id)valueForUndefinedKey:(id)key
{
	if ([key isEqualToString:@"filepath"]) {
		return [[self properties] valueForKey:@"filepath"];
	}
    
	if ([key isEqualToString:@"expected"]) {
		return [[self properties] valueForKey:@"expected"];
	}
    
	if ([key isEqualToString:@"result"]) {
		return [[self properties] valueForKey:@"result"];
	}
    
    return [[self properties] valueForKey:key];
}


-(NSMutableDictionary*)properties
{
    return properties;
}

- (NSArray*) defaultKeys
{
    return keys;
}

@end

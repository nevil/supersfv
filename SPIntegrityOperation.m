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

#import "SPIntegrityOperation.h"

@implementation SPIntegrityOperation

@synthesize hash;

- (id)initWithFileEntry:(SPFileEntry *)entry target:(NSObject *)object
{
    return [self initWithFileEntry:entry target:object algorithm:-1];
}

- (id)initWithFileEntry:(SPFileEntry *)entry target:(NSObject *)object algorithm:(int)algorithm
{
    if (self = [super init])
    {
        fileEntry = [entry retain];
        target = object;
        cryptoAlgorithm = algorithm;
    }
    
    return self;
}

- (void)dealloc
{
    [fileEntry release];
    [super dealloc];
}

-(void)main
{
	NSAutoreleasePool *autoReleasePool = [[NSAutoreleasePool alloc] init];

    NSLog(@"Running for file %@", [[fileEntry properties] objectForKey:@"filepath"]);

	if (![self isCancelled])
	{
        int bytes, algorithm;
        uint8_t data[1024], *dgst; // buffers
        
        NSString *file = [[fileEntry properties] objectForKey:@"filepath"];
        NSString *expectedHash = [[fileEntry properties] objectForKey:@"expected"];

        NSFileManager *dm = [NSFileManager defaultManager];
        NSDictionary *fileAttributes = [dm attributesOfItemAtPath:file error:NULL];


        if (cryptoAlgorithm == -1)
        {
            switch ([expectedHash length])
            {
                case 8:
                    algorithm = 0;
                    break;
                case 32:
                    algorithm = 1;
                    break;
                case 40:
                    algorithm = 2;
                    break;
                default:
                    algorithm = 0;
                    break;
            }
        }
        else
        {
            algorithm = cryptoAlgorithm;
        }
        
        FILE *inFile = fopen([file cStringUsingEncoding:NSUTF8StringEncoding], "rb");
        
        if (inFile == NULL)
            goto cancelled;
        
//        [target performSelectorOnMainThread:@selector(initProgress:)
//                               withObject:[NSArray arrayWithObjects:
//                                           [NSString stringWithFormat:@"Performing %@ on %@", @"CRC32", //TODO: [popUpButton_checksum itemTitleAtIndex:algorithm],
//                                            [file lastPathComponent]],
//                                           [NSNumber numberWithDouble:0.0],
//                                           [fileAttributes objectForKey:NSFileSize],
//                                           nil]
//                            waitUntilDone:YES];

        crc32_t crc;
        MD5_CTX md5_ctx;
        SHA_CTX sha_ctx;
        
        if (!algorithm) {
            crc = crc32(0L,Z_NULL,0);
        } else if (algorithm == 1) {
            MD5_Init(&md5_ctx);
        } else { // algorithm == 2
            SHA1_Init(&sha_ctx);
        }
        
        while ((bytes = fread (data, 1, 1024, inFile)) != 0) {
            if ([self isCancelled])
                break;
            
            switch (algorithm) {
                case 0:
                    crc = crc32(crc, data, bytes);
                    break;
                case 1:
                    MD5_Update(&md5_ctx, data, bytes);
                    break;
                case 2:
                    SHA1_Update(&sha_ctx, data, bytes);
                    break;
            }
        }
        
        fclose(inFile);

        NSLog(@"Finished with file %@", [[fileEntry properties] objectForKey:@"filepath"]);
        

        if ([self isCancelled])
            goto cancelled;
        
        if (!algorithm) {
            hash = [[NSString stringWithFormat:@"%08x", crc] uppercaseString];
        } else {
            hash = @"";
            dgst = (uint8_t *) calloc (((algorithm == 1)?32:40), sizeof(uint8_t));
            
            if (algorithm == 1)
                MD5_Final(dgst,&md5_ctx);
            else if (algorithm == 2)
                SHA1_Final(dgst,&sha_ctx);
            
            int i;
            for (i = 0; i < ((algorithm == 1)?16:20); i++)
                hash = [[[self hash] stringByAppendingFormat:@"%02x", dgst[i]] uppercaseString];
            
            free(dgst);
        }
        
        /* SPFileEntry *newEntry = [[SPFileEntry alloc] init];
        NSDictionary *newDict;

        if (![expectedHash isEqualToString:@""])
            newDict = [[NSMutableDictionary alloc]
                       initWithObjects:[NSArray arrayWithObjects:[[expectedHash uppercaseString] isEqualToString:result]?[NSImage imageNamed:@"button_ok"]:[NSImage imageNamed:@"button_cancel"],
                                        file, [expectedHash uppercaseString], result, nil]
                       forKeys:[newEntry defaultKeys]];
        else
            newDict = [[NSMutableDictionary alloc]
                       initWithObjects:[NSArray arrayWithObjects:[NSImage imageNamed:@"button_ok"],
                                        file, result, result, nil]
                       forKeys:[newEntry defaultKeys]];

        [newEntry setProperties:newDict];
        [newDict release];

        // TODO: Make it possible to update records with the result
        //        [records addObject:newEntry];
        [target addRecordObject:newEntry];
        [newEntry release];
         */

    }
cancelled:
	[autoReleasePool release];
}

@end

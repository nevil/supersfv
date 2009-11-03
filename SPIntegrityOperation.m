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

- (id)initWithFileEntry:(SPFileEntry *)entry target:(NSObject *)object
{
    if (self = [super init])
    {
        fileEntry = [entry retain];
        target = object;
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
    BOOL doEndProgress = NO; // we use this to make sure we only call endProgress when needed

    NSLog(@"Running for file %@", [[fileEntry properties] objectForKey:@"filepath"]);

	if (![self isCancelled])
	{
// TODO: This button should be locked when the first operation is added....
//        [popUpButton_checksum setEnabled:NO]; // so they can't screw with it

        int bytes, algorithm;
        uint8_t data[1024], *dgst; // buffers
        
        NSString *file = [[fileEntry properties] objectForKey:@"filepath"];
        NSString *hash = [[fileEntry properties] objectForKey:@"expected"];
        NSString *result;

        NSFileManager *dm = [NSFileManager defaultManager];
        NSDictionary *fileAttributes = [dm attributesOfItemAtPath:file error:NULL];


        if (![hash isEqualToString:@""])
        {
            switch ([hash length])
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
            // TODO: Fix access to button value
            algorithm = 0;
//            algorithm = [popUpButton_checksum indexOfSelectedItem];
        }

//
//        algorithm = (![hash isEqualToString:@""]) ? ([hash length] == 8) ? 0 : ([hash length] == 32) ? 1 : ([hash length] == 40) ? 2 : 0 : [popUpButton_checksum indexOfSelectedItem];
        
        FILE *inFile = fopen([file cStringUsingEncoding:NSUTF8StringEncoding], "rb");
        
        if (inFile == NULL)
            goto cancelled;
        
        [target performSelectorOnMainThread:@selector(initProgress:)
                               withObject:[NSArray arrayWithObjects:
                                           [NSString stringWithFormat:@"Performing %@ on %@", @"CRC32", //TODO: [popUpButton_checksum itemTitleAtIndex:algorithm],
                                            [file lastPathComponent]],
                                           [NSNumber numberWithDouble:0.0],
                                           [fileAttributes objectForKey:NSFileSize],
                                           nil]
                            waitUntilDone:YES];
        
        doEndProgress = YES; // don't care about doing endProgress unless the progress has been init-ed
        
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

//TODO: KVC
            [target performSelectorOnMainThread:@selector(updateProgress:)
                                     withObject:[NSArray arrayWithObjects:
                                                 [NSNumber numberWithDouble:(double)bytes], @"", nil]
                                  waitUntilDone:NO];
        }
        
        fclose(inFile);

        NSLog(@"Finished with file %@", [[fileEntry properties] objectForKey:@"filepath"]);
        

        if ([self isCancelled])
            goto cancelled;
        
        if (!algorithm) {
            result = [[NSString stringWithFormat:@"%08x", crc] uppercaseString];
        } else {
            result = @"";
            dgst = (uint8_t *) calloc (((algorithm == 1)?32:40), sizeof(uint8_t));
            
            if (algorithm == 1)
                MD5_Final(dgst,&md5_ctx);
            else if (algorithm == 2)
                SHA1_Final(dgst,&sha_ctx);
            
            int i;
            for (i = 0; i < ((algorithm == 1)?16:20); i++)
                result = [[result stringByAppendingFormat:@"%02x", dgst[i]] uppercaseString];
            
            free(dgst);
        }
        
        SPFileEntry *newEntry = [[SPFileEntry alloc] init];
        NSDictionary *newDict;
        
        if (![hash isEqualToString:@""])
            newDict = [[NSMutableDictionary alloc]
                       initWithObjects:[NSArray arrayWithObjects:[[hash uppercaseString] isEqualToString:result]?[NSImage imageNamed:@"button_ok"]:[NSImage imageNamed:@"button_cancel"],
                                        file, [hash uppercaseString], result, nil]
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
        
        [target performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:YES];

cancelled:
        if (doEndProgress)
        {
            [target performSelectorOnMainThread:@selector(endProgress) withObject:nil waitUntilDone:YES];
        }
    }

	[autoReleasePool release];
}

@end

#if 0
// this probably needs to be rewritten to be more efficient, and clean
- (void)addFiles:(NSTimer *)timer
{
	SPFileEntry *content;
    int do_endProgress = 0; // we use this to make sure we only call endProgress when needed

	while ((content = [pendingFiles dequeue])) {
        if (!continueProcessing)
            break;

        [popUpButton_checksum setEnabled:NO]; // so they can't screw with it

        int bytes, algorithm;
        uint8_t data[1024], *dgst; // buffers

        NSString *file = [[content properties] objectForKey:@"filepath"],
        *hash = [[content properties] objectForKey:@"expected"],
        *result;

        NSFileManager *dm = [NSFileManager defaultManager];
        NSDictionary *fileAttributes = [dm attributesOfItemAtPath:file error:NULL];


        algorithm = (![hash isEqualToString:@""]) ? ([hash length] == 8) ? 0 : ([hash length] == 32) ? 1 : ([hash length] == 40) ? 2 : 0 : [popUpButton_checksum indexOfSelectedItem];

        FILE *inFile = fopen([file cStringUsingEncoding:NSUTF8StringEncoding], "rb");

        if (inFile == NULL)
            break;

        [self performSelectorOnMainThread:@selector(initProgress:)
                               withObject:[NSArray arrayWithObjects:
                                           [NSString stringWithFormat:@"Performing %@ on %@", [popUpButton_checksum itemTitleAtIndex:algorithm],
                                            [file lastPathComponent]],
                                           [NSNumber numberWithDouble:0.0],
                                           [fileAttributes objectForKey:NSFileSize],
                                           nil]
                            waitUntilDone:YES];

        do_endProgress++; // don't care about doing endProgress unless the progress has been init-ed

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
            if (!continueProcessing)
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

            [self performSelectorOnMainThread:@selector(updateProgress:)
                                   withObject:[NSArray arrayWithObjects:
                                               [NSNumber numberWithDouble:(double)bytes], @"", nil]
                                waitUntilDone:NO];
        }

        fclose(inFile);

        if (!continueProcessing)
            break;

        if (!algorithm) {
            result = [[NSString stringWithFormat:@"%08x", crc] uppercaseString];
        } else {
            result = @"";
            dgst = (uint8_t *) calloc (((algorithm == 1)?32:40), sizeof(uint8_t));

            if (algorithm == 1)
                MD5_Final(dgst,&md5_ctx);
            else if (algorithm == 2)
                SHA1_Final(dgst,&sha_ctx);

            int i;
            for (i = 0; i < ((algorithm == 1)?16:20); i++)
                result = [[result stringByAppendingFormat:@"%02x", dgst[i]] uppercaseString];

            free(dgst);
        }

        SPFileEntry *newEntry = [[SPFileEntry alloc] init];
        NSDictionary *newDict;

        if (![hash isEqualToString:@""])
            newDict = [[NSMutableDictionary alloc]
                       initWithObjects:[NSArray arrayWithObjects:[[hash uppercaseString] isEqualToString:result]?[NSImage imageNamed:@"button_ok"]:[NSImage imageNamed:@"button_cancel"],
                                        file, [hash uppercaseString], result, nil]
                       forKeys:[newEntry defaultKeys]];
        else
            newDict = [[NSMutableDictionary alloc]
                       initWithObjects:[NSArray arrayWithObjects:[NSImage imageNamed:@"button_ok"],
                                        file, result, result, nil]
                       forKeys:[newEntry defaultKeys]];

        [newEntry setProperties:newDict];
        [newDict release];

        [records addObject:newEntry];
        [newEntry release];

        [self performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:YES];
	}
    // 4 times I had to add this LAME! C'mon Apple, get yer thread on!
    if (!continueProcessing) {
        [pendingFiles dump];
        [self performSelectorOnMainThread:@selector(updateUI) withObject:nil waitUntilDone:YES];
        continueProcessing = YES;
    }

    if (do_endProgress) {
        [self performSelectorOnMainThread:@selector(endProgress) withObject:nil waitUntilDone:YES];
    }

    [autoreleasePool release];
    autoreleasePool = [[NSAutoreleasePool alloc] init];
}
#endif
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

#import "SPSuperSFV.h"
#import "SPFileEntry.h"
#import "SPIntegrityOperation.h"

#define SuperSFVToolbarIdentifier    @"SuperSFV Toolbar Identifier"
#define AddToolbarIdentifier         @"Add Toolbar Identifier"
#define RemoveToolbarIdentifier      @"Remove Toolbar Identifier"
#define RecalculateToolbarIdentifier @"Recalculate Toolbar Identifier"
#define ChecksumToolbarIdentifier    @"Checksum Toolbar Identifier"
#define StopToolbarIdentifier        @"Stop Toolbar Identifier"
#define SaveToolbarIdentifier        @"Save Toolbar Identifier"

@implementation SPSuperSFV

#pragma mark Initialization (App launching)
+ (void)initialize {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setObject:@"CRC32" forKey:@"checksum_algorithm"]; // default for most SFV programs
    [[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:dictionary];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    records = [[NSMutableArray alloc] init];
    queue = [[NSOperationQueue alloc] init];
    // TODO: We want to run several ops at the same time in the future
    [queue setMaxConcurrentOperationCount:1];

    updateUITimer = [[NSTimer scheduledTimerWithTimeInterval:0.5
                                                      target:self
                                                    selector:@selector(updateUITimer:)
                                                    userInfo:nil
                                                     repeats:YES] retain];
    
    
    
    [self setup_toolbar];

    // this is for the 'status' image
    cell = [[NSImageCell alloc] initImageCell:nil];
    NSTableColumn *tableColumn;
    tableColumn = [tableView_fileList tableColumnWithIdentifier:@"status"];
    [cell setEditable: YES];
    [tableColumn setDataCell:cell];
    [cell release];
    cell = [[NSImageCell alloc] initImageCell:nil];

    // selecting items in our table view and pressing the delete key
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(removeSelectedRecords:)
                                                 name:@"RM_RECORD_FROM_LIST"
                                               object:nil];

    // register for drag and drop on the table view
    [tableView_fileList registerForDraggedTypes:
        [NSArray arrayWithObjects:NSFilenamesPboardType, nil]];

    // make the window pertee and show it
    [button_stop setEnabled:NO];
    [self updateUI];

    [window_main center];
    [window_main makeKeyAndOrderFront:nil];
}

#pragma mark Termination (App quitting)
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *) sender
{
    // we're not document based, so we'll quit when the last window is closed
    return YES;
}

- (void) applicationWillTerminate: (NSNotification *) notification
{
    // dealloc, etc
    [queue release];
    queue = nil;
}

#pragma mark IBActions
- (IBAction)addClicked:(id)sender
{
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setPrompt:@"Add"];
    [oPanel setTitle:@"Add files or folder contents"];
    [oPanel setAllowsMultipleSelection:YES];
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:YES];
    [oPanel beginSheetForDirectory:NSHomeDirectory()
                              file:nil
                    modalForWindow:window_main
                     modalDelegate:self
                    didEndSelector:@selector(didEndOpenSheet:returnCode:contextInfo:)
                       contextInfo:NULL];
}

- (void)didEndOpenSheet:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSOKButton)
        [self processFiles:[openPanel filenames]];
}

// Hmm... Is this OK?
- (IBAction)recalculateClicked:(id)sender
{
    NSMutableArray *t = [[NSMutableArray alloc] initWithCapacity:1];
	[t addObjectsFromArray:records];
	[records removeAllObjects];
    int i;
    for (i = 0; i < [t count]; i++)
        [self processFiles:[NSArray arrayWithObject:[[[t objectAtIndex:i] properties] objectForKey:@"filepath"]]];
	[self updateUI];
	[t release];
}

- (IBAction)removeClicked:(id)sender
{
    if ((![tableView_fileList numberOfSelectedRows]) && ([records count] > 0))
        NSBeginAlertSheet(@"Confirm Removal", @"Removal All", @"Cancel", nil, window_main, self,
                          @selector(didEndRemoveAllSheet:returnCode:contextInfo:),
                          nil, nil, @"You sure you want to ditch all of the entries? They're so cute!");
    else
        [self removeSelectedRecords:nil];
}

- (void)didEndRemoveAllSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSOKButton) {
        [records removeAllObjects];
        [self updateUI];
    }
}


- (IBAction)saveClicked:(id)sender
{
    if (![records count])
        return;

    NSSavePanel *sPanel = [NSSavePanel savePanel];
    [sPanel setPrompt:@"Save"];
    [sPanel setTitle:@"Save"];
    [sPanel setRequiredFileType:@"sfv"];

    [sPanel beginSheetForDirectory:NSHomeDirectory()
                              file:nil
                    modalForWindow:window_main
                     modalDelegate:self
                    didEndSelector:@selector(didEndSaveSheet:returnCode:contextInfo:)
                       contextInfo:NULL];
}

- (void)didEndSaveSheet:(NSSavePanel *)savePanel returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSOKButton) {
        if ([records count]) {
            // shameless plug to start out with
            NSString *output = [NSString stringWithFormat:@"; Created using SuperSFV v%@ on Mac OS X", [self _applicationVersion]];

            NSEnumerator *e = [records objectEnumerator];
            SPFileEntry *entry;
            while (entry = [e nextObject]) {
                if ((![[[entry properties] objectForKey:@"result"] isEqualToString:@"Missing"])
                    && (![[[entry properties] objectForKey:@"result"] isEqualToString:@""])) {

                    output = [output stringByAppendingFormat:@"\n%@ %@",
                                [[[entry properties] objectForKey:@"filepath"] lastPathComponent],
                                [[entry properties] objectForKey:@"result"]];
                }
            }

            [output writeToFile:[savePanel filename] atomically:NO encoding:NSUTF8StringEncoding error:NULL];
        }
    }
}

- (IBAction)stopClicked:(id)sender
{
    [queue cancelAllOperations];
}

- (IBAction)showLicense:(id)sender
{
    NSString *licensePath = [[NSBundle mainBundle] pathForResource:@"License" ofType:@"txt"];
    [textView_license setString:[NSString stringWithContentsOfFile:licensePath usedEncoding:NULL error:NULL]];

    [NSApp beginSheet:panel_license
       modalForWindow:window_about
        modalDelegate:nil
       didEndSelector:nil
          contextInfo:nil];
}

- (IBAction)closeLicense:(id)sender
{
    [panel_license orderOut:nil];
    [NSApp endSheet:panel_license returnCode:0];
}

- (IBAction)aboutIconClicked:(id)sender
{

}

- (IBAction)showAbout:(id)sender
{
    // Credits
    NSAttributedString *creditsString;
    creditsString = [[[NSAttributedString alloc] initWithPath:[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"] documentAttributes:nil] autorelease];
    [[textView_credits textStorage] setAttributedString:creditsString];

    // Version
    [textField_version setStringValue:[self _applicationVersion]];

    // die you little blue bastard for attempting to thwart my easter egg
    [button_easterEgg setFocusRingType:NSFocusRingTypeNone];

    // Center n show eet
    [window_about center];
    [window_about makeKeyAndOrderFront:nil];
}

- (IBAction)contactClicked:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:reikonmusha@gmail.com"]];
}

#pragma mark Runloop
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    [self processFiles:[NSArray arrayWithObject:filename]];
    return YES;
}

// remove selected records from our table view
- (void)removeSelectedRecords:(id)ssender
{
	NSIndexSet *rows = [tableView_fileList selectedRowIndexes];

	NSUInteger current_index = [rows lastIndex];
    while (current_index != NSNotFound) {
        [records removeObjectAtIndex:current_index];
        current_index = [rows indexLessThanIndex:current_index];
    }

    [self updateUI];
}

// Called periodically for updating the UI
- (void)updateUITimer:(NSTimer *)timer
{
    [self updateUI];
}

// updates the general UI, i.e the toolbar items, and reloads the data for our tableview
- (void)updateUI
{
    [button_recalculate setEnabled:([records count] > 0)];
    [button_remove setEnabled:([records count] > 0)];
    [button_save setEnabled:([records count] > 0)];
    [textField_fileCount setIntValue:[records count]];

    // other 'stats' .. may be a bit sloppy
    int error_count = 0, failure_count = 0, verified_count = 0;

    NSEnumerator *e = [records objectEnumerator];
    SPFileEntry *entry;
    while (entry = [e nextObject]) {
        if ([[[entry properties] objectForKey:@"result"] isEqualToString:@"Missing"] ||
            [[[entry properties] objectForKey:@"expected"] isEqualToString:@"Unknown (not recognized)"]) {
                error_count++;
                continue;
        }

        if (![[[entry properties] objectForKey:@"expected"] isEqualToString:[[entry properties] objectForKey:@"result"]]) {
            failure_count++;
            continue;
        }

        if ([[[entry properties] objectForKey:@"expected"] isEqualToString:[[entry properties] objectForKey:@"result"]]) {
            verified_count++;
            continue;
        }
    }

    [textField_errorCount setIntValue:error_count];
    [textField_failedCount setIntValue:failure_count];
    [textField_verifiedCount setIntValue:verified_count];

    [tableView_fileList reloadData];
    [tableView_fileList scrollRowToVisible:([records count]-1)];
}

// process files dropped on the tableview, icon, or are manually opened
- (void)processFiles:(NSArray *) filenames
{
    BOOL isDir;
    NSFileManager *dm = [NSFileManager defaultManager];

    NSEnumerator *e = [filenames objectEnumerator];
    NSString *file;

    while (file = [e nextObject]) {
        if ([[[file lastPathComponent] substringWithRange:NSMakeRange(0, 1)] isEqualToString:@"."])
            continue;  // ignore hidden files
        if ([[[file pathExtension] lowercaseString] isEqualToString:@"sfv"]) {
            if ([dm fileExistsAtPath:file isDirectory:&isDir] && !isDir) {
                [self parseSFVFile:file];
                continue;
            }
        } else {
            // recurse directories (I didn't feel like using NSDirectoryEnumerator)
            if ([dm fileExistsAtPath:file isDirectory:&isDir] && isDir) {
                NSArray *dirContents = [dm contentsOfDirectoryAtPath:file error:NULL];
                int i;
                for (i = 0; i < [dirContents count]; i++) {
                    [self processFiles:[NSArray arrayWithObject:[file stringByAppendingPathComponent:[dirContents objectAtIndex:i]]]];
                }
                continue;
            }

            SPFileEntry *newEntry = [[SPFileEntry alloc] init];
            NSDictionary *newDict = [[NSMutableDictionary alloc]
                        initWithObjects:[NSArray arrayWithObjects:[NSImage imageNamed: @"button_cancel.png"], file, @"", @"", nil]
                                forKeys:[newEntry defaultKeys]];

            [newEntry setProperties:newDict];
            [newDict release];

            SPIntegrityOperation *integrityOp = [[SPIntegrityOperation alloc] initWithFileEntry:newEntry
                                                                                         target:self
                                                                                      algorithm:[popUpButton_checksum indexOfSelectedItem]];
            [newEntry release];

            [queue addOperation: integrityOp];
            [integrityOp release];
        }
    }
}

- (void)parseSFVFile:(NSString *) filepath
{
    NSArray *contents = [[NSString stringWithContentsOfFile:filepath usedEncoding:NULL error:NULL] componentsSeparatedByString:@"\n"];
    NSString *entry;
    NSEnumerator *e = [contents objectEnumerator];

    while (entry = [e nextObject]) {
        int errc = 0; // error count
        NSString *newPath;
        NSString *hash;

        entry = [entry stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([entry isEqualToString:@""])
            continue;
        if ([[entry substringWithRange:NSMakeRange(0, 1)] isEqualToString:@";"])
            continue; // skip the line if it's a comment

        NSRange r = [entry rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" "] options:NSBackwardsSearch];
        newPath = [[filepath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[entry substringToIndex:r.location]];
        hash = [entry substringFromIndex:(r.location+1)]; // +1 so we don't capture the space

        SPFileEntry *newEntry = [[SPFileEntry alloc] init];
        NSDictionary *newDict;

        // file doesn't exist...
        if (![[NSFileManager defaultManager] fileExistsAtPath:newPath]) {
            newDict = [[NSMutableDictionary alloc]
                        initWithObjects:[NSArray arrayWithObjects:[NSImage imageNamed: @"error.png"], newPath, hash, @"Missing", nil]
                                forKeys:[newEntry defaultKeys]];
            [newEntry setProperties:newDict];
            [newDict release];
            errc++;
        }

        // length doesn't match CRC32, MD5 or SHA-1 respectively
        if ([hash length] != 8 && [hash length] != 32 && [hash length] != 40) {
            newDict = [[NSMutableDictionary alloc]
                        initWithObjects:[NSArray arrayWithObjects:[NSImage imageNamed: @"error.png"],newPath,
                                            @"Unknown (not recognized)",[[newEntry properties] objectForKey:@"result"], nil]
                                forKeys:[newEntry defaultKeys]];

            [newEntry setProperties:newDict];
            [newDict release];
            errc++;
        }

        // if theres an error, then we don't need to continue with this entry
        if (errc) {
            [records addObject:newEntry];
            [newEntry release];
            [self updateUI];
            continue;
        }
        // assume it'll fail until proven otherwise
        newDict = [[NSMutableDictionary alloc]
                        initWithObjects:[NSArray arrayWithObjects:[NSImage imageNamed: @"button_cancel.png"], newPath, hash, @"", nil]
                                forKeys:[newEntry defaultKeys]];

        [newEntry setProperties:newDict];
        [newDict release];

        SPIntegrityOperation *integrityOp = [[SPIntegrityOperation alloc] initWithFileEntry:newEntry target:self];
        [newEntry release];

        [queue addOperation: integrityOp];
        [integrityOp release];
    }
}

// expects an NSArray containing:
// (NSNumber *)progressDelta, (NSString *)description
- (void)updateProgress:(NSArray *)args
{
    if (![[args objectAtIndex:1] isEqualToString:@""])
        [textField_status setStringValue:[args objectAtIndex:1]];

    [progressBar_progress incrementBy:[[args objectAtIndex:0] doubleValue]];
}

// expects an NSArray containing:
// (NSString *)description, (NSNumber *)minValue, (NSNumber *)maxValue
- (void)initProgress:(NSArray *)args
{
    if (![[args objectAtIndex:0] isEqualToString:@""])
        [textField_status setStringValue:[args objectAtIndex:0]];
    [progressBar_progress setMinValue:[[args objectAtIndex:1] doubleValue]];
    [progressBar_progress setMaxValue:[[args objectAtIndex:2] doubleValue]];
    [progressBar_progress setDoubleValue:0.0];

    if ([progressBar_progress isHidden])
        [progressBar_progress setHidden:NO];

    if ([textField_status isHidden])
        [textField_status setHidden:NO];

    if (![button_stop isEnabled])
        [button_stop setEnabled:YES];
}

// resets the progress bar and it's progress text to it's initial state
- (void)endProgress
{
    [textField_status setStringValue:@""];
    [textField_status setHidden:YES];

    [progressBar_progress setHidden:YES];
    [progressBar_progress setMinValue:0.0];
    [progressBar_progress setMaxValue:0.0];
    [progressBar_progress setDoubleValue:0.0];

    [button_stop setEnabled:NO];
    [popUpButton_checksum setEnabled:YES];
}

- (NSString *)_applicationVersion
{
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    return [NSString stringWithFormat:@"%@",(version ? version : @"")];
}

#pragma mark TableView
- (id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)row
{
    NSString *key = [column identifier];
    SPFileEntry *newEntry = [records objectAtIndex:row];
    if ([key isEqualToString:@"filepath"])
        return [[[newEntry properties] objectForKey:@"filepath"] lastPathComponent];
    return [[newEntry properties] objectForKey:key];
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [records count];
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
    return NSDragOperationEvery;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
              row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard* pboard = [info draggingPasteboard];
    NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];

    [self processFiles:files];

    return YES;
}

- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn
{
	if (tableView==tableView_fileList) {
		NSArray *allColumns = [tableView_fileList tableColumns];
		int i;
		for (i = 0; i < [tableView_fileList numberOfColumns]; i++)
			if ([allColumns objectAtIndex:i] != tableColumn)
				[tableView_fileList setIndicatorImage:nil inTableColumn:[allColumns objectAtIndex:i]];

		[tableView_fileList setHighlightedTableColumn:tableColumn];

		if ([tableView_fileList indicatorImageInTableColumn:tableColumn] != [NSImage imageNamed:@"NSAscendingSortIndicator"]) {
			[tableView_fileList setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:tableColumn];
			[self sortWithDescriptor:[[NSSortDescriptor alloc] initWithKey:[tableColumn identifier] ascending:YES]];
		} else {
			[tableView_fileList setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:tableColumn];
			[self sortWithDescriptor:[[NSSortDescriptor alloc] initWithKey:[tableColumn identifier] ascending:NO]];
		}
	}
}

- (void)sortWithDescriptor:(id)descriptor
{
	NSMutableArray *sorted = [[NSMutableArray alloc] initWithCapacity:1];
	[sorted addObjectsFromArray:[records sortedArrayUsingDescriptors:[NSArray arrayWithObject:descriptor]]];
	[records removeAllObjects];
	[records addObjectsFromArray:sorted];
	[self updateUI];
	[sorted release];
}


#pragma mark Toolbar
- (void)setup_toolbar
{
    NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier: SuperSFVToolbarIdentifier] autorelease];

    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: YES];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconOnly];

    [toolbar setDelegate: self];
    [window_main setToolbar: toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL)flag
{

    NSToolbarItem *toolbarItem = nil;

    if ([itemIdent isEqual: AddToolbarIdentifier]) {

        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];

        [toolbarItem setLabel: @"Add"];
        [toolbarItem setPaletteLabel: @"Add"];
        [toolbarItem setToolTip: @"Add a file or the contents of a folder"];
        [toolbarItem setImage: [NSImage imageNamed: @"edit_add.png"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(addClicked:)];
        [toolbarItem setAutovalidates: NO];

    } else if ([itemIdent isEqual: RemoveToolbarIdentifier]) {

        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];

        [toolbarItem setLabel: @"Remove"];
        [toolbarItem setPaletteLabel: @"Remove"];
        [toolbarItem setToolTip: @"Remove selected items or prompt to remove all items if none are selected"];
        [toolbarItem setImage: [NSImage imageNamed: @"edit_remove.png"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(removeClicked:)];
        [toolbarItem setAutovalidates: NO];

    } else if ([itemIdent isEqual: RecalculateToolbarIdentifier]) {

        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];

        [toolbarItem setLabel: @"Recalculate"];
        [toolbarItem setPaletteLabel: @"Recalculate"];
        [toolbarItem setToolTip: @"Recalculate checksums"];
        [toolbarItem setImage: [NSImage imageNamed: @"reload.png"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(recalculateClicked:)];
        [toolbarItem setAutovalidates: NO];

    } else if ([itemIdent isEqual: StopToolbarIdentifier]) {

        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];

        [toolbarItem setLabel: @"Stop"];
        [toolbarItem setPaletteLabel: @"Stop"];
        [toolbarItem setToolTip: @"Stop calculating checksums"];
        [toolbarItem setImage: [NSImage imageNamed: @"stop.png"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(stopClicked:)];
        [toolbarItem setAutovalidates: NO];

    } else if ([itemIdent isEqual: SaveToolbarIdentifier]) {

        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];

        [toolbarItem setLabel: @"Save"];
        [toolbarItem setPaletteLabel: @"Save"];
        [toolbarItem setToolTip: @"Save current state"];
        [toolbarItem setImage: [NSImage imageNamed: @"1downarrow.png"]];
        [toolbarItem setTarget: self];
        [toolbarItem setAction: @selector(saveClicked:)];
        [toolbarItem setAutovalidates: NO];

    } else if ([itemIdent isEqual: ChecksumToolbarIdentifier]) {

        toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];

        [toolbarItem setLabel: @"Checksum"];
        [toolbarItem setPaletteLabel: @"Checksum"];
        [toolbarItem setToolTip: @"Checksum algorithm to use"];
        [toolbarItem setView: view_checksum];
        [toolbarItem setMinSize:NSMakeSize(106, NSHeight([view_checksum frame]))];
        [toolbarItem setMaxSize:NSMakeSize(106,NSHeight([view_checksum frame]))];

	} else {
        toolbarItem = nil;
    }
    return toolbarItem;
}

- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar {
    return [NSArray arrayWithObjects: AddToolbarIdentifier, RemoveToolbarIdentifier,
                            RecalculateToolbarIdentifier, NSToolbarSeparatorItemIdentifier,
                            ChecksumToolbarIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
                            SaveToolbarIdentifier, StopToolbarIdentifier, nil];

}


- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar {
    return [NSArray arrayWithObjects: AddToolbarIdentifier, RecalculateToolbarIdentifier,
                            StopToolbarIdentifier, SaveToolbarIdentifier, ChecksumToolbarIdentifier,
                            NSToolbarPrintItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier,
                            NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier,
                            NSToolbarSeparatorItemIdentifier, RemoveToolbarIdentifier, nil];
}

// TODO: Delete this when we use KVO or notifications
- (void) addRecordObject:(NSObject *)object {
    [records addObject:object];
}

@end

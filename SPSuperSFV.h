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

#import <Cocoa/Cocoa.h>
#import "SPTableView.h"

@interface SPSuperSFV : NSObject <NSToolbarDelegate>
{
    IBOutlet NSButton *button_add;
    IBOutlet NSButton *button_closeLicense;
    IBOutlet NSButton *button_contact;
    IBOutlet NSButton *button_easterEgg;
    IBOutlet NSButton *button_recalculate;
    IBOutlet NSButton *button_remove;
    IBOutlet NSButton *button_save;
    IBOutlet NSButton *button_showLicense;
    IBOutlet NSButton *button_stop;
    IBOutlet NSPanel *panel_license;
    IBOutlet NSPopUpButton *popUpButton_checksum;
    IBOutlet NSProgressIndicator *progressBar_progress;
    IBOutlet NSTextField *textField_errorCount;
    IBOutlet NSTextField *textField_failedCount;
    IBOutlet NSTextField *textField_fileCount;
    IBOutlet NSTextField *textField_status;
    IBOutlet NSTextField *textField_verifiedCount;
    IBOutlet NSTextField *textField_version;
    IBOutlet NSTextView *textView_credits;
    IBOutlet NSTextView *textView_license;
    IBOutlet NSView *view_checksum;
    IBOutlet NSWindow *window_about;
    IBOutlet NSWindow *window_main;
    IBOutlet SPTableView *tableView_fileList;

    NSMutableArray *records;
    NSImageCell *cell;
    NSOperationQueue *queue;
    NSTimer *updateUITimer;
}
- (IBAction)aboutIconClicked:(id)sender;
- (IBAction)addClicked:(id)sender;
- (IBAction)closeLicense:(id)sender;
- (IBAction)contactClicked:(id)sender;
- (IBAction)recalculateClicked:(id)sender;
- (IBAction)removeClicked:(id)sender;
- (IBAction)saveClicked:(id)sender;
- (IBAction)showAbout:(id)sender;
- (IBAction)showLicense:(id)sender;
- (IBAction)stopClicked:(id)sender;

- (void)updateUI;
- (void)initProgress:(NSArray *)args;
- (void)updateProgress:(NSArray *)args;
- (void)endProgress;
- (void)parseSFVFile:(NSString *) filepath;
- (void)processFiles:(NSArray *) filenames;
- (void)removeSelectedRecords:(id) sender;
- (void)didEndSaveSheet:(NSSavePanel *)savePanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)didEndOpenSheet:(NSOpenPanel *)openPanel returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)didEndRemoveAllSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (NSString *)_applicationVersion;

- (id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)row;
- (int)numberOfRowsInTableView:(NSTableView *)aTableView;
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op;
- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation;
- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn;
- (void)sortWithDescriptor:(id)descriptor;

- (void)setup_toolbar;
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL)flag;
- (NSArray *) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar;
- (NSArray *) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar;

// TODO: Delete this when we use KVO or notifications
- (void) addRecordObject:(NSObject *)object;
@end

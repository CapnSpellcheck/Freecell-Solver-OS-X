/*
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 
 */

#import "PreferenceController.h"
#include "Debug.h"
#include "Solve FreeCell.h"

const int FCSLogModeAppend = 0;
const int FCSLogModeTruncate = 1;
const int FCSDefaultLogMode = 1; // mode is overwrite file
const BOOL FCSDefaultLogEnabled = NO; // log not enabled by default
NSString* FCSDefaultBgColorKey = @"bgcolor";
NSString* FCSDefaultLogEnabledKey = @"logenabled";
NSString* FCSDefaultLogFilePathKey = @"logpath";
NSString* FCSDefaultLogModeKey = @"logmode";
NSString* FCSDefaultLogFileName = @"FreeCell Solver log.txt";

@interface PreferenceController (PrivateAPI)
- (void) disableLogControls;
- (void) enableLogControls;
@end

@implementation PreferenceController

/* Initialization, maintenance, etc. */
- (id) init
{
  return [super initWithWindowNibName: @"Preferences"];
}

- (void) windowDidLoad
{
  // set the state of all the preference controls.
  NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];

  NSColor* bgColor = [NSUnarchiver unarchiveObjectWithData: [prefs objectForKey: FCSDefaultBgColorKey]];
  [bgColorWell setColor: bgColor];

  BOOL debugLogEnabled = [prefs boolForKey: FCSDefaultLogEnabledKey];
  [chkEnableLog setState: debugLogEnabled];

  NSString* logFilePath = [prefs objectForKey: FCSDefaultLogFilePathKey];
  [txtLogFilePath setStringValue: logFilePath];

  int logMode = [prefs integerForKey: FCSDefaultLogModeKey];
  // seems to be unexpected behavior with an NSMatrix of option buttons: selecting a different one
  // doesn't unselect the one already selected...?
  [optLogMode deselectAllCells];
  [optLogMode selectCellAtRow: logMode column: 0];

  // now we disable some controls if debug log is not enabled... (all enabled in nib)
  if (!debugLogEnabled) {
    [self disableLogControls];
  }
  // done
}
  

/* Actions */
- (IBAction)changeBackgroundColor:(id)sender
{
  NSColor* newColor = [bgColorWell color];
  NSData* colorData = [NSArchiver archivedDataWithRootObject: newColor];
  NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
  [prefs setObject: colorData forKey: FCSDefaultBgColorKey];
  // and send a notification to notify the main window of background change...
  [[NSNotificationCenter defaultCenter] postNotificationName: @"BgColorChange" object: [bgColorWell color]];
}

- (IBAction)changeEnableDebugLog:(id)sender
{
  // first update the controls
  if ([chkEnableLog state]) {
    [self enableLogControls];
    Debug::getDefaultInstance().enable(); // update setting in solver library 
  }
  else {
    [self disableLogControls];
    Debug::getDefaultInstance().disable(); // update setting in solver library
  }

  // and store the stuff in prefs
  [[NSUserDefaults standardUserDefaults] setBool: [chkEnableLog state] forKey: FCSDefaultLogEnabledKey];
}

// We run a sheet to ask the user for a path, then update the text field and prefs
- (IBAction)changeLogFilePath:(id)sender
{
  NSSavePanel* pathPanel = [NSSavePanel savePanel];
  [pathPanel setRequiredFileType: nil];

  [pathPanel setPrompt: @"Choose"];
//  [pathPanel setNameFieldLabel: @"Save log to:"];
  [pathPanel beginSheetForDirectory: [[txtLogFilePath stringValue] stringByDeletingLastPathComponent]
                               file: [[txtLogFilePath stringValue] lastPathComponent]
                     modalForWindow: [self window]
                      modalDelegate: self
                     didEndSelector: @selector(logPathSheetEnded:returnCode:context:)
                        contextInfo: NULL];
}

// update the text field and prefs
- (void) logPathSheetEnded: (NSSavePanel*) sheet returnCode: (int) code context: (void *) context
{
  if (code == NSOKButton) {
    [txtLogFilePath setStringValue: [sheet filename]];
    [[NSUserDefaults standardUserDefaults] setObject: [txtLogFilePath stringValue]
                                                forKey: FCSDefaultLogFilePathKey];
    // and finally, update the private data in the solver library
    setLogPath([[txtLogFilePath stringValue] UTF8String]);
  }
}

- (IBAction)changeLogFileMode:(id)sender
{
  NSLog(@"optLogMode: row is %i", [optLogMode selectedRow]);
  [[NSUserDefaults standardUserDefaults] setInteger: [optLogMode selectedRow]
                                             forKey: FCSDefaultLogModeKey];
  // and update the setting in the solver library
  setAppend([optLogMode selectedRow]);  
}

// PrivateAPI
- (void) enableLogControls
{
  [btnChooseLogFile setEnabled: YES];
  [txtLogFilePath setEnabled: YES];
  [optLogMode setEnabled: YES];
}

- (void) disableLogControls
{
  [btnChooseLogFile setEnabled: NO];
  [txtLogFilePath setEnabled: NO];
  [optLogMode setEnabled: NO];
}


@end

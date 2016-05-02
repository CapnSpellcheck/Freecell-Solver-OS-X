/* PreferenceController */
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

#import <Cocoa/Cocoa.h>

// global constants
extern const int FCSDefaultLogMode; // mode is overwrite file
extern NSString* FCSDefaultBgColorKey;
extern NSString* FCSDefaultLogEnabledKey;
extern NSString* FCSDefaultLogFilePathKey;
extern NSString* FCSDefaultLogModeKey;
extern const BOOL FCSDefaultLogEnabled;
extern NSString* FCSDefaultLogFileName;
extern const int FCSLogModeAppend;
extern const int FCSLogModeTruncate;

@interface PreferenceController : NSWindowController
{
    IBOutlet NSColorWell *bgColorWell;
    IBOutlet NSButton *btnChooseLogFile;
    IBOutlet NSButton *btnSave;
    IBOutlet NSButton *chkEnableLog;
    IBOutlet NSMatrix *optLogMode;
    IBOutlet NSTextField *txtLogFilePath;
}
- (IBAction)changeBackgroundColor:(id)sender;
- (IBAction)changeEnableDebugLog:(id)sender;
- (IBAction)changeLogFilePath:(id)sender;
- (IBAction)changeLogFileMode:(id)sender;

- (void) logPathSheetEnded: (NSSavePanel*) sheet returnCode: (int) code context: (void *) context;


@end

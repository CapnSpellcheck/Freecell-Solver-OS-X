/* AppController */
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
#include <vector>
#include "Tableau.h"
#include "Card.h"
#include "Location.h"

using std::vector;

const int FCSDeckWindowTag = 13; // lucky number
const int FCSMainWindowWidth = 781;

@class PreferenceController, DeckView, SolverView;

@interface AppController : NSObject
{
    IBOutlet NSWindow *mainWindow;
    IBOutlet DeckView* deckView;
    IBOutlet SolverView* solverView;
    IBOutlet NSWindow *solveSheet;
    IBOutlet NSProgressIndicator* solveProgressBar;
    IBOutlet NSProgressIndicator* playbackProgressBar;
    IBOutlet NSButton* backwardButton;
    IBOutlet NSButton* pauseButton;
    IBOutlet NSButton* forwardButton;
    IBOutlet NSTextField* curMoveTextField;
    IBOutlet NSTextField* totalMovesTextField;
    IBOutlet NSTextField* moveDelayField;
    
    PreferenceController* prefsController;
    BOOL solveMenuItemEnabled;
    BOOL isSolving;
}

- (IBAction)cancelSolve:(id)sender;

- (IBAction)doOpen:(id)sender;
- (IBAction)doPause:(id)sender;
- (IBAction)doPlayBackward:(id)sender;
- (IBAction)doPlayForward:(id)sender;
- (IBAction)doReset:(id)sender;
- (IBAction)doSave:(id)sender;
- (IBAction)doSolve:(id)sender;
- (IBAction)showPreferencePanel:(id)sender;
- (IBAction)toggleDeckWindowVisible:(id)sender;
- (IBAction)randomizeSetup:(id)sender;
- (IBAction)changeMoveDelay: (id)sender;
- (IBAction)randomizeRemaining: (id)sender;

- (void) changeBgColor: (NSNotification*) note;
- (void) setSolveMenuItemEnabled: (BOOL) enabled;

- (void) solveAlgorithmCompleted: (NSNotification*) note;
- (void) solveAlgorithmCompletedMainThread: (NSNotification*) note;

- (void) solverViewDidAdvanceMove;
- (void) solverViewDidUndoMove;
- (void) solverViewDidReachBeginning;
- (void) solverViewDidReachEnd;

- (void) userLeftPlaybackMode;

- (void) addOpenedFileToRecentMenu: (NSString*) filename;

- (void) moveCard: (Card) card fromLocation: (Location) from toLocation: (Location) to;

@end

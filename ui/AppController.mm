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

#import "AppController.h"
#import "Debug.h"
#import "DeckView.h"
#import "FCSFileHandler.h"
#import "FreeCellGame.h"
#import "Solve FreeCell.h"
#import "PreferenceController.h"
#import "SolverView.h"
#import "Tableau.h"
#include <vector>

using namespace std;

extern NSString* FCSAllCardsPlaced;

NSString* FCSFileExtension = @"fcs";

@implementation AppController

/* Initializations / maintenance etc. */
+ (void) initialize
{
  // Create a dictionary of the default preferences
  NSMutableDictionary* defaultPrefs = [NSMutableDictionary dictionary];

  // save the prefs to the dictionary
  // archive the background color
  // the default color will be blue, just for the heck of it...
  NSData* colorData = [NSArchiver archivedDataWithRootObject: [NSColor greenColor]];
  // default log file path is user's home directory
  NSString* logFilePath = [(NSHomeDirectory()) stringByAppendingPathComponent: FCSDefaultLogFileName];
  NSNumber* logMode = [NSNumber numberWithInt: FCSDefaultLogMode];
  NSNumber* logEnabled = [NSNumber numberWithBool: FCSDefaultLogEnabled];

  // put values in dictionary
  [defaultPrefs setObject: colorData   forKey: FCSDefaultBgColorKey];
  [defaultPrefs setObject: logEnabled  forKey: FCSDefaultLogEnabledKey];
  [defaultPrefs setObject: logFilePath forKey: FCSDefaultLogFilePathKey];
  [defaultPrefs setObject: logMode     forKey: FCSDefaultLogModeKey];

  // register the dictionary
  [[NSUserDefaults standardUserDefaults] registerDefaults: defaultPrefs];

  // initialize the random seed
  srand(time(NULL));
}

- (id) init
{
  // register as an observer for notifications
  [[NSNotificationCenter defaultCenter] addObserver: self
                                           selector: @selector(changeBgColor:)
                                               name: @"BgColorChange"
                                             object: nil];
  [[NSNotificationCenter defaultCenter] addObserver: self
                                           selector: @selector(solveAlgorithmCompleted:)
                                               name: NSThreadWillExitNotification
                                             object: nil];

  solveMenuItemEnabled = NO;
  isSolving = NO;
  
  return self;
}

- (void) dealloc
{
  // unregister as observer
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [prefsController release];
  [super dealloc];
}

// When we awake from nib, we have to set the background color of the main window.
// Also do other preference-related stuff: setting the state of the Solve FreeCell library
// (logging enabled, log path, log append mode)
- (void) awakeFromNib
{
  NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
  NSColor* bgColor = [NSUnarchiver unarchiveObjectWithData: [prefs objectForKey: FCSDefaultBgColorKey]];
  [mainWindow setBackgroundColor: bgColor];

  BOOL debugLogEnabled = [prefs boolForKey: FCSDefaultLogEnabledKey];
  if (debugLogEnabled) {
    Debug::getDefaultInstance().enable();
  }
  setLogPath([[prefs objectForKey: FCSDefaultLogFilePathKey] UTF8String]);
  setAppend([prefs integerForKey: FCSDefaultLogModeKey]);

  // Set these to the empty string because I have them nonempty in the nib
  // (so I can see them)
  [curMoveTextField setStringValue: @""];
  [totalMovesTextField setStringValue: @""];
  [moveDelayField setDoubleValue: [solverView timeIntervalBetweenMoves]];
}


/* Notifications */
- (void) changeBgColor: (NSNotification*) note
{
  NSColor* color = [note object];
  [mainWindow setBackgroundColor: color];
  [[mainWindow contentView] setNeedsDisplay: YES];
}


/* Actions */
- (IBAction)toggleDeckWindowVisible:(id)sender
{
  NSMenuItem* deckWindowItem = (NSMenuItem*) sender;
  if ([deckWindowItem state] == NSOffState) {
    [[deckView window] orderFront: self];
    [deckWindowItem setState: NSOnState];
  }
  else if ([deckWindowItem state] == NSOnState) {
    [[deckView window] orderOut: self];
    [deckWindowItem setState: NSOffState];
  }
}
    
/* In Open, we show an Open dialog, then process the setup file */
- (IBAction) doOpen: (id) sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  vector<Tableau> tempSetup;
  int result;
  FCSLoadSetupReturnValue loadStatus;

  result = [openPanel runModalForTypes:
             [NSArray arrayWithObjects: FCSFileExtension, NSFileTypeForHFSTypeCode(FCSFileTypeCode), nil]];

  // the rest of this method is only done if the user clicked OK.
  if (result == NSOKButton) {
    loadStatus = FCSFileHandler::loadSetupFromFile([openPanel filename], &tempSetup);
    switch (loadStatus) {
      case FCSLoadInvalidArchivedObject:
        NSRunAlertPanel(@"Loading failed",
                        @"The selected file did not contain a valid FreeCell setup.",
                        @"OK", nil, nil, nil);
        return;
      case FCSLoadInvalidCard:
        NSRunAlertPanel(@"Load warning",
                        @"The setup file was mostly correct, but had some invalid card information. "
                        @"I loaded as much information as I could."
                        @"OK", nil, nil, nil);
        break;
    }

    // disable Solve, if all cards are placed by the setup the SolverView will send us a notification
    solveMenuItemEnabled = NO;

    // the load more or less succeeded, so give the solver view the tableaus
    [solverView exitAnimationMode];
    [solverView setTableaus: &tempSetup];

    // do cleanup on the lower part of the main window
    [self userLeftPlaybackMode];
    
    // now we still need to figure out what cards are remaining on the deck (the saved setup did not
    // necessarily have all cards placed on the tableau)
    unsigned int tableauIndex, cardIndex;
    [deckView resetDeck];
    for (tableauIndex = 0; tableauIndex < kNumTableaus; tableauIndex++) {
      const Tableau& tableau = tempSetup[tableauIndex];
      for (cardIndex = 0; cardIndex < tableau.size(); cardIndex++) {
        [deckView removeCardWithRank: tableau.peek(cardIndex).num suit: tableau.peek(cardIndex).suit];
      }
    }
    [solverView discardCursorRects];
    [solverView resetCursorRects];

    [self addOpenedFileToRecentMenu: [openPanel filename]];
    [solverView setNeedsDisplay: YES];
    [deckView setNeedsDisplay: YES];
  }
}

/* On a Reset, we empty the setup tableaus, and move the cards back to the deck window. */
- (IBAction)doReset:(id)sender
{
  // remove all the cards from the solver view
  [solverView clearTableaus];
  [solverView exitAnimationMode];
  [solverView setNeedsDisplay: YES];
  
  // tell the deck window it has all cards
  [deckView resetDeck];
  [deckView setNeedsDisplay: YES];

  // do cleanup on the lower part of the main window
  [self userLeftPlaybackMode];
  
  // disable solve menu item
  solveMenuItemEnabled = NO;
  
  [solverView discardCursorRects];
  [solverView resetCursorRects];

  // show the deck window if it isn't already there
  [[deckView window] orderFront: self];  
}

/*
* On Randomize Setup, we overwrite the current state of the setup with a randomly generated setup.
* We need to tell the Solver View to redraw itself.
* We also empty the DeckView.
*/
- (IBAction)randomizeSetup:(id)sender
{
  vector<Tableau> randomSetup;
  FreeCellGame::getRandomSetup(&randomSetup);
  [solverView setTableaus: &randomSetup];
  [solverView setNeedsDisplay: YES];
  [deckView emptyDeck];
  [deckView setNeedsDisplay: YES];
  
  [solverView discardCursorRects];
  [solverView resetCursorRects];
}

/*
 * On Randomize Remaining, we take the current state of the setup, determine the cards remaining,
 * complete the setup by randomly placing the remaining cards.
 */
- (IBAction)randomizeRemaining: (id)sender
{
  if ([solverView cardCount] == 0) {
    // if there are no setup cards yet, do this which may be faster
    [self randomizeSetup: self];
    return;
  }
  vector<Tableau> setup;
  [solverView getTableaus: &setup];
  FreeCellGame::finishSetupRandomly(&setup);
  [solverView setTableaus: &setup];
  [solverView setNeedsDisplay: YES];
  [deckView emptyDeck];
  [deckView setNeedsDisplay: YES];
  
  [solverView discardCursorRects];
  [solverView resetCursorRects];
}

- (IBAction)changeMoveDelay: (id)sender
{
  [moveDelayField setDoubleValue: [sender doubleValue]];
  [solverView setTimeIntervalBetweenMoves: [sender doubleValue]];
}

/* On a save, we bring up a save panel and write the tableau setup to the selected file */
- (IBAction) doSave: (id) sender
{
  int result;
  NSString* filePath;
  NSSavePanel* savePanel = [NSSavePanel savePanel];
  [savePanel setRequiredFileType: FCSFileExtension];
  [savePanel setTitle: @"Save Game Setup"];

  result = [savePanel runModal];
  if (result == NSFileHandlingPanelOKButton) {
    filePath = [savePanel filename];
    vector<Tableau> tableaus;
    [solverView getTableaus: &tableaus];

    if (!FCSFileHandler::saveSetupToFile(filePath, tableaus)) {
      NSRunAlertPanel(@"Error", @"Your setup couldn't be saved to the specified file. You may not have permission to write to the specified path", @"OK", nil, nil);
    }
  }
  // if button was Cancel, do nothing
}

/* in Solve, we show the solving sheet, and run the solver. ;-) */
- (IBAction) doSolve: (id) sender
{
  [NSApp beginSheet: solveSheet
     modalForWindow: mainWindow
      modalDelegate: self
     didEndSelector: @selector(solveDidEnd:returnCode:contextInfo:)
        contextInfo: NULL];

  // disable everything in the menu bar...can't do nothin' but cancel...
  isSolving = YES;
  
  // begin the progress bar
  [solveProgressBar startAnimation: self];

  // ask the solver view to set up a SolveTask with its private data
  [solverView runSolveTask];
  // we'll get a notification NSThreadWillExitNotification when the thread ends
}

- (IBAction) cancelSolve: (id) sender
{
  [solveProgressBar stopAnimation: self];
  [solveSheet orderOut: self];
  [NSApp endSheet: solveSheet returnCode: 1];
  solveMenuItemEnabled = YES;
  requestStopForSolverThread();
}

// the below name is slightly a misnomer; I realized it's also called if the user cancels and
// the solver thread is told to stop.
// To account for this, we check our isSolving variable.
// I realized that this selector will always be executed on the exiting thread, due to how
// NSThreadWillExitNotifications work. It's really just better if execution switches to the
// main thread.
- (void) solveAlgorithmCompleted: (NSNotification*) note
{
  [self performSelectorOnMainThread: @selector(solveAlgorithmCompletedMainThread:)
                         withObject: note
                      waitUntilDone: NO];
}

- (void) solveAlgorithmCompletedMainThread: (NSNotification*) note {
  if (!isSolving) {
    // The UI is no longer in a solving state. Which means the user canceled and we requested the
    // thread to stop.
    return;
  }
  [solveProgressBar stopAnimation: self];
  [solveSheet orderOut: self];
  [NSApp endSheet: solveSheet returnCode: 0];  
}

- (void) solveDidEnd: (NSWindow*) solveSheet returnCode: (int) code contextInfo: (void *) info
{
  // re-enable the menu bar
  isSolving = NO;
  // if the user didn't cancel, see if the solve succeeded
  if (code == 0) {
    if ([solverView hasSolution]) {
      // begin playing the solution
      [curMoveTextField setIntValue: 0];
      [totalMovesTextField setIntValue: [solverView moveCount]];
      [playbackProgressBar setMaxValue: [solverView moveCount]];
      [playbackProgressBar setDoubleValue: 0];
      [solverView enterAnimationMode];
      // disable the Solve menu item
      solveMenuItemEnabled = NO;
      [solverView discardCursorRects];

      // and we'll send ourselves a doPlayForward action
      [self doPlayForward: self];
    }
    else {
      // didn't get a solution
      // notify user
      NSRunInformationalAlertPanel(@"Failure", @"The solver could not find a solution to this setup.", @"OK", nil, nil);
      solveMenuItemEnabled = YES;
    }
  }
}

- (IBAction) showPreferencePanel: (id) sender
{
  if (prefsController == nil) {
    prefsController = [[PreferenceController alloc] init];
  }
  [prefsController showWindow: self];
}

- (IBAction)doPause:(id)sender
{
  // disable the pause button
  [pauseButton setEnabled: NO];
  // enable the other buttons
  [forwardButton setEnabled: YES];
  [backwardButton setEnabled: YES];

  // pause the progress bar animation
  [playbackProgressBar stopAnimation: self];
  // and tell the solver view to pause
  [solverView pause];
}

- (IBAction)doPlayBackward:(id)sender
{
  // disable the play backward button
  [backwardButton setEnabled: NO];
  // enable the other buttons
  [pauseButton setEnabled: YES];
  [forwardButton setEnabled: YES];

  // resume progress bar animation
  [playbackProgressBar startAnimation: self];
  // and tell the solver view to play backward
  [solverView playBackward];
}

- (IBAction)doPlayForward:(id)sender;
{
  // disable the play forward button
  [forwardButton setEnabled: NO];
  // enable the other buttons
  [backwardButton setEnabled: YES];
  [pauseButton setEnabled: YES];

  // resume progress bar animation
  [playbackProgressBar startAnimation: self];
  // and tell the solver view to play forward
  [solverView playForward];
}


/**
 * Menus
 **/
- (BOOL) validateMenuItem: (NSMenuItem*) menuItem
{
  SEL action = [menuItem action];

  // first, if we're solving, disable everything
  if (isSolving) {
    return NO;
  }
  
  if (action == @selector(doSolve:)) {
    return solveMenuItemEnabled;
  }
  // Don't allow the user to save the setup after the user has asked the solver to solve.
  // I know, it's less than ideal, but I don't keep a copy of the original game setup after
  // the solution has started.
  // Also don't allow the user to randomize setup.
  if (action == @selector(doSave:) || action == @selector(randomizeSetup:)) {
    return ![solverView isInAnimationMode];
  }
  if (action == @selector(randomizeRemaining:)) {
    return ![solverView isInAnimationMode] && [solverView cardCount] < NUM_CARDS;
  }
  return YES;
}

/**
* delegate for deck window
 **/
- (void) windowWillClose: (NSNotification*) notification
{
  if ([notification object] == [deckView window]) {
    [[[NSApp windowsMenu] itemWithTag: FCSDeckWindowTag] setState: NSOffState];
  }
}

// The user can increase the height of the window if some tableaus become super long during the game.
// But the user can't change the width while resizing.
- (NSSize) windowWillResize: (NSWindow*) sender toSize: (NSSize) size
{
  if (sender == [solverView window]) {
    return NSMakeSize(FCSMainWindowWidth, size.height);
  }
  return size;
}

/* delegate for solver window */
// if the user miniaturizes the main window, we'll pause the animation
- (void) windowWillMiniaturize: (NSNotification*) notification
{
  if ([notification object] == [solverView window] && [solverView isInAnimationMode]) {
    [self doPause: self];
  }
}

/* delegate for NSApplication */
- (BOOL) application: (NSApplication*) app openFile: (NSString*) filename
{
  // Much of the code is similar to doOpen:
  vector<Tableau> tempSetup;
  FCSLoadSetupReturnValue loadStatus;

  loadStatus = FCSFileHandler::loadSetupFromFile(filename, &tempSetup);
  switch (loadStatus) {
    case FCSLoadInvalidArchivedObject:
      NSRunAlertPanel(@"Loading failed",
                      @"The selected file did not contain a valid FreeCell setup.",
                      @"OK", nil, nil, nil);
      return NO;
    case FCSLoadInvalidCard:
      NSRunAlertPanel(@"Loading failed",
                      @"The selected file did not contain a valid FreeCell setup.",
                      @"OK", nil, nil, nil);
      return NO;
  }

  // disable Solve, if all cards are placed by the setup the SolverView will send us a notification
  solveMenuItemEnabled = NO;

  // the load more or less succeeded, so give the solver view the tableaus
  [solverView exitAnimationMode];
  [solverView setTableaus: &tempSetup];

  // do cleanup on the lower part of the main window
  [self userLeftPlaybackMode];

  // now we still need to figure out what cards are remaining on the deck (the saved setup did not
  // necessarily have all cards placed on the tableau)
  unsigned int tableauIndex, cardIndex;
  [deckView resetDeck];
  for (tableauIndex = 0; tableauIndex < kNumTableaus; tableauIndex++) {
    const Tableau& tableau = tempSetup[tableauIndex];
    for (cardIndex = 0; cardIndex < tableau.size(); cardIndex++) {
      [deckView removeCardWithRank: tableau.peek(cardIndex).num suit: tableau.peek(cardIndex).suit];
    }
  }
  
  [solverView discardCursorRects];
  [solverView resetCursorRects];

  [self addOpenedFileToRecentMenu: filename];
  [solverView setNeedsDisplay: YES];
  [deckView setNeedsDisplay: YES];
  return YES;
}

/* Logic */
- (void) setSolveMenuItemEnabled: (BOOL) enabled
{
  solveMenuItemEnabled = enabled;
}

- (void) userLeftPlaybackMode
{
  // playback buttons may have been enabled, so disable all
  [backwardButton setEnabled: NO];
  [pauseButton setEnabled: NO];
  [forwardButton setEnabled: NO];

  // reset solution playback progress bar
  [playbackProgressBar setDoubleValue: 0];
  
  [curMoveTextField setStringValue: @""];
  [totalMovesTextField setStringValue: @""];
}

- (void) addOpenedFileToRecentMenu: (NSString*) filename
{
  // one-line goodness!
  [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL: [NSURL fileURLWithPath: filename]];
}

// moveCard is meant to move cards only to/from tableaus and the deck view
// I was going to use this to implement Undo/Redo, but then decided that moving a card is simple enough
// that a user can do any undoing.
- (void) moveCard: (Card) card fromLocation: (Location) from toLocation: (Location) to
{
  if (from == deck) {
    [deckView removeCardWithRank: card.num suit: card.suit];
    if (to >= tableau1 && to <= tableau8) {
      [solverView addCard: card toTableauIndex: to - tableau1];
    }
  }
  else if (from >= tableau1 && from <= tableau8) {
    [solverView removeCardFromTableauIndex: from - tableau1];
    if (to == deck) {
      [deckView addCardWithRank: card.num suit: card.suit];
    }
    else if (to >= tableau1 && to <= tableau8) {
      [solverView addCard: card toTableauIndex: to - tableau1];
    }
  }
  else {
    NSLog(@"moveCard:fromLocation:toLocation: invalid from or to location.");
  }
}

/* This is kind of delegate behavior, and ideally would be so. */
- (void) solverViewDidAdvanceMove
{
  NSAssert([curMoveTextField intValue] >= 0, @"Oops: curMoveTextField was not a nonnegative integer");
  [curMoveTextField setIntValue: [curMoveTextField intValue] + 1];
  [playbackProgressBar incrementBy: 1];
}
  
- (void) solverViewDidUndoMove
{
  if ([curMoveTextField intValue] > 0) {
    [curMoveTextField setIntValue: [curMoveTextField intValue] - 1];
    [playbackProgressBar incrementBy: -1];
  }
}

- (void) solverViewDidReachBeginning
{
  [pauseButton setEnabled: NO];
  [curMoveTextField setIntValue: 0];
}

- (void) solverViewDidReachEnd
{
  [pauseButton setEnabled: NO];
}


@end

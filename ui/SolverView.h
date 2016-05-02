/* SolverView */
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
#import "FreeCellGame.h"
#import "UIConstants.h"
#include <vector>
#include "Tableau.h"
#include "CardMove.h"

using std::vector;

const int FCSSolverHorizontalMargin = 30;
const int FCSSolverVerticalMargin = 20;
const int FCSSpaceBetweenTableaus = 20;
const int FCSFirstFoundationX = 400;
const int FCSSpaceBetweenFoundations = 20;
const int FCSFirstTableauX = 40;
const int FCSTableauY = 170;

const int TARGET_ANIMATIONS_PER_SECOND = 40;
static const NSTimeInterval ANIMATION_INTERVAL = 1.0 / TARGET_ANIMATIONS_PER_SECOND;
// This constant MUST BE SYNCED to the initial value of the slider in the solver window.
// Ideally this kludge would be fixed
const float DEFAULT_PLAY_SPEED = 300.0;

enum PlaybackMode {
  PlaybackReverse,
  PlaybackPause,
  PlaybackForward
};

@class AppController;

@interface SolverView : NSView
{
  // I was pretty reluctant to do this, but in the end it made the code simpler to have
  // a pointer here to the app controller.
  IBOutlet AppController* appController;
  
  // paths for drawing rects around card areas
  NSBezierPath* freeCellPath;
  NSBezierPath* foundationPath;

  int highlightedTableau; // index of a highlighted tableau during dragging
  vector<Tableau>* tableauContents; // cards on the tableaus, left to right
  unsigned int cardCount; // during setup, it means the number of cards on the tableaus; don't
                          // count on this during solution playback
  unsigned int numTableausWithMaxCards; // similar to comment above...
  int draggedCardOrigin; // index of the tableau where a mouse down occurred
  BOOL wasDestinationOfDrag;

  // playback logic
  BOOL inAnimationMode;
  Card freeCellCards[NUM_FREE_CELLS]; // the cards on the 4 free cells, left to right
  unsigned int ranksOnFoundation[4]; // the rank of the top card on each foundation
  vector<CardMove>* moveList; // list of moves in the solution
  int currentMove; // index of the current move in moveList
  PlaybackMode mode;
  NSPoint currentMovingCardLoc; // where the current moving card should be drawn
  NSPoint currentMoveOrigin;
  NSPoint currentMoveDest;
  NSTimeInterval secsBetweenMoves; // have a little pause between moves so that even if play is at max speed, user
                          // has some chance to see what's going on -- this is currently set as a constant
                          // in the init method
  NSPoint deltaBetweenFrames; // the dx and dy to move the current card by for the next frame
  // it's the absolute value actually, the frame advancer converts to negative if necessary
  float playSpeed; // in pixels moved per second
  NSTimer* animationTimer; // times when the next frame should be drawn for the current moving card; invalidated
                           // when paused and between card moves
  BOOL atEndOfSolution; // indicates whether the view is at the end of the solution - necessary hack
  BOOL atBeginningOfSolution; // indicates whether the view is at the beginning of the solution
}

- (IBAction)changePlaySpeed:(id)sender; // SolverView receives action directly from slider
// - (void) setMoveDelay: (double) moveDelay; // if I wanna allow this settable later...

- (NSPoint) pointForNextCardOnTableau: (int) tableau;
- (NSPoint) pointForTopCardOnTableau: (int) tableau;
- (NSPoint) pointForFreeCellNumber: (int) number;
- (NSPoint) pointForFoundationOfSuit: (CardSuit) suit;
- (int) tableauIndexForPoint: (NSPoint) point;
- (int) pixelLengthForTableau: (int) tableau;
- (NSRect) rectForTableau: (int) tableau;
- (NSRect) rectForTopCardOnTableau: (int) tableau;
- (NSPoint) originPointForCurrentMoveInverted: (BOOL) inverted;
- (NSPoint) destinationPointForCurrentMoveInverted: (BOOL) inverted;
- (NSPoint) deltaBetweenFramesForCurrentMove;

- (void) clearTableaus;
- (void) getTableaus: (vector<Tableau>*) tableaus;
- (void) setTableaus: (const vector<Tableau>*) tableaus;

- (unsigned int) cardCount;
- (unsigned int) moveCount;

- (BOOL) hasSolution;

- (void) pause;
- (void) playBackward;
- (void) playForward;
- (void) solverViewAdvanceFrame;
- (void) advanceMove;
- (void) goBackMove;

- (void) runSolveTask;
- (void) enterAnimationMode;
- (void) exitAnimationMode;
- (BOOL) isInAnimationMode;

- (void) removeCurrentMoveCardFromOrigin;
- (void) removeCard: (Card) card fromLocation: (Location) loc;
- (void) addCard: (Card) card toTableauIndex: (int) index;
- (void) removeCardFromTableauIndex: (int) index;

- (double) timeIntervalBetweenMoves;
- (void) setTimeIntervalBetweenMoves: (double)interval;

@end

CardSuit foundationSuitForIndex(int index);
int foundationIndexForSuit(CardSuit suit);

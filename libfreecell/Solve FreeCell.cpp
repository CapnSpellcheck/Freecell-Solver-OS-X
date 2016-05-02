// Solve FreeCell
// Julian Pellico
// � 2001 Julian Pellico
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

// This file contains an ANSI C++ implementation of solving the solitaire
// game FreeCell.
// FreeCell consists of 8 tableaus, 4 free cells, and 4 foundations.
// The 8 tableaus are the input for the problem. They describe the initial
// card arrangement. The tableaus must be read in by either the ANSI
// command line module, or with a platform-specific front end.
// The algorithm used is trial-and-error backtracking, with preferable
// moves (i.e., moves to foundations) attempted first.

// A problem I will need to handle with this method is the fact that
// moves in this game can be cycled: a card can potentially be moved back
// and forth between 2 tableaus, or between a freecell and tableau, if there
// are no other moves available.
// 7/28/01: First attempt to control move cycling. I implement a counter that
// keeps track of the number of moves made between foundation moves. When
// solveFreeCell sees that the count has reached a certain level, it simply
// returns.
// 5/31/04: So I'm finally returning to this project.... :-P
// First attempt didn't work. I'm going to implement a state memory so that if
// the solver ever returns to the same game state, it will abandon that path.

// 7/16/04
// TODO: The solver library exhibits really poor OOD. It's not reentrant and doesn't
// reset its state well.

// 8/15/04
// Implementing a simple scoring system for possible moves so they can be stored
// in a priority queue.

///////////////////////////////////////////////////////////////////////////////

#include "FreeCellGame.h"
#include "Solve FreeCell.h"
#include "MoveScorePair.h"
#include <time.h>

using namespace std;
extern void printSolution(const vector<CardMove>& soln);

///////////////////////////////////////////////////////////////////////////////
// constants
// move rankings
enum {
  ScoreMoveToFoundation = 10000,
  ScoreMoveOffFreeCell = 300,
  ScoreMoveToTableau = 100,
  ScoreMoveFromTableau = 100,
  ScoreMoveToFreeCell = 0,
  ScoreMoveToEmptyTableauPerRank = 20,
  ScoreMoveFromPreferredOrigin = 200,
  ScoreMoveToPreferredDestination = 200,
  ScorePenaltyForBuryingCard = 50,
};


///////////////////////////////////////////////////////////////////////////////
// globals
static bool gSolved;

static FreeCellStates fcStates;

static FreeCellGame game;

static int append = false;

static string logPath;

static bool stopRequested = false;


///////////////////////////////////////////////////////////////////////////////
// Functions

// solveFreeCell
void solveFreeCell(vector<CardMove>* moveList, const vector<Tableau>& passedTableaus) {
  ofstream logfile;
  Debug& debugger = Debug::getDefaultInstance();
  char * strStartTime, * strEndTime;

  if (debugger.isEnabled()) {
    if (append == LOG_MODE_APPEND) {
      logfile.open(logPath.c_str(), ios_base::out | ios_base::app);
    }
    else {
      logfile.open(logPath.c_str());
    }
    debugger.setDebugStream(logfile);

    time_t startTime = time(NULL);
    strStartTime = ctime(&startTime);
    strStartTime[INDEX_TO_CHANGE_FROM_NEWLINE_TO_SPACE_FROM_CTIME] = ' ';
    debugger << strStartTime << "Solve FreeCell library starting" << endl;
  }

  gSolved = false;
  // copy the passed tableaus to the game tableaus
  game.setTableaus(passedTableaus);
  moveList->clear();

  solveFCRec(moveList);
  // validate the solution
  debugger << "Validating initial solution..." << endl;
  if (!validateSolution(*moveList, passedTableaus)) {
    cerr << "Error: solution not valid." << endl;
  }
  else {
    debugger << "Solution is valid" << endl;
  }

#ifdef SOLVEFREECELL_LIB_THREADED
  if (!stopRequested) {
#endif
    // optimize solution
    optimizeMoves(moveList);
    debugger << "Validating optimized solution..." << endl;
    if (!validateSolution(*moveList, passedTableaus)) {
      debugger << "Error: optimization caused the solution to be invalid." << endl;
    }
    else {
      debugger << "Optimized solution is valid" << endl;
    }
#ifdef SOLVEFREECELL_LIB_THREADED
  }
#endif

  if (debugger.isEnabled()) {
    time_t endTime = time(NULL);
    strEndTime = ctime(&endTime);
    strEndTime[INDEX_TO_CHANGE_FROM_NEWLINE_TO_SPACE_FROM_CTIME] = ' ';
    debugger << strEndTime << "Solve FreeCell library finished\n" << endl;
    logfile.close();
  }

  game.reset();
  fcStates.clear();
  stopRequested = false;
}

// solveFCRec
// Requirements: that the random seed has been suitably initialized.
void solveFCRec(vector<CardMove>* moveList, unsigned short myCount) {
#ifdef SOLVEFREECELL_LIB_THREADED
  if (stopRequested) {
    return;
  }
#endif
  priority_queue<MoveScorePair> possibleMoves;
  bool foundationMovesOnly = (myCount == kMaxMovesBetweenFoundationMoves);
  unsigned short newCount;

  possibleMoves = getPossibleMoves();
  Debug::getDefaultInstance() << "Possible move count: " << possibleMoves.size() << endl;

  while (!possibleMoves.empty()) {
    const CardMove& curMove = possibleMoves.top().move();
    possibleMoves.pop();
    if (filterMove(*moveList, curMove)) {
      continue; // skip this move
    }
    
    if (!(foundationMovesOnly && curMove.dest != foundation)) {
      if (curMove.dest == foundation)
        newCount = 0;
      else
        newCount = myCount + 1;

      makeMove(moveList, curMove);
      if (!seenCurrentState() || curMove.dest == foundation) {
        addState();

        if (!game.gameIsSolved()) {
          solveFCRec(moveList, newCount);
          if (!gSolved) {
            undoMove(moveList, curMove);
          }
          else return;	// game was solved in recursive call
        }
        else { // foundations are full -- just solved game
          gSolved = true;
          return;
        }
      }
      else {	// we have seen the current state -- undo the move
        undoMove(moveList, curMove);
      }
    }
  }
}


// getPossibleMoves
// Get all the possible moves, in some heuristic order that should move the game
// towards a solution.
// 8/2/04 I have revised the move selection order to something that is more fine-grained.
// It is based on a research paper written by two grad students in an AI course.
// Their names are Kevin Atkinson and Shari Holstege. The paper is locatable online.
// 8/15/04 Got rid of cumbersome vector storage for moves. Switched to priority queue.
priority_queue<MoveScorePair> getPossibleMoves() {
  unsigned int i, j;
  set<Location> goodOrigins = game.getPreferredMoveOrigins();
  set<Location> goodDestinations = game.getPreferredMoveDestinations();
  const vector<Tableau>& tableaus = game.getTableaus();
  const FreeCells& freeCells = game.getFreeCells();
  unsigned short usedCells = freeCells.countUsedCells();
  const Card* topTableauCards[kNumTableaus];
  // yeah, use greater<>, just so I can keep my head straight: higher score => better
  // longest type ever...
  priority_queue<MoveScorePair> rankedMoves;
  long score;
  bool hasEmptyTableau = false;
  Debug& debugger = Debug::getDefaultInstance();

  // get top tableau cards
  for (i = 0; i < kNumTableaus; i++) {
    if (tableaus[i].empty()) {
      topTableauCards[i] = NULL;
      hasEmptyTableau = true;
    }
    else {
      topTableauCards[i] = &tableaus[i].top();
    }
  }

  // 1. score moves for tableau => foundation
  for (i = 0; i < kNumTableaus; i++) {
    if (topTableauCards[i]) {
      const Card& curCard = *topTableauCards[i];
      if (curCard.num == game.nextFoundationRankForSuit(curCard.suit)) {
        score = ScoreMoveToFoundation;
        rankedMoves.push(MoveScorePair(CardMove(curCard, tableauToLoc(i), foundation), score));
      }
    }
  }

  // 1. Add moves for free cells => foundation
  for (i = 0; i < usedCells; i++) {
    Card const& curCard = freeCells.get(i);
    if (curCard.num == game.nextFoundationRankForSuit(curCard.suit)) {
      score = ScoreMoveToFoundation;
      rankedMoves.push(MoveScorePair(CardMove(curCard, cell, foundation), score));
    }
  }

  // add moves for free cells => tableau
  for (i = 0; i < usedCells; i++) {
    Card const& curCard = freeCells.get(i);
    for (j = 0; j < kNumTableaus; j++) {
      score = ScoreMoveToTableau + ScoreMoveOffFreeCell;
      Location loc = tableauToLoc(j);
      if (goodDestinations.find(loc) != goodDestinations.end()) {
        score += ScoreMoveToPreferredDestination;
      }
      // 8/21/04 added penalty based on how deep the next useful cards are in the tableaus
      else {
        int depth = game.depthOfNextFoundationCardForTableau(j);
        if (depth > 0) {
          score -= ScorePenaltyForBuryingCard; 
        }
      }
      if (topTableauCards[j] == NULL) {
        score += ScoreMoveToEmptyTableauPerRank * curCard.num;
        rankedMoves.push(MoveScorePair(CardMove(curCard, cell, loc), score));
      }
      else if (canPlaceOnTop(curCard, *topTableauCards[j])) {
        rankedMoves.push(MoveScorePair(CardMove(curCard, cell, loc), score));
      }
    }
  }

  // add moves for tableau => different tableau
  for (i = 0; i < kNumTableaus; i++) {
    if (topTableauCards[i]) {
      for (j = 0; j < kNumTableaus; j++) {
        if (i != j) {
          score = ScoreMoveFromTableau + ScoreMoveToTableau;
          Location originLoc = tableauToLoc(i);
          Location destLoc = tableauToLoc(j);
          if (goodOrigins.find(originLoc) != goodOrigins.end()) {
            score += ScoreMoveFromPreferredOrigin;
          }
          if (goodDestinations.find(destLoc) != goodDestinations.end()) {
            score += ScoreMoveToPreferredDestination;
          }
          else {
            int depth = game.depthOfNextFoundationCardForTableau(j);
            if (depth > 0) {
              score -= ScorePenaltyForBuryingCard;
            }
          }
          if (topTableauCards[j] == NULL) {
            score += ScoreMoveToEmptyTableauPerRank * topTableauCards[i]->num;
            rankedMoves.push(MoveScorePair(CardMove(*topTableauCards[i], originLoc, destLoc), score));
          }
          else if (canPlaceOnTop(*topTableauCards[i], *topTableauCards[j])) {
            rankedMoves.push(MoveScorePair(CardMove(*topTableauCards[i], originLoc, destLoc), score));
          }
        }
      }
    }
  }
  
  // add moves for tableau => free cell
  // 7/31/01 added randomization
  if (usedCells < 4) {
    unsigned char indices[kNumTableaus];
    getRandomIndices(indices, kNumTableaus);
    for (i = 0; i < kNumTableaus; i++) {
      if (topTableauCards[indices[i]]) {
        score = ScoreMoveFromTableau + ScoreMoveToFreeCell;
        Location originLoc = tableauToLoc(indices[i]);
        if (goodOrigins.find(originLoc) != goodOrigins.end()) {
          score += ScoreMoveFromPreferredOrigin;
        }
        rankedMoves.push(MoveScorePair(CardMove(*topTableauCards[indices[i]], originLoc, cell), score));
      }
    }
  }

  return rankedMoves;
}


void makeMove(vector<CardMove>* moveList, const CardMove& theMove) {
  game.performMove(theMove);
  moveList->push_back(theMove);
}


void undoMove(vector<CardMove>* moveList, const CardMove& theMove) {
  game.undoMove(theMove);
  moveList->pop_back();
}

/**
* filterMove: return a boolean, true if prospectiveMove should be filtered (skipped),
 * false if it should be performed.
 * The point of filterMove is to ignore possible moves that are provably asinine.
 * The filter is allowed to look at past moves and the state of the tableaus.
 **/
bool filterMove(const vector<CardMove>& moves, const CardMove& prospectiveMove)
{
  if (prospectiveMove.dest == foundation) { // avoid doing stupid things...
    return false;
  }

  const vector<Tableau>& tableaus = game.getTableaus();

  // filter moves that take a card off a very "stable" tableau: a tableau based on a king, is stacked
  // correctly and is 3 or more cards
  if (isLocTableau(prospectiveMove.from)) {
    const Tableau& tableau = tableaus[locToTableau(prospectiveMove.from)];
    if (tableau.peek(0).num == 13 && tableau.size() >= 3) { // if the bottom card is a king...
      // move from the top of the tableau to the bottom
      for (int i = tableau.size() - 1; i > 0; i--) {
        // compare this card to the one below it
        if (!canPlaceOnTop(tableau.peek(i), tableau.peek(i - 1))) {
          return false; // it's not a perfect stack, move may not be asinine
        }
      }
      Debug::getDefaultInstance() << "filtering a move: stable tableau rule" << endl;
      return true;
    }
  }

  // filter 2: don't move a card to Location x that is identically stackable to a card that was just moved off of
  // location x, if x is a tableau. That is asinine.
  if (isLocTableau(prospectiveMove.dest) && moves.size() > 0) {
    if (prospectiveMove.dest == moves.back().from && prospectiveMove.card.num == moves.back().card.num &&
        prospectiveMove.card.hasSuitOfSameColorAs(moves.back().card)) {
      Debug::getDefaultInstance() << "filtering a move: move equivalent card rule" << endl;
      return true;
    }
  }

  // filter 3: don't move the same card twice in a row.
  if (moves.size() > 0 && prospectiveMove.card == moves.back().card) {
    return true;
  }

  return false;
}

bool canPlaceOnTop(const Card& c, const Card& target) {
  return c.num == target.num - 1 &&
  (((c.suit == clubs || c.suit == spades) &&
    (target.suit == hearts || target.suit == diamonds)) ||
   ((c.suit == hearts || c.suit == diamonds) &&
    (target.suit == clubs || target.suit == spades)));
}

// getRandomIndices
template <typename index_type>
void getRandomIndices(index_type indices[], int n) {
  int i, j;
  int* rands = new int[n];
  for (i = 0; i < n; i++) {
    indices[i] = i;
    rands[i] = rand();
  }
  // bubble sort
  for (i = 1; i < n; i++)
    for (j = 0; j < n - i; j++)
      if (rands[indices[j]] > rands[indices[j + 1]]) {
        index_type temp = indices[j];
        indices[j] = indices[j + 1];
        indices[j + 1] = temp;
      }

        delete[] rands;
}

void addState()
{
  FreeCellStates::iterator lookup;
  set<Tableau> tableauSet = game.getTableauSet();
  lookup = fcStates.find(tableauSet);
  if (lookup == fcStates.end())
  {
    pair<set<Tableau>, set<set<Card> > > newPair;
    newPair.first = tableauSet;
    newPair.second.insert(game.getFreeCellSet());
    fcStates.insert(newPair);
  }
  else
  {
    (*lookup).second.insert(game.getFreeCellSet());
  }
}

bool seenCurrentState()
{
  FreeCellStates::iterator lookup;
  set<Tableau> tableauSet = game.getTableauSet();
  lookup = fcStates.find(tableauSet);
  if (lookup == fcStates.end())
    return false;
  else
  {
    set<set<Card> >& seenFreeCells = (*lookup).second;
    if (seenFreeCells.find(game.getFreeCellSet()) == seenFreeCells.end())
      return false;
    else
      return true;
  }
}

// TODO: Integrate optimizations into the core algorithm because optimizations are
// tedious and dangerous (see comment in opt. 1 below).
// Optimize a sequence of moves by removing silly sequences that the solver created.
// Currently, this function works without knowing what's on the tableaus, so it only
// does some simple optimizations that can be applied based on knowledge of just the
// moves.
// Currently, the optimizations are:
// 1) The algorithm may generate the following:
//    - Move a card (T, suit) that is properly stacked on a tableau to a free cell.
//    - Move the other card (T, suit') where suit is the other suit of the same color,
//      which also happens to be on top of another tableau, to the tableau (T, suit) was
//      on.
//    - Move (T, suit) to where (T, suit') was.
//    This can happen if there are no moves of Type 1-4 as described in getPossibleMoves.
//    The solver happens to choose (T, suit), after which is moved to a free cell, allows
//    a type 4 move and then a type 3 move. This is not caught by the state checker
//    because it is technically a different state.
// 2) If a card is moved from a) a tableau to a free cell or b) a tableau to a tableau,
//    and then is moved back to the tableau before the tableau is otherwise modified,
//    that is pointless.
// 3) If a card is moved twice in a row, combine the moves.
//
// Since one of these optimizations can produce an opportunity for another optimization to be
// run again, we loopp through these optimizations until there are no changes.
void optimizeMoves(vector<CardMove>* moveList)
{
  unsigned int move, startingMoveCount;
  bool optimized; 

  Debug::getDefaultInstance() << "Optimizing" << endl;

  do {
#ifdef SOLVEFREECELL_LIB_THREADED
    // heed the request to stop, even when optimizing
    if (stopRequested) {
      break;
    }
#endif

    startingMoveCount = moveList->size();

    // perform optimization 1
    // optimization 1 is BROKEN because it doesn't account for the fact that
    // the 2 cards of same color and rank are different with respect to
    // foundations, so we can't swap the cards for the rest of the game and we can't
    // guarantee that we can just put the original card on the foundation
#if 0
    move = 0;
    while (move < int(moveList->size()) - 2) {
      const CardMove& thisMove = moveList->at(move);
      const CardMove& nextMove = moveList->at(move + 1);
      const CardMove& moveAfterNext = moveList->at(move + 2);
      optimized = false;

      if (isLocTableau(thisMove.from) && thisMove.dest == cell) {
        if (nextMove.dest == thisMove.from &&
            thisMove.card.hasSuitOfSameColorAs(nextMove.card) &&
            thisMove.card.num == nextMove.card.num) {
          if (moveAfterNext.card == thisMove.card && moveAfterNext.dest == nextMove.from) {
            // all conditions are met for optimization 1
            Debug::getDefaultInstance() << "Performing optimization type 1 on move " << move + 1 << endl;
            // erase the moves
            optimized = true;
            Card card1 = thisMove.card;
            Card card2 = nextMove.card;
            int index;
            moveList->erase(moveList->begin() + move, moveList->begin() + move + 3);
            // let's not forget, the state has changed: the cards are swapped from what
            // the solver output for the rest of the game
            for (index = move; index < moveList->size(); index++) {
              // FIX 7/31/04
              if (moveList->at(index).card == card1) {
                moveList->at(index).card = card2;
              }
              else if (moveList->at(index).card == card2) {
                moveList->at(index).card = card1;
              }
            }
          }
        }
      }

      if (!optimized) {
        move++;
      }
    }
    // done optimization 1
#endif

    for (move = 0; move < moveList->size(); move++) {
      const CardMove& thisMove = moveList->at(move);
      if (isLocTableau(thisMove.from) && thisMove.dest != foundation) {
        Card watchCard = thisMove.card;
        // search till when it's moved next, noting if its origin tableau is modified.
        // Also need to be careful if the destination is tableau and it is modified (i.e. another
        // card placed on top -- then we can't optimize
        Location origin = thisMove.from;
        Location otherWatchLocation = thisMove.dest;
        unsigned int index;
        bool done = false;
        bool checkOtherLocation = isLocTableau(otherWatchLocation);
        for (index = move + 1; index < moveList->size() && !done; index++) {
          const CardMove& futureMove = moveList->at(index);
          if (futureMove.card == watchCard) {
            if (futureMove.dest == origin) {
              Debug::getDefaultInstance() << "Performing optimization 2 on move " << move + 1 << endl;
              // the card moves back to its origin before its origin has changed.
              // optimize away the 2 moves
              // NOTE: using the fact that index > move, to erase index first
              moveList->erase(moveList->begin() + index, moveList->begin() + index + 1);
              moveList->erase(moveList->begin() + move, moveList->begin() + move + 1);
            }
            done = true;
          }
          else if (futureMove.from == origin || futureMove.dest == origin) {
            // the tableau changes state, so the move may be necessary
            done = true;
          }
          else if (checkOtherLocation && futureMove.dest == otherWatchLocation) {
            done = true;
          }
          // move is innocuous for the optimization. Continue
        }
      }
    }
    // done optimization 2

    move = 0;
    // optimization 3 is theoretically obsolete with the filter in filterMove
    // careful with unsigned type of size(), don't subtract 1 from it
    while (move + 1 < moveList->size()) {
      if (moveList->at(move).card == moveList->at(move + 1).card) {
        Debug::getDefaultInstance() << "Performing optimization 3 on move " << move + 1 << endl;
        // note that the 2 moves could put the card back to where it started...and it would
        // be nonsensical to have a move's origin and destination be the same
        if (moveList->at(move).from == moveList->at(move + 1).dest) {
          // obliterate both moves
          Debug::getDefaultInstance() << "3a" << endl;
          moveList->erase(moveList->begin() + move, moveList->begin() + move + 2);
        }
        else {
          Debug::getDefaultInstance() << "3b" << endl;
          moveList->at(move).dest = moveList->at(move + 1).dest;
          moveList->erase(moveList->begin() + move + 1, moveList->begin() + move + 2);
          // reexamine the same move because next move might ALSO be this card
        }
      }
      else {
        move++;
      }
    }
    // done optimization 3

  } while (moveList->size() < startingMoveCount);

  Debug::getDefaultInstance() << "Final move count: " << moveList->size() << endl;
}

void setAppend(int appendValue)
{
  append = appendValue;
}

void setLogPath(const char * path)
{
  logPath = path;
}

/* validation */
/* Currently this is only useful if debugging is turned on */
bool validateSolution(const vector<CardMove>& moves, const vector<Tableau>& tableaus)
{
  FreeCellGame game;
  game.setTableaus(tableaus);
  bool valid = true;

  for (unsigned int i = 0; i < moves.size(); i++) {
    if (!game.performMove(moves[i])) {
      const CardMove& theMove = moves[i];
      char *suitname, *fromname, *destname;
      suitString(&suitname, theMove.card.suit);
      locString(&destname, theMove.dest);
      locString(&fromname, theMove.from);

      valid = false;
      Debug::getDefaultInstance() << "Move " << i + 1 << " in the solution is not valid";
      Debug::getDefaultInstance() <<  " (move " << theMove.card.num << " of " << suitname << " from " << fromname << " to " << destname << ")" << endl;
    }
  }
  return valid;
}


/***
debug printing methods
***/

// suitString
// Returns the suit name for a given CardSuit
void suitString(char** suitStr, CardSuit suit) {
  if (suit == clubs) 			*suitStr = "clubs";
  else if (suit == diamonds)  *suitStr = "diamonds";
  else if (suit == hearts) 	*suitStr = "hearts";
  else /* suit == spades */	*suitStr = "spades";
}

// Returns the location name for a given location
void locString(char** locStrPtr, Location loc) {
  if (loc == cell) 				*locStrPtr = "a free cell";
  else if (loc == foundation) 	*locStrPtr = "foundation";
  else if (loc == tableau1) 		*locStrPtr = "tableau 1";
  else if (loc == tableau2)		*locStrPtr = "tableau 2";
  else if (loc == tableau3)		*locStrPtr = "tableau 3";
  else if (loc == tableau4)		*locStrPtr = "tableau 4";
  else if (loc == tableau5)		*locStrPtr = "tableau 5";
  else if (loc == tableau6)		*locStrPtr = "tableau 6";
  else if (loc == tableau7)		*locStrPtr = "tableau 7";
  else if (loc == tableau8) 	*locStrPtr = "tableau 8";
}

void requestStopForSolverThread() {
#ifdef SOLVEFREECELL_LIB_THREADED
  stopRequested = true;
#endif
}

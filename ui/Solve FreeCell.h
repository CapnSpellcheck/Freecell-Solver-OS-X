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

#ifndef __SOLVE_FREECELL_H__
#define __SOLVE_FREECELL_H__

// C++ Includes
#include <vector>
#include <iostream>
#include <fstream>
#include <map>
#include <set>
#include <string>
#include <queue>
#include <functional>

// C includes
#include <assert.h>
#include <stdlib.h>
#include <ctype.h>

// Project includes
#include "Tableau.h"
#include "CardMove.h"
#include "Debug.h"
#include "FreeCells.h"
#include "MoveScorePair.h"

using std::set;
using std::vector;
using std::map;
using std::priority_queue;
using std::less;

///////////////////////////////////////////////////////////////////////////////
// constants

enum {
		kFoundationFull = 13,
		kNumTableaus = 8,
		kMaxMovesBetweenFoundationMoves = 20
};

const int INDEX_TO_CHANGE_FROM_NEWLINE_TO_SPACE_FROM_CTIME = 24;
const int LOG_MODE_APPEND = 0; // TODO: unify with FCSLogModeAppend


///////////////////////////////////////////////////////////////////////////////
// Types
// The state of a FreeCell game can be completely defined by the cards on the
// eight tableaus, and the cards in the free cells.
// We organize this information by maintaining a function
// f(tableau description) => { all sets of cards that have been in the free cells }
typedef map<set<Tableau>, set< set<Card> > > FreeCellStates;


///////////////////////////////////////////////////////////////////////////////
// prototypes
void solveFreeCell(vector<CardMove>* moveList, const vector<Tableau>& passedTableaus);
void solveFCRec(vector<CardMove>* moveList, unsigned short myCount = 0);

priority_queue<MoveScorePair> getPossibleMoves();
void makeMove(vector<CardMove>* moves, const CardMove& move);
void undoMove(vector<CardMove>* moves, const CardMove& move);
bool filterMove(const vector<CardMove>& moves, const CardMove& prospectiveMove);

inline unsigned short locToTableau(Location loc)
{
  return loc - tableau1;
}
inline Location tableauToLoc(unsigned short tNum) {
  //assert(tNum <= kNumTableaus);
  return static_cast<Location>(tableau1 + tNum);
}
inline bool isLocTableau(Location loc)
{
  return loc >= tableau1 && loc <= tableau8;
}

bool canPlaceOnTop(const Card& toBeOnTop, const Card& target);
template<typename index_type> void getRandomIndices(index_type indices[], int n);

void addState();
bool seenCurrentState();

void optimizeMoves(vector<CardMove>* moveList);

void setAppend(int appendValue);
void setLogPath(const char * path);

bool validateSolution(const vector<CardMove>& moves, const vector<Tableau>& tableaus);

void suitString(char** suitStr, CardSuit suit);
void locString(char** locStrPtr, Location loc);

#ifdef SOLVEFREECELL_LIB_THREADED
void requestStopForSolverThread();
#endif

#endif

/*
 *  FreeCellGame.h
 *  FreeCell Solver
 *
 *  Created by Julian on Fri Jul 30 2004.
 *  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
 *
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
#ifndef __FRECELLGAME_H__
#define __FRECELLGAME_H__

#include <vector>
#include <set>
#include <stdlib.h>
#include "Tableau.h"
#include "CardMove.h"
#include "FreeCells.h"
#include "Card.h"
#include "Location.h"

const int NUM_TABLEAUS = 8;
const int NUM_FREE_CELLS = 4;
const int NUM_FOUNDATIONS = 4;
const int NUM_CARDS = 52;
const int NUM_SUITS = 4;
const int HIGHEST_RANK = 13;
const int NUM_RANKS = 13;
const int MAX_CARDS_PER_TABLEAU = 7;

class FreeCellGame {
public:
  FreeCellGame();
  void setTableaus(const std::vector<Tableau>& tableaus);
  // return true if the move is valid for the current state; false otherwise; always "performs" the move.
  bool performMove(const CardMove& move);
  // undoes the move without checking if the reverse move is valid, since it
  // won't necessarily be.
  void undoMove(const CardMove& move);
  void reset();

  std::set<Tableau> getTableauSet();
  const std::vector<Tableau>& getTableaus();
  std::set<Card> getFreeCellSet();
  const FreeCells& getFreeCells();

  std::set<Location> getPreferredMoveOrigins();
  std::set<Location> getPreferredMoveDestinations();
  int depthOfNextFoundationCardForTableau(int tableau);

  bool gameIsSolved();

  unsigned char nextFoundationRankForSuit(CardSuit suit);

  // a class utility method available to the public, to get a random game setup.
  static void getRandomSetup(std::vector<Tableau>* setup);
  static void finishSetupRandomly(std::vector<Tableau>* setup);

private:
  // methods

  // data
  FreeCells freeCells;
  std::vector<Tableau> tableaus;
  // the ranks of the top cards on the foundations, ordered by the suits in
  // enum CardSuit
  unsigned char foundationRanks[NUM_FOUNDATIONS];
  // keep some statistics about the game that will help us determine the
  // better moves; try to think like a human player would think
  // maintain the Location for each card
  Location locationsByCard[NUM_SUITS][HIGHEST_RANK + 1]; // overallocated ranks by 1, don't use index 0

  // the next 2 arrays use -1 to indicate the card is not on a tableau.
  int tableauIndicesForNextCardInSuit[NUM_SUITS];
  int depthsForNextCardInSuit[NUM_SUITS]; // top card has depth zero
  
};

inline const FreeCells& FreeCellGame::getFreeCells()
{
  return freeCells;
}

inline unsigned char FreeCellGame::nextFoundationRankForSuit(CardSuit suit)
{
  return foundationRanks[suit] + 1;
}

inline std::set<Tableau> FreeCellGame::getTableauSet()
{
  return std::set<Tableau>(tableaus.begin(), tableaus.end());
}

inline const std::vector<Tableau>& FreeCellGame::getTableaus()
{
  return tableaus;
}

inline std::set<Card> FreeCellGame::getFreeCellSet()
{
  return freeCells.asSet();
}

inline int randInRange(int min, int max)
{
  return min + int((max - min + 1.0) * rand() / (RAND_MAX + 1.0));
}

#endif

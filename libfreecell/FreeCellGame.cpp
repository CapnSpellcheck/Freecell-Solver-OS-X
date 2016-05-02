/*
 *  FreeCellGame.cpp
 *  FreeCell Solver
 *
 *  Created by Julian on Fri Jul 30 2004.
 *  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
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
 
 *
 */

#include "FreeCellGame.h"
#include "Solve FreeCell.h"
#include <iostream>
#include <string>
#include <assert.h>

using namespace std;

FreeCellGame::FreeCellGame()
{
  reset(); // reset the instance
}

/**
 * As well as copying the tableaus, setTableaus calculates the initial state
 * information that can be applied towards selecting good moves.
 * setTableaus must be called before calling performMove
 **/
void FreeCellGame::setTableaus(const vector<Tableau>& tableaus)
{
  size_t i, j;

  this->tableaus = tableaus;

  // now scan the tableaus, setting the location for each card
  for (i = 0; i < tableaus.size(); i++) {
    const Tableau& tableau = tableaus[i];
    for (j = 0; j < tableau.size(); j++) {
      const Card& card = tableau.peek(j);
      locationsByCard[card.suit][card.num] = tableauToLoc(i);
    }
  }

}

bool FreeCellGame::performMove(const CardMove& theMove)
{
  Debug& debugger = Debug::getDefaultInstance();
  bool validMove;
  string debugMessage;

  if (theMove.from >= tableau1) {
    if (theMove.dest == foundation) {
      // move from tableau to foundation
      validMove = (tableaus[locToTableau(theMove.from)].size() > 0 &&
                   foundationRanks[theMove.card.suit] == theMove.card.num - 1);
      if (!validMove) {
        debugMessage = "Invalid move (tableau => foundation): ";
        if (tableaus[locToTableau(theMove.from)].size() == 0)
          debugMessage += "tried to move a card from a tableau that was empty";
        else
          debugMessage += "tried to move a card to foundation that wasn't the required card";
      }
      foundationRanks[theMove.card.suit]++;
      tableaus[locToTableau(theMove.from)].removeTop();
    }
    else if (theMove.dest >= tableau1) {
      validMove = (tableaus[locToTableau(theMove.from)].size() > 0 &&
                   (tableaus[locToTableau(theMove.dest)].size() == 0 ||
                    canPlaceOnTop(theMove.card, tableaus[locToTableau(theMove.dest)].top()) ));
      if (!validMove) {
        debugMessage = "Invalid move (tableau => tableau): ";
        if (tableaus[locToTableau(theMove.from)].size() == 0)
          debugMessage += "tried to move a card from a tableau that was empty";
        else
          debugMessage += "tried to move a card on top of a card that it can't be placed on";
      }
      tableaus[locToTableau(theMove.dest)].place(theMove.card);
      tableaus[locToTableau(theMove.from)].removeTop();
    }
    else { // tableau =>free cell
      validMove = (tableaus[locToTableau(theMove.from)].size() > 0 && freeCells.countUsedCells() < NUM_FREE_CELLS);
      if (!validMove) {
        debugMessage = "Invalid move (tableau => cell): ";
        if (tableaus[locToTableau(theMove.from)].size() == 0)
          debugMessage += "tried to move a card from a tableau that was empty";
        else
          debugMessage += "tried to move a card to a free cell when all cells were full";
      }
      freeCells.add(theMove.card);
      tableaus[locToTableau(theMove.from)].removeTop();
    }
  }
  // theMove.from == cell
  else if (theMove.dest >= tableau1) {
    bool cellsHadCard = freeCells.remove(theMove.card);
    validMove = (cellsHadCard &&
                 ( tableaus[locToTableau(theMove.dest)].size() == 0 ||
                   canPlaceOnTop(theMove.card, tableaus[locToTableau(theMove.dest)].top()) ));
    if (!validMove) {
      debugMessage = "Invalid move (cell => tableau): ";
      if (!cellsHadCard)
        debugMessage += "Tried to move a card from a free cell when that card wasn't there";
      else
        debugMessage += "tried to move a card on top of a card that it can't be placed on";
    }
    tableaus[locToTableau(theMove.dest)].place(theMove.card);
  }
  else { // (theMove.dest == foundation)
    bool cellsHadCard = freeCells.remove(theMove.card);
    validMove = (cellsHadCard && foundationRanks[theMove.card.suit] == theMove.card.num - 1);
    if (!validMove) {
      debugMessage = "Invalid move (cell => foundation): ";
      if (!cellsHadCard)
        debugMessage += "Tried to move a card from a free cell when that card wasn't there";
      else
        debugMessage += "tried to move a card to foundation that wasn't the required card";
    }
    foundationRanks[theMove.card.suit]++;
  }
  if (!validMove) {
    debugger << debugMessage << endl;
  }

  // update the location for the moved card
  locationsByCard[theMove.card.suit][theMove.card.num] = theMove.dest;

  // log relevant message for move
  if (debugger.isEnabled()) {
    char *suitname, *fromname, *destname;
    suitString(&suitname, theMove.card.suit);
    locString(&destname, theMove.dest);
    locString(&fromname, theMove.from);
    debugger << "Moved the " << theMove.card.num << " of "
      << suitname << " from " << fromname << " to " << destname << endl;
    if (theMove.dest == foundation)
      debugger << "Moving to foundation, now "
        << foundationRanks[clubs] + foundationRanks[hearts] + foundationRanks[diamonds] + foundationRanks[spades]
        << " cards on foundations" << endl;
  }

  // done
  return validMove;
}

void FreeCellGame::undoMove(const CardMove& theMove)
{
  if (Debug::getDefaultInstance().isEnabled()) {
    char *suitname, *fromname, *destname;
    suitString(&suitname, theMove.card.suit);
    locString(&destname, theMove.dest);
    locString(&fromname, theMove.from);
    Debug::getDefaultInstance() << "Unmoved the " << theMove.card.num << " of "
      << suitname << " from " << destname << " back to " << fromname << endl;
  }

  if (theMove.from >= tableau1) {
    if (theMove.dest == foundation) {
      foundationRanks[theMove.card.suit]--;
      tableaus[locToTableau(theMove.from)].place(theMove.card);
    }
    else if (theMove.dest >= tableau1) {
      tableaus[locToTableau(theMove.dest)].removeTop();
      tableaus[locToTableau(theMove.from)].place(theMove.card);
    }
    else { // undo tableau => free cell
      freeCells.remove(theMove.card);
      tableaus[locToTableau(theMove.from)].place(theMove.card);
    }
  }
  // undo cell => tableau
  else if (theMove.dest >= tableau1) {
    tableaus[locToTableau(theMove.dest)].removeTop();
    freeCells.add(theMove.card);
  }
  else { // undo cell => foundation
    foundationRanks[theMove.card.suit]--;
    freeCells.add(theMove.card);
  }

  // update the location for the unmoved card
  locationsByCard[theMove.card.suit][theMove.card.num] = theMove.from;
}

// check to see if all the foundations have the highest card (king)
bool FreeCellGame::gameIsSolved()
{
  return foundationRanks[clubs] == kFoundationFull &&
  foundationRanks[diamonds] == kFoundationFull &&
  foundationRanks[hearts]   == kFoundationFull &&
  foundationRanks[spades]   == kFoundationFull;
}

// update the elements in tableauIndicesForNextCardInSuit and
// depthsForNextCardInSuit for a given suit.
/*
 void FreeCellGame::updateDataForSuit(CardSuit suit)
 {
   // preset it to a non-tableau location
   tableauIndicesForNextCardInSuit[suit] = -1;
   depthsForNextCardInSuit[suit] = -1;

   int i, j;
   for (i = 0; i < tableaus.size(); i++) {
     const Tableau& tableau = tableaus[i];
     for (j = 0; j < tableau.size(); j++) {
       const Card& card = tableau.peek(j);
       // if the card's rank matches what goes next on its suit's foundation
       if (suit == card.suit && card.num == foundationRanks[suit] + 1) {
         tableauIndicesForNextCardInSuit[suit] = i;
         // the highest index is the top card of the tableau
         depthsForNextCardInSuit[suit] = tableau.size() - j - 1;
       }
     }
   }
 }
 */

void FreeCellGame::reset()
{
  int i, j;
  for (i = 0; i < NUM_FOUNDATIONS; i++) {
    foundationRanks[i] = 0;
  }
  freeCells.clear();
  tableaus.clear();
  for (i = 0; i < NUM_FOUNDATIONS; i++) {
    tableauIndicesForNextCardInSuit[i] = -1;
    depthsForNextCardInSuit[i] = -1;
  }
  for (i = 0; i < NUM_SUITS; i++) {
    for (j = 0; j < HIGHEST_RANK; j++) {
      // default the location to somewhere not in the game
      locationsByCard[i][j] = deck;
    }
  }
}

/**
 * Give hints as to where better moves might come from.
 **/
set<Location> FreeCellGame::getPreferredMoveOrigins()
{
  size_t i;
  set<Location> origins;
  for (i = 0; i < NUM_SUITS; i++) {
    if (foundationRanks[i] < HIGHEST_RANK) { // remember rank = 1..13
      Location loc = locationsByCard[i][foundationRanks[i] + 1];
      origins.insert(loc);
    }
  }
  return origins;
}

set<Location> FreeCellGame::getPreferredMoveDestinations()
{
  size_t i;
  static set<Location>* tableauDestinations = NULL;
  if (tableauDestinations == NULL) {
    tableauDestinations = new set<Location>;
    for (i = 0; i < NUM_TABLEAUS; i++) {
      tableauDestinations->insert(tableauToLoc(i));
    }
  }

  set<Location> destinations = *tableauDestinations;
  for (i = 0; i < NUM_SUITS; i++) {
    destinations.erase(locationsByCard[i][foundationRanks[i] + 1]);
  }
  return destinations;
}

/**
 * Destroys contents of *setup and places a new random setup there.
 **/
void FreeCellGame::getRandomSetup(vector<Tableau>* setup)
{
  vector<Card> cards;
  int i, j, randCard;
  unsigned int cardsPerTableau;
  const CardSuit suits[] = {clubs, diamonds, hearts, spades};

  setup->clear();
  setup->resize(NUM_TABLEAUS);

  // add all cards to the cards vector
  for (i = 0; i < NUM_SUITS; i++) {
    for (j = 0; j < HIGHEST_RANK; j++) {
      Card card;
      card.num = j + 1;
      card.suit = suits[i];
      cards.push_back(card);
    }
  }

  // go through the tableaus 
  // randomly pick a card from the cards vector and add it to the tableau
  // until all cards have been picked.
  cardsPerTableau = 7;
  for (i = 0; i < NUM_TABLEAUS; i++) {
    if (i == 4) {
      cardsPerTableau = 6;
    }
    for (j = 0; j < cardsPerTableau; j++) {
      randCard = randInRange(0, cards.size() - 1);
      setup->at(i).place(cards[randCard]);
      cards.erase(cards.begin() + randCard, cards.begin() + randCard + 1);
    }
  }
  // make sure there are no extra cards
  assert(cards.size() == 0);
}


void FreeCellGame::finishSetupRandomly(vector<Tableau>* setup)
{
  vector<Card> unusedCards;
  bool hasCards[NUM_SUITS][NUM_RANKS] = {false};
  int fullTableaus = 0, cardsPerTableau, randCard, i, j, rank, suit;
  Card unusedCard;
  
  if (setup->size() != NUM_TABLEAUS) {
    return;
  }
  
  for (i = 0; i < NUM_TABLEAUS; i++) {
    if (setup->at(i).size() == MAX_CARDS_PER_TABLEAU) {
      fullTableaus++;
    }
    for (j = 0; j < setup->at(i).size(); j++) {
      Card card = setup->at(i).peek(j);
      hasCards[card.suit][card.num - 1] = true;
    }
  }
  for (suit = 0; suit < NUM_SUITS; suit++) {
    for (rank = 0; rank < NUM_RANKS; rank++) {
      if (!hasCards[suit][rank]) {
        unusedCard.num = rank + 1;
        unusedCard.suit = (CardSuit)suit;
        unusedCards.push_back(unusedCard);
      }
    }
  }
  
  cardsPerTableau = (fullTableaus < 4 ? MAX_CARDS_PER_TABLEAU : MAX_CARDS_PER_TABLEAU - 1);  
  for (i = 0; i < NUM_TABLEAUS; i++) {
    if (setup->at(i).size() == cardsPerTableau) {
      continue;
    }
    while (setup->at(i).size() < cardsPerTableau) {
      randCard = randInRange(0, unusedCards.size() - 1);
      setup->at(i).place(unusedCards[randCard]);
      unusedCards.erase(unusedCards.begin() + randCard, unusedCards.begin() + randCard + 1);
    }
    fullTableaus++;
    if (fullTableaus == 4) {
      cardsPerTableau = 6;
    }
  }
  assert(unusedCards.empty());
}

/**
 * Let {C, D, H, S} be the set of cards, one from each suit (clubs, diamonds, hearts, spades respectively),
 * that are the next cards required on foundation for each suit. Then this method returns the depth of the topmost
 * card of that set on tableau tableauIndex, or -1 if no card from that set is on that tableau.
 **/
int FreeCellGame::depthOfNextFoundationCardForTableau(int tableauIndex)
{
  int i;
  for (i = tableaus[tableauIndex].size() - 1; i >= 0; i--) {
    const Card& card = tableaus[tableauIndex].peek(i);
    if (card.num == foundationRanks[card.suit] + 1) {
      return tableaus[tableauIndex].size() - i - 1;
    }
  }
  return -1;
}

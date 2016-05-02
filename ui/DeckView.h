//
//  DeckView.h
//  FreeCell Solver
//
//  Created by Julian on Sat Jul 03 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//
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

#import <AppKit/AppKit.h>
#import "CardManager.h"
#include "CardSuit.h"

const CardSuit deckOrder[NUM_SUITS] = {clubs, spades, hearts, diamonds};
const int FCSDeckVerticalMargin = 20;
const int FCSDeckVerticalSpaceBetweenSuits = 20;
const int FCSDeckHorizontalMargin = 20;

@class AppController;

@interface DeckView : NSView {
  IBOutlet AppController* appController;
  
  // the array of card flags is stored in the suit order given above
  BOOL hasCards[NUM_CARDS];
  // the card that has been clicked on and should be shown frontmost
  // it is also the one that is being dragged, if a drag is occurring.
  int frontCardIndex;
  // flag that indicates whether to highlight the deck view for a drag receipt
  BOOL highlightView;
}

- (BOOL) hasCardWithRank: (unsigned int) rank suit: (CardSuit) suit;
- (int) cardIndexForPoint: (NSPoint) point;
- (CardSuit) suitForIndex: (int) index;
- (NSPoint) pointForCardWithRank: (unsigned int) rank suit: (CardSuit) suit;
- (NSRect) rectForCardWithRank: (unsigned int) rank suit: (CardSuit) suit;
- (int) rowForSuit: (CardSuit) suit;
- (void) resetDeck; // gives self a full deck
- (void) emptyDeck; // removes all cards from self
- (BOOL) addCardWithRank: (unsigned int) rank suit: (CardSuit) suit;
- (BOOL) removeCardWithRank: (unsigned int) rank suit: (CardSuit) suit;


@end

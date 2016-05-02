//
//  CardManager.m
//  FreeCell Solver
//
//  Created by Julian on Fri Jul 02 2004.
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

#import "CardManager.h"
#include "Card.h"

@implementation CardManager

- (id) init
{
  unsigned int suit;
  unsigned int rank;
  int imagesIndex = 0;

  // load the images and store them in the images array
  for (suit = 0; suit < NUM_SUITS; suit++) {
    for (rank = 1; rank <= NUM_RANKS; rank++) {
      Card card;
      card.suit = (CardSuit) suit;
      NSString* cardName = [NSString stringWithFormat: @"card_%hu%c.gif", rank, tolower(card.suitChar())];
      NSImage* image = [NSImage imageNamed: cardName];
      if (image == nil) {
        NSRunAlertPanel(@"Image missing", @"The image for the card '%@' is missing from the application. You may have tampered with my contents. Please don't do that.", @"OK", nil, nil, cardName);
      }
      [image setFlipped: YES];
      images[imagesIndex] = image;
      imagesIndex++;
    }
  }
  return self;
}
      
+ (CardManager*) defaultManager
{
  static CardManager* cachedManager = nil;

  if (cachedManager == nil) {
    cachedManager = [[CardManager alloc] init];
  }
  return cachedManager;
}

- (NSImage*) imageForCardWithRank: (unsigned int) rank suit: (CardSuit) suit
{
  NSImage* image;
  rank = rank - 1; // move rank from 1-based to 0-based
  switch (suit) {
    case clubs:
      image = images[rank];
      break;
      
    case diamonds:
      image = images[NUM_RANKS + rank];
      break;
      
    case hearts:
      image = images[NUM_RANKS * 2 + rank];
      break;
      
    case spades:
      image = images[NUM_RANKS * 3 + rank];
  }
  return image;
}

- (void) setDraggedCard: (Card) card
{
  draggedCard = card;
}

- (Card) draggedCard
{
  return draggedCard;
}


@end

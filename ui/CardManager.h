//
//  CardManager.h
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

#import <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include "CardSuit.h"
#include "Card.h"
#include "FreeCellGame.h"


@interface CardManager : NSObject {
  NSImage* images[NUM_CARDS];
  Card draggedCard;
}

+ (CardManager*) defaultManager;
- (NSImage*) imageForCardWithRank: (unsigned int) rank suit: (CardSuit) suit;

- (void) setDraggedCard: (Card) card;
- (Card) draggedCard;

@end

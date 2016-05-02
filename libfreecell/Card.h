// Card.h
// Represent a playing card, which consists of a suit and number.
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

#ifndef CARD_H
#define CARD_H

#include "CardSuit.h"

struct Card {
  // why I named this num instead of rank I have no idea.
	unsigned short num; 	// Jack = 11, Queen = 12, King = 13, Ace = 1
	CardSuit suit;
	bool operator == (const Card& c) const {
		return num == c.num && suit == c.suit;
	}
	bool operator < (const Card& c) const {
		return num < c.num || (num == c.num && suit < c.suit);
	}
  char suitChar() const {
    char theChar;
    switch (suit) {
      case clubs:
        theChar = 'C';
        break;
      case diamonds:
        theChar = 'D';
        break;
      case hearts:
        theChar = 'H';
        break;
      case spades:
        theChar = 'S';
        break;
    }
    return theChar;
  }
  bool hasSuitOfSameColorAs(const Card& c) const {
		return ((suit == clubs || suit == spades) && (c.suit == clubs || c.suit == spades))
				 ||
				 ((suit == hearts || suit == diamonds) && (c.suit == hearts || c.suit == diamonds));
	}
  Card() { num = 0;}
};

#endif // CARD_H
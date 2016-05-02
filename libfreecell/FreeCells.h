// FreeCells.h
// Abstracts the free cells in FreeCell.

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


#ifndef FREECELLS_H
#define FREECELLS_H

#include <set>
#include "Card.h"

class FreeCells {
public:
  FreeCells() {
    count = 0;
  }
	unsigned short countUsedCells() const {
		return count;
	}
	bool remove(Card const& card);
	bool add(Card const& card);
	Card get(unsigned char n) const;
	std::set<Card> asSet() const;
  void clear();

private:
	Card freeCellCards[4];
	unsigned short count;
};

inline void FreeCells::clear()
{
  count = 0;
}

#endif // FREECELLS_H

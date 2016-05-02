// FreeCells.cpp
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

#include "FreeCells.h"
#include <assert.h>
#include <set>

using std::set;

bool FreeCells::remove(Card const& card) 
{
	for (unsigned short i = 0; i < count; i++) {
		if (card == freeCellCards[i]) {
			for (unsigned short j = i + 1; j < count; j++) {
				freeCellCards[j - 1] = freeCellCards[j];
			}
			count--;
			return true;
		}
	}
	return false;
}

bool FreeCells::add(Card const& card) 
{
	if (count < 4) {
		freeCellCards[count++] = card;
		return true;
	}
	return false;
}

Card FreeCells::get(unsigned char n) const 
{
	assert(count >= n);
	return freeCellCards[n];
}

set<Card> FreeCells::asSet() const
{
	set<Card> theSet;
	for (int i = 0; i < count; i++)
	{
		theSet.insert(freeCellCards[i]);
	}
	return theSet;
}

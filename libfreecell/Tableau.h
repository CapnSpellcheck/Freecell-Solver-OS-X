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

/*
 * Representation of Tableau object in solitaire game.
 * A tableau is a pile of cards that is accessible only at the top.
 */
 #ifndef __TABLEAU_H__
 #define __TABLEAU_H__
 
 #include <vector>
 #include "Card.h"
 
 class Tableau : private std::vector<Card>
 {
 public:
 	// creation and destruction
 	Tableau();
 	~Tableau();
 	
 	// accessing, placing and removing
 	bool empty() const;
 	const Card& peek(size_type index) const;
 	const Card& top() const;
 	Card removeTop();
  void removeAll();
  size_type size() const
 	{
 		return std::vector<Card>::size();
 	}
 	void place(const Card& c);

 	// Comparison operations for set management and ordering
 	bool operator < (const Tableau& rhs) const;
 	bool operator == (const Tableau& rhs) const;
 };
 
 inline Tableau::Tableau()
 {
 }
 
 inline Tableau::~Tableau()
 {
 }
 
 inline bool Tableau::empty() const
 {
 	return std::vector<Card>::empty();
 }
 
 inline const Card& Tableau::peek(size_type index) const
 {
 	return at(index);
 }
 
 // beware calling on an empty tableau
 inline const Card& Tableau::top() const
 {
 	return back();
 }
 
 // beware calling on an empty tableau
 inline Card Tableau::removeTop()
 {
 	Card ret = back();
 	pop_back();
 	return ret;
 }
 
 inline void Tableau::removeAll()
 {
   clear();
 }

 inline void Tableau::place(const Card& c)
 {
 	push_back(c);
 }
 
 
 #endif // __TABLEAU_H__
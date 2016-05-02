/*
 *  MoveScorePair.h
 *  FreeCell Solver
 *
 *  Created by Julian on Sat Aug 14 2004.
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
// 8/21/04 Changed the score to long so it could be negative.

#ifndef __MOVESCOREPAIR_H__
#define __MOVESCOREPAIR_H__

#include <utility>
#include "CardMove.h"

using std::pair;

class MoveScorePair : public pair<CardMove, long>
{
public:
  MoveScorePair(const CardMove& move, long score);
  
  bool operator <(const MoveScorePair& rt) const;
  bool operator >(const MoveScorePair& rt) const;
  CardMove move() const;
  long score() const;
};

inline MoveScorePair::MoveScorePair(const CardMove& move, long score)
: pair<CardMove, long>(move, score)
{
}

inline CardMove MoveScorePair::move() const
{
  return first;
}

inline long MoveScorePair::score() const
{
  return second;
}

inline bool MoveScorePair::operator <(const MoveScorePair& rt) const
{
  return score() < rt.score();
}

inline bool MoveScorePair::operator >(const MoveScorePair& rt) const
{
  return score() > rt.score();
}

#endif
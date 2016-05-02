//
//  SolveTask.mm
//  FreeCell Solver
//
//  Created by Julian on Sun Jul 11 2004.
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


#import "SolveTask.h"
#include "Solve FreeCell.h"

// This class runs the Solve FreeCell library in a thread.

@implementation SolveTask

- (id) init
{
  tableaus = NULL;
  solution = NULL;
  return self;
}

- (void) setTableauPointer: (vector<Tableau>*) tableauPtr
{
  tableaus = tableauPtr;
}

- (void) setSolutionPointer: (vector<CardMove>*) solutionPtr
{
  solution = solutionPtr;
}

- (void) solveFreeCellGame: (id) uselessObject
{
  solveFreeCell(solution, *tableaus);
}


@end

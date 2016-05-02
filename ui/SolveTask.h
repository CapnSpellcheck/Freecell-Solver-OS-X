//
//  SolveTask.h
//  FreeCell Solver
//
//  Created by Julian on Sun Jul 11 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
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

// This class has a selector that runs the Solve FreeCell library.

#include <vector>
#include "Tableau.h"
#include "CardMove.h"
using std::vector;

#import <Foundation/Foundation.h>


@interface SolveTask : NSObject {
  vector<Tableau>* tableaus;
  vector<CardMove>* solution;
}

- (void) setTableauPointer: (vector<Tableau>*) tableauPtr;
- (void) setSolutionPointer: (vector<CardMove>*) solutionPtr;
- (void) solveFreeCellGame: (id) uselessObject;


@end

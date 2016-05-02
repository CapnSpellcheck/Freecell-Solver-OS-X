/*
 *  FreeCell Solver
 *
 *  Created by Julian on Tue Jun 29 2004.
 *  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
 *
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

#include <vector>
#include <Foundation/NSString.h>
#include "Tableau.h"
#import <CoreFoundation/CFXMLParser.h>

using std::vector;

extern unsigned long FCSCreatorCode;
extern unsigned long FCSFileTypeCode;

enum FCSLoadSetupReturnValue {
  FCSLoadInvalidArchivedObject,
  FCSLoadInvalidCard,
  FCSLoadSucceeded
};

// I wrote this class in C++, but then figured I'd use the Cocoa API to handle the files. Oh well.
class FCSFileHandler
{
public:
  static FCSLoadSetupReturnValue loadSetupFromFile(NSString * path, vector<Tableau> * gameSetup);
  static bool saveSetupToFile(NSString * path, const vector<Tableau>& gameSetup);

};


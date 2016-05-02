// Tableau.cpp
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

#include "Tableau.h"
#include <iostream>

using namespace std;

bool Tableau::operator < (const Tableau& rhs) const
{
    if (size() < rhs.size())
        return true;
    else if (size() > rhs.size())
        return false;
    if (rhs.empty()) {
        return false;
    }
    return top() < rhs.top();
}

bool Tableau::operator == (const Tableau& rhs) const
{
    return size() == rhs.size() && top() == rhs.top();
}
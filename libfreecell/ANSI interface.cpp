
// ANSI interface.cpp
// Provides an ANSI C++ console front end for Solve FreeCell

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

///////////////////////////////////////////////////////////////////////////////
// C++ Includes
#include <vector>
#include <iostream>

// C includes
#include <assert.h>
#include <stdlib.h>
#include <ctype.h>
#include <time.h>

// Project includes
#include "Card.h"
#include "CardMove.h"
#include "CardSuit.h"
#include "Location.h"
#include "Tableau.h"
#include "Solve FreeCell.h"
#include "ANSI Interface.h"

using namespace std;

extern void solveFreeCell(vector<CardMove>* moveList);
extern void optimizeMoves(vector<CardMove>* moveList);

///////////////////////////////////////////////////////////////////////////////
// Implementations

// main
// The following options are available as arguments:
// - None: The program expects to receive the tableau definitions on stdin.
// - 8: The program expects the arguments to be the tableau definitions.

// A tableau is represented
// by listing card descriptions with no spaces in between. A card description
// is the number of the card (1-13, 1=ace, 11=jack etc) followed immediately
// by a letter {c, d, h, s} representing the suit. For example,
// "1d5h13s8d9c2s6c" is a 7-card tableau.
// Main receives the input, solves the problem, and prints a solution
// to the console.
int main(int argc, char** argv) {
	int i;
  vector<Tableau> tableaus;
  
	tableaus.resize(kNumTableaus);

  setAppend(1); // I really have to fix the constants here...what's a good way to share it
                // between back and front ends?
  Debug::getDefaultInstance().enable();
  setLogPath("SolveFreeCell log.txt");

	if (argc == 1) {
	string inputTableau;
    // read from stdin
    // if there are fewer than eight tokens, we notify the user and abort.
    // if there are more than eight, the rest are ignored.
    for (i = 0; i < kNumTableaus; i++) {
      cin >> inputTableau;
      cout << "tableau is " << inputTableau << "\n";
      if (cin.fail()) {
      	cerr << "Not enough tableau descriptions were sent to standard input." << endl;
      	return 1;
      }
      parseTableau(inputTableau.c_str(), &tableaus[i]);
    }
  }
	else if (argc == 9) {
		for (i = 1; i < argc; i++) {
			parseTableau(argv[i], &tableaus[i - 1]);
		}
	}
	else {
		cerr << "Invalid number of arguments. Specify 0 or 8 arguments." << endl;
		return 1;
	}
	
	srand(time(0));				// seed for pseudorandom numbers
  // print the initital state of the game
	for (short i = 0; i < 8; i++) {
		printTableau(tableaus[i]);
	}
	
	vector<CardMove> soln;
	soln.reserve(200);
	solveFreeCell(&soln, tableaus);		// solve FreeCell game
	printSolution(soln);		// print solution

	return 0;
}


// parseTableau
// cardDescriptions: a C-style string. The front of the string represents
// the bottom of the tableau. 
// t: a pointer to the tableau that cardDescriptions represents
// on exit, *t is a tableau with the cards described
// No error checking to ensure cardDescriptions or t are non-null
void parseTableau(const char* cardDescriptions, Tableau* t) {
	unsigned char suitChar, lengthOfNum;
	Card card;
	do {
		// atoi correctly returns the number even when non-digits follow
		card.num = atoi(cardDescriptions);
		// Need to determine location of the suit character; card number is
		// 1 *or* 2 characters.
		lengthOfNum = 1 + (card.num > 9 ? 1 : 0);
		suitChar = *(cardDescriptions + lengthOfNum);
		switch (toupper(suitChar)) {
			case 'C':
				card.suit = clubs;
				break;
			case 'D':
				card.suit = diamonds;
				break;
			case 'H':
				card.suit = hearts;
				break;
			case 'S':
				card.suit = spades;
				break;
			default:
				exit(1);
				break;
		}
		t->place(card);			// copies the card to the tableau
		cardDescriptions += 1 + lengthOfNum; // advances the ptr on the string
	} while (*cardDescriptions != '\0');
}


// printTableau
void printTableau(const Tableau& t) {
	for (int i = 0; i < t.size(); i++) {
		cout << (int) t.peek(i).num << " of ";
		switch (t.peek(i).suit) {
			case clubs:
				cout << "clubs\n";
				break;
			case diamonds:
				cout << "diamonds\n";
				break;
			case hearts:
				cout << "hearts\n";
				break;
			case spades:
				cout << "spades\n";
				break;
		}
	}
	cout << endl;
}


// printSolution
// prints out the moves the algorithm came up with to solve the problem
// instance to the standard output stream
// soln: pointer to a vector of card moves
void printSolution(const vector<CardMove>& soln) {
	size_t index;
	for (index = 0; index < soln.size(); index++) {
		CardMove const& move = soln[index];
    char *suitName, *destName, *fromName;
		
		suitString(&suitName, move.card.suit);
		locString(&destName, move.dest);
    locString(&fromName, move.from);
		
		// for each move, print out a string like:
		// "Move the 8 of spades to tableau 2."
		cout << "Move the ";
		switch (move.card.num) {
			case 1:
				cout << "ace";
				break;
			case 11:
				cout << "jack";
				break;
			case 12:
				cout << "queen";
				break;
			case 13:
				cout << "king";
				break;
			default:
				cout << move.card.num;
				break;
		}
		cout << " of " << suitName << " from " << fromName << " to " << destName << endl;
	}
	cout << endl;
}

/*
 *  XMLProcessor.cpp
 *  FreeCell Solver
 *
 *  Created by Julian on Tue Jun 29 2004.
 *  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
 *
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

#import "Card.h"
#import "FCSFileHandler.h"
#import <Foundation/Foundation.h>
#import <AppKit/NSPanel.h>
#include "Solve FreeCell.h"
#import "CardManager.h"

unsigned long FCSCreatorCode = 'FCS ';
unsigned long FCSFileTypeCode = 'FCSs';


FCSLoadSetupReturnValue FCSFileHandler::loadSetupFromFile(NSString* path, vector<Tableau>* gameSetup) {
  id unarchivedObject = [NSUnarchiver unarchiveObjectWithFile: path];
  if (![unarchivedObject isKindOfClass: [NSArray class]]) {
    return FCSLoadInvalidArchivedObject;
  }

  NSArray* tableauArray = (NSArray*) unarchivedObject;
  if ([tableauArray count] != kNumTableaus) {
    return FCSLoadInvalidArchivedObject;
  }
  int i, j;
  NSArray* tableau;
  for (i = 0; i < kNumTableaus; i++) {
    if (![[tableauArray objectAtIndex: i] isKindOfClass: [NSArray class]]) {
      return FCSLoadInvalidArchivedObject;
    }
    tableau = [tableauArray objectAtIndex: i];
    for (j = 0; j < [tableau count]; j++) {
      if (![[tableau objectAtIndex: j] isKindOfClass: [NSString class]]) {
        return FCSLoadInvalidArchivedObject;
      }
    }
  }
  // whew, done validating
  NSString* cardString;
  bool hadInvalidCard = false;
  Card newCard; 
  int cardInt;
  unichar suitChar;
  
  gameSetup->resize(kNumTableaus);
  // TODO: validate that cards aren't used more than once, and that the tableau sizes
  // conform to the FreeCell rules
  for (i = 0; i < kNumTableaus; i++) {
    tableau = [tableauArray objectAtIndex: i];
    for (j = 0; j < [tableau count]; j++) {
      cardString = [tableau objectAtIndex: j];
      cardInt = [cardString intValue];
      if (cardInt <= 0 || cardInt > NUM_RANKS) {
        hadInvalidCard = true;
        continue;
      }
      suitChar = (cardInt > 9 ? [cardString characterAtIndex: 2] : [cardString characterAtIndex: 1]);
      newCard.num = cardInt;
      switch (suitChar) {
        case L'c':
        case L'C':
          newCard.suit = clubs;
          break;
        case L'D':
        case L'd':
          newCard.suit = diamonds;
          break;
        case L'H':
        case L'h':
          newCard.suit = hearts;
          break;
        case L'S':
        case L's':
          newCard.suit = spades;
          break;
        default:
          hadInvalidCard = true;
          continue;
      }
      (*gameSetup)[i].place(newCard);
    }
  }
  if (hadInvalidCard) {
    return FCSLoadInvalidCard;
  }
  return FCSLoadSucceeded;
}

/* So I was gonna save it to XML in the same format as Solitaire Till Dawn's format,
   but I decided that wasn't necessary. */
bool FCSFileHandler::saveSetupToFile(NSString * path, const vector<Tableau>& gameSetup)
{
  if (gameSetup.size() != kNumTableaus) {
    NSLog(@"Internal error: gameSetup had incorrect number of tableaus");
    return false;
  }

  // we don't even open the file for writing ourselves; we just create an array of an array of strings
  // representing the cards.
  NSMutableArray* tableauArray = [[NSMutableArray alloc] initWithCapacity: kNumTableaus];

  for (int i = 0; i < kNumTableaus; i++) {
    const Tableau& tableau = gameSetup[i];
    NSMutableArray* tableauObjc = [[NSMutableArray alloc] initWithCapacity: tableau.size()];
    [tableauArray addObject: tableauObjc];
    
    for (unsigned int cardIndex = 0; cardIndex < tableau.size(); cardIndex++) {
      const Card& card = tableau.peek(cardIndex);
      [tableauObjc addObject: [NSString stringWithFormat: @"%hu%c", card.num, card.suitChar()]];
    }
  }

  bool retval;
  // Now we just archive the array to a file
  if ( (retval = [NSArchiver archiveRootObject: tableauArray toFile: path]) ) {
    // and set the type and creator codes
    NSNumber* creatorCode = [NSNumber numberWithUnsignedLong: FCSCreatorCode];
    NSNumber* typeCode = [NSNumber numberWithUnsignedLong: FCSFileTypeCode];
    NSDictionary* hfsCodesDict = [NSDictionary dictionaryWithObjectsAndKeys: creatorCode, NSFileHFSCreatorCode,
      typeCode, NSFileHFSTypeCode, nil];

    [[NSFileManager defaultManager] changeFileAttributes: hfsCodesDict atPath: path];
  }

  // and release the alloc'ed arrays
  [tableauArray makeObjectsPerformSelector: @selector(release)];
  [tableauArray removeAllObjects];
  [tableauArray release];
  return retval;
}

/*
 bool FCSFileHandler::loadSetupFromXML(NSString * path, vector<Tableau> * gameSetup)
 {
   bool retval;

   // get a URL for the file
   CFURLRef setupFileURL = (CFURLRef) [[NSURL alloc] initFileURLWithPath: path];

   // set up an XML parser
   CFXMLParserCallBacks callbacks = {0, createStructure, addChild, endStructure, NULL, NULL};
   CFXMLParserRef parser = CFXMLParserCreateWithDataFromURL(kCFAllocatorDefault, setupFileURL, kCFXMLParserAllOptions,
                                                            kCFXMLNodeCurrentVersion, &callbacks, NULL);
   retval = CFXMLParserParse(parser);
   [(NSURL *) setupFileURL release];

   return retval;
 }

 void * createStructure(CFXMLParserRef parser, CFXMLNodeRef node, void * info)
 {
   switch (CFXMLNodeGetTypeCode(node)) {
     case kCFXMLNodeTypeDocument:
       NSLog(@"create structure: document: %@", (NSString*) CFXMLNodeGetString(node));
       break;

     case kCFXMLNodeTypeElement:
       NSLog(@"create structure: element: %@", (NSString*) CFXMLNodeGetString(node));
       break;

     case kCFXMLNodeTypeText:
       NSLog(@"create structure: text: %@", (NSString*) CFXMLNodeGetString(node));
       break;

     case kCFXMLNodeTypeAttribute:
       NSLog(@"create structure: attribute: %@", (NSString*) CFXMLNodeGetString(node));
       break;

     default:
       break;
   }
   return CFXMLNodeGetString(node);
 }

 void endStructure(CFXMLParserRef parser, void * xmlType, void * info)
 {
   NSLog(@"end structure: xmlType = %@", (NSString*) xmlType);
 }

 void addChild(CFXMLParserRef parser, void * parent, void * child, void * info)
 {
   NSLog(@"add child: parent = %@, child = %@", (NSString*) parent, (NSString*) child);
 }
 */

/*
bool FCSFileHandler::saveSetupToXML(NSString * path, const vector<Tableau>& gameSetup)
{
  if (gameSetup.size() != kNumTableaus) {
    NSLog(@"Internal error: gameSetup had incorrect number of tableaus");
    return false;
  }
  
  // write the data to a file
  NSFileHandle* setupFile = [NSFileHandle fileHandleForWritingAtPath: path];
  if (setupFile == nil) {
    return false;
  }

  int i, cardIndex;	
  NSMutableString* fileContentsXML = [[NSMutableString alloc] initWithCapacity: 1000];
  // write out the XML intro
  [fileContentsXML appendString: FCSXMLHeader];
  [fileContentsXML appendString: FCSSolitaireTag];
  [fileContentsXML appendString: @"<savedgame numcards=\"52\">\n"];
  [fileContentsXML appendString: @"<movelist index=\"1\" />\n"];

  for (i = 0; i < gameSetup.size(); i++) {
    [fileContentsXML appendFormat: @"%@%i%@",  @"  <pilecontents pilenum=\"", FCSBasePile + i, @"\">\n"];
    for (cardIndex = 0; cardIndex < gameSetup[i].size(); cardIndex++) {
      const Card& card = gameSetup[i].peek(cardIndex);
      [fileContentsXML appendFormat: @"%@%hu%@%c%@", @"    <card rank=\"",
        card.num, @"\" suit=\"", card.suitChar(), @"\" />\n"];
    }
    [fileContentsXML appendString: @"  </pilecontents>\n"];
  }

  [fileContentsXML appendString: FCSSolitaireEndTag];
  [fileContentsXML appendString: @"</savedgame>\n"];

  [setupFile writeData: [fileContentsXML dataUsingEncoding: NSUTF8StringEncoding]];

  [fileContentsXML release];
  [setupFile closeFile];
  return true;
}
*/

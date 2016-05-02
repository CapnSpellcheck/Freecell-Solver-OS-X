//
//  DeckView.m
//  FreeCell Solver
//
//  Created by Julian on Sat Jul 03 2004.
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

#import "DeckView.h"
#import "UIConstants.h"
#import "AppController.h"


@implementation DeckView

// isFlipped, for starting drawing at the upper left
- (BOOL) isFlipped
{
  return YES;
}

- (id)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    // No custom drawing needed. The view just starts with the full deck at app launch.
    // We do, however, tell ourself that we have all the cards.
    for (int i = 0; i < NUM_CARDS; i++) {
      hasCards[i] = YES;
    }
    frontCardIndex = -1;
    highlightView = NO;

    // register for drag type
    [self registerForDraggedTypes: [NSArray arrayWithObject: FCSPboardType]];
  }
  return self;
}

- (void)drawRect:(NSRect)rect {
  // draw all the cards that we have.
  // card layering is achieved by drawing the cards from low to high rank.
  // TODO:
  // ¥ skip over frontCard
  // ¥ clip cards to visible portion
  // ¥ clip entire region to rect argument
  NSImage* curImage;
  CardManager* cardMan = [CardManager defaultManager];
  NSRect destRect, imageRect;
  NSPoint curDrawingPoint = NSMakePoint(FCSDeckHorizontalMargin, FCSDeckVerticalMargin);
  int curIndex = 0;

  imageRect.origin = NSZeroPoint;
  imageRect.size = NSMakeSize(FCSCardWidth, FCSCardHeight);
  destRect.size = imageRect.size;

  if (highlightView) {
    [[NSColor keyboardFocusIndicatorColor] set];
    [NSBezierPath fillRect: [self bounds]];
  }
  
  for (int i = 0; i < NUM_SUITS; i++) {
    CardSuit curSuit = deckOrder[i];
    for (unsigned int rank = 1; rank <= NUM_RANKS; rank++) {
      if (hasCards[curIndex]) {
        curImage = [cardMan imageForCardWithRank: rank suit: curSuit];
        destRect.origin = curDrawingPoint;
        // draw the card
        [curImage drawInRect: destRect fromRect: imageRect operation: NSCompositeCopy fraction: 1.0];
      }
      // move to the point for the next card
      curDrawingPoint.x += FCSCardHorizontalSeparation;
      curIndex++;
    }
    curDrawingPoint.x = FCSDeckHorizontalMargin;
    curDrawingPoint.y += FCSCardHeight + FCSDeckVerticalSpaceBetweenSuits;
  }
  // draw front card
  if (frontCardIndex >= 0 && hasCards[frontCardIndex]) {
    unsigned int rank, row;
    rank = (frontCardIndex % NUM_RANKS) + 1;
    row = frontCardIndex / NUM_RANKS;
    curImage = [[CardManager defaultManager] imageForCardWithRank: rank suit: deckOrder[row]];
    curDrawingPoint.x = FCSDeckHorizontalMargin + (rank - 1) * FCSCardHorizontalSeparation;
    curDrawingPoint.y = FCSDeckVerticalMargin + row * (FCSCardHeight + FCSDeckVerticalSpaceBetweenSuits);
    destRect.origin = curDrawingPoint;
    [curImage drawInRect: destRect fromRect: imageRect operation: NSCompositeCopy fraction: 1.0];
  }
}


/**
 * cursor rects
 **/

- (void) resetCursorRects
{
  if ([NSCursor respondsToSelector: @selector(openHandCursor)]) {
    for (int rank = 1; rank <= NUM_RANKS; rank++) {
      for (int suit = 0; suit < NUM_SUITS; suit++) {
        if ([self hasCardWithRank: rank suit: deckOrder[suit]]) {
          [self addCursorRect: [self rectForCardWithRank: rank suit: deckOrder[suit]] cursor: [NSCursor openHandCursor]];
        }
      }
    }        
  }
}

/**
* Dragging
 **/
// Make the deck view be a drag source
- (unsigned int) draggingSourceOperationMaskForLocal: (BOOL) isLocal
{
  if (isLocal) {
    return NSDragOperationMove;
  }
  else {
    return NSDragOperationNone;
  }
}

- (BOOL) ignoreModifierKeysWhileDragging
{
  return YES;
}

// When the mouse is clicked, we check to see if it is over a card image, and if so, move that image
// so it is not blocked by other cards.
- (void) mouseDown: (NSEvent*) event
{
  // get the card index for the card visible at the event's point, and move the card up front
  NSPoint eventPoint = [self convertPoint: [event locationInWindow] fromView: nil];
  frontCardIndex = [self cardIndexForPoint: eventPoint];
  if (frontCardIndex >= 0) {
    [self setNeedsDisplay: YES];
    if ([NSCursor respondsToSelector: @selector(closedHandCursor)]) {
      [[NSCursor closedHandCursor] push];
    }
  }
}

// When we get a drag, we see if the click originated on a card (by frontCardIndex)
// If it did, we set up the card image for dragging, and place a Card object on the pasteboard.
- (void) mouseDragged: (NSEvent*) event
{
  if (frontCardIndex >= 0) {
    NSPoint imagePoint;
    Card card;
    unsigned int rank = frontCardIndex % NUM_RANKS + 1;
    CardSuit suit = [self suitForIndex: frontCardIndex];
    NSPasteboard* pasteboard = [NSPasteboard pasteboardWithName: NSDragPboard];
    [pasteboard declareTypes: [NSArray arrayWithObject: FCSPboardType] owner: self];

    card.num = rank;
    card.suit = suit;
    [[CardManager defaultManager] setDraggedCard: card];
    hasCards[frontCardIndex] = NO;
    imagePoint = [self pointForCardWithRank: rank suit: suit];
    // convert point from upper left of card to lower left
    imagePoint.y += FCSCardHeight;
    [self setNeedsDisplay: YES];

    [self dragImage: [[CardManager defaultManager] imageForCardWithRank: rank suit: suit]
                 at: imagePoint
             offset: NSMakeSize(0, 0)
              event: event
         pasteboard: pasteboard
             source: self
          slideBack: YES];
  }
}

- (void) mouseUp: (NSEvent*) event
{
  if (frontCardIndex >= 0) {
    frontCardIndex = -1;
    [self setNeedsDisplay: YES];
    if ([NSCursor respondsToSelector: @selector(closedHandCursor)]) {
      [NSCursor pop];
    }
  }
}

- (void) draggedImage: (NSImage*) image endedAt: (NSPoint) point operation: (NSDragOperation) op
{
  if (op == NSDragOperationNone) {
    NSLog(@"drag op none");
    // source takes responsibility for reverting cursor after cancelled drag
    if ([NSCursor respondsToSelector: @selector(openHandCursor)]) {
      [NSCursor pop];
    }
    hasCards[frontCardIndex] = YES;
    frontCardIndex = -1;
    [self setNeedsDisplay: YES];
  }
  else if (op == NSDragOperationMove) {
    // remove the tracking rect
    if ([NSCursor respondsToSelector: @selector(closedHandCursor)]) {
      [self removeCursorRect: [self rectForCardWithRank: (frontCardIndex % NUM_RANKS + 1) suit: [self suitForIndex: frontCardIndex]] 
                      cursor: [NSCursor openHandCursor]];
    }
    // leave hasCards[frontCardIndex] = NO, but reset the frontCardIndex
    frontCardIndex = -1;
  }
}

// since we're a floating window, makes sense to accept the first event.
- (BOOL) acceptsFirstMouse: (NSEvent*) event
{
  return YES;
}

// Make the view be a drag destination
- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>) sender
{
  if ([NSCursor respondsToSelector: @selector(closedHandCursor)]) {
    [[NSCursor closedHandCursor] set];
  }
  if ([sender draggingSource] == self) {
    return NSDragOperationNone;
  }
  
  highlightView = YES;
  [self setNeedsDisplay: YES];
  return NSDragOperationMove;
}

- (NSDragOperation) draggingUpdated: (id<NSDraggingInfo>) sender
{
  if ([sender draggingSource] == self) {
    return NSDragOperationNone;
  }
  return NSDragOperationMove;
}

// don't need to do much here
- (void) draggingExited: (id<NSDraggingInfo>) sender
{
  highlightView = NO;
  [self setNeedsDisplay: YES];
}

// not much here either
- (BOOL) prepareForDragOperation: (id<NSDraggingInfo>) sender
{
  NSWindow* myWindow = [self window];
  Card draggedCard = [[CardManager defaultManager] draggedCard];
  NSPoint destPoint = [self convertPoint: [self pointForCardWithRank: draggedCard.num suit: draggedCard.suit]
                                  toView: nil];
  // this method doesn't seem to work, but still put it here in case it does someday
  [sender slideDraggedImageTo: [myWindow convertBaseToScreen: destPoint]];
  return YES;
}

- (BOOL) performDragOperation: (id<NSDraggingInfo>) sender
{
  Card draggedCard = [[CardManager defaultManager] draggedCard];
  [self addCardWithRank: draggedCard.num suit: draggedCard.suit];
  // destination performs cursor update on successful drag
  if ([NSCursor respondsToSelector: @selector(openHandCursor)]) {
    [NSCursor pop];
  }
  // add tracking rect if necessary
  if ([NSCursor respondsToSelector: @selector(closedHandCursor)]) {
    [self addCursorRect: [self rectForCardWithRank: draggedCard.num suit: draggedCard.suit] cursor: [NSCursor openHandCursor]];
  }
  //[self setNeedsDisplayInRect: [self rectForCardWithRank: draggedCard.num suit: draggedCard.suit]];
  return YES;
}  

- (void) concludeDragOperation: (id<NSDraggingInfo>) sender
{
  [appController setSolveMenuItemEnabled: NO];
  highlightView = NO;
  [self setNeedsDisplay: YES];
}


/**
 * Logic
 **/
- (BOOL) hasCardWithRank: (unsigned int) rank suit: (CardSuit) suit
{
  if (rank > NUM_RANKS || rank == 0)
    return NO;

  rank -= 1;
  return hasCards[[self rowForSuit: suit] * NUM_RANKS + rank];
}

- (CardSuit) suitForIndex: (int) index
{
  // index should be >= 0 and < 52
  return deckOrder[index / NUM_RANKS];
}

// returns the point for the upper-left corner of the given card
- (NSPoint) pointForCardWithRank: (unsigned int) rank suit: (CardSuit) suit
{
  return NSMakePoint(FCSDeckHorizontalMargin + (rank - 1) * FCSCardHorizontalSeparation,
                     FCSDeckVerticalMargin + [self rowForSuit: suit] * (FCSCardHeight + FCSDeckVerticalSpaceBetweenSuits));
}

- (NSRect) rectForCardWithRank: (unsigned int) rank suit: (CardSuit) suit
{
  NSPoint rectOrigin = [self pointForCardWithRank: rank suit: suit];
  return NSMakeRect(rectOrigin.x, rectOrigin.y, FCSCardWidth, FCSCardHeight);
}

- (int) rowForSuit: (CardSuit) suit
{
  switch (suit) {
    case clubs:
      return 0;
    case spades:
      return 1;
    case hearts:
      return 2;
    case diamonds:
      return 3;
  }
}

// Encapsulates the logic for determining the card that is exposed at a point.
// -1 means no card is at the point.
- (int) cardIndexForPoint: (NSPoint) point
{
  int highestCandidateRank;
  static int numCardsToSearch = ceil((double)FCSCardWidth / FCSCardHorizontalSeparation);
  int curRank;
  
  // let's shift by the x-coordinate of the left edge of the ace
  point.x -= FCSDeckHorizontalMargin;

  // let's filter by the x-coordinate
  if (point.x < 0 || point.x >= (NUM_RANKS - 1) * FCSCardHorizontalSeparation + FCSCardWidth) {
    return -1;
  }

  // TODO: make a loop!
  // first, let's see if the point's y-coordinate lies in any of the suits' rows.
  if (point.y >= FCSDeckVerticalMargin && point.y < FCSDeckVerticalMargin + FCSCardHeight) {    
    // Now we need to get fancy...if all cards are present, the viewable slice of each card is
    // FCSCardHorizontalSeparation pixels wide. BUT, we need to account for other cards that would
    // normally be on top of the card but may be already gone.
    highestCandidateRank = int(point.x) / FCSCardHorizontalSeparation + 1; // shift to one-based
    for (curRank = highestCandidateRank; curRank > highestCandidateRank - numCardsToSearch; curRank--) {
      if ([self hasCardWithRank: curRank suit: deckOrder[0]]) {
        return curRank - 1;
      }
    }
    // no hit, not found
    return -1;
  }
  else if (point.y >= FCSDeckVerticalMargin + FCSCardHeight + FCSDeckVerticalSpaceBetweenSuits &&
           point.y < FCSDeckVerticalMargin + 2 * FCSCardHeight + FCSDeckVerticalSpaceBetweenSuits) {
    highestCandidateRank = int(point.x / FCSCardHorizontalSeparation) + 1; // shift to one-based
    for (curRank = highestCandidateRank; curRank > highestCandidateRank - numCardsToSearch; curRank--) {
      if ([self hasCardWithRank: curRank suit: deckOrder[1]]) {
        return NUM_RANKS + curRank - 1;
      }
    }
    // no hit, not found
    return -1;    
  }
  else if (point.y >= FCSDeckVerticalMargin + 2 * (FCSCardHeight + FCSDeckVerticalSpaceBetweenSuits) &&
           point.y < FCSDeckVerticalMargin + 3 * FCSCardHeight + 2 * FCSDeckVerticalSpaceBetweenSuits) {
    highestCandidateRank = int(point.x / FCSCardHorizontalSeparation) + 1; // shift to one-based
    for (curRank = highestCandidateRank; curRank > highestCandidateRank - numCardsToSearch; curRank--) {
      if ([self hasCardWithRank: curRank suit: deckOrder[2]]) {
        return 2 * NUM_RANKS + curRank - 1;
      }
    }
    // no hit, not found
    return -1;    
  }
  else if (point.y >= FCSDeckVerticalMargin + 3 * (FCSCardHeight + FCSDeckVerticalSpaceBetweenSuits) &&
           point.y < FCSDeckVerticalMargin + 4 * FCSCardHeight + 3 * FCSDeckVerticalSpaceBetweenSuits) {
    highestCandidateRank = int(point.x / FCSCardHorizontalSeparation) + 1; // shift to one-based
    for (curRank = highestCandidateRank; curRank > highestCandidateRank - numCardsToSearch; curRank--) {
      if ([self hasCardWithRank: curRank suit: deckOrder[3]]) {
        return 3 * NUM_RANKS + curRank - 1;
      }
    }
    // no hit, not found
    return -1;    
  }
  
  return -1;
}

- (void) resetDeck
{
  for (int i = 0; i < NUM_CARDS; i++) {
    hasCards[i] = YES;
  }
  [self discardCursorRects];
  [self resetCursorRects];
}

- (void) emptyDeck
{
  for (int i = 0; i < NUM_CARDS; i++) {
    hasCards[i] = NO;
  }
  [self discardCursorRects];
  [self resetCursorRects];
}

// Adds the specified card to the cards the DeckView has.
// If the deck already has the specified card, returns NO; otherwise returns YES.
- (BOOL) addCardWithRank: (unsigned int) rank suit: (CardSuit) suit
{
  if ([self hasCardWithRank: rank suit: suit]) {
    return NO;
  }
  else {
    hasCards[[self rowForSuit: suit] * NUM_RANKS + rank - 1] = YES;
    if ([NSCursor respondsToSelector: @selector(openHandCursor)]) {
      [self addCursorRect: [self rectForCardWithRank: rank suit: suit] cursor: [NSCursor openHandCursor]];
    }
    return YES;
  }
}

// Removes the specified card to the DeckView's cards.
// If the deck did not have the card, returns NO; else returns YES.
- (BOOL) removeCardWithRank: (unsigned int) rank suit: (CardSuit) suit
{
  if ([self hasCardWithRank: rank suit: suit]) {
    hasCards[[self rowForSuit: suit] * NUM_RANKS + rank - 1] = NO;
    if ([NSCursor respondsToSelector: @selector(openHandCursor)]) {
      [self removeCursorRect: [self rectForCardWithRank: rank suit: suit] cursor: [NSCursor openHandCursor]];
    }
    return YES;
  }
  else {
    return NO;
  }
}

  
@end

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

#import "SolverView.h"
#import "UIConstants.h"
#import "CardManager.h"
#import "SolveTask.h"
#import "AppController.h"
#include <math.h>
#include <vector>

using namespace std;

NSString* FCSPboardType = @"FCS Card drag operation";
NSString* FCSAllCardsPlaced = @"All cards placed";

const double DEFAULT_MOVE_INTERVAL = 0.4;

// quick C function for determining the foundation index for a suit
inline CardSuit foundationSuitForIndex(int index) {
  switch (index) {
    case 0: return clubs;
    case 1: return spades;
    case 2: return hearts;
    case 3: return diamonds;
    default:
      assert(false);
      break;
  }
}
// quick C function for determining the foundation index for a suit
inline int foundationIndexForSuit(CardSuit suit) {
  switch (suit) {
    case clubs: return 0;
    case spades: return 1;
    case hearts: return 2;
    case diamonds: return 3;
    default:
      assert(false);
      break;
  }
}

@implementation SolverView

// isFlipped, for starting drawing at the upper left
- (BOOL) isFlipped
{
  return YES;
}

// In initWithFrame, we set up the custom drawing for the free cells, foundations and tableaus
- (id)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    NSRect curRect;
    int i;

    // setup member data
    tableauContents = new vector<Tableau>;
    tableauContents->resize(NUM_TABLEAUS);
    moveList = new vector<CardMove>;
    cardCount = 0;
    numTableausWithMaxCards = 0;
    // set no highlighted tableau
    highlightedTableau = -1;
    [self setTimeIntervalBetweenMoves: DEFAULT_MOVE_INTERVAL];
    // set play speed
    playSpeed = DEFAULT_PLAY_SPEED;
    currentMove = -1;
    inAnimationMode = NO;
    atEndOfSolution = NO;
    wasDestinationOfDrag = NO;
    
    // register for drag type
    [self registerForDraggedTypes: [NSArray arrayWithObject: FCSPboardType]];
    
    freeCellPath = [NSBezierPath new];
    foundationPath = [NSBezierPath new];
    // try to draw rounded rects...so it doesn't work too well, but it's ok.
    [freeCellPath setLineJoinStyle: NSRoundLineJoinStyle];
    [freeCellPath setLineWidth: 2.0];
    // draw FreeCell borders
    curRect.origin.x = FCSSolverHorizontalMargin;
    curRect.origin.y = FCSSolverVerticalMargin;
    curRect.size.width = FCSCardWidth + 2;
    curRect.size.height = FCSCardHeight + 2;
    // draw first free cell
    [freeCellPath appendBezierPathWithRect: curRect];
    // draw 3 more free cells
    for (i = 1; i < NUM_FREE_CELLS; i++) {
      curRect.origin.x += FCSCardWidth + 2;
      [freeCellPath appendBezierPathWithRect: curRect];
    }
    // draw the 4 foundations
    [foundationPath setLineWidth: 1.0];
    curRect.origin.x = FCSFirstFoundationX;
    curRect.size.width = FCSCardWidth + 1;
    curRect.size.height = FCSCardHeight + 1;
    [foundationPath appendBezierPathWithRect: curRect];
    for (i = 1; i < 4; i++) {
      curRect.origin.x += FCSCardWidth + FCSSpaceBetweenFoundations;
      [foundationPath appendBezierPathWithRect: curRect];
    }
  }
  return self;
}

- (void)drawRect:(NSRect)rect
{
  NSRect curRect;
  int i, cardIndex;
  
  [[NSColor blackColor] set];
  [freeCellPath stroke];
  [foundationPath stroke];

  // fill the foundations with a little lighter color
  // fill the foundation only if it's empty
  [[[[self window] backgroundColor] highlightWithLevel: 0.2] set];
  curRect.origin.x = FCSFirstFoundationX;
  curRect.origin.y = FCSSolverVerticalMargin;
  curRect.size.width = FCSCardWidth;
  curRect.size.height = FCSCardHeight;
  for (i = 0; i < 4; i++) {
    if (ranksOnFoundation[i] == 0) {
      [NSBezierPath fillRect: NSIntersectionRect(curRect, rect)];
    }
    curRect.origin.x += FCSCardWidth + FCSSpaceBetweenFoundations;
  }

  // fill the tableau bases with a little darker color
  // fill only if the tableau is empty
  [[[[self window] backgroundColor] shadowWithLevel: 0.2] set];
  curRect.origin.x = FCSFirstTableauX;
  curRect.origin.y = FCSTableauY;
  for (i = 0; i < NUM_TABLEAUS; i++) {
    if ((*tableauContents)[i].size() == 0) {
      [NSBezierPath fillRect: NSIntersectionRect(curRect, rect)];
    }
    curRect.origin.x += FCSCardWidth + FCSSpaceBetweenTableaus;
  }

  // let's draw some cards!
  CardManager* cardMan = [CardManager defaultManager];
  NSPoint curDrawingPoint;
  NSRect imageRect, drawingRect, tableauRect;
  NSImage* cardImage;

  // draw the cards on the free cells
  curDrawingPoint.x = FCSSolverHorizontalMargin + 1;
  curDrawingPoint.y = FCSSolverVerticalMargin + 1;
  imageRect.origin = NSMakePoint(0, 0);
  imageRect.size = NSMakeSize(FCSCardWidth, FCSCardHeight);
  drawingRect.size = imageRect.size;
  for (i = 0; i < NUM_FREE_CELLS; i++) {
    if (freeCellCards[i].num > 0) {
      drawingRect.origin = curDrawingPoint;
      if (NSIntersectsRect(drawingRect, rect)) {
        cardImage = [cardMan imageForCardWithRank: freeCellCards[i].num suit: freeCellCards[i].suit];
        [cardImage drawInRect: drawingRect fromRect: imageRect operation: NSCompositeCopy fraction: 1.0];
      }
    }
    curDrawingPoint.x += FCSCardWidth + 2;
  }

  // draw the cards on the foundations
  curDrawingPoint.x = FCSFirstFoundationX;
  curDrawingPoint.y = FCSSolverVerticalMargin;
  for(i = 0; i < NUM_SUITS; i++) {
    if (ranksOnFoundation[i] > 0) {
      drawingRect.origin = curDrawingPoint;
      if (NSIntersectsRect(drawingRect, rect)) {
        cardImage = [cardMan imageForCardWithRank: ranksOnFoundation[i] suit: foundationSuitForIndex(i)];
        [cardImage drawInRect: drawingRect fromRect: imageRect operation: NSCompositeCopy fraction: 1.0];
      }
    }
    curDrawingPoint.x += FCSCardWidth + FCSSpaceBetweenFoundations;
  }

  // not yet done...draw the cards on the tableaus
  curDrawingPoint.x = FCSFirstTableauX;
  curDrawingPoint.y = FCSTableauY;
  imageRect.origin = NSMakePoint(0, 0);
  for (i = 0; i < NUM_TABLEAUS; i++) {
    const Tableau& tableau = (*tableauContents)[i];
    for (cardIndex = 0; cardIndex < tableau.size(); cardIndex++) {
      const Card& card = tableau.peek(cardIndex);
      cardImage = [cardMan imageForCardWithRank: card.num suit: card.suit];
      drawingRect.origin = curDrawingPoint;
      // clip the image rect to the part that is seen for all cards on the tableau except the topmost
      // First we get the OS X version number.
      // This became necessary because I found that NSImage's drawInRect:... behavior changed in ~10.3.
      // Assume 10.3 if Gestalt fails
      SInt32 osVersion;
      if (Gestalt(gestaltSystemVersion, &osVersion) == noErr && osVersion < 0x1030) {
        imageRect.origin = NSMakePoint(0, FCSCardHeight - FCSCardVerticalSeparation);
      }
      else {
        imageRect.origin = NSMakePoint(0, 0);
      }
      if (cardIndex < tableau.size() - 1) {
        drawingRect.size = NSMakeSize(FCSCardWidth, FCSCardVerticalSeparation);
      }
      else {
        imageRect.origin = NSMakePoint(0, 0);
        drawingRect.size = NSMakeSize(FCSCardWidth, FCSCardHeight);
      }
      
      if (NSIntersectsRect(drawingRect, rect)) {
        imageRect.size = drawingRect.size;
        [cardImage drawInRect: drawingRect fromRect: imageRect operation: NSCompositeCopy fraction: 1.0];
      }
      curDrawingPoint.y += FCSCardVerticalSeparation;
    }
    // advance to next tableau
    curDrawingPoint.x += FCSCardWidth + FCSSpaceBetweenTableaus;
    curDrawingPoint.y = FCSTableauY;
  }

  // draw the moving card
  if (currentMove >= 0 && currentMove < moveList->size()) {
    const Card& movingCard = (*moveList)[currentMove].card;
    drawingRect.origin = currentMovingCardLoc;
    drawingRect.size = NSMakeSize(FCSCardWidth, FCSCardHeight);
    if (NSIntersectsRect(drawingRect, rect)) {
      imageRect.origin = NSMakePoint(0, 0);
      imageRect.size = NSMakeSize(FCSCardWidth, FCSCardHeight);
      cardImage = [cardMan imageForCardWithRank: movingCard.num suit: movingCard.suit];
      [cardImage drawInRect: drawingRect fromRect: imageRect operation: NSCompositeCopy fraction: 1.0];
    }
  }
  
  // and highlight a tableau if necessary during dragging
  if (highlightedTableau >= 0) {
    tableauRect.origin.x = FCSFirstTableauX + highlightedTableau * (FCSCardWidth + FCSSpaceBetweenTableaus) - 0.5;
    tableauRect.origin.y = FCSTableauY - 0.5;
    tableauRect.size.width = FCSCardWidth;
    tableauRect.size.height = [self pixelLengthForTableau: highlightedTableau];

    // I like the blue menu item color. It seems like it should be graphite when the graphite theme is
    // selected, but it seems like that's not the case...
    [[NSColor selectedMenuItemColor] set];
    [NSBezierPath setDefaultLineWidth: 3.0];
    [NSBezierPath strokeRect: tableauRect];
  }
}

- (void) dealloc
{
  delete tableauContents;
  delete moveList;
  [freeCellPath release];
  [foundationPath release];
  [super dealloc];
}

/**
* cursor rects
 **/
- (void) resetCursorRects
{
  if (!inAnimationMode && [NSCursor respondsToSelector: @selector(openHandCursor)]) {
    for (int tableau = 0; tableau < NUM_TABLEAUS; tableau++) {
      if (tableauContents->at(tableau).size() > 0) {
        NSRect cursorRect = [self rectForTopCardOnTableau: tableau];
        [self addCursorRect: cursorRect cursor: [NSCursor openHandCursor]];
      }
    }
  }
}

/**
 * Dragging
 **/
// SolverView is a drag source when the app is not in solve/playback mode
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

- (void) mouseDown: (NSEvent*) event
{
  NSPoint eventPoint = [self convertPoint: [event locationInWindow] fromView: nil];
  draggedCardOrigin = [self tableauIndexForPoint: eventPoint];
  if ([NSCursor respondsToSelector: @selector(closedHandCursor)]) {
    if (draggedCardOrigin != -1 && tableauContents->at(draggedCardOrigin).size() > 0 && 
        NSPointInRect(eventPoint, [self rectForTopCardOnTableau: draggedCardOrigin])) {
      [[NSCursor closedHandCursor] push];
    }
  }
}

- (void) mouseUp: (NSEvent*) event
{
  if ([NSCursor respondsToSelector: @selector(closedHandCursor)]) {
    [NSCursor pop];
  }
}

// The SolverView starts a drag event if the view is in setup mode, and the drag occurred
// on a card at the top of a tableau
- (void) mouseDragged: (NSEvent*) event
{
  if (inAnimationMode) {
    return;
  }
  NSPoint localPoint = [self convertPoint: [event locationInWindow] fromView: nil];
  int tableauIndex = [self tableauIndexForPoint: localPoint];
  if (tableauIndex >= 0 && (*tableauContents)[tableauIndex].size() > 0 && tableauIndex == draggedCardOrigin) {
    NSRect topCardRect = [self rectForTopCardOnTableau: tableauIndex];
    if (NSPointInRect(localPoint, topCardRect)) {
      // we've got a drag
      // get the card at the top of the given tableau
      // remove the card from ourself so it disappears from the tableau while dragging
      const Card& card = tableauContents->at(tableauIndex).top();
      [self removeCardFromTableauIndex: tableauIndex];
      
      [[CardManager defaultManager] setDraggedCard: card];

      // redraw ourself without that card in the tableau
      [self setNeedsDisplayInRect: topCardRect];
      
      // move the point from upper left to lower left
      NSPoint imageDragPoint = topCardRect.origin;
      imageDragPoint.y += FCSCardHeight;
      [self dragImage: [[CardManager defaultManager] imageForCardWithRank: card.num suit: card.suit]
                   at: imageDragPoint
               offset: NSMakeSize(0, 0)
                event: event
           pasteboard: [NSPasteboard pasteboardWithName: NSDragPboard]
               source: self
            slideBack: YES];
    }
  }
}

// If the drag was canceled, we need to reclaim the card to the tableau
- (void) draggedImage: (NSImage*) image endedAt: (NSPoint) point operation: (NSDragOperation) op
{
  if (op == NSDragOperationNone) {
    // on a cancelled drag, only the source can update the cursor
    // revert to last cursor
    if ([NSCursor respondsToSelector: @selector(openHandCursor)]) {
      [NSCursor pop];
    }
    NSRect dirtyRect;
    // redraw the rect where the card slides back to
    dirtyRect.origin = [self pointForNextCardOnTableau: draggedCardOrigin];
    dirtyRect.size.width = FCSCardWidth;
    dirtyRect.size.height = FCSCardHeight;
    // place the card back on the tableau it was dragged from
    [self addCard: [[CardManager defaultManager] draggedCard] toTableauIndex: draggedCardOrigin];
    
    [self setNeedsDisplayInRect: dirtyRect];
  }
  // If the cards moved to the deck window, this is the only chance we'll get to remove the cursor rect
  // for that card.
  if (!wasDestinationOfDrag) {
    [self discardCursorRects];
    [self resetCursorRects];
  }
  wasDestinationOfDrag = NO;
}

// SolverView is a drag destination for the 8 tableaus, under the following circumstances:
// the tableau has <= 5 cards
// the tableau has 6 cards, and 4 or fewer tableaus currently have 7 cards
- (NSDragOperation) draggingEntered: (id<NSDraggingInfo>) sender
{
  if ([NSCursor respondsToSelector: @selector(closedHandCursor)]) {
    [[NSCursor closedHandCursor] set];
  }
  NSPasteboard* pboard = [sender draggingPasteboard];
  if ([pboard availableTypeFromArray: [NSArray arrayWithObject: FCSPboardType]] != nil) {
    // The drag source can even be self, so that the user can move the top card between tableaus
    return NSDragOperationMove;
  }
  else {
    return NSDragOperationNone;
  }
}

// draggingUpdated doesn't check the types available on the pasteboard...but since the pasteboard
// is just a formality, and there is only one type of drag for this view, that's ok...
- (NSDragOperation) draggingUpdated: (id<NSDraggingInfo>) sender
{
  int possibleTableau;
  NSPoint mousePoint = [self convertPoint: [sender draggingLocation] fromView: nil];
  
  // shift the point so that the first tableau is at (0,0)
  mousePoint.x -= FCSFirstTableauX;
  mousePoint.y -= FCSTableauY;
  // is the point's x position in a tableau?
  if (mousePoint.x >= 0 && mousePoint.y >= 0 &&
      (int)mousePoint.x % (FCSCardWidth + FCSSpaceBetweenTableaus) < FCSCardWidth)
  {
    possibleTableau = (int)mousePoint.x / (FCSCardWidth + FCSSpaceBetweenTableaus);
    if (possibleTableau < NUM_TABLEAUS) {
      // ok, so the x position indicates the point is in a tableau. We're not done...
      // we don't allow this tableau to receive a drag if 1) it has the max # of cards, or
      // 2) If it has one less than the max and 4 tableaus already have the max.
      unsigned int tableauSize = (*tableauContents)[possibleTableau].size();
      if (tableauSize == MAX_CARDS_PER_TABLEAU) {
        return NSDragOperationNone;
      }
      if (tableauSize == MAX_CARDS_PER_TABLEAU - 1 && numTableausWithMaxCards == 4) {
        return NSDragOperationNone;
      }
      // we're still not done...what about y?
      // Have to find out the length of a tableau...
      if (mousePoint.y < [self pixelLengthForTableau: possibleTableau]) {
        if (possibleTableau != highlightedTableau) {
          // let's not forget that no event may have been triggered between the two tableaus. --
          // have to redraw both here
          if (highlightedTableau >= 0) {
            [self setNeedsDisplayInRect: [self rectForTableau: highlightedTableau]];
          }
          highlightedTableau = possibleTableau;
          [self setNeedsDisplayInRect: [self rectForTableau: possibleTableau]];
        }
        return NSDragOperationMove;
      }
    }
  }
  // the fall-through if anything failed above, it means the point is not on a tableau
  if (highlightedTableau >= 0) {
    [self setNeedsDisplayInRect: [self rectForTableau: highlightedTableau]];
    highlightedTableau = -1;
  }
  return NSDragOperationNone;
}

- (void) draggingExited: (id<NSDraggingInfo>) sender
{
  if (highlightedTableau >= 0) {
    [self setNeedsDisplayInRect: [self rectForTableau: highlightedTableau]];
    highlightedTableau = -1;
  }
}

- (BOOL) prepareForDragOperation: (id<NSDraggingInfo>) sender
{
  NSWindow* myWindow = [self window];
  NSPoint destPoint = [self convertPoint: [self pointForNextCardOnTableau: highlightedTableau] toView: nil];
  destPoint.y += FCSCardHeight; // move from upper-left to lower-left 
  [sender slideDraggedImageTo: [myWindow convertBaseToScreen: destPoint]];
  return YES;
}

// here we actually get the card that was dragged
- (BOOL) performDragOperation: (id<NSDraggingInfo>) sender
{
  Card draggedCard = [[CardManager defaultManager] draggedCard];
  [self addCard: draggedCard toTableauIndex: highlightedTableau];
  if ([sender draggingSource] == self) {
    wasDestinationOfDrag = YES;
  }
  return YES;
}

- (void) concludeDragOperation: (id<NSDraggingInfo>) sender
{
  [[self window] disableCursorRects];
  // on a completed drag, the destination updates the cursor
  if ([NSCursor respondsToSelector: @selector(openHandCursor)]) {
    [NSCursor pop];
  }
  [self discardCursorRects];
  [self resetCursorRects];
  [[self window] enableCursorRects];
  
  // and finally we unhighlight the tableau
  [self setNeedsDisplayInRect: [self rectForTableau: highlightedTableau]];
  highlightedTableau = -1;
}

// Here, all we have to do is update the delta between frames.
// the slider's value is the distance in pixels to move per second.
// So we convert per second to per frame and project onto the x and y axes.
- (IBAction) changePlaySpeed: (id) sender
{
  playSpeed = [sender floatValue];
  float deltaDistance = [sender floatValue] * ANIMATION_INTERVAL;
  if (currentMove == -1) {
    // we shouldn't run the rest of this method if we're not in animation mode
    return;
  }
  // we use the "destination point" regardless of whether we're playing forward or
  // backward; we just need a point to get the angle, basically.
  float xDifference = currentMoveDest.x - currentMovingCardLoc.x;
  float yDifference = currentMoveDest.y - currentMovingCardLoc.y;
  float distanceFromCurPointToDestPoint = sqrt(xDifference * xDifference + yDifference * yDifference);
  // if we're pretty close, the math could cause bad stuff. We don't need to continue anyway.
  if (distanceFromCurPointToDestPoint < 0.5) {
    return;
  }
  deltaBetweenFrames.x = deltaDistance / distanceFromCurPointToDestPoint * xDifference;
  deltaBetweenFrames.y = deltaDistance / distanceFromCurPointToDestPoint * yDifference;
}

/**
 * Logic
 **/
- (NSPoint) pointForNextCardOnTableau: (int) tableau
{
  return NSMakePoint(FCSFirstTableauX + tableau * (FCSCardWidth + FCSSpaceBetweenTableaus),
                     FCSTableauY + (*tableauContents)[tableau].size() * FCSCardVerticalSeparation);
}

// undefined if there are no cards on given tableau
- (NSPoint) pointForTopCardOnTableau: (int) tableau
{
  NSPoint tempPoint = [self pointForNextCardOnTableau: tableau];
  tempPoint.y -= FCSCardVerticalSeparation;
  return tempPoint;
}

- (NSPoint) pointForFreeCellNumber: (int) number
{
  NSAssert(number >= 0 && number < NUM_FREE_CELLS, @"OOPS");
  return NSMakePoint(FCSSolverHorizontalMargin + number * (FCSCardWidth + 2) + 1, FCSSolverVerticalMargin + 1);
}

- (NSPoint) pointForFoundationOfSuit: (CardSuit) suit
{
  int suitIndex = foundationIndexForSuit(suit);
  return NSMakePoint(FCSFirstFoundationX + suitIndex * (FCSCardWidth + FCSSpaceBetweenFoundations),
                                                        FCSSolverVerticalMargin);
}

// OK, so I made the bad mistake of making this return the height of a card if there are no cards.
// Don't call this if you don't want that behavior, or work around it.
- (int) pixelLengthForTableau: (int) tableau
{
  if ((*tableauContents)[tableau].size() > 0) {
    return ((*tableauContents)[tableau].size() - 1) * FCSCardVerticalSeparation + FCSCardHeight;
  }
  else {
    return FCSCardHeight;
  }
}

- (int) tableauIndexForPoint: (NSPoint) point
{
  int possibleTableau;
  point.x -= FCSFirstTableauX;
  point.y -= FCSTableauY;
  if (point.x >= 0 && point.y >= 0 &&
      (int)point.x % (FCSCardWidth + FCSSpaceBetweenTableaus) < FCSCardWidth)
  {
    possibleTableau = (int)point.x / (FCSCardWidth + FCSSpaceBetweenTableaus);
    if (possibleTableau < NUM_TABLEAUS) {
      if (point.y < [self pixelLengthForTableau: possibleTableau]) {
        return possibleTableau;
      }
    }
  }
  return -1;
}

/* NOTE that this does not return the PRECISE rectangle that would be the border of the cards currently
   on the tableau. It returns a slightly larger rect for clipping purposes. */
- (NSRect) rectForTableau: (int) tableau
{
  NSAssert(tableau >= 0 && tableau < NUM_TABLEAUS, @"Oops: unexpected number of tableaus in SovlerView");
  return NSMakeRect(FCSFirstTableauX + tableau * (FCSCardWidth + FCSSpaceBetweenTableaus) - 2,
                    FCSTableauY - 2, FCSCardWidth + 4, [self pixelLengthForTableau: tableau] + 4);
}

- (NSRect) rectForTopCardOnTableau: (int) tableau
{
  NSAssert(tableau >= 0 && tableau < NUM_TABLEAUS, @"Oops: unexpected number of tableaus in SovlerView");
  NSPoint origin = [self pointForTopCardOnTableau: tableau];
  NSRect rect;
  rect.size = NSMakeSize(FCSCardWidth, FCSCardHeight);
  rect.origin = origin;
  return rect;
}

- (void) clearTableaus
{
  // remove all the cards from all tableaus
  for (int i = 0; i < NUM_TABLEAUS; i++) {
    (*tableauContents)[i].removeAll();
  }
  cardCount = 0;
  numTableausWithMaxCards = 0;
}

// I decided this should return a copy, rather than just point to tableauContents. Feels safer.
- (void) getTableaus: (vector<Tableau>*) tableaus
{
  *tableaus = *tableauContents;
}

- (void) setTableaus: (const vector<Tableau>*) tableaus
{
  *tableauContents = *tableaus;
  // let's not forget to update our card count information...
  cardCount = 0;
  numTableausWithMaxCards = 0;	

  unsigned int tableauSize;
  for (unsigned int index = 0; index < tableauContents->size(); index++) {
    tableauSize = (*tableauContents)[index].size();
    cardCount += tableauSize;
    if (tableauSize == MAX_CARDS_PER_TABLEAU) {
      numTableausWithMaxCards++;
    }
  }
  if (cardCount == NUM_CARDS) {
    [appController setSolveMenuItemEnabled: YES];
  }
}

- (unsigned int) cardCount
{
  return cardCount;
}

- (unsigned int) moveCount
{
  return moveList->size();
}

- (void) runSolveTask
{
  // clear the last solution
  moveList->clear();
  // run the solving algorithm on another thread
  SolveTask* solveTask = [SolveTask new];
  [solveTask setTableauPointer: tableauContents];
  [solveTask setSolutionPointer: moveList];
  [NSThread detachNewThreadSelector: @selector(solveFreeCellGame:) toTarget: solveTask withObject: nil];
  // the thread retains and releases the task, so we can release it here
  [solveTask release];
}

- (BOOL) hasSolution
{
  return moveList->size() != 0;
}

/**
 * playback logic
 **/
- (void) enterAnimationMode
{
  currentMove = 0;
  currentMoveOrigin = [self originPointForCurrentMoveInverted: NO];
  currentMoveDest = [self destinationPointForCurrentMoveInverted: NO];
  currentMovingCardLoc = currentMoveOrigin;
  // gotta set up the delta between frames too
  deltaBetweenFrames = [self deltaBetweenFramesForCurrentMove];
  inAnimationMode = YES;
  atBeginningOfSolution = YES;
}

- (void) exitAnimationMode
{
  [self pause];
  currentMove = -1;
  inAnimationMode = NO;
  atEndOfSolution = NO;

  int i;
  for (i = 0; i < 4; i++) {
    ranksOnFoundation[i] = 0;
  }
  for (i = 0; i < NUM_FREE_CELLS; i++) {
    freeCellCards[i].num = 0;
  }
}

- (BOOL) isInAnimationMode
{
  return inAnimationMode;
}

- (void) pause
{
  if (mode == PlaybackPause)
    return;

  mode = PlaybackPause;
  // Invalidate the timer
  [animationTimer invalidate];
  [animationTimer release];
  animationTimer = nil;
  
  // that's pretty much all we need to do...I would love to render the cards in grayscale, and will
  // implement that at some future point.
}

- (void) playBackward
{
  if (mode == PlaybackReverse)
    return;

  mode = PlaybackReverse;

  if (atEndOfSolution) {
    atEndOfSolution = NO;
    const CardMove& lastMove = moveList->at(currentMove);
    [self removeCard: lastMove.card fromLocation: lastMove.dest];
  }
  // invalidate the timer
  [animationTimer invalidate];
  // release the current timer
  [animationTimer release];
  // create a new timer
  animationTimer = [NSTimer scheduledTimerWithTimeInterval: ANIMATION_INTERVAL
                                                    target: self
                                                  selector: @selector(solverViewAdvanceFrame)
                                                  userInfo: nil
                                                   repeats: YES];
  [animationTimer retain];
}

- (void) playForward
{
  if (mode == PlaybackForward)
    return;

  mode = PlaybackForward;
  // we need this to remove the card in the first move from its tableau
  if (atBeginningOfSolution) {
    atBeginningOfSolution = NO;
    [self removeCurrentMoveCardFromOrigin];
  }
  // invalidate the timer
  [animationTimer invalidate];
  // release the current timer
  [animationTimer release];
  // create a new timer
  animationTimer = [NSTimer scheduledTimerWithTimeInterval: ANIMATION_INTERVAL
                                                    target: self
                                                  selector: @selector(solverViewAdvanceFrame)
                                                  userInfo: nil
                                                   repeats: YES];
  [animationTimer retain];
}

// Frame advancement
// We look at which direction we're animating, update the current moving card location by the frame delta.
// If we're approaching the end of a move, forward or backward, we invalidate the animation timer and
// set up the animation timer as a one-shot timer for the delay between moves. The timer calls advanceMove
// or goBackMove as appropriate.
- (void) solverViewAdvanceFrame
{
  NSRect startRect, endRect;
  
  startRect = NSMakeRect(currentMovingCardLoc.x, currentMovingCardLoc.y, FCSCardWidth, FCSCardHeight);
  
  // TODO: the interval needs to be adjusted for the last frame, but that's a minor detail since we're
  // drawing 30 frames/sec. I'm not sure if this will even be noticeable.
  NSPoint actualDestination = (mode == PlaybackForward ? currentMoveDest : currentMoveOrigin);
  if (fabsf(deltaBetweenFrames.x) >= fabsf(currentMovingCardLoc.x - actualDestination.x) &&
      fabsf(deltaBetweenFrames.y) >= fabsf(currentMovingCardLoc.y - actualDestination.y)) {
    currentMovingCardLoc.x = actualDestination.x;
    currentMovingCardLoc.y = actualDestination.y;

    // stop the animation timer and make it a one-shot timer for a pause between moves
    [animationTimer invalidate];
    [animationTimer release];
    animationTimer = [NSTimer scheduledTimerWithTimeInterval: secsBetweenMoves
                                                 target: self
                                               selector: (mode == PlaybackForward ? @selector(advanceMove)
                                                                                  : @selector(goBackMove))
                                               userInfo: nil
                                                repeats: NO];
    [animationTimer retain];
    // and we're done for this case
  }
  else {
    // we're not near the end of move, just continue the animation
    if (mode == PlaybackForward) {
      currentMovingCardLoc.x += deltaBetweenFrames.x;
      currentMovingCardLoc.y += deltaBetweenFrames.y;
    }
    else if (mode == PlaybackReverse) {
      currentMovingCardLoc.x -= deltaBetweenFrames.x;
      currentMovingCardLoc.y -= deltaBetweenFrames.y;
    }
  }

  endRect = NSMakeRect(currentMovingCardLoc.x, currentMovingCardLoc.y, FCSCardWidth, FCSCardHeight);
  // mark the dirty region as the union of the area the card moved through
  [self setNeedsDisplayInRect: NSUnionRect(startRect, endRect)];
}

// Design note: for simplicity, the move origin and destination are always from the point of view of
// playing forward.

// advanceMove informs the app controller that it's advancing a move, then looks at the move list to find
// the card that's being moved, and where it's being moved to. In the case of moving to or from a free cell,
// we need to determine which free cell the card was in (the move list doesn't identify a particular free cell
// it was in) or the first available free cell from the left.
// In short, the state information we need to update are:
// current move number
// moving card start location
// moving card destination
// delta between frames by calculating the distance between the above two points and looking at the
//   play speed
// the cards on the free cells, foundation and tableau (commit the card from the last move to its destination)
// Finally, it sets up the animation timer to play the next move.
- (void) advanceMove
{
  [appController solverViewDidAdvanceMove];

  const CardMove& finishedMove = moveList->at(currentMove);
  switch (finishedMove.dest) {
    case cell:
      // find a free cell, the convention is to take the leftmost unused free cell
      int i;
      for (i = 0; i < NUM_FREE_CELLS; i++) {
        if (freeCellCards[i].num == 0) {
          freeCellCards[i] = finishedMove.card;
          break;
        }
      }
      if (i == NUM_FREE_CELLS) {
        NSLog(@"Fatal error: SolverView was told to move a card to a free cell when all cells were full.");
      }
      break;
    case foundation:
      ranksOnFoundation[foundationIndexForSuit(finishedMove.card.suit)]++;
      break;
    default: // a tableau
      unsigned int tableauIndex = (unsigned int)(finishedMove.dest - tableau1);
      tableauContents->at(tableauIndex).place(finishedMove.card);
      break;
  }

  currentMove++;
  if (currentMove >= moveList->size()) {
    [appController solverViewDidReachEnd];
    atEndOfSolution = YES;
    currentMove--;
    return;
  }

  // update for the next move: origin, destination, delta
  currentMoveOrigin = [self originPointForCurrentMoveInverted: NO];
  currentMoveDest = [self destinationPointForCurrentMoveInverted: NO];
  currentMovingCardLoc = currentMoveOrigin;

  // remove the card from the origin of the next move
  [self removeCurrentMoveCardFromOrigin];
  
  // now we have the origin and destination points, so we can calculate the delta
  deltaBetweenFrames = [self deltaBetweenFramesForCurrentMove];
  // phew...done with math
  
  animationTimer = [NSTimer scheduledTimerWithTimeInterval: ANIMATION_INTERVAL
                                                    target: self
                                                  selector: @selector(solverViewAdvanceFrame)
                                                  userInfo: nil
                                                   repeats: YES];
  [animationTimer retain];
  [self setNeedsDisplayInRect: NSMakeRect(currentMoveOrigin.x, currentMoveOrigin.y, FCSCardWidth, FCSCardHeight)];
}

- (void) goBackMove
{
  [appController solverViewDidUndoMove];

  // commit the card to the origin of the move we're at the start of
  const CardMove& revertMove = moveList->at(currentMove);
  switch (revertMove.from) {
    case cell: // find a free cell
      int i;
      for (i = 0; i < NUM_FREE_CELLS; i++) {
        if (freeCellCards[i].num == 0) {
          freeCellCards[i] = revertMove.card;
          break;
        }
      }
      break;
    case foundation:
      NSLog(@"Fatal error: the origin of a move was a foundation.");
      NSAssert(0 == 1, @"Fatal error: the origin of a move was a foundation.");
      break;
    default: // a tableau
      unsigned int tableauIndex = (unsigned int)(revertMove.from - tableau1);
      tableauContents->at(tableauIndex).place(revertMove.card);
      break;
  }

  currentMove--;
  if (currentMove < 0) {
    currentMove = 0;
    [appController solverViewDidReachBeginning];
    atBeginningOfSolution = YES;
    return;
  }

  // update for the next move: origin, destination, delta
  currentMoveOrigin = [self destinationPointForCurrentMoveInverted: YES];
  currentMoveDest = [self originPointForCurrentMoveInverted: YES];
  currentMovingCardLoc = currentMoveDest;

  // remove the card at the destination of the move we're going back to
  const CardMove& lastMove = moveList->at(currentMove);
  [self removeCard: lastMove.card fromLocation: lastMove.dest];

  // now we have the origin and destination points, so we can calculate the delta
  deltaBetweenFrames = [self deltaBetweenFramesForCurrentMove];
  // phew...done with math
  
  animationTimer = [NSTimer scheduledTimerWithTimeInterval: ANIMATION_INTERVAL
                                                    target: self
                                                  selector: @selector(solverViewAdvanceFrame)
                                                  userInfo: nil
                                                  repeats: YES];
  [animationTimer retain];
}

- (NSPoint) originPointForCurrentMoveInverted: (BOOL) inverted
{
  const CardMove& cardMove = moveList->at(currentMove);
  NSPoint originPoint;
  Location originLoc = (inverted ? cardMove.dest : cardMove.from);
  
  switch (originLoc) {
    case cell:
      // find the cell it's in
      int i;
      for (i = 0; i < NUM_FREE_CELLS; i++) {
        if (freeCellCards[i] == cardMove.card) {
          originPoint = [self pointForFreeCellNumber: i];
          break;
        }
      }
      if (i == NUM_FREE_CELLS) {
        NSLog(@"Fatal error: SolverView couldn't find a card in the free cells when a move specified the card's origin as a free cell.");
      }
      break;
    case foundation:
      originPoint = [self pointForFoundationOfSuit: cardMove.card.suit];
      break;
    default: // a tableau
      int tableauIndex = originLoc - tableau1;
      // the origin is the point for the top card on the tableau
      originPoint = [self pointForTopCardOnTableau: tableauIndex];
      break;
  }
  return originPoint;
}

- (NSPoint) destinationPointForCurrentMoveInverted: (BOOL) inverted
{
  const CardMove& cardMove = moveList->at(currentMove);
  NSPoint destination;
  Location destLoc = (inverted ? cardMove.from : cardMove.dest);

  switch (destLoc) {
    case cell:
      // the SolverView's convention is to find the leftmost unused cell
      int i;
      for (i = 0; i < NUM_FREE_CELLS; i++) {
        if (freeCellCards[i].num == 0) {
          destination = [self pointForFreeCellNumber: i];
          break;
        }	
      }
        if (i == NUM_FREE_CELLS) {
          NSLog(@"Fatal error: SolverView couldn't find an unused free cell when looking for a destination.");
        }
      break;
    case foundation:
      destination = [self pointForFoundationOfSuit: cardMove.card.suit];
      break;
    default: // a tableau
      int tableauIndex = destLoc - tableau1;
      // the destination is the point for the next card on the tableau
      destination = [self pointForNextCardOnTableau: tableauIndex];
      break;
  }
  return destination;
}

- (NSPoint) deltaBetweenFramesForCurrentMove
{
  NSPoint resultPoint;
  float distBetweenFrames = playSpeed * ANIMATION_INTERVAL;
  float totalMoveDist = sqrt( pow(currentMoveOrigin.x - currentMoveDest.x, 2) +
                              pow(currentMoveOrigin.y - currentMoveDest.y, 2) );
  resultPoint.x = distBetweenFrames * (currentMoveDest.x - currentMoveOrigin.x) / totalMoveDist;
  resultPoint.y = distBetweenFrames * (currentMoveDest.y - currentMoveOrigin.y) / totalMoveDist;
  return resultPoint;
}

/**
 * Moving cards around during solve playback
 **/
- (void) removeCurrentMoveCardFromOrigin
{
  [self removeCard: moveList->at(currentMove).card fromLocation: moveList->at(currentMove).from];
}

- (void) removeCard: (Card) card fromLocation: (Location) loc
{
  switch (loc) {
    case cell:
      int i;
      for (i = 0; i < NUM_FREE_CELLS; i++) {
        if (freeCellCards[i] == card) {
          freeCellCards[i].num = 0;
          break;
        }
      }
        if (i == NUM_FREE_CELLS) {
          NSLog(@"Fatal error: SolverView couldn't find a card in the free cells when a move specified the card's origin as a free cell.");
        }
        break;
    case foundation:
      ranksOnFoundation[foundationIndexForSuit(card.suit)]--;
      break;
    default: // a tableau
      unsigned int tableauIndex = (unsigned int)(loc - tableau1);
      tableauContents->at(tableauIndex).removeTop();
      break;
  }
}

/**
 * The next 2 methods have nothing to do with solver animation. They should only be used at
 * setup time.
 **/
- (void) addCard: (Card) card toTableauIndex: (int) index
{
  if (index < 0 || index >= NUM_TABLEAUS) {
    NSLog(@"Error: addCard:totableauIndex: index was not a valid value.");
    return;
  }
  tableauContents->at(index).place(card);
  cardCount++;
  if (cardCount == NUM_CARDS) {
    [appController setSolveMenuItemEnabled: YES];
  }
  // we need to know how many cards are on this tableau now to see if the tableau has 7 cards
  if (tableauContents->at(index).size() == MAX_CARDS_PER_TABLEAU) {
    numTableausWithMaxCards++;
  }
}

- (void) removeCardFromTableauIndex: (int) index
{
  if (index < 0 || index >= NUM_TABLEAUS) {
    NSLog(@"Error: addCard:totableauIndex: index was not a valid value.");
    return;
  }
  if (tableauContents->at(index).size() == 0) {
    return;
  }
  tableauContents->at(index).removeTop();
  cardCount--;
  [appController setSolveMenuItemEnabled: NO];
  // also update the count of tableaus with the max number of cards if necessary
  if (tableauContents->at(index).size() == MAX_CARDS_PER_TABLEAU - 1) {
    numTableausWithMaxCards -= 1;
  }
}

- (double) timeIntervalBetweenMoves
{
  return secsBetweenMoves;
}

- (void) setTimeIntervalBetweenMoves: (double)interval
{
  if (interval >= 0) {
    secsBetweenMoves = interval;
  }
}

@end

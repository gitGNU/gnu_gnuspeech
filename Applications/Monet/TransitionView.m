#import "TransitionView.h"

#import <AppKit/AppKit.h>
#include <math.h>

#import "AppController.h"
#import "FormulaExpression.h"
#import "Inspector.h"
#import "MMEquation.h"
#import "MMPosture.h"
#import "MMPoint.h"
#import "MMTransition.h"
#import "MMSlope.h"
#import "MMSlopeRatio.h"
#import "MMTarget.h"
#import "MonetList.h"
#import "NamedList.h"
#import "PointInspector.h"
#import "PrototypeManager.h"
#import "SymbolList.h"
#import "TargetList.h"

#import "MModel.h"

#define LABEL_MARGIN 5
#define LEFT_MARGIN 50
#define BOTTOM_MARGIN 50
#define SECTION_COUNT 14
#define SLOPE_MARKER_HEIGHT 18

#define ZERO_INDEX 2
#define SECTION_AMOUNT 10

// TODO (2004-03-15): Should have methods to convert between points in the view and graph values.

@implementation TransitionView

static NSImage *_dotMarker = nil;
static NSImage *_squareMarker = nil;
static NSImage *_triangleMarker = nil;
static NSImage *_selectionBox = nil;

+ (void)initialize;
{
    NSBundle *mainBundle;
    NSString *path;

    mainBundle = [NSBundle mainBundle];
    path = [mainBundle pathForResource:@"dotMarker" ofType:@"tiff"];
    NSLog(@"path: %@", path);
    _dotMarker = [[NSImage alloc] initWithContentsOfFile:path];

    path = [mainBundle pathForResource:@"squareMarker" ofType:@"tiff"];
    NSLog(@"path: %@", path);
    _squareMarker = [[NSImage alloc] initWithContentsOfFile:path];

    path = [mainBundle pathForResource:@"triangleMarker" ofType:@"tiff"];
    NSLog(@"path: %@", path);
    _triangleMarker = [[NSImage alloc] initWithContentsOfFile:path];

    path = [mainBundle pathForResource:@"selectionBox" ofType:@"tiff"];
    NSLog(@"path: %@", path);
    _selectionBox = [[NSImage alloc] initWithContentsOfFile:path];
}

// The size was originally 700 x 380
- (id)initWithFrame:(NSRect)frameRect;
{
    if ([super initWithFrame:frameRect] == nil)
        return nil;

    cache = 100000;
    [self allocateGState];

    timesFont = [[NSFont fontWithName:@"Times-Roman" size:12] retain];
    currentTemplate = nil;

    samplePhoneList = [[MonetList alloc] init];
    displayPoints = [[MonetList alloc] init];
    displaySlopes = [[MonetList alloc] init];
    selectedPoints = [[MonetList alloc] init];

    shouldDrawSelection = NO;

    editingSlope = nil;
    textFieldCell = [[NSTextFieldCell alloc] initTextCell:@""];
    nonretained_fieldEditor = nil;

    [self setNeedsDisplay:YES];

    return self;
}

- (void)dealloc;
{
    [timesFont release];
    [samplePhoneList release];
    [displayPoints release];
    [displaySlopes release];
    [selectedPoints release];
    [textFieldCell release];

    [super dealloc];
}

- (MModel *)model;
{
    return model;
}

- (void)setModel:(MModel *)newModel;
{
    if (newModel == model)
        return;

    [model release];
    model = [newModel retain];

    [self _updateFromModel];
}

// TODO (2004-03-21): I don't think this will catch changes to the "Formula Symbols"...
- (void)_updateFromModel;
{
    MMPosture *aPosture;

    NSLog(@" > %s", _cmd);

    [samplePhoneList removeAllObjects];
    [displayPoints removeAllObjects];
    [displaySlopes removeAllObjects];
    [selectedPoints removeAllObjects];

    aPosture = [[MMPosture alloc] initWithModel:model];
    [aPosture setSymbol:@"dummy"];
    [(MMTarget *)[[aPosture symbolList] objectAtIndex:0] setValue:100.0]; // Rule Duration (should be "duration"?)
    [(MMTarget *)[[aPosture symbolList] objectAtIndex:1] setValue:33.3333]; // Beat Location? (should be "transition"?)
    [(MMTarget *)[[aPosture symbolList] objectAtIndex:2] setValue:33.3333]; // Mark 1 (should be "qssa"?)
    [(MMTarget *)[[aPosture symbolList] objectAtIndex:3] setValue:33.3333]; // Mark 2 (should be "qssb"?)

    // We need four postures to show a tetraphone
    [samplePhoneList addObject:aPosture];
    [samplePhoneList addObject:aPosture];
    [samplePhoneList addObject:aPosture];
    [samplePhoneList addObject:aPosture];

    [aPosture release];

    [self setNeedsDisplay:YES];

    NSLog(@"<  %s", _cmd);
}

- (double)ruleDuration;
{
    return _parameters[0];
}

- (void)setRuleDuration:(double)newValue;
{
    _parameters[0] = newValue;
    [self setNeedsDisplay:YES];
}

- (double)beatLocation;
{
    return _parameters[1];
}

- (void)setBeatLocation:(double)newValue;
{
    _parameters[1] = newValue;
    [self setNeedsDisplay:YES];
}

- (double)mark1;
{
    return _parameters[2];
}

- (void)setMark1:(double)newValue;
{
    _parameters[2] = newValue;
    [self setNeedsDisplay:YES];
}

- (double)mark2;
{
    return _parameters[3];
}

- (void)setMark2:(double)newValue;
{
    _parameters[3] = newValue;
    [self setNeedsDisplay:YES];
}

- (double)mark3;
{
    return _parameters[4];
}

- (void)setMark3:(double)newValue;
{
    _parameters[4] = newValue;
    [self setNeedsDisplay:YES];
}

- (IBAction)takeRuleDurationFrom:(id)sender;
{
    [self setRuleDuration:[sender doubleValue]];
}

- (IBAction)takeBeatLocationFrom:(id)sender;
{
    [self setBeatLocation:[sender doubleValue]];
}

- (IBAction)takeMark1From:(id)sender;
{
    [self setMark1:[sender doubleValue]];
}

- (IBAction)takeMark2From:(id)sender;
{
    [self setMark2:[sender doubleValue]];
}

- (IBAction)takeMark3From:(id)sender;
{
    [self setMark3:[sender doubleValue]];
}

- (BOOL)shouldDrawSelection;
{
    return shouldDrawSelection;
}

- (void)setShouldDrawSelection:(BOOL)newFlag;
{
    if (newFlag == shouldDrawSelection)
        return;

    shouldDrawSelection = newFlag;
    [self setNeedsDisplay:YES];
}

//
// Drawing
//

- (void)drawRect:(NSRect)rect;
{
    NSLog(@" > %s, cache: %d", _cmd, cache);

    [self clearView];
    [self drawGrid];
    [self drawEquations];
    [self drawPhones];
    [self drawTransition];
    [self drawSlopes];

    if (shouldDrawSelection == YES) {
        NSRect selectionRect;

        selectionRect = [self rectFormedByPoint:selectionPoint1 andPoint:selectionPoint2];
        selectionRect.origin.x += 0.5;
        selectionRect.origin.y += 0.5;

        [[NSColor purpleColor] set];
        [NSBezierPath strokeRect:selectionRect];
    }

    if (nonretained_fieldEditor != nil) {
        NSRect editingRect;

        editingRect = [nonretained_fieldEditor frame];
        editingRect = NSInsetRect(editingRect, -1, -1);
        //[[NSColor redColor] set];
        //NSRectFill(editingRect);
        NSFrameRect(editingRect);
    }

    NSLog(@"<  %s", _cmd);
}

- (void)clearView;
{
    [[NSColor whiteColor] set];
    NSRectFill([self bounds]);
}

- (void)drawGrid;
{
    int i;
    int sectionHeight;
    NSBezierPath *bezierPath;
    NSRect bounds, rect;
    NSPoint graphOrigin; // But not the zero point on the graph.

    bounds = NSIntegralRect([self bounds]);

    sectionHeight = [self sectionHeight];
    graphOrigin = [self graphOrigin];

    [[NSColor lightGrayColor] set];
    rect = NSMakeRect(graphOrigin.x + 1.0, graphOrigin.y + 1.0, bounds.size.width - 2 * (LEFT_MARGIN + 1), ZERO_INDEX * sectionHeight);
    NSRectFill(rect);

    rect = NSMakeRect(graphOrigin.x + 1.0, graphOrigin.y + 1.0 + (10 + ZERO_INDEX) * sectionHeight,
                      bounds.size.width - 2 * (LEFT_MARGIN + 1), 2 * sectionHeight);
    NSRectFill(rect);

    /* Grayed out (unused) data spaces should be placed here */

    [[NSColor blackColor] set];
    bezierPath = [[NSBezierPath alloc] init];
    [bezierPath setLineWidth:2];
    [bezierPath appendBezierPathWithRect:NSMakeRect(graphOrigin.x, graphOrigin.y, bounds.size.width - 2 * LEFT_MARGIN, 14 * sectionHeight)];
    [bezierPath stroke];
    [bezierPath release];

    [[NSColor blackColor] set];
    [timesFont set];

    bezierPath = [[NSBezierPath alloc] init];
    [bezierPath setLineWidth:1];

    for (i = 1; i < SECTION_COUNT; i++) {
        NSString *label;
        float currentYPos;
        NSSize labelSize;

        currentYPos = graphOrigin.y + 0.5 + i * sectionHeight;
        [bezierPath moveToPoint:NSMakePoint(graphOrigin.x + 0.5, currentYPos)];
        [bezierPath lineToPoint:NSMakePoint(bounds.size.width - LEFT_MARGIN + 0.5, currentYPos)];

        currentYPos = graphOrigin.y + i * sectionHeight - 5;
        label = [NSString stringWithFormat:@"%4d%%", (i - ZERO_INDEX) * SECTION_AMOUNT];
        labelSize = [label sizeWithAttributes:nil];
        //NSLog(@"label (%@) size: %@", label, NSStringFromSize(labelSize));
        [label drawAtPoint:NSMakePoint(LEFT_MARGIN - LABEL_MARGIN - labelSize.width, currentYPos) withAttributes:nil];
        // The current max label width is 35, so we'll just shift the label over a little
        [label drawAtPoint:NSMakePoint(bounds.size.width - 10 - labelSize.width, currentYPos) withAttributes:nil];
    }

    [bezierPath stroke];
    [bezierPath release];
}

// These are the proto equations
- (void)drawEquations;
{
    int i, j;
    double time;
    MonetList *equationList = [NXGetNamedObject(@"prototypeManager", NSApp) equationList];
    NamedList *namedList;
    MMEquation *equation;
    float timeScale = [self timeScale];
    int type;
    NSBezierPath *bezierPath;
    NSPoint graphOrigin;

    graphOrigin = [self graphOrigin];

    cache++;

    if (currentTemplate)
        type = [currentTemplate type];
    else
        type = DIPHONE;

    [[NSColor darkGrayColor] set];
    bezierPath = [[NSBezierPath alloc] init];
    for (i = 0; i < [equationList count]; i++) {
        namedList = [equationList objectAtIndex:i];
        //NSLog(@"named list: %@, count: %d", [namedList name], [namedList count]);
        for (j = 0; j < [namedList count]; j++) {
            equation = [namedList objectAtIndex:j];
            if ([[equation expression] maxPhone] <= type) {
                time = [equation evaluate:_parameters phones:samplePhoneList andCacheWith:cache];
                //NSLog(@"\t%@", [equation name]);
                //NSLog(@"\t\ttime = %f", time);
                //NSLog(@"equation name: %@, formula: %@, time: %f", [equation name], [[equation expression] expressionString], time);
                // TODO (2004-03-11): Need to check with users to see if floor()'ing the x is okay.
                [bezierPath moveToPoint:NSMakePoint(graphOrigin.x + 0.5 + floor(timeScale * (float)time), graphOrigin.y - 1)];
                [bezierPath lineToPoint:NSMakePoint(graphOrigin.x + 0.5 + floor(timeScale * (float)time), graphOrigin.y - 10)];
            }
        }
    }

    [bezierPath stroke];
    [bezierPath release];
}

- (void)drawPhones;
{
    NSPoint myPoint;
    float timeScale;
    float currentTimePoint;
    int type;
    NSBezierPath *bezierPath;
    NSRect bounds;
    NSPoint graphOrigin;
    float graphTopYPos;

    bounds = NSIntegralRect([self bounds]);
    graphOrigin = [self graphOrigin];

    if (currentTemplate)
        type = [currentTemplate type];
    else
        type = DIPHONE;

    [[NSColor blackColor] set];
    //[[NSColor redColor] set];

    bezierPath = [[NSBezierPath alloc] init];
    [bezierPath setLineWidth:2];

    timeScale = [self timeScale];
    graphTopYPos = bounds.size.height - BOTTOM_MARGIN - 1;
    myPoint.y = bounds.size.height - BOTTOM_MARGIN + 6;

    switch (type) {
      case TETRAPHONE:
          currentTimePoint = (timeScale * [self mark3]);
          [bezierPath moveToPoint:NSMakePoint(graphOrigin.x + currentTimePoint, graphOrigin.y + 1)];
          [bezierPath lineToPoint:NSMakePoint(graphOrigin.x + currentTimePoint, graphTopYPos)];
          myPoint.x = currentTimePoint + LEFT_MARGIN;
          [self drawSquareMarkerAtPoint:myPoint];
          // And draw the other two:

      case TRIPHONE:
          currentTimePoint = (timeScale * [self mark2]);
          [bezierPath moveToPoint:NSMakePoint(graphOrigin.x + currentTimePoint, graphOrigin.y + 1)];
          [bezierPath lineToPoint:NSMakePoint(graphOrigin.x + currentTimePoint, graphTopYPos)];
          myPoint.x = currentTimePoint + LEFT_MARGIN;
          [self drawTriangleMarkerAtPoint:myPoint];
          // And draw the other one:

      case DIPHONE:
          currentTimePoint = (timeScale * [self mark1]);
          [bezierPath moveToPoint:NSMakePoint(graphOrigin.x + currentTimePoint, graphOrigin.y + 1)];
          [bezierPath lineToPoint:NSMakePoint(graphOrigin.x + currentTimePoint, graphTopYPos)];
          myPoint.x = currentTimePoint + LEFT_MARGIN;
          [self drawCircleMarkerAtPoint:myPoint];
    }

    [bezierPath stroke];
    [bezierPath release];
}

- (void)drawTransition;
{
    int count, index;
    MonetList *currentPoints;
    MMPoint *currentPoint;
    double tempos[4] = {1.0, 1.0, 1.0, 1.0};
    NSPoint myPoint;
    float timeScale, y;
    int yScale;
    float eventTime;
    MMPoint *tempPoint;
    NSBezierPath *bezierPath;
    NSPoint graphOrigin;
    NSMutableArray *diphonePoints, *triphonePoints, *tetraphonePoints;

    if (currentTemplate == nil)
        return;

    [[NSColor blackColor] set];

    graphOrigin = [self graphOrigin];

    [displayPoints removeAllObjects];
    [displaySlopes removeAllObjects];

    timeScale = [self timeScale];
    yScale = [self sectionHeight];

    cache++;

    currentPoints = [currentTemplate points];
    count = [currentPoints count];
    for (index = 0; index < count; index++) {
        currentPoint = [currentPoints objectAtIndex:index];
        //NSLog(@"%2d: object class: %@", index, NSStringFromClass([currentPoint class]));
        //NSLog(@"%2d (a): value: %g, freeTime: %g, type: %d, isPhantom: %d", index, [currentPoint value], [currentPoint freeTime], [currentPoint type], [currentPoint isPhantom]);
        [currentPoint calculatePoints:_parameters tempos:tempos phones:samplePhoneList andCacheWith:cache toDisplay:displayPoints];
        //NSLog(@"%2d (b): value: %g, freeTime: %g, type: %d, isPhantom: %d", index, [currentPoint value], [currentPoint freeTime], [currentPoint type], [currentPoint isPhantom]);

        if ([currentPoint isKindOfClass:[MMSlopeRatio class]])
            [(MMSlopeRatio *)currentPoint displaySlopesInList:displaySlopes];
    }

    diphonePoints = [[NSMutableArray alloc] init];
    triphonePoints = [[NSMutableArray alloc] init];
    tetraphonePoints = [[NSMutableArray alloc] init];

    bezierPath = [[NSBezierPath alloc] init];
    [bezierPath setLineWidth:2];
    [bezierPath moveToPoint:NSMakePoint(graphOrigin.x, graphOrigin.y + (yScale * ZERO_INDEX))];

    // TODO (2004-03-02): With the bezier path change, we may want to do the compositing after we draw the path.
    count = [displayPoints count];
    //NSLog(@"%d display points", count);
    for (index = 0; index < count; index++) {
        currentPoint = [displayPoints objectAtIndex:index];
        y = [currentPoint value];
        NSLog(@"%d: [%p] y = %f", index, currentPoint, y);
        if ([currentPoint expression] == nil)
            eventTime = [currentPoint freeTime];
        else
            eventTime = [[currentPoint expression] cacheValue];
        myPoint.x = graphOrigin.x + timeScale * eventTime;
        myPoint.y = graphOrigin.y + (yScale * ZERO_INDEX) + (y * (float)yScale / SECTION_AMOUNT);
        [bezierPath lineToPoint:myPoint];
        switch ([currentPoint type]) {
          case TETRAPHONE:
              [tetraphonePoints addObject:[NSValue valueWithPoint:myPoint]];
              break;
          case TRIPHONE:
              [triphonePoints addObject:[NSValue valueWithPoint:myPoint]];
              break;
          case DIPHONE:
              [diphonePoints addObject:[NSValue valueWithPoint:myPoint]];
              break;
        }

        if (index != [displayPoints count] - 1) {
            if ([currentPoint type] == [(MMPoint *)[displayPoints objectAtIndex:index+1] type])
                [bezierPath moveToPoint:myPoint];
            else
                [bezierPath moveToPoint:NSMakePoint(myPoint.x, graphOrigin.y + (ZERO_INDEX * yScale))];
        }
        else
            [bezierPath moveToPoint:NSMakePoint(myPoint.x, myPoint.y)];
    }

    [bezierPath lineToPoint:NSMakePoint([self bounds].size.width - LEFT_MARGIN, [self bounds].size.height - BOTTOM_MARGIN - (ZERO_INDEX * yScale))];
    [bezierPath stroke];
    [bezierPath release];

    //[[NSColor redColor] set];
    count = [diphonePoints count];
    for (index = 0; index < count; index++) {
        NSPoint aPoint;

        aPoint = [[diphonePoints objectAtIndex:index] pointValue];
        [self drawCircleMarkerAtPoint:aPoint];
    }

    count = [triphonePoints count];
    for (index = 0; index < count; index++) {
        NSPoint aPoint;

        aPoint = [[triphonePoints objectAtIndex:index] pointValue];
        [self drawTriangleMarkerAtPoint:aPoint];
    }

    count = [tetraphonePoints count];
    for (index = 0; index < count; index++) {
        NSPoint aPoint;

        aPoint = [[tetraphonePoints objectAtIndex:index] pointValue];
        [self drawSquareMarkerAtPoint:aPoint];
    }

    [diphonePoints release];
    [triphonePoints release];
    [tetraphonePoints release];

//    for (i = 0; i < [displaySlopes count]; i++) {
//        currentSlope = [displaySlopes objectAtIndex:i];
//        slopeRect.origin.x = [currentSlope displayTime]*timeScale+32.0;
//        slopeRect.origin.y = 100.0;
//        slopeRect.size.height = 20.0;
//        slopeRect.size.width = 30.0;
//        NXDrawButton(&slopeRect, &bounds);
//    }

    if ([selectedPoints count]) {
        //NSLog(@"Drawing %d selected points", [selectedPoints count]);
        for (index = 0; index < [selectedPoints count]; index++) {
            tempPoint = [selectedPoints objectAtIndex:index];
            y = (float)[tempPoint value];
            if ([tempPoint expression] == nil)
                eventTime = [tempPoint freeTime];
            else
                eventTime = [[tempPoint expression] cacheValue];
            myPoint.x = graphOrigin.x + timeScale * eventTime;
            myPoint.y = graphOrigin.y + (yScale * ZERO_INDEX) + (y * (float)yScale / SECTION_AMOUNT);

            //NSLog(@"Selection; x: %f y:%f", myPoint.x, myPoint.y);

            [self highlightMarkerAtPoint:myPoint];
        }
    }
}

- (void)drawCircleMarkerAtPoint:(NSPoint)aPoint;
{
    int radius = 3;
    NSBezierPath *bezierPath;

    //NSLog(@"->%s, point: %@", _cmd, NSStringFromPoint(aPoint));
    aPoint.x = rint(aPoint.x);
    aPoint.y = rint(aPoint.y);
    //NSLog(@"-->%s, point: %@", _cmd, NSStringFromPoint(aPoint));

    bezierPath = [[NSBezierPath alloc] init];
    [bezierPath appendBezierPathWithArcWithCenter:aPoint radius:radius startAngle:0 endAngle:360];
    [bezierPath closePath];
    [bezierPath fill];
    //[bezierPath stroke];
    [bezierPath release];
}

- (void)drawTriangleMarkerAtPoint:(NSPoint)aPoint;
{
    int radius = 5;
    NSBezierPath *bezierPath;
    float angle;

    //NSLog(@"->%s, point: %@", _cmd, NSStringFromPoint(aPoint));
    aPoint.x = rint(aPoint.x);
    aPoint.y = rint(aPoint.y);
    //NSLog(@"-->%s, point: %@", _cmd, NSStringFromPoint(aPoint));

    bezierPath = [[NSBezierPath alloc] init];
    //[bezierPath moveToPoint:NSMakePoint(aPoint.x, aPoint.y + radius)];
    angle = 90.0 * (2 * M_PI) / 360.0;
    //NSLog(@"angle: %f, cos(angle): %f, sin(angle): %f", angle, cos(angle), sin(angle));
    [bezierPath moveToPoint:NSMakePoint(aPoint.x + cos(angle) * radius, aPoint.y + sin(angle) * radius)];
    angle = 210.0 * (2 * M_PI) / 360.0;
    //NSLog(@"angle: %f, cos(angle): %f, sin(angle): %f", angle, cos(angle), sin(angle));
    [bezierPath lineToPoint:NSMakePoint(aPoint.x + cos(angle) * radius, aPoint.y + sin(angle) * radius)];
    angle = 330.0 * (2 * M_PI) / 360.0;
    //NSLog(@"angle: %f, cos(angle): %f, sin(angle): %f", angle, cos(angle), sin(angle));
    [bezierPath lineToPoint:NSMakePoint(aPoint.x + cos(angle) * radius, aPoint.y + sin(angle) * radius)];
    [bezierPath closePath];
    [bezierPath fill];
    //[bezierPath stroke];
    [bezierPath release];
}

- (void)drawSquareMarkerAtPoint:(NSPoint)aPoint;
{
    NSRect rect;

    //NSLog(@"->%s, point: %@", _cmd, NSStringFromPoint(aPoint));
    aPoint.x = rint(aPoint.x);
    aPoint.y = rint(aPoint.y);
    //NSLog(@"-->%s, point: %@", _cmd, NSStringFromPoint(aPoint));

    rect = NSIntegralRect(NSMakeRect(aPoint.x - 3, aPoint.y - 3, 1, 1));
    rect.size = NSMakeSize(6, 6);
    //NSLog(@"%s, rect: %@", _cmd, NSStringFromRect(rect));
    [NSBezierPath fillRect:rect];
    //[NSBezierPath strokeRect:rect];
    //NSRectFill(rect);
    //NSFrameRect(rect);
}

- (void)highlightMarkerAtPoint:(NSPoint)aPoint;
{
    NSRect rect;

    //NSLog(@"->%s, point: %@", _cmd, NSStringFromPoint(aPoint));
    aPoint.x = rint(aPoint.x);
    aPoint.y = rint(aPoint.y);
    //NSLog(@"-->%s, point: %@", _cmd, NSStringFromPoint(aPoint));


    rect = NSIntegralRect(NSMakeRect(aPoint.x - 5, aPoint.y - 5, 10, 10));
    //NSLog(@"%s, rect: %@", _cmd, NSStringFromRect(rect));
    NSFrameRect(rect);
}

//
// Event handling
//

- (BOOL)acceptsFirstResponder;
{
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent;
{
    return YES;
}

- (void)mouseDown:(NSEvent *)mouseEvent;
{
    NSPoint hitPoint;
    MMSlope *hitSlope;
    float startTime, endTime;

    NSLog(@" > %s", _cmd);

    hitPoint = [self convertPoint:[mouseEvent locationInWindow] fromView:nil];
    NSLog(@"hitPoint: %@", NSStringFromPoint(hitPoint));

    hitSlope = [self getSlopeMarkerAtPoint:hitPoint startTime:&startTime endTime:&endTime];

    [self setShouldDrawSelection:NO];
    [selectedPoints removeAllObjects];
    [[controller inspector] inspectPoint:nil];
    [self setNeedsDisplay:YES];

    if ([mouseEvent clickCount] == 1) {
        if (hitSlope == nil)
            [[self window] endEditingFor:nil];
        else {
            [self editSlope:hitSlope startTime:startTime endTime:endTime];
            return;
        }

        //NSLog(@"[mouseEvent modifierFlags]: %x", [mouseEvent modifierFlags]);
        if ([mouseEvent modifierFlags] & NSAlternateKeyMask) {
            MMPoint *newPoint;
            NSPoint graphOrigin = [self graphOrigin];
            int yScale = [self sectionHeight];
            float newValue;

            //NSLog(@"Alt-clicked!");
            newPoint = [[MMPoint alloc] init];
            [newPoint setFreeTime:(hitPoint.x - graphOrigin.x) / [self timeScale]];
            //NSLog(@"hitPoint: %@, graphOrigin: %@, yScale: %d", NSStringFromPoint(hitPoint), NSStringFromPoint(graphOrigin), yScale);
            newValue = (hitPoint.y - graphOrigin.y - (ZERO_INDEX * yScale)) * SECTION_AMOUNT / yScale;

            //NSLog(@"NewPoint Time: %f  value: %f", [tempPoint freeTime], [tempPoint value]);
            [newPoint setValue:newValue];
            if ([currentTemplate insertPoint:newPoint]) {
                [selectedPoints removeAllObjects];
                [selectedPoints addObject:newPoint];
            }

            [newPoint release];

            [[controller inspector] inspectPoints:selectedPoints];
            [self setNeedsDisplay:YES];
            return;
        }
    }


    selectionPoint1 = hitPoint;
    selectionPoint2 = hitPoint; // TODO (2004-03-11): Should only do this one they start dragging
    [self setShouldDrawSelection:YES];

    NSLog(@"<  %s", _cmd);
}

- (void)mouseDragged:(NSEvent *)mouseEvent;
{
    NSPoint hitPoint;

    //NSLog(@" > %s", _cmd);

    if (shouldDrawSelection == YES) {
        hitPoint = [self convertPoint:[mouseEvent locationInWindow] fromView:nil];
        //NSLog(@"hitPoint: %@", NSStringFromPoint(hitPoint));
        selectionPoint2 = hitPoint;
        [self setNeedsDisplay:YES];

        [self selectGraphPointsBetweenPoint:selectionPoint1 andPoint:selectionPoint2];
    }

    //NSLog(@"<  %s", _cmd);
}

- (void)mouseUp:(NSEvent *)mouseEvent;
{
    NSLog(@" > %s", _cmd);
    [self setShouldDrawSelection:NO];
    NSLog(@"<  %s", _cmd);
}

//
// View geometry
//

- (int)sectionHeight;
{
    NSRect bounds;
    int sectionHeight;

    bounds = [self bounds];
    sectionHeight = (bounds.size.height - 2 * BOTTOM_MARGIN) / SECTION_COUNT;

    return sectionHeight;
}

- (NSPoint)graphOrigin;
{
    NSPoint graphOrigin;

    graphOrigin.x = LEFT_MARGIN;
    graphOrigin.y = [self bounds].size.height - BOTTOM_MARGIN - SECTION_COUNT * [self sectionHeight];

    return graphOrigin;
}

- (float)timeScale;
{
    // TODO (2004-03-11): Remove outlets to form, turn these values into ivars.
    return ([self bounds].size.width - 2 * LEFT_MARGIN) / [self ruleDuration];
}

- (NSRect)rectFormedByPoint:(NSPoint)point1 andPoint:(NSPoint)point2;
{
    float minx, miny, maxx, maxy;
    NSRect rect;

    if (point1.x < point2.x) {
        minx = point1.x;
        maxx = point2.x;
    } else {
        minx = point2.x;
        maxx = point1.x;
    }

    if (point1.y < point2.y) {
        miny = point1.y;
        maxy = point2.y;
    } else {
        miny = point2.y;
        maxy = point1.y;
    }

    rect.origin.x = minx;
    rect.origin.y = miny;
    rect.size.width = maxx - minx;
    rect.size.height = maxy - miny;

    return rect;
}

- (float)slopeMarkerYPosition;
{
    NSPoint graphOrigin;

    graphOrigin = [self graphOrigin];

    return graphOrigin.y - BOTTOM_MARGIN + 10;
}

- (NSRect)slopeMarkerRect;
{
    NSRect bounds, rect;
    NSPoint graphOrigin;

    bounds = NSIntegralRect([self bounds]);
    graphOrigin = [self graphOrigin];

    rect.origin.x = graphOrigin.x;
    rect.origin.y = [self slopeMarkerYPosition];
    rect.size.width = bounds.size.width - 2 * LEFT_MARGIN;
    rect.size.height = SLOPE_MARKER_HEIGHT; // Roughly

    return rect;
}

//
// Slopes
//

- (void)drawSlopes;
{
    int i, j;
    double start, end;
    NSRect rect = NSMakeRect(0, 0, 2 * LEFT_MARGIN, SLOPE_MARKER_HEIGHT);
    MMSlopeRatio *currentPoint;
    MonetList *slopes, *points;
    float timeScale = [self timeScale];
    NSPoint graphOrigin;
    NSRect bounds;

    bounds = [self bounds];
    graphOrigin = [self graphOrigin];
    rect.origin.y = [self slopeMarkerYPosition];

    for (i = 0; i < [[currentTemplate points] count]; i++) {
        currentPoint = [[currentTemplate points] objectAtIndex:i];
        if ([currentPoint isKindOfClass:[MMSlopeRatio class]]) {
            //NSLog(@"%d: Drawing slope ratio...", i);
            start = graphOrigin.x + [currentPoint startTime] * timeScale;
            end = graphOrigin.x + [currentPoint endTime] * timeScale;
            //NSLog(@"Slope  %f -> %f", start, end);
            rect.origin.x = (float)start;
            rect.size.width = (float)(end - start);
            //NSLog(@"drawing button, rect: %@, bounds: %@", NSStringFromRect(rect), NSStringFromRect(bounds));
            NSDrawButton(rect, bounds);

            slopes = [currentPoint slopes];
            points = [currentPoint points];
            for (j = 0; j < [slopes count]; j++) {
                NSString *str;
                //NSPoint aPoint;
                NSRect textFieldFrame;

                str = [NSString stringWithFormat:@"%.1f", [[slopes objectAtIndex:j] slope]];
                //NSLog(@"Buffer = %@", str);

                [[NSColor blackColor] set];
                textFieldFrame.origin.x = ([[(MMPoint *)[points objectAtIndex:j] expression] cacheValue]) * timeScale + LEFT_MARGIN + 5.0;
                textFieldFrame.origin.y = rect.origin.y + 2;
                textFieldFrame.size.width = 60;
                textFieldFrame.size.height = SLOPE_MARKER_HEIGHT - 2;
                //[str drawAtPoint:aPoint withAttributes:nil];
                [textFieldCell setStringValue:str];
                [textFieldCell setFont:timesFont];
                [textFieldCell drawWithFrame:textFieldFrame inView:self];
            }
        }
    }
}

- (void)_setEditingSlope:(MMSlope *)newSlope;
{
    if (newSlope == editingSlope)
        return;

    [editingSlope release];
    editingSlope = [newSlope retain];
}

- (void)editSlope:(MMSlope *)aSlope startTime:(float)startTime endTime:(float)endTime;
{
    NSWindow *window;

    NSLog(@" > %s", _cmd);

    if (aSlope == nil)
        return;

    window = [self window];

    if ([window makeFirstResponder:window] == YES) {
        float timeScale;
        NSRect rect;

        [self _setEditingSlope:aSlope];
        timeScale = [self timeScale];

        rect.origin.x = LEFT_MARGIN + startTime * timeScale;
        rect.origin.y = [self slopeMarkerYPosition];
        rect.size.width = (endTime - startTime) * timeScale;
        rect.size.height = SLOPE_MARKER_HEIGHT;
        rect = NSIntegralRect(rect);
        nonretained_fieldEditor = [window fieldEditor:YES forObject:self];
        NSLog(@"nonretained_fieldEditor: %p", nonretained_fieldEditor);

        [nonretained_fieldEditor setString:[NSString stringWithFormat:@"%0.1f", [aSlope slope]]];
        [nonretained_fieldEditor setRichText:NO];
        [nonretained_fieldEditor setUsesFontPanel:NO];
        [nonretained_fieldEditor setFont:timesFont];
        [nonretained_fieldEditor setHorizontallyResizable:NO];
        [nonretained_fieldEditor setVerticallyResizable:NO];
        [nonretained_fieldEditor setAutoresizingMask:NSViewWidthSizable];

        [nonretained_fieldEditor setFrame:rect];
        [nonretained_fieldEditor setMinSize:rect.size];
        [nonretained_fieldEditor setMaxSize:rect.size];
        [[(NSTextView *)nonretained_fieldEditor textContainer] setLineFragmentPadding:3];

        [nonretained_fieldEditor setFieldEditor:YES];

        [self setNeedsDisplay:YES];
        [nonretained_fieldEditor setNeedsDisplay:YES];
        [nonretained_fieldEditor setDelegate:self];

        [self addSubview:nonretained_fieldEditor positioned:NSWindowAbove relativeTo:nil];

        [window makeFirstResponder:nonretained_fieldEditor];
        [nonretained_fieldEditor selectAll:nil];
    } else {
        [window endEditingFor:nil];
    }

    NSLog(@"<  %s", _cmd);
}

- (MMSlope *)getSlopeMarkerAtPoint:(NSPoint)aPoint startTime:(float *)startTime endTime:(float *)endTime;
{
    MonetList *pointList;
    MMSlopeRatio *currentMMSlopeRatio;
    float timeScale = [self timeScale];
    float tempTime;
    float time1, time2;
    int i, j;
    MonetList *points;

    NSRect slopeMarkerRect;

    //NSLog(@" > %s", _cmd);
    //NSLog(@"aPoint: %@", NSStringFromPoint(aPoint));

    //if ( (aPoint.y > -21.0) || (aPoint.y < -39.0)) {

    slopeMarkerRect = [self slopeMarkerRect];
    if (NSPointInRect(aPoint, slopeMarkerRect) == NO) {
        //NSLog(@"Y not in range -21 to -39, returning.");
        //NSLog(@"<  %s", _cmd);
        return nil;
    }

    aPoint.x -= LEFT_MARGIN;
    aPoint.y -= BOTTOM_MARGIN;

    tempTime = aPoint.x / timeScale;

    //NSLog(@"ClickSlopeMarker Row: %f  Col: %f  time = %f", aPoint.y, aPoint.x, tempTime);

    points = [currentTemplate points];
    for (i = 0; i < [points count]; i++) {
        currentMMSlopeRatio = [points objectAtIndex:i];
        if ([currentMMSlopeRatio isKindOfClass:[MMSlopeRatio class]]) {
            if ((tempTime < [currentMMSlopeRatio endTime]) && (tempTime > [currentMMSlopeRatio startTime])) {
                pointList = [currentMMSlopeRatio points];
                time1 = [[pointList objectAtIndex:0] getTime];

                for (j = 1; j < [pointList count]; j++) {
                    time2 = [[pointList objectAtIndex:j] getTime];
                    if ((tempTime < time2) && (tempTime > time1)) {
                        *startTime = time1;
                        *endTime = time2;
                        //NSLog(@"<  %s", _cmd);
                        return [[currentMMSlopeRatio slopes] objectAtIndex:j-1];
                    }

                    time1 = time2;
                }
            }
        }
    }

    //NSLog(@"<  %s", _cmd);
    return nil;
}

//
// NSTextView delegate method, used for editing slopes
//

- (void)textDidEndEditing:(NSNotification *)notification;
{
    NSString *str;

    NSLog(@" > %s", _cmd);

    NSLog(@"notification: %@", notification);

    str = [nonretained_fieldEditor string];
    NSLog(@"str: %@", str);

    [editingSlope setSlope:[str floatValue]];
    [editingSlope release];
    editingSlope = nil;

    [nonretained_fieldEditor removeFromSuperview];
    nonretained_fieldEditor = nil;

    [self setNeedsDisplay:YES];

    NSLog(@"<  %s", _cmd);
}

//
// Selection
//

- (void)selectGraphPointsBetweenPoint:(NSPoint)point1 andPoint:(NSPoint)point2;
{
    NSPoint graphOrigin;
    NSRect selectionRect;
    int count, index;
    float timeScale;
    int yScale;

    [selectedPoints removeAllObjects];

    cache++;
    graphOrigin = [self graphOrigin];
    timeScale = [self timeScale];
    yScale = [self sectionHeight];

    selectionRect = [self rectFormedByPoint:point1 andPoint:point2];
    selectionRect.origin.x -= graphOrigin.x;
    selectionRect.origin.y -= graphOrigin.y;

    NSLog(@"%s, selectionRect: %@", _cmd, NSStringFromRect(selectionRect));

    count = [displayPoints count];
    NSLog(@"%d display points", count);
    for (index = 0; index < count; index++) {
        MMPoint *currentDisplayPoint;
        MMEquation *currentExpression;
        NSPoint currentPoint;

        currentDisplayPoint = [displayPoints objectAtIndex:index];
        currentExpression = [currentDisplayPoint expression];
        if (currentExpression == nil)
            currentPoint.x = [currentDisplayPoint freeTime];
        else
            currentPoint.x = [[currentDisplayPoint expression] evaluate:_parameters phones:samplePhoneList andCacheWith:cache];

        currentPoint.x *= timeScale;
        currentPoint.y = (yScale * ZERO_INDEX) + ([currentDisplayPoint value] * yScale / SECTION_AMOUNT);

        //NSLog(@"%2d: currentPoint: %@", index, NSStringFromPoint(currentPoint));
        if (NSPointInRect(currentPoint, selectionRect) == YES) {
            [selectedPoints addObject:currentDisplayPoint];
        }
    }

    [[controller inspector] inspectPoints:selectedPoints];
    [self setNeedsDisplay:YES];
}

//
// Actions
//

- (IBAction)delete:(id)sender;
{
    int i;
    MMPoint *tempPoint;

    if ((currentTemplate == nil) || (![selectedPoints count])) {
        NSBeep();
        return;
    }

    for (i = 0; i < [selectedPoints count]; i++) {
        tempPoint = [selectedPoints objectAtIndex:i];
        if ([[currentTemplate points] indexOfObject:tempPoint]) {
            [[currentTemplate points] removeObject:tempPoint];
        }
    }

    [[controller inspector] cleanInspectorWindow];
    [selectedPoints removeAllObjects];
    [[controller inspector] inspectPoint:nil];

    [self setNeedsDisplay:YES];
}


- (IBAction)groupInSlopeRatio:(id)sender;
{
    int i, index;
    int type;
    MonetList *tempPoints, *newPoints;
    MMSlopeRatio *tempMMSlopeRatio;

    if ([selectedPoints count] < 3) {
        NSBeep();
        return;
    }

    type = [(MMPoint *)[selectedPoints objectAtIndex:0] type];
    for (i = 1; i < [selectedPoints count]; i++) {
        if (type != [(MMPoint *)[selectedPoints objectAtIndex:i] type]) {
            NSBeep();
            return;
        }
    }

    tempPoints = [currentTemplate points];

    index = [tempPoints indexOfObject:[selectedPoints objectAtIndex:0]];
    for (i = 0; i < [selectedPoints count]; i++)
        [tempPoints removeObject:[selectedPoints objectAtIndex:i]];

    tempMMSlopeRatio = [[MMSlopeRatio alloc] init];
    newPoints = [tempMMSlopeRatio points];
    for (i = 0; i < [selectedPoints count]; i++)
        [newPoints addObject:[selectedPoints objectAtIndex:i]];
    [tempMMSlopeRatio updateSlopes];

    [tempPoints insertObject:tempMMSlopeRatio atIndex:index];
    [tempMMSlopeRatio release];

    [self setNeedsDisplay:YES];
}

//
// Publicly used API
//

- (void)setTransition:(MMTransition *)newTransition;
{
    NSLog(@" > %s", _cmd);

    NSLog(@"currentTemplate: %p, newTransition: %p", currentTemplate, newTransition);

    if (newTransition == currentTemplate) {
        NSLog(@"<  %s", _cmd);
        return;
    }

    [[self window] endEditingFor:nil];
    [selectedPoints removeAllObjects];
    [[controller inspector] inspectPoint:nil];

    [currentTemplate release];
    currentTemplate = [newTransition retain];

    switch ([currentTemplate type]) {
      case DIPHONE:
          [self setRuleDuration:100];
          [self setBeatLocation:33];
          [self setMark1:100];
          [self setMark2:0];
          [self setMark3:0];
          break;
      case TRIPHONE:
          [self setRuleDuration:200];
          [self setBeatLocation:33];
          [self setMark1:100];
          [self setMark2:200];
          [self setMark3:0];
          break;
      case TETRAPHONE:
          [self setRuleDuration:300];
          [self setBeatLocation:33];
          [self setMark1:100];
          [self setMark2:200];
          [self setMark3:300];
          break;
    }

    [self setNeedsDisplay:YES];

    NSLog(@"<  %s", _cmd);
}

- (void)showWindow:(int)otherWindow;
{
    [[self window] orderWindow:NSWindowBelow relativeTo:otherWindow];
}

@end

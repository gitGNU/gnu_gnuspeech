#import <Foundation/NSObject.h>

@class EventList;

/*===========================================================================

	Author: Craig-Richard Taube-Schock
		Copyright (c) 1994, Trillium Sound Research Incorporated.
		All Rights Reserved.

=============================================================================
*/

// TODO (2004-08-09): absoluteTime is derived from offsetTime and beatTime.  And beatTime is derived from ruleIndex and eventList.

@interface IntonationPoint : NSObject
{
    double semitone; /* Value of the point in semitones */
    double offsetTime; /* Points are timed wrt a beat + this offset */
    double slope;  /* Slope of point */

    int ruleIndex; /* Index of phone which is the focus of this point */
    EventList *eventList; /* Current EventList */
}

- (id)init;
- (id)initWithEventList:(EventList *)aList;
- (void)dealloc;

- (EventList *)eventList;
- (void)setEventList:(EventList *)aList;

- (double)semitone;
- (void)setSemitone:(double)newValue;

- (double)offsetTime;
- (void)setOffsetTime:(double)newValue;

- (double)slope;
- (void)setSlope:(double)newValue;

- (int)ruleIndex;
- (void)setRuleIndex:(int)newIndex;

- (double)absoluteTime;
- (double)beatTime;

- (double)semitoneInHertz;
- (void)setSemitoneInHertz:(double)newHertzValue;

- (void)appendXMLToString:(NSMutableString *)resultString level:(int)level;

@end

//  This file is part of __APPNAME__, __SHORT_DESCRIPTION__.
//  Copyright (C) 2004 __OWNER__.  All rights reserved.

#import "MRuleManager.h"

#import <AppKit/AppKit.h>
#import "BooleanExpression.h"
#import "MCommentCell.h"
#import "MModel.h"
#import "MMParameter.h"
#import "MMPosture.h"
#import "MMRule.h"
#import "NamedList.h"
#import "ParameterList.h"
#import "PhoneList.h"
#import "RuleList.h"

@implementation MRuleManager

- (id)initWithModel:(MModel *)aModel;
{
    unsigned int index;

    if ([super initWithWindowNibName:@"RuleManager"] == nil)
        return nil;

    model = [aModel retain];

    matchLists = [[MonetList alloc] init];
    for (index = 0; index < 4; index++) {
        PhoneList *aPhoneList;

        aPhoneList = [[PhoneList alloc] init];
        [matchLists addObject:aPhoneList];
        [aPhoneList release];
    }

    [self setWindowFrameAutosaveName:@"New Rule Manager"];

    return self;
}

- (void)dealloc;
{
    [model release];
    [matchLists release];

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

    [self updateViews];
    [self expandOutlines];
}

- (NSUndoManager *)undoManager;
{
    return nil;
}

- (MMRule *)selectedRule;
{
    int selectedRow;

    selectedRow = [ruleTableView selectedRow];

    return [[model rules] objectAtIndex:selectedRow];
}

- (void)windowDidLoad;
{
    MCommentCell *commentImageCell;

    commentImageCell = [[MCommentCell alloc] initImageCell:nil];
    [commentImageCell setImageAlignment:NSImageAlignCenter];
    [[ruleTableView tableColumnWithIdentifier:@"hasComment"] setDataCell:commentImageCell];
    [commentImageCell release];

    [errorTextField setStringValue:@""];
    [possibleCombinationsTextField setIntValue:0];

    [self updateViews];
    [self expandOutlines];
}

- (void)updateViews;
{
}

- (void)expandOutlines;
{
    unsigned int count, index;

    count = [[model equations] count];
    for (index = 0; index < count; index++)
        [symbolEquationOutlineView expandItem:[[model equations] objectAtIndex:index]];

    count = [[model transitions] count];
    for (index = 0; index < count; index++)
        [parameterTransitionOutlineView expandItem:[[model transitions] objectAtIndex:index]];

    count = [[model specialTransitions] count];
    for (index = 0; index < count; index++)
        [specialParameterTransitionOutlineView expandItem:[[model specialTransitions] objectAtIndex:index]];

    count = [[model transitions] count];
    for (index = 0; index < count; index++)
        [metaParameterTransitionOutlineView expandItem:[[model transitions] objectAtIndex:index]];
}

- (void)_updateSelectedRuleDetails;
{
    //Inspector *inspector;
    MMRule *aRule;
    NSString *str;
    BooleanExpression *anExpression;
    int index;

    NSLog(@" > %s", _cmd);

    aRule = [self selectedRule];

    //inspector = [controller inspector];
    //[inspector inspectRule:[[model rules] objectAtIndex:selectedRow]];

    for (index = 0; index < 4; index++) {
        anExpression = [aRule getExpressionNumber:index];
        str = [anExpression expressionString];
        if (str == nil)
            str = @"";
        [[expressionForm cellAtIndex:index] setStringValue:str];
        [self setExpression:anExpression atIndex:index];
    }

    [self evaluateMatchLists];

    [self _updateRuleComment];

    //[[sender window] makeFirstResponder:delegateResponder];

    NSLog(@"<  %s", _cmd);
}

- (void)_updateRuleComment;
{
    MMRule *aRule;
    NSString *str;

    aRule = [self selectedRule];
    str = [aRule comment];
    if (str == nil)
        str = @"";

    [ruleCommentTextView setString:str];
}

- (void)setExpression:(BooleanExpression *)anExpression atIndex:(int)index;
{
    if (anExpression == expressions[index])
        return;

    [expressions[index] release];
    expressions[index] = [anExpression retain];
}

- (void)evaluateMatchLists;
{
    unsigned int expressionIndex;
    unsigned int count, index;
    PhoneList *aMatchedPhoneList;
    PhoneList *mainPhoneList = [[self model] postures];
    NSString *str;

    NSLog(@" > %s", _cmd);

    //NSLog(@"[mainPhoneList count]: %d", [mainPhoneList count]);

    count = [[model postures] count];

    for (expressionIndex = 0; expressionIndex < 4; expressionIndex++) {
        aMatchedPhoneList = [matchLists objectAtIndex:expressionIndex];
        [aMatchedPhoneList removeAllObjects];

        for (index = 0; index < count; index++) {
            MMPosture *aPhone;

            aPhone = [mainPhoneList objectAtIndex:index];
            //NSLog(@"index: %d, phone categoryList count: %d", index, [[aPhone categoryList] count]);
            if ([expressions[expressionIndex] evaluate:[aPhone categoryList]]) {
                [aMatchedPhoneList addObject:aPhone];
            }
        }
        //NSLog(@"expressions[%d]: %p, matches[%d] count: %d", expressionIndex, expressions[expressionIndex], expressionIndex, [aMatchedPhoneList count]);
    }

    str = [NSString stringWithFormat:@"Total Matches: %d", [[matchLists objectAtIndex:0] count]];
    [match1Browser setTitle:str ofColumn:0];
    [match1Browser loadColumnZero];

    str = [NSString stringWithFormat:@"Total Matches: %d", [[matchLists objectAtIndex:1] count]];
    [match2Browser setTitle:str ofColumn:0];
    [match2Browser loadColumnZero];

    str = [NSString stringWithFormat:@"Total Matches: %d", [[matchLists objectAtIndex:2] count]];
    [match3Browser setTitle:str ofColumn:0];
    [match3Browser loadColumnZero];

    str = [NSString stringWithFormat:@"Total Matches: %d", [[matchLists objectAtIndex:3] count]];
    [match4Browser setTitle:str ofColumn:0];
    [match4Browser loadColumnZero];

    [self updateCombinations];

    NSLog(@"<  %s", _cmd);
}

- (void)updateCombinations;
{
    unsigned int index;
    int totalCombinations;

    totalCombinations = [[matchLists objectAtIndex:0] count];
    for (index = 1; index < 4; index++) {
        int matchCount;

        matchCount = [[matchLists objectAtIndex:index] count];
        if (matchCount != 0)
            totalCombinations *= matchCount;
    }

    [possibleCombinationsTextField setIntValue:totalCombinations];
}

//
// NSTableView data source
//

- (int)numberOfRowsInTableView:(NSTableView *)tableView;
{
    if (tableView == ruleTableView)
        return [[model rules] count];

    if (tableView == parameterTableView || tableView == specialParameterTableView)
        return [[[self model] parameters] count];

    if (tableView == metaParameterTableView)
        return [[[self model] metaParameters] count];

    return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row;
{
    id identifier;

    identifier = [tableColumn identifier];

    if (tableView == ruleTableView) {
        MMRule *rule;

        rule = [[model rules] objectAtIndex:row];
        if ([@"hasComment" isEqual:identifier] == YES) {
            return [NSNumber numberWithBool:[rule hasComment]];
        } else if ([@"number" isEqual:identifier] == YES) {
            return [NSString stringWithFormat:@"%d.", row + 1];
        } else if ([@"rule" isEqual:identifier] == YES) {
            return [rule ruleString];
        } else if ([@"numberOfTokensConsumed" isEqual:identifier] == YES) {
            return [NSNumber numberWithInt:[rule numberExpressions]];
        }
    } else if (tableView == parameterTableView || tableView == specialParameterTableView) {
        MMParameter *parameter;

        parameter = [[[self model] parameters] objectAtIndex:row];
        if ([@"name" isEqual:identifier] == YES) {
            return [parameter symbol];
        }
    } else if (tableView == metaParameterTableView) {
        MMParameter *parameter;

        parameter = [[[self model] metaParameters] objectAtIndex:row];
        if ([@"name" isEqual:identifier] == YES) {
            return [parameter symbol];
        }
    }


    return nil;
}

//
// NSTableView delegate
//

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;
{
    NSTableView *tableView;

    tableView = [aNotification object];

    if (tableView == ruleTableView) {
        [self _updateSelectedRuleDetails];
    }
}

//
// Browser delegate methods
//

- (int)browser:(NSBrowser *)sender numberOfRowsInColumn:(int)column;
{
    if (sender == match1Browser)
        return [[matchLists objectAtIndex:0] count];

    if (sender == match2Browser)
        return [[matchLists objectAtIndex:1] count];

    if (sender == match3Browser)
        return [[matchLists objectAtIndex:2] count];

    if (sender == match4Browser)
        return [[matchLists objectAtIndex:3] count];

    return 0;
}

- (void)browser:(NSBrowser *)sender willDisplayCell:(id)cell atRow:(int)row column:(int)column;
{
    MMPosture *aPosture;

    if (sender == match1Browser) {
        aPosture = [[matchLists objectAtIndex:0] objectAtIndex:row];
        [cell setStringValue:[aPosture symbol]];
    } else if (sender == match2Browser) {
        aPosture = [[matchLists objectAtIndex:1] objectAtIndex:row];
        [cell setStringValue:[aPosture symbol]];
    } else if (sender == match3Browser) {
        aPosture = [[matchLists objectAtIndex:2] objectAtIndex:row];
        [cell setStringValue:[aPosture symbol]];
    } else if (sender == match4Browser) {
        aPosture = [[matchLists objectAtIndex:3] objectAtIndex:row];
        [cell setStringValue:[aPosture symbol]];
    }

    [cell setLeaf:YES];
}

//
// NSOutlineView data source
//

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item;
{
    if (outlineView == symbolEquationOutlineView) {
        if (item == nil)
            return [[[self model] equations] count];
        else
            return [item count];
    } else if (outlineView == parameterTransitionOutlineView || outlineView == metaParameterTransitionOutlineView) {
        if (item == nil)
            return [[[self model] transitions] count];
        else
            return [item count];
    } else if (outlineView == specialParameterTransitionOutlineView) {
        if (item == nil)
            return [[[self model] specialTransitions] count];
        else
            return [item count];
    }

    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item;
{
    if (outlineView == symbolEquationOutlineView) {
        if (item == nil)
            return [[[self model] equations] objectAtIndex:index];
        else
            return [item objectAtIndex:index];
    } else if (outlineView == parameterTransitionOutlineView || outlineView == metaParameterTransitionOutlineView) {
        if (item == nil)
            return [[[self model] transitions] objectAtIndex:index];
        else
            return [item objectAtIndex:index];
    } else if (outlineView == specialParameterTransitionOutlineView) {
        if (item == nil)
            return [[[self model] specialTransitions] objectAtIndex:index];
        else
            return [item objectAtIndex:index];
    }

    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
{
    if (outlineView == symbolEquationOutlineView) {
        return [item isKindOfClass:[NamedList class]];
    } else if (outlineView == parameterTransitionOutlineView || outlineView == metaParameterTransitionOutlineView) {
        return [item isKindOfClass:[NamedList class]];
    } else if (outlineView == specialParameterTransitionOutlineView) {
        return [item isKindOfClass:[NamedList class]];
    }

    return NO;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;
{
    id identifier;

    identifier = [tableColumn identifier];
    //NSLog(@"identifier: %@, item: %p, item class: %@", identifier, item, NSStringFromClass([item class]));

    if (outlineView == symbolEquationOutlineView) {
        if ([@"name" isEqual:identifier] == YES) {
            return [item name];
        }
    } else if (outlineView == parameterTransitionOutlineView || outlineView == metaParameterTransitionOutlineView) {
        if ([@"name" isEqual:identifier] == YES) {
            return [item name];
        }
    } else if (outlineView == specialParameterTransitionOutlineView) {
        if ([@"name" isEqual:identifier] == YES) {
            return [item name];
        }
    }

    return nil;
}

@end

//
//  MarvinManager.m
//  Marvin
//
//  Created by Christoffer Winterkvist on 15/07/14.
//
//

#import <ScriptingBridge/SBApplication.h>
#import "Coda2.h"
#import "SystemEvents.h"
#import "CodaManager.h"

#import "MarvinManager.h"
#import "MARSelectionMenu.h"
#import "MARWindowMenu.h"
#import "MARTextMenu.h"
#import "MAREOLMenu.h"
#import "MARObjectiveCMenu.h"

@interface MarvinManager ()
@property (nonatomic, strong) CodaManager *codaManager;
@property (nonatomic, strong) dispatch_queue_t bridgeQueue;
@property (nonatomic, strong) SystemEventsProcess *bridge;
@end

@implementation MarvinManager

- (instancetype)initWithPlugInsController:(CodaPlugInsController *)inController
{
    self = [super init];
    if (!self) return nil;

    self.pluginController = inController;

    [self registerMenuItems:[MARTextMenu new]];
    [self registerMenuItems:[MARSelectionMenu new]];
    [self registerMenuItems:[MARWindowMenu new]];
    [self registerMenuItems:[MAREOLMenu new]];
    [self registerMenuItems:[MARObjectiveCMenu new]];

    return self;
}

- (NSString *)name
{
    return MARPlugInName;
}

- (CodaManager *)codaManager
{
    if (_codaManager) return _codaManager;

    _codaManager = [CodaManager new];
    _codaManager.pluginController = self.pluginController;

    return _codaManager;
}

- (dispatch_queue_t)bridgeQueue
{
    if (_bridgeQueue) return _bridgeQueue;

    _bridgeQueue = dispatch_queue_create("ScriptingBridgeQueue", DISPATCH_QUEUE_SERIAL);

    return _bridgeQueue;
}

- (SystemEventsProcess *)bridge
{
    if (_bridge) return _bridge;

    _bridge = [[[SBApplication applicationWithBundleIdentifier:@"com.apple.systemevents"] applicationProcesses] objectWithName:@"Coda 2"];

    return _bridge;
}

- (void)bridge:(void(^)())block;
{
    dispatch_async(self.bridgeQueue, block);
}

- (void)registerMenuItems:(id)menu
{
    for (MARMenuItem *menuItem in [[menu class] items]) {
        [self.pluginController registerActionWithTitle:menuItem.title underSubmenuWithTitle:menuItem.submenu target:self selector:@selector(execute:) representedObject:menuItem keyEquivalent:menuItem.keyEquivalent pluginName:MARPlugInName];
    }
}

- (void)execute:(id)sender
{
    MARMenuItem *menuItem = ((NSMenuItem *)sender).representedObject;
    menuItem.command(self);
}

- (void)selectLine
{
    [self.codaManager setSelectedRange:[self.codaManager lineContentsRange]];
}

- (void)selectWord
{
    [self.codaManager setSelectedRange:[self.codaManager currentWordRange]];
}

- (void)selectPreviousWord
{
    [self.codaManager setSelectedRange:[self.codaManager previousWordRange]];
    [self.codaManager setSelectedRange:[self.codaManager currentWordRange]];
}

- (void)selectWordAbove
{
    NSCharacterSet *validSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFGHIJKOLMNOPQRSTUVWXYZÅÄÆÖØabcdefghijkolmnopqrstuvwxyzåäæöø_"];
    NSRange currentRange = [self.codaManager selectedRange];
    unichar characterAtCursorStart = [[self.codaManager contents] characterAtIndex:currentRange.location];
    unichar characterAtCursorEnd = [[self.codaManager contents] characterAtIndex:currentRange.location-1];

    if (![self.codaManager selectedRange].length && [validSet characterIsMember:characterAtCursorStart]) {
        [self selectWord];
    } else if (![self.codaManager selectedRange].length && [validSet characterIsMember:characterAtCursorEnd]) {
        [self selectPreviousWord];
    } else {
        CGEventRef event = CGEventCreateKeyboardEvent(NULL, 126, true);
        CGEventSetFlags(event, 0);
        CGEventPost(kCGHIDEventTap, event);
        CFRelease(event);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

            NSRange currentRange = [self.codaManager selectedRange];
            unichar characterAtCursorStart = [[self.codaManager contents] characterAtIndex:currentRange.location];

            if ([validSet characterIsMember:characterAtCursorStart]) {
                [self selectWord];
            } else {
                [self selectPreviousWord];
            }
        });
    }
}

- (void)selectWordBelow
{
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, 125, true);
    CGEventSetFlags(event, 0);
    CGEventPost(kCGHIDEventTap, event);
    CFRelease(event);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self selectWord];
    });
}

- (void)deleteLine
{
    [self.codaManager beginUndoGrouping];
    [self.codaManager replaceCharactersInRange:[self.codaManager lineRange] withString:@""];
    [self.codaManager endUndoGrouping];
}

- (void)duplicateLine
{
    NSRange range = [self.codaManager lineRange];
    [self.codaManager beginUndoGrouping];
    NSString *string = [self.codaManager contentsOfRange:range];
    NSRange duplicateRange = NSMakeRange(range.location+range.length, 0);
    [self.codaManager replaceCharactersInRange:duplicateRange withString:string];
    NSRange selectRange = NSMakeRange(duplicateRange.location + duplicateRange.length + string.length - 1, 0);
    [self.codaManager setSelectedRange:selectRange];
    [self.codaManager endUndoGrouping];
}

- (void)joinLine
{
    [self.codaManager replaceCharactersInRange:[self.codaManager joinRange] withString:@""];
}

- (void)uppercase
{
	[self.codaManager beginUndoGrouping];
	NSRange selectedRange = [self.codaManager selectedRange];
	NSString *uppercaseString = [[self.codaManager selectedText] uppercaseString];
	[self.codaManager replaceCharactersInRange:selectedRange withString:uppercaseString];
	[self.codaManager setSelectedRange:selectedRange];
	[self.codaManager endUndoGrouping];
}

- (void)lowercase
{
	[self.codaManager beginUndoGrouping];
	NSRange selectedRange = [self.codaManager selectedRange];
	NSString *lowercaseString = [[self.codaManager selectedText] lowercaseString];
	[self.codaManager replaceCharactersInRange:selectedRange withString:lowercaseString];
	[self.codaManager setSelectedRange:selectedRange];
	[self.codaManager endUndoGrouping];
}

- (void)openInNewWindow
{
    NSString *path = [self.codaManager path];
    [self bridge:^{
        [[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"File"] menuItems] objectWithName:@"New Window"] clickAt:nil];
        [[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"View"] menuItems] objectWithName:@"Editor"] clickAt:nil];
        [[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"View"] menuItems] objectWithName:@"Hide Sidebar"] clickAt:nil];

        NSArray *menuItems = [[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"File"] menuItems];
        if (menuItems) {
            [[menuItems objectAtIndex:11] clickAt:nil];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.0005f * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                NSError *error;
                [self.pluginController openFileAtPath:path error:&error];
                if (error) {
                    NSLog(@"error: %@", error.localizedDescription);
                }
            });
        }
    }];
}

- (void)moveToNewWindow
{
    NSString *path = [self.codaManager path];
    [self bridge:^{
        NSArray *menuItems = [[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"File"] menuItems];

        if (menuItems) {
            [[menuItems objectAtIndex:11] clickAt:nil];
            [[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"File"] menuItems] objectWithName:@"New Window"] clickAt:nil];
            [[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"View"] menuItems] objectWithName:@"Editor"] clickAt:nil];
            [[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"View"] menuItems] objectWithName:@"Hide Sidebar"] clickAt:nil];
            [[menuItems objectAtIndex:11] clickAt:nil];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.0005f * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                NSError *error;
                [self.pluginController openFileAtPath:path error:&error];
                if (error) {
                    NSLog(@"error: %@", error.localizedDescription);
                }
            });
        }
    }];
}

- (void)splitViewHorizontally
{
    [self bridge:^{
        NSArray *menuItems = [[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"View"] menuItems];
        if (menuItems) {
            SystemEventsMenuItem *find = [[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"Edit"] menuItems] objectWithName:@"Find"];
            [[[[[find menus] lastObject] menuItems] objectWithName:@"Hide Find Banner"] clickAt:nil];
            [[menuItems objectAtIndex:22] clickAt:nil];
            [[[[[find menus] lastObject] menuItems] objectWithName:@"Jump to Selection"] clickAt:nil];
        }
    }];
}


- (void)splitViewVertically
{
    [self bridge:^{
        NSArray *menuItems = [[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"View"] menuItems];
        if (menuItems) {
            SystemEventsMenuItem *find = [[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"Edit"] menuItems] objectWithName:@"Find"];
            [[[[[find menus] lastObject] menuItems] objectWithName:@"Hide Find Banner"] clickAt:nil];
            [[menuItems objectAtIndex:23] clickAt:nil];
            [[[[[find menus] lastObject] menuItems] objectWithName:@"Jump to Selection"] clickAt:nil];
        }
    }];
}

- (void)addNewlineAtEOF
{
    NSString *documentText = [self.codaManager contents];
    int eof = [documentText characterAtIndex:[documentText length]-1];
    int lastAscii = [documentText characterAtIndex:[documentText length]-2];
    if (lastAscii != 100 && eof != 10) {
        NSRange selectedRange = [self.codaManager selectedRange];
        [self.codaManager replaceCharactersInRange:NSMakeRange([[self.codaManager contents] length], 0) withString:[NSString stringWithFormat:@"%c", 10]];
        [self.codaManager setSelectedRange:selectedRange];
    }
}

- (void)removeTrailingWhitespace
{
    NSError *error = nil;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"([ \t]+)\r?\n" options:NSRegularExpressionCaseInsensitive error:&error];

    if (error) {
        NSLog(@"Couldn't create regex with given string and options");
    }

    NSString *string = [self.codaManager contents];
    NSRange currentRange = [self.codaManager selectedRange];
    NSMutableArray *ranges = [NSMutableArray array];

    [regex enumerateMatchesInString:string options:NSMatchingReportProgress range:NSMakeRange(0,[string length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if (result) {
            if (!NSLocationInRange(currentRange.location, result.range))
                [ranges addObject:result];
        }
    }];

    if (![ranges count]) return;

    NSEnumerator *enumerator = [ranges reverseObjectEnumerator];

    dispatch_async(dispatch_get_main_queue(),^{
        for (NSTextCheckingResult *textResult in enumerator) {
            NSRange range = textResult.range;
            range.length -= 1;
            [self.codaManager replaceCharactersInRange:range withString:@""];
        }

        [self bridge:^{
        	[[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"File"] menuItems] objectWithName:@"Save"] clickAt:nil];
        }];
    });
}

- (void)codaWillSave
{
    [self addNewlineAtEOF];
    [self removeTrailingWhitespace];
}

- (void)moveToEOLAndInsertLF
{
    NSRange endOfLineRange = [self.codaManager lineContentsRange];
    NSRange lineRange = [self.codaManager lineRange];
    unsigned long endOfLine = (unsigned long)endOfLineRange.location+(unsigned long)endOfLineRange.length;

    NSString *spacing = [[self.codaManager contents] substringWithRange:NSMakeRange(lineRange.location, endOfLineRange.location - lineRange.location)];

    unichar lastCharacterInLine = [[self.codaManager contents] characterAtIndex:endOfLineRange.location+endOfLineRange.length-1];
    int ascii = lastCharacterInLine;

    NSMutableString *additionalSpacing = [NSMutableString string];
    if (ascii == 123) {
        for (int x = 0; x < [self.codaManager tabWidth]; x++) {
            [additionalSpacing appendString:@" "];
        }
    }

    [self.codaManager replaceCharactersInRange:NSMakeRange(endOfLine,0) withString:[NSString stringWithFormat:@"\n%@%@", spacing, [additionalSpacing copy]]];
    [self.codaManager setSelectedRange:NSMakeRange(endOfLine+1+spacing.length+additionalSpacing.length, 0)];
}

- (void)moveToEOLAndInsertTerminator {
    [self.codaManager beginUndoGrouping];
    NSRange endOfLineRange = [self.codaManager lineContentsRange];
    unsigned long endOfLine = (unsigned long)endOfLineRange.location+(unsigned long)endOfLineRange.length;
    unichar characterAtEndOfLine = [[self.codaManager contents] characterAtIndex:endOfLine-1];

    if ((int)characterAtEndOfLine != 59) {
        [self.codaManager replaceCharactersInRange:NSMakeRange(endOfLine,0) withString:@";"];
    }

    [self.codaManager endUndoGrouping];
}

- (void)moveToEOLAndInsertTerminatorPlusLF {
    [self moveToEOLAndInsertTerminator];
    [self moveToEOLAndInsertLF];
}

- (void)selectAllWithinBracketsBackward
{
    if (self.codaManager) {
        if ([[self.codaManager selectedText] length] > 0) {
            NSRange currentRange = [self.codaManager selectedRange];
            [self.codaManager setSelectedRange:NSMakeRange((currentRange.location-1), 0)];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.0005f * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self bridge:^{
                [[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"Edit"] menuItems] objectWithName:@"Select All Within Brackets"] clickAt:nil];
                }];
            });
        } else {
            [self bridge:^{
                [[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"Edit"] menuItems] objectWithName:@"Select All Within Brackets"] clickAt:nil];
            }];
        }
    }
}

- (void)selectAllWithinBracketsForward
{
    if (self.codaManager) {
        if ([self.codaManager hasSelection]) {
            NSRange currentRange = [self.codaManager selectedRange];
            [self.codaManager setSelectedRange:NSMakeRange((currentRange.location+currentRange.length), 0)];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.0005f * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self bridge:^{
                    [[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"Edit"] menuItems] objectWithName:@"Select All Within Brackets"] clickAt:nil];
                }];
            });
        } else {
            [self bridge:^{
                [[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"Edit"] menuItems] objectWithName:@"Select All Within Brackets"] clickAt:nil];
            }];
        }
    }
}

- (void)shiftLeft
{
    [self bridge:^{
        [[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"Text"] menuItems] objectWithName:@"Shift Left"] clickAt:nil];
    }];
}

- (void)shiftRight
{
    [self bridge:^{
        [[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"Text"] menuItems] objectWithName:@"Shift Right"] clickAt:nil];
    }];
}

- (void)clearChangeMarks
{
    [self bridge:^{
        [[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"View"] menuItems] objectWithName:@"Clear Change Marks"] clickAt:nil];
    }];
}

- (void)triggerUndo
{
    [self bridge:^{
        [[[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"Edit"] menuItems] objectWithName:@"Undo"] clickAt:nil];
    }];
}

- (void)enableShowChangeMarks
{
    [self bridge:^{
        SystemEventsUIElement *menuItem = [[[[[[self.bridge menuBars] lastObject] menus] objectWithName:@"View"] menuItems] objectWithName:@"Show Change Marks"];
        SystemEventsAttribute *attribute = [[menuItem attributes] objectWithName:@"AXMenuItemMarkChar"];

        if (![[[attribute properties] objectForKey:@"value"] isEqualTo:@"✓"]) {
            [menuItem clickAt:nil];
        }
    }];
}

- (void)wrapInBrackets
{
    NSRange range = [self.codaManager selectScope:@"[]"];
    BOOL aborted = NSEqualRanges(range, self.codaManager.selectedRange);
    [self.codaManager beginUndoGrouping];
    [self.codaManager setSelectedRange:range];

    NSString *target = [self.codaManager contentsOfRange:range];
    NSString *result = [NSString stringWithFormat:@"[%@%@]", target, (aborted) ? @"" : @" " ];

    [self.codaManager replaceCharactersInRange:range withString:result];
    range.location += (range.length) + ((aborted) ? 1 : 2);
    range.length = 0;
    [self.codaManager setSelectedRange:range];
    [self.codaManager endUndoGrouping];
}

- (void)openCounterpart
{
    NSString *path = [self.codaManager path];
	NSString *extension = ([[path pathExtension] isEqualToString:@"m"]) ? @"h" : @"m" ;
    NSString *counterPath = [NSString stringWithFormat:@"%@.%@", [path stringByDeletingPathExtension], extension];

    if ([[NSFileManager defaultManager] fileExistsAtPath:counterPath]) {
        [self openFileAtPath:counterPath];
    }

}

- (void)openFileAtPath:(NSString *)path
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/usr/local/bin/coda" isDirectory:NO]) {
        [NSTask launchedTaskWithLaunchPath:@"/usr/local/bin/coda" arguments:@[@"-rp", path]];
    } else {
        [NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" arguments:@[@"-a", @"Coda 2", path]];
    }
}

@end

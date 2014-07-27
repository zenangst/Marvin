//
//  MARManipulationMenu.m
//  Marvin
//
//  Created by Christoffer Winterkvist on 16/07/14.
//
//

#import "MARTextMenu.h"

@implementation MARTextMenu

+ (NSArray *)items
{
    NSMutableArray *items = [NSMutableArray array];

    MARMenuItem *deleteLine = [[MARMenuItem alloc] initWithTitle:@"Delete Line"
                                                         submenu:[self.class menuTitle]
                                                   keyEquivalent:@""
                                                         command:^(MarvinManager *manager){
                                                             [manager deleteLine];
                                                         }];
    [items addObject:deleteLine];

    MARMenuItem *duplicateLine = [[MARMenuItem alloc] initWithTitle:@"Duplicate Line"
                                                         submenu:[self.class menuTitle]
                                                   keyEquivalent:@""
                                                         command:^(MarvinManager *manager){
                                                             [manager duplicateLine];
                                                         }];
    [items addObject:duplicateLine];

    MARMenuItem *joinLine = [[MARMenuItem alloc] initWithTitle:@"Join Line"
                                                         submenu:[self.class menuTitle]
                                                   keyEquivalent:@""
                                                         command:^(MarvinManager *manager){
                                                             [manager joinLine];
                                                         }];
    [items addObject:joinLine];

    MARMenuItem *uppercase = [[MARMenuItem alloc] initWithTitle:@"Uppercase"
                                                       submenu:[self.class menuTitle]
                                                 keyEquivalent:@""
                                                       command:^(MarvinManager *manager){
                                                           [manager uppercase];
                                                       }];
    [items addObject:uppercase];

    MARMenuItem *lowercase = [[MARMenuItem alloc] initWithTitle:@"Lowercase"
                                                        submenu:[self.class menuTitle]
                                                  keyEquivalent:@""
                                                        command:^(MarvinManager *manager){
                                                            [manager uppercase];
                                                        }];
    [items addObject:lowercase];
    
    MARMenuItem *wrapInBrackets = [[MARMenuItem alloc] initWithTitle:@"Wrap in Brackets"
                                                        submenu:[self.class menuTitle]
                                                  keyEquivalent:@""
                                                        command:^(MarvinManager *manager){
                                                            [manager wrapInBrackets];
                                                        }];
    [items addObject:wrapInBrackets];

    return items;
}

+ (NSString *)menuTitle
{
    return @"Text";
}

@end

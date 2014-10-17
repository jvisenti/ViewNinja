//
//  RZNinjaWindow.m
//  RZViewActionTest
//
//  Created by Rob Visentin on 10/17/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

#import "RZNinjaWindow.h"

NSString* const kRZWindowWillSendTouchesNotificaton = @"RZWindowWillSendTouchesNotification";
NSString* const kRZWindowTouchesKey = @"RZWindowTouches";

@implementation RZNinjaWindow

- (void)sendEvent:(UIEvent *)event
{
    if ( event.type == UIEventTypeTouches ) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kRZWindowWillSendTouchesNotificaton object:nil userInfo:@{ kRZWindowTouchesKey : [[event allTouches] allObjects]}];
    }
    
    [super sendEvent:event];
}

@end

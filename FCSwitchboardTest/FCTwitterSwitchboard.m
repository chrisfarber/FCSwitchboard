//
//  FCTwitterSwitchboard.m
//  FCSwitchboardTest
//
//  Created by Chris Farber on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "FCTwitterSwitchboard.h"

@implementation FCTwitterSwitchboard

- init
{
    if ((self = [super init])) {
        [self setBaseURL:[NSURL URLWithString:@"http://twitter.com"]];
    }
    return self;
}

- (id<FCSwitchboardConnection>)publicTweetsWithBlock:(void (^)(NSArray *, NSError *))block
{
    return [self sendRequest:@"GET" forPath:@"statuses/public_timeline.json" withData:nil block:block];
}

@end

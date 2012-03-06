//
//  FCTwitterSwitchboard.h
//  FCSwitchboardTest
//
//  Created by Chris Farber on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "FCSwitchboard.h"

@interface FCTwitterSwitchboard : FCSwitchboard

- (id <FCSwitchboardConnection>)publicTweetsWithBlock:(void (^)(NSArray *, NSError *))block;

@end

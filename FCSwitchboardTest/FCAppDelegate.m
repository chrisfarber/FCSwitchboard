//
//  FCAppDelegate.m
//  FCSwitchboardTest
//
//  Created by Chris Farber on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "FCAppDelegate.h"
#import "FCTwitterSwitchboard.h"

@implementation FCAppDelegate

@synthesize window = _window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
}

- (IBAction)logTweets:(id)sender
{
    [[FCTwitterSwitchboard switchboard] publicTweetsWithBlock:^(NSArray *tweets, NSError *error) {
        if (error) {
            NSLog(@"got error: %@", error);
            return;
        }
        for (NSDictionary *tweetInfo in tweets) {
            NSLog(@"%@: %@", [tweetInfo valueForKeyPath:@"user.screen_name"],
                  [tweetInfo valueForKey:@"text"]);
        }
    }];
}

@end

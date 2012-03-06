//
//  FCAppDelegate.h
//  FCSwitchboardTest
//
//  Created by Chris Farber on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FCAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

- (IBAction)logTweets:(id)sender;

@end

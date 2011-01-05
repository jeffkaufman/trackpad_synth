//
//  TrackpadSynthAppDelegate.m
//  TrackpadSynth
//
//  Created by Jeff Kaufman on 1/2/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "TrackpadSynthAppDelegate.h"

@implementation TrackpadSynthAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application 
}

-(BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)theApplication
{
	return YES;
}
@end

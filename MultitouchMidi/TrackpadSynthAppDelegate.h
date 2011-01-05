//
//  TrackpadSynthAppDelegate.h
//  TrackpadSynth
//
//  Created by Jeff Kaufman on 1/2/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TrackpadSynthAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end

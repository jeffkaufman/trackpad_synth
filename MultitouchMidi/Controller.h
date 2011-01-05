//
//  Controller.h
//  TrackpadSynth
//
//  Created by Jeff Kaufman on 1/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface Controller : NSObject {
    IBOutlet id keyDropdown;
    IBOutlet id octavesDropdown;
    IBOutlet id channelDropdown;
	IBOutlet id useVelocityCheck;
	IBOutlet id sendAftertouchCheck;
	IBOutlet id sendChannelPressureCheck;
	IBOutlet id fakeChannelPressureCheck;
	IBOutlet id scaleDropdown;
	IBOutlet id check0;
	IBOutlet id check1;
	IBOutlet id check2;
	IBOutlet id check3;
	IBOutlet id check4;
	IBOutlet id check5;
	IBOutlet id check6;
	IBOutlet id check7;
	IBOutlet id check8;
	IBOutlet id check9;
	IBOutlet id checkA;
	IBOutlet id checkB;
}
-(IBAction)useVelocityClicked:(id)sender;
-(IBAction)sendAftertouchClicked:(id)sender;
-(IBAction)sendChannelPressureClicked:(id)sender;
-(IBAction)fakeChannelPressureClicked:(id)sender;
-(IBAction)check0Clicked:(id)sender;
-(IBAction)check1Clicked:(id)sender;
-(IBAction)check2Clicked:(id)sender;
-(IBAction)check3Clicked:(id)sender;
-(IBAction)check4Clicked:(id)sender;
-(IBAction)check5Clicked:(id)sender;
-(IBAction)check6Clicked:(id)sender;
-(IBAction)check7Clicked:(id)sender;
-(IBAction)check8Clicked:(id)sender;
-(IBAction)check9Clicked:(id)sender;
-(IBAction)checkAClicked:(id)sender;
-(IBAction)checkBClicked:(id)sender;

@end

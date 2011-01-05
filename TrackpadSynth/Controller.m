//
//  Controller.m
//  TrackpadSynth
//
//  Created by Jeff Kaufman on 1/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Controller.h"
#import "../trackmidilib.h"

@implementation Controller

-(IBAction)useVelocityClicked:(id)sender
{
	tml_use_velocity = [sender state];
}

-(IBAction)sendAftertouchClicked:(id)sender 
{
	tml_send_aftertouch = [sender state];
}

-(IBAction)sendChannelPressureClicked:(id)sender
{
	tml_send_channel_pressure = [sender state];
}

-(IBAction)fakeChannelPressureClicked:(id)sender
{
	tml_send_channel_volume = [sender state];
}

-(IBAction)check0Clicked:(id)sender;
{
	tml_on[0] = [sender state];
	tml_recompute_scale();
}

-(IBAction)check1Clicked:(id)sender;
{
	tml_on[1] = [sender state];
	tml_recompute_scale();
}

-(IBAction)check2Clicked:(id)sender;
{
	tml_on[2] = [sender state];
	tml_recompute_scale();
}

-(IBAction)check3Clicked:(id)sender;
{
	tml_on[3] = [sender state];
	tml_recompute_scale();
}

-(IBAction)check4Clicked:(id)sender;
{
	tml_on[4] = [sender state];
	tml_recompute_scale();
}

-(IBAction)check5Clicked:(id)sender;
{
	tml_on[5] = [sender state];
	tml_recompute_scale();
}

-(IBAction)check6Clicked:(id)sender;
{
	tml_on[6] = [sender state];
	tml_recompute_scale();
}

-(IBAction)check7Clicked:(id)sender;
{
	tml_on[7] = [sender state];
	tml_recompute_scale();
}

-(IBAction)check8Clicked:(id)sender;
{
	tml_on[8] = [sender state];
	tml_recompute_scale();
}

-(IBAction)check9Clicked:(id)sender;
{
	tml_on[9] = [sender state];
	tml_recompute_scale();
}

-(IBAction)checkAClicked:(id)sender;
{
	tml_on[10] = [sender state];
	tml_recompute_scale();
}

-(IBAction)checkBClicked:(id)sender;
{
	tml_on[11] = [sender state];
	tml_recompute_scale();
}


@end

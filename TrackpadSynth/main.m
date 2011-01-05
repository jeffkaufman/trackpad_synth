//
//  main.m
//  TrackpadSynth
//
//  Created by Jeff Kaufman on 1/2/11.
//  Copyright 2011 Jeff Kaufman.  All code under GPL.
//

//#import "../trackmidilib.h"
int main(int argc, char *argv[])
{
	tml_setup();
	tml_set_scale("0123456789AB");
    return NSApplicationMain(argc,  (const char **) argv);
}

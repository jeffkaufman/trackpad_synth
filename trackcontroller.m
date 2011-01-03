#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include "trackmidilib.h"

void usage() {
  printf("Usage: trackcontroller [options]\n");
  printf("\n");
  printf("Options:\n");
  printf("  -k [KEY]  Play in the given key.  Allowable keys are\n");
  printf("            'A'-'G' followed by an optional '#' or 'b'.\n");
  printf("            Default is D.\n");
  printf("  -H        Harmonic minor mode\n");
  printf("  -r        Relative/natural minor mode\n");
  printf("  -x        Mixolidian mode\n");
  printf("  -K        A Klezmer mode (flat 2, sharp 6)\n");
  printf("  -5        Pentatonic scale\n");
  printf("  -C [nnn]  Specify scale (ex: '024579B')\n");
  printf("  -S        Send SKINI to stdout instead of MIDI from a\n");
  printf("            virtual source.\n");
  printf("  -V        Use the far left of the controller as a\n");
  printf("            volume control.\n");
  printf("  -o [N]    Divide the trackpad vertically into this many\n");
  printf("            octaves.  Default is 5.\n");
  printf("  -s [N]    Octave Shift: how far down to shift from the\n");
  printf("            top of our range.  Default is 3.\n");
  printf("  -v        Use velocity.  When pressing keys, set midi\n");
  printf("            velocity to the finger width detected on the\n");
  printf("            trackpad.\n");
  printf("  -a        Send aftertouch midi messages based on how fat\n");
  printf("            each finger is\n");
  printf("  -c [N]    Send on channel N.  Default is 3.\n");
  printf("  -p        Send channel pressure messages based on how fat\n");
  printf("            all the fingers are on average,\n");
  printf("  -P        Fake channel pressure using volume instead.\n");
  printf("  -h        Print this usage.\n");
  printf("\n");
  printf("Example:\n");
  printf("  # play in Ab, four octaves, faking channel pressure\n");
  printf("  trackcontroller -k Ab -o 4 -P\n");
  printf("\n");
  printf("Many options only work with MIDI.\n");
  printf("\n");
  printf("If you want to play in non-major modes, use some music theory:\n");
  printf("pick an appropriate major scale and scale degree to start on.\n\n");
}

int main(int argc, char** argv) {

  int optch;
  while ((optch = getopt(argc, argv, "hk:HrxK5C:SVo:s:vac:pP")) != -1) {
    switch (optch) {
    case 'k':
      while (optarg[0] == ' ') {
	optarg++;
      }
      if (optarg[0] >= 'A' && optarg[0] <= 'G') {
	switch(optarg[0]) {
	case 'A': tml_base_pitch = TML_A440; break;
	case 'B': tml_base_pitch = TML_A440+2; break;
	case 'C': tml_base_pitch = TML_A440+3; break;
	case 'D': tml_base_pitch = TML_A440+5; break;
	case 'E': tml_base_pitch = TML_A440+7; break;
	case 'F': tml_base_pitch = TML_A440+8; break;
	case 'G': tml_base_pitch = TML_A440+10; break;
	default:
	  printf("error: -k argument needs a key between A and G\n");
	  return 0;
	}

	if (optarg[1] == '#') {
	  tml_base_pitch += 1;
	}
	if (optarg[1] == 'b') {
	  tml_base_pitch -= 1;
	}
      }
      break;
    case 'H': /* harmonic minor */
      tml_scale = "023579B";
      break;
    case 'r': /* relative minor */
      tml_scale = "023579A";
      break;
    case 'x': /* mixolidian */
      tml_scale = "024579A";
      break;
    case 'K': /* klezmer */
      tml_scale = "014578B";
      break;
    case '5': /* pentatonic */
      tml_scale = "0357A";
      break;
    case 'C': /* specified tml_scale */
      tml_scale = malloc(strlen(optarg));
      strcpy(tml_scale, optarg);
      break;
    case 'S':
      tml_midi = 0;
      break;
    case 'V':
      tml_use_sidevolume = 1;
      break;
    case 'o':
      tml_n_octaves = atoi(optarg);
      if (tml_n_octaves < 2 || tml_n_octaves > 10) {
	printf("error: -o argument needs number of octaves between 2 and 10\n");
	return 0;
      }
      break;
    case 's':
      tml_octave_shift = atoi(optarg);
      if (tml_octave_shift < 1 || tml_octave_shift > 6) {
	printf("error: -s argument needs number of octaves between 1 and 6\n");
	return 0;
      }
      break;
    case 'v':
      tml_use_velocity = 1;
      break;
    case 'a':
      tml_send_aftertouch = 1;
      break;
    case 'c':
      tml_channel = atoi(optarg);
      if (tml_channel < 1 || tml_channel > 16) {
	printf("error: -c argument needs channel between 1 and 16\n");
	return 0;
      }
      break;
    case 'p':
      tml_send_channel_pressure = 1;
      break;
    case 'P':
      tml_send_channel_volume = 1;
      break;
    case '?':
    case 'h':
    default:
      usage();
      return 0;
    }
  }
  tml_setup();  /* doesn't return */
  return 0;
}

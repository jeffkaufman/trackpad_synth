#include <math.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include "trackmidilib.h"

int tml_use_sidevolume = 0; /* does the side of the trackpad control volume? */
int tml_use_velocity = 0; /* does how hard you hit notes matter? */
int tml_n_octaves = 5; /* how many octaves on the trackpad? */
int tml_octave_shift = 3; /* how far lower than the top of our range should we be at? */
int tml_midi = 1; /* should we use midi? */
int tml_send_aftertouch = 0; /* send aftertouch messages */
int tml_send_channel_pressure = 0; /* send channel pressure messages */
int tml_send_channel_volume = 0; /* send channel pressure as a volume message */
int tml_channel = 3; /* which channel (1-16) to send on) */
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


void tml_die(char *errmsg) {
  printf("%s\n",errmsg);
  exit(-1);
}

void tml_attempt(OSStatus result, char* errmsg) {
  if (result != noErr) {
    tml_die(errmsg);
  }
}

#define TML_MAX_NOTES 128

typedef struct { float x,y; } mtPoint;
typedef struct { mtPoint pos,vel; } mtReadout;

typedef struct {
  int frame;
  double timestamp;
  int identifier, state, foo3, foo4;
  mtReadout normalized;
  float size;
  int zero1;
  float angle, majorAxis, minorAxis; // ellipsoid
  mtReadout mm;
  int zero2[2];
  float unk2;
} Finger;

typedef struct {
  int timeOn;
  int val;
  int lastval;
} TmlNote;

typedef void *MTDeviceRef;
typedef int (*MTContactCallbackFunction)(int,Finger*,int,double,int);

MTDeviceRef MTDeviceCreateDefault();
void MTRegisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
void MTDeviceStart(MTDeviceRef, int); // thanks comex

TmlNote tml_notes[TML_MAX_NOTES];
MIDIClientRef tml_midiclient;
MIDIEndpointRef tml_midiendpoint;

void tml_compose_midi(char actionType, int noteNo, int v, Byte* msg) {

  if (actionType == 'O') { /* on */
    msg[0] = 0x90;
    msg[2] = 82;
  }
  else if (actionType == 'o') { /* off */
    msg[0] = 0x80;
    msg[2] = 0;
  }
  else if (actionType == 'A') { /* aftertouch */
    msg[0] = 0xA0;
    msg[2] = 82;
  }
  else if (actionType == 'C') { /* channel pressure */
    msg[0] = 0xD0;
    msg[2] = 0;
  }    
  else if (actionType == 'V') { /* volume */
    msg[0] = 0xB0;
    msg[2] = 0;
  }

  if (v != -1) {
    if (v > TML_MAX_NOTES) {
      v = TML_MAX_NOTES-1;
    }
    msg[2] = v;
  }
  msg[0] += ((tml_channel-1) & 0xFF);
  
  msg[1] = noteNo;
}


#define TML_PACKET_BUF_SIZE (3+64) /* 3 for message, 32 for structure vars */
void tml_send_midi(char actionType, int noteNo, int v) {
  Byte buffer[TML_PACKET_BUF_SIZE];
  Byte msg[3];
  tml_compose_midi(actionType, noteNo, v, msg);

  MIDIPacketList *packetList = (MIDIPacketList*) buffer;
  MIDIPacket *curPacket = MIDIPacketListInit(packetList);

  curPacket = MIDIPacketListAdd(packetList,
				TML_PACKET_BUF_SIZE,
				curPacket,
				AudioGetCurrentHostTime(),
				actionType == 'C' ? 2 : 3,
				msg);
  if (!curPacket) {
      tml_die("packet list allocation failed");
  }
  
  tml_attempt(MIDIReceived(tml_midiendpoint, packetList), "error sending midi");
}

void tml_volume(int amt) {
  if (tml_midi) {
    tml_send_midi('V', 7 /* coarse volume */, amt);
  }
  else {
    /* unsupported */
  }
}

void tml_aftertouch(int note, int amt) {
  if (tml_midi && tml_send_aftertouch) {
    tml_send_midi('A', note, amt);
  }
  else {
    /* unsupported */
  }
}

void tml_channel_pressure(int amt) {
  if (tml_midi) {
    tml_send_midi('C', amt, -1);
  }
  else {
    /* unsupported */
  }
}

void tml_note_on(int note, int val) {
  if (tml_midi) {
    tml_send_midi('O', note, val);
  }
  else {
    printf("NoteOn          0.0 %d %d %d\n", note, note, val);
    fflush(stdout);
  }
}

void tml_note_off(int note, int val) {
  if (tml_midi) {
    tml_send_midi('o', note, val);
  }
  else {
    printf("NoteOff         0.0 %d %d 0\n", note, note);
    fflush(stdout);
  }
}

/* x should be beween 0 and 1 */
#define TML_A440 69
int tml_base_pitch = TML_A440; 
char *tml_scale = "024579B";
int tml_scale_note(float x) {
  int n;
  switch(tml_scale[(int)(x*strlen(tml_scale))]) {
  case '0': n = 0; break;
  case '1': n = 1; break;
  case '2': n = 2; break;
  case '3': n = 3; break;
  case '4': n = 4; break;
  case '5': n = 5; break;
  case '6': n = 6; break;
  case '7': n = 7; break;
  case '8': n = 8; break;
  case '9': n = 9; break;
  case 'A': n = 10; break;
  case 'B': n = 11; break;
  }
  return n + tml_base_pitch;
}

void tml_do_note(Finger *f) {
  float x = f->normalized.pos.x;
  float y = f->normalized.pos.y;

  if (tml_use_sidevolume) {
    if (x < 1.0/20) {
      tml_volume(y*(TML_MAX_NOTES-1));
      return;
    }
    else {
      x = x*19.0/20 + 1.0/20;
    }
  }

  float v_x = f->normalized.vel.x;
  float v_y = f->normalized.vel.y;
  float v = f->size;

  int octave = (int)((tml_n_octaves-1) * y * 2 + 1)/2 - tml_octave_shift;

  tml_notes[tml_scale_note(x)+12*octave].val = v*128;
}

#define TML_MAX_TOUCH_LATENCY 6
int tml_callback(int device, Finger *data, int nFingers, double timestamp, int frame) {

  for (int i=0; i<nFingers; i++) {
    tml_do_note(&data[i]);
  }

  for (int i=0 ; i < TML_MAX_NOTES ; i++) {
    if (tml_use_velocity) {
      if (tml_notes[i].lastval && !tml_notes[i].val) {
	tml_note_off(i, -1);
	tml_notes[i].timeOn = 0;
      }
      else if (tml_notes[i].val) {
	if (tml_notes[i].timeOn != -1) {
	  tml_notes[i].timeOn += 1;
	  if (tml_notes[i].lastval && 
	      (tml_notes[i].timeOn == TML_MAX_TOUCH_LATENCY ||
	       tml_notes[i].val < tml_notes[i].lastval)) {
	    tml_note_on(i, tml_notes[i].val);
	    tml_notes[i].timeOn = -1;
	  }
	}
	else if (tml_notes[i].val != tml_notes[i].lastval) {
	  tml_aftertouch(i,tml_notes[i].val);
	}
      }
    }
    else { /* no velocity */
      if (tml_notes[i].lastval && !tml_notes[i].val) {
	tml_note_off(i, tml_notes[i].lastval);
      }
      else if (tml_notes[i].val && tml_notes[i].val != tml_notes[i].lastval) {
	if (!tml_notes[i].lastval) {
	  tml_note_on(i, -1);
	}
	tml_aftertouch(i,tml_notes[i].val);
      }
    }

    tml_notes[i].lastval = tml_notes[i].val;
    tml_notes[i].val = 0; /* will be overwritten in do_note if note is actually on */
  }

  if (tml_send_channel_pressure || tml_send_channel_volume) {
    int pressure_sum = 0;
    int notes_on = 0;
    for (int i = 0 ; i < TML_MAX_NOTES-1 ; i++) {
      if (tml_notes[i].lastval) {
	pressure_sum += tml_notes[i].lastval;
	notes_on += 1;
      }
    }
    
    if (notes_on) {
      if (tml_send_channel_pressure) {
	tml_channel_pressure(pressure_sum / notes_on);
      }
      if (tml_send_channel_volume) {
	tml_volume(pressure_sum / notes_on);
      }
    }
  }

  return 0;
}


void tml_setup_trackpad() {
  MTDeviceRef dev = MTDeviceCreateDefault();
  MTRegisterContactFrameCallback(dev, tml_callback);
  MTDeviceStart(dev, 0);
  sleep(-1);
}

void tml_setup_midi() {
  tml_attempt(MIDIClientCreate 
	      (CFStringCreateWithCString( NULL, "touchpad", kCFStringEncodingASCII ),
	       NULL, NULL, &tml_midiclient),
	      "creating OS-X MIDI client object." );

  tml_attempt(MIDISourceCreate
	      (tml_midiclient, 
	       CFStringCreateWithCString( NULL, "touchpad", kCFStringEncodingASCII ),
	       &tml_midiendpoint),
	      "creating OS-X virtual MIDI source." );  
}

void tml_setup_general() {
  for (int i = 0 ; i < TML_MAX_NOTES; i++) {
    tml_notes[i].val = 0;
    tml_notes[i].lastval = 0;
    tml_notes[i].timeOn = 0;
  }
  tml_volume(100);
}

void tml_setup() {
  tml_setup_general();
  tml_setup_midi();
  tml_setup_trackpad(); /* doesn't return */
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

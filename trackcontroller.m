#include <math.h>
#include <stdio.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <CoreMIDI/MIDIServices.h>
#include <CoreAudio/HostTime.h>

#define BUF_SIZE 256

int use_sidevolume = 0; /* does the side of the trackpad control volume? */
int use_velocity = 0; /* does how hard you hit notes matter? */
int n_octaves = 5; /* how many octaves on the trackpad? */
int octave_shift = 3; /* how far lower than the top of our range should we be at? */
int midi = 1; /* should we use midi? */
int send_aftertouch = 0; /* send aftertouch messages */
int send_channel_pressure = 0; /* send channel pressure messages */
int send_channel_volume = 0; /* send channel pressure as a volume message */
int channel = 3; /* which channel (1-16) to send on) */
void usage() {
  printf("Usage: trackcontroller [options]\n");
  printf("\n");
  printf("Options:\n");
  printf("  -k [KEY]  Play in the given key.  Allowable keys are\n");
  printf("            'A'-'G' followed by an optional '#' or 'b'.\n");
  printf("            Default is D.\n");
  printf("  -h        Harmonic minor mode\n");
  printf("  -r        Relative/natural minor mode\n");
  printf("  -x        Mixolidian mode\n");
  printf("  -K        A Klezmer mode (flat 2, sharp 6)\n");
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


void die(char *errmsg) {
  printf("%s\n",errmsg);
  exit(-1);
}

void attempt(OSStatus result, char* errmsg) {
  if (result != noErr) {
    die(errmsg);
  }
}

#define MAX_NOTES 128

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
} Note;

typedef void *MTDeviceRef;
typedef int (*MTContactCallbackFunction)(int,Finger*,int,double,int);

MTDeviceRef MTDeviceCreateDefault();
void MTRegisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
void MTDeviceStart(MTDeviceRef, int); // thanks comex

Note notes[MAX_NOTES];
MIDIClientRef midiclient;
MIDIEndpointRef midiendpoint;

void compose_midi(char actionType, int noteNo, int v, Byte* msg) {

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
    if (v > MAX_NOTES) {
      v = MAX_NOTES-1;
    }
    msg[2] = v;
  }
  msg[0] += ((channel-1) & 0xFF);
  
  msg[1] = noteNo;
    
}


#define PACKET_BUF_SIZE (3+64) /* 3 for message, 32 for structure vars */
void send_midi(char actionType, int noteNo, int v) {
  Byte buffer[PACKET_BUF_SIZE];
  Byte msg[3];
  compose_midi(actionType, noteNo, v, msg);

  MIDIPacketList *packetList = (MIDIPacketList*) buffer;
  MIDIPacket *curPacket = MIDIPacketListInit(packetList);

  //printf("%x %x %x\n", msg[0], msg[1], msg[2]);

  curPacket = MIDIPacketListAdd(packetList,
				PACKET_BUF_SIZE,
				curPacket,
				AudioGetCurrentHostTime(),
				actionType == 'C' ? 2 : 3,
				msg);
  if (!curPacket) {
      die("packet list allocation failed");
  }
  
  attempt(MIDIReceived(midiendpoint, packetList), "error sending midi");
}

void volume(int amt) {
  if (midi) {
    send_midi('V', 7 /* coarse volume */, amt);
    //send_midi('V', 39 /* fine volume */, amt);
  }
  else {
    /* unsupported */
  }
}

void aftertouch(int note, int amt) {
  if (midi && send_aftertouch) {
    send_midi('A', note, amt);
  }
  else {
    /* unsupported */
  }
}

void channel_pressure(int amt) {
  if (midi) {
    send_midi('C', amt, -1);
  }
  else {
    /* unsupported */
  }
}

void note_on(int note, int val) {
  if (midi) {
    send_midi('O', note, val);
  }
  else {
    printf("NoteOn          0.0 %d %d %d\n", note, note, val);
    fflush(stdout);
  }
}

void note_off(int note, int val) {
  if (midi) {
    send_midi('o', note, val);
  }
  else {
    printf("NoteOff         0.0 %d %d 0\n", note, note);
    fflush(stdout);
  }
}

void print_finger(Finger *f) {
  printf("Frame %7d: Angle %6.2f, ellipse %6.3f x%6.3f; "
	      "position (%6.3f,%6.3f) vel (%6.3f,%6.3f) "
	   "ID %d, state %d [%d %d?] size %6.3f, %6.3f?\n",
	   f->frame,
	   f->angle * 90 / atan2(1,0),
	   f->majorAxis,
	   f->minorAxis,
	   f->normalized.pos.x,
	   f->normalized.pos.y,
	   f->normalized.vel.x,
	   f->normalized.vel.y,
	   f->identifier, f->state, f->foo3, f->foo4,
	   f->size, f->unk2);
}

/* x should be beween 0 and 1 */
#define A440 69
int base_pitch = A440; 
char *scale = "024579B";
int scale_note(float x) {
  int n;
  switch(scale[(int)(x*7)]) {
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
  return n+base_pitch;
}

void do_note(Finger *f) {
  float x = f->normalized.pos.x;
  float y = f->normalized.pos.y;

  if (use_sidevolume) {
    if (x < 1.0/20) {
      volume(y*(MAX_NOTES-1));
      return;
    }
    else {
      x = x*19.0/20 + 1.0/20;
    }
  }

  float v_x = f->normalized.vel.x;
  float v_y = f->normalized.vel.y;
  float v = f->size;

  int octave = (int)((n_octaves-1) * y * 2 + 1)/2 - octave_shift;

  notes[scale_note(x)+12*octave].val = v*128;
}

#define MAX_TOUCH_LATENCY 6
int callback(int device, Finger *data, int nFingers, double timestamp, int frame) {

  for (int i=0; i<nFingers; i++) {
    do_note(&data[i]);
  }

  for (int i=0 ; i < MAX_NOTES ; i++) {
    if (use_velocity) {
      if (notes[i].lastval && !notes[i].val) {
	note_off(i, -1);
	notes[i].timeOn = 0;
      }
      else if (notes[i].val) {
	if (notes[i].timeOn != -1) {
	  notes[i].timeOn += 1;
	  if (notes[i].lastval && 
	      (notes[i].timeOn == MAX_TOUCH_LATENCY ||
	       notes[i].val < notes[i].lastval)) {
	    note_on(i, notes[i].val);
	    notes[i].timeOn = -1;
	  }
	}
	else if (notes[i].val != notes[i].lastval) {
	  aftertouch(i,notes[i].val);
	}
      }
    }
    else { /* no velocity */
      if (notes[i].lastval && !notes[i].val) {
	note_off(i, notes[i].lastval);
      }
      else if (notes[i].val && notes[i].val != notes[i].lastval) {
	if (!notes[i].lastval) {
	  note_on(i, -1);
	}
	aftertouch(i,notes[i].val);
      }
    }

    notes[i].lastval = notes[i].val;
    notes[i].val = 0; /* will be overwritten in do_note if note is actually on */
  }

  if (send_channel_pressure || send_channel_volume) {
    int pressure_sum = 0;
    int notes_on = 0;
    for (int i = 0 ; i < MAX_NOTES-1 ; i++) {
      if (notes[i].lastval) {
	pressure_sum += notes[i].lastval;
	notes_on += 1;
      }
    }
    
    if (notes_on) {
      if (send_channel_pressure) {
	channel_pressure(pressure_sum / notes_on);
      }
      if (send_channel_volume) {
	volume(pressure_sum / notes_on);
      }
    }
  }

  return 0;
}

int main(int argc, char** argv) {

  int optch;
  while ((optch = getopt(argc, argv, "k:hrxKSVo:s:vac:pP")) != -1) {
    switch (optch) {
    case 'k':
      while (optarg[0] == ' ') {
	optarg++;
      }
      if (optarg[0] >= 'A' && optarg[0] <= 'G') {
	switch(optarg[0]) {
	case 'A': base_pitch = A440; break;
	case 'B': base_pitch = A440+2; break;
	case 'C': base_pitch = A440+3; break;
	case 'D': base_pitch = A440+5; break;
	case 'E': base_pitch = A440+7; break;
	case 'F': base_pitch = A440+8; break;
	case 'G': base_pitch = A440+10; break;
	default:
	  printf("error: -k argument needs a key between A and G\n");
	  return 0;
	}

	if (optarg[1] == '#') {
	  base_pitch += 1;
	}
	if (optarg[1] == 'b') {
	  base_pitch -= 1;
	}
      }
      break;
    case 'h': /* harmonic minor */
      scale = "023579B";
      break;
    case 'r': /* relative minor */
      scale = "023579A";
      break;
    case 'x': /* mixolidian */
      scale = "024579A";
      break;
    case 'K': /* klezmer */
      scale = "014578B";
      break;
    case 'S':
      midi = 0;
      break;
    case 'V':
      use_sidevolume = 1;
      break;
    case 'o':
      n_octaves = atoi(optarg);
      if (n_octaves < 2 || n_octaves > 10) {
	printf("error: -o argument needs number of octaves between 2 and 10\n");
	return 0;
      }
      break;
    case 's':
      octave_shift = atoi(optarg);
      if (octave_shift < 1 || octave_shift > 6) {
	printf("error: -s argument needs number of octaves between 1 and 6\n");
	return 0;
      }
      break;
    case 'v':
      use_velocity = 1;
      break;
    case 'a':
      send_aftertouch = 1;
      break;
    case 'c':
      channel = atoi(optarg);
      if (channel < 1 || channel > 16) {
	printf("error: -c argument needs channel between 1 and 16\n");
	return 0;
      }
      break;
    case 'p':
      send_channel_pressure = 1;
      break;
    case 'P':
      send_channel_volume = 1;
      break;
    case '?':
    default:
      usage();
      return 0;
    }
  }

  attempt(MIDIClientCreate( CFStringCreateWithCString( NULL, "touchpad", kCFStringEncodingASCII ),
			    NULL, NULL, &midiclient),
	  "creating OS-X MIDI client object." );

  attempt(MIDISourceCreate(midiclient, 
			   CFStringCreateWithCString( NULL, "touchpad", kCFStringEncodingASCII ),
			   &midiendpoint),
	  "creating OS-X virtual MIDI source." );

  for (int i = 0 ; i < MAX_NOTES; i++) {
    notes[i].val = 0;
    notes[i].lastval = 0;
    notes[i].timeOn = 0;
  }
  volume(100);

  MTDeviceRef dev = MTDeviceCreateDefault();
  MTRegisterContactFrameCallback(dev, callback);
  MTDeviceStart(dev, 0);
  //printf("Ctrl-C to abort\n");
  sleep(-1);

  MIDIClientDispose(midiclient);
  MIDIEndpointDispose(midiendpoint);

  return 0;
}


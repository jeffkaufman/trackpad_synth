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

/* remove this to send all notes out with a velocity of 82 */
#define USE_VELOCITY

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
#define N_OCTAVES 4

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
int midi = 1;
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

  if (v != -1) {
    if (v > 127) {
      v = 127;
    }
    msg[2] = v;
  }

  Byte channel = 2;
  msg[0] += channel;
  
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
				3,
				msg);
  if (!curPacket) {
      die("packet list allocation failed");
  }
  
  attempt(MIDIReceived(midiendpoint, packetList), "error sending midi");
}

void aftertouch(int note, int amt) {
  if (midi) {
    send_midi('A', note, amt);
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

  float v_x = f->normalized.vel.x;
  float v_y = f->normalized.vel.y;
  float v = f->size;

  int octave = (int)(N_OCTAVES * y * 2 + 1)/2 - 3;

  notes[scale_note(x)+12*octave].val = v*128;
}

#define MAX_TOUCH_LATENCY 6
int callback(int device, Finger *data, int nFingers, double timestamp, int frame) {

  for (int i=0; i<nFingers; i++) {
    do_note(&data[i]);
  }

  for (int i=0 ; i < MAX_NOTES ; i++) {


#ifdef USE_VELOCITY

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

#else

    if (notes[i].lastval && !notes[i].val) {
      note_off(i, notes[i].lastval);
    }
    else if (notes[i].val && notes[i].val != notes[i].lastval) {
      if (!notes[i].lastval) {
	note_on(i, -1);
      }
      aftertouch(i,notes[i].val);
    }

#endif

    notes[i].lastval = notes[i].val;
    notes[i].val = 0; /* will be overwritten in do_note if note is actually on */
  }



  return 0;
}

int main(int argc, char** argv) {

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

  if (argc >= 2 && argv[1][0] == '-') {
    midi = argv[1][1] != 's';
    argv++;
    argc--;
  }

  if (argc == 2) {
    if (argv[1][0] >= 'A' && argv[1][0] <= 'G') {
      switch(argv[1][0]) {
      case 'A': base_pitch = A440; break;
      case 'B': base_pitch = A440+2; break;
      case 'C': base_pitch = A440+3; break;
      case 'D': base_pitch = A440+5; break;
      case 'E': base_pitch = A440+7; break;
      case 'F': base_pitch = A440+8; break;
      case 'G': base_pitch = A440+10; break;
      }
    }
    if (argv[1][0] && argv[1][1] == '#') {
      base_pitch += 1;
    }
    if (argv[1][0] && argv[1][1] == 'b') {
      base_pitch -= 1;
    }
  }

  MTDeviceRef dev = MTDeviceCreateDefault();
  MTRegisterContactFrameCallback(dev, callback);
  MTDeviceStart(dev, 0);
  //printf("Ctrl-C to abort\n");
  sleep(-1);

  MIDIClientDispose(midiclient);
  MIDIEndpointDispose(midiendpoint);

  return 0;
}


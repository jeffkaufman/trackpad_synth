#ifndef TRACK_MIDI_LIB_H
#define TRACK_MIDI_LIB_H

#include <CoreFoundation/CoreFoundation.h>
#include <CoreMIDI/MIDIServices.h>
#include <CoreAudio/HostTime.h>

int tml_use_sidevolume = 0; /* does the side of the trackpad control volume? */
int tml_use_velocity = 0; /* does how hard you hit notes matter? */
int tml_n_octaves = 5; /* how many octaves on the trackpad? */
int tml_octave_shift = 3; /* how far lower than the top of our range should we be at? */
int tml_midi = 1; /* should we use midi? */
int tml_send_aftertouch = 0; /* send aftertouch messages */
int tml_send_channel_pressure = 0; /* send channel pressure messages */
int tml_send_channel_volume = 0; /* send channel pressure as a volume message */
int tml_channel = 3; /* which channel (1-16) to send on) */


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

  //float v_x = f->normalized.vel.x;
  //float v_y = f->normalized.vel.y;
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
  tml_setup_trackpad();
}

#endif

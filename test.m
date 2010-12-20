#include <math.h>
#include <stdio.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>

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

typedef void *MTDeviceRef;
typedef int (*MTContactCallbackFunction)(int,Finger*,int,double,int);

MTDeviceRef MTDeviceCreateDefault();
void MTRegisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
void MTDeviceStart(MTDeviceRef, int); // thanks comex


int notes[MAX_NOTES];
int last_notes[MAX_NOTES];

void note_on(int note) {
  printf("NoteOn          0.0 2 %d 82\n", note);
  fflush(stdout);
}

void note_off(int note) {
  printf("NoteOff         0.0 2 %d 0\n", note);
  fflush(stdout);
}

/* amt should be between 0 and 1 */
int cur_volume = 64;
void volume(float amt) {
  int new_volume = (int)(amt*128);
  if (cur_volume != new_volume) {
    /*printf("Volume        0.0 2 %d 0\n", new_volume);*/
    printf("        StringDamping   0.000100 2 %d\n", 127-new_volume);
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

/* returns 0-127 where 69 is A440.
 * returns -1 on failure */
int do_note(Finger *f) {
  float x = f->normalized.pos.x;
  float y = f->normalized.pos.y;

  int octave = (int)(N_OCTAVES * y)-2;

  notes[scale_note(x)+12*octave] = 1;
}

int callback(int device, Finger *data, int nFingers, double timestamp, int frame) {
  int note;
  for (int i=0; i<nFingers; i++) {
    note = do_note(&data[i]);
  }

  for (int i=0 ; i < MAX_NOTES ; i++) {
    if (last_notes[i] && !notes[i]) {
      note_off(i);
    }
    else if (notes[i] && !last_notes[i]) {
      note_on(i);
    }

    last_notes[i] = notes[i];
    notes[i] = 0;
  }

  return 0;
}

int main(int argc, char** argv) {
  for (int i = 0 ; i < MAX_NOTES; i++) {
    notes[i] = 0;
    last_notes[i] = 0;
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
  printf("Ctrl-C to abort\n");
  sleep(-1);
  return 0;
}


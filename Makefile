KEY=D

trackcontroller: trackcontroller.m trackmidilib.h
	gcc -F/System/Library/PrivateFrameworks -framework MultitouchSupport \
	-framework CoreMIDI -framework CoreFoundation -framework CoreAudio \
	$^ -o $@ -std=c99

runskini: trackcontroller
	./trackcontroller -S -k ${KEY} | stk-4.4.2/projects/demo/demo Clarinet -n 12 -or -ip 

runsolo: trackcontroller
	./trackcontroller

runmidi: trackcontroller
	./trackcontroller -k ${KEY}

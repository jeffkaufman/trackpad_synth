I=Clarinet
KEY=D
V=12

runskini: trackcontroller
	./trackcontroller ${KEY} | stk-4.4.2/projects/demo/demo ${I} -n ${V} -or -ip 

runsolo: trackcontroller
	./trackcontroller

trackcontroller: trackcontroller.m
	gcc -F/System/Library/PrivateFrameworks -framework MultitouchSupport \
	-framework CoreMIDI -framework CoreFoundation -framework CoreAudio \
	$^ -o $@ -std=c99

runmidi: trackcontroller
	./trackcontroller -m ${KEY}

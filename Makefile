I=Clarinet
KEY=D
V=12

runskini: trackcontroller
	./trackcontroller -s ${KEY} | stk-4.4.2/projects/demo/demo ${I} -n ${V} -or -ip 

runsolo: trackcontroller
	./trackcontroller

trackcontroller: trackcontroller.m
	gcc -F/System/Library/PrivateFrameworks -framework MultitouchSupport \
	-framework CoreMIDI -framework CoreFoundation -framework CoreAudio \
	$^ -o $@ -std=c99

runmidi: trackcontroller
	./trackcontroller ${KEY}

bundle: trackcontroller
	rm -r TrackController.app || echo "no app to remove"
	mkdir TrackController.app
	cp trackcontroller TrackController.app
	cp Info.plist TrackController.app

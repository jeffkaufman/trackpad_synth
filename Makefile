KEY=D

trackcontroller: trackcontroller.m
	gcc -F/System/Library/PrivateFrameworks -framework MultitouchSupport \
	-framework CoreMIDI -framework CoreFoundation -framework CoreAudio \
	$^ -o $@ -std=c99

runskini: trackcontroller
	./trackcontroller -S -k ${KEY} | stk-4.4.2/projects/demo/demo Clarinet -n 12 -or -ip 

runsolo: trackcontroller
	./trackcontroller

runmidi: trackcontroller
	./trackcontroller -k ${KEY}

bundle: trackcontroller
	rm -r TrackController.app || echo "no app to remove"
	mkdir TrackController.app
	cp trackcontroller TrackController.app
	cp Info.plist TrackController.app

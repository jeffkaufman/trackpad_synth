I=Clarinet
KEY=D
V=12

run: test
	./test ${KEY} | stk-4.4.2/projects/demo/demo ${I} -or -ip

ski:
	cat test.ski | stk-4.4.2/projects/demo/demo ${I} -or -ip

runpoly: test
	./test ${KEY} | stk-4.4.2/projects/demo/demo ${I} -n ${V} -or -ip 

runsolo: test
	./test

test: test.m
	gcc -F/System/Library/PrivateFrameworks -framework MultitouchSupport \
	-framework CoreMIDI -framework CoreFoundation -framework CoreAudio \
	$^ -o $@ -std=c99

runmidi: test
	./test -m ${KEY}

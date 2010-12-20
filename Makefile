I=Clarinet
KEY=D

run: test
	./test ${MODE} ${KEY} | stk-4.4.2/projects/demo/demo ${I} -or -ip

runsolo: test
	./test

test: test.m
	gcc -F/System/Library/PrivateFrameworks -framework MultitouchSupport $^ -o $@ -std=c99

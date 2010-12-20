run: test
	./test

test: test.m
	gcc -F/System/Library/PrivateFrameworks -framework MultitouchSupport $^ -o $@ -std=c99

.PHONY: clean

all: build

build: clean
	zip -r -9 /tmp/putioroku.zip .
	mkdir build
	mv /tmp/putioroku.zip build/

clean:
	rm -rf build


.PHONY: clean

all: build/putioroku.zip

build: clean
	mkdir -p build

build/putioroku.zip: build
	zip -r -9 build/putioroku.zip . -x "build*" ".git*"

clean:
	rm -rf build


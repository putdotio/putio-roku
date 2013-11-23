.PHONY: clean

all: build/putioroku.zip

build: clean
	mkdir -p build

build/putioroku.zip: build
	zip -r -9 build/putioroku.zip . --exclude build

clean:
	rm -rf build


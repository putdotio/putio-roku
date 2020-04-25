clean:
	rm putio-roku-v2.zip

build:
	zip -r putio-roku-v2.zip components images manifest source

move:
	mv putio-roku-v2.zip ../landing/static/dl/

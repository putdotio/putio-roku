clean:
	rm putio-roku-2019.zip

build:
	zip -r putio-roku-2019.zip components images manifest source

move:
	mv putio-roku-2019.zip ../landing/static/dl/

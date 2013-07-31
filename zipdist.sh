#!/bin/sh

export ZIPNAME=nubdist/iceball-indev-0.1.1-4.zip

zip -r $ZIPNAME *.dll *.exe *.txt opencmd.bat connect-*.bat docs/ \
	dlcache/info.txt clsave/info.txt \
	clsave/config.json clsave/pub/user.json clsave/pub/controls.json \
	pkg/iceball/halp/


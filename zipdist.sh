#!/bin/sh

export ZIPNAME=nubdist/iceball-indev-0.1.1-9.zip

zip -r $ZIPNAME *.dll *.exe *.txt opencmd.bat docs/ \
	dlcache/info.txt clsave/info.txt \
	clsave/config.json clsave/pub/user.json clsave/pub/controls.json \
	"DOUBLE CLICK ON THIS FILE TO GET THE MASTER SERVER LIST WORKING PROPERLY ON WINDOWS I MEAN IT.exe" \
	pkg/iceball/halp/


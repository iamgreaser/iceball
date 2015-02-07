#!/bin/sh

export ZIPNAME=nubdist/iceball-indev-0.2a-3.zip

zip -r $ZIPNAME *.dll *.exe *.txt opencmd.bat docs/ \
	clsave/config.json \
	clsave/pub/user.json \
	clsave/pub/controls.json \
	clsave/vol/dummy \
	svsave/pub/dummy \
	svsave/vol/dummy \
	pkg/iceball/halp/ \
	pkg/iceball/launch/ \
	pkg/iceball/config/ \
	pkg/iceball/lib/ \
	pkg/iceball/gfx/ \
	#


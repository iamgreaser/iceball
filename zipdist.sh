#!/bin/sh

export ZIPNAME=nubdist/iceballfornoobs-0.0-45.zip

#zip -r $ZIPNAME *.dll *.exe *.txt *.bat docs/ \
#	pkg/base/*.lua \
#	pkg/base/icegui/*.lua \
#	pkg/maps/mesa.vxl \
#	pkg/base/gfx/ pkg/base/pmf/ \
#	pkg/iceball/snowtest/ \
#	pkg/iceball/pmfedit/ \
#	pkg/iceball/mapedit/ \
#	dlcache/info.txt clsave/info.txt svsave/info.txt \
#	clsave/config.json clsave/pub/user.json

zip -r $ZIPNAME *.dll *.exe *.txt opencmd.bat connect-*.bat docs/ \
	MANUAL/ \
	dlcache/info.txt clsave/info.txt \
	clsave/config.json clsave/pub/user.json \
	pkg/iceball/halp/ \
	clsave/pub/controls.json


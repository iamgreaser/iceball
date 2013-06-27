#!/bin/sh

export ZIPNAME=nubdist/iceball-0.1.zip

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
	pmfedit.bat mapedit.bat \
	dlcache/info.txt clsave/info.txt \
	clsave/config.json clsave/pub/user.json \
	clsave/pub/skin/info.txt \
	clsave/vol/dummy clsave/base/vol/dummy \
	pkg/iceball/halp/ \
	pkg/base/ pkg/maps/mesa.vxl pkg/maps/mesa.vxl.tga \
	pkg/iceball/snowtest/ pkg/iceball/hack_console/ \
	pkg/iceball/pmfedit/ pkg/iceball/mapedit/ \
	svsave/info.txt \
	svsave/pub/server.json svsave/pub/mods.json svsave/base/vol/dummy svsave/vol/dummy \
	src/ include/ Makefile* CMakeLists.txt main.make \
	clsave/pub/controls.json \
	xlibinc/dummy winlibs/dummy \
	-x pkg/base/srcwav16/ pkg/base/kv6/ pkg/base/glsl/


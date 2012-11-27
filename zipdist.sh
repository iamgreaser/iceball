export ZIPNAME=nubdist/iceballfornoobs-002.zip

zip -r $ZIPNAME *.dll *.exe *.txt *.bat docs/ \
	pkg/maps/ \
	pkg/base/*.lua \
	pkg/base/gfx/ pkg/base/pmf/ \
	pkg/iceball/snowtest/ \
	pkg/iceball/pmfedit/ \
	dlcache/info.txt clsave/info.txt svsave/info.txt

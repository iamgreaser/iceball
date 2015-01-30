"""
A simple tool for converting 512x64x512 icemap files into vxl.

NOTE: this does NOT do the icemap footer variant. (Yet.)

GreaseMonkey, 2012 - Public Domain

"""

from __future__ import print_function

import sys, struct

# Backwards compatibility - make new code work on old version, not vice-versa
PY2 = sys.version_info[0] == 2
PY3 = sys.version_info[0] == 3
if PY2:
	# This script didn't use range() anyway, so no problem overwriting it in Py2
	import __builtin__
	range = getattr(__builtin__, "xrange")
	_ord = ord
else:
	_ord = lambda x: x

USAGE_MSG = """
usage:
	python2 icemap2vxl.py in.icemap out.vxl

note: icemap file MUST be 512x64x512,
and the type information will be LOST!
"""

if len(sys.argv) <= 2:
	print(USAGE_MSG)
	exit()

infp = open(sys.argv[1],"rb")
if infp.read(8) != "IceMap\x1A\x01":
	raise Exception("not an IceMap v1 file")

while True:
	tag = infp.read(7)
	taglen = _ord(infp.read(1))
	
	if tag == b" "*7:
		break
	
	if taglen == 255:
		taglen, = struct.unpack("<I", infp.read(4))
	
	if tag == "MapData":
		xlen, ylen, zlen = struct.unpack("<HHH", infp.read(6))
		if xlen != 512 or ylen != 64 or zlen != 512:
			raise Exception("not a 512x64x512 map")
		
		outfp = open(sys.argv[2],"wb")
		
		for z in range(512):
			for x in range(512):
				k = True
				while k:
					cblk = infp.read(4)
					outfp.write(cblk)
					n = _ord(cblk[0])
					if n == 0:
						n = _ord(cblk[2])-_ord(cblk[1])+1
						k = False
					else:
						n = n - 1
					
					for i in range(n):
						s = infp.read(4)
						outfp.write(s[:3]+b"\x7F")
		
		outfp.close()
		infp.close()
		break
	else:
		infp.seek(taglen, 1) # SEEK_CUR

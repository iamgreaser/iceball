"""
A simple tool for converting 512x64x512 icemap files into vxl.

NOTE: this does NOT do the icemap footer variant. (Yet.)

GreaseMonkey, 2012 - Public Domain

"""

import sys, struct

USAGE_MSG = """
usage:
	python2 icemap2vxl.py in.icemap out.vxl

note: icemap file MUST be 512x64x512,
and the type information will be LOST!
"""

if len(sys.argv) <= 2:
	print USAGE_MSG
	exit()

infp = open(sys.argv[1],"rb")
if infp.read(8) != "IceMap\x1A\x01":
	raise Exception("not an IceMap v1 file")

while True:
	tag = infp.read(7)
	taglen = ord(infp.read(1))
	
	if tag == " "*7:
		break
	
	if taglen == 255:
		taglen, = struct.unpack("<I", infp.read(4))
	
	if tag == "MapData":
		xlen, ylen, zlen = struct.unpack("<HHH", infp.read(6))
		if xlen != 512 or ylen != 64 or zlen != 512:
			raise Exception("not a 512x64x512 map")
		
		outfp = open(sys.argv[2],"wb")
		
		for z in xrange(512):
			for x in xrange(512):
				k = True
				while k:
					cblk = infp.read(4)
					outfp.write(cblk)
					n = ord(cblk[0])
					if n == 0:
						n = ord(cblk[2])-ord(cblk[1])+1
						k = False
					else:
						n = n - 1
					
					for i in xrange(n):
						s = infp.read(4)
						outfp.write(s[:3]+"\x7F")
		
		outfp.close()
		infp.close()
		break
	else:
		infp.seek(taglen, 1) # SEEK_CUR

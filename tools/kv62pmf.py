"""
A tool for converting kv6 models into pmf.

GreaseMonkey, 2013 - Public Domain

WARNING: I haven't checked to ensure that X,Y are around the right way.
If you find your models have been flipped inadvertently, let me know! --GM

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
	python2 kv62pmf.py in.kv6 out.pmf ptsize ptspacing bonename
"""

if len(sys.argv) <= 4:
	print(USAGE_MSG)
	exit()

if not sys.argv[3].isdigit():
	raise Exception("expected a number for the 3rd argument")
if not sys.argv[4].isdigit():
	raise Exception("expected a number for the 4th argument")
ptsize = int(sys.argv[3])
ptspacing = int(sys.argv[4])
if ptsize < 1 or ptsize > 65535:
	raise Exception("point size out of range (1..65535)")

bonename = sys.argv[4]
if PY3:
    bonename = bonename.encode()
if len(bonename) > 15:
	raise Exception("bone name too large")

infp = open(sys.argv[1],"rb")

if infp.read(4) != b"Kvxl":
	raise Exception("not a KV6 file")

xsiz, ysiz, zsiz, xpivot, ypivot, zpivot, blklen = struct.unpack("<IIIfffI", infp.read(28))
print(xsiz, ysiz, zsiz, xpivot, ypivot, zpivot)

xpivot = int(xpivot*ptspacing+0.5)
ypivot = int(ypivot*ptspacing+0.5)
zpivot = int(zpivot*ptspacing+0.5)

# yeah i know this is basically worst case assuming x,y,z pivot is within the model bounds
if max(max(xsiz,ysiz),zsiz)*ptspacing > 65535:
	raise Exception("point size a bit TOO large to fit into a pmf")
if blklen > 4096:
	raise Exception("kv6 has too many blocks to fit into a pmf")

def parseblk(s):
	return struct.unpack("<BBBBHBB",s)

blkdata = [parseblk(infp.read(8)) for i in range(blklen)]

xoffset = [struct.unpack("<I", infp.read(4))[0] for i in range(xsiz)]
xyoffset = [struct.unpack("<H", infp.read(2))[0] for i in range(xsiz*ysiz)]

assert blklen == sum(xoffset)
assert blklen == sum(xyoffset)
# Corollary: sum(xoffset) == sum(xyoffset)
# Proof: Left as an exercise to the reader.

magic_spal = infp.read(4)
palette = None
if magic_spal == b"":
	pass # no palette
elif magic_spal == b"SPal":
	palette = [[_ord(v) for v in infp.read(3)] for i in range(256)]
else:
	raise Exception("expected palette at end of file")

infp.close()

#
#
#

# pretty simple really
outfp = open(sys.argv[2], "wb")

# start with the header of "PMF",0x1A,1,0,0,0
outfp.write(b"PMF\x1A\x01\x00\x00\x00")

# then there's a uint32_t denoting how many body parts there are
outfp.write(struct.pack("<I",1))

# then, for each body part,
# there's a null-terminated 16-byte string (max 15 chars) denoting the part
outfp.write(bonename + b"\x00"*(16-len(bonename)))

# then there's a uint32_t denoting how many points there are in this body part
outfp.write(struct.pack("<I",blklen))

# then there's a whole bunch of this:

# uint16_t radius;
# int16_t x,y,z;
# uint8_t b,g,r,reserved;
bi = 0
oi = 0
for cx in range(xsiz):
	for cy in range(ysiz):
		for i in range(xyoffset[oi]):
			b,g,r,l,ypos,vis,unk1 = blkdata[bi]
			outfp.write(struct.pack("<HhhhBBBB"
				,ptsize
				,cx*ptspacing-xpivot
				,ypos*ptspacing-zpivot
				,cy*ptspacing-ypivot
				,b,g,r,0))
			bi += 1
		oi += 1

# rinse, lather, repeat
outfp.close()

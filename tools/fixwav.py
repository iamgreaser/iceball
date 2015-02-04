import sys, struct

infp = open(sys.argv[1], "rb")

hdr_riff = infp.read(4)
if hdr_riff != "RIFF":
	raise Exception("not a RIFF WAVE file")
infsize_total, = struct.unpack("<I", infp.read(4))
hdr_wave = infp.read(4)
if hdr_wave != "WAVE":
	raise Exception("not a RIFF WAVE file")

fsize_total = 4
chunks = []

while True:
	s = infp.read(4)
	if s == "":
		break

	cname = s
	clen, = struct.unpack("<I", infp.read(4))
	cdata = infp.read(clen)
	print "Read", cname, clen, len(cdata)
	assert clen == len(cdata)

	if cname in ["fmt ", "data"]:
		chunks.append((cname, cdata))
		fsize_total += clen + 8

infp.close()

outfp = open(sys.argv[2], "wb")
outfp.write("RIFF" + struct.pack("<I", fsize_total) + "WAVE")
for (cname, cdata) in chunks:
	print "Write", cname, len(cdata)
	outfp.write(cname + struct.pack("<I", len(cdata)) + cdata)
outfp.close()


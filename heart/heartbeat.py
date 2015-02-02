#
# heartbeat.py: Iceball heartbeat server
# This file is part of Iceball.
# 
# Iceball is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# Iceball is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with Iceball.  If not, see <http://www.gnu.org/licenses/>.
#

import errno, heapq, json, random, socket, struct, sys, time

CONN_PORT = int(sys.argv[1])

def ib_version_str(n):
	z = n & ((1<<10)-1); n >>= 10
	a = n & ((1<<5)-1); n >>= 5
	y = n & ((1<<7)-1); n >>= 7
	x = n & ((1<<5)-1); n >>= 5
	w = n

	s = "%i.%i" % (w, x)
	if y > 0:
		s += ".%i" % y
	if a > 0:
		s += "." + chr(ord('a')+a-1)
	if z > 0:
		s += "-%i" % z
	
	return s

def calc_ib_version(w,x,y,a,z):
	return (((((((w<<5) + x
		)<<7) + y
		)<<5) + a
		)<<10) + z

HB_LIFETIME = 120
HB_VERSION = 2
IB_VERSION_CMP = (0,2,0,0,0)
IB_VERSION = calc_ib_version(*IB_VERSION_CMP)

# ignore "Z" version
IB_VERSION_MASK = ~((1<<10)-1)
# if you wish to ignore "A" version as well, use this instead:
# IB_VERSION_MASK = ~((1<<(10+5))-1)

def stripnul(s):
	idx = s.find("\x00")
	return (s if idx == -1 else s[:idx])

def replace_char_all(s, f, t):
	v = ord(f)
	s = s.replace(f, t)
	s = s.replace(chr(0xC0 | ((v>>6)&3)) + chr(0x80 | (v&63)), t)
	s = s.replace(chr(0xE0) + chr(0x80 | ((v>>6)&3)) + chr(0x80 | (v&63)), t)
	s = s.replace(chr(0xF0) + chr(0x80) + chr(0x80 | ((v>>6)&3)) + chr(0x80 | (v&63)), t)
	s = s.replace(chr(0xF8) + chr(0x80) + chr(0x80) + chr(0x80 | ((v>>6)&3)) + chr(0x80 | (v&63)), t)
	s = s.replace(chr(0xFC) + chr(0x80) + chr(0x80) + chr(0x80) + chr(0x80 | ((v>>6)&3)) + chr(0x80 | (v&63)), t)
	# TODO: handle the 6-bit and 8-bit variants and whatnot
	return s

def sanestr(s):
	s = str(s)
	s = replace_char_all(s, "&", "&amp;")
	s = replace_char_all(s, "<", "&lt;")
	s = replace_char_all(s, ">", "&gt;")
	return s

class HTTPClient:
	def __init__(self, ct, reactor, server, sockfd):
		self.reactor = reactor
		self.server = server
		self.sockfd = sockfd
		self.buf = ""
		self.wbuf = None
		self.sockfd.setblocking(False)
		self.reactor.push(ct, self.update)

	def is_dead(self, ct):
		return self.sockfd == None

	def update(self, et, ct):
		self.get_msgs(ct)
		self.push_buf(ct)
		if self.sockfd:
			self.reactor.push(ct + 0.1, self.update)

	def get_file_index(self):
		l = self.server.get_ib_fields()
		s = "<html>\n<head>\n"
		s += "<title>Iceball Server List</title>\n"
		s += "<link href=\"//netdna.bootstrapcdn.com/bootstrap/3.0.0/css/bootstrap.min.css\" rel=\"stylesheet\">\n"
		s += "<link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\">\n"
		s += "</head>\n<body>\n"
		s += "<div class=\"content\">\n"
		s += "<h1>Iceball Server List</h1>\n"
		s += "<table class=\"table table-bordered table-striped table-hover\">\n"
		s += "<thead>"
		s += "<th>Address</th>"
		s += "<th>Port</th>"
		s += "<th>Name</th>"
		s += "<th>Version</th>"
		s += "<th>Players</th>"
		s += "<th>Mode</th>"
		s += "<th>Map</th>"
		s += "</thead>\n"
		for d in l:
			s += "<tr>"
			s += "<td>" + sanestr(d["address"]) + "</td>"
			s += "<td>" + sanestr(d["port"]) + "</td>"
			s += "<td>" + "<a href=\"iceball://" + sanestr(d["address"]) + ":" + sanestr(d["port"]) + "\">" + sanestr(d["name"]) + "</a>" + "</td>"
			s += "<td>" + sanestr(d["version"]) + "</td>"
			s += "<td>" + sanestr(d["players_current"]) + " / " + sanestr(d["players_max"]) + "</td>"
			s += "<td>" + sanestr(d["mode"]) + "</td>"
			s += "<td>" + sanestr(d["map"]) + "</td>"
			s += "</tr>\n"
		s += "</table>\n"
		s += "</div>\n"
		s += "</body>\n</html>\n"
		return "text/html", s.replace("\n","\r\n")

	def get_file_json(self):
		l = self.server.get_ib_fields()
		return "text/plain", json.dumps({
			"version": HB_VERSION,
			"servers": l}) 

	def push_bad_http(self, ver):
		self.wbuf = ver + " 400 Bad Request\r\n\r\n"

	def push_not_found(self, ver):
		self.wbuf = ver + " 404 Not Found\r\n\r\n"

	def get_file(self, fname):
		if fname == "/" or fname == "/index.html":
			return self.get_file_index()
		elif fname == "/style.css":
			try:
				with open("style.css") as f:
					return "text/css", f.read()
			except IOError:
				return None, None
		elif fname == "/master.json":
			return self.get_file_json()
		else:
			return None, None

	def push_data(self, ver, mime, data, head=False):
		if data == None:
			self.push_not_found(ver)
			return

		self.wbuf = ver + " 200 OK\r\n"
		self.wbuf += "Content-Type: " + mime + "\r\n"
		self.wbuf += "Length: " + str(len(data)) + "\r\n"
		self.wbuf += "\r\n"

		if not head:
			self.wbuf += data
	
	def parse_http_data(self, data):
		l = data.split("\r\n")
		hdr, l = l[0], l[1:]

		self.buf = None

		hl = hdr.split(" ")
		if len(hl) == 2:
			hl.append("HTTP/0.9")
		if len(hl) != 3:
			if len(hl) < 3:
				self.push_bad_http("HTTP/1.1")
			else:
				self.push_bad_http(hl[2])
			return

		typ = hl[0]
		if typ == "GET":
			mime, data = self.get_file(hl[1])
			self.push_data(hl[2], mime, data)
		elif typ == "HEAD":
			mime, data = self.get_file(hl[1])
			self.push_data(hl[2], mime, data, head=True)
		else:
			self.push_bad_http(hl[2])
	
	def collect(self, ct):
		if self.buf == None:
			return

		if "\r\n\r\n" in self.buf:
			data, _, self.buf = self.buf.partition("\r\n\r\n")
			self.parse_http_data(data)
	
	def push_buf(self, ct):
		if self.sockfd == None:
			return

		if self.wbuf == None:
			return

		try:
			bsent = self.sockfd.send(self.wbuf)
			if bsent == 0:
				self.sockfd.close()
				self.sockfd = None
				return
			self.wbuf = self.wbuf[bsent:]
			if len(self.wbuf) == 0:
				self.sockfd.close()
				self.sockfd = None
				return
		except socket.timeout:
			pass
		except socket.error, e:
			if e.errno != errno.EAGAIN:
				print "error send:", e
				try:
					self.sockfd.close()
				except Exception:
					pass
				self.sockfd = None
	
	def get_msgs(self, ct):
		if self.sockfd == None:
			return

		if self.buf == None:
			return

		try:
			msg = self.sockfd.recv(2048)
			if msg == None:
				self.sockfd.close()
				self.sockfd = None
			
			self.buf += msg
			self.collect(ct)
		except socket.timeout:
			pass
		except socket.error, e:
			if e.errno != errno.EAGAIN:
				print "error recv:", e
				try:
					self.sockfd.close()
				except Exception:
					pass
				self.sockfd = None

class HReactor:
	def __init__(self):
		self.evq = []
	
	def run(self):
		while len(self.evq) > 0:
			ct = self.get_time()

			dt = self.evq[0][0] - ct
			if dt > 0:
				time.sleep(dt)

			self.update()

		# we've run out of tasks, so exit.

	def update(self):
		ct = self.get_time()
		while self.evq and ct >= self.evq[0][0]:
			et, fn = heapq.heappop(self.evq)
			fn(et, ct)
	
	def get_time(self):
		return time.time()

	def push(self, et, fn):
		heapq.heappush(self.evq, (et, fn))

class HServer:
	def __init__(self, ct, reactor, af, port):
		self.af = af
		self.port = port
		self.reactor = reactor
		self.clients = {}
		self.http_clients = set([])
		self.bans = set([]) # TODO: use a proper banlist
		
		self.http_sockfd = socket.socket(af, socket.SOCK_STREAM)
		self.http_sockfd.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
		self.http_sockfd.bind(("", self.port))
		self.http_sockfd.setblocking(False)
		self.http_sockfd.listen(2)

		self.sockfd = socket.socket(af, socket.SOCK_DGRAM)
		self.sockfd.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
		self.sockfd.bind(("", self.port))
		self.sockfd.settimeout(0.05)
		self.reactor.push(ct, self.update)
	
	def update(self, et, ct):
		self.get_hb_packets(ct)
		self.create_http_clients(ct)
		self.kill_dead_http_clients(ct)
		self.kill_old_clients(ct)
		self.reactor.push(ct+0.05, self.update)

	def get_hb_packets(self, ct):
		try:
			(msg, adtup) = self.sockfd.recvfrom(2048)

			if msg and adtup:
				(addr, port) = adtup
				self.on_msg(ct, self.af, addr, port, msg)
		except socket.timeout:
			pass

	def create_http_clients(self, ct):
		try:
			nsock, (addr, port) = self.http_sockfd.accept()
			self.http_clients.add(HTTPClient(ct, self.reactor, self, nsock))
		except socket.timeout:
			pass
		except socket.error, e:
			if e.errno != errno.EAGAIN:
				print "error accept:", e

	
	def kill_dead_http_clients(self, ct):
		# TODO: use a priority queue for the clients
		# that'd mean we'd get this running in O(1) time instead of O(n)

		kill = []

		for v in self.http_clients:
			if v.is_dead(ct):
				kill.append(v)

		for v in kill:
			self.http_clients.remove(v)
				

	def kill_old_clients(self, ct):
		# TODO: use a priority queue for the clients
		# that'd mean we'd get this running in O(1) time instead of O(n)

		kill = []

		for k,v in self.clients.iteritems():
			if v.is_dead(ct):
				kill.append(k)

		for k in kill:
			self.clients.pop(k)

	def on_msg(self, ct, af, addr, port, msg):
		client = self.get_client(ct, af, addr, port)
		if client:
			client.on_msg(ct, msg)
	
	def get_client(self, ct, af, addr, port):
		tup = (af, addr, port)

		if tup in self.bans:
			return None
		if tup not in self.clients:
			self.clients[tup] = HClient(ct, self.reactor, self, af, addr, port)

		return self.clients[tup]

	def get_ib_fields(self):
		l = []

		for k, v in self.clients.iteritems():
			d = v.get_fields()
			if d:
				l.append(d)

		return l

class HClient:
	def __init__(self, ct, reactor, server, af, addr, port):
		self.reactor = reactor
		self.server = server
		self.af = af
		self.addr = addr
		self.port = port
		self.ibdata = None
		self.ibdata_queued = None
		self.ibdata_cookie = None
		self.not_dead(ct)
	
	def get_fields(self):
		return self.ibdata 
	
	def is_dead(self, ct):
		return ct > self.last_msg + HB_LIFETIME
	
	def not_dead(self, ct):
		self.last_msg = ct

	def send_delayed(self, t, msg):
		self.reactor.push(lambda et, ct : self.send(msg))

	def send(self, msg):
		self.server.sockfd.sendto(msg, (self.addr, self.port))

	def on_msg(self, ct, msg):
		if len(msg) < 4:
			# empty message - do nothing
			return

		typ = msg[:4]
		msg = msg[4:]

		if typ == "1CEB" and len(msg) >= 6:
			hbver, ibver = struct.unpack("<HI", msg[:6])
			msg = msg[6:]
			
			if hbver != HB_VERSION or ((ibver^IB_VERSION)&IB_VERSION_MASK) != 0:
				# version is incorrect
				self.send("BADV" + struct.pack("<HI", HB_VERSION, IB_VERSION))
			elif len(msg) != (2+2+2+30+10+30):
				# bad format
				print "BADF", len(msg)
				self.send("BADF")
			else:
				# parse this!
				d = {}
				d["address"] = str(self.addr)
				d["port"], d["players_current"], d["players_max"] = struct.unpack("<HHH", msg[:6])
				msg = msg[6:]
				d["name"] = stripnul(msg[:30])
				msg = msg[30:]
				d["mode"] = stripnul(msg[:10])
				msg = msg[10:]
				d["map"] = stripnul(msg[:30])

				d["version"] = ib_version_str(ibver)

				self.ibdata_queued = d
				self.ibdata_cookie = struct.pack("<I", random.randint(0,0xFFFFFFFF))
				self.not_dead(ct)
				self.send("MSOK" + self.ibdata_cookie)
				print "MSOK", d
		elif typ == "HSHK":
			#print "HSHK", repr(msg)
			if msg == self.ibdata_cookie:
				print "HSHK - pushing", (self.addr, self.port)
				self.ibdata = self.ibdata_queued

hb_reactor = HReactor()
hb_server = HServer(hb_reactor.get_time(), hb_reactor, socket.AF_INET, CONN_PORT)
hb_reactor.run()


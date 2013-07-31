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

import heapq, socket, struct, sys, time

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
HB_VERSION = 1
IB_VERSION_CMP = (0,1,1,0,0)
IB_VERSION = calc_ib_version(*IB_VERSION_CMP)

# ignore "Z" version
IB_VERSION_MASK = ~((1<<10)-1)
# if you wish to ignore "A" version as well, use this instead:
# IB_VERSION_MASK = ~((1<<(10+5))-1)

def stripnul(s):
	idx = s.find("\x00")
	return (s if idx == -1 else s[:idx])

class HTTPClient:
	def __init__(self, reactor, server, sockfd):
		self.reactor = reactor
		self.server = server
		self.sockfd = sockfd
		self.buf = ""
	
	def is_dead(self, ct):
		return self.sockfd == None
	
	def update(self, ct):
		self.get_msgs(ct)
	
	def collect(self, ct):
		# TODO!
		pass
	
	def get_msgs(self, ct):
		if not self.sockfd:
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
		self.http_clients = {}
		self.bans = set([]) # TODO: use a proper banlist
		
		self.http_sockfd = socket.socket(af, socket.SOCK_STREAM)
		self.http_sockfd.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
		self.http_sockfd.bind(("", self.port))
		self.http_sockfd.settimeout(0)

		self.sockfd = socket.socket(af, socket.SOCK_DGRAM)
		self.sockfd.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
		self.sockfd.bind(("", self.port))
		self.sockfd.settimeout(0.05)
		self.reactor.push(ct, self.update)
	
	def update(self, et, ct):
		self.get_hb_packets(ct)
		self.update_http_clients(ct)
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

	def update_http_clients(self, ct):
		for v in self.http_clients:
			v.update(ct)

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

				self.ibdata = d
				self.not_dead(ct)
				self.send("MSOK")
				print "MSOK", d

hb_reactor = HReactor()
hb_server = HServer(hb_reactor.get_time(), hb_reactor, socket.AF_INET, CONN_PORT)
hb_reactor.run()


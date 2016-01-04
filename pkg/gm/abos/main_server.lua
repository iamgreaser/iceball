dofile("pkg/gm/abos/common.lua")

function server.hook_tick(sec_current, sec_delta)
	return math.max(0.001, math.min(0.02, 0.04 - sec_delta))
end

function server.hook_connect(neth, addrinfo)
	print("connect", anytostring(addrinfo))
end

function server.hook_disconnect(neth, server_force, reason)
end

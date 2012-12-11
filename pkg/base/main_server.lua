--[[
    This file is part of Ice Lua Components.

    Ice Lua Components is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Ice Lua Components is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with Ice Lua Components.  If not, see <http://www.gnu.org/licenses/>.
]]

print("pkg/base/main_server.lua starting")
print(...)

dofile("pkg/base/common.lua")

client_list = {fdlist={}}

function net_broadcast(sockfd, msg)
	local i
	for i=1,#(client_list.fdlist) do
		if client_list.fdlist[i] ~= sockfd then
			--print("to", client_list.fdlist[i], type(msg))
			common.net_send(client_list.fdlist[i], msg)
		end
	end
end

function net_broadcast_team(sockfd, msg)
	-- TODO!
	return net_broadcast(sockfd, msg)
end

function server.hook_connect(sockfd, addrinfo)
	-- TODO: enforce bans
	client_list.fdlist[#(client_list.fdlist)+1] = sockfd
	client_list[sockfd] = {
		fdidx = #(client_list.fdlist),
		addrinfo = addrinfo,
		plrid = nil
	}
	print("connect:", sockfd, addrinfo.proto,
		addrinfo.addr and addrinfo.addr.sport,
		addrinfo.addr and addrinfo.addr.ip,
		addrinfo.addr and addrinfo.addr.cport)
	
	local ss = (sockfd == true and "(local)") or sockfd
	net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFFFF0000,
		"Connected: player on sockfd "..ss))
end

function server.hook_disconnect(sockfd, server_force, reason)
	-- just in case we get any stray disconnect messages
	if not client_list[sockfd] then return end
	
	local fdidx = client_list[sockfd].fdidx
	client_list.fdlist[fdidx] = client_list.fdlist[#(client_list.fdlist)]
	client_list.fdlist[#(client_list.fdlist)] = nil
	client_list[sockfd] = nil
	print("disconnect:", sockfd, server_force, reason)
	
	local ss = (sockfd == true and "(local)") or sockfd
	net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFFFF0000,
		"Disconnected: player on sockfd "..ss))
end

function server.hook_tick(sec_current, sec_delta)
	--print("tick",sec_current,sec_delta)
	
	local pkt, sockfd
	while true do
		pkt, sockfd = common.net_recv()
		if not pkt then break end
		--print("in",sockfd)
		
		local cid
		cid, pkt = common.net_unpack("B", pkt)
		
		if cid == 0x0C then
			-- chat
			local msg
			local plr = players[1]
			msg, pkt = common.net_unpack("z", pkt)
			-- TODO: broadcast
			local s = plr.name.." ("..teams[plr.team].name.."): "..msg
			--local s = "dummy: "..msg
			
			net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFFFFFFFF, s))
		elseif cid == 0x0D then
			-- teamchat
			local msg
			local plr = players[1]
			msg, pkt = common.net_unpack("z", pkt)
			local s = plr.name..": "..msg
			--local s = "dummy: "..msg
			local cb = teams[plr.team].color_chat
			local cb = {0,0,255}
			local c = argb_split_to_merged(cb[1],cb[2],cb[3])
			net_broadcast_team(nil, common.net_pack("BIz", 0x0E, c, s))
		end
		-- TODO!
	end
	
	return 0.005
end

-- load map
map_fname = ...
map_fname = map_fname or MAP_DEFAULT
map_loaded = common.map_load(map_fname, "auto")
common.map_set(map_loaded)

-- spam with players
players.local_multi = math.floor(math.random()*32)+1

for i=1,players.max do
	players[i] = new_player({
		name = name_generate(),
		--[[squad = squads[math.fmod(i-1,2)][
			math.fmod(math.floor((i-1)/2),4)+1],]]
		squad = nil,
		team = math.fmod(i-1,2), -- 0 == blue, 1 == green
		weapon = WPN_RIFLE,
	})
	print("player", i, players[i].name)
end

print("pkg/base/main_server.lua loaded.")

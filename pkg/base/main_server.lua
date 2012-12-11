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

function slot_add(sockfd, tidx, wpn, name)
	local i
	for i=1,players.max do
		if not players[i] then
			if tidx < 0 or tidx > 1 then
				-- TODO: actually balance this properly!
				tidx = math.fmod(i-1,2)
			end
			players[i] = new_player({
				name = name,
				--[[squad = squads[math.fmod(i-1,2)][
					math.fmod(math.floor((i-1)/2),4)+1],]]
				squad = nil,
				team = tidx, -- 0 == blue, 1 == green
				weapon = WPN_RIFLE,
			})
			return i
		end
	end
	
	return nil
end

function net_broadcast(sockfd, msg)
	local i
	for i=1,#(client_list.fdlist) do
		if client_list.fdlist[i] ~= sockfd then
			--print("to", client_list.fdlist[i], type(msg))
			common.net_send(client_list.fdlist[i], msg)
		end
	end
end

function net_broadcast_team(tidx, msg)
	local i
	for i=1,#(client_list.fdlist) do
		local cli = client_list[client_list.fdlist[i]]
		local plr = cli and players[cli.plrid]
		if plr.team == tidx then
			--print("to", client_list.fdlist[i], type(msg))
			common.net_send(client_list.fdlist[i], msg)
		end
	end
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
	--[[net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFF800000,
		"Connected: player on sockfd "..ss))]]
	print("Connected: player on sockfd "..ss)
end

function server.hook_disconnect(sockfd, server_force, reason)
	-- just in case we get any stray disconnect messages
	if not client_list[sockfd] then return end
	
	local plrid = client_list[sockfd].plrid
	local plr = players[plrid]
	
	local fdidx = client_list[sockfd].fdidx
	client_list.fdlist[fdidx] = client_list.fdlist[#(client_list.fdlist)]
	client_list.fdlist[#(client_list.fdlist)] = nil
	client_list[sockfd] = nil
	print("disconnect:", sockfd, server_force, reason)
	
	local ss = (sockfd == true and "(local)") or sockfd
	--[[net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFF800000,
		"Disconnected: player on sockfd "..ss))]]
	print("Disconnected: player on sockfd "..ss)
	
	if plr then
		net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFF800000,
			"* Player "..plr.name.." disconnected"))
		players[plrid] = nil
	end
end

function server.hook_tick(sec_current, sec_delta)
	--print("tick",sec_current,sec_delta)
	
	local pkt, sockfd
	while true do
		pkt, sockfd = common.net_recv()
		if not pkt then break end
		
		local cli = client_list[sockfd]
		local plr = cli and players[cli.plrid]
		
		local cid
		cid, pkt = common.net_unpack("B", pkt)
		
		--print("in",sockfd,cid)
		
		if cid == 0x03 and plr then
			-- TODO: throttle this
			local pid, x2, y2, z2
			pid, x2, y2, z2, pkt = common.net_unpack("Bhhh", pkt)
			local x = x2/32.0
			local y = y2/32.0
			local z = z2/32.0
			
			if plr then
				plr.set_pos_recv(x, y, z)
				net_broadcast(sockfd, common.net_pack("BBhhh",
					0x03, cli.plrid, x2, y2, z2))
			end
		elseif cid == 0x04 and plr then
			-- TODO: throttle this
			local pid, ya2, xa2, keys
			pid, ya2, xa2, keys = common.net_unpack("BbbB", pkt)
			local ya = ya2*math.pi/128
			local xa = xa2*math.pi/256
			
			if plr then
				plr.set_orient_recv(ya, xa, keys)
				net_broadcast(sockfd, common.net_pack("BBbbB",
					0x04, cli.plrid, ya2, xa2, keys))
			end
		elseif cid == 0x0C and plr then
			-- chat
			local msg
			msg, pkt = common.net_unpack("z", pkt)
			-- TODO: broadcast
			local s = plr.name.." ("..teams[plr.team].name.."): "..msg
			--local s = "dummy: "..msg
			
			net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFFFFFFFF, s))
		elseif cid == 0x0D and plr then
			-- teamchat
			local msg
			msg, pkt = common.net_unpack("z", pkt)
			local s = plr.name..": "..msg
			--local s = "dummy: "..msg
			local cb = teams[plr.team].color_chat
			local cb = {0,0,255}
			local c = argb_split_to_merged(cb[1],cb[2],cb[3])
			net_broadcast_team(plr.team, common.net_pack("BIz", 0x0E, c, s))
		elseif cid == 0x11 and not plr then
			local tidx, wpn, name
			tidx, wpn, name, pkt = common.net_unpack("bbz", pkt)
			name = (name ~= "" and name) or name_generate()
			cli.plrid = slot_add(sockfd, tidx, wpn, name)
			if not cli.plrid then
				print("* server full")
				-- TODO: kick somehow!
			else
				plr = players[cli.plrid]
				print("* "..name.." joined team "..tidx..".")
				
				-- relay other players to this player
				local i
				for i=1,players.max do
					local plr = players[i]
					if plr then
						common.net_send(sockfd, common.net_pack("BBBBhhhz",
							0x05, i,
							plr.team, plr.weapon,
							plr.score, plr.kills, plr.deaths,
							plr.name))
						common.net_send(sockfd, common.net_pack("BBfffBB",
							0x10, i,
							plr.x, plr.y, plr.z,
							plr.angy*128/math.pi, plr.angx*256/math.pi))
					end
				end
				
				-- relay this player to everyone
				net_broadcast(nil, common.net_pack("BBBBhhhz",
					0x05, cli.plrid,
					plr.team, plr.weapon,
					plr.score, plr.kills, plr.deaths,
					plr.name))
				net_broadcast(nil, common.net_pack("BBfffBB",
					0x10, cli.plrid,
					plr.x, plr.y, plr.z,
					plr.angy*128/math.pi, plr.angx*256/math.pi))
				
				-- set player ID
				common.net_send(sockfd, common.net_pack("BB",
					0x06, cli.plrid))
				
				net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFF800000,
					"* Player "..name.." has joined the "..teams[plr.team].name.." team"))
			end
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
--[=[
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
]=]

print("pkg/base/main_server.lua loaded.")

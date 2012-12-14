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
				pid = i,
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
		if plr and plr.team == tidx then
			--print("to", client_list.fdlist[i], type(msg))
			common.net_send(client_list.fdlist[i], msg)
		end
	end
end


function server.hook_file(sockfd, ftype, fname)
	print("hook_file:", sockfd, ftype, fname)
	
	--if (ftype == "icemap" or ftype == "map") and fname == "*MAP" then
	if (ftype == "icemap" or ftype == "map") and fname == "pkg/MAP" then
		-- hackish workaround so iceballfornoobs-004 still works
		return map_loaded
	end
	
	return true
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
	
	common.net_send(sockfd, common.net_pack("Bz", 0xE0, map_fname))
end

function server.hook_disconnect(sockfd, server_force, reason)
	-- just in case we get any stray disconnect messages
	if not client_list[sockfd] then return end
	
	local plrid = client_list[sockfd].plrid
	local plr = players[plrid]
	
	local fdidx = client_list[sockfd].fdidx
	local cli2 = client_list[client_list.fdlist[#(client_list.fdlist)]]
	cli2.fdidx = fdidx
	client_list.fdlist[fdidx] = client_list.fdlist[#(client_list.fdlist)]
	client_list.fdlist[#(client_list.fdlist)] = nil
	client_list[sockfd] = nil
	print("disconnect:", sockfd, server_force, reason)
	
	local ss = (sockfd == true and "(local)") or sockfd
	--[[net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFF800000,
		"Disconnected: player on sockfd "..ss))]]
	print("Disconnected: player on sockfd "..ss)
	
	if plr then
		plr.intel_drop()
		net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFF800000,
			"* Player "..plr.name.." disconnected"))
		net_broadcast(sockfd, common.net_pack("BB",
			0x07, plrid))
			
		-- TODO fix crash bug
		--plr.free()
		players[plrid] = nil
	end
end

function server.hook_tick(sec_current, sec_delta)
	--print("tick",sec_current,sec_delta)
	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	
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
			
			plr.set_pos_recv(x, y, z)
			net_broadcast(sockfd, common.net_pack("BBhhh",
				0x03, cli.plrid, x2, y2, z2))
			--print("03.")
		elseif cid == 0x04 and plr then
			-- TODO: throttle this
			local pid, ya2, xa2, keys
			pid, ya2, xa2, keys = common.net_unpack("BbbB", pkt)
			local ya = ya2*math.pi/128
			local xa = xa2*math.pi/256
			
			plr.set_orient_recv(ya, xa, keys)
			net_broadcast(sockfd, common.net_pack("BBbbB",
				0x04, cli.plrid, ya2, xa2, keys))
			--print("04.")
		elseif cid == 0x08 and plr then
			local x,y,z,cb,cg,cr,ct
			x,y,z,cb,cg,cr,ct,pkt = common.net_unpack("HHHBBBB", pkt)
			if x >= 0 and x < xlen and z >= 0 and z < zlen then
			if y >= 0 and y <= ylen-3 then
				if plr.blocks > 0 then
					plr.blocks = plr.blocks - 1
					map_block_set(x,y,z,ct,cr,cg,cb)
					net_broadcast(nil, common.net_pack("BHHHBBBB",
						0x08,x,y,z,cb,cg,cr,ct))
				else
					plr.blocks = 0
				end
				if plr.blocks == 0 then
					net_broadcast(nil, common.net_pack("BBB",
						0x19, cli.plrid, 0))
				else
					-- to prevent desyncing issues.
					common.net_send(sockfd, common.net_pack("BBB",
						0x19, cli.plrid, plr.blocks))
				end
			end
			end
		elseif cid == 0x09 and plr then
			local x,y,z
			x,y,z = common.net_unpack("HHH", pkt)
			if x >= 0 and x < xlen and z >= 0 and z < zlen then
			if y >= 0 and y <= ylen-3 then
				map_block_break(x,y,z)
				net_broadcast(nil, common.net_pack("BHHH",
						0x09,x,y,z))
				if plr.tool == TOOL_SPADE then
					local oblocks = plr.blocks
					plr.blocks = plr.blocks + 1
					if plr.blocks > 100 then
						plr.blocks = 100
					end
					
					if oblocks == 0 then
						net_broadcast(nil, common.net_pack("BBB",
							0x19, cli.plrid, plr.blocks))
					else
						common.net_send(sockfd, common.net_pack("BBB",
							0x19, cli.plrid, plr.blocks))
					end
				end
			end
			end
		elseif cid == 0x0A and plr then
			local x,y,z
			x,y,z = common.net_unpack("HHH", pkt)
			if x >= 0 and x < xlen and z >= 0 and z < zlen then
				local i
				for i=-1,1 do
					if y+i >= 0 and y+i <= ylen-3 then
						map_block_break(x,y+i,z)
						net_broadcast(nil, common.net_pack("BHHH",
								0x09,x,y+i,z))
					end
				end
			end
		elseif cid == 0x0C and plr then
			-- chat
			local msg
			msg, pkt = common.net_unpack("z", pkt)
			
			local s = nil
			if string.sub(msg,1,4) == "/me " then
				s = "* "..plr.name.." "..string.sub(msg,5)
			elseif msg == "/kill" then
				plr.set_health_damage(0, 0xFF800000, plr.name.." shuffled off this mortal coil", plr)
			else
				s = plr.name.." ("..teams[plr.team].name.."): "..msg
			end
			
			if s then
				net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFFFFFFFF, s))
			end
		elseif cid == 0x0D and plr then
			-- teamchat
			local msg
			msg, pkt = common.net_unpack("z", pkt)
			
			local s = nil
			if string.sub(msg,1,4) == "/me " then
				s = "* "..plr.name.." "..string.sub(msg,5)
			else
				s = plr.name..": "..msg
			end
			
			if s then
				local cb = teams[plr.team].color_chat
				local c = argb_split_to_merged(cb[1],cb[2],cb[3])
				net_broadcast_team(plr.team, common.net_pack("BIz", 0x0E, c, s))
			end
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
						common.net_send(sockfd, common.net_pack("BBB",
							0x17, i, plr.tool))
						common.net_send(sockfd, common.net_pack("BBBBB",
							0x18, i,
							plr.blk_color[1],plr.blk_color[2],plr.blk_color[3]))
					end
				end
				
				-- relay intels/tents to this player
				for i=1,4 do
					local f,x,y,z
					x,y,z = intent[i].get_pos()
					f = intent[i].get_flags()
					common.net_send(sockfd, common.net_pack("BHhhhB",
						0x12, i, x, y, z, f))
					local plr = intent[i].player
					if plr then
						common.net_send(sockfd, common.net_pack("BHB",
							0x16, i, plr.pid))
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
		elseif cid == 0x13 and plr then
			local tpid, styp
			tpid, styp, pkt = common.net_unpack("BB", pkt)
			--print("hit", tpid, styp)
			
			local tplr = players[tpid]
			if tplr and styp >= 1 and styp <= 3 then
				if tplr.wpn then
					local dmg = tplr.wpn.cfg.dmg[({"head","body","legs"})[styp]]
					--print("dmg",dmg,tplr.wpn.cfg.dmg)
					tplr.gun_damage(styp, dmg, plr)
				end
			end
		elseif cid == 0x17 and plr then
			local tpid, tool
			tpid, tool, pkt = common.net_unpack("BB", pkt)
			
			if plr and tool >= 0 and tool <= 3 then
				plr.tool = tool
				net_broadcast(sockfd, common.net_pack("BBB"
					, 0x17, cli.plrid, tool))
			end
		elseif cid == 0x18 and plr then
			local tpid, cr,cg,cb
			tpid, cr,cg,cb, pkt = common.net_unpack("BBBB", pkt)
			
			if plr then
				plr.blk_color = {cr,cg,cb}
				net_broadcast(sockfd, common.net_pack("BBBBB"
					, 0x18, cli.plrid, cr, cg, cb))
			end
		end
		-- TODO!
	end
	
	local i
	for i=1,players.max do
		local plr = players[i]
		if plr then
			plr.tick(sec_current, sec_delta)
		end
	end
	
	for i=1,#intent do
		intent[i].tick(sec_current, sec_delta)
	end
	
	return 0.005
end

-- parse arguments

local loose, user_toggles, user_settings = parse_commandline_options({...})

-- load map
map_fname = loose[1]
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

intent[#intent+1] = new_intel({team = 0, iid = #intent+1})
intent[#intent+1] = new_tent({team = 0, iid = #intent+1})
intent[#intent+1] = new_intel({team = 1, iid = #intent+1})
intent[#intent+1] = new_tent({team = 1, iid = #intent+1})

do
	local i
	for i=1,4 do
		intent[i].spawn()
	end
end

print("pkg/base/main_server.lua loaded.")

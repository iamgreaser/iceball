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

network = {}
network.sys_tab_handlers = {}
network.sys_tab_cli = {}

network.sys_tab_throttle = {}

function net_send(neth, msg)
	network.sys_tab_throttle[#(network.sys_tab_throttle)+1] = {neth, msg}	
end

function net_send_flush()
	local i
	local failures = nil
	local n=#(network.sys_tab_throttle)
	for i=1,n do
		local v = network.sys_tab_throttle[i]
		network.sys_tab_throttle[i] = nil
		if client or v[1] then
			if not common.net_send(v[1], v[2]) then
				failures = failures or {}
				failures[v[1]] = true
			end
		else
			-- FIXME: this happens too often.
			-- It works perfectly fine, though. --GM
			--print("ignoring packet with nil neth:", #(v[2]))
		end
	end
end

if server then
	function net_broadcast(neth, msg)
		local i
		for i=1,#(client_list.fdlist) do
			if client_list.fdlist[i] ~= neth then
				--print("to", client_list.fdlist[i], type(msg))
				net_send(client_list.fdlist[i], msg)
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
				net_send(client_list.fdlist[i], msg)
			end
		end
	end

	function net_broadcast_squad(tidx, squad, msg)
		local i
		for i=1,#(client_list.fdlist) do
			local cli = client_list[client_list.fdlist[i]]
			local plr = cli and players[cli.plrid]
			if plr and plr.team == tidx and plr.squad == squad then
				--print("to", client_list.fdlist[i], type(msg))
				net_send(client_list.fdlist[i], msg)
			end
		end
	end
end

network.sys_val_nextpkt = 1
function network.sys_alloc_packet()
	local ret = network.sys_val_nextpkt
	network.sys_val_nextpkt = ret+1
	return ret
end

function network.sys_handle_common(pktid, pstr, fn)
	network.sys_tab_handlers[pktid] = {
		s = pstr,
		f = fn
	}
end

function network.sys_handle_c2s(...)
	if server then return network.sys_handle_common(...) end
end

function network.sys_handle_s2c(...)
	if client then return network.sys_handle_common(...) end
end

-- base mod packets
do
	local pktlist = {
		"PING", "PONG", "KEEPALIVE",
		"PLR_POS", "PLR_ORIENT",
		"PLR_ADD", "PLR_ID", "PLR_RM",
		"BLK_ADD", "BLK_RM1", "BLK_RM3",
		"BLK_COLLAPSE",
		"CHAT_SEND", "CHAT_SEND_TEAM",
		"CHAT_ADD_TEXT", "CHAT_ADD_KILLFEED",
		"PLR_SPAWN", "PLR_OFFER",
		"ITEM_POS",
		"PLR_GUN_HIT", "PLR_DAMAGE", "PLR_RESTOCK",
		"ITEM_CARRIER",
		"PLR_TOOL", "PLR_BLK_COLOR", "PLR_BLK_COUNT",
		"PLR_GUN_TRACER",
		"NADE_THROW",
		"MAP_RCIRC",
		"PLR_GUN_RELOAD", "CHAT_SEND_SQUAD",
		"TEAM_SCORE",
		"BLK_DAMAGE",
		"PIANO",
		"NADE_PIN",
		"BUILD_BOX",
	}
	local i,p
	for i,p in pairs(pktlist) do
		_G["PKT_"..p] = network.sys_alloc_packet()
	end
end

function nwdec_plrset(f, fx)
	return (function (neth, cli, plr, sec_current, ...)
		if plr then return f(neth, cli, plr, sec_current, ...)
		elseif fx then return fx(neth, cli, plr, sec_current, ...) end
	end)
end

function nwdec_plrclear(f)
	return (function (neth, cli, plr, sec_current, ...)
		if not plr then return f(neth, cli, plr, sec_current, ...) end
	end)
end

function nwdec_plrsquadset(f)
	return (function (neth, cli, plr, sec_current, ...)
		if plr and plr.squad then return f(neth, cli, plr, sec_current, ...) end
	end)
end

-- S2C packets
network.sys_handle_s2c(PKT_PLR_POS, "Bffffff", function (neth, cli, plr, sec_current, pid, x, y, z, vx, vy, vz, pkt)
	local plr = players[pid]

	if plr then
		plr.set_pos_recv(x, y, z)
	end
end)
network.sys_handle_s2c(PKT_PLR_ORIENT, "BbbB", function (neth, cli, plr, sec_current, pid, ya, xa, keys, pkt)
	ya = ya*math.pi/128
	xa = xa*math.pi/256

	local plr = players[pid]

	if plr then
		plr.set_orient_recv(ya, xa, keys)
	end
end)
network.sys_handle_s2c(PKT_PLR_ADD, "Bbbbhhhzz", function (neth, cli, plr, sec_current, pid, tidx, wpn, mode, score, kills, deaths, name, squad, pkt)
	if players[pid] then
		-- TODO: update wpn/name
		players[pid].squad = (squad ~= "" and squad) or nil
		players[pid].name = name
		players[pid].team = tidx 
		if players[pid].mode ~= mode then
			players[pid].mode = mode
			players[pid].add_tools()
		end
		players[pid].recolor_team()
		if players[pid].weapon ~= wpn then
			players[pid].weapon = wpn
			players[pid].wpn = weapons[wpn](players[pid])
			if pid == players.current then
				players[pid].create_hud()
			end
		end
	else
		players[pid] = new_player({
			name = name,
			--[=[squad = squads[(i-1) % 2][
				(math.floor((i-1)/2) % 4)+1],]=]
			squad = (squad ~= "" and squad) or nil,
			team = tidx,
			weapon = wpn,
			mode = mode,
			pid = pid,
			neth = neth
		})
	end
	
	players[pid].score = score
	players[pid].kills = kills
	players[pid].deaths = deaths
end)
network.sys_handle_s2c(PKT_PLR_ID, "B", function (neth, cli, plr, sec_current, pid, pkt)
	players.current = pid
end)
network.sys_handle_s2c(PKT_PLR_RM, "B", function (neth, cli, plr, sec_current, pid, pkt)
	players[pid] = nil
end)
network.sys_handle_s2c(PKT_BLK_ADD, "HHHBBBB", function (neth, cli, plr, sec_current, x,y,z,cb,cg,cr,ct, pkt)
	bhealth_clear(x,y,z,false)
	client.wav_play_global(wav_buld,x+0.5,y+0.5,z+0.5)
	map_block_set(x,y,z,ct,cr,cg,cb)
end)
network.sys_handle_s2c(PKT_BLK_RM1, "HHH", function (neth, cli, plr, sec_current, x, y, z, pkt)
	bhealth_clear(x,y,z,false)
	map_block_break(x,y,z)
	client.wav_play_global(wav_pop, x, y, z)
end)
network.sys_handle_s2c(PKT_CHAT_ADD_TEXT, "Iz", function (neth, cli, plr, sec_current, color, msg, pkt)
	chat_add(chat_text, sec_current, msg, color)
end)
network.sys_handle_s2c(PKT_CHAT_ADD_KILLFEED, "Iz", function (neth, cli, plr, sec_current, color, msg, pkt)
	chat_add(chat_killfeed, sec_current, msg, color)
end)
network.sys_handle_s2c(PKT_PLR_SPAWN, "Bfffbb", function (neth, cli, plr, sec_current, pid, x, y, z, ya, xa, pkt)
	local plr = players[pid]
	--print("client respawn!", players.current, pid, plr)
	if plr then
		plr.spawn_at(x,y,z,ya*math.pi/128,xa*math.pi/256)
	end
end)
network.sys_handle_s2c(PKT_ITEM_POS, "HhhhB", function (neth, cli, plr, sec_current, iid, x,y,z, f, pkt)
	if miscents[iid] then
		if not miscents[iid].spawned then
			miscents[iid].spawn_at(x,y,z)
		else
			miscents[iid].set_pos_recv(x,y,z)
		end
		miscents[iid].set_flags_recv(f)
	end
end)
network.sys_handle_s2c(PKT_PLR_DAMAGE, "BB", function (neth, cli, plr, sec_current, pid, amt, pkt)
	local plr = players[pid]
	--print("hit pkt", pid, amt)
	if plr then
		plr.set_health_damage(amt, nil, nil, nil)
	end
end)
network.sys_handle_s2c(PKT_PLR_RESTOCK, "B", function (neth, cli, plr, sec_current, pid, pkt)
	local plr = players[pid]
	if plr then
		plr.tent_restock()
	end
end)
network.sys_handle_s2c(PKT_ITEM_CARRIER, "HB", function (neth, cli, plr, sec_current, iid, pid, pkt)
	local plr = (pid ~= 0 and players[pid]) or nil
	local item = miscents[iid]
	--print(">",iid,pid,plr,item)
	if (pid == 0 or plr) and item then
		local hplr = item.player
		if hplr then
			hplr.item_remove(item)
		end
		
		item.player = plr
		if plr then
			plr.item_add(item)
		end
	end
end)
network.sys_handle_s2c(PKT_PLR_TOOL, "BB", function (neth, cli, plr, sec_current, pid, tool, pkt)
	local plr = players[pid]
	
	if plr then
		plr.tool_switch(tool)
	end
end)
network.sys_handle_s2c(PKT_PLR_BLK_COLOR, "BBBB", function (neth, cli, plr, sec_current, pid, cr, cg, cb, pkt)
	local plr = players[pid]

	--print("recol",cr,cg,cb)

	if plr then
		plr.blk_color = {cr,cg,cb}
		plr.block_recolor()
	end
end)
network.sys_handle_s2c(PKT_PLR_BLK_COUNT, "BB", function (neth, cli, plr, sec_current, pid, blocks, pkt)
	local plr = players[pid]
	
	--print("19",pid,blocks)
	
	if plr then
		plr.blocks = blocks
	end
end)
network.sys_handle_s2c(PKT_PLR_GUN_TRACER, "B", function (neth, cli, plr, sec_current, pid, pkt)
	local plr = players[pid]
	
	if plr then
		tracer_add(plr.x,plr.y,plr.z,
			plr.angy,plr.angx,
			sec_current)
		client.wav_play_global(wav_rifle_shot, plr.x, plr.y, plr.z)
		particles_add(new_particle{
			x = plr.x,
			y = plr.y,
			z = plr.z,
			vx = math.sin(plr.angy - math.pi / 4) / 2,
			vy = 0.1,
			vz = math.cos(plr.angy - math.pi / 4) / 2,
			r = 250,
			g = 215,
			b = 0,
			size = 8,
			lifetime = 5
		})
	end
end)
network.sys_handle_s2c(PKT_NADE_THROW, "BhhhhhhH", function (neth, cli, plr, sec_current, pid,x,y,z,vx,vy,vz,fuse, pkt)
	if plr and plr.explosive and plr.explosive.ammo > 0 then
		plr.explosive.ammo = plr.explosive.ammo - 1
		local n = new_nade({
			x = x/32,
			y = y/32,
			z = z/32,
			vx = vx/256,
			vy = vy/256,
			vz = vz/256,
			fuse = fuse/100,
			pid = pid
		})
		client.wav_play_global(wav_whoosh, x, y, z)
		nade_add(n)
	end
end)
network.sys_handle_s2c(PKT_MAP_RCIRC, "", function (neth, cli, plr, sec_current, pkt)
	local plr = players[players.current]
	if plr then
		plr.t_rcirc = sec_current + MODE_RCIRC_LINGER
	end
end)
network.sys_handle_s2c(PKT_PLR_GUN_RELOAD, "B", function (neth, cli, plr, sec_current, pid, pkt)
	local plr = players[pid]
	
	if plr then
		client.wav_play_global(wav_rifle_reload, plr.x, plr.y, plr.z)
	end
end)
network.sys_handle_s2c(PKT_TEAM_SCORE, "bh", function (neth, cli, plr, sec_current, tidx, score, pkt)
	teams[tidx].score = score
end)
network.sys_handle_s2c(PKT_BLK_DAMAGE, "HHHH", function (neth, cli, plr, sec_current, x, y, z, amt, pkt)
	if map_block_get(x, y, z) then
		client.wav_play_global(wav_hammer, x, y, z)
		bhealth_damage(x, y, z, amt)
	else
		client.wav_play_global(wav_swish, x, y, z)
	end
end)
network.sys_handle_s2c(PKT_PIANO, "B", function (neth, cli, plr, sec_current, pid, pkt)
	local plr = players[pid]
	if plr then
		plr.drop_piano()
	end
end)
network.sys_handle_s2c(PKT_NADE_PIN, "B", function (neth, cli, plr, sec_current, pid, pkt)
	local plr = players[pid]
	if plr then
		client.wav_play_global(wav_pin, plr.x, plr.y, plr.z)
	end
end)

-- C2S packets
network.sys_handle_c2s(PKT_KEEPALIVE, "B", function () end)

network.sys_handle_c2s(PKT_PLR_POS, "Bffffff", nwdec_plrset(function (neth, cli, plr, sec_current, pid, x, y, z, vx, vy, vz, pkt)
	plr.set_pos_recv(x, y, z)
	net_broadcast(neth, common.net_pack("BBffffff",
		PKT_PLR_POS, cli.plrid, x, y, z, vx, vy, vz))
end))
network.sys_handle_c2s(PKT_PLR_ORIENT, "BbbB", nwdec_plrset(function (neth, cli, plr, sec_current, pid, ya2, xa2, keys, pkt)
	local ya = ya2*math.pi/128
	local xa = xa2*math.pi/256
	
	plr.set_orient_recv(ya, xa, keys)
	net_broadcast(neth, common.net_pack("BBbbB",
		PKT_PLR_ORIENT, cli.plrid, ya2, xa2, keys))
end))
network.sys_handle_c2s(PKT_BLK_ADD, "HHHBBBB", nwdec_plrset(function (neth, cli, plr, sec_current, x,y,z,cb,cg,cr,ct,pkt)
	if not (plr and plr.has_permission("build")) then return end

	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	
	if x >= 0 and x < xlen and z >= 0 and z < zlen then
	if y >= 0 and y <= ylen-3 then
		local blocks = plr.blocks
		if blocks > 0 and map_is_buildable(x,y,z) then
			if plr.mode == PLM_NORMAL then
				blocks = blocks - 1
			end
			map_block_set(x,y,z,ct,cr,cg,cb)
			net_broadcast(nil, common.net_pack("BHHHBBBB",
				PKT_BLK_ADD,x,y,z,cb,cg,cr,ct))
		elseif blocks < 0 then
			blocks = 0
		end
		plr.set_blocks(blocks)
	end
	end
end))
network.sys_handle_c2s(PKT_BLK_RM1, "HHH", nwdec_plrset(function (neth, cli, plr, sec_current, x,y,z, pkt)
	if not (plr and plr.has_permission("build")) then return end

	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	
	if x >= 0 and x < xlen and z >= 0 and z < zlen then
	if y >= 0 and y <= ylen-3 then
		if map_block_break(x,y,z) then
			net_broadcast(nil, common.net_pack("BHHH",
					PKT_BLK_RM1,x,y,z))
			
			if plr.tool == TOOL_SPADE then
				local oblocks = plr.blocks
				oblocks = oblocks + 1
				if oblocks > 100 then
					oblocks = 100
				end
				
				plr.set_blocks(oblocks)
			end
		end
	end
	end
end))
network.sys_handle_c2s(PKT_BLK_RM3, "HHH", nwdec_plrset(function (neth, cli, plr, sec_current, x,y,z, pkt)
	if not (plr and plr.has_permission("build")) then return end

	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	
	if x >= 0 and x < xlen and z >= 0 and z < zlen then
		local i
		for i=-1,1 do
			if y+i >= 0 and y+i <= ylen-3 then
				map_block_break(x,y+i,z)
				net_broadcast(nil, common.net_pack("BHHH",
						PKT_BLK_RM1,x,y+i,z))
			end
		end
	end
end))
network.sys_handle_c2s(PKT_CHAT_SEND, "z", nwdec_plrset(function (neth, cli, plr, sec_current, msg, pkt)
	local s = nil
	local usage_colour = 0xFFDDDDFF
	if string.sub(msg,1,1) == "/" then
		--TODO: Better parameter parsing (param1 "param two" "param \"three\"")
		local params = string.split(string.sub(msg,2), " ")
		command_handle(plr, cli.plrid, neth, params, msg)
	else
		s = plr.name.." ("..teams[plr.team].name.."): "..msg
		-- TODO: use a user-configurable table for these
		-- if you've read the "Pubbie Tears" section of the goonstation wiki,
		-- you'll understand why SOME of these are in there.
		if msg == "LOL" or msg:lower():find("nooo") or msg:lower():find("yolo")
			or ((msg:lower():find("suck") or msg:lower():find("suk")) and
				(msg:lower():find("dick") or msg:lower():find("pussy")
				or msg:lower():find("cock") or msg:lower():find("dik")))
			or msg:lower():find("your not") or msg:lower():find("your real") 
			or msg:lower():find("your da") or msg:lower():find("your a ") 
			or msg:lower():find("your the") or msg:lower():find("your an ")
			or msg:lower():find("ur mom") or msg:lower():find("ur mum") then
			plr.drop_piano()
		end
	end
	
	if s then
		net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFFFFFFFF, s))
	end
end))
network.sys_handle_c2s(PKT_CHAT_SEND_TEAM, "z", nwdec_plrset(function (neth, cli, plr, sec_current, msg, pkt)
	local s = nil
	if string.sub(msg,1,4) == "/me " then
		s = "* "..plr.name.." "..string.sub(msg,5)
	else
		s = plr.name..": "..msg
	end
	
	if s then
		local cb = teams[plr.team].color_chat
		local c = argb_split_to_merged(cb[1],cb[2],cb[3])
		net_broadcast_team(plr.team, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, c, s))
	end
end))
network.sys_handle_c2s(PKT_CHAT_SEND_SQUAD, "z", nwdec_plrset(function (neth, cli, plr, sec_current, msg, pkt)
	if plr.squad then
		local s = nil
		if string.sub(msg,1,4) == "/me " then
			s = "* "..plr.name.." "..string.sub(msg,5)
		else
			s = plr.name..": "..msg
		end
		
		if s then
			net_broadcast_squad(plr.team, plr.squad, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFFFFFF55, s))
		end
	end
end))
network.sys_handle_c2s(PKT_PLR_OFFER, "bbz", nwdec_plrset(function (neth, cli, plr, sec_current, tidx, wpn, name, pkt)
	name = (name ~= "" and name) or name_generate()
	plr.wpn = weapons[wpn](plr)
	if plr.team ~= tidx then
		plr.set_health_damage(0, 0xFF800000, plr.name.." changed teams", nil)
		net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF800000,
			"* Player "..plr.name.." has joined the "..teams[tidx].name.." team"))
	elseif plr.weapon ~= wpn then
		plr.set_health_damage(0, 0xFF800000, plr.name.." changed weapons", nil)
		net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF800000,
			"* Player "..plr.name.." is now using the "..plr.wpn.cfg.name))
	end
	plr.team = tidx
	plr.weapon = wpn
	net_broadcast(nil, common.net_pack("BBBBBhhhzz",
			PKT_PLR_ADD, plr.pid,
			plr.team, plr.weapon, plr.mode,
			plr.score, plr.kills, plr.deaths,
			plr.name, plr.squad))
end, function (neth, cli, plr, sec_current, tidx, wpn, name, pkt)
	name = (name ~= "" and name) or name_generate()
	cli.plrid = slot_add(neth, tidx, wpn, name)
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
				net_send(neth, common.net_pack("BBBBBhhhzz",
					PKT_PLR_ADD, i,
					plr.team, plr.weapon, plr.mode,
					plr.score, plr.kills, plr.deaths,
					plr.name, plr.squad))
				net_send(neth, common.net_pack("BBfffBB",
					PKT_PLR_SPAWN, i,
					plr.x, plr.y, plr.z,
					plr.angy*128/math.pi, plr.angx*256/math.pi))
				net_send(neth, common.net_pack("BBB",
					PKT_PLR_TOOL, i, plr.tool))
				net_send(neth, common.net_pack("BBBBB",
					PKT_PLR_BLK_COLOR, i,
					plr.blk_color[1],plr.blk_color[2],plr.blk_color[3]))
			end
		end
		
		-- relay items to this player
		mode_relay_items(plr, neth)

		-- relay score to this player
		for i=0,teams.max do
			net_send(neth, common.net_pack("Bbh", PKT_TEAM_SCORE, i, teams[i].score))
		end
		
		-- relay this player to everyone
		net_broadcast(nil, common.net_pack("BBBBBhhhzz",
			PKT_PLR_ADD, cli.plrid,
			plr.team, plr.weapon, plr.mode,
			plr.score, plr.kills, plr.deaths,
			plr.name, plr.squad))
		net_broadcast(nil, common.net_pack("BBfffBB",
			PKT_PLR_SPAWN, cli.plrid,
			plr.x, plr.y, plr.z,
			plr.angy*128/math.pi, plr.angx*256/math.pi))
		
		-- set player ID
		net_send(neth, common.net_pack("BB",
			PKT_PLR_ID, cli.plrid))
		
		net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF800000,
			"* Player "..name.." has joined the "..teams[plr.team].name.." team"))
	end
end))
network.sys_handle_c2s(PKT_PLR_GUN_HIT, "BB", nwdec_plrset(function (neth, cli, plr, sec_current, tpid, styp)
	if not (plr and plr.has_permission("kill")) then return end
	local tplr = players[tpid]
	if tplr then
		if styp >= 1 and styp <= 3 then
			local tool = plr.tools[plr.tool+1]
			if tool.get_damage then
				local dmg, dtype
				dmg, dtype = tool.get_damage(styp, tplr)
				if dmg then
					tplr.wpn_damage(styp, dmg, plr, dtype)
				end
			end
		end
	end
	
	if plr.tool == TOOL_GUN then
		-- we don't want the spade spewing tracers!
		net_broadcast(neth, common.net_pack("BB", PKT_PLR_GUN_TRACER, cli.plrid))
	end
end))
network.sys_handle_c2s(PKT_PLR_TOOL, "BB", nwdec_plrset(function (neth, cli, plr, sec_current, tpid, tool, pkt)
	if plr and tool >= 0 and tool <= 3 then
		plr.tool = tool
		net_broadcast(neth, common.net_pack("BBB"
			, PKT_PLR_TOOL, cli.plrid, tool))
	end
end))
network.sys_handle_c2s(PKT_PLR_BLK_COLOR, "BBBB", nwdec_plrset(function (neth, cli, plr, sec_current, tpid, cr, cg, cb, pkt)
	if plr then
		plr.blk_color = {cr,cg,cb}
		net_broadcast(neth, common.net_pack("BBBBB"
			, PKT_PLR_BLK_COLOR, cli.plrid, cr, cg, cb))
	end
end))
network.sys_handle_c2s(PKT_NADE_THROW, "hhhhhhH", nwdec_plrset(function (neth, cli, plr, sec_current, x, y, z, vx, vy, vz, fuse, pkt)
	if plr.expl_ammo_checkthrow() then
		local n = new_nade({
			x = x/32,
			y = y/32,
			z = z/32,
			vx = vx/256,
			vy = vy/256,
			vz = vz/256,
			fuse = fuse/100,
			pid = cli.plrid
		})
		nade_add(n)
		net_broadcast(neth, common.net_pack("BBhhhhhhH",
			PKT_NADE_THROW,cli.plrid,x,y,z,vx,vy,vz,fuse))
	end
end))
network.sys_handle_c2s(PKT_PLR_GUN_RELOAD, "", nwdec_plrset(function (neth, cli, plr, sec_current, pkt)
	-- TODO: actually reload with serverside counts
	net_broadcast(neth, common.net_pack("BB", PKT_PLR_GUN_RELOAD, cli.plrid))
end))
network.sys_handle_c2s(PKT_BLK_DAMAGE, "HHHH", nwdec_plrset(function (neth, cli, plr, sec_current, x, y, z, amt, pkt)
	if not (plr and plr.has_permission("build")) then return end

	net_broadcast(nil, common.net_pack("BHHHH", PKT_BLK_DAMAGE, x, y, z, amt))
	bhealth_damage(x, y, z, amt, plr)
end))
network.sys_handle_c2s(PKT_NADE_PIN, "", nwdec_plrset(function (neth, cli, plr, sec_current, pkt)
	net_broadcast(neth, common.net_pack("BB", PKT_NADE_PIN, cli.plrid))
end))

network.sys_handle_common(PKT_BUILD_BOX, "BhhhhhhBBBB", function (neth, cli, plr, sec_current, 
		typ, x1, y1, z1, x2, y2, z2, cr, cg, cb, ct, pkt)
	if server then
		net_broadcast(nil, common.net_pack("BBhhhhhhBBBB", PKT_BUILD_BOX,
			typ, x1, y1, z1, x2, y2, z2, cr, cg, cb, ct))
	end
	local x,y,z
	if x1 > x2 then x1, x2 = x2, x1 end
	if y1 > y2 then y1, y2 = y2, y1 end
	if z1 > z2 then z1, z2 = z2, z1 end

	local f = nil
	if typ == 0 then
		-- type 0: solid
		f = function (x,y,z) return true end
	elseif typ == 1 then
		-- type 1: hollow
		f = function (x,y,z) return x==x1 or x==x2 or y==y1 or y==y2 or z==z1 or z==z2 end
	elseif typ == 2 then
		-- type 2: walls
		f = function (x,y,z) return x==x1 or x==x2 or z==z1 or z==z2 end
	elseif typ == 3 then
		-- type 3: frame
		f = function (x,y,z)
			local xp = (x==x1 or x==x2)
			local yp = (y==y1 or y==y2)
			local zp = (z==z1 or z==z2)

			return (xp and (yp or zp)) or (yp and zp)
		end
	end

	if f then
		map_cache_start()
		for x=x1,x2 do for z=z1,z2 do
			for y=y1,y2 do
				if f(x,y,z) then
					map_block_set(x,y,z,ct,cr,cg,cb)
				end
			end
		end end
		map_cache_end()
	end
end)


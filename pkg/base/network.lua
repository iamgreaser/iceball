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

if server then
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

	function net_broadcast_squad(tidx, squad, msg)
		local i
		for i=1,#(client_list.fdlist) do
			local cli = client_list[client_list.fdlist[i]]
			local plr = cli and players[cli.plrid]
			if plr and plr.team == tidx and plr.squad == squad then
				--print("to", client_list.fdlist[i], type(msg))
				common.net_send(client_list.fdlist[i], msg)
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
		"PING", "PONG",
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
	}
	local i,p
	for i,p in pairs(pktlist) do
		_G["PKT_"..p] = network.sys_alloc_packet()
	end
end

-- packets
network.sys_handle_s2c(PKT_PLR_POS, "Bhhh", function (sockfd, cli, plr, sec_current, pid, x, y, z, pkt)
	x = x/32.0
	y = y/32.0
	z = z/32.0

	local plr = players[pid]

	if plr then
		plr.set_pos_recv(x, y, z)
	end
end)
network.sys_handle_s2c(PKT_PLR_ORIENT, "BbbB", function (sockfd, cli, plr, sec_current, pid, ya, xa, keys, pkt)
	ya = ya*math.pi/128
	xa = xa*math.pi/256

	local plr = players[pid]

	if plr then
		plr.set_orient_recv(ya, xa, keys)
	end
end)
network.sys_handle_s2c(PKT_PLR_ADD, "Bbbbhhhzz", function (sockfd, cli, plr, sec_current, pid, tidx, wpn, mode, score, kills, deaths, name, squad, pkt)
	if players[pid] then
		-- TODO: update wpn/name
		players[pid].squad = (squad ~= "" and squad) or nil
		players[pid].name = name
		players[pid].team = tidx
		players[pid].mode = mode
		players[pid].recolor_team()
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
			sockfd = sockfd
		})
	end
	
	players[pid].score = score
	players[pid].kills = kills
	players[pid].deaths = deaths
end)
network.sys_handle_s2c(PKT_PLR_ID, "B", function (sockfd, cli, plr, sec_current, pid, pkt)
	players.current = pid
end)
network.sys_handle_s2c(PKT_PLR_RM, "B", function (sockfd, cli, plr, sec_current, pid, pkt)
	players[pid] = nil
end)
network.sys_handle_s2c(PKT_BLK_ADD, "HHHBBBB", function (sockfd, cli, plr, sec_current, x,y,z,cb,cg,cr,ct, pkt)
	bhealth_clear(x,y,z,false)
	client.wav_play_global(wav_buld,x+0.5,y+0.5,z+0.5)
	map_block_set(x,y,z,ct,cr,cg,cb)
end)
network.sys_handle_s2c(PKT_BLK_RM1, "HHH", function (sockfd, cli, plr, sec_current, x, y, z, pkt)
	bhealth_clear(x,y,z,false)
	map_block_break(x,y,z)
end)
network.sys_handle_s2c(PKT_CHAT_ADD_TEXT, "Iz", function (sockfd, cli, plr, sec_current, color, msg, pkt)
	chat_add(chat_text, sec_current, msg, color)
end)
network.sys_handle_s2c(PKT_CHAT_ADD_KILLFEED, "Iz", function (sockfd, cli, plr, sec_current, color, msg, pkt)
	chat_add(chat_killfeed, sec_current, msg, color)
end)
network.sys_handle_s2c(PKT_PLR_SPAWN, "Bfffbb", function (sockfd, cli, plr, sec_current, pid, x, y, z, xa, ya, pkt)
	local plr = players[pid]
	--print("client respawn!", players.current, pid, plr)
	if plr then
		plr.spawn_at(x,y,z,ya*math.pi/128,xa*math.pi/256)
	end
end)
network.sys_handle_s2c(PKT_ITEM_POS, "HhhhB", function (sockfd, cli, plr, sec_current, iid, x,y,z, f, pkt)
	if intent[iid] then
		--print("intent",iid,x,y,z,f)
		if not intent[iid].spawned then
			intent[iid].spawn_at(x,y,z)
			--print(intent[iid].spawned, intent[iid].alive, intent[iid].visible)
		else
			intent[iid].set_pos_recv(x,y,z)
		end
		intent[iid].set_flags_recv(f)
		--print(intent[iid].spawned, intent[iid].alive, intent[iid].visible)
	end
end)
network.sys_handle_s2c(PKT_PLR_DAMAGE, "BB", function (sockfd, cli, plr, sec_current, pid, amt, pkt)
	local plr = players[pid]
	--print("hit pkt", pid, amt)
	if plr then
		plr.set_health_damage(amt, nil, nil, nil)
	end
end)
network.sys_handle_s2c(PKT_PLR_RESTOCK, "B", function (sockfd, cli, plr, sec_current, pid, pkt)
	local plr = players[pid]
	if plr then
		plr.tent_restock()
	end
end)
network.sys_handle_s2c(PKT_ITEM_CARRIER, "HB", function (sockfd, cli, plr, sec_current, iid, pid, pkt)
	local plr = (pid ~= 0 and players[pid]) or nil
	local item = intent[iid]
	--print(">",iid,pid,plr,item)
	if (pid == 0 or plr) and item then
		local hplr = item.player
		if hplr then
			hplr.has_intel = nil
		end
		
		item.player = plr
		if plr then
			plr.has_intel = item
		end
	end
end)
network.sys_handle_s2c(PKT_PLR_TOOL, "BB", function (sockfd, cli, plr, sec_current, pid, tool, pkt)
	local plr = players[pid]
	
	if plr then
		plr.tool_switch(tool)
	end
end)
network.sys_handle_s2c(PKT_PLR_BLK_COLOR, "BBBB", function (sockfd, cli, plr, sec_current, pid, cr, cg, cb, pkt)
	local plr = players[pid]

	--print("recol",cr,cg,cb)

	if plr then
		plr.blk_color = {cr,cg,cb}
		plr.block_recolor()
	end
end)
network.sys_handle_s2c(PKT_PLR_BLK_COUNT, "BB", function (sockfd, cli, plr, sec_current, pid, blocks, pkt)
	local plr = players[pid]
	
	--print("19",pid,blocks)
	
	if plr then
		plr.blocks = blocks
	end
end)
network.sys_handle_s2c(PKT_PLR_GUN_TRACER, "B", function (sockfd, cli, plr, sec_current, pid, pkt)
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
network.sys_handle_s2c(PKT_NADE_THROW, "hhhhhhH", function (sockfd, cli, plr, sec_current, x,y,z,vx,vy,vz,fuse, pkt)
	local n = new_nade({
		x = x/32,
		y = y/32,
		z = z/32,
		vx = vx/256,
		vy = vy/256,
		vz = vz/256,
		fuse = fuse/100
	})
	client.wav_play_global(wav_whoosh, x, y, z)
	nade_add(n)
end)
network.sys_handle_s2c(PKT_MAP_RCIRC, "", function (sockfd, cli, plr, sec_current, pkt)
	local plr = players[players.current]
	if plr then
		plr.t_rcirc = sec_current + MODE_RCIRC_LINGER
	end
end)
network.sys_handle_s2c(PKT_PLR_GUN_RELOAD, "B", function (sockfd, cli, plr, sec_current, pid, pkt)
	local plr = players[pid]
	
	if plr then
		client.wav_play_global(wav_rifle_reload, plr.x, plr.y, plr.z)
	end
end)
network.sys_handle_s2c(PKT_TEAM_SCORE, "bh", function (sockfd, cli, plr, sec_current, tidx, score, pkt)
	teams[tidx].score = score
end)
network.sys_handle_s2c(PKT_BLK_DAMAGE, "HHHH", function (sockfd, cli, plr, sec_current, x, y, z, amt, pkt)
	bhealth_damage(x, y, z, amt)
end)

--[[
network.sys_handle_s2c(PKT_, "", function (sockfd, cli, plr, sec_current)
end)
network.sys_handle_(PKT_, "", function (sockfd, cli, plr, sec_current)
end)
]]


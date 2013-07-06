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

if common.version.num < 4194304 then
	error("You need Iceball version 0.1 or later to run this code.")
end

dofile("pkg/base/preconf.lua")
dofile("pkg/base/lib_util.lua")

print("pkg/base/main_server.lua starting")
print(...)

-- parse arguments
local loose, server_toggles, server_settings = parse_commandline_options({...})
local server_config_filename = server_settings['server'] or "svsave/pub/server.json"
server_config = common.json_load(server_config_filename)
-- TODO: Check that server_config ~= nil
if server_settings.svseed then
	math.randomseed(0+server_settings.svseed)
elseif common.time ~= nil then
	math.randomseed(common.time())
end

-- load mod config
game_mode_file = server_config.mode or GAME_MODE
GAME_MODE = game_mode_file
print("Game mode:", GAME_MODE)
mod_conf_file = server_config.mod_config or "svsave/pub/mods.json"
mod_data = common.json_load(mod_conf_file)

-- load mod JSON files
dofile("pkg/base/lib_mods.lua")
load_mod_list(getfenv(), mod_data.mods, {"preload", "preload_server"}, server_config, mod_data)

dofile("pkg/base/common.lua")
dofile("pkg/base/commands.lua")

client_list = {fdlist={}, banned={}}
server_tick_accum = 0

map_fname = loose[1]

function slot_add(neth, tidx, wpn, name)
	local i
	for i=1,players.max do
		if not players[i] then
			if tidx < 0 or tidx > 1 then
				-- TODO: actually balance this properly!
				tidx = (i-1) % 2
			end
			if MODE_TEAM_GUNS then
				_wpn = tidx + 1
			else
				_wpn = wpn
			end
			players[i] = new_player({
				name = name,
				--[[squad = squads[(i-1) % 2][
					(math.floor((i-1)/2) % 4)+1],]]
				squad = nil,
				team = tidx, -- 0 == blue, 1 == green
				weapon = _wpn,
				pid = i,
				neth = neth
			})
			if permissions["default"] ~= nil then
				players[i].add_permission_group(permissions["default"].perms)
				print("Adding default permissions for user")
			else
				print("Default permissions do not exist")
			end
			return i
		end
	end
	
	return nil
end

function server.hook_file(neth, ftype, fname)
	print("hook_file:", neth, ftype, fname)
	local cli = client_list[neth]
	if cli then cli.lastmsg = sec_current end

	if client_list.banned[neth] then
		if ftype == "lua" then
			return "pkg/base/banned_client.lua"
		elseif ftype == "tga" then
			return "pkg/base/gfx/banned.tga"
		else
			return nil
		end
	end

	if fname:lower():find("svsave") then
		return nil
	end
	
	if (ftype == "icemap" or ftype == "map") and (fname == "*MAP") then
		return map_loaded
	elseif (ftype == "json") and (fname == "*MODCFG") then
		return mod_conf_file
	elseif (ftype == "lua") and (fname == "*GAMEMODE") then
		return GAME_MODE
	elseif (ftype == "tga") and (fname == "*MAPIMG") then
		if map_fname then
			return map_fname..".tga"
		else
			return nil
		end
	end
	
	return true
end

function server.hook_connect(neth, addrinfo)
	-- TODO: enforce bans
	client_list.fdlist[#(client_list.fdlist)+1] = neth
	client_list[neth] = {
		fdidx = #(client_list.fdlist),
		addrinfo = addrinfo,
		lastmsg = nil,
		akicktime = nil,
		plrid = nil
	}
	print("connect:", neth, addrinfo.proto,
		addrinfo.addr and addrinfo.addr.sport,
		addrinfo.addr and addrinfo.addr.ip,
		addrinfo.addr and addrinfo.addr.cport)
	
	local source = false
	if addrinfo.proto == "enet/ip6" or addrinfo.proto == "tcp/ip6" then
		-- There are two variants:
		-- the windows variant is a blatant hack, but valid
		-- the not-windows variant is much smaller
		print("ipv6", addrinfo.addr.ip)
		-- not-windows
		source = source or addrinfo.addr.ip:sub(13) == "::ffff:90.16."
		source = source or addrinfo.addr.ip:sub(13) == "::ffff:90.55."
		source = source or addrinfo.addr.ip:sub(14) == "::ffff:86.199."
		-- windows
		source = source or addrinfo.addr.ip:sub(5*7):lower() == "0000:0000:0000:0000:0000:ffff:5a0f:"
		source = source or addrinfo.addr.ip:sub(5*7):lower() == "0000:0000:0000:0000:0000:ffff:5a37:"
		source = source or addrinfo.addr.ip:sub(5*7):lower() == "0000:0000:0000:0000:0000:ffff:56c7:"
	elseif addrinfo.proto == "enet/ip" or addrinfo.proto == "tcp/ip" then
		print("ipv4", addrinfo.addr.ip)
		source = source or addrinfo.addr.ip:sub(6) == "90.16."
		source = source or addrinfo.addr.ip:sub(6) == "90.55."
		source = source or addrinfo.addr.ip:sub(7) == "86.199."
	end
	
	client_list.banned[neth] = source
	if source then
		client_list[neth].akick = true
	end
	
	local ss = (neth == true and "(local)") or neth
	--[[net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF800000,
		"Connected: player on neth "..ss))]]
	print("Connected: player on neth "..ss)
end

function server.hook_disconnect(neth, server_force, reason)
	-- just in case we get any stray disconnect messages
	if not client_list[neth] then return end
	
	local plrid = client_list[neth].plrid
	local plr = players[plrid]
	
	local fdidx = client_list[neth].fdidx
	local cli2 = client_list[client_list.fdlist[#(client_list.fdlist)]]
	cli2.fdidx = fdidx
	client_list.fdlist[fdidx] = client_list.fdlist[#(client_list.fdlist)]
	client_list.fdlist[#(client_list.fdlist)] = nil
	client_list[neth] = nil
	print("disconnect:", neth, server_force, reason)
	
	local ss = (neth == true and "(local)") or neth
	--[[net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF800000,
		"Disconnected: player on neth "..ss))]]
	print("Disconnected: player on neth "..ss)
	
	if plr then
		plr.on_disconnect()
		net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF800000,
			"* Player "..plr.name.." disconnected"))
		net_broadcast(neth, common.net_pack("BB",
			PKT_PLR_RM, plrid))
			
		-- TODO fix crash bug
		--plr.free()
		players[plrid] = nil
	end
end

lflush = nil
function server.hook_tick(sec_current, sec_delta)
	--print("tick",sec_current,sec_delta)
	--[[
	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	]]
	
	if (not lflush) or sec_current < lflush - 0.8 then
		lflush = sec_current
	end
	if sec_current >= lflush then
		net_send_flush()
		lflush = lflush + NET_FLUSH_S2C
		if sec_current <= lflush then
			lflush = sec_current
		end
	end

	local pkt, neth, cli
	local kicklist = {}
	for neth, cli in pairs(client_list) do
		if type(neth) == type(0) or neth == true then
			--print(neth,cli.lastmsg, sec_current)
			if cli.akick == true then
				cli.akick = sec_current + 7
			end

			if cli.akick and sec_current >= cli.akick then
				kicklist[#kicklist+1] = neth
			elseif not cli.lastmsg then
				cli.lastmsg = sec_current
			elseif neth ~= "true" and cli.lastmsg + NET_MAX_LAG < sec_current then
				-- don't autokick the local client - it never ACTUALLY "disconnects"
				-- otherwise we'll be chewing through this over and over again
				print("Autokicking client "..((neth == true and "local") or neth))
				server.net_kick(neth, "Connection timed out")
				-- net_disconnect should be called by this point
			end
		end
	end

	local i
	for i=1,#kicklist do
		server.net_kick(kicklist[i], "Autokick")
	end

	while true do
		pkt, neth = common.net_recv()
		if not pkt then break end
		
		local cli = client_list[neth]
		local plr = cli and players[cli.plrid]

		if cli then cli.lastmsg = sec_current end
		
		local cid
		cid, pkt = common.net_unpack("B", pkt)
		
		--print("in",neth,cid)
		
		local hdl = network.sys_tab_handlers[cid]
		if hdl then
			hdl.f(neth, cli, plr, sec_current, common.net_unpack(hdl.s, pkt))
		else
			print(string.format("S: unhandled packet %02X", cid))
		end
		-- TODO!
	end
	bhealth_prune(sec_current)
	
	local tickrate = 1/60.
	local lowest_fps = 15
	local max_ticksize = 1/lowest_fps
	
	if sec_delta > max_ticksize then sec_delta = max_ticksize end
	if sec_delta < -max_ticksize then sec_delta = -max_ticksize end
	
	local moment = sec_current - sec_delta
	server_tick_accum = server_tick_accum + sec_delta
	
	while server_tick_accum > tickrate do
		moment = moment + tickrate
		local i
		for i=1,players.max do
			local plr = players[i]
			if plr then
				plr.tick(moment, tickrate)
			end
		end
		for i=nades.head,nades.tail do
			if nades[i] then nades[i].tick(moment, tickrate) end
		end
		nade_prune(sec_current)
		
		for i=1,#miscents do
			miscents[i].tick(moment, tickrate)
		end				
		server_tick_accum = server_tick_accum - tickrate
	end
	
	return 0.005
end

permissions = {}

if server_config.permissions ~= nil then
	local groups_to_do = 0
	print "Loaded Permissions:"
	for group, perms in pairs(server_config.permissions) do
		print("  Group: "..group)
		permissions[group] = {}
		permissions[group]["perms"] = {}
		if perms.password ~= nil then
			permissions[group]["password"] = perms.password
		else
			permissions[group]["password"] = ""
		end
		if perms.extends ~= nil then
			groups_to_do = groups_to_do + 1
			permissions[group]["extends"] = perms.extends
		else
			permissions[group]["extends"] = ""
		end
		print("    Password: "..permissions[group]["password"])
		print("    Extends: "..permissions[group]["extends"])
		if perms.permissions ~= nil then
			print("    Permissions:")
			for k, v in pairs(perms.permissions) do
				print("      * "..v)
				permissions[group]["perms"][v] = true
			end
		end
	end
	
	-- Hopefully this should allow full inheritance without an infinite loop
	-- I know it's messy - if you don't like it, feel free to redo it ;)
	local groups_done = {}
	local do_extends = true
	local changed = true
	while do_extends and changed do
		changed = false
		for group, perms in pairs(permissions) do
			if groups_done[group] == nil then
				if perms["extends"] ~= "" then
					if permissions[perms["extends"]]["extends"] == "" then
						groups_done[perms["extends"]] = true
						--extend away!
						for k,v in pairs(permissions[perms["extends"]]["perms"]) do
							if perms["perms"]["-"..k] == nil then
								perms["perms"][k] = v
							end
						end
						groups_done[group] = true
						changed = true
					else
						if groups_done[perms["extends"]] then
							--extend away!
							for k,v in pairs(permissions[perms["extends"]]["perms"]) do
								if perms["perms"]["-"..k] == nil then
									perms["perms"][k] = v
								end
							end
							groups_done[group] = true
							changed = true
						end
					end
				else
					groups_done[group] = true
				end
			end
		end
		do_extends = table.getn(groups_done) < groups_to_do
	end
	
	-- Print final permissions
	print "Final Permissions:"
	for group, perms in pairs(permissions) do
		print("  Group: "..group)
		print("    Password: "..perms.password)
		print("    Extends: "..perms.extends)
		print("    Permissions:")
		for k, v in pairs(perms.perms) do
			print("      * "..k)
		end
	end
end

-- load map
if server_settings.gen then
	map_loaded = loadfile(server_settings.gen)(loose, server_toggles, server_settings)
elseif map_fname then
	map_loaded = common.map_load(map_fname, "auto")
else
	map_loaded = loadfile("pkg/base/gen_classic.lua")(loose, server_toggles, server_settings)
end
common.map_set(map_loaded)

mode_create_server()

print("pkg/base/main_server.lua: Loading mods...")
load_mod_list(getfenv(), mod_data.mods, {"load", "load_server"}, server_config, mod_data)
print("pkg/base/main_server.lua loaded.")


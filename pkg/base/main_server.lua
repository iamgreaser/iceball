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

dofile("pkg/base/preconf.lua")

print("pkg/base/main_server.lua starting")
print(...)

if common.version == nil then
	error("You must have at least version 0.0-1 to run this server!"
	.." iceballfornoobs-004 is FAR TOO OLD!"
	.." If you are using an old git version, PLEASE UPDATE!")
end

dofile("pkg/base/common.lua")
dofile("pkg/base/commands.lua")

client_list = {fdlist={}}
server_tick_accum = 0.

function slot_add(sockfd, tidx, wpn, name)
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
				_wpn = WPN_RIFLE
			end
			players[i] = new_player({
				name = name,
				--[[squad = squads[(i-1) % 2][
					(math.floor((i-1)/2) % 4)+1],]]
				squad = nil,
				team = tidx, -- 0 == blue, 1 == green
				weapon = _wpn,
				pid = i,
				sockfd = sockfd
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


function server.hook_file(sockfd, ftype, fname)
	print("hook_file:", sockfd, ftype, fname)
	
	if (ftype == "icemap" or ftype == "map") and (fname == "*MAP") then
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
	--[[net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF800000,
		"Connected: player on sockfd "..ss))]]
	print("Connected: player on sockfd "..ss)
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
	--[[net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF800000,
		"Disconnected: player on sockfd "..ss))]]
	print("Disconnected: player on sockfd "..ss)
	
	if plr then
		plr.intel_drop()
		net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF800000,
			"* Player "..plr.name.." disconnected"))
		net_broadcast(sockfd, common.net_pack("BB",
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
	local pkt, sockfd
	while true do
		pkt, sockfd = common.net_recv()
		if not pkt then break end
		
		local cli = client_list[sockfd]
		local plr = cli and players[cli.plrid]
		
		local cid
		cid, pkt = common.net_unpack("B", pkt)
		
		--print("in",sockfd,cid)
		
		local hdl = network.sys_tab_handlers[cid]
		if hdl then
			hdl.f(sockfd, cli, plr, sec_current, common.net_unpack(hdl.s, pkt))
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
		
		for i=1,#intent do
			intent[i].tick(moment, tickrate)
		end				
		server_tick_accum = server_tick_accum - tickrate
	end
	
	return 0.005
end

-- parse arguments

local loose, server_toggles, server_settings = parse_commandline_options({...})
local server_config_filename = server_settings['server'] or "svsave/pub/server.json"
server_config = common.json_load(server_config_filename)
-- TODO: Check that server_config ~= nil
if server_settings.svseed then
	math.randomseed(0+server_settings.svseed)
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
map_fname = loose[1]
--[[map_fname = map_fname or MAP_DEFAULT
map_loaded = common.map_load(map_fname, "auto")
]]
if map_fname then
	map_loaded = common.map_load(map_fname, "auto")
else
	map_loaded = loadfile("pkg/base/gen_classic.lua")(loose, server_toggles, server_settings)
end
common.map_set(map_loaded)

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

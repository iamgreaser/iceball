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

function server.hook_tick(sec_current, sec_delta)
	--print("tick",sec_current,sec_delta)
	
	local pkt, sockfd
	while true do
		pkt, sockfd = common.net_recv()
		if not pkt then break end
		
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
			if not common.net_send(true, common.net_pack("BIz", 0x0E, 0xFFFFFFFF, s)) then
				print("err!")
			end
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
			common.net_send(true, common.net_pack("BIz", 0x0E, c, s))
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

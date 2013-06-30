-- TDM: this is about as simple as it gets.
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

dofile("pkg/base/mode/obj_tent.lua")

function mode_reset()
	local i
	for i=1,players.max do
		if players[i] ~= nil then
			players[i].spawn()
			net_broadcast(nil, common.net_pack("BBfffBB",
				PKT_PLR_SPAWN, i,
				players[i].x, players[i].y, players[i].z,
				players[i].angy*128/math.pi, players[i].angx*256/math.pi))
		end
	end
	for i=1,#miscents do
		miscents[i].spawn()
		local x,y,z
		x,y,z = miscents[i].get_pos()
		miscents[i].player = nil
		net_broadcast(nil, common.net_pack("BHhhhB", PKT_ITEM_POS,
			i, x,y,z, miscents[i].get_flags() ))
		net_broadcast(nil, common.net_pack("BHB", PKT_ITEM_CARRIER, i, 0))
	end
	for i=0,teams.max do
		if teams[i] ~= nil then
			teams[i].score = 0
			net_broadcast(nil, common.net_pack("Bbh", PKT_TEAM_SCORE, i, teams[i].score))
		end
	end
end

function mode_create_server()
	TEAM_SCORE_LIMIT = TEAM_SCORE_LIMIT_TDM

	miscents = {}
	miscents[#miscents+1] = new_tent({team = 0, iid = #miscents+1})
	miscents[#miscents+1] = new_tent({team = 1, iid = #miscents+1})

	do
		local i
		for i=1,#miscents do
			miscents[i].spawn()
		end
	end
end

function mode_create_client()
	TEAM_SCORE_LIMIT = TEAM_SCORE_LIMIT_TDM

	miscents = {}
	miscents[#miscents+1] = new_tent({team = 0, iid = #miscents+1})
	miscents[#miscents+1] = new_tent({team = 1, iid = #miscents+1})
end

function mode_relay_items(plr, neth)
	for i=1,#miscents do
		local f,x,y,z
		x,y,z = miscents[i].get_pos()
		f = miscents[i].get_flags()
		net_send(neth, common.net_pack("BHhhhB",
			PKT_ITEM_POS, i, x, y, z, f))
		local plr = miscents[i].player
		if plr then
			net_send(neth, common.net_pack("BHB",
				PKT_ITEM_CARRIER, i, plr.pid))
		end
	end
end


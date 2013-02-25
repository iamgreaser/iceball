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


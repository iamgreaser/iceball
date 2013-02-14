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
network.parsetab = {}

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

function net_add_pkt_read(clread, svread)
	local fn_read
	
	if server then
		fn_read = svread
	else
		fn_read = clread
	end
	
	local idx = #(network.parsetab)+1
	network.parsetab[idx] = fn_read or function (pkt, cli, plr)
		print("unhandled packet", idx)
	end

	return idx
end

-- base mod packets
net_add_pkt_read(function (pkt)
	local pid, x, y, z
	pid, x, y, z, pkt = common.net_unpack("Bhhh", pkt)
	x = x/32.0
	y = y/32.0
	z = z/32.0

	local plr = players[pid]

	if plr then
		plr.set_pos_recv(x, y, z)
	end
end, function(pkt, cli, plr)
	if not plr then return end
	-- TODO: throttle this
	local pid, x2, y2, z2
	pid, x2, y2, z2, pkt = common.net_unpack("Bhhh", pkt)
	local x = x2/32.0
	local y = y2/32.0
	local z = z2/32.0
	
	plr.set_pos_recv(x, y, z)
	net_broadcast(sockfd, common.net_pack("BBhhh",
		0x03, cli.plrid, x2, y2, z2))
end)


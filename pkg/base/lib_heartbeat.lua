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

HB_VERSION = 2

heartbeat_sockfd = nil
heartbeat_t_nextmsg = nil
heartbeat_t_nextburst = nil
heartbeat_burstsleft = nil
heartbeat_cooloff = true

local function pad_nul(n, s)
	while s:len() < n do
		s = s .. "\0"
	end

	if s:len() > n then
		s = s:sub(1, n)
	end

	return s
end

function heartbeat_init()
	-- check if we have this actually enabled
	if not server_config.heartbeat_send then return end

	-- open the socket
	heartbeat_sockfd = common.udp_open()
end

function heartbeat_update(sec_current, sec_delta)
	-- we need to let the timer "cool off" as the first few values are just plain wrong.
	if heartbeat_cooloff then
		if sec_current < 60 and sec_current >= 2 then
			heartbeat_cooloff = nil
		end
		return
	end
	
	-- if we're using the wrong heartbeat and/or iceball version,
	-- heartbeat_sockfd will be nil,
	-- because we have given up.
	-- (it'll also be nil if we haven't enabled the heartbeat client.)
	if not heartbeat_sockfd then return end
	
	-- versions before 0.1.1-4 don't have server.port,
	-- so we need to rip the port from server.hook_connect.
	if not server.port then return end

	-- check if we received any messages
	while true do
		local msg, host, port = common.udp_recvfrom(heartbeat_sockfd)
		if msg == "" then
			break
		elseif msg == false then
			error("UDP socket used to connect to master servers broke horribly. What the hell?!")
		elseif msg:len() >= 4 and msg:sub(1,4) == "MSOK" then
			-- send handshake
			common.udp_sendto(heartbeat_sockfd, "HSHK" .. msg:sub(5), host, port)
		elseif msg == "BADF" then
			error("heartbeat server \""..host.."\" port "..port.." reports bad packet format - FIX ME OR REMOVE THIS SERVER")
		elseif msg:len() >= 4 and msg:sub(1,4) == "BADV" then
			error("heartbeat server \""..host.."\" port "..port.." reports bad version - UPGRADE OR REMOVE THIS SERVER")
		end
	end

	-- check if we need to send a new burst
	heartbeat_t_nextburst = heartbeat_t_nextburst or sec_current

	if sec_current >= heartbeat_t_nextburst then
		heartbeat_t_burstsleft = 5
		heartbeat_t_nextmsg = heartbeat_t_nextburst
		heartbeat_t_nextburst = heartbeat_t_nextburst + 40
	end

	-- check if we need to send a new message
	if heartbeat_t_burstsleft and heartbeat_t_nextmsg and sec_current >= heartbeat_t_nextmsg then
		-- get player count
		local players_max = players.max
		local players_current = 0
		local i

		for i=1,players_max do
			if players[i] then
				players_current = players_current + 1
			end
		end

		-- assemble message
		local msg = "1CEB" .. common.net_pack("HI", HB_VERSION, common.version.num)
		msg = msg .. common.net_pack("HHH", server.port, players_current, players_max)
		msg = msg .. pad_nul(30, server_config.name)
		msg = msg .. pad_nul(10, game_hb_mode)
		msg = msg .. pad_nul(30, map_name)

		--print("HEARTBEAT MESSAGE")

		-- send message
		local i
		local hbl = server_config.heartbeat
		for i=1,#hbl do
			local host, port = hbl[i][1], hbl[i][2]
			common.udp_sendto(heartbeat_sockfd, msg, host, port)
		end
		
		-- give time for next message if necessary
		heartbeat_t_burstsleft = heartbeat_t_burstsleft - 1 
		if heartbeat_t_burstsleft <= 0 then
			heartbeat_t_burstsleft = nil
			heartbeat_t_nextmsg = nil
		else
			heartbeat_t_nextmsg = heartbeat_t_nextmsg + 1
		end
	end
end


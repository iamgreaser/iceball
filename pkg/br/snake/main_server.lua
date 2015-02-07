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

dofile("pkg/br/snake/heartbeat.lua")

players_current = 0
players_max = 1

function server.hook_connect()
	players_current = players_current + 1
end

function server.hook_disconnect()
	players_current = players_current - 1
end

function server.hook_tick(sec_current, sec_delta)
	heartbeat_update(sec_current, sec_delta)
	return 0.005
end

print("Starting heartbeat server...")
heartbeat_init()
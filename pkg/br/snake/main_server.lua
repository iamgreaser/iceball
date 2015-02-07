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

MODE_HEARTBEAT = false

if MODE_HEARTBEAT then
	dofile("pkg/br/snake/heartbeat.lua")
end

players_current = 0
players_max = 1

function server.hook_connect()
	players_current = players_current + 1
end

function server.hook_disconnect()
	players_current = players_current - 1
end

function server.hook_tick(sec_current, sec_delta)
	if MODE_HEARTBEAT then
		heartbeat_update(sec_current, sec_delta)
	end
	return 0.005
end

if MODE_HEARTBEAT then
	print("Starting heartbeat server...")
	heartbeat_init()
end
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
	return 0.005
end

-- load map
map_fname = ...
map_fname = map_fname or MAP_DEFAULT
map_loaded = common.map_load(map_fname, "auto")
common.map_set(map_loaded)

print("pkg/base/main_server.lua loaded.")

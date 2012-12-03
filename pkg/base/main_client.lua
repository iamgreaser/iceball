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

print("pkg/base/main_client.lua starting")

-- please excuse this hack.

a1,a2,a3,a4,a5,a6,a7,a8,a9,a10 = ...

hboot = loadfile("pkg/base/client_start.lua")

function client.hook_tick()
	client.hook_tick = nil
	print(a1)
	hboot(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	return 0.005
end

--dofile("pkg/base/client_start.lua")
print("pkg/base/main_client.lua loaded.")


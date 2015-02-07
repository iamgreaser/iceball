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

--Gen city by LeCom

--Nooby code, feel free to fix things and optimize the code for lua

function gen_terrain(mx, my, mz)
	for x=0, mx-1 do
		for z=0, mz-1 do
			l={0, my-4, my-4, 0, CONCRETE_BLOCK.r, CONCRETE_BLOCK.g, CONCRETE_BLOCK.b, 1}
			common.map_pillar_set(x, z, l)
		end
	end
end
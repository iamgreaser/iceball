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

function argb_split_to_merged(r,g,b,a)
	a = a or 0xFF
	r = math.min(math.max(0,math.floor(r+0.5)),255)
	g = math.min(math.max(0,math.floor(g+0.5)),255)
	b = math.min(math.max(0,math.floor(b+0.5)),255)
	a = math.min(math.max(0,math.floor(a+0.5)),255)
	return 256*(256*(256*a+r)+g)+b
end

function abgr_split_to_merged(r,g,b,a)
	return argb_split_to_merged(b,g,r,a)
end

function argb_merged_to_split(c)
	-- yuck
	local b = c % (2 ^ 8)
	local g = math.floor(c / (2 ^ 8) % (2 ^ 8))
	local r = math.floor(c / (2 ^ 16) % (2 ^ 8))
	local a = math.floor(c / (2 ^ 24))
	if a < 0 then a = 0 end
	--print(string.format("%08X %d %d %d %d", c, r, g, b, a))
	return a, r, g, b
end

function recolor_component(r,g,b,mdata)
	for i=1,#mdata do
		if mdata[i].r == 0 and mdata[i].g == 0 and mdata[i].b == 0 then
			mdata[i].r = r
			mdata[i].g = g
			mdata[i].b = b
		end
	end
end

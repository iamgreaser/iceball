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

do
	local loose, user_toggles, user_settings
	loose, user_toggles, user_settings = ...
	local mx,my,mz,depth,r,g,b
	mx = user_settings["mx"] or 512
	my = user_settings["my"] or 96
	mz = user_settings["mz"] or 512
	depth = user_settings["depth"] or 20
	r = user_settings["r"] or 180
	b = user_settings["b"] or 180
	g = user_settings["g"] or 180
	
	local ret = common.map_new(mx, my, mz)
	common.map_set(ret)
	for x=0,mx-1 do
		for z=0,mz-1 do
			l = {0, my - depth, my - depth, 0, b, g, r, 1}
			common.map_pillar_set(x, z, l)
		end
	end
	print("gen finished")
	return ret, "flat("..mx..","..mz..","..my..")"
end


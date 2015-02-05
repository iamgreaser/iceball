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
DIR_CITYGEN_BUILDINGS = "pkg/base/citygen/buildings"

do
	local loose, user_toggles, user_settings
	loose, user_toggles, user_settings = ...
	local mx,my,mz,mode
	mx = user_settings["mx"] or 512
	my = user_settings["my"] or 96
	mz = user_settings["mz"] or 512
	mode = user_settings["mode"] or "default"
	
	--TODO: move terrain gen to tpl_genterrain.lua
	local ret = common.map_new(mx, my, mz)
	common.map_set(ret)
	local asphalt_r, asphalt_g, asphalt_b =  12, 12, 12 -- base ground colour
	for x=0,mx-1 do
		for z=0,mz-1 do
			ayylmao = (1+(math.random()/10)) --this is horrible don't do this
			l = {0, my - 4, my - 4, 0, asphalt_b*ayylmao, asphalt_g*ayylmao, asphalt_r*ayylmao, 1}
			common.map_pillar_set(x, z, l)
		end
	end
	
	for x=0,mx-1,16 do
		for z=0,mz-1 do
			if z % 4 ~= 0 then
				l = {0, my - 4, my - 4, 0, 233, 233, 233, 1}
				common.map_pillar_set(x, z, l)
			end
		end
	end
	
	--TODO: read the mode from JSON city settings
	--TODO: mode should point to tpl_gencity.lua to generate the city grid
	--TODO: grid should probably be 2d, array of lines, then buildings should adapt to terrain
	dofile(DIR_CITYGEN_BUILDINGS.."/basic_building.lua")
	
	-- building1 = new_building({})
	-- building1.build(mx/2, my-4-12, mz/2, 12, 12, 12)
	
	local building_number = math.floor((mx-24)/12)
	for i=1, mx-1, 12+16 do
		for y=1, mz-1, 12+16 do
			building = new_building({})
			building.build(i + 12, my-4-12, y+12, 12, 12, 12)
		end
	end
	
	
	--collectgarbage() --waiting for this to be implemented
	print("gen finished")
	return ret, "citygen("..mx..","..mz..","..my..")"
end


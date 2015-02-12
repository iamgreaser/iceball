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

dofile(DIR_CITYGEN_BUILDINGS.."tpl_building.lua")
local s_new_building = new_building
local function f_new_building(...)
	local this = s_new_building(...)

	this.type = "basic building" -- I'm so basic 
	
	-- this.x = settings.x
	-- this.y = settings.y
	-- this.z = settings.z
	
	
	local s_build = this.build_at
	function this.build_at(x, y, z, width, length, height)
			if height % 2 == 0 then height = height + 1 end
			local start_x, start_z = x, z
			local current_x, current_z = start_x, start_z
			local end_x, end_z = x+width, z+ length
			
			repeat
				chunk_header = 0
				starting_block = y
				ending_block = y
				air_start = y
				
				r,g,b = 120, 120, 120
				type_of_block = 1
				pillar_table = {chunk_header, starting_block, ending_block, air_start, b, g, r, type_of_block}
				-- common.map_pillar_set(current_x, current_z, pillar_table)
				for i=y,y+height do
					rand = math.floor(math.random()*5)%4
					if rand == 3 and i > y+height - 5 then
						map_block_set(current_x, i, current_z, 1, r-60, g-60, b-60)
					else
						if current_x % 2 == 0 and i < y+height - 5 and i % 3 ~= 0 and i > y then
							map_block_set(current_x, i, current_z, 1, 35, 156, 233)
						else
							map_block_set(current_x, i, current_z, 1, r, g, b)
						end
					end
				end
				current_x = current_x + 1
				if current_x>= end_x then
					current_x = start_x
					current_z = current_z + length - 1
				end
			until current_z  >= end_z
			
			current_x = start_x
			current_z = start_z
			repeat
				chunk_header = 0
				starting_block = y
				ending_block = y
				air_start = y
				
				r,g,b = 120, 120, 120
				type_of_block = 1
				pillar_table = {chunk_header, starting_block, ending_block, air_start, b, g, r, type_of_block}
				common.map_pillar_set(current_x, current_z, pillar_table)
				for i=y,y+height do
					rand = math.floor(math.random()*5)%4
					if rand == 3 and i > y+height - 5 then
						map_block_set(current_x, i, current_z, 1, r-60, g-60, b-60)
					else
						if current_z % 2 == 0 and i < y+height - 5 and i % 3 ~= 0 and i > y then
							map_block_set(current_x, i, current_z, 1, 35, 156, 233)
						else
							map_block_set(current_x, i, current_z, 1, r, g, b)
						end
					end
				end
				current_z = current_z + 1
				if current_z>= end_z then
					current_z = start_z
					current_x = current_x + width - 1
				end
			until current_x  >= end_x
			
			for i=y+1, y+height, 4 do
				for current_x = start_x+1, end_x-1-1 do
				
					for current_z = start_z+1, end_z-1-1 do
						map_block_set(current_x, i, current_z, 1, r*(rand/5), g*(rand/5), b*(rand/5))
					end
					
				end
			end
	end
	
	return this
end

new_building = f_new_building --three yays for iceball inheritance! \:D/ \:D/ \:D/
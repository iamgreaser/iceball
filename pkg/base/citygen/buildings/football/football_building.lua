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

-- can have multiple textures per 
local img_football_texture = common.img_load(DIR_CITYGEN_BUILDINGS.."football/football_texture.png","png") 
local img_football_texture_width, img_football_texture_height = common.img_get_dims(img_football_texture)

dofile(DIR_CITYGEN_BUILDINGS.."tpl_building.lua")
local s_new_building = new_building
function football_new_building(...)
	local this = s_new_building(...)

	this.type = "Football stadium"
	
	
	local s_build = this.build_at
	function this.build_at(x, y, z, width, length, height)
		--ignore height
		
		local a, r, g, b
		local outside_offset = 2
		local goal_width = math.floor(this.width / 16)
		for current_x=x,x+width-1 do
			for current_z=z,z+length-1 do
				subtly_changing_the_colour = (1+(math.random()/10))
				
				-- if ((current_x == x + outside_offset or current_x == x+width-1-outside_offset) and current_z >= outside_offset) or ((current_z == z+outside_offset or current_z == z+length-1-outside_offset) and current_x >= outside_offset) then
					-- r, g, b = 233, 233, 233
				-- else
				-- can possibly work with alpha too, but cba			
					a, r, g, b = argb_merged_to_split(common.img_pixel_get(img_football_texture, current_x % img_football_texture_width, current_z % img_football_texture_height)) 
				-- end
				-- common.map_pillar_set(current_x, current_z, {0, y, y, 0,
					-- math.min(r * subtly_changing_the_colour, 255), math.min(g * subtly_changing_the_colour, 255), math.min(b * subtly_changing_the_colour, 255),
				-- 1})
				map_pillar_add_block(current_x, y, current_z, math.min(r * subtly_changing_the_colour, 255), math.min(g * subtly_changing_the_colour, 255), math.min(b * subtly_changing_the_colour, 255))
				--map_pillar_set_column(current_x, y, current_z, 20, 120, 120, 120)
				-- map_block_set(current_x, y, current_z, 1, math.min(r * subtly_changing_the_colour, 255), math.min(g * subtly_changing_the_colour, 255), math.min(b * subtly_changing_the_colour, 255))
			end
		end
		
		
		
		map_cache_start()
		
		--mark lines
		map_draw_line( x+outside_offset,y,z+outside_offset,
								x+outside_offset,y,z+length-1-outside_offset,
								233, 233, 233)
		map_draw_line( x+outside_offset,y,z+outside_offset,
								x+width-1-outside_offset,y,z+outside_offset,
								233, 233, 233)
		map_draw_line( x+width-1-outside_offset,y,z+outside_offset,
								x+width-1-outside_offset,y,z+length-1-outside_offset,
								233, 233, 233)
		map_draw_line( x+outside_offset,y,z+length-1-outside_offset,
								x+width-1-outside_offset,y,z+length-1-outside_offset,
								233, 233, 233)
								
		map_draw_line( math.floor((x+width-1-outside_offset)/2),y,z+outside_offset,
								math.floor((x+width-1-outside_offset)/2),y,z+length-1-outside_offset,
								233, 233, 233)						
						
		--centre circle
		local pw=math.pow(goal_width, 2)
		for current_x=0, width do
			for current_z=0, length do
				if (math.pow((current_x+.5-(width)/2.0),2)+math.pow((current_z+.5-(length)/2.0), 2))<=pw then
					map_block_set(current_x+x-1, y, current_z+z-1, 1, 233, 233, 233)
				end
			end
		end
						
		--GOALS
		
		map_create_frame(0+goal_width,y-goal_width,z+length/2-goal_width,
									goal_width/4+goal_width,y,z+length/2+goal_width,
									233, 233, 233)
		map_create_frame(x+width-1-goal_width/4-goal_width,y-goal_width,z+length/2-goal_width,
									x+width-1-goal_width,y,z+length/2+goal_width, 
									233, 233, 233)
		--END GOALS
		
		--Stairs
		for current_x=goal_width, x+width-goal_width do
			map_draw_line(x+current_x, y, z+goal_width*2, x+current_x, y-(goal_width/2), z, 196, 196, 196)
			map_draw_line(x+current_x, y, z-goal_width*2+length, x+current_x, y-(goal_width/2), z+length, 196, 196, 196)
		end
		
		map_cache_end()
	end
	

	
	return this
end
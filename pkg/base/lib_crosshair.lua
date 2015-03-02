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

local DEFAULT_CROSSHAIR = {
	dot = true,
	lines = true,
	size = 4,
	thickness = 1,
	gap = 3,
	colour = {255, 0, 0},
	outline = false,
	outline_colour = {0, 0, 0},
	outline_thickness = 1,
	style = "classic",
}

local function crosshair_parse_config(config)
	config = config or {}
	local crosshair = {}
	for k, v in pairs(DEFAULT_CROSSHAIR) do
		if config[k] ~= nil then
			crosshair[k] = config[k]
		else
			crosshair[k] = v
		end
	end
	return crosshair
end

local function colour_array_to_int(colour)
	if #colour == 4 then
		return argb_split_to_merged(colour[1], colour[2], colour[3], colour[4])
	elseif #colour == 3 then
		return argb_split_to_merged(colour[1], colour[2], colour[3], 255)
	elseif #colour == 1 then
		return argb_split_to_merged(colour[1], colour[1], colour[1], 255)
	else
		error("Invalid colour array - should be of format: [L], [R, G, B], or [R, G, B, A]")
	end
end

-- TODO: Image lib? More C functions?
local function draw_outline(image, x, y, width, height, thickness, colour)
	common.img_rect_fill(image, x - thickness, y,             thickness, height,    colour)  -- Left
	common.img_rect_fill(image, x + width,     y,             thickness, height,    colour)  -- Right
	common.img_rect_fill(image, x,             y - thickness, width,     thickness, colour)  -- Top
	common.img_rect_fill(image, x,             y + height,    width,     thickness, colour)  -- Bottom
end

crosshair_styles = {}
function crosshair_styles.classic(config)
	-- Local variables make everything better
	local thickness = config.thickness
	local outline_thickness = config.outline_thickness
	local size = config.size
	local gap = config.gap
	
	-- We may want different w/h in future versions/styles, so everything has an x/y version
	local offset_x = 0
	local offset_y = 0
	local offset_centre_x = size + gap
	local offset_centre_y = size + gap
	local width = (offset_centre_x * 2) + thickness
	local height = (offset_centre_y * 2) + thickness
	local offset_n_x = width
	local offset_n_y = height
	if config.outline then
		width = width + (outline_thickness * 2)
		height = height + (outline_thickness * 2)
		offset_x = offset_x + outline_thickness
		offset_y = offset_y + outline_thickness
		offset_n_x = width - outline_thickness
		offset_n_y = height - outline_thickness
		offset_centre_x = offset_centre_x + outline_thickness
		offset_centre_y = offset_centre_y + outline_thickness
	end
	
	local colour = colour_array_to_int(config.colour)
	local outline_colour = colour_array_to_int(config.outline_colour)
	
	-- Crosshair
	
	local crosshair = common.img_new(width, height)
	-- Centre dot
	if config.dot then
		-- Dot
		common.img_rect_fill(crosshair, offset_centre_x, offset_centre_y, thickness, thickness, colour)
		
		-- Outline
		if config.outline then
			draw_outline(crosshair, offset_centre_x, offset_centre_y, thickness, thickness, outline_thickness, outline_colour)
		end
	end
	
	-- Horizontal/vertical lines
	if config.lines then
		local offset_right_x = offset_centre_x + thickness + gap
		local offset_bottom_y = offset_centre_y + thickness + gap
		
		-- Lines
		common.img_rect_fill(crosshair, offset_x,        offset_centre_y, size,      thickness, colour) -- Left
		common.img_rect_fill(crosshair, offset_right_x,  offset_centre_y, size,      thickness, colour) -- Right
		common.img_rect_fill(crosshair, offset_centre_x, offset_y,        thickness, size,      colour) -- Top
		common.img_rect_fill(crosshair, offset_centre_x, offset_bottom_y, thickness, size,      colour) -- Bottom
		
		-- Outline
		if config.outline then
			draw_outline(crosshair, offset_x,        offset_centre_y, size,      thickness, outline_thickness, outline_colour)  -- Left
			draw_outline(crosshair, offset_right_x,  offset_centre_y, size,      thickness, outline_thickness, outline_colour)  -- Right
			draw_outline(crosshair, offset_centre_x, offset_y,        thickness, size,      outline_thickness, outline_colour)  -- Top
			draw_outline(crosshair, offset_centre_x, offset_bottom_y, thickness, size,      outline_thickness, outline_colour)  -- Bottom
		end
	end
	
	-- Hit marker
	crosshair_hit = common.img_new(width, height)
	-- For now, we replace the entire crosshair with a separate hitmarker crosshair, so copy the crosshair into the hitmarker
	client.img_blit_to(crosshair_hit, crosshair, 0, 0)
	
	-- Draw outline first, so we can draw the fill over the intersection
	hm_line_length = size
	hm_offset_right = offset_n_x - hm_line_length
	hm_offset_right_far = offset_n_x - thickness
	hm_offset_bottom = offset_n_y - hm_line_length
	hm_offset_bottom_far = offset_n_y - thickness
	if config.outline then
		-- Top-left
		draw_outline(crosshair_hit, offset_x, offset_y, hm_line_length, thickness, outline_thickness, outline_colour)
		draw_outline(crosshair_hit, offset_x, offset_y, thickness, hm_line_length, outline_thickness, outline_colour)
		
		-- Top-right
		draw_outline(crosshair_hit, hm_offset_right, offset_y, hm_line_length, thickness, outline_thickness, outline_colour)
		draw_outline(crosshair_hit, hm_offset_right_far, offset_y, thickness, hm_line_length, outline_thickness, outline_colour)
		
		-- Bottom-left
		draw_outline(crosshair_hit, offset_x, hm_offset_bottom_far, hm_line_length, thickness, outline_thickness, outline_colour)
		draw_outline(crosshair_hit, offset_x, hm_offset_bottom, thickness, hm_line_length, outline_thickness, outline_colour)
		
		-- Bottom-right
		draw_outline(crosshair_hit, hm_offset_right, hm_offset_bottom_far, hm_line_length, thickness, outline_thickness, outline_colour)
		draw_outline(crosshair_hit, hm_offset_right_far, hm_offset_bottom, thickness, hm_line_length, outline_thickness, outline_colour)
	end
	
	-- Top-left
	common.img_rect_fill(crosshair_hit, offset_x, offset_y, hm_line_length, thickness, colour)
	common.img_rect_fill(crosshair_hit, offset_x, offset_y, thickness, hm_line_length, colour)
	
	-- Top-right
	common.img_rect_fill(crosshair_hit, hm_offset_right, offset_y, hm_line_length, thickness, colour)
	common.img_rect_fill(crosshair_hit, hm_offset_right_far, offset_y, thickness, hm_line_length, colour)
	
	-- Bottom-left
	common.img_rect_fill(crosshair_hit, offset_x, hm_offset_bottom_far, hm_line_length, thickness, colour)
	common.img_rect_fill(crosshair_hit, offset_x, hm_offset_bottom, thickness, hm_line_length, colour)
	
	-- Bottom-right
	common.img_rect_fill(crosshair_hit, hm_offset_right, hm_offset_bottom_far, hm_line_length, thickness, colour)
	common.img_rect_fill(crosshair_hit, hm_offset_right_far, hm_offset_bottom, thickness, hm_line_length, colour)
	
	return crosshair, crosshair_hit
end

function crosshair_generate_images(config)
	-- TODO: Perhaps draw outline and crosshair at full alpha on separate images, then merge them?
	-- This would stop overlapping areas from having different alpha than the rest
	local config = crosshair_parse_config(config)
	
	local gen = crosshair_styles[config.style]
	if gen == null then
		error("Invalid crosshair style selected")
	else
		return gen(config)
	end
end

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

if client then
-- load images
local img_font_numbers = common.img_load("pkg/base/gfx/font-numbers.tga")
local img_font_mini = common.img_load("pkg/base/gfx/font-mini.tga")
--[[
client.img_free(img_font_numbers)
img_font_numbers = nil -- PLEASE DO THIS, GUYS!
]]

local digit_map = {
	[" "] = 0,
	["0"] = 1,
	["1"] = 2,
	["2"] = 3,
	["3"] = 4,
	["4"] = 5,
	["5"] = 6,
	["6"] = 7,
	["7"] = 8,
	["8"] = 9,
	["9"] = 10,
	["-"] = 11,
}

-- TODO: find a better solution than this shit
-- y'know, just in case someone decides they're going to play this with an AZERTY
local shift_map = {
	["1"] = "!", ["2"] = "@", ["3"] = "#", ["4"] = "$", ["5"] = "%",
	["6"] = "^", ["7"] = "&", ["8"] = "*", ["9"] = "(", ["0"] = ")",
	["`"] = "~", ["-"] = "_", ["="] = "+",
	["["] = "{", ["]"] = "}", ["\\"] = "|",
	[";"] = ":", ["'"] = "\"",
	[","] = "<", ["."] = ">", ["/"] = "?",
}

local DIGIT_WIDTH = 32
local DIGIT_HEIGHT = 48
local MINI_WIDTH = 6
local MINI_HEIGHT = 8

function gui_index_mini(str, i) return (string.byte(str,i)-32) end
function gui_index_digit(str, i) return digit_map[string.sub(str,i,i)] end

-- create a new fixed-width font using the bitmap image, character width and height, and char indexing function
function gui_create_fixwidth_font(image, char_width, char_height, indexing_fn)
	local this = {image=image, width=char_width, height=char_height,
		indexing_fn=indexing_fn}
	
	-- print text with topleft at x, y, color c, string str
	function this.print(x, y, c, str)
		local i
		for i=1,#str do
			local idx = this.indexing_fn(str, i)
			client.img_blit(this.image, x, y, this.width, this.height, idx*this.width, 0, c)
			x = x + this.width
		end
	end
	
	-- print text with minimum-space wordwrapping, pixelwidth wp, topleft at x, y, color c, string str
	function this.print_wrap(wp, x, y, c, str)
		
		-- 1. find whitespace
		
		local i
		local j
		local toks = {}
		local cur_tok = 1
		local line_charwidth = math.floor(wp / this.width)
		
		for i=1,#str do
			local idx = string.byte(str, i)
			if idx == 13 or idx == 10 then -- CR/LF
				if toks[cur_tok] == nil then 
					toks[cur_tok] = {newlines=1}
				elseif toks[cur_tok].newlines == nil then 
					cur_tok = cur_tok + 1; toks[cur_tok] = {newlines=1}
				else
					toks[cur_tok].newlines = toks[cur_tok].newlines + 1
				end
			elseif idx == 32 then -- space
				if toks[cur_tok] == nil then 
					toks[cur_tok] = {spaces=1}
				elseif toks[cur_tok].spaces == nil then 
					cur_tok = cur_tok + 1; toks[cur_tok] = {spaces=1}
				else
					toks[cur_tok].spaces = toks[cur_tok].spaces + 1
				end
			else -- word
				if toks[cur_tok] == nil then 
					toks[cur_tok] = {word={idx}}
				elseif toks[cur_tok].word == nil or 
					#toks[cur_tok].word+1 > line_charwidth -- split if word is larger than a line
					then 
					cur_tok = cur_tok + 1; toks[cur_tok] = {word={idx}}
				else
					toks[cur_tok].word[#toks[cur_tok].word+1] = idx
				end
			end
		end
		
		-- 2. render as many words as possible per line
		
		local begin_x = x
		local end_x = x + wp
		
		local function endline()
			x = begin_x; y = y + this.height
		end
		
		for i=1,#toks do
			local tok = toks[i]
			if tok.word ~= nil then
				if x + #tok.word * this.width > end_x then endline() end
				for j=1,#tok.word do
					idx = tok.word[j]
					client.img_blit(this.image, x, y, this.width, this.height, 
						this.indexing_fn(idx)*this.width, 0, c)
					x = x + this.width
				end
			elseif tok.spaces ~= nil then
				x = x + this.width * tok.spaces
			elseif tok.newlines ~= nil then 
				for j=1,tok.newlines do endline() end 
			end
			if x > end_x then endline() end
		end	
		
	end
	
	return this
end

font_mini = gui_create_fixwidth_font(img_font_mini, MINI_WIDTH, MINI_HEIGHT, gui_index_mini)
font_digits = gui_create_fixwidth_font(img_font_numbers, MINI_WIDTH, MINI_HEIGHT, gui_index_digit)

function gui_get_char(key, modif)
	if key >= 32 and key <= 126 then
		local shifted = (bit_and(modif, KMOD_SHIFT) ~= 0)
		local crapslock = (bit_and(modif, KMOD_CAPS) ~= 0)
		if key >= SDLK_a and key <= SDLK_z then
			if shifted ~= crapslock then
				key = key - 32
			end
		end
		
		local k = string.char(key)
		k = (shifted and shift_map[k]) or k
		return k
	end
	
	-- TODO: check some other things
	
	return nil
end

function gui_string_edit(str, maxlen, key, modif)
	if key == SDLK_BACKSPACE then
		str = string.sub(str, 1, #str-1)
	else
		local k = gui_get_char(key, modif)
		
		if #str < maxlen and k then
			str = str .. k
		end
	end
	
	return str
end

function gui_create_scene(width, height)
	
	local scene = {}
	
	function scene.display_object(options)
		local this = widgets.widget(options)
		this.visible = true -- draws this node and children
		this.drawable = true -- calls the draw method
		this.use_img = false -- allocates a img buffer to this node
		this.img = nil
		this.dirty = true -- whether drawing needs to be updated
		function this.free()
			common.img_free(this.img) for k,v in pairs(this.children) do v.free() end
		end
		-- stub for actual drawing
		function this.draw_update() end
		-- draw this and the child, if possible.
		function this.draw()
			if this.visible then
				if this.drawable then
					if this.use_img then -- draw using img buffer
						this.detect_bufsize_change()
						if this.dirty then
							this.draw_update()
							this.dirty = false
						end
						client.img_blit(this.img, this.relx, this.rely)
					else -- draw using some other method?
						this.draw_update()
					end
				end
				for k,v in pairs(this.children) do v.draw() end
			end
		end
		function this.detect_bufsize_change()
			local cw, ch = math.ceil(this.width), math.ceil(this.height)
			if this.img == nil then
				this.img = common.img_new(cw, ch)
			else 
				pw, ph = common.img_get_dims(this.img)
				pw, ph = math.ceil(pw), math.ceil(ph)
				if not (pw == cw and ph == ch) then
					common.img_free(this.img)
					this.img = common.img_new(cw, ch)
				end
			end
		end
		return this
	end
	
	local root = scene.display_object{x=0, y=0, 
		width=width, height=height, align_x=0, align_y=0}
	
	function scene.draw() root.draw() end
	function scene.free() root.free() end
	
	function scene.rect_frame(options)
		
		local this = scene.display_object(options)
		
		this.frame_col = options.frame_col or 0xFF888888
		this.fill_col = options.fill_col or 0xFFAAAAAA
		
		this.use_img = true
		
		function this.draw_update()
			local w = math.ceil(this.width)
			local h = math.ceil(this.height)
			local img = this.img
			local frame_col = this.frame_col
			local fill_col = this.fill_col
			for ix = 0, w-1, 1 do
				common.img_pixel_set(img, ix, 0, frame_col)
				common.img_pixel_set(img, ix, h-1, frame_col)
			end
			for iy = 0, h-1, 1 do
				common.img_pixel_set(img, 0, iy, frame_col)
				common.img_pixel_set(img, w-1, iy, frame_col)
			end
			for ix = 1, w-2, 1 do
				for iy = 1, h-2, 1 do
					common.img_pixel_set(this.img, ix, iy, fill_col)
				end
			end
		end
		
		return this
		
	end
	
	-- TEST CODE
	--local frame = scene.rect_frame{width=320,height=320, x=width/2, y=height/2}
	--local frame2 = scene.rect_frame{width=32,height=32, x=0, y=0}
	--local frame3 = scene.rect_frame{width=32,height=32, x=64, y=96}
	--root.add_child(frame)
	--frame.add_child(frame2)
	--frame.add_child(frame3)
	
	return scene
	
end

function gui_free_scene(scene)
	for k in 1, #scene.buffers, 1 do
		common.img_free(buffers[k])
	end
end

end
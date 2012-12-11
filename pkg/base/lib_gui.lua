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
	[string.byte(" ")] = 0,
	[string.byte("0")] = 1,
	[string.byte("1")] = 2,
	[string.byte("2")] = 3,
	[string.byte("3")] = 4,
	[string.byte("4")] = 5,
	[string.byte("5")] = 6,
	[string.byte("6")] = 7,
	[string.byte("7")] = 8,
	[string.byte("8")] = 9,
	[string.byte("9")] = 10,
	[string.byte("-")] = 11,
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

function gui_index_mini(idx) return idx-32 end
function gui_index_digit(idx) return digit_map[idx] end

-- create a new fixed-width font using the bitmap image, character width and height, and char indexing function
function gui_create_fixwidth_font(image, char_width, char_height, indexing_fn)
	local this = {image=image, width=char_width, height=char_height,
		indexing_fn=indexing_fn}
	
	-- compute a non-wrapped characters + positions output suitable for usage in text selections as well as render
	function this.compute_unwrapped(x, y, c, str)
		
		result = {{}}
		local col_count = 1
		
		for col_count=1, #str do
			local char = string.byte(str, col_count)
			result[1][col_count] = {char, this.indexing_fn(char), x, y, c}
			x = x + this.width
		end
		
		return result
	end
	
	-- compute a wordwrapped characters + positions output suitable for usage in text selections as well as render
	function this.compute_wordwrap(wp, x, y, c, str)
	
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
		
		-- 2. render as many words as possible per line to a cacheable character buffer
		
		local begin_x = x
		local end_x = x + wp
		local result = {{}}
		local line_count = 1
		local col_count = 1
		
		local function endline()
			x = begin_x; y = y + this.height
			line_count = line_count + 1
			result[line_count] = {}
			col_count = 1
		end
		
		for i=1,#toks do
			local tok = toks[i]
			if tok.word ~= nil then
				if x + #tok.word * this.width > end_x then endline() end
				for j=1,#tok.word do
					result[line_count][col_count] = {tok.word[j], 
						this.indexing_fn(tok.word[j]), x, y, c}
					x = x + this.width
					col_count = col_count + 1
				end
			elseif tok.spaces ~= nil then
				local char = string.byte(' ')
				result[line_count][col_count] = {char, 
					this.indexing_fn(char), x, y, c}
				x = x + this.width * tok.spaces
				col_count = col_count + 1
			elseif tok.newlines ~= nil then 
				for j=1,tok.newlines do endline() end 
			end
			if x > end_x then endline() end
		end
		
		return result
	end
	
	-- get the AABB dimensions of text given precomputed text data
	function this.dimensions(data)
		
		local result = {l=data[1][1][3], 
						r=data[1][1][3] + this.width,
						t=data[1][1][4], 
						b=data[1][1][4] + this.height, 
						width=0, height=0}
		
		local row = 1
		local col = 1
		
		for row=1,#data do
			for col=1,#data[row] do
				result.l = math.min(result.l, data[row][col][3])
				result.r = math.max(result.r, data[row][col][3] + this.width)
				result.t = math.min(result.t, data[row][col][4])
				result.b = math.max(result.b, data[row][col][4] + this.height)
			end
		end
		
		result.width = result.r - result.l
		result.height = result.b - result.t
		
		return result
		
	end
	
	-- print text with topleft at x, y, color c, string str
	function this.print(x, y, c, str, buffer)
		for i=1,#str do
			local idx = this.indexing_fn(string.byte(str, i))
			if buffer == nil then
				client.img_blit(this.image, x, y, this.width, this.height, idx*this.width, 0, c)
			else
				client.img_blit_to(buffer, this.image, x, y, this.width, this.height, idx*this.width, 0, c)
			end
			x = x + this.width
		end
		local i
	end
	
	-- print a selection of precomputed text
	function this.print_precomputed(data, offx, offy, buffer)
		
		for y=1,#data do
			for x=1,#data[y] do
				local char = data[y][x][1]
				local idx = data[y][x][2]
				local px = data[y][x][3] + offx
				local py = data[y][x][4] + offy
				local c = data[y][x][5]
				if buffer == nil then
					client.img_blit(this.image, px, py, this.width, this.height, 
						idx*this.width, 0, c)
				else
					client.img_blit_to(buffer, this.image, px, py, this.width, this.height, 
						idx*this.width, 0, c)
				end
			end
		end
		
	end
	
	-- print text with minimum-space wordwrapping, pixelwidth wp, topleft at x, y, color c, string str
	function this.print_wrap(wp, x, y, c, str, buffer)
		this.print_precomputed(this.compute_wordwrap(wp, x, y, c, str), 0, 0, buffer)
	end
	
	return this
end

font_mini = gui_create_fixwidth_font(img_font_mini, MINI_WIDTH, MINI_HEIGHT, gui_index_mini)
font_digits = gui_create_fixwidth_font(img_font_numbers, DIGIT_WIDTH, DIGIT_HEIGHT, gui_index_digit)

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
	
	function scene.textfield(options)
		
		local this = scene.display_object(options)
		
		this.wordwrap = options.wordwrap or true
		this.color = options.color or 0xFF880088
		this.autosize = options.autosize or true
		this.font = options.font or font_mini
		this.use_img = true
		
		-- so, we are computing the text around offset 0, 0
		-- but when we go to display or collide with it, we're going to have to
		-- apply the widget offsets on top.
		
		-- TODO: cursor + text selection collision, data structure, rendering
		-- TODO: compute_unwrapped should allow new lines...
		
		function this.setter_keys.width(w)
			if this.autosize == false then
				rawset(this, 'width', w)
				this.dirty = true
			end
		end
		
		function this.setter_keys.height(h)
			if this.autosize == false then
				rawset(this, 'height', h)
				this.dirty = true
			end
		end
		
		function this._recalc_size()
			if this.wordwrap == true then
				this.text_cache = this.font.compute_wordwrap(this.width,
					0, 0, this.color, this._text)
			else
				this.text_cache = this.font.compute_unwrapped(0, 0, 
					this.color, this._text)
			end
			if this.autosize then
				local dim = this.font.dimensions(this.text_cache)
				rawset(this, 'width', dim.width)
				rawset(this, 'height', dim.height)
			end
			this.dirty = true
		end
		
		function this.getter_keys.text()
			return this._text
		end
		
		function this.setter_keys.text(str)
			this._text = str
			this._recalc_size()
		end
		
		function this.draw_update()
			this.font.print_precomputed(this.text_cache, 0, 0, this.img)
		end
		
		this.text = options.text or ""
		
		return this
		
	end
	
	-- TEST CODE
	--[=[local frame = scene.rect_frame{width=320,height=320, x=width/2, y=height/2}
	local frame2 = scene.rect_frame{width=32,height=32, x=0, y=0}
	local frame3 = scene.rect_frame{width=32,height=32, x=64, y=96}
	local text1 = scene.textfield{width=400,height=100, text="hello world"}
	root.add_child(frame)
	frame.add_child(text1)
	frame.add_child(frame2)
	frame.add_child(frame3)
	frame.child_to_top(text1)]=]
	
	return scene
	
end

function gui_free_scene(scene)
	for k in 1, #scene.buffers, 1 do
		common.img_free(buffers[k])
	end
end

end
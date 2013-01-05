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

dofile("pkg/base/lib_util.lua")

-- load images
local img_font_numbers = common.img_load("pkg/base/gfx/font-numbers.tga")
local img_font_mini = common.img_load("pkg/base/gfx/font-mini.tga")
local img_font_large = common.img_load("pkg/base/gfx/font-large.tga")
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
local LARGE_WIDTH = 24
local LARGE_HEIGHT = 32

function gui_index_mini(idx) return idx-32 end
function gui_index_digit(idx) return digit_map[idx] end

-- create a new fixed-width font using the bitmap image, character width and height, and char indexing function
function gui_create_fixwidth_font(image, char_width, char_height, indexing_fn, shadow)
	local this = {image=image, width=char_width, height=char_height,
		indexing_fn=indexing_fn, shadow=shadow}

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
	
	-- compute characters + positions from a colortable, where each line of table contains a string "msg" and a color "color"
	function this.compute_ctab(ctab, x, y)
		local result = {}
		
		for k, v in pairs(ctab) do
			-- compute and append a single line
			local line = this.compute_unwrapped(x, y, v.color, v.msg)
			local i
			for i=0, #line do
				table.insert(result, line[i])
			end
			-- then add the y of the last character + a newline		
			y = line[#line][#line[#line]][4] + this.height
		end
		return result
	end

	-- compute a wordwrapped characters + positions output suitable for usage in text selections as well as render
	function this.compute_wordwrap(wp, x, y, c, str)

	-- 1. find whitespace

		if wp < this.width then wp = this.width end -- force width to at least 1 char
		
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
		
		if #data<1 or #data[1]<1 then return {l=0,r=0,t=0,b=0,width=1,height=1} end
		
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

	function this._blit(buffer, x, y, idx, c)
		if this.shadow then
			if buffer == nil then
				client.img_blit(this.image, x+1, y+1, this.width, this.height, idx*this.width, 0, this.shadow)
			else
				client.img_blit_to(buffer, this.image, x+1, y+1, this.width, this.height, idx*this.width, 0, this.shadow)
			end
		end
		if buffer == nil then
			client.img_blit(this.image, x, y, this.width, this.height, idx*this.width, 0, c)
		else
			client.img_blit_to(buffer, this.image, x, y, this.width, this.height, idx*this.width, 0, c)
		end
	end

	-- calculate the shadow strength from the percieved luminance of the font; brighter color = darker shadow
	function this.calc_shadow(c)
		local a, r, g, b = argb_merged_to_split(c)
		local luminance = (0.2126 * r/256 + 0.7152 * g/256 + 0.0722 * b/256) -- Photometric/digital ITU-R
		this.shadow = argb_split_to_merged(0,0,0,(luminance)*256)
	end

	-- print text with topleft at x, y, color c, string str
	function this.print(x, y, c, str, buffer)
		this.calc_shadow(c)
		for i=1,#str do
			local idx = this.indexing_fn(string.byte(str, i))
			this._blit(buffer, x, y, idx, c)
			x = x + this.width
		end
		local i
	end

	-- print a selection of precomputed text
	function this.print_precomputed(data, offx, offy, buffer)
		
		local lastc = nil
		
		for y=1,#data do
			for x=1,#data[y] do
				local char = data[y][x][1]
				local idx = data[y][x][2]
				local px = data[y][x][3] + offx
				local py = data[y][x][4] + offy
				local c = data[y][x][5]
				if c ~= lastc then lastc = c; this.calc_shadow(c) end
				this._blit(buffer, px, py, idx, c)
			end
		end

	end

	-- print text with minimum-space wordwrapping, pixelwidth wp, topleft at x, y, color c, string str
	function this.print_wrap(wp, x, y, c, str, buffer)
		this.print_precomputed(this.compute_wordwrap(wp, x, y, c, str), 0, 0, buffer)
	end

	return this
end

font_mini = gui_create_fixwidth_font(img_font_mini, MINI_WIDTH, MINI_HEIGHT, gui_index_mini, true)
font_large = gui_create_fixwidth_font(img_font_large, LARGE_WIDTH, LARGE_HEIGHT, gui_index_mini, true)
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

--[[Create a new scene. 
Each scene contains its own displaylist, buffers, and listeners.]]
function gui_create_scene(width, height, shared_rate)

	local scene = {}

	function scene.display_object(options)
		local this = widgets.widget(options)
		
		this.visible = options.visible
		if this.visible == nil then this.visible = true end -- draws this node and children
		this.drawable = options.drawable
		if this.drawable == nil then this.drawable = true end -- calls the draw method
		options.dirty = true -- whether drawing needs to be updated
		this.use_img = options.use_img or false -- allocates a img buffer to this node
		this.img = options.img or nil
		this.listeners = options.listeners or {}
		this.alarms = options.alarms or {} -- ticked if seen. Will NOT dispose finished alarms for you!
		
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
				local pw, ph
				pw, ph = common.img_get_dims(this.img)
				pw, ph = math.ceil(pw), math.ceil(ph)
				if not (pw == cw and ph == ch) then
					common.img_free(this.img)
					this.img = common.img_new(cw, ch)
				end
			end
		end
		function this.add_listener(ge_type, callback)
			if ge_type == nil then error("nil ge_type") end
			if callback == nil then error("nil callback") end
			local l = this.listeners
			if not l[ge_type] then l[ge_type] = {} end
			table.insert(l[ge_type], callback)
		end
		-- given a dT and list of events [ge_type, data] call the listeners with matching type and progress any alarms
		function this.pump_listeners(dT, events)
			for k, v in pairs(this.alarms) do
				this.alarms[k].tick(dT)
			end
			for i=1, #events do
				local ev = events[i]
				local listen_list = this.listeners[ev[1]]
				if listen_list ~= nil then
					for j=1, #listen_list do
						listen_list[j](ev[2])
					end
				end
			end
			for k,v in pairs(this.children) do v.pump_listeners(dT, events) end
		end
		--Declare a self-cleaning alarm using the common.lua alarm syntax.
		function this.alarm(options)
			local a = alarm(options)
			table.insert(this.alarms, a)
			local on_trigger = a.on_trigger
			local function wrap()
				on_trigger()
				for i=1, #this.alarms do
					if this.alarms[i] == a then table.remove(this.alarms, i) break end
				end				
			end
			a.on_trigger = wrap
		end
		--[[Declare a self-cleaning alarm using the common.lua alarm syntax, plus a
			"name" option so that at most 1 of this alarm exists at one time.]]
		function this.static_alarm(options)
			local a = alarm(options)
			this.alarms[options.name] = a
			local on_trigger = a.on_trigger
			local function wrap()
				on_trigger()
				this.alarms[options.name] = nil
			end
			a.on_trigger = wrap
		end
		return this
	end
	
	local root = scene.display_object{x=0, y=0,
		width=width, height=height, align_x=0, align_y=0}
	scene.root = root
	
	function scene.hspacer(options)
		local this = widgets.hspacer(options)
		this.draw = function()
			for k,v in pairs(this.children) do v.draw() end
		end
		this.pump_listeners = function(dT, events)
			for k,v in pairs(this.children) do v.pump_listeners(dT, events) end
		end
		return this
	end
	
	function scene.vspacer(options)
		local this = widgets.vspacer(options)
		this.draw = function()
			for k,v in pairs(this.children) do v.draw() end
		end
		this.pump_listeners = function(dT, events)
			for k,v in pairs(this.children) do v.pump_listeners(dT, events) end
		end
		return this
	end
	
	function scene.pump_listeners(dT, events)
		-- copy incoming events
		local e = {}
		local i
		for i=1, #events do
			table.insert(e, events[i])
		end
		-- tick timers
		scene.shared_alarm_trigger = 0
		scene.shared_alarm.tick(dT)
		for i=1,scene.shared_alarm_trigger do
			table.insert(e, {GE_SHARED_ALARM, scene.shared_alarm.time})
		end
		table.insert(e, {GE_DELTA_TIME, dT})
		-- propogate
		root.pump_listeners(dT, e)
	end
	
	function scene.draw() root.draw() end
	function scene.free() root.free() end

	function scene.rect_frame(options)

		local this = scene.display_object(options)

		this.frame_col = options.frame_col or 0xFF888888
		this.fill_col = options.fill_col or 0xFFAAAAAA

		this.use_img = true
		this.dirty = true

		function this.draw_update()
			local w = math.ceil(this.width)
			local h = math.ceil(this.height)
			local img = this.img
			local frame_col = this.frame_col
			local fill_col = this.fill_col
			common.img_fill(img, fill_col)
			for ix = 0, w-1, 1 do
				common.img_pixel_set(img, ix, 0, frame_col)
				common.img_pixel_set(img, ix, h-1, frame_col)
			end
			for iy = 0, h-1, 1 do
				common.img_pixel_set(img, 0, iy, frame_col)
				common.img_pixel_set(img, w-1, iy, frame_col)
			end
		end

		return this

	end

	function scene.textfield(options)

		local this = scene.display_object(options)

		this.wordwrap = options.wordwrap
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
		
		local _text
		local _ctab
		local _color = options.color or 0xFF880088
		
		local function recalc_glyphs()
			if _ctab ~= nil then
				this.text_cache = this.font.compute_ctab(_ctab, 0, 0)
			else
				if this.wordwrap == true then
					this.text_cache = this.font.compute_wordwrap(this.width,
						0, 0, _color, _text)
				else
					this.text_cache = this.font.compute_unwrapped(0, 0,
						_color, _text)
				end
			end		
			this.dirty = true
		end
		
		local function recalc_size()
			recalc_glyphs()
			if this.autosize then
				local dim = this.font.dimensions(this.text_cache)
				rawset(this, 'width', dim.width)
				rawset(this, 'height', dim.height)
			end
		end

		function this.getter_keys.text()
			return _text
		end

		function this.setter_keys.text(str)
			_ctab = nil
			if _text == str then return end
			_text = str
			recalc_size()
		end
		
		function this.getter_keys.ctab()
			return _ctab
		end

		function this.setter_keys.ctab(ctab)
			_text = nil
			
			-- test sameness
			
			local same = true
			if _ctab == nil or #_ctab ~= #ctab then same = false
			else
				local i
				for i=1, #ctab do
					if _ctab[i] ~= ctab then same = false break end
				end
			end
			if same then return end
			
			-- copy and dirtify
			
			local tabcopy = {}
			for k, v in pairs(ctab) do
				table.insert(tabcopy, v)
			end
			_ctab = tabcopy
			recalc_size()
		end

		function this.draw_update()
			common.img_fill(this.img, 0x00000000)
			this.font.print_precomputed(this.text_cache, 0, 0, this.img)
		end
			
		function this.getter_keys.color(v)
			return _color
		end
		
		function this.setter_keys.color(v)
			_color = v
			recalc_glyphs()
		end

		this.text = options.text or ""
		if options.ctab ~= nil then this.ctab = options.ctab end

		return this

	end
	
	function scene.image(options)
		
		local this = scene.display_object(options)
		
		this._img = options.img
		this.use_img = false
		
		function this.getter_keys.width()
			error("can't set the width of an image")
		end
		function this.getter_keys.height()
			error("can't set the height of an image")
		end
		
		function this._recalc_size()
			local pw, ph 
			pw, ph = common.img_get_dims(this.img)
			rawset(this, 'width', pw)
			rawset(this, 'height', ph)
			this.dirty = true
		end
		function this.getter_keys.img()
			return this._img
		end
		function this.setter_keys.img(img)
			this._img = img
			this._recalc_size()
		end
		function this.draw_update()
			client.img_blit(this._img, this.l, this.t)
		end
		
		this._recalc_size()
		
		return this
	end

	function scene.bone(options)

		local this = scene.display_object(options)

		this.z = options.z or 1
		this.model = options.model or nil
		this.bone_idx = options.bone_idx or 0
		this.rot_x = options.rot_x or 0
		this.rot_y = options.rot_y or 0
		this.rot_y2 = options.rot_y2 or 0
		this.scale = options.scale or 1

		function this.getter_keys.width() return 0 end
		this.getter_keys.height = this.getter_keys.width

		function this.draw_update()
			if this.model ~= nil then
				-- remap pixel coordinates to (-1, 1) range
				local ratio = root.height/root.width
				local mx = -(this.relx/root.width*2-1)
				local my = (this.rely/root.height*2-1)*ratio
				client.model_render_bone_local(this.model,
					this.bone_idx,
					mx, my,
					this.z,
					this.rot_y, this.rot_x, this.rot_y2, this.scale)
			end
		end

		return this

	end
	
	--[[
		Each frame, before we start drawing, we traverse the DL tree in order to
		pass in events.
		
		Each displayobject has a "hash of lists" - one list for each event type.
		Callbacks are simply stored in the list.
	]]
	
	--[[
		The shared alarm records "whether it went off" this frame.
		Each count of the trigger injects a SHARED_ALARM event into this frame.
	]]
	
	function scene.on_shared_alarm(dT)
		scene.shared_alarm_trigger = scene.shared_alarm_trigger + 1
	end
	
	shared_rate = shared_rate or 1./60
	scene.shared_alarm = alarm{time=shared_rate, loop=true,
		on_trigger=scene.on_shared_alarm }

	-- TEST CODE
	--[[local frame = scene.rect_frame{width=320,height=320, x=width/2, y=height/2}
	local frame2 = scene.rect_frame{width=32,height=32, x=0, y=0}
	local frame3 = scene.rect_frame{width=32,height=32, x=64, y=96}
	local text1 = scene.textfield{width=400,height=100, text="hello world"}
	local bone = scene.bone{model=mdl_intel, rot_y = -0.3, rot_x = -0.4, rot_y2 = 0.2, scale = 0.5}
	root.add_child(frame)
	frame.add_child(text1)
	frame.add_child(frame2)
	frame.add_child(frame3)
	frame.child_to_top(text1)
	frame.add_child(bone)
	
	-- rotate using shared alarm(accumulates 60hz frames)
	
	local function bone_rotate(dT)
		bone.rot_y = bone.rot_y + 1./6
	end
	bone.add_listener(GE_SHARED_ALARM, bone_rotate)]]
	--[[
	
	-- rotate using dT(passes in the raw dT value and multiplies)
	
	local function bone_rotate_2(dT)
		bone.rot_y = bone.rot_y + dT
	end
	bone.add_listener(GE_DELTA_TIME, bone_rotate_2)]]

	return scene

end

function gui_free_scene(scene)
	for k in 1, #scene.buffers, 1 do
		common.img_free(buffers[k])
	end
end

end

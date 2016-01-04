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

if common.argb_split_to_merged then
	argb_split_to_merged = common.argb_split_to_merged
else
	function argb_split_to_merged(r,g,b,a)
		a = a or 0xFF
		r = math.min(math.max(0,math.floor(r+0.5)),255)
		g = math.min(math.max(0,math.floor(g+0.5)),255)
		b = math.min(math.max(0,math.floor(b+0.5)),255)
		a = math.min(math.max(0,math.floor(a+0.5)),255)
		return 256*(256*(256*a+r)+g)+b
	end
end
	
function abgr_split_to_merged(r,g,b,a)
	return argb_split_to_merged(b,g,r,a)
end

if common.argb_merged_to_split then
	argb_merged_to_split = common.argb_merged_to_split
else
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

function gen_icon(mspr)
	local this = {
		ofx = mspr[1],
		ofy = mspr[2],
	}

	do
		local i
		local lgx, lgy = mspr[1], mspr[2]

		for i=3,#mspr,2 do
			this.ofx = math.min(this.ofx, mspr[i+0])
			this.ofy = math.min(this.ofy, mspr[i+1])
			lgx = math.max(lgx, mspr[i+0])
			lgy = math.max(lgy, mspr[i+1])
		end

		this.w = lgx - this.ofx + 1
		this.h = lgy - this.ofy + 1
		this.img = common.img_new(this.w, this.h)

		--print(this.w, this.h, this.ofx, this.ofy)
		for i=1,#mspr,2 do
			common.img_pixel_set(this.img,
				mspr[i+0]-this.ofx,
				mspr[i+1]-this.ofy,
				0xFFFFFFFF)
		end
	end

	function this.blit(x, y, c, mx, my, x1, y1, x2, y2)
		local dx = x + this.ofx - x1
		local dy = y + this.ofy - y1
		local sx = 0
		local sy = 0
		local iw = this.w
		local ih = this.h

		if dx < 0 then
			local diff = 0 - dx
			dx = 0
			sx = sx + diff
			iw = iw - diff
		end

		if dy < 0 then
			local diff = 0 - dy
			dy = 0
			sy = sy + diff
			ih = ih - diff
		end

		if dx + iw >= x2-x1 then
			iw = (x2-x1) - dx
		end

		if dy + ih >= y2-y1 then
			ih = (y2-y1) - dy
		end

		if iw >= 1 and ih >= 1 then
			client.img_blit(this.img, dx+mx, dy+my, iw, ih, sx, sy, c)
		end
	end

	return this
end

function string.split(s, sep, plain)
	local start = 1
	local done = false
	local function pass(i, j, ...)
		if i then
			local seg = s:sub(start, i - 1)
			start = j + 1
			return seg, ...
		else
			done = true
			return s:sub(start)
		end
	end
	local result = {}
	while not done do
		if sep == '' then done = true result[#result+1]=s end
		result[#result+1]=pass(s:find(sep, start, plain))
	end
	return result
end

-- trim the character 'sep' from the left hand side of the string
function string.triml(s, sep)
	sep = string.byte(sep)
	if s == '' then return s end
	local pos = 1
	while string.byte(s,pos)==sep and #s<=pos do pos = pos + 1 end
	return string.sub(s, pos+1)
end

-- trim the character 'sep' from the right hand side of the string
function string.trimr(s, sep)
	sep = string.byte(sep)
	if s == '' then return s end
	local pos = #s
	while string.byte(s, pos)==sep and pos>=1 do pos = pos - 1 end
	return string.sub(s, 1, pos)
end

-- trim the character 'sep' from both sides of the string
function string.trim(s, sep)
	return string.triml(string.trimr(s, sep), sep)
end

function parse_commandline_options(options, nocheckdash, na, nb, nc)
	local loose = na or {} -- loose strings, filenames, etc.
	local user_toggles = nb or {} -- toggle options (key is name, value is position)
	local user_settings = nc or {} -- key-value pairs

	for k, v in pairs(options) do
		if nocheckdash then
			v = "-" .. v
		end
		local setting_pair = string.split(v, "=")
		local first = string.byte(v,1)
		if first==string.byte('-') then -- we are toggling an option or setting a value
			if #setting_pair == 2 then -- we are setting a key to a value
				user_settings[string.triml(setting_pair[1], '-')]=setting_pair[2]
				print(string.triml(setting_pair[1], '-'),"trimmed")
			else
				user_toggles[string.triml(v, '-')]=k
			end
		elseif first == string.byte('/') then -- optional extra arg on URI
			-- look for a ? thing
			local npair = string.split(v:sub(2), "?")
			if npair[1] ~= "" then
				user_settings[" "] = npair[1]
			end
			if npair[2] then
				-- TODO: URI-decode
				local nopts = string.split(npair[2], "&")
				parse_commandline_options(nopts, true, loose, user_toggles, user_settings)
			end
		else -- add to the loose values
			loose[#loose+1] = v
		end
	end
	return loose, user_toggles, user_settings
end

--[[Create an alarm object. When run, counts down to the specified value
based on the time delta passed in.

time: The time limit of the alarm. Ignored with values less than 1.
progress: the progress towards the time limit.
active: Whether alarm is running or not.
on_frame: Callback run every frame, passed in the dT of that frame.
on_trigger: Callback run when alarm reaches its limit, passed in the dT of that frame.
loop: Whether the alarm will continue after the first run.
preserve_accumulator: Whether looping transfers overflow dT from the previous run

]]
function alarm(options)
	
	this = {}
	
	this.time = options.time or 1
	this.progress = options.progress or 0
	if options.active ~= nil then this.active = options.active else this.active = true end
	this.loop = options.loop or false
	this.preserve_accumulator = options.preserve_accumulator
	if this.preserve_accumulator == nil then this.preserve_accumulator = true end
	this.on_frame = options.on_frame or nil
	this.on_trigger = options.on_trigger or nil

	function this.tick(dT)
		if this.active then
			this.progress = this.progress + dT
			if this.on_frame ~= nil then this.on_frame(dT) end
			while this.progress >= this.time and this.active do
				if this.on_trigger ~= nil then this.on_trigger(dT) end
				if this.loop and this.time > 0 then
					if this.preserve_accumulator then
						this.progress = this.progress - this.time
					else
						this.progress = 0
					end
				else
					this.active = false
				end
			end
		end
	end
	
	function this.restart()
		this.progress = 0
		this.active = true
	end
	
	function this.time_remaining()
		return this.time - this.progress
	end
	
	return this
end

-- Rescale an "aval" between "amin" and "amax" to values between "bmin" and "bmax".
function rescale_value(amin, amax, bmin, bmax, aval)
	local adist = amax - amin;
	local bdist = bmax - bmin;
	local ratio = bdist / adist;
	return bmin + (aval - amin) * ratio;
end

-- Creates a shallow copy of a table
function copy_table(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- GUI Events

-- DELTA_TIME: 
-- uses the delta time passed in when listeners are pumped.
-- callback passes in the dT value.
GE_DELTA_TIME = 1

-- SHARED_ALARM:
-- uses the scene's shared alarm, which is run at a fixed interval (default "1/60").
-- callback passes in the dT value of the shared alarm timer.
GE_SHARED_ALARM = 2

-- KEY:
-- User pressed or released a key.
-- callback passes in {key(int), state(bool), modif(int bitmask)}
GE_KEY = 3

-- TEXT:
-- User submitted text to the OS by pressing key(s).
-- callback passes in {text(string)}
GE_TEXT = 4

-- BUTTON:
-- User pressed or released a mapped button.
-- callback passes in {key(int), button{name(string), desc(string)}, state(bool), modif(int bitmask)}
GE_BUTTON = 5

-- MOUSE:
-- Mouse movement: x, y, dx, dy.
-- callback passes in {x(number), y(number), dx(number), dy(number)}
GE_MOUSE = 6

-- MOUSE_BUTTON:
-- Mouse button is pressed or released.
-- callback passes in {button(int), down(bool)}
GE_MOUSE_BUTTON = 7

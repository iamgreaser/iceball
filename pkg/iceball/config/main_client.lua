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

dofile("pkg/base/lib_sdlkey.lua")

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

gfx_font = common.img_load("pkg/iceball/halp/font-large.tga")
mus_rollb = common.mus_load_it("pkg/iceball/halp/gm-rollb-munch.it")
client.mus_vol_set(1.0)
client.mus_play(mus_rollb)

function unhex(s)
	local htab = {
		["0"] = 0x0,
		["1"] = 0x1,
		["2"] = 0x2,
		["3"] = 0x3,
		["4"] = 0x4,
		["5"] = 0x5,
		["6"] = 0x6,
		["7"] = 0x7,
		["8"] = 0x8,
		["9"] = 0x9,
		["A"] = 0xA,
		["B"] = 0xB,
		["C"] = 0xC,
		["D"] = 0xD,
		["E"] = 0xE,
		["F"] = 0xF,
		["a"] = 0xa,
		["b"] = 0xb,
		["c"] = 0xc,
		["d"] = 0xd,
		["e"] = 0xe,
		["f"] = 0xf,
	}

	local v = 0
	local i
	for i=1,#s do
		v = v*16 + htab[s:sub(i,i)]
	end
	return v
end

function tparse(s)
	local l = string.split(s, "\n")
	l[#l] = nil

	local i
	for i=1,#l do
		local v = l[i]
		local r = {data = v, color = 0xFFFFFFFF}
		if v:sub(1,1) == "$" then
			local c = v:sub(2,2)
			if c == "-" then
				r.data = "---------------------------------"
				r.color = 0xFF888888
			elseif c == "p" then
				r.data = "* "..v:sub(3,#v)
				r.color = 0xFFAAFFFF
			elseif c == "c" then
				r.data = v:sub(3+8,#v)
				r.color = unhex(v:sub(3,2+8))
			else
				error("invalid text command: "..v)
			end
		end
		l[i] = r
	end

	return {text = l, camy = 0}
end

function sprint(x, y, color, align, s, ...)
	if not s then return end
	local cx
	if align == 0 then
		cx = x
	elseif align == 1 then
		cx = x - #s * 4*6 / 2
	else
		cx = x - #s * 4*6
	end
	local i
	for i=1,#s do
		local c = s:sub(i,i):byte()
		client.img_blit(gfx_font, cx, y, 4*6, 4*8, 4*6*(c-32), 0, color)
		cx = cx + 4*6
	end
	sprint(x, y, color, align, ...)
end

blink_cursor = "_"
blink_time = 0

function client.hook_tick(sec_current, sec_delta)
	if blink_time < sec_current then
		if blink_cursor == "_" then
			blink_cursor = " "
		else
			blink_cursor = "_"
		end
		blink_time = sec_current + 0.25
	end
	return 0.033
end

profile = common.json_load("clsave/pub/user.json")
config = common.json_load("clsave/config.json")
selected = 1

fields = {
	{profile, "name", "Nickname", "string"},
	{nil, nil, "Resolution", "resolution"},
	{config["video"], "fullscreen", "Fullscreen", "boolean"},
	{profile, "sensitivity", "Mouse Sensitivity", "float", 0.5, 4.0, 0.25},
	{config["audio"], "mus_volume", "Music Volume", "float", 0, 1, 0.1},
	{config["audio"], "volume", "Sound Volume", "float", 0, 1, 0.1},
	{config["video"], "gl_vsync", "VSync", "boolean"},
	{config["video"], "antialiasinglevel", "Anti-Aliasing", "select",
		{0, 1, 2, 4, 8, 16}, {"Off", "1x", "2x", "4x", "8x", "16x"}},
	{config["video"], "smoothlighting", "Lighting", "boolean", {"Flat", "Smooth"}},
	{nil, nil, "Save and Exit", "action_save"},
	{nil, nil, "Exit without Saving", "action_exit"}
}

function get_value_default(field)
	if field[1] ~= nil and field[2] ~= nil then
		return field[1][field[2]]
	else
		return nil
	end
end

function set_value_default(field, value)
	if field[1] ~= nil and field[2] ~= nil then
		field[1][field[2]] = value
	end
end

function print_value_default(field, value)
	return value
end

function key_value_default()
end

function key_value_select(field, value, key, values)
	for i=1,#values do
		if values[i] == value then
			if key == SDLK_RIGHT or key == SDLK_RETURN then
				if i == #values then
					return values[1]
				else
					return values[i + 1]
				end
			elseif key == SDLK_LEFT then
				if i == 1 then
					return values[#values]
				else
					return values[i - 1]
				end
			else
				return values[i]
			end
		end
	end

	return values[1]
end

field_types = {}

-- TODO: Add actual resolution size check from SDL (Note: iceball requires at least 800x600, so check for that)
local resolution_list = {"800x600", "1024x600", "1024x768", "1280x720", "1280x800", "1280x960", "1280x1024",
			"1366x768", "1440x900", "1600x900", "1600x1200", "1680x1050", "1920x1080", "1920x1200", "2560x1440", "2560x1600",
			"3840x2160"}

field_types["resolution"] = {}
field_types["resolution"]["get"] =
	function(field, value)
		return config["video"]["width"] .. "x" .. config["video"]["height"]
	end
field_types["resolution"]["set"] =
	function(field, value)
		local res = string.split(value, "x")
		if #res == 2 and tonumber(res[1]) ~= nil and tonumber(res[2]) ~= nil then
			config["video"]["width"] = tonumber(res[1])
			config["video"]["height"] = tonumber(res[2])
		end
	end
field_types["resolution"]["key"] =
	function(field, value, key)
		return key_value_select(field, value, key, resolution_list)
	end

field_types["boolean"] = {}
field_types["boolean"]["print"] =
	function(field, value)
		local values = field[5]
		if values == nil then values = {"Off", "On"} end
		if value then return values[2] else return values[1] end
	end
field_types["boolean"]["key"] =
	function(field, value, key, uni)
		if key == SDLK_LEFT or key == SDLK_RIGHT or key == SDLK_RETURN then
			return not value
		else
			return value
		end
	end

field_types["float"] = {}
field_types["float"]["print"] =
	function(field, value)
		return math.floor((value * 100) + 0.5) .. "%"
	end
field_types["float"]["key"] =
	function(field, value, key, uni)
		local min = field[5]
		local max = field[6]
		local step = field[7]
		if min == nil then min = 0 end
		if max == nil then max = 1 end
		if step == nil then step = (max - min) * 10 end
		if key == SDLK_RIGHT then
			return math.min(max, value + step)
		elseif key == SDLK_LEFT then
			return math.max(min, value - step)
		end
	end

field_types["select"] = {}
field_types["select"]["print"] =
	function(field, value)
		local values = field[5]
		if field[6] ~= nil then
			local i = 1
			for j=1,#values do
				if values[j] == value then
					i = j
				end
			end
			return field[6][i]
		else
			return value
		end
	end
field_types["select"]["key"] =
	function(field, value, key, uni)
		return key_value_select(field, value, key, field[5])
	end

field_types["string"] = {}
field_types["string"]["key"] =
	function(field, value, key, uni)
		if key == SDLK_BACKSPACE then
			return string.sub(value, 1, -2)
		elseif key >= 32 and key <= 126 then
			return value .. string.char(uni)
		else
			return value
		end
	end

for k,v in pairs(field_types) do
	if v["get"] == nil then v["get"] = get_value_default end
	if v["set"] == nil then v["set"] = set_value_default end
	if v["print"] == nil then v["print"] = print_value_default end
	if v["key"] == nil then v["key"] = key_value_default end
end

function client.hook_key(key, state, modif, uni)
	local field = fields[selected]
	local field_type = field_types[field[4]]
	local value = nil
	if field_type ~= nil then
		value = field_type["get"](field)
	end

	if state then
		if key == SDLK_RETURN and field[4]:find("action") then
			if field[4] == "action_save" then
				common.json_write("clsave/pub/user.json", profile)
				common.json_write("clsave/config.json", config)
				client.create_launcher("pkg/iceball/launch")
				-- client.mk_sys_execv()
			elseif field[4] == "action_exit" then
				client.create_launcher("pkg/iceball/launch")
				-- client.mk_sys_execv()
			end
		elseif key == SDLK_UP then
			selected = selected - 1
			if selected <= 0 then
				selected = #fields
			end
		elseif key == SDLK_DOWN then
			selected = selected + 1
			if selected > #fields then
				selected = 1
			end
		elseif field_type ~= nil then
			value = field_type["key"](field, value, key, uni)
		end
	end

	if field_type ~= nil then
		field_type["set"](field, value)
	end

end

function client.hook_render()
	local sw, sh = client.screen_get_dims()
	local xl = 10
	local xr = sw - 30
	local oy = 10
	local oh = 50
	-- TODO: Add scrolling/centering, for now we almost fill the screen on 800x600
	for i=1,#fields do
		local y = oy + ((i - 1) * oh)
		local field = fields[i]
		local field_type = field_types[field[4]]
		local key = field[3]
		if selected == i then
			key = ">" .. key
			if field[4] == "string" then
				sprint(xr, y, 0xFFFFFFFF, 0, blink_cursor)
			end
		else
			key = " " .. key
		end
		sprint(xl, y, 0xFFFFFFFF, 0, key)
		if field_type ~= nil then
			local value = field_type["get"](field)
			if value ~= nil then
				sprint(xr, y, 0xFFFFFFFF, -1, field_type["print"](field, value))
			end
		end
	end
end

client.map_fog_set(0, 35, 75, 30.0)


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

function argb_split_to_merged(r,g,b,a)
	a = a or 0xFF
	r = math.min(math.max(0,math.floor(r+0.5)),255)
	g = math.min(math.max(0,math.floor(g+0.5)),255)
	b = math.min(math.max(0,math.floor(b+0.5)),255)
	a = math.min(math.max(0,math.floor(a+0.5)),255)
	return 256*(256*(256*a+r)+g)+b
end

function abgr_split_to_merged(r,g,b,a)
	return argb_split_to_merged(b,g,r,a)
end

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

function recolor_component(r,g,b,mdata)
	for i=1,#mdata do
		if mdata[i].r == 0 and mdata[i].g == 0 and mdata[i].b == 0 then
			mdata[i].r = r
			mdata[i].g = g
			mdata[i].b = b
		end
	end
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

function parse_commandline_options(options)
	local user_toggles = {} -- toggle options (key is name, value is position)
	local user_settings = {} -- key-value pairs
	local loose = {} -- loose strings, filenames, etc.

	for k, v in pairs(options) do
		local setting_pair = string.split(v, "=")
		local first = string.byte(v,1)
		if first==string.byte('-') then -- we are toggling an option or setting a value
			if #setting_pair == 2 then -- we are setting a key to a value
				user_settings[string.triml(setting_pair[1], '-')]=setting_pair[2]
				print(string.triml(setting_pair[1], '-'),"trimmed")
			else
				user_toggles[string.triml(v, '-')]=k
			end
		else -- add to the loose values
			loose[#loose+1] = v
		end
	end
	return loose, user_toggles, user_settings
end

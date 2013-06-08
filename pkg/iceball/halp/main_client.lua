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

dofile("pkg/iceball/halp/lib_sdlkey.lua")

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

cam_key_speed = 0

texts = loadfile("pkg/iceball/halp/texts.lua")()
curtext = "main"

function sprint(x, y, color, s, ...)
	if not s then return end
	local i
	for i=1,#s do
		local c = s:sub(i,i):byte()
		client.img_blit(gfx_font, x, y, 4*6, 4*8, 4*6*(c-32), 0, color)
		x = x + 4*6
	end
	sprint(x, y, color, ...)
end

function client.hook_tick(sec_current, sec_delta)
	--
	texts[curtext].camy = texts[curtext].camy + cam_key_speed*sec_delta
	return 0.005
end

function client.hook_key(key, state, modif, uni)
	if key == SDLK_ESCAPE and not state then
		client.hook_tick = nil
	elseif state then
		if key == SDLK_UP or key == SDLK_k then
			cam_key_speed = -500
		elseif key == SDLK_DOWN or key == SDLK_j then
			cam_key_speed = 500
		end
	else
		if key == SDLK_UP or key == SDLK_k then
			cam_key_speed = 0
		elseif key == SDLK_DOWN or key == SDLK_j then
			cam_key_speed = 0
		end
	end
end

function client.hook_render()
	local l = texts[curtext].text
	local y = 4 + -texts[curtext].camy
	local i
	for i=1,#l do
		local r = l[i]
		sprint(4, y, r.color, r.data); y = y + 32
	end
end

client.map_fog_set(0, 35, 75, 30.0)


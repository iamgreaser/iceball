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

dofile("pkg/iceball/config/lib_sdlkey.lua")

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
json = common.json_load("clsave/pub/user.json")
name = json["name"]


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

function client.hook_key(key, state, modif, uni)
	if state then
		if key == SDLK_BACKSPACE then
			name = string.sub(name, 1, -2)
		elseif key >= 32 and key <= 126 then
			name = name .. string.char(uni)
		end
	else
		if key == SDLK_ESCAPE then
			client.mk_sys_execv()
		elseif key == SDLK_RETURN then
			json["name"] = name
			common.json_write("clsave/pub/user.json", json)
			client.mk_sys_execv()
		end
	end
end

function client.hook_render()
	sprint(400, 250, 0xFFFFFFFF, 1, "ENTER NAME:")
	sprint(400, 300, 0xFFFFFFFF, 1, name .. blink_cursor)
	sprint(0, 550, 0xFFFFFFFF, 0, "  Cancel: Esc")
	sprint(800, 550, 0xFFFFFFFF, 2, "OK: Enter  ")
end

client.map_fog_set(0, 35, 75, 30.0)


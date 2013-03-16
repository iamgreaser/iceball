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

gfx_font = common.img_load("pkg/iceball/halp/font-large.tga")

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
	return 0.005
end

function client.hook_key(key, state, modif, uni)
	if key == SDLK_ESCAPE and not state then
		client.hook_tick = nil
	end
end

function client.hook_render()
	local y = 4
	sprint(4, y, 0xFFFFFFFF, "Welcome to Iceball."); y = y + 32
	sprint(4, y, 0xFFFFFFFF, "INSERT TUTORIAL HERE"); y = y + 32
end

client.map_fog_set(0, 35, 75, 30.0)


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

do
-- load images
local img_font_numbers = client.img_load("pkg/base/gfx/font-numbers.tga")
local img_font_mini = client.img_load("pkg/base/gfx/font-mini.tga")
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

function gui_print_mini(x, y, c, str)
	local i
	for i=1,#str do
		client.img_blit(img_font_mini, x, y, 6, 8, (string.byte(str,i)-32)*6, 0, c)
		x = x + 6
	end
end

function gui_print_digits(x, y, c, str)
	local i
	for i=1,#str do
		client.img_blit(img_font_numbers, x, y, 32, 48, digit_map[string.sub(str,i,i)]*32, 0, c)
		x = x + 32
	end
end
end

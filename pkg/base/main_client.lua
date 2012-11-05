--[[
    This file is part of BtS Lua Components.

    BtS Lua Components is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    BtS Lua Components is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with BtS Lua Components.  If not, see <http://www.gnu.org/licenses/>.
]]

print("pkg/base/main_client.lua starting")

function common.hook_tick(sec_current, sec_delta)
	-- 50 FPS MASTER RACE
	return 0.02
end

print("pkg/base/main_client.lua loaded.")

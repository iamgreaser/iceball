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

local thisid = ...

if client then
	if common.va_make then
		weapon_vas[thisid] = loadkv6(DIR_PKG_KV6.."/rifle.kv6", 1.0/96.0)
	else
		weapon_models[thisid] = skin_load("pmf", "rifle.pmf", DIR_PKG_PMF)
	end
end

weapon_names[thisid] = "Rifle"

return function (plr)
	local this = tpl_gun(plr, {
		dmg = {
			head = 100,
			body = 49,
			legs = 33,
		},
		block_damage = MODE_BLOCK_DAMAGE_RIFLE,
		
		ammo_clip = 10,
		ammo_reserve = 50,
		time_fire = 1/2,
		time_reload = 2.5,
		
		recoil_x = 0.0001,
		recoil_y = -0.05,

		model = weapon_models[thisid],
		va = weapon_vas[thisid],
		
		name = "Rifle",
	})
	
	return this
end


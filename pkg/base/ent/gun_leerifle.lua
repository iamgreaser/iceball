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
	weapon_models[thisid] = model_load({
		kv6 = {
			bdir = DIR_PKG_KV6,
			name = "leerifle.kv6",
			scale = 1.0/128.0,
		},
		pmf = {
			bdir = DIR_PKG_PMF,
			name = "leerifle.pmf",
		},
	}, {"kv6", "pmf"})
end

weapon_names[thisid] = "Lee-Enfield"

return function (plr)
	local this = tpl_gun(plr, {
		dmg = {
			head = 100,
			body = 100,
			legs = 100,
		},
		block_damage = 100,
		
		ammo_clip = 1,
		ammo_reserve = 25,
		time_fire = 1,
		time_reload = 2.5,
		
		recoil_x = 0.001,
		recoil_y = -0.2,
		sway = 0.0002,

		model = client and (weapon_models[thisid] {}),
		
		name = "Lee-Enfield Rifle",
	})
	
	this.reset()
	
	local s_prv_fire = this.prv_fire --unzoom if you shot, I don't remember why this.reset() is required
	function this.prv_fire(...)
		local ret = s_prv_fire(...)
		plr.zooming = false
		return ret
	end
	
	return this
end


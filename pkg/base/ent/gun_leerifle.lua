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

if client then
	weapon_models[WPN_LEERIFLE] = skin_load("pmf", "leerifle.pmf", DIR_PKG_PMF)
end

return function (plr)
	local this = tpl_gun(plr, {
		dmg = {
			head = 100,
			body = 100,
			legs = 100,
		},
		
		ammo_clip = 1,
		ammo_reserve = 25,
		time_fire = 1,
		time_reload = 2.5,
		
		recoil_x = 0.001,
		recoil_y = -0.2,

		model = weapon_models[WPN_LEERIFLE],
		
		name = "Lee-Enfield Rifle",
	})
	
	this.reset()
	
	local s_prv_fire = this.prv_fire
	function this.prv_fire(...)
		local ret = s_prv_fire(...)
		plr.zooming = false
		return ret
	end
	
	local s_tick = this.tick
	function this.tick(sec_current, sec_delta, ...)
		local ret = s_tick(sec_current, sec_delta, ...)
		if plr.tools[plr.tool+1] == this then
			local swayamt = 0.0002
			if plr.crouching then swayamt = swayamt * 0.5 end
			plr.angx = plr.angx + math.sin(sec_current * 2) * swayamt
			plr.angy = plr.angy + math.sin(sec_current * 2.5) * swayamt
		end
		return ret
	end
	
	return this
end


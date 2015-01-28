-- BR's SMG patch, ported to 0.1's modding system by GreaseMonkey.
--[[
    This file is derived from a part of Ice Lua Components.

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

MODE_BLOCK_DAMAGE_SMG = 20

if client then
	wav_smg_shot = wav_rifle_shot
	wav_smg_reload = wav_rifle_reload

	weapon_models[thisid] = skin_load("pmf", "smg.pmf", DIR_SMG)
end

weapon_names[thisid] = "SMG"

return function (plr)
	local this = tpl_gun(plr, {
		dmg = {
			head = 15,
			body = 10,
			legs = 10,
		},
		
		ammo_clip = 25,
		ammo_reserve = 500,
		time_fire = 60/500,
		time_reload = 1,
		
		recoil_x = 0.0001,
		recoil_y = -0.005,

		model = weapon_models[thisid],
		
		name = "SMG",
	})
	
	local s_click = this.click
	function this.click(button, state, ...)
		-- inhibit RMB
		if button == 1 then
			-- LMB
			return s_click(button, state, ...)
		end
	end
	
	return this
end


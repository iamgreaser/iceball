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

-- sprint mod by Dany0, enjoy!

MODE_PSPEED_SPRINT = 1.75



local super = new_player
function new_player(...)
	local this = super(...)

	this.ev_sprint = false
	
	local s_on_key = this.on_key
	local function f_on_key(key, state, modif)
		if key == SDLK_e then
			this.ev_sprint = state
			this.tools[this.tool+1].unfocus()
			if not state then
				this.crosshair.visible = true
			end
		end
	end
	
	function this.on_key(key, state, modif)
		local ret = s_on_key(key, state, modif)
		f_on_key(key, state, modif)
		return ret
	end
	
	local s_input_reset = this.input_reset
	local function f_input_reset(...)
		this.ev_sprint = false
	end
	
	function this.input_reset(...)
		local ret = s_input_reset(...)
		f_input_reset(...)
		return ret
	end
	
	local s_calc_motion_local = this.calc_motion_local
	
	function this.calc_motion_local(sec_current, sec_delta)
		local mvx, mvy, mvz, mvchange = s_calc_motion_local(sec_current, sec_delta)
		if this.ev_sprint then
			mvx = mvx * MODE_PSPEED_SPRINT
			mvz = mvz * MODE_PSPEED_SPRINT
			this.crosshair.visible = false
			rotpos = rotpos + sec_delta * 120.0 * MODE_PSPEED_SPRINT
		end
		return mvx, mvy, mvz, mvchange
	end
	
	return this
end
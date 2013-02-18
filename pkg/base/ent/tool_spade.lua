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

return function (plr)
	local this = {} this.this = this

	this.plr = plr
	this.mdl = mdl_spade
	this.mdl_bone = mdl_spade_bone
	this.gui_y = 0.3
	this.gui_scale = 0.2
	this.gui_pick_scale = 1.3
	this.angle = 0
	
	function this.prespawn()
		this.t_newspade1 = nil
		this.t_newspade2 = nil
	end

	function this.free()
		--
	end

	function this.textgen()
		return 0xFFC0C0C0, ""..this.plr.blocks
	end

	function this.draw(px,py,pz,angx,angy)
		client.model_render_bone_global(mdl_spade, mdl_spade_bone,
			px, py, pz,
			0.0, -angx+this.angle, angy, 1)
	end
end


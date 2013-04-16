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
	this.mdl = mdl_block
	this.mdl_bone = mdl_block_bone
	this.gui_y = 0.25
	this.gui_scale = 0.1
	this.gui_pick_scale = 2.0
	
	function this.prespawn()
		this.t_newspade1 = nil
		this.t_newspade2 = nil
	end

	function this.free()
		--
	end

	function this.textgen()
		local cr,cg,cb
		cr,cg,cb = this.plr.blk_color[1],this.plr.blk_color[2],this.plr.blk_color[3]
		local col = (cr*256+cg)*256+cb+0xFF000000
		return col, ""..this.plr.blocks
	end

	function this.render(px,py,pz,angx,angy)
		client.model_render_bone_global(this.mdl, this.mdl_bone,
			px, py, pz,
			0.0, -angx, angy, 1)
	end
end


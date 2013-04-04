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
	this.mdl = mdl_bomb
	this.mdl_bone = mdl_bomb_bone
	this.gui_y = 0.25
	this.gui_scale = 0.1
	this.gui_pick_scale = 2.0
	this.t_newbomb = nil
	this.ammo = 1
	
	function this.restock()
		this.ammo = 1
	end
	
	function this.throw_bomb(sec_current)
		local n = new_bomb({
			pid = plr.pid
		})
		bomb_add(n)
		net_send(nil, common.net_pack("B", PKT_BOMB_THROW))
	end
	
	function this.tick(sec_current, sec_delta)
		if this.t_newbomb then
			this.t_newbomb = this.t_newbomb - sec_delta
			if this.t_newbomb <= 0 then
				this.t_newbomb = nil
			end
		end
	end
	
	function this.click(button, state)
		if button == 1 then
			-- LMB
			if client and plr.alive and plr.tool == TOOL_EXPL and this.ammo > 0 and plr.mode ~= PLM_SPECTATE and state and not this.t_newbomb then
				this.ammo = this.ammo - 1
				this.t_newbomb = 20
				this.throw_bomb(sec_current)
			end
		end
	end
	
	function this.free()
		--
	end

	function this.textgen()
		return 0xCCCCCCCC, ""..this.ammo
	end
	
	function this.get_model()
		return mdl_bomb
	end
	
	function this.draw(px, py, pz, ya, xa, ya2)
		if this.ammo > 0 then
			client.model_render_bone_global(this.get_model(), 0,
				px, py, pz, ya, xa, ya2, 1)
		end
	end
	
	return this
end


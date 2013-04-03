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
	this.mdl = mdl_nade
	this.mdl_bone = mdl_nade_bone
	this.gui_y = 0.25
	this.gui_scale = 0.1
	this.gui_pick_scale = 2.0
	this.t_nadeboom = nil
	this.t_newnade = nil
	this.ammo = 2
	
	function this.restock()
		this.ammo = 4
	end
	
	function this.throw_nade(sec_current)
		local sya = math.sin(plr.angy)
		local cya = math.cos(plr.angy)
		local sxa = math.sin(plr.angx)
		local cxa = math.cos(plr.angx)
		local fwx,fwy,fwz
		fwx,fwy,fwz = sya*cxa, sxa, cya*cxa
		
		local n = new_nade({
			x = plr.x,
			y = plr.y,
			z = plr.z,
			vx = fwx*MODE_NADE_SPEED*MODE_NADE_STEP+plr.vx*MODE_NADE_STEP,
			vy = fwy*MODE_NADE_SPEED*MODE_NADE_STEP+plr.vy*MODE_NADE_STEP,
			vz = fwz*MODE_NADE_SPEED*MODE_NADE_STEP+plr.vz*MODE_NADE_STEP,
			fuse = math.max(0, this.t_nadeboom - sec_current)
		})
		nade_add(n)
		net_send(nil, common.net_pack("BhhhhhhH",
			PKT_NADE_THROW,
			math.floor(n.x*32+0.5),
			math.floor(n.y*32+0.5),
			math.floor(n.z*32+0.5),
			math.floor(n.vx*256+0.5),
			math.floor(n.vy*256+0.5),
			math.floor(n.vz*256+0.5),
			math.floor(n.fuse*100+0.5)))
	end
	
	function this.tick(sec_current, sec_delta)
		if this.t_newnade and sec_current >= this.t_newnade then
			this.t_newnade = nil
		end
		
		if this.t_nadeboom then
			if (not this.ev_lmb) or sec_current >= this.t_nadeboom then
				this.throw_nade(sec_current)
				this.t_newnade = sec_current + MODE_DELAY_NADE_THROW
				this.t_nadeboom = nil
				this.ev_lmb = false
			end
		end

		if client and plr.alive and (not this.t_switch) then
		if this.ev_lmb and plr.mode ~= PLM_SPECTATE then
		if plr.tool == TOOL_EXPL then
			if (not this.t_newnade) and this.ammo > 0 then
				if (not this.t_nadeboom) then
					if plr.mode == PLM_NORMAL then
						this.ammo = this.ammo - 1
					end
					this.t_nadeboom = sec_current + MODE_NADE_FUSE
				end
			end
		end end end
	end
	
	function this.click(button, state)
		if button == 1 then
			-- LMB
			this.ev_lmb = state
		end
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
	
	function this.get_model()
		return mdl_nade
	end
	
	function this.draw(px, py, pz, ya, xa, ya2)
		if this.ammo > 0 then
			client.model_render_bone_global(this.get_model(), 0,
				px, py, pz, ya, xa, ya2, 1)
		end
	end
	
	return this
end


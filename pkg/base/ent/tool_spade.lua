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

	function this.get_model()
		return this.mdl
	end
	
	function this.reset()
		this.t_newspade1 = nil
		this.t_newspade2 = nil
	end

	this.reset()

	function this.free()
		--
	end

	function this.restock()
		--
	end

	function this.click(button, state)
		if button == 1 then
			if state then
				this.t_newspade2 = nil
			end
		elseif button == 3 then
			if state then
				this.t_newspade2 = true
			else
				this.t_newspade2 = nil
			end
		end
	end

	function this.tick(sec_current, sec_delta)
		local xlen,ylen,zlen
		xlen,ylen,zlen = common.map_get_dims()

		if plr.tools[plr.tool+1] ~= this then return end

		local sya = math.sin(this.angy)
		local cya = math.cos(this.angy)
		local sxa = math.sin(this.angx)
		local cxa = math.cos(this.angx)
		local fwx,fwy,fwz
		fwx,fwy,fwz = sya*cxa, sxa, cya*cxa

		if this.t_newspade2 == true then
			this.t_newspade2 = sec_current + 1.0
		end

		if this.t_newspade1 and sec_current >= this.t_newspade1 then
			this.t_newspade1 = nil
		end
		
		if this.t_newspade2 and sec_current >= this.t_newspade2 and plr.blx2 then
			if plr.blx2 >= 0 and plr.blx2 < xlen and plr.blz2 >= 0 and plr.blz2 < zlen then
			if plr.bly2-1 <= ylen-3 then
				net_send(nil, common.net_pack("BHHH",
					PKT_BLK_RM3,
					plr.blx2, plr.bly2, plr.blz2))
			end
			end
			
			this.t_newspade2 = this.t_newspade2 + 1
			if this.t_newspade2 < sec_current then
				this.t_newspade2 = sec_current + 1
			end
		end

		if plr.ev_lmb then
			if (not this.t_newspade1) then
				-- see if there's anyone we can kill
				local d = plr.bld2 or 4 -- NOTE: cannot spade through walls anymore. Sorry guys :/
				local hurt_idx = nil
				local hurt_part = nil
				local hurt_part_idx = 0
				local hurt_dist = d*d
				local i,j
				
				for i=1,players.max do
					local p = players[i]
					if p and p ~= plr and p.alive and p.team ~= plr.team then
						local dx = p.x-plr.x
						local dy = p.y-plr.y+0.1
						local dz = p.z-plr.z
						
						for j=1,3 do
							local dot, dd = isect_line_sphere_delta(dx,dy,dz,fwx,fwy,fwz)
							if dot and dot < 0.55 and dd < hurt_dist then
								hurt_idx = i
								hurt_dist = dd
								hurt_part_idx = j
								hurt_part = ({"head","body","legs"})[j]
								
								break
							end
							dy = dy + 1.0
						end
					end
				end
				
				if hurt_idx then
					if server then
						players[hurt_idx].spade_damage(
							hurt_part, 1000, this)
					else
						net_send(nil, common.net_pack("BBB"
							, PKT_PLR_GUN_HIT, hurt_idx, hurt_part_idx))
					end
				elseif plr.blx2 then
					if plr.blx2 >= 0 and plr.blx2 < xlen and plr.blz2 >= 0 and plr.blz2 < zlen then
						if plr.bly2 <= ylen-3 then
							net_send(nil, common.net_pack("BHHHH", PKT_BLK_DAMAGE, plr.blx2, plr.bly2, plr.blz2, MODE_BLOCK_DAMAGE_SPADE))
							this.t_newspade1 = sec_current + MODE_DELAY_SPADE_HIT
						end
					end
				end
			elseif plr.ev_rmb and plr.blx2 and plr.alive then
				if (not this.t_newspade2) then
					this.t_newspade2 = sec_current
						+ MODE_DELAY_SPADE_DIG
					print("dig")
				end
			end
		end
	end

	function this.textgen()
		local col
		if this.plr.blocks == 0 then
			col = 0xFFFF3232
		else
			col = 0xFFC0C0C0
		end
		return col, ""..this.plr.blocks
	end

	function this.render(px,py,pz,ya,xa,ya2)
		ya = ya - math.pi/2
		if plr.blx1 and (plr.alive or plr.respawning) and map_block_get(plr.blx2, plr.bly2, plr.blz2) then
			client.model_render_bone_global(mdl_test, mdl_test_bone,
				plr.blx1+0.5, plr.bly1+0.5, plr.blz1+0.5,
				rotpos*0.01, rotpos*0.004, 0.0, 0.1+0.01*math.sin(rotpos*0.071))
			client.model_render_bone_global(mdl_test, mdl_test_bone,
				(plr.blx1*2+plr.blx2)/3+0.5,
				(plr.bly1*2+plr.bly2)/3+0.5,
				(plr.blz1*2+plr.blz2)/3+0.5,
				-rotpos*0.01, -rotpos*0.004, 0.0, 0.1+0.01*math.sin(-rotpos*0.071))
		end
		client.model_render_bone_global(this.mdl, this.mdl_bone,
			px, py, pz, ya, xa, ya2, 1)
	end
	
	return this
end


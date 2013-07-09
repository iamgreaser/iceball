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
	this.mdl = nil
	this.mdl_bone = 0
	this.gui_x = 0.15
	this.gui_y = 0.25
	this.gui_scale = 0.1
	this.gui_pick_scale = 2.0

	this.mspeed_mul = MODE_PSPEED_SPADE

	function this.get_model()
		return this.mdl or mdl_block
	end
	
	local function prv_recolor_block(r,g,b)
		if not client then return end
		if not this.mdl then
			this.mdl, this.mdl_bone = common.model_bone_new(common.model_new(1))
		end
		local mname,mdata
		mname,mdata = common.model_bone_get(mdl_block, mdl_block_bone)
		recolor_component(r,g,b,mdata)
		common.model_bone_set(this.mdl, this.mdl_bone, mname, mdata)
	end

	function this.recolor()
		local r,g,b
		r = plr.blk_color[1]
		g = plr.blk_color[2]
		b = plr.blk_color[3]
		prv_recolor_block(r,g,b)
	end

	prv_recolor_block(0,0,0)

	function this.reset()
		this.t_place = nil
		if plr.blk_color then
			prv_recolor_block(plr.blk_color[1], plr.blk_color[2], plr.blk_color[3])
		end
		plr.blocks = 25
	end

	this.reset()

	function this.free()
		if this.mdl then common.model_free(this.mdl) this.mdl = nil end
	end

	function this.restock()
		plr.blocks = 100
	end

	function this.focus()
		--
	end
	
	function this.unfocus()
		--
	end

	function this.need_restock()
		return false
	end

	function this.key(key, state, modif)
		if plr.alive and state then
			if key == BTSK_COLORLEFT then
				plr.blk_color_x = plr.blk_color_x - 1
				if plr.blk_color_x < 0 then
					plr.blk_color_x = 7
				end
				plr.blk_color = cpalette[plr.blk_color_x+plr.blk_color_y*8+1]
				this.recolor()
				net_send(nil, common.net_pack("BBBBB",
					PKT_PLR_BLK_COLOR, 0x00,
					plr.blk_color[1],plr.blk_color[2],plr.blk_color[3]))
			elseif key == BTSK_COLORRIGHT then
				plr.blk_color_x = plr.blk_color_x + 1
				if plr.blk_color_x > 7 then
					plr.blk_color_x = 0
				end
				plr.blk_color = cpalette[plr.blk_color_x+plr.blk_color_y*8+1]
				this.recolor()
				net_send(nil, common.net_pack("BBBBB",
					PKT_PLR_BLK_COLOR, 0x00,
					plr.blk_color[1],plr.blk_color[2],plr.blk_color[3]))
			elseif key == BTSK_COLORUP then
				plr.blk_color_y = plr.blk_color_y - 1
				if plr.blk_color_y < 0 then
					plr.blk_color_y = 7
				end
				plr.blk_color = cpalette[plr.blk_color_x+plr.blk_color_y*8+1]
				this.recolor()
				net_send(nil, common.net_pack("BBBBB",
					PKT_PLR_BLK_COLOR, 0x00,
					plr.blk_color[1],plr.blk_color[2],plr.blk_color[3]))
			elseif key == BTSK_COLORDOWN then
				plr.blk_color_y = plr.blk_color_y + 1
				if plr.blk_color_y > 7 then
					plr.blk_color_y = 0
				end
				plr.blk_color = cpalette[plr.blk_color_x+plr.blk_color_y*8+1]
				this.recolor()
				net_send(nil, common.net_pack("BBBBB",
					PKT_PLR_BLK_COLOR, 0x00,
					plr.blk_color[1],plr.blk_color[2],plr.blk_color[3]))
			end
		end
	end
	
	function this.click(button, state)
		--
	end

	function this.tick(sec_current, sec_delta)
		local xlen,ylen,zlen
		xlen,ylen,zlen = common.map_get_dims()

		if plr.blk_color_changed then
			plr.blk_color_changed = false
			this.recolor()
		end

		if plr.tools[plr.tool+1] ~= this then return end

		local sya = math.sin(plr.angy)
		local cya = math.cos(plr.angy)
		local sxa = math.sin(plr.angx)
		local cxa = math.cos(plr.angx)

		if this.t_place and sec_current >= this.t_place then
			this.t_place = nil
		end
		if plr.mode == PLM_SPECTATE then return end
		if plr.ev_lmb and plr.blx1 then
			if (not this.t_place) and plr.blocks > 0 then
				local dist, blx1, bly1, blz1
				local mblk = (plr.mode == PLM_BUILD and 40) or 5
				for dist=mblk,1,-1 do
					_, blx1, bly1, blz1 = trace_map_ray_dist(plr.x+0.4*sya,plr.y,plr.z+0.4*cya, sya*cxa,sxa,cya*cxa, dist, false)
					if blx1 >= 0 and blx1 < xlen and bly1 >= 0 and bly1 <= ylen - 3 and blz1 >= 0 and blz1 < zlen and map_is_buildable(blx1, bly1, blz1) then
						net_send(nil, common.net_pack("BHHHBBBB",
							PKT_BLK_ADD,
							blx1, bly1, blz1,
							plr.blk_color[3],
							plr.blk_color[2],
							plr.blk_color[1],
							1))
						if plr.mode == PLM_NORMAL then
							plr.blocks = plr.blocks - 1
						end
						this.t_place = sec_current + MODE_DELAY_BLOCK_BUILD
						plr.t_switch = this.t_place
						break
					end
				end
			end
		elseif plr.ev_rmb and plr.blx3 and plr.alive then
			local ct,cr,cg,cb
			ct,cr,cg,cb = map_block_pick(plr.blx3, plr.bly3, plr.blz3)
			if ct ~= nil then
				plr.blk_color = {cr,cg,cb}
				this.recolor()
				net_send(nil, common.net_pack("BBBBB",
					PKT_PLR_BLK_COLOR, 0x00,
					plr.blk_color[1],plr.blk_color[2],plr.blk_color[3]))
			end
			plr.ev_rmb = false
		end
	end

	function this.textgen()
		local cr,cg,cb
		cr,cg,cb = this.plr.blk_color[1],this.plr.blk_color[2],this.plr.blk_color[3]
		local col = (cr*256+cg)*256+cb+0xFF000000
		return col, ""..this.plr.blocks
	end

	function this.render(px,py,pz,ya,xa,ya2)
		local ays,ayc,axs,axc
		ays = math.sin(plr.angy)
		ayc = math.cos(plr.angy)
		axs = math.sin(plr.angx)
		axc = math.cos(plr.angx)

		if plr.blx1 and (plr.alive or plr.respawning) and plr.blocks >= 1 then
			local xlen,ylen,zlen = common.map_get_dims()
			local err = true
			local dist
			local blx1, bly1, blz1
			local mblk = (plr.mode == PLM_BUILD and 40) or 5
			for dist=mblk,1,-1 do
				_, blx1, bly1, blz1 = trace_map_ray_dist(plr.x+0.4*ays,plr.y,plr.z+0.4*ayc, ays*axc,axs,ayc*axc, dist, false)
				if blx1 >= 0 and blx1 < xlen and bly1 >= 0 and bly1 <= ylen - 3 and blz1 >= 0 and blz1 < zlen and (map_is_buildable(blx1, bly1, blz1) or MODE_BLOCK_PLACE_IN_AIR) then
					bname, mdl_data = client.model_bone_get(mdl_cube, mdl_cube_bone)
					
					mdl_data_backup = mdl_data
					
					for i=1,#mdl_data do
						if mdl_data[i].r > 4 then
							mdl_data[i].r = math.max(plr.blk_color[1], 5) --going all the way down to
							mdl_data[i].g = math.max(plr.blk_color[2], 5) --to 4 breaks it and you'd
							mdl_data[i].b = math.max(plr.blk_color[3], 5) --have to reload the model
						end
					end
					
					client.model_bone_set(mdl_cube, mdl_cube_bone, bname, mdl_data)
					
					client.model_render_bone_global(mdl_cube, mdl_cube_bone,
						blx1+0.5, bly1+0.5, blz1+0.5,
						0.0, 0.0, 0.0, 24.0) --no rotation, 24 roughly equals the cube size
					err = false
					break
				end
			end
			if err and not MODE_BLOCK_NO_RED_MARKER then
				for dist=mblk,0,-1 do
					_, blx1, bly1, blz1 = trace_map_ray_dist(plr.x+0.4*ays,plr.y,plr.z+0.4*ayc, ays*axc,axs,ayc*axc, dist, false)
					if blx1 >= 0 and blx1 < xlen and bly1 >= 0 and bly1 <= ylen - 3 and blz1 >= 0 and blz1 < zlen then
						client.model_render_bone_global(mdl_Xcube, mdl_Xcube_bone,
							blx1+0.5, bly1+0.5, blz1+0.5,
							0.0, 0.0, 0.0, 24.0)
						break
					end
				end
				--print(plr.blx1.." "..plr.bly1.." "..plr.blz1)
			end
		end
		if plr.blocks > 0 then
			client.model_render_bone_global(this.mdl, this.mdl_bone,
				px, py, pz, ya, xa, ya2, 1)
		end
	end

	return this
end


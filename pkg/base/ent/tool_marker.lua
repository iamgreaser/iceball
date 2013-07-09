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
	this.mdl = mdl_marker
	this.mdl_bone = mdl_marker_bone
	this.gui_x = 0.15
	this.gui_y = 0.32
	this.gui_scale = 0.1
	this.gui_pick_scale = 2.0

	this.mode = 0
	this.x1, this.y1, this.z1 = nil, nil, nil
	this.x2, this.y2, this.z2 = nil, nil, nil
	this.xp, this.yp, this.zp = nil, nil, nil

	this.mspeed_mul = MODE_PSPEED_SPADE

	function this.get_model()
		return this.mdl
	end

	function this.reset()
		--
	end

	this.reset()

	function this.free()
		--
	end

	function this.restock()
		--
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
		if state then
			if key == BTSK_COLORUP then
				this.mode = (this.mode - 1) % 4
			elseif key == BTSK_COLORDOWN then
				this.mode = (this.mode + 1) % 4
			end
		end
	end
	
	function this.click(button, state)
		if state then
			if plr.tools[plr.tool+1] ~= this then return end
			if button == 1 then
				if plr.blx1 then
					this.x1, this.y1, this.z1 = plr.blx1, plr.bly1, plr.blz1
					this.xp, this.yp, this.zp = plr.x, plr.y, plr.z
				end
			end
		else
			if plr.tools[plr.tool+1] ~= this then
				this.x1, this.y1, this.z1 = nil, nil, nil
				this.x2, this.y2, this.z2 = nil, nil, nil
				this.xp, this.yp, this.zp = nil, nil, nil
				return
			end
			if button == 1 then
				if this.x1 and this.x2 then
					common.net_send(nil, common.net_pack("BBHHHHHHBBBB", PKT_BUILD_BOX,
						this.mode, this.x1, this.y1, this.z1, this.x2, this.y2, this.z2,
						plr.blk_color[1], plr.blk_color[2], plr.blk_color[3]))
				end
				this.x1, this.y1, this.z1 = nil, nil, nil
				this.x2, this.y2, this.z2 = nil, nil, nil
				this.xp, this.yp, this.zp = nil, nil, nil
			end
		end
	end

	function this.tick(sec_current, sec_delta)
		local xlen,ylen,zlen
		xlen,ylen,zlen = common.map_get_dims()

		if plr.tools[plr.tool+1] ~= this then return end

		if this.x1 then
			--
			this.x2 = math.floor(this.x1 + plr.x - this.xp + 0.5)
			this.y2 = math.floor(this.y1 + plr.y - this.yp + 0.5)
			this.z2 = math.floor(this.z1 + plr.z - this.zp + 0.5)
		end
	end

	function this.textgen()
		local cr,cg,cb
		cr,cg,cb = 128,128,128
		local col = (cr*256+cg)*256+cb+0xFF000000
		return col, ""..this.mode
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
		if this.x1 and this.x2 then
			local x,y,z
			local x1,y1,z1,x2,y2,z2
			x1, y1, z1 = this.x1, this.y1, this.z1
			x2, y2, z2 = this.x2, this.y2, this.z2

			if x1 > x2 then x1, x2 = x2, x1 end
			if y1 > y2 then y1, y2 = y2, y1 end
			if z1 > z2 then z1, z2 = z2, z1 end
			local f = function (x,y,z)
				local xp = (x==x1 or x==x2)
				local yp = (y==y1 or y==y2)
				local zp = (z==z1 or z==z2)

				return (xp and (yp or zp)) or (yp and zp)
			end
			for x=x1,x2 do for z=z1,z2 do
				for y=y1,y2 do
					if f(x,y,z) then
						client.model_render_bone_global(mdl_Xcube, mdl_Xcube_bone,
							x+0.5, y+0.5, z+0.5,
							0, 0, 0, 24.0)
					end
				end
			end end
		end
		client.model_render_bone_global(this.mdl, this.mdl_bone,
			px, py, pz, ya, xa, ya2, 1)
	end

	return this
end



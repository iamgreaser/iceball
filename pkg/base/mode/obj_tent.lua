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
	mdl_tent = model_load({
		kv6 = {
			bdir = DIR_PKG_KV6,
			name = "flagpole.kv6",
			scale = 1.0/16.0,
		},
		pmf = {
			bdir = DIR_PKG_PMF,
			name = "tent.pmf",
		},
	}, {"kv6", "pmf"})
end

function new_tent(settings)
	local this = {} this.this = this

	this.type = "tent"

	this.team = settings.team or -1
	this.iid = settings.iid
	this.mspr = mspr_tent

	function this.tick(sec_current, sec_delta)
		local i

		if not server then return end

		if not this.spawned then return end

		-- set position
		local l = common.map_pillar_get(
			math.floor(this.x),
			math.floor(this.z))

		local ty = l[1+(1)]
		if this.y ~= ty and this.visible then
			this.y = ty
			net_broadcast(nil, common.net_pack("BHhhhB", PKT_ITEM_POS, this.iid,
				this.x, this.y, this.z,
				this.get_flags()))
		end

		-- see if anyone is restocking
		for i=1,players.max do
			local plr = players[i]

			if plr then
				local dx = plr.x-this.x
				local dy = (plr.y+2.4)-this.y
				local dz = plr.z-this.z
				local dd = dx*dx+dy*dy+dz*dz
				if dd > 2*2 then
					plr = nil
				end
			end

			if plr then
				this.player_in_range(plr, sec_current)
			end
		end
	end

	function this.player_in_range(plr, sec_current)
		local restock = false
		local i
		for i=1,#plr.tools do
			restock = restock or plr.tools[i].need_restock()
		end
		restock = restock or plr.health ~= 100
		restock = restock or plr.blocks ~= 100

		restock = restock and plr.alive
		restock = restock and plr.team == this.team

		if restock then
			plr.tent_restock()
		end
	end

	function this.should_glow()
		return (players[players.current].team == this.team
			and players[players.current].has_intel)
	end

	function this.render()
		if client.gfx_stencil_test and this.should_glow() then
			client.gfx_stencil_test(true)

			-- PASS 1: set to 1 for enlarged model
			client.gfx_depth_mask(false)
			client.gfx_stencil_func("0", 1, 255)
			client.gfx_stencil_op("===")
			this.mdl_tent.render_global(
				this.x, this.y+0.5, this.z,
				this.rotpos, 0, 0, 3*1.4)
			client.gfx_depth_mask(true)

			-- PASS 2: set to 0 for regular model
			client.gfx_stencil_func("1", 0, 255)
			client.gfx_stencil_op(";==")
			this.mdl_tent.render_global(
				this.x, this.y, this.z,
				this.rotpos, 0, 0, 3)

			-- PASS 3: draw red for stencil == 1; clear stencil
			client.gfx_stencil_func("==", 1, 255)
			client.gfx_stencil_op("000")
			local iw, ih = common.img_get_dims(img_fsrect)
			client.img_blit(img_fsrect, 0, 0, iw, ih, 0, 0, 0x7FFFFFFF)

			client.gfx_stencil_test(false)
		else
			this.mdl_tent.render_global(
				this.x, this.y, this.z,
				0, 0, 0, 3)
		end
	end

	function this.prespawn()
		this.alive = false
		this.spawned = false
		this.visible = false
	end

	local function prv_spawn_cont1()
		this.alive = true
		this.spawned = true
		this.visible = true
	end

	function this.spawn()
		local xlen,ylen,zlen
		xlen,ylen,zlen = common.map_get_dims()

		while true do
			this.x = math.floor(math.random()*xlen/4.0)+0.5
			this.z = math.floor((math.random()*0.5+0.25)*zlen)+0.5
			if this.team == 1 then this.x = xlen - this.x end
			this.y = (common.map_pillar_get(this.x, this.z))[1+1]
			if this.y < ylen-1 then break end
		end

		prv_spawn_cont1()
	end

	function this.spawn_at(x,y,z)
		this.x = x
		this.y = y
		this.z = z

		prv_spawn_cont1()
	end

	function this.get_pos()
		return this.x, this.y, this.z
	end

	function this.set_pos_recv(x,y,z)
		this.x = x
		this.y = y
		this.z = z
	end

	function this.get_flags()
		local v = 0
		if this.visible then v = v + 0x01 end
		return v
	end

	function this.set_flags_recv(v)
		this.visible = (bit_and(v, 0x01) ~= 0)
	end

	local _
	local l = (this.team and teams[this.team].color_mdl) or {170, 170, 170}
	this.color = l
	this.color_icon = (this.team and teams[this.team].color_chat) or {255,255,255}
	if client then
		this.mdl_tent = mdl_tent({filt=function (r,g,b)
			if r == 0 and g == 0 and b == 0 then
				return this.color[1], this.color[2], this.color[3]
			else
				return r,g,b
			end
		end})
	end

	this.prespawn()

	return this
end


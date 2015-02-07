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
	if common.va_make then
		function va_tent(filt)
			return loadkv6(DIR_PKG_KV6.."/flagpole.kv6", 1.0/16.0, filt)
		end
	else
		mdl_tent, mdl_tent_bone = skin_load("pmf", "tent.pmf", DIR_PKG_PMF), 0
	end
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
	
	function this.render()
		if this.va_tent then
			client.va_render_global(this.va_tent,
				this.x, this.y, this.z,
				0, 0, 0, 3)
		else
			client.model_render_bone_global(this.mdl_tent, 0,
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
	local mbone,mname,mdata
	if client then
		if va_tent then
			this.va_tent = va_tent(function (ll)
				print("FILTER", #ll)
				local i
				for i=1,#ll do
					local l = ll[i]
					if l[4] == 0 and l[5] == 0 and l[6] == 0 then
						l[4] = this.color[1]/255.0
						l[5] = this.color[2]/255.0
						l[6] = this.color[3]/255.0
					end
				end
				print("DONE FILTER")
			end)
		else
			this.mdl_tent = client.model_new(1)
			this.mdl_tent, mbone = client.model_bone_new(this.mdl_tent,1)
			mname,mdata = common.model_bone_get(mdl_tent, 0)
			recolor_component(l[1],l[2],l[3],mdata)
			common.model_bone_set(this.mdl_tent, 0, mname, mdata)
		end
	end
	
	this.prespawn()
	
	return this
end


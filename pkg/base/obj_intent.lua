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

function new_intel(settings)
	local this = {} this.this = this
	
	this.team = settings.team or -1
	
	function this.tick(sec_current, sec_delta)
		local i
		
		for i=1,32 do
			local plr = players[i]
			
			if plr then
				local dx = plr.x-this.x
				local dy = plr.y-this.y
				local dz = plr.z-this.z
				local dd = dx*dx+dy*dy+dz*dz
				if dd > 2*2 then
					plr = nil
				end
			end
			
			if plr then
				-- TODO: intel capture
			end
		end
	end
	
	function this.render()
		client.model_render_bone_global(this.mdl_tent, mdl_tent_bone,
			this.x, this.y, this.z,
			0.0, this.angx, this.angy-math.pi, 1)
	end
	
	function this.spawn()
		local xlen,ylen,zlen
		xlen,ylen,zlen = common.map_get_dims()
		
		while true do
			this.x = math.floor(math.random()*xlen/4.0)+0.5
			this.z = math.floor(math.random()*zlen)+0.5
			if this.team == 1 then this.x = xlen - this.x end
			this.y = (common.map_pillar_get(this.x, this.z))[1+1]
			if this.y < 63 then break end
		end
		
		this.alive = true
		this.spawned = true
	end
	
	local _
	local l = teams[this.team].color_mdl
	local mbone,mname,mdata
	this.mdl_intel = client.model_new(1)
	this.mdl_intel, mbone = client.model_bone_new(this.mdl_intel,1)
	mname,mdata = common.model_bone_get(mdl_intel, 0)
	recolor_component(l[1],l[2],l[3],mdata)
	common.model_bone_set(this.mdl_intel, 0, mname, mdata)
	
	this.spawn()
	
	return this
end

function new_tent(settings)
	local this = {} this.this = this
	
	this.team = settings.team or -1
	
	function this.tick(sec_current, sec_delta)
		local i
		
		for i=1,32 do
			local plr = players[i]
			
			if plr then
				local dx = plr.x-this.x
				local dy = plr.y-this.y
				local dz = plr.z-this.z
				local dd = dx*dx+dy*dy+dz*dz
				if dd > 1.5*1.5 then
					plr = nil
				end
			end
			
			if plr then
				local restock = false
				if plr.wpn then
					restock = restock or
						plr.wpn.ammo_reserve ~= plr.wpn.cfg.ammo_reserve
				end
				restock = restock or plr.health ~= 100
				restock = restock or plr.blocks ~= 100
				
				if restock then
					plr.health = 100
					plr.blocks = 100
					if plr.wpn then
						plr.wpn.ammo_clip = plr.wpn.cfg.ammo_clip
						plr.wpn.ammo_reserve = plr.wpn.cfg.ammo_reserve
					end
				end
			end
		end
	end
	
	function this.spawn()
		local xlen,ylen,zlen
		xlen,ylen,zlen = common.map_get_dims()
		
		while true do
			this.x = math.floor(math.random()*xlen/4.0)+0.5
			this.z = math.floor(math.random()*zlen)+0.5
			if this.team == 1 then this.x = xlen - this.x end
			this.y = (common.map_pillar_get(this.x, this.z))[1+1]
			if this.y < 63 then break end
		end
		
		this.alive = true
		this.spawned = true
	end
	
	this.spawn()
	
	local _
	local l = teams[this.team].color_mdl
	local mbone,mname,mdata
	this.mdl_tent = client.model_new(1)
	this.mdl_tent, mbone = client.model_bone_new(this.mdl_tent,1)
	mname,mdata = common.model_bone_get(mdl_tent, 0)
	recolor_component(l[1],l[2],l[3],mdata)
	common.model_bone_set(this.mdl_tent, 0, mname, mdata)
	
	return this
end


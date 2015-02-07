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
	mdl_intel, mdl_intel_bone = skin_load("pmf", "intel.pmf", DIR_PKG_PMF), 0
end

function new_intel(settings)
	local this = {} this.this = this

	this.type = "intel"
	
	this.team = settings.team
	this.iid = settings.iid
	this.mspr = mspr_intel
	this.player = nil
	
	this.rotpos = 0
	
	function this.get_name()
		if this.team then
			return teams[this.team].name .. " intel"
		else
			return "intel"
		end
	end
	
	function this.tick(sec_current, sec_delta)
		local i
		
		this.rotpos = sec_current*2
		
		if not this.spawned then return end
		
		if this.player then
			-- anything to do here?
		else
			
			if not server then return end
			
			-- set position
			local l = common.map_pillar_get(
				math.floor(this.x),
				math.floor(this.z))
			
			local ty = l[1+(1)]
			if this.y ~= ty and this.visible then
				--print("grav", this.y, ty)
				this.y = ty
				net_broadcast(nil, common.net_pack("BHhhhB", PKT_ITEM_POS, this.iid,
					this.x, this.y, this.z,
					this.get_flags()))
			end
			
			-- see if anyone has picked us up
			local mplr = nil
			local mdd = 2*2
			for i=1,players.max do
				local plr = players[i]
				
				if plr and plr.alive then
					local dx = plr.x-this.x
					local dy = (plr.y+2.8)-this.y
					local dz = plr.z-this.z
					local dd = dx*dx+dy*dy+dz*dz
					if dd < mdd then
						mplr = plr
					end
				end
			end
			
			if mplr then
				if mplr.intel_pickup(this) then
					this.player = mplr
					this.visible = false
				end
			end
		end
	end
	
	function this.render()
		if this.va_intel then
			client.va_render_global(this.va_intel,
				this.x, this.y-0.9, this.z,
				this.rotpos, 0, 0, 3)
		else
			client.model_render_bone_global(this.mdl_intel, 0,
				this.x, this.y-0.9, this.z,
				this.rotpos, 0, 0, 3)
		end
	end
	
	function this.render_backpack()
		local rpx = this.player.x
		local rpy = this.player.y+0.5+this.player.jerkoffs
		local rpz = this.player.z
		
		local sya = math.sin(this.player.angy)
		local cya = math.cos(this.player.angy)
		
		rpx = rpx - sya*0.4
		rpz = rpz - cya*0.4
		
		if this.va_intel then
			client.va_render_global(this.va_intel,
				rpx, rpy, rpz,
				math.pi/2, math.pi/2, this.player.angy-math.pi/2, 1)
		else
			client.model_render_bone_global(this.mdl_intel, 0,
				rpx, rpy, rpz,
				math.pi/2, math.pi/2, this.player.angy-math.pi/2, 1)
		end
	end
	
	function this.intel_drop()
		if not this.player then return end

		this.visible = true
		this.x = math.floor(this.player.x+0.5)+0.5
		this.y = math.floor(this.player.y+0.5)
		this.z = math.floor(this.player.z+0.5)+0.5
		this.player = nil
		if server then
			local x,y,z,f
			x,y,z = this.get_pos()
			f = this.get_flags()
			--print("bc pos")
			net_broadcast(nil, common.net_pack("BHhhhB",
				PKT_ITEM_POS, this.iid, x,y,z, f))
			net_broadcast(nil, common.net_pack("BHB", PKT_ITEM_CARRIER, this.iid, 0))
		end
	end
	
	function this.intel_capture(sec_current)
		teams[this.player.team].score = teams[this.player.team].score + 1
		net_broadcast(nil, common.net_pack("Bbh", PKT_TEAM_SCORE, this.player.team, teams[this.player.team].score))

		local cplr = this.player
		this.player = nil
		this.spawn()
		if server then
			local x,y,z,f
			x,y,z = this.get_pos()
			f = this.get_flags()
			net_broadcast(nil, common.net_pack("BHhhhB",
				PKT_ITEM_POS, this.iid, x,y,z, f))
			net_broadcast(nil, common.net_pack("BHB", PKT_ITEM_CARRIER, this.iid, 0))
			if cplr then
				cplr.score = cplr.score + SCORE_INTEL
				cplr.update_score()
			end
		end

		if teams[cplr.team].score >= TEAM_SCORE_LIMIT then
			mode_reset()
		else
			local i
			for i=1,players.max do
				local plr = players[i]
				if plr and plr.team == cplr.team then
					plr.t_rcirc = sec_current + MODE_RCIRC_LINGER
				end
			end
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
			this.z = math.floor((math.random()/2.0+0.25)*zlen)+0.5
			if this.team == 1 then this.x = xlen - this.x end
			--if this.team == 0 then this.x = xlen - this.x end -- quick test
			if this.team == nil then this.x = this.x + (xlen - (xlen/4.0))/2 end
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
	local l = (this.team and teams[this.team].color_mdl) or {170,170,170}
	this.color = l
	this.color_icon = (this.team and teams[this.team].color_chat) or {255,255,255}
	local mbone,mname,mdata
	if client then
		if va_intel then
			local ext_l = l
			this.va_intel = va_intel(function (ll)
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
		end
		this.mdl_intel = client.model_new(1)
		this.mdl_intel, mbone = client.model_bone_new(this.mdl_intel,1)
		mname,mdata = common.model_bone_get(mdl_intel, 0)
		recolor_component(l[1],l[2],l[3],mdata)
		common.model_bone_set(this.mdl_intel, 0, mname, mdata)
	end
	
	this.prespawn()
	
	return this
end


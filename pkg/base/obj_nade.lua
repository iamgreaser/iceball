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

function nade_add(nade)
	nades.tail = nades.tail + 1
	nades[nades.tail] = nade
end

function nade_prune(sec_current)
	local i
	for i=nades.head,nades.tail do
		if nades[i].dead then
			nades[i] = nil
			if i == nades.head then
				nades.head = nades.head + 1
			end
		end
	end
	if nades.head > nades.tail then
		nades.head = 1
		nades.tail = 0
	end
end

function new_nade(settings)
	local this = {
		x = settings.x,
		y = settings.y,
		z = settings.z,
		x0 = settings.x,
		y0 = settings.y,
		z0 = settings.z,
		x1 = settings.x,
		y1 = settings.y,
		z1 = settings.z,
		
		vx = settings.vx,
		vy = settings.vy,
		vz = settings.vz,
		
		pid = settings.pid,
		
		trem = 0.0,
		fuse = settings.fuse,
		dead = false
	} this.this = this
	
	local function prv_advance()
		local d,x1,y1,z1,x2,y2,z2,_
		this.x0 = this.x1
		this.y0 = this.y1
		this.z0 = this.z1
		local db = math.sqrt(this.vx*this.vx+this.vy*this.vy+this.vz*this.vz)
		--print("a",this.x0,this.y0,this.z0,this.vx,this.vy,this.vz)
		--print("db",db)
		d,x1,y1,z1,x2,y2,z2 = trace_map_ray_dist(
			this.x0,this.y0,this.z0,
			this.vx/db,this.vy/db,this.vz/db,
			db)
		
		local df = 1.0
		if d then
			df = math.max(0,d/db-0.001)
			--print("df",df,d,db)
		end
		
		this.x1 = this.x0 + this.vx*df
		this.y1 = this.y0 + this.vy*df
		this.z1 = this.z0 + this.vz*df
		
		if x1 then
			if x1 ~= x2 then this.vx = -this.vx*MODE_NADE_BDAMP end
			if y1 ~= y2 then this.vy = -this.vy*MODE_NADE_BDAMP end
			if z1 ~= z2 then this.vz = -this.vz*MODE_NADE_BDAMP end
			this.vx = this.vx * MODE_NADE_ADAMP
			this.vy = this.vy * MODE_NADE_ADAMP
			this.vz = this.vz * MODE_NADE_ADAMP
		end
		
		this.vy = this.vy + 5*9.81*MODE_NADE_STEP*MODE_NADE_STEP
	end
	
	function this.explode_dmg()
		local x,y,z
		local x0,y0,z0
		x0,y0,z0 = math.floor(this.x)
			, math.floor(this.y)
			, math.floor(this.z)
		
		local xlen,ylen,zlen
		xlen,ylen,zlen = common.map_get_dims()
		
		local hplr = this.pid and players[this.pid]
		
		local i
		for i=1,players.max do
			local plr = players[i]
			if plr and ((not hplr) or plr == hplr or plr.team ~= hplr.team) then
				local dx,dy,dz
				dx = plr.x-this.x
				dy = (plr.y+0.9)-this.y
				dz = plr.z-this.z
				
				local dd = dx*dx+dy*dy+dz*dz
				if dd < MODE_NADE_RANGE*MODE_NADE_RANGE then
					dd = math.sqrt(dd)
					dx = dx/dd
					dy = dy/dd
					dz = dz/dd
					local nd
					nd = trace_map_ray_dist(this.x,this.y,this.z, dx,dy,dz, dd)
					if not nd then
						local dmg = ((MODE_NADE_RANGE-dd)/MODE_NADE_RANGE)
						dmg = dmg * dmg
						dmg = dmg * MODE_NADE_DAMAGE
						
						plr.grenade_damage(dmg, hplr)
					end
				end
			end
		end
		
		if map_block_get(x0,y0,z0) ~= nil then
			if y0 < ylen-2 then
				map_block_break(x0,y0,z0)
				net_broadcast(nil, common.net_pack("BHHH"
					, 0x09, x0,y0,z0))
			end
		else
			for z=z0-1,z0+1 do
			for x=x0-1,x0+1 do
			for y=y0-1,y0+1 do
				if y < ylen-2 and map_block_break(x,y,z) then
					net_broadcast(nil, common.net_pack("BHHH"
						, 0x09, x,y,z))
				end
			end
			end
			end
		end
		
		
	end
	
	function this.tick(sec_current, sec_delta)
		if this.dead then return end
		
		this.trem = this.trem - sec_delta
		local i = 10
		while this.trem < 0 do
			prv_advance()
			this.trem = this.trem + MODE_NADE_STEP
			i = i - 1
			if i <= 0 then break end
		end
		
		local lerp = 1-this.trem/MODE_NADE_STEP
		this.x = this.x1*lerp+this.x0*(1-lerp)
		this.y = this.y1*lerp+this.y0*(1-lerp)
		this.z = this.z1*lerp+this.z0*(1-lerp)
		
		this.fuse = this.fuse - sec_delta
		if this.fuse <= 0 then
			-- TODO: explosion gfx
			if server then
				this.explode_dmg()
			end
			this.dead = true
		end
	end
	
	function this.render()
		if this.dead then return end
		
		client.model_render_bone_global(mdl_nade, mdl_nade_bone,
			this.x, this.y, this.z,
			0.0, 0.0, 0.0, 1.0)
	end
	
	return this
end

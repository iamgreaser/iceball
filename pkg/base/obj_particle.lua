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

particles = {head = 1, tail = 0}

function particles_add(particle)
	particles.tail = particles.tail + 1
	particles[particles.tail] = particle
end

function particles_prune(sec_current)
	local i
	for i=particles.head,particles.tail do
		if particles[i] and particles[i].dead then
			particles[i] = nil
			if i == particles.head then
				particles.head = particles.head + 1
			end
		end
	end
	if particles.head > particles.tail then
		particles.head = 1
		particles.tail = 0
	end
end

function new_particle(settings)
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
		vx = settings.vx or 0,
		vy = settings.vy or 0,
		vz = settings.vz or 0,
		r = settings.r or 255,
		g = settings.g or 255,
		b = settings.b or 255,
		size = settings.size or 32,
		lifetime = settings.lifetime or 5,
		trem = 0,
		dead = false,
		step = settings.step or 0.1,
		adamp = settings.adamp or 0.5,
		bdamp = settings.bdamp or 1,
		noclip = settings.noclip
	}
	this.this = this
	
	local mdl_particle = common.model_new(1)
	local mdl_particle_bone, mdl_particle_tab
	mdl_particle, mdl_particle_bone = common.model_bone_new(mdl_particle, 1)
	mdl_particle_tab = {{
		x = 0, y = 0, z = 0,
		radius = this.size,
		r = this.r, g = this.g, b = this.b
	}}
	common.model_bone_set(mdl_particle, mdl_particle_bone, "particle", mdl_particle_tab)
	
	local function prv_advance()
		local d,x1,y1,z1,x2,y2,z2
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
		if d and not this.noclip then
			df = math.max(0,d/db-0.001)
			--print("df",df,d,db)
		end
		
		this.x1 = this.x0 + this.vx*df
		this.y1 = this.y0 + this.vy*df
		this.z1 = this.z0 + this.vz*df
		
		if x1 then
			if not this.noclip then
				if x1 ~= x2 then this.vx = -this.vx*this.bdamp end
				if y1 ~= y2 then this.vy = -this.vy*this.bdamp end
				if z1 ~= z2 then this.vz = -this.vz*this.bdamp end
			end
			this.vx = this.vx * this.adamp
			this.vy = this.vy * this.adamp
			this.vz = this.vz * this.adamp
		end
		
		this.vy = this.vy + 5*9.81*this.step*this.step
	end
	
	function this.tick(sec_current, sec_delta)
		if this.dead then
			return
		end
		
		this.trem = this.trem - sec_delta
		local i = 10
		while this.trem < 0 do
			prv_advance()
			this.trem = this.trem + this.step
			i = i - 1
			if i <= 0 then
				break
			end
		end

		local lerp = 1 - this.trem/this.step
		this.x = this.x1*lerp+this.x0*(1-lerp)
		this.y = this.y1*lerp+this.y0*(1-lerp)
		this.z = this.z1*lerp+this.z0*(1-lerp)
		
		this.lifetime = this.lifetime - sec_delta
		if this.lifetime <= 0 then
			common.model_free(mdl_particle)
			this.dead = true
		end
	end
	
	function this.render()
		if this.dead then
			return
		end

		client.model_render_bone_global(
			mdl_particle, mdl_particle_bone,
			this.x, this.y, this.z,
			0.0, 0.0, 0.0,
			1.0
		)
	end
	
	return this
end

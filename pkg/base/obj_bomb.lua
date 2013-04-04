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
	mdl_bomb, mdl_bomb_bone = skin_load("pmf", "bomb.pmf", DIR_PKG_PMF), 0
end

function bomb_add(bomb)
	bombs.tail = bombs.tail + 1
	bombs[bombs.tail] = bomb
end

function bomb_prune(sec_current)
	local i
	for i=bombs.head,bombs.tail do
		if bombs[i] and bombs[i].dead then
			bombs[i] = nil
			if i == bombs.head then
				bombs.head = bombs.head + 1
			end
		end
	end
	if bombs.head > bombs.tail then
		bombs.head = 1
		bombs.tail = 0
	end
end

function new_bomb(settings)
	local this = {
		x = players[settings.pid].x,
		y = players[settings.pid].y,
		z = players[settings.pid].z,
		pid = settings.pid,
		fuse = 10,
		dead = false
	} this.this = this
	
	function this.explode_dmg()
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
				if dd < (MODE_NADE_RANGE*MODE_NADE_RANGE*25) then
					dd = math.sqrt(dd)
					dx = dx/dd
					dy = dy/dd
					dz = dz/dd
					local nd
					nd = trace_map_ray_dist(this.x,this.y,this.z, dx,dy,dz, dd)
					if not nd then
						local dmg = (-(math.pow(dd / (MODE_NADE_RANGE * 5), 4)) + 1) * (MODE_NADE_DAMAGE * 5)
						
						plr.explosive_damage(dmg, hplr)
					end
				end
			end
		end
	end
	
	function this.tick(sec_current, sec_delta)
		if this.dead then return end
		
		this.fuse = this.fuse - sec_delta
		if this.fuse <= 0 then
			if client then
				client.wav_play_global(wav_nade_boom, this.x, this.y, this.z)
				local i
				local bomb_particlecount = math.random() * 500 + 1000
				for i=1,bomb_particlecount do
					particles_add(new_particle{
						x = this.x,
						y = this.y-0.1,
						z = this.z,
						vx = 10*(2*math.random()-1),
						vy = 10*(2*math.random()-1.8),
						vz = 10*(2*math.random()-1),
						r = 60 + math.random() * 20,
						g = 60 + math.random() * 20,
						b = 60 + math.random() * 20,
						size = 64 + math.random() * 128,
						lifetime = 60
					})
				end
			end
			if server then
				local x,y,z
				local x0,y0,z0
				x0,y0,z0 = math.floor(this.x)
					, math.floor(this.y)
					, math.floor(this.z)
				
				local xlen,ylen,zlen
				xlen,ylen,zlen = common.map_get_dims()
				
				if map_block_get(x0,y0,z0) ~= nil then
					if y <= ylen and y >= 0 and x <= xlen and x >= 0 and z <= zlen and z >= 0 then
						map_block_break(x0,y0,z0)
						net_broadcast(nil, common.net_pack("BHHH"
							, PKT_BLK_RM1, x0,y0,z0))
					end
				else
					local r = 5
					y = y0-r
					for z=z0-r,z0+r do
					for x=x0-r,x0+r do
						if y <= ylen and y >= 0 and x <= xlen and x >= 0 and z <= zlen and z >= 0 and map_block_break(x,y,z) then
							net_broadcast(nil, common.net_pack("BHHH"
								, PKT_BLK_RM1, x,y,z))
						end
					end
					end
					y = y0+r
					for z=z0-r,z0+r do
					for x=x0-r,x0+r do
						if y <= ylen and y >= 0 and x <= xlen and x >= 0 and z <= zlen and z >= 0 and map_block_break(x,y,z) then
							net_broadcast(nil, common.net_pack("BHHH"
								, PKT_BLK_RM1, x,y,z))
						end
					end
					end
					x = x0-r
					for z=z0-r,z0+r do
					for y=y0-r,y0+r do
						if y <= ylen and y >= 0 and x <= xlen and x >= 0 and z <= zlen and z >= 0 and map_block_break(x,y,z) then
							net_broadcast(nil, common.net_pack("BHHH"
								, PKT_BLK_RM1, x,y,z))
						end
					end
					end
					x = x0+r
					for z=z0-r,z0+r do
					for y=y0-r,y0+r do
						if y <= ylen and y >= 0 and x <= xlen and x >= 0 and z <= zlen and z >= 0 and map_block_break(x,y,z) then
							net_broadcast(nil, common.net_pack("BHHH"
								, PKT_BLK_RM1, x,y,z))
						end
					end
					end
					z = z0-r
					for y=y0-r,y0+r do
					for x=x0-r,x0+r do
						if y <= ylen and y >= 0 and x <= xlen and x >= 0 and z <= zlen and z >= 0 and map_block_break(x,y,z) then
							net_broadcast(nil, common.net_pack("BHHH"
								, PKT_BLK_RM1, x,y,z))
						end
					end
					end
					z = z0+r
					for y=y0-r,y0+r do
					for x=x0-r,x0+r do
						if y <= ylen and y >= 0 and x <= xlen and x >= 0 and z <= zlen and z >= 0 and map_block_break(x,y,z) then
							net_broadcast(nil, common.net_pack("BHHH"
								, PKT_BLK_RM1, x,y,z))
						end
					end
					end
				end
				this.explode_dmg()
			end
			this.dead = true
		else
			if client then
				client.wav_play_global(wav_pin, this.x, this.y, this.z)
				local i
				local bomb_particlecount = math.random() * 5 + 10
				for i=1,bomb_particlecount do
					particles_add(new_particle{
						x = this.x,
						y = this.y-0.1,
						z = this.z,
						vx = (2*math.random()-1),
						vy = 5*(2*math.random()-1.8),
						vz = (2*math.random()-1),
						r = 60 + math.random() * 20,
						g = 60 + math.random() * 20,
						b = 60 + math.random() * 20,
						size = 16 + math.random() * 32,
						lifetime = 1
					})
				end
			end
		end
	end
	
	function this.render()
		if this.dead then return end

		client.model_render_bone_global(mdl_bomb, mdl_bomb_bone,
			this.x, this.y, this.z,
			0.0, 0.0, 0.0, 5.0)
	end
	
	return this
end

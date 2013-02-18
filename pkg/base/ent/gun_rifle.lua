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
	
	this.cfg = {
		dmg = {
			head = 100,
			body = 49,
			legs = 33,
		},
		
		ammo_clip = 10,
		ammo_reserve = 50,
		time_fire = 1/2,
		time_reload = 2.5,
		
		recoil_x = 0.0001,
		recoil_y = -0.05,
		
		name = "Rifle"
	}
	
	function this.restock()
		this.ammo_clip = this.cfg.ammo_clip
		this.ammo_reserve = this.cfg.ammo_reserve
	end
	
	function this.reset()
		this.t_fire = nil
		this.t_reload = nil
		this.reloading = false
		this.restock()
	end
	
	this.reset()
	
	local function prv_fire(sec_current)
		local xlen, ylen, zlen
		xlen, ylen, zlen = common.map_get_dims()
		
		if client then
			tracer_add(plr.x,plr.y,plr.z,
				plr.angy,plr.angx)
			
			client.wav_play_global(wav_rifle_shot, plr.x, plr.y, plr.z)
			
			particles_add(new_particle{
				x = plr.x,
				y = plr.y,
				z = plr.z,
				vx = math.sin(plr.angy - math.pi / 4) / 2 + math.random() * 0.25,
				vy = 0.1 + math.random() * 0.25,
				vz = math.cos(plr.angy - math.pi / 4) / 2 + math.random() * 0.25,
				r = 250,
				g = 215,
				b = 0,
				size = 8,
				lifetime = 5
			})
		end
		
		local sya = math.sin(plr.angy)
		local cya = math.cos(plr.angy)
		local sxa = math.sin(plr.angx)
		local cxa = math.cos(plr.angx)
		local fwx,fwy,fwz
		fwx,fwy,fwz = sya*cxa, sxa, cya*cxa
		
		-- perform a trace
		local d,cx1,cy1,cz1,cx2,cy2,cz2
		d,cx1,cy1,cz1,cx2,cy2,cz2
		= trace_map_ray_dist(plr.x+sya*0.4,plr.y,plr.z+cya*0.4, fwx,fwy,fwz, 127.5)
		d = d or 127.5
		
		-- see if there's anyone we can kill
		local hurt_idx = nil
		local hurt_part = nil
		local hurt_part_idx = 0
		local hurt_dist = d*d
		local i,j
		
		for i=1,players.max do
			local p = players[i]
			if p and p ~= plr and p.alive then
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
				players[hurt_idx].gun_damage(
					hurt_part, this.cfg.dmg[hurt_part], plr)
			else
				common.net_send(nil, common.net_pack("BBB"
					, 0x13, hurt_idx, hurt_part_idx))
				plr.show_hit()
			end
		else
			if client then
				common.net_send(nil, common.net_pack("BBB"
					, 0x13, 0, 0))
			end
			
			if cx2 and cy2 <= ylen-3 then
				common.net_send(nil, common.net_pack("BHHHH", 0x20, cx2, cy2, cz2, MODE_BLOCK_DAMAGE_RIFLE))
			end
		end
		
		-- apply recoil
		-- attempting to emulate classic behaviour provided i have it right
		plr.recoil(sec_current, this.cfg.recoil_y, this.cfg.recoil_x)
	end
	
	function this.reload()
		if this.ammo_clip ~= this.cfg.ammo_clip then
		if this.ammo_reserve ~= 0 then
		if not this.reloading then
			this.reloading = true
			client.wav_play_global(wav_rifle_reload, plr.x, plr.y, plr.z)
			common.net_send(nil, common.net_pack("BB", 0x1D, 0))
			plr.zooming = false
			this.t_reload = nil
		end end end
	end
	
	function this.click(button, state)
		if button == 1 then
			-- LMB
			if this.ammo_clip > 0 then
				this.firing = state
			else
				this.firing = false
				-- TODO: play sound
			end
		elseif button == 3 then
			-- RMB
			if hold_to_zoom then
				plr.zooming = state
			else
				if state and not this.reloading then
					plr.zooming = not plr.zooming
				end
			end
		end
	end
	
	function this.get_model()
		return weapon_models[WPN_RIFLE]
	end
	
	function this.draw(px, py, pz, ya, xa, ya2)
		client.model_render_bone_global(this.get_model(), 0,
			px, py, pz, ya, xa, ya2, 3)
	end
	
	function this.tick(sec_current, sec_delta)
		if this.reloading then
			if not this.t_reload then
				this.t_reload = sec_current + this.cfg.time_reload
			end
			
			if sec_current >= this.t_reload then
				local adelta = this.cfg.ammo_clip - this.ammo_clip
				if adelta > this.ammo_reserve then
					adelta = this.ammo_reserve
				end
				this.ammo_reserve = this.ammo_reserve - adelta
				this.ammo_clip = this.ammo_clip + adelta
				this.t_reload = nil
				this.reloading = false
				plr.arm_rest_right = 0
			else
				local tremain = this.t_reload - sec_current
				local telapsed = this.cfg.time_reload - tremain
				local roffs = math.min(tremain,telapsed)
				roffs = math.min(roffs,0.3)/0.3
				
				plr.arm_rest_right = roffs
			end
		elseif this.firing and this.ammo_clip == 0 then
			this.firing = false
		elseif this.firing and ((not this.t_fire) or sec_current >= this.t_fire) then
			prv_fire(sec_current)
			
			this.t_fire = this.t_fire or sec_current
			this.t_fire = this.t_fire + this.cfg.time_fire
			if this.t_fire < sec_current then
				this.t_fire = sec_current
			end
			
			this.ammo_clip = this.ammo_clip - 1
			
			-- TODO: poll: do we want to require a new click per shot?
			-- nope - rakiru
		end
		
		if this.t_fire and this.t_fire < sec_current then
			this.t_fire = nil
		end
	end
	
	return this
end


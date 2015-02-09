--[[
    This file is derived from a part of Ice Lua Components.

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

-- TODO: Sound effects

local thisid = ...

if client then
	wav_shotgun_shot = skin_load("wav", "shotgun-shot.wav", DIR_SHOTGUN)

	weapon_models[thisid] = model_load({
		pmf = {
			bdir = DIR_SHOTGUN,
			name = "shotgun.pmf",
		},
	}, {"pmf"})
end

weapon_names[thisid] = "Shotgun"

return function (plr)
	local this = tpl_gun(plr, {
		dmg = {
			head = 45,
			body = 25,
			legs = 17,
		},
		
		ammo_clip = 2,
		ammo_reserve = 36,
		time_fire = 0.4,
		time_reload = 1.5,
		pellet_count = 16,
		range = 127.5,
		spread = 0.15,
		
		recoil_x = 0.002,
		recoil_y = -0.3,

		model = client and (weapon_models[thisid] {}),
		
		name = weapon_names[thisid],
	})
	
	local s_click = this.click
	function this.click(button, state, ...)
		if button == 3 then
			-- RMB
			this.firing_double = state
			this.firing = this.firing or state
		else
			return s_click(button, state, ...)
		end
	end
	
	function this.prv_fire(sec_current)
		local xlen, ylen, zlen
		xlen, ylen, zlen = common.map_get_dims()
		
		if client then
			
			client.wav_play_global(wav_shotgun_shot, plr.x, plr.y, plr.z)
			
			shellcase_part_mdl = shellcase_part_mdl or new_particle_model(245, 32, 0)
			particles_add(new_particle{
				x = plr.x,
				y = plr.y,
				z = plr.z,
				vx = math.sin(plr.angy - math.pi / 4) / 2 + math.random() * 0.25,
				vy = 0.1 + math.random() * 0.25,
				vz = math.cos(plr.angy - math.pi / 4) / 2 + math.random() * 0.25,
				model = shellcase_part_mdl,
				size = 8,
				lifetime = 2
			})
		end
		
		local multiplier = 1
		if this.firing_double and this.ammo_clip >= 2 then
			multiplier = 2
			-- TODO: Make base gun work better in situations like this (ammo is removed in tick)
			this.ammo_clip = this.ammo_clip - 1
		end
		
		net_send(nil, common.net_pack("BBB", PKT_PLR_GUN_SHOT, 0, multiplier))
		
		for i=1,(this.cfg.pellet_count * multiplier) do
			-- TODO: Better spread
			-- spread
			local angy = plr.angy + (this.cfg.spread * (math.random() - 0.5))
			local angx = plr.angx + (this.cfg.spread * (math.random() - 0.5))
			
			-- maths shit
			local sya = math.sin(angy)
			local cya = math.cos(angy)
			local sxa = math.sin(angx)
			local cxa = math.cos(angx)
			local fwx,fwy,fwz
			fwx,fwy,fwz = sya*cxa, sxa, cya*cxa
			
			-- tracer
			if client then
				tracer_add(plr.x, plr.y, plr.z, angy, angx)
			end
			
			-- perform a trace
			local d,cx1,cy1,cz1,cx2,cy2,cz2
			d,cx1,cy1,cz1,cx2,cy2,cz2
			= trace_map_ray_dist(plr.x+sya*0.4,plr.y,plr.z+cya*0.4, fwx,fwy,fwz, this.cfg.range)
			d = d or this.cfg.range
			
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
					net_send(nil, common.net_pack("BBB"
						, PKT_PLR_GUN_HIT, hurt_idx, hurt_part_idx))
					plr.show_hit()
				end
			else
				if client then
					net_send(nil, common.net_pack("BBB"
						, PKT_PLR_GUN_HIT, 0, 0))
				end
				
				if cx2 and cy2 <= ylen-3 and cx2 >= 0 and cx2 < xlen and cz2 >= 0 and cz2 < zlen then
					net_send(nil, common.net_pack("BHHHH", PKT_BLK_DAMAGE, cx2, cy2, cz2, MODE_BLOCK_DAMAGE_RIFLE))
				end
			end  -- if hurt_idx
		end  -- for pellet_count
		
		-- apply recoil
		-- attempting to emulate classic behaviour provided i have it right
		plr.recoil(sec_current, this.cfg.recoil_y * multiplier, this.cfg.recoil_x * multiplier)
	end
	
	local s_tick = this.tick
	function this.tick(sec_current, sec_delta)
		s_tick(sec_current, sec_delta)
	end
	
	function this.remote_client_fire(fire_type)
		if client then
			-- TODO: Different sound for alt-fire (fire_type == 2)
			client.wav_play_global(this.cfg.shot_sound, plr.x, plr.y, plr.z)
			
			-- TODO: See network.lua comment in PKT_PLR_GUN_SHOT handler for future tracer code
			for i=1,(this.cfg.pellet_count * fire_type) do
				local angy = plr.angy + (this.cfg.spread * (math.random() - 0.5))
				local angx = plr.angx + (this.cfg.spread * (math.random() - 0.5))
				
				tracer_add(plr.x, plr.y, plr.z, angy, angx)
			end
		end
	end
	
	return this
end


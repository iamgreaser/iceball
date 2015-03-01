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
	wav_flamethrower_shot = skin_load("wav", "flamethrower-shot.wav", DIR_FLAMETHROWER)

	weapon_models[thisid] = model_load({
		kv6 = {
			bdir = DIR_FLAMETHROWER,
			name = "flamethrower.kv6",
			scale = 2.0/128.0,
		},
	}, {"kv6"})
end

weapon_names[thisid] = "MOTHERFUCKING FLAMETHROWER"  -- TODO: Be serious

local flame_particles = nil
if client then
	flame_particles = {
		new_particle_model(250, 34, 0),
		new_particle_model(250, 128, 0),
		new_particle_model(250, 167, 0),
		new_particle_model(250, 200, 0),
		new_particle_model(250, 230, 0),
	}
end

return function (plr)
	local this = tpl_gun(plr, {
		-- We're abusing this - it's not actually the hit part, but the number of parts hit
		dmg = {
			head = 2,
			body = 4,
			legs = 5,
		},
		
		ammo_clip = 200,
		ammo_reserve = 400,
		time_fire = 0.05,
		time_reload = 5,
		pellet_count = 0,
		range = 9,
		spread = 0.5,
		
		-- We null out the recoil function call anyway, but just in case I overlook that when refactoring guns...
		recoil_x = 0,
		recoil_y = 0,

		model = client and (weapon_models[thisid] {}),
		
		name = weapon_names[thisid],
	})
	
	this.burn_dmg = 4
	this.burn_time = 5
	this.burn_tick_time = 0.5
	this.flame_particle_count = 32
	
	if client then
		this.flame_particles = flame_particles
	end
	
	if server then
		this.hits = {}
	end
	
	local s_click = this.click
	function this.click(button, state, ...)
		-- inhibit RMB
		if button == 1 then
			-- LMB
			return s_click(button, state, ...)
		end
	end
	
	function this.prv_fire(sec_current)
		local xlen, ylen, zlen
		xlen, ylen, zlen = common.map_get_dims()
		
		net_send(nil, common.net_pack("BBB", PKT_PLR_GUN_SHOT, 0, 1))
				
		-- FIYAH
		if client then
			this.spray_fire()
		end
		
		-- Check if anyone is in our firing cone
		local sya = math.sin(plr.angy)
		local cya = math.cos(plr.angy)
		local sxa = math.sin(plr.angx)
		local cxa = math.cos(plr.angx)
		local fwx,fwy,fwz
		fwx,fwy,fwz = sya*cxa, sxa, cya*cxa
		
		local spread_limit = 1 - (this.cfg.spread / 2)
		local distance_limit = this.cfg.range * this.cfg.range
		
		for i=1,players.max do
			local p = players[i]
			if p and p ~= plr and p.alive then
				local dx = p.x-plr.x
				local dy = p.y-plr.y+0.1
				local dz = p.z-plr.z
				
				local hits = 0
				
				for j=1,3 do
					
					local dist = dx * dx + dy * dy + dz * dz
					
					if dist <= distance_limit then
				
						local dxn, dyn, dzn = vnorm(dx, dy, dz)
						local dot = vdot(dxn, dyn, dzn, fwx, fwy, fwz)
						
						if dot >= spread_limit then
							hits = hits + 1
						end
					end
					
					dy = dy + 1.0
				end
				
				if hits > 0 then
					net_send(nil, common.net_pack("BBB", PKT_PLR_GUN_HIT, i, hits))
					plr.show_hit()
				end
			end
		end
		
		-- apply recoil
		-- No recoil on flamethrower
		-- plr.recoil(sec_current, this.cfg.recoil_y, this.cfg.recoil_x)
	end
	
	function this.hit_player(hit_player, hit_area)
		local dmg = this.cfg.dmg[({"head","body","legs"})[hit_area]]
		if dmg then
			hit_player.wpn_damage(hit_area, dmg, plr, "roasted")
		end
		if not hit_player.inwater then
			if this.hits[hit_player] == nil then
				this.hits[hit_player] = {
					burn_end = 0,
					time_left = this.burn_tick_time,
				}
			end
			-- Reset the burn end time, so they still burn for this.burn_time once they stop getting hit
			this.hits[hit_player].burn_end = 0
		end
	end
	
	local s_tick = this.tick
	function this.tick(sec_current, sec_delta, ...)
		-- We store time left and tick it down instead of next_tick because of the way we do burn_end, and the ticks shouldn't be reset when burn_end is
		-- TODO: Check if player is in water
		if server then
			-- Keep a list of players to remove after we're done iterating
			local to_remove = {}
			for burning_player,burn_data in pairs(this.hits) do
				-- The lack of continue makes this block slightly weird
				if not burning_player.alive or burning_player.inwater then
					table.insert(to_remove, burning_player)
				else
					if burn_data.burn_end == 0 then
						-- First burn tick - set end time
						burn_data.burn_end = sec_current + this.burn_time
					end
					if sec_current >= burn_data.burn_end then
						table.insert(to_remove, burning_player)
					else
						burn_data.time_left = burn_data.time_left - sec_delta
						if burn_data.time_left <= 0 then
							burning_player.wpn_damage(2, this.burn_dmg, plr, "toasted")  -- 2 is body, but it isn't actually used in that function anymore/yet
							burn_data.time_left = burn_data.time_left + this.burn_tick_time
						end
					end
				end
			end
			
			-- Remove players that are no longer burning
			for i=1,table.getn(to_remove) do
				this.hits[to_remove[i]] = nil
			end
		end
		return s_tick(sec_current, sec_delta, ...)
	end
	
	function this.remote_client_fire(fire_type)
		if client then
			-- TODO: Different sound for alt-fire (fire_type == 2)
			-- client.wav_play_global(this.cfg.shot_sound, plr.x, plr.y, plr.z)
			this.spray_fire()
		end
	end
	
	function this.spray_fire()
		local range = this.cfg.range * 0.7
		-- TODO: Come out of gun - doesn't really work when the gun position derps around the place depending on vertical view angle
		
		for i=1,(this.flame_particle_count) do
			local angy = plr.angy + (this.cfg.spread * (math.random() - 0.5))
			local angx = plr.angx + (this.cfg.spread * (math.random() - 0.5))
			
			local sya = math.sin(angy)
			local cya = math.cos(angy)
			local sxa = math.sin(angx)
			local cxa = math.cos(angx)
			local fwx,fwy,fwz
			fwx,fwy,fwz = sya*cxa, sxa, cya*cxa
			-- Random speed/life, dependent on each other for equal travel distance
			local speed = math.random() + 0.5
			local life = 2.5 - (speed * 0.7)
			particles_add(new_particle{
				x = plr.x,
				y = plr.y + 0.35,
				z = plr.z,
				vx = fwx * range * speed,
				vy = fwy * range * speed,
				vz = fwz * range * speed,
				model = flame_particles[math.random(table.getn(flame_particles))],
				size = math.random(15, 50),
				lifetime = 0.015 * range * life  -- Magic number that makes it last about the right amount of time for the effective range
			})
		end
	end
	
	return this
end


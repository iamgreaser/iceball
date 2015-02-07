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

-- Default values used by anything that doesn't explicitly set them
local default_cfg = {
	range = 127.5,
	block_damage = MODE_BLOCK_DAMAGE_RIFLE,
	spread = 0,
	pellet_count = 1,
	shot_sound = wav_rifle_shot,
	reload_sound = wav_rifle_reload,
}

return function (plr, cfg)
	local this = {} this.this = this

	this.cfg = cfg
	
	-- Default cfg values
	for k, v in pairs(default_cfg) do
		if this.cfg[k] == nil then
			this.cfg[k] = v
		end
	end

	this.gui_x = 0.15
	this.gui_y = 0.25
	this.gui_scale = 0.2
	this.gui_pick_scale = 2.0

	function this.free()
		--
	end

	function this.get_damage(styp, tplr)
		local dmg = this.cfg.dmg[({"head","body","legs"})[styp]]
		local dtype = "killed"
		if styp == 1 then dtype = "headshot" end
		return dmg, dtype
	end
	
	function this.restock()
		this.ammo_clip = this.cfg.ammo_clip
		this.ammo_reserve = this.cfg.ammo_reserve
	end
	
	function this.reset()
		this.t_fire = nil
		this.t_reload = nil
		this.reloading = false
		this.sway = this.cfg.sway or 0
		this.restock()
	end
	
	this.reset()
	
	function this.prv_fire(sec_current)
		local xlen, ylen, zlen
		xlen, ylen, zlen = common.map_get_dims()
		
		if client then
			client.wav_play_global(this.cfg.shot_sound, plr.x, plr.y, plr.z)
			
			bcase_part_mdl = bcase_part_mdl or new_particle_model(250, 215, 0)
			particles_add(new_particle{
				x = plr.x,
				y = plr.y,
				z = plr.z,
				vx = math.sin(plr.angy - math.pi / 4) / 2 + math.random() * 0.25,
				vy = 0.1 + math.random() * 0.25,
				vz = math.cos(plr.angy - math.pi / 4) / 2 + math.random() * 0.25,
				model = bcase_part_mdl,
				size = 8,
				lifetime = 2
			})
		end
		
		net_send(nil, common.net_pack("BBB", PKT_PLR_GUN_SHOT, 0, 1))
		
		for i=1,(this.cfg.pellet_count) do
			-- TODO: Better spread
			-- spread
			local angy = plr.angy + (this.cfg.spread * (math.random() - 0.5))
			local angx = plr.angx + (this.cfg.spread * (math.random() - 0.5))
			
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
					net_send(nil, common.net_pack("BHHHH", PKT_BLK_DAMAGE, cx2, cy2, cz2, this.cfg.block_damage))
				end
			end  -- if hurt_idx
		end  -- for pellet_count
		
		-- apply recoil
		-- attempting to emulate classic behaviour provided i have it right
		plr.recoil(sec_current, this.cfg.recoil_y, this.cfg.recoil_x)
	end
	
	function this.reload()
		if this.ammo_clip ~= this.cfg.ammo_clip then
		if this.ammo_reserve ~= 0 then
		if not this.reloading then
			this.reloading = true
			client.wav_play_global(this.cfg.reload_sound, plr.x, plr.y, plr.z)
			net_send(nil, common.net_pack("BB", PKT_PLR_GUN_RELOAD, 0))
			plr.zooming = false
			this.t_reload = nil
		end end end
	end

	function this.focus()
		--
	end
	
	function this.unfocus()
		this.firing = false
		this.reloading = false
		plr.zooming = false
		plr.arm_rest_right = 0
	end

	function this.need_restock()
		return this.ammo_reserve ~= this.cfg.ammo_reserve
	end

	function this.key(key, state, modif)
		if plr.alive and state and key == BTSK_RELOAD then
			if plr.mode ~= PLM_SPECTATE and plr.alive then
				this.reload()
			end
		end
	end
	
	function this.click(button, state)
		if button == 1 then
			-- LMB
			if this.ammo_clip > 0 then
				this.firing = state
			else
				this.firing = false
				client.wav_play_global(wav_pin, plr.x, plr.y, plr.z)
				plr.reload_msg.visible = true
				plr.reload_msg.static_alarm{name='reloadviz',
					time=0.5, on_trigger=function() plr.reload_msg.visible = false end}
			end
		elseif button == 3 then
			-- RMB
			if hold_to_zoom then
				plr.zooming = state and not this.reloading
			else
				if state and not this.reloading then
					plr.zooming = not plr.zooming
				end
			end
		end
	end
	
	function this.get_va()
		return this.cfg.va
	end
	
	function this.get_model()
		return this.cfg.model
	end

	function this.textgen()
		local col
		if this.ammo_clip == 0 then
			col = 0xFFFF3232
		else
			col = 0xFFC0C0C0
		end
		return col, ""..this.ammo_clip.."-"..this.ammo_reserve
	end
	
	function this.render(px, py, pz, ya, xa, ya2)
		if this.get_va and this.get_va() then
			client.va_render_global(this.get_va(),
				px, py, pz, ya, xa, ya2, 3)
		else
			client.model_render_bone_global(this.get_model(), 0,
				px, py, pz, ya, xa, ya2, 3)
		end
	end
	
	function this.tick(sec_current, sec_delta)
		if not plr.alive then
			this.firing = false
			this.reloading = false
			plr.zooming = false
		elseif this.reloading then
			if not this.t_reload then
				this.t_reload = sec_current + this.cfg.time_reload
			end
			plr.reload_msg.visible = false
			
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
			this.prv_fire(sec_current)
			
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
		
		if plr.alive and plr.tool == TOOL_GUN then
			local swayamt = this.sway
			if plr.crouching then swayamt = swayamt * 0.5 end
			if plr.zooming then swayamt = swayamt * 0.25 end
			plr.angx = plr.angx + math.sin(sec_current * 2) * swayamt
			plr.angy = plr.angy + math.sin(sec_current * 2.5) * swayamt
		end
	end
	
	function this.remote_client_fire(fire_type)
		if client then
			client.wav_play_global(this.cfg.shot_sound, plr.x, plr.y, plr.z)
		
			-- TODO: See network.lua comment in PKT_PLR_GUN_SHOT handler for future tracer code
			for i=1,(this.cfg.pellet_count) do
				local angy = plr.angy + (this.cfg.spread * (math.random() - 0.5))
				local angx = plr.angx + (this.cfg.spread * (math.random() - 0.5))
				
				tracer_add(plr.x, plr.y, plr.z, angy, angx)
			end
		end
		
		this.ammo_clip = this.ammo_clip - 1
	end
	
	function this.remote_client_reload()
		if client then
			client.wav_play_global(this.cfg.reload_sound, plr.x, plr.y, plr.z)
		end
		
		local adelta = this.cfg.ammo_clip - this.ammo_clip
		if adelta > this.ammo_reserve then
			adelta = this.ammo_reserve
		end
		this.ammo_reserve = this.ammo_reserve - adelta
		this.ammo_clip = this.ammo_clip + adelta
	end

	return this
end


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
	
	local aimbot_oldrender = client.hook_render
	function aimbot_render(...)
		local i
		local camx,camy,camz
		camx,camy,camz = client.camera_get_pos()
		client.hook_render = aimbot_oldrender
		local ret = client.hook_render(...)
		aimbot_oldrender = client.hook_render
		client.hook_render = aimbot_render
	end
	
	local aimbot_oldtick = client.hook_tick
	function aimbot_tick(sec_current, sec_delta)
	
		client.hook_tick = aimbot_oldtick
		local ret = client.hook_tick(sec_current, sec_delta)
		aimbot_oldtick = client.hook_tick
		client.hook_tick = aimbot_oldtick and aimbot_tick
		return ret
	end
	
	client.hook_render = aimbot_render
	client.hook_tick = aimbot_tick
	
end

-- why is this copied? because model x/y has to be different from cam x/y now

local super = new_player
function new_player(...)
	local this = super(...)
	
	this.mdlangx = this.angx
	this.mdlangy = this.angy
	this.mdltargangx = this.angx
	this.mdltargangy = this.angy
	
	-- hmm the players are not appearing....
	
	-- rendering now uses mdlang
	
	function this.render(sec_current, sec_delta)
		if this.mode == PLM_SPECTATE then return end

		if this.t_piano and this.t_piano ~= true then
			local dt = this.t_piano_delta
			if dt < 0 then dt = 0 end
			if dt > 0.5 then dt = 0.5 end
			local size = (0.5-dt)/(0.5-0.4)
			if size > 1.0 then size = 1.0 end
			local dist = (dt/0.5) * -20
			client.model_render_bone_global(mdl_piano, mdl_piano_bone, this.x, this.y + dist + 2.5, this.z, 0, 0, 0, size*4)
		end
		if this.t_piano2 and this.t_piano2 ~= true then
			local dt = this.t_piano2_delta
			if dt < 0 then dt = 0 end
			if dt > 0.5 then dt = 0.5 end
			dt = dt/0.5
			local py = this.dead_y or this.y
			local h1,h2
			h1,h2 = trace_gap(this.dead_x or this.x, this.dead_y or this.y, this.dead_z or this.z)
			if h2 then py = h2 end
			client.model_render_bone_global(mdl_piano, mdl_piano_bone, this.dead_x or this.x, py, this.dead_z or this.z, 0, 0, 0, dt*4)
		end
		
		local ays,ayc,axs,axc
		ays = math.sin(this.mdlangy)
		ayc = math.cos(this.mdlangy)
		axs = math.sin(this.mdlangx)
		axc = math.cos(this.mdlangx)
		
		local mdl = nil

		local hand_x1 = -ayc*0.4
		local hand_y1 = 0.5
		local hand_z1 = ays*0.4

		local hand_x2 = ayc*0.4
		local hand_y2 = 0.5
		local hand_z2 = -ays*0.4

		local leg_x1 = -ayc*0.2
		local leg_y1 = 1.5
		local leg_z1 = ays*0.2

		local leg_x2 = ayc*0.2
		local leg_y2 = 1.5
		local leg_z2 = -ays*0.2

		if this.crouching then
			-- TODO make this look less crap
			leg_y1 = leg_y1 - 1
			leg_y2 = leg_y2 - 1
		end
		
		local swing = math.sin(rotpos/30*2)
			*math.min(1.0, math.sqrt(
				 this.vx*this.vx
				+this.vz*this.vz)/8.0)
			*math.pi/4.0

		local rax_right = (1-this.arm_rest_right)*(this.mdlangx)
				+ this.arm_rest_right*(-swing+math.pi/2)
		local rax_left = (1-this.arm_rest_left)*(this.mdlangx)
				+ this.arm_rest_left*(swing+math.pi/2)

		local mdl_x = hand_x1+math.cos(rax_right)*ays*0.8
		local mdl_y = hand_y1+math.sin(rax_right)*0.8
		local mdl_z = hand_z1+math.cos(rax_right)*ayc*0.8
		if not this.alive then
			-- do nothing --
		elseif this.tools and this.tools[this.tool+1] then
			this.tools[this.tool+1].render(this.x+mdl_x, this.y+this.jerkoffs+mdl_y, this.z+mdl_z,
				math.pi/2, -this.mdlangx + this.recoil_amt, this.mdlangy)
		end

		client.model_render_bone_global(this.mdl_player, mdl_player_arm,
			this.x+hand_x1, this.y+this.jerkoffs+hand_y1, this.z+hand_z1,
			0.0, rax_right-math.pi/2,
			this.mdlangy-math.pi, 2.0)
		client.model_render_bone_global(this.mdl_player, mdl_player_arm,
			this.x+hand_x2, this.y+this.jerkoffs+hand_y2, this.z+hand_z2,
			0.0, rax_left-math.pi/2,
			this.mdlangy-math.pi, 2.0)

		client.model_render_bone_global(this.mdl_player, mdl_player_leg,
			this.x+leg_x1, this.y+this.jerkoffs+leg_y1, this.z+leg_z1,
			0.0, swing, this.mdlangy-math.pi, 2.2)
		client.model_render_bone_global(this.mdl_player, mdl_player_leg,
			this.x+leg_x2, this.y+this.jerkoffs+leg_y2, this.z+leg_z2,
			0.0, -swing, this.mdlangy-math.pi, 2.2)

		client.model_render_bone_global(this.mdl_player, mdl_player_head,
			this.x, this.y+this.jerkoffs, this.z,
			0.0, this.mdlangx, this.mdlangy-math.pi, 1)

		client.model_render_bone_global(this.mdl_player, mdl_player_body,
			this.x, this.y+this.jerkoffs+0.8, this.z,
			0.0, 0.0, this.mdlangy-math.pi, 1.5)
	end
	
	local function prv_spawn_cont1()
		this.prespawn()

		this.alive = true
		this.spawned = true
		this.t_switch = true
	end
	
	-- spawning now sets mdlang

	function this.spawn_at(x,y,z,ya,xa)
		prv_spawn_cont1()

		this.x = x
		this.y = y
		this.z = z
		this.angy = ya
		this.angx = xa
		this.mdlangy = ya
		this.mdlangx = xa
	end

	function this.spawn()
		local xlen,ylen,zlen
		xlen,ylen,zlen = common.map_get_dims()

		prv_spawn_cont1()

		while true do
			this.x = math.floor(math.random()*xlen/4.0)+0.5
			this.z = math.floor(math.random()*zlen)+0.5
			if this.team == 1 then this.x = xlen - this.x end
			this.y = (common.map_pillar_get(this.x, this.z))[1+1]
			if this.y < ylen-1 then break end
		end
		this.y = this.y - 3.0
		this.angy, this.angx = math.pi/2.0, 0.0
		if this.team == 1 then this.angy = this.angy-math.pi end
		this.mdlangy, this.mdlangx = this.angx, this.angy
	end
	
	return this
end

-- why is this copied? because aimbot gun is way different, it's "always" firing.
-- it could probably be inherited but i didn't bother...

local function make_aimbot_gun(plr, cfg)
	local this = {} this.this = this

	this.cfg = cfg

	this.gui_x = 0.15
	this.gui_y = 0.25
	this.gui_scale = 0.2
	this.gui_pick_scale = 2.0
	
	local AIM_ZOOM_MUL = 1. -- we should bonus this only if zoom has some mechanical penalties to it too
	local AIM_CROUCH_MUL = 0.9
	local AIM_STILL = 0.5
	local AIM_FALLING = 1.5
	local AIM_MOVING = 1
	
	this.aim_limit = AIM_STILL

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
		
		-- OK, so now we're changing this to cast a ray against
		-- a pre-chosen target.
		-- the target choosing part has to happen every tick.
		
		-- TODO: add something so that targets can be "chosen" less arbitrarily
		
		this.ammo_clip = this.ammo_clip - 1
	
		if client then
			tracer_add(plr.x,plr.y,plr.z,
				plr.mdlangy,plr.mdlangx)
			
			client.wav_play_global(wav_rifle_shot, plr.x, plr.y, plr.z)
			
			particles_add(new_particle{
				x = plr.x,
				y = plr.y,
				z = plr.z,
				vx = math.sin(plr.mdlangy - math.pi / 4) / 2 + math.random() * 0.25,
				vy = 0.1 + math.random() * 0.25,
				vz = math.cos(plr.mdlangy - math.pi / 4) / 2 + math.random() * 0.25,
				r = 250,
				g = 215,
				b = 0,
				size = 8,
				lifetime = 5
			})
		end
	
		local hurt_idx = this.aimbot_target
		local hurt_part_idx = 1
		local hurt_part = ({"head","body","legs"})[hurt_part_idx]
		
		if server then
			players[hurt_idx].wpn_damage(
				hurt_part, this.cfg.dmg[hurt_part], plr, "shot")
		else
			--net_send(nil, common.net_pack("BBB"
			--	, PKT_PLR_GUN_HIT, hurt_idx, hurt_part_idx))
			--plr.show_hit()
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
			this.reload()			
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
		client.model_render_bone_global(this.get_model(), 0,
			px, py, pz, ya, xa, ya2, 3)
	end
	
	function this.aimbottable(i)
		local p = players[i]
		
		local eye_y = -0.1
		local targ_y
		for k,targ_y in pairs({0,1.55}) do
			if p and p ~= plr and p.alive then
			
				local gun_x = (plr.x)
				local gun_y = (plr.y+eye_y)
				local gun_z = (plr.z)
			
				local other_x = (p.x)
				local other_y = (p.y+eye_y)
				local other_z = (p.z)
				
				local dx = p.x-gun_x
				local dy = (p.y+targ_y)-gun_y
				local dz = p.z-gun_z
				
				local dd = math.sqrt(dx * dx + dy * dy + dz * dz)
				
				if dd < 127.5 then
					local dxdd = dx/dd
					local dydd = dy/dd
					local dzdd = dz/dd
				
					-- trace
					local d,cx1,cy1,cz1,cx2,cy2,cz2
					d,cx1,cy1,cz1,cx2,cy2,cz2
					= trace_map_ray_dist(gun_x,gun_y,gun_z, dxdd,dydd,dzdd, 127.5)
					if d and d-dd>=0 then
						return {dxdd,dydd,dzdd}
					end
					-- trace again because aliasing may make the result different
					local d,cx1,cy1,cz1,cx2,cy2,cz2
					d,cx1,cy1,cz1,cx2,cy2,cz2
					= trace_map_ray_dist(other_x,other_y,other_z, -dxdd,-dydd,-dzdd, 127.5)
					if d and d-dd>=0 then
						return {dxdd,dydd,dzdd}
					end
				end
			end
		end
		
		return nil
	end
	
	function this.tick(sec_current, sec_delta)
	
		local pi = 3.1415926535
		local tau = pi * 2

		local function rotation_dist(a, b)
			if (a - b >= pi) then return (b + tau) - a
			elseif (a - b <= -pi) then return (b - tau) - a
			else return b - a end
		end
	
		local function tween(a, b, q)
			return a + (b - a) * q
		end
		
		local function rtween(a, b, q)
			return a + rotation_dist(a, b) * q
		end
		
		-- we always are "firing" if we have the gun out
		if plr.tool == 2 and not this.reloading then
			this.firing = true
		else
			this.aimbot_target = nil
			this.aimbot_trace = nil
		end
		
		-- monitor tracking of current target		
		if this.aimbot_target then
			this.aimbot_trace = this.aimbottable(this.aimbot_target)
			if this.aimbot_trace == nil then
				this.aimbot_target = nil
			end
		end
		
		-- find new targets
		if this.aimbot_target == nil then
			
			-- update aim_limit
			local hdist = math.abs(vlen(plr.vx, plr.vz, 0))
			local vdist = math.abs(plr.vy)
			if vdist>0.01 then
				this.aim_limit = tween(AIM_STILL, AIM_FALLING, math.min(vdist, 2)/2)
			elseif hdist>0.01 then
				this.aim_limit = tween(AIM_STILL, AIM_MOVING, math.min(hdist, 4)/4)
			else
				this.aim_limit = AIM_STILL
			end
			if plr.crouching then
				this.aim_limit = this.aim_limit * AIM_CROUCH_MUL
			end
			if plr.zooming then 
				this.aim_limit = this.aim_limit * AIM_ZOOM_MUL
			end
			this.aim_limit = this.aim_limit + sec_current
		
			-- find new traces
			this.aimbot_trace = nil
			for i=1, players.max do
				this.aimbot_trace = this.aimbottable(i)
				if this.aimbot_trace then
					this.aimbot_target = i
					break
				end
			end
			
		end
		
		if client then
			local aim_readout_update = function(options)
				if plr.mode == PLM_NORMAL and plr.alive and this.aim_limit then
					plr.health_text.text = ""..math.floor(math.max(0,(this.aim_limit - sec_current)) * 100)	
				end
			end
			-- really, we should add a new text or something less hacky.
			if plr.health_text then
				plr.health_text.listeners[GE_DELTA_TIME] = {aim_readout_update}
			end
		end
	
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
		elseif this.firing and plr.alive and this.aimbot_target then
				
			-- ok now we add some built-in delay on top of the firing delay.
			-- this happens as soon as we get the "i found an aimbot target" event.
			-- if the target changes we don't change the delay...
			
			-- we have the constants set up and aim_time and aim_limit
			-- the moment at which aiming is allowed should be AFTER we hit the moment where
			-- we are ABLE to fire.
			-- that is, prv_fire has to happen inside polling logic in the "aimbot_target is there" thingy,
			-- and that polling logic is the only thing that can advance the aim timer.
			-- if we don't have a target then we start resetting the state of aim_limit.
		
			if sec_current >= this.aim_limit then
				this.prv_fire(sec_current)
				
				this.aimbot_target = nil
				this.aimbot_trace = nil
				this.aim_limit = nil
			end
		end
		
		-- calculate and tween in the model movements
		
		if this.aimbot_target and plr.alive then
			local dist = math.sqrt(this.aimbot_trace[1]*this.aimbot_trace[1]+this.aimbot_trace[3]*this.aimbot_trace[3])			
			plr.mdltargangy = math.atan2(this.aimbot_trace[1], this.aimbot_trace[3])
			plr.mdltargangx = math.atan2(this.aimbot_trace[2], dist)
			plr.mdlangx = tween(plr.mdlangx, plr.mdltargangx, 0.1)
			plr.mdlangy = rtween(plr.mdlangy, plr.mdltargangy, 0.1)
		else
			plr.mdltargangx = plr.angx
			plr.mdltargangy = plr.angy
			plr.mdlangx = tween(plr.mdlangx, plr.mdltargangx, 0.2)
			plr.mdlangy = rtween(plr.mdlangy, plr.mdltargangy, 0.2)
		end
		
	end

	return this
end

local rifle = function (plr)
	local this = make_aimbot_gun(plr, {
		dmg = {
			head = 100,
			body = 49,
			legs = 33,
		},
		
		ammo_clip = 13,
		ammo_reserve = 50,
		time_fire = 1/2,
		time_reload = 2.5,
		
		recoil_x = 0.0001,
		recoil_y = -0.05,

		model = weapon_models[WPN_RIFLE],
		
		name = "Rifle",
	})
	
	return this
end

local leerifle = rifle

weapons = {
	[WPN_RIFLE] = rifle,
	[WPN_LEERIFLE] = leerifle,
}

print("Aimbot plugin loaded.")

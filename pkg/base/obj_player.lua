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

function new_player(settings)
	local this = {} this.this = this this.this.this = this this = this.this
	
	this.team = settings.team or math.floor(math.random()*2)
	this.squad = settings.squad or nil
	this.weapon = settings.weapon or WPN_RIFLE
	this.alive = false
	this.spawned = false
	this.zooming = false
	
	this.mdl_block = common.model_new(1)
	this.mdl_block = common.model_bone_new(this.mdl_block)
	
	this.mdl_player = common.model_new(4)
	this.mdl_player = common.model_bone_new(this.mdl_player)
	this.mdl_player = common.model_bone_new(this.mdl_player)
	this.mdl_player = common.model_bone_new(this.mdl_player)
	this.mdl_player = common.model_bone_new(this.mdl_player)
	
	local function prv_recolor_team(r,g,b)
		if not client then return end
		local mname,mdata
		mname,mdata = common.model_bone_get(mdl_player, mdl_player_head)
		recolor_component(r,g,b,mdata)
		common.model_bone_set(this.mdl_player, mdl_player_head, mname, mdata)
		mname,mdata = common.model_bone_get(mdl_player, mdl_player_body)
		recolor_component(r,g,b,mdata)
		common.model_bone_set(this.mdl_player, mdl_player_body, mname, mdata)
		mname,mdata = common.model_bone_get(mdl_player, mdl_player_arm)
		recolor_component(r,g,b,mdata)
		common.model_bone_set(this.mdl_player, mdl_player_arm, mname, mdata)
		mname,mdata = common.model_bone_get(mdl_player, mdl_player_leg)
		recolor_component(r,g,b,mdata)
		common.model_bone_set(this.mdl_player, mdl_player_leg, mname, mdata)
	end
	
	local function prv_recolor_block(r,g,b)
		if not client then return end
		local mname,mdata
		mname,mdata = common.model_bone_get(mdl_block, mdl_block_bone)
		recolor_component(r,g,b,mdata)
		common.model_bone_set(this.mdl_block, mdl_block_bone, mname, mdata)
	end
	
	prv_recolor_block(0,0,0)
	do
		local c = teams[this.team].color_mdl
		local r,g,b
		r,g,b = c[1],c[2],c[3]
		prv_recolor_team(r,g,b)
	end
	
	function this.input_reset()
		this.ev_forward = false
		this.ev_back = false
		this.ev_left = false
		this.ev_right = false
		
		this.ev_jump = false
		this.ev_crouch = false
		this.ev_sneak = false
	end
	
	this.input_reset()
	
	function this.free()
		if this.mdl_block then common.model_free(this.mdl_block) end
		if this.mdl_player then common.model_free(this.mdl_player) end
	end
	
	this.t_rcirc = nil
	
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
		this.y = this.y - 3.0
		
		this.alive = true
		this.spawned = true
		
		this.grounded = false
		this.crouching = false
		
		this.arm_rest_right = 0.0
		this.arm_rest_left = 1.0
		
		this.t_respawn = nil
		this.t_switch = true
		this.t_newnade = nil
		this.t_newblock = nil
		this.t_newspade1 = nil
		this.t_newspade2 = nil
		
		this.vx, this.vy, this.vz = 0, 0, 0
		this.angy, this.angx = math.pi/2.0, 0.0
		this.dangx, this.dangy = 0, 0
		if this.team == 1 then this.angy = this.angy-math.pi end
		
		this.blx1, this.bly1, this.blz1 = nil, nil, nil
		this.blx2, this.bly2, this.blz2 = nil, nil, nil
		
		this.blk_color = {0x7F,0x7F,0x7F}
		this.blk_color_x = 3
		this.blk_color_y = 0
		
		this.jerkoffs = 0.0
		
		this.zoom = 1.0
		this.zooming = false
		
		this.health = 100
		this.blocks = 25
		this.grenades = 2
		
		this.wpn = weapons[this.weapon](this)
		
		this.tool = 2
		
		this.has_intel = nil
	end
	
	this.name = settings.name or "Noob"
	this.spawn()
	
	function this.tool_switch(tool)
		if this.tool == TOOL_GUN then
			if this.wpn then
				this.wpn.firing = false
				this.wpn.reloading = false
			end
			this.zooming = false
			this.arm_rest_right = 0
		end
		this.t_switch = true
		this.tool = tool
	end
	
	function this.recoil(sec_current, recoil_y, recoil_x)
		local xrec = recoil_x*math.cos(sec_current*math.pi*2)*math.pi*20
		local ydip = math.sin(this.angx)
		local ycos = math.cos(this.angx)
		local yrec = recoil_y + ydip
		local ydist = math.sqrt(ycos*ycos+yrec*yrec)
		this.angy = this.angy + xrec
		this.angx = math.asin(yrec/ydist)
	end
	
	function this.damage(amt, kcol, kmsg)
		this.health = this.health - amt
		if this.health <= 0 then
			this.intel_drop()
			chat_add(chat_killfeed, nil, kmsg, kcol)
			this.health = 0
			this.alive = false
		end
	end
	
	function this.fall_damage(amt)
		--print("damage",this.name,part,amt)
		local l = teams[this.team].color_chat
		r,g,b = l[1],l[2],l[3]
		
		local c = argb_split_to_merged(r,g,b)
		
		local kmsg = this.name.." found a high place"
		this.damage(amt, c, kmsg)
	end
	
	function this.gun_damage(part, amt, enemy)
		--print("damage",this.name,part,amt)
		local midmsg = " killed "
		if this.team == enemy.team then
			midmsg = " teamkilled "
		end
		
		local r,g,b
		r,g,b = 0,0,0
		
		local l = teams[enemy.team].color_chat
		r,g,b = l[1],l[2],l[3]
		
		local c = argb_split_to_merged(r,g,b)
		
		local kmsg = enemy.name..midmsg..this.name
		this.damage(amt, c, kmsg)
	end
	
	function this.grenade_damage(amt, enemy)
		--print("damage",this.name,part,amt)
		local midmsg = " killed "
		if this.team == enemy.team then
			midmsg = " teamkilled "
		end
		
		local r,g,b
		r,g,b = 0,0,0
		
		local l = teams[enemy.team].color_chat
		r,g,b = l[1],l[2],l[3]
		
		local c = argb_split_to_merged(r,g,b)
		
		local kmsg = enemy.name..midmsg..this.name
		if enemy == this then
			kmsg = this.name.." exploded"
		end
		
		this.damage(amt, c, kmsg)
	end
	
	function this.intel_pickup(intel)
		if this.has_intel or intel.team == this.team then
			return false
		end
		
		local s = this.name.." has picked up the "..teams[intel.team].name.." intel."
		this.has_intel = intel
		chat_add(chat_text, nil, s, 0xFFC00000)
		
		return true
	end
	
	function this.intel_drop()
		local intel = this.has_intel
		if not intel then
			return
		end
		
		local s = this.name.." has dropped the "..teams[intel.team].name.." intel."
		intel.intel_drop()
		this.has_intel = nil
		chat_add(chat_text, nil, s, 0xFFC00000)
	end
	
	function this.intel_capture(sec_current)
		local intel = this.has_intel
		if not intel then
			return
		end
		
		local s = this.name.." has captured the "..teams[intel.team].name.." intel."
		intel.intel_capture(sec_current)
		this.has_intel = nil
		chat_add(chat_text, nil, s, 0xFFC00000)
	end
	
	function this.tick(sec_current, sec_delta)
		if (not this.alive) and (not this.t_respawn) then
			this.t_respawn = sec_current + MODE_RESPAWN_TIME
			this.input_reset()
		end
		
		if this.t_respawn then
			if this.t_respawn <= sec_current then
				this.t_respawn = nil
				this.spawn()
			else
				-- any last requests?
			end
		end
		
		if this.t_switch == true then
			this.t_switch = sec_current + 0.2
		end
		
		if this.t_rcirc and sec_current >= this.t_rcirc then
			this.t_rcirc = nil
		end
		
		if this.alive and this.t_switch then
			if sec_current > this.t_switch then
				this.t_switch = nil
				this.arm_rest_right = 0
			else
				local delta = this.t_switch-sec_current
				this.arm_rest_right = math.max(0.0,delta/0.2)
			end
		end
		
		-- apply delta angle
		this.angx = this.angx + this.dangx
		this.angy = this.angy + this.dangy
		this.dangx = 0
		this.dangy = 0
		
		-- clamp angle, YOU MUST NOT LOOK DIRECTLY UP OR DOWN!
		if this.angx > math.pi*0.499 then
			this.angx = math.pi*0.499
		elseif this.angx < -math.pi*0.499 then
			this.angx = -math.pi*0.499
		end
		
		if this.zooming then
			this.zoom = 3.0
		else
			this.zoom = 1.0
		end
		
		-- set camera direction
		local sya = math.sin(this.angy)
		local cya = math.cos(this.angy)
		local sxa = math.sin(this.angx)
		local cxa = math.cos(this.angx)
		local fwx,fwy,fwz
		fwx,fwy,fwz = sya*cxa, sxa, cya*cxa
		
		-- move along
		local mvx = 0.0
		local mvy = 0.0
		local mvz = 0.0
		
		if this.ev_forward then
			mvz = mvz + 1.0
		end
		if this.ev_back then
			mvz = mvz - 1.0
		end
		if this.ev_left then
			mvx = mvx + 1.0
		end
		if this.ev_right then
			mvx = mvx - 1.0
		end
		if this.ev_crouch then
			if this.grounded and not this.crouching then
				if MODE_SOFTCROUCH then this.jerkoffs = this.jerkoffs - 1 end
				this.y = this.y + 1
			end
			this.crouching = true
		end
		if this.ev_jump and (MODE_CHEAT_FLY or this.grounded) then
			this.vy = -7
			this.ev_jump = false
		end
		
		-- normalise mvx,mvz
		local mvd = math.max(0.00001,math.sqrt(mvx*mvx + mvz*mvz))
		mvx = mvx / mvd
		mvz = mvz / mvd
		
		-- apply base slowdown
		local mvspd = 8.0
		local mvchange = 10.0
		mvx = mvx * mvspd
		mvz = mvz * mvspd
		
		-- apply extra slowdowns
		if not this.grounded then
			mvx = mvx * 0.6
			mvz = mvz * 0.6
			mvchange = mvchange * 0.3
		end
		if this.y > 61.0 then
			mvx = mvx * 0.6
			mvz = mvz * 0.6
		end
		if this.crouching then
			mvx = mvx * 0.5
			mvz = mvz * 0.5
		end
		if this.zooming or this.ev_sneak then
			mvx = mvx * 0.5
			mvz = mvz * 0.5
		end
		
		-- apply rotation
		mvx, mvz = mvx*cya+mvz*sya, mvz*cya-mvx*sya
		
		this.vx = this.vx + (mvx - this.vx)*(1.0-math.exp(-sec_delta*mvchange))
		this.vz = this.vz + (mvz - this.vz)*(1.0-math.exp(-sec_delta*mvchange))
		this.vy = this.vy + 2*9.81*sec_delta
		
		local ox, oy, oz
		local nx, ny, nz
		local tx1,ty1,tz1
		ox, oy, oz = this.x, this.y, this.z
		this.x, this.y, this.z = this.x + this.vx*sec_delta, this.y + this.vy*sec_delta, this.z + this.vz*sec_delta
		nx, ny, nz = this.x, this.y, this.z
		this.jerkoffs = this.jerkoffs * math.exp(-sec_delta*15.0)
		
		local by1, by2
		by1, by2 = -0.3, 2.5
		if this.crouching then
			if (not this.ev_crouch) and box_is_clear(
					ox-0.39, oy-0.8, oz-0.39,
					ox+0.39, oy-0.3, oz+0.39) then
				this.crouching = false
				oy = oy - 1
				if this.grounded then
					ny = ny - 1
					if MODE_SOFTCROUCH then this.jerkoffs = this.jerkoffs + 1 end
				end
			end
		end
		if this.crouching or MODE_AUTOCLIMB then
			by2 = by2 - 1
		end
		
		
		if this.alive then
			tx1,ty1,tz1 = trace_map_box(
				ox, oy, oz,
				nx, ny, nz,
				-0.4,  by1, -0.4,
				0.4,  by2,  0.4,
				false)
		else
			tx1,ty1,tz1 = nx,ny,nz
		end
		
		if this.alive and MODE_AUTOCLIMB then
			local jerky = ty1
			if not this.crouching then
				ty1 = ty1 - 1
				by2 = by2 + 1
			end
			tx1,ty1,tz1 = trace_map_box(
				tx1,ty1,tz1,
				nx, ny, nz,
				-0.4,  by1, -0.4,
				0.4,  by2,  0.4,
				false)
			if ty1-jerky < -0.8 and not box_is_clear(
					nx-0.4, ny-0.3-0.5, nz-0.4,
					nx+0.4, ny-0.3, nz+0.4) then
				this.crouching = true
				ty1 = ty1 + 1
			end
			if math.abs(jerky-ty1) > 0.2 then
				this.jerkoffs = this.jerkoffs + jerky - ty1
			end
		end
		
		this.x, this.y, this.z = tx1, ty1, tz1
		
		this.grounded = (MODE_AIRJUMP and this.grounded) or not box_is_clear(
			tx1-0.39, ty1+by2, tz1-0.39,
			tx1+0.39, ty1+by2+0.1, tz1+0.39)
		
		if this.alive and this.vy > 0 and this.grounded then
			this.vy = 0
		end
		
		-- trace for stuff
		do
			local td
			local _
			
			local camx,camy,camz
			camx = this.x+0.4*math.sin(this.angy)
			camy = this.y
			camz = this.z+0.4*math.cos(this.angy)
			
			td,
			this.blx1, this.bly1, this.blz1, 
			this.blx2, this.bly2, this.blz2
			= trace_map_ray_dist(camx,camy,camz, fwx,fwy,fwz, 5)
			
			_,
			_, _, _, 
			this.blx3, this.bly3, this.blz3
			= trace_map_ray_dist(camx,camy,camz, fwx,fwy,fwz, 127.5)
		end
		
		-- update gun
		if this.wpn then this.wpn.tick(sec_current, sec_delta) end
	end
	
	function this.camera_firstperson()
		-- set camera position
		client.camera_move_to(this.x, this.y + this.jerkoffs, this.z)
		
		-- set camera direction
		local sya = math.sin(this.angy)
		local cya = math.cos(this.angy)
		local sxa = math.sin(this.angx)
		local cxa = math.cos(this.angx)
		local fwx,fwy,fwz
		fwx,fwy,fwz = sya*cxa, sxa, cya*cxa
		client.camera_point(fwx, fwy, fwz, this.zoom, 0.0)
		
		-- offset by eye pos
		-- slightly cheating here.
		client.camera_move_global(sya*0.4, 0, cya*0.4)
	end
	
	function this.render()
		local ays,ayc,axs,axc
		ays = math.sin(this.angy)
		ayc = math.cos(this.angy)
		axs = math.sin(this.angx)
		axc = math.cos(this.angx)
		
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
		
		local rax_right = (1-this.arm_rest_right)*(this.angx)
				+ this.arm_rest_right*(-swing+math.pi/2)
		local rax_left = (1-this.arm_rest_left)*(this.angx)
				+ this.arm_rest_left*(swing+math.pi/2)
		
		local mdl_x = hand_x1+math.cos(rax_right)*ays*0.8
		local mdl_y = hand_y1+math.sin(rax_right)*0.8
		local mdl_z = hand_z1+math.cos(rax_right)*ayc*0.8
		if this.tool == TOOL_SPADE then
			client.model_render_bone_global(mdl_spade, mdl_spade_bone,
				this.x+mdl_x, this.y+this.jerkoffs+mdl_y, this.z+mdl_z,
				--0.0, -this.angx-math.pi/2*0.90, this.angy, 1)
				0.0, -this.angx, this.angy, 1)
		elseif this.tool == TOOL_BLOCK then
			client.model_render_bone_global(this.mdl_block, mdl_block_bone,
				this.x+mdl_x, this.y+this.jerkoffs+mdl_y, this.z+mdl_z,
				0.0, -this.angx, this.angy, 1)
		elseif this.tool == TOOL_GUN then
			this.wpn.draw(this.x+mdl_x, this.y+this.jerkoffs+mdl_y, this.z+mdl_z,
				math.pi/2, -this.angx, this.angy)
		elseif this.tool == TOOL_NADE then
			client.model_render_bone_global(mdl_nade, mdl_nade_bone,
				this.x+mdl_x, this.y+this.jerkoffs+mdl_y, this.z+mdl_z,
				0.0, -this.angx, this.angy, 0.5)
		end
		
		client.model_render_bone_global(this.mdl_player, mdl_player_arm,
			this.x+hand_x1, this.y+this.jerkoffs+hand_y1, this.z+hand_z1,
			0.0, rax_right-math.pi/2,
			this.angy-math.pi, 2.0)
		client.model_render_bone_global(this.mdl_player, mdl_player_arm,
			this.x+hand_x2, this.y+this.jerkoffs+hand_y2, this.z+hand_z2,
			0.0, rax_left-math.pi/2,
			this.angy-math.pi, 2.0)
		
		client.model_render_bone_global(this.mdl_player, mdl_player_leg,
			this.x+leg_x1, this.y+this.jerkoffs+leg_y1, this.z+leg_z1,
			0.0, swing, this.angy-math.pi, 2.2)
		client.model_render_bone_global(this.mdl_player, mdl_player_leg,
			this.x+leg_x2, this.y+this.jerkoffs+leg_y2, this.z+leg_z2,
			0.0, -swing, this.angy-math.pi, 2.2)
		
		client.model_render_bone_global(this.mdl_player, mdl_player_head,
			this.x, this.y+this.jerkoffs, this.z,
			0.0, this.angx, this.angy-math.pi, 1)
		
		client.model_render_bone_global(this.mdl_player, mdl_player_body,
			this.x, this.y+this.jerkoffs+0.8, this.z,
			0.0, 0.0, this.angy-math.pi, 1.5)
		
		if this.has_intel then
			this.has_intel.render_backpack()
		end
	end
	
	function this.show_hud()
		local fogr,fogg,fogb,fogd = client.map_fog_get()
		
		local ays,ayc,axs,axc
		ays = math.sin(this.angy)
		ayc = math.cos(this.angy)
		axs = math.sin(this.angx)
		axc = math.cos(this.angx)
		
		local w, h
		local i, j
		w, h = client.screen_get_dims()
		
		-- TODO: palettise this more nicely
		prv_recolor_block(this.blk_color[1],this.blk_color[2],this.blk_color[3])
		
		if (this.tool == TOOL_SPADE or this.tool == TOOL_BLOCK) and this.blx1 then
			client.model_render_bone_global(mdl_test, mdl_test_bone,
				this.blx1+0.5, this.bly1+0.5, this.blz1+0.5,
				rotpos*0.01, rotpos*0.004, 0.0, 0.1+0.01*math.sin(rotpos*0.071))
			client.model_render_bone_global(mdl_test, mdl_test_bone,
				(this.blx1*2+this.blx2)/3+0.5,
				(this.bly1*2+this.bly2)/3+0.5,
				(this.blz1*2+this.blz2)/3+0.5,
				-rotpos*0.01, -rotpos*0.004, 0.0, 0.1+0.01*math.sin(-rotpos*0.071))
		end
		--[[
		client.model_render_bone_local(mdl_test, mdl_test_bone,
			1-0.2, 600/800-0.2, 1.0,
			rotpos*0.01, rotpos*0.004, 0.0, 0.1)
		]]
		
		-- TODO: not have this on all the time
		client.model_render_bone_local(mdl_spade, mdl_spade_bone,
			1-0.15, -h/w+0.25+((this.tool == TOOL_SPADE and 0.02*math.sin(rotpos*0.02)) or 0), 1.0,
			rotpos*0.01, 0.0, 0.0, 0.2*((this.tool == TOOL_SPADE and 1.5) or 1.0))
		client.model_render_bone_local(this.mdl_block, this.mdl_block_bone,
			1-0.30, -h/w+0.2+((this.tool == TOOL_BLOCK and 0.02*math.sin(rotpos*0.02)) or 0), 1.0,
			rotpos*0.01, 0.0, 0.0, 0.1*((this.tool == TOOL_BLOCK and 2.0) or 1.0))
		client.model_render_bone_local(this.wpn.get_model(), 0,
			1-0.45, -h/w+0.2+((this.tool == TOOL_GUN and 0.02*math.sin(rotpos*0.02)) or 0), 1.0,
			rotpos*0.01, 0.0, 0.0, 0.2*((this.tool == TOOL_GUN and 2.0) or 1.0))
		client.model_render_bone_local(mdl_nade, mdl_nade_bone,
			1-0.60, -h/w+0.2+((this.tool == TOOL_NADE and 0.02*math.sin(rotpos*0.02)) or 0), 1.0,
			rotpos*0.01, 0.0, 0.0, 0.1*((this.tool == TOOL_NADE and 2.0) or 1.0))
		
		this.render()
		
		if MODE_DEBUG_SHOWBOXES then
			client.model_render_bone_global(mdl_bbox, 
				(this.crouching and mdl_bbox_bone2) or mdl_bbox_bone1,
				this.x, this.y, this.z, 0, 0, 0.0, 1)
		end
		
		for i=1,players.max do
			local plr = players[i]
			if plr and plr ~= this then
				plr.render()
				if plr.alive and plr.team == this.team then
					local px,py
					local dx,dy,dzNULL
					dx,dy,dz = plr.x-this.x,
						plr.y+plr.jerkoffs-this.y-this.jerkoffs-0.5,
						plr.z-this.z
					local d = dx*dx+dy*dy+dz*dz
					d = math.sqrt(d)
					dx,dy,dz = dx/d,dy/d,dz/d
					dx,dy,dz =
						(dx*ayc-dz*ays),
						dy,
						(dx*ays+dz*ayc)
					dx,dy,dz =
						dx,
						(dy*axc-dz*axs),
						(dy*axs+dz*axc)
					
					if dz > 0.001 then
						local fatt = ((fogd*fogd
							-((d*d < 0.001 and 0.001) or d*d))
							/(fogd*fogd));
						if fatt > 1.0 then fatt = 1.0 end
						if fatt < 0.25 then fatt = 0.25 end
						px = w/2-w/2*dx*this.zoom/dz
						py = h/2+w/2*dy*this.zoom/dz
						local c
						if plr.squad and plr.squad == this.squad then
							c = {255,255,255}
						else
							c = teams[this.team].color_chat
						end
						
						local s_name = plr.name
						if plr.squad then
							s_name = s_name.." ["..plr.squad.."]"
						end
						
						gui_print_mini(px-(6*#s_name)/2,py-7
							,argb_split_to_merged(c[1],c[2],c[3]
								,math.floor(fatt*255))
							,s_name)
					end
				end
			end
		end
		
		for i=1,#intent do
			local obj = intent[i]
			if obj.visible then
				obj.render()
			end
		end
		
		if this.has_intel then
			local intel = this.has_intel
			intel.render_icon(-0.5,-0.5,1.0,0.2)
		end
		
		local hcolor = 0xFFA1FFA1
		local acolor = 0xFFC0C0C0
		local gcolor = 0xFFC0C0C0
		local cr,cg,cb
		cr,cg,cb = this.blk_color[1],this.blk_color[2],this.blk_color[3]
		local bcolor = (cr*256+cg)*256+cb
		local hstr = ""..this.health
		local astr = ""..this.wpn.ammo_clip.."-"..this.wpn.ammo_reserve
		local bstr = ""..this.blocks
		local gstr = ""..this.grenades
		
		gui_print_digits((w-32*#hstr)/2, h-48, hcolor, hstr)
		if this.tool == TOOL_GUN then
			gui_print_digits(-16+w-32*#astr, h-48, acolor, astr)
		elseif this.tool == TOOL_NADE then
			gui_print_digits(-16+w-32*#gstr, h-48, gcolor, gstr)
		else
			gui_print_digits(-16+w-32*#bstr, h-48, bcolor+0xFF000000, bstr)
		end
		local i
		
		if debug_enabled then
			local camx,camy,camz
			camx,camy,camz = client.camera_get_pos()
			local cam_pos_str = string.format("x: %f y: %f z: %f j: %f c: %i"
				, camx, camy, camz, this.jerkoffs, (this.crouching and 1) or 0)
			
			gui_print_mini(4, 4, 0x80FFFFFF, cam_pos_str)
		end
		
		client.img_blit(img_crosshair, w/2 - 8, h/2 - 8)
		
		for i=1,#log_mspr,2 do
			local u,v
			u = log_mspr[i  ]
			v = log_mspr[i+1]
			common.img_pixel_set(img_overview_icons, u, v, 0x00000000)
		end
		log_mspr = {}
		
		for j=1,players.max do
			local plr = players[j]
			if plr then
				local x,y
				x,y = plr.x, plr.z
				local c
				local drawit = true
				if not plr.alive then
					drawit = false
				elseif plr == this then
					c = 0xFF00FFFF
				elseif plr.team == this.team then
					c = 0xFFFFFFFF
				else
					c = 0xFFFF0000
					drawit = drawit and (this.t_rcirc ~= nil and
						(MODE_MINIMAP_RCIRC or large_map))
				end
				
				if drawit then
					for i=1,#mspr_player,2 do
						local u,v
						u = math.floor(x)+mspr_player[i  ]
						v = math.floor(y)+mspr_player[i+1]
						log_mspr[#log_mspr+1] = u
						log_mspr[#log_mspr+1] = v
						common.img_pixel_set(img_overview_icons, u, v, c)
					end
				end
			end
		end
		
		for j=1,#intent do
			local obj = intent[j]
			
			if obj.visible then
				local x,y
				x,y = obj.x, obj.z
				local l = teams[obj.team].color_chat
				local c = argb_split_to_merged(l[1],l[2],l[3])
				for i=1,#(obj.mspr),2 do
					local u,v
					u = math.floor(x)+obj.mspr[i  ]
					v = math.floor(y)+obj.mspr[i+1]
					log_mspr[#log_mspr+1] = u
					log_mspr[#log_mspr+1] = v
					common.img_pixel_set(img_overview_icons, u, v, c)
				end
			end
		end
		
		local ow, oh
		ow, oh = common.img_get_dims(img_overview)
		if large_map then
			local mx, my
			mx = w/2 - ow/2
			my = h/2 - oh/2 - 24
			client.img_blit(img_overview, mx, my)
			client.img_blit(img_overview_grid, mx, my,
				ow, oh, 0, 0, 0x80FFFFFF)
			client.img_blit(img_overview_icons, mx, my)
			
			local i
			
			for i=1,8 do
				gui_print_mini(mx - 12, my + (i-0.5)*64,
					0xFFFFFFFF, ""..i)
				gui_print_mini(mx + ow + 12-6, my + (i-0.5)*64,
					0xFFFFFFFF, ""..i)
				gui_print_mini(mx + (i-0.5)*64, my - 12,
					0xFFFFFFFF, ""..string.char(64+i))
				gui_print_mini(mx + (i-0.5)*64, my + oh + 12-6,
					0xFFFFFFFF, ""..string.char(64+i))
			end
		elseif MODE_ENABLE_MINIMAP then
			-- TODO: make this a JSON option
			local mw, mh
			mw, mh = 128, 128
			local qx, qy
			
			for qy=-1,1 do
			for qx=-1,1 do
				client.img_blit(img_overview, w - mw, 0,
					mw, mh,
					this.x-mw/2+ow*qx, this.z-mh/2+oh*qy,
					0xFFFFFFFF)
				client.img_blit(img_overview_grid, w - mw, 0,
					mw, mh,
					this.x-mw/2+ow*qx, this.z-mh/2+oh*qy,
					0x80FFFFFF)
				client.img_blit(img_overview_icons, w - mw, 0,
					mw, mh,
					this.x-mw/2+ow*qx, this.z-mh/2+oh*qy,
					0xFFFFFFFF)
			end
			end
			
			local s = "Location: "
				..string.char(65+math.floor(this.x/64))
				..(1+math.floor(this.z/64))
			gui_print_mini(w - mw/2 - 3*#s, mh + 2, 0xFFFFFFFF, s)
		end
		client.img_blit(img_cpal, 0, h-64)
		client.img_blit(img_cpal_rect,
			0 + this.blk_color_x*8,
			h-64 + this.blk_color_y*8)
		
		local coffs_killfeed = (#chat_killfeed-chat_killfeed.head)
		local coffs_text = (#chat_text-chat_text.head)
		
		chat_draw(chat_killfeed, (function (i,s,w,h)
			return w-4-6*#s, h-90-(coffs_killfeed-i)*8
		end))
		chat_draw(chat_text, (function (i,s,w,h)
			return 4, h-90-(coffs_text-i)*8
		end))
		
		if typing_type then
			local s = typing_type..typing_msg.."_"
			gui_print_mini(4, h-80, 0xFFFFFFFF, s)
		end
	end
	
	return this
end

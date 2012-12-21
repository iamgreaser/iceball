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
	this.pid = settings.pid or error("pid must be set when creating player!")
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
	
	this.score = 0
	this.kills = 0
	this.deaths = 0

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

	function this.recolor_team()
		local c = teams[this.team].color_mdl
		local r,g,b
		r,g,b = c[1],c[2],c[3]
		prv_recolor_team(r,g,b)
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

	function this.block_recolor()
		prv_recolor_block(this.blk_color[1],this.blk_color[2],this.blk_color[3])
	end

	function this.input_reset()
		this.ev_forward = false
		this.ev_back = false
		this.ev_left = false
		this.ev_right = false

		this.ev_jump = false
		this.ev_crouch = false
		this.ev_sneak = false
		
		this.ev_lmb = false
		this.ev_rmb = false
	end

	this.input_reset()

	function this.free()
		if this.mdl_block then common.model_free(this.mdl_block) end
		if this.mdl_player then common.model_free(this.mdl_player) end
	end

	this.t_rcirc = nil

	function this.prespawn()
		this.alive = false
		this.spawned = false
		
		this.grounded = false
		this.crouching = false
		
		this.arm_rest_right = 0.0
		this.arm_rest_left = 1.0
		
		this.t_respawn = nil
		this.t_switch = nil
		this.t_nadeboom = nil
		this.t_newnade = nil
		this.t_newblock = nil
		this.t_newspade1 = nil
		this.t_newspade2 = nil
		
		this.dangx, this.dangy = 0, 0
		this.vx, this.vy, this.vz = 0, 0, 0
		
		this.blx1, this.bly1, this.blz1 = nil, nil, nil
		this.blx2, this.bly2, this.blz2 = nil, nil, nil
		
		this.blk_color = {0x7F,0x7F,0x7F}
		this.block_recolor()
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

	local function prv_spawn_cont1()
		this.prespawn()

		this.alive = true
		this.spawned = true
		this.t_switch = true
	end

	function this.spawn_at(x,y,z,ya,xa)
		this.x = x
		this.y = y
		this.z = z
		this.angy = ya
		this.angx = xa

		return prv_spawn_cont1()
	end

	function this.spawn()
		local xlen,ylen,zlen
		xlen,ylen,zlen = common.map_get_dims()

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

		return prv_spawn_cont1()
	end

	this.name = settings.name or "Noob"
	if server then
		this.spawn()
	else
		this.prespawn()
	end

	function this.tool_switch(tool)
		if not this.alive then return end

		if this.tool == TOOL_GUN then
			if this.wpn then
				this.wpn.firing = false
				this.wpn.reloading = false
			end
			this.zooming = false
			this.arm_rest_right = 0
		end
		this.t_switch = true
		if client and this == players[players.current] and this.tool ~= tool then
			common.net_send(nil, common.net_pack("BBB"
				, 0x17, 0x00, tool))
		end
		this.tool = tool
		this.ev_lmb = false
		this.ev_rmb = false
		
		-- hud
		if this.tools_align then
			this.tools_align.visible = true
			this.tools_align.static_alarm{name='viz',
				time=3.0, on_trigger=function() this.tools_align.visible = false end}
		end
		
	end

	function this.tool_switch_next()
		new_tool = (this.tool + 1) % (TOOL_NADE + 1) -- Nade is last weapon
		this.tool_switch(new_tool)
	end

	function this.tool_switch_prev()
		new_tool = (this.tool - 1) % (TOOL_NADE + 1) -- Nade is last weapon
		this.tool_switch(new_tool)
	end

	--[[
		keys are:
			0x01: up
			0x02: down
			0x04: left
			0x08: right
			0x10: sneak | scope
			0x20: crouch
			0x40: jump
			0x80: * RESERVED *
	]]

	function this.get_pos()
		return this.x, this.y, this.z
	end

	function this.set_pos_recv(x, y, z)
		this.x = x
		this.y = y
		this.z = z
	end

	function this.get_orient()
		local keys = 0
		if this.ev_forward then keys = keys + 0x01 end
		if this.ev_back then keys = keys + 0x02 end
		if this.ev_left then keys = keys + 0x04 end
		if this.ev_right then keys = keys + 0x08 end
		if this.ev_sneak or this.zooming then keys = keys + 0x10 end
		if this.ev_crouch then keys = keys + 0x20 end
		if this.ev_jump then keys = keys + 0x40 end
		--if this.ev_aimbot then keys = keys + 0x80 end

		return this.angy, this.angx, keys
	end

	function this.set_orient_recv(ya, xa, keys)
		this.angy = ya
		this.angx = xa

		this.ev_forward = bit_and(keys,0x01) ~= 0
		this.ev_back = bit_and(keys,0x02) ~= 0
		this.ev_left = bit_and(keys,0x04) ~= 0
		this.ev_right = bit_and(keys,0x08) ~= 0
		this.ev_sneak = bit_and(keys,0x10) ~= 0
		this.ev_crouch = bit_and(keys,0x20) ~= 0
		this.ev_jump = bit_and(keys,0x40) ~= 0
		--this.ev_aimbot = bit_and(keys,0x80) ~= 0
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
	
	function this.update_score()
		net_broadcast(nil, common.net_pack("BBBBhhhzz",
			0x05, this.pid,
			this.team, this.weapon,
			this.score, this.kills, this.deaths,
			this.name, this.squad))
		sort_players()
	end
	
	function this.tent_restock()
		this.health = 100
		this.blocks = 100
		this.grenades = 4
		if this.wpn then
			this.wpn.ammo_clip = this.wpn.cfg.ammo_clip
			this.wpn.ammo_reserve = this.wpn.cfg.ammo_reserve
		end
		if server then
			net_broadcast(nil, common.net_pack("BB", 0x15, this.pid))
		end
	end

	function this.set_health_damage(amt, kcol, kmsg, enemy)
		this.health = amt
		
		if this.health <= 0 and this.alive then
			if server then
				this.intel_drop()
				this.deaths = this.deaths + 1
				if enemy == nil then
					-- do nothing --
				elseif enemy == this then
					enemy.score = enemy.score + SCORE_SUICIDE
				elseif enemy.team == this.team then
					enemy.score = enemy.score + SCORE_TEAMKILL
				else
					enemy.score = enemy.score + SCORE_KILL
					enemy.kills = enemy.kills + 1
				end
				if enemy ~= nil and enemy ~= this then
					enemy.update_score()
				end
				this.update_score()
				net_broadcast(nil, common.net_pack("BIz", 0x0F, kcol, kmsg))
			end
			--chat_add(chat_killfeed, nil, kmsg, kcol)
			this.health = 0
			this.alive = false
		end
		
		if server then
			net_broadcast(nil, common.net_pack("BBB", 0x14, this.pid, this.health))
		end
	end

	function this.damage(amt, kcol, kmsg, enemy)
		return this.set_health_damage(
			this.health - amt, kcol, kmsg, enemy)
	end

	function this.fall_damage(amt)
		--print("damage",this.name,part,amt)
		local l = teams[this.team].color_chat
		r,g,b = l[1],l[2],l[3]

		local c = argb_split_to_merged(r,g,b)

		local kmsg = this.name.." found a high place"
		this.damage(amt, c, kmsg, this)
	end

	function this.gun_damage(part, amt, enemy)
		--print("damage",this.name,part,amt)

		if not server then
			return
		end

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
		this.damage(amt, c, kmsg, enemy)
	end

	function this.spade_damage(part, amt, enemy)
		--print("damage",this.name,part,amt)

		if not server then
			return
		end

		local midmsg = " spaded "
		if this.team == enemy.team then
			error("THIS SHOULD NEVER HAPPEN WORST PYSPADES BUG EVER")
		end

		local r,g,b
		r,g,b = 0,0,0

		local l = teams[enemy.team].color_chat
		r,g,b = l[1],l[2],l[3]

		local c = argb_split_to_merged(r,g,b)

		local kmsg = enemy.name..midmsg..this.name
		this.damage(amt, c, kmsg, enemy)
	end

	function this.grenade_damage(amt, enemy)
		--print("damage",this.name,part,amt)
		local midmsg = " grenaded "
		if this.team == enemy.team and this ~= enemy then
			error("THIS SHOULD NEVER HAPPEN")
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

		this.damage(amt, c, kmsg, enemy)
	end

	function this.intel_pickup(intel)
		if this.has_intel or intel.team == this.team then
			return false
		end
		
		if server then
			local x,y,z,f
			x,y,z = intel.get_pos()
			intel.visible = false
			f = intel.get_flags()
			net_broadcast(nil, common.net_pack("BHhhhB", 0x12, intel.iid, x,y,z,f))
			net_broadcast(nil, common.net_pack("BHB", 0x16, intel.iid, this.pid))
			local s = "* "..this.name.." has picked up the "..teams[intel.team].name.." intel."
			net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFF800000, s))
			this.has_intel = intel
		end

		return true
	end

	function this.intel_drop()
		if server then
			local intel = this.has_intel
			--print("dropped", intel)
			if not intel then
				return
			end
			
			intel.intel_drop()
			this.has_intel = nil
			
			local s = "* "..this.name.." has dropped the "..teams[intel.team].name.." intel."
			net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFF800000, s))
		end
	end

	function this.intel_capture(sec_current)
		if server then
			local intel = this.has_intel
			if not intel then
				return
			end
			
			intel.intel_capture(sec_current)
			this.has_intel = nil
			
			local s = "* "..this.name.." has captured the "..teams[intel.team].name.." intel."
			net_broadcast(nil, common.net_pack("BIz", 0x0E, 0xFF800000, s))
			net_broadcast_team(this.team, common.net_pack("B", 0x1C))
		end
	end
	
	function this.throw_nade(sec_current)
		local sya = math.sin(this.angy)
		local cya = math.cos(this.angy)
		local sxa = math.sin(this.angx)
		local cxa = math.cos(this.angx)
		local fwx,fwy,fwz
		fwx,fwy,fwz = sya*cxa, sxa, cya*cxa
		
		local n = new_nade({
			x = this.x,
			y = this.y,
			z = this.z,
			vx = fwx*MODE_NADE_SPEED*MODE_NADE_STEP+this.vx*MODE_NADE_STEP,
			vy = fwy*MODE_NADE_SPEED*MODE_NADE_STEP+this.vy*MODE_NADE_STEP,
			vz = fwz*MODE_NADE_SPEED*MODE_NADE_STEP+this.vz*MODE_NADE_STEP,
			fuse = math.max(0, this.t_nadeboom - sec_current)
		})
		nade_add(n)
		common.net_send(nil, common.net_pack("BhhhhhhH",
			0x1B,
			math.floor(n.x*32+0.5),
			math.floor(n.y*32+0.5),
			math.floor(n.z*32+0.5),
			math.floor(n.vx*256+0.5),
			math.floor(n.vy*256+0.5),
			math.floor(n.vz*256+0.5),
			math.floor(n.fuse*100+0.5)))
	end

	function this.tick(sec_current, sec_delta)
		local xlen,ylen,zlen
		xlen,ylen,zlen = common.map_get_dims()

		if this.scene then
			this.scene.pump_listeners(sec_delta, input_events)
		end
		
		if not this.spawned then
			return
		end

		if (not this.alive) and (not this.t_respawn) then
			this.t_respawn = sec_current + MODE_RESPAWN_TIME
			this.input_reset()
		end

		if this.t_respawn then
			if server and this.t_respawn <= sec_current then
				--print("server respawn!")
				this.t_respawn = nil
				this.spawn()
				net_broadcast(nil, common.net_pack("BBfffBB",
					0x10, this.pid,
					this.x, this.y, this.z,
					this.angy*128/math.pi, this.angx*256/math.pi))
			else
				-- any last requests?
			end
		end

		if not this.alive then
			this.input_reset()
		end

		if this.t_switch == true then
			this.t_switch = sec_current + MODE_DELAY_TOOL_CHANGE
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
		
		if this.t_newblock and sec_current >= this.t_newblock then
			this.t_newblock = nil
		end
		
		if this.t_newspade1 and sec_current >= this.t_newspade1 then
			this.t_newspade1 = nil
		end
		
		if this.t_newnade and sec_current >= this.t_newnade then
			this.t_newnade = nil
		end
		
		if this.t_nadeboom then
			if (not this.ev_lmb) or sec_current >= this.t_nadeboom then
				this.throw_nade(sec_current)
				this.t_newnade = sec_current + MODE_DELAY_NADE_THROW
				this.t_nadeboom = nil
				this.ev_lmb = false
			end
		end
		
		if not this.ev_rmb then
			this.t_newspade2 = nil
		end
		
		if this.t_newspade2 and sec_current >= this.t_newspade2 and this.blx2 then
			if this.blx2 >= 0 and this.blx2 < xlen and this.blz2 >= 0 and this.blz2 < zlen then
			if this.bly2-1 <= ylen-3 then
				common.net_send(nil, common.net_pack("BHHH",
					0x0A,
					this.blx2, this.bly2, this.blz2))
			end
			end
			
			this.t_newspade2 = nil
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
		
		if client and this.alive and (not this.t_switch) then
		if this.ev_lmb then
			if this.tool == TOOL_BLOCK and this.blx1 then
				if (not this.t_newblock) and this.blocks > 0 then
				if this.blx1 >= 0 and this.blx1 < xlen and this.blz1 >= 0 and this.blz1 < zlen then
				if this.bly1 <= ylen-3 then
					common.net_send(nil, common.net_pack("BHHHBBBB",
						0x08,
						this.blx1, this.bly1, this.blz1,
						this.blk_color[3],
						this.blk_color[2],
						this.blk_color[1],
						1))
					this.blocks = this.blocks - 1
					this.t_newblock = sec_current + MODE_DELAY_BLOCK_BUILD
					this.t_switch = this.t_newblock
				end
				end
				end
			elseif this.tool == TOOL_SPADE then
				if (not this.t_newspade1) then
				
				-- see if there's anyone we can kill
				local d = this.bld2 or 5 -- NOTE: cannot spade through walls anymore. Sorry guys :/
				local hurt_idx = nil
				local hurt_part = nil
				local hurt_part_idx = 0
				local hurt_dist = d*d
				local i,j
				
				for i=1,players.max do
					local p = players[i]
					if p and p ~= this and p.alive and p.team ~= this.team then
						local dx = p.x-this.x
						local dy = p.y-this.y+0.1
						local dz = p.z-this.z
						
						for j=1,3 do
							local dd = dx*dx+dy*dy+dz*dz
							
							local dotk = dx*fwx+dy*fwy+dz*fwz
							local dot = math.sqrt(dd-dotk*dotk)
							if dot < 0.55 and dd < hurt_dist then
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
						players[hurt_idx].spade_damage(
							hurt_part, 1000, this)
					else
						common.net_send(nil, common.net_pack("BBB"
							, 0x13, hurt_idx, hurt_part_idx))
					end
				elseif this.blx2 then
				if this.blx2 >= 0 and this.blx2 < xlen and this.blz2 >= 0 and this.blz2 < zlen then
				if this.bly2 <= ylen-3 then
					bhealth_damage(this.blx2, this.bly2, this.blz2, MODE_BLOCK_DAMAGE_SPADE)
					this.t_newspade1 = sec_current + MODE_DELAY_SPADE_HIT
				end
				end
				end
				
				end
			elseif this.tool == TOOL_NADE then
				if (not this.t_newnade) and this.grenades > 0 then
					if (not this.t_nadeboom) then
						this.grenades = this.grenades - 1
						this.t_nadeboom = sec_current + MODE_NADE_FUSE
					end
				end
			else
				
			end
		elseif this.ev_rmb then
			if this.tool == TOOL_BLOCK and this.blx3 and this.alive then
				local ct,cr,cg,cb
				ct,cr,cg,cb = map_block_pick(this.blx3, this.bly3, this.blz3)
				if ct ~= nil then
					this.blk_color = {cr,cg,cb}
					common.net_send(nil, common.net_pack("BBBBB",
						0x18, 0x00,
						this.blk_color[1],this.blk_color[2],this.blk_color[3]))
				end
				this.ev_rmb = false
			elseif this.tool == TOOL_SPADE and this.blx2 and this.alive then
				if (not this.t_newspade2) then
					this.t_newspade2 = sec_current
						+ MODE_DELAY_SPADE_DIG
				end
			end
		end
		end
		
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
		if this.ev_jump and this.alive and (MODE_CHEAT_FLY or this.grounded) then
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
		if this.y > ylen-3 then
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
			if MODE_AUTOCLIMB then
				by2 = by2 - 0.01
			end
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
		
		if this.alive and MODE_AUTOCLIMB and not this.crouching then
			by2 = by2 + 1.01
		end
		
		if this.alive and MODE_AUTOCLIMB and not this.crouching then
			local jerky = ty1
			
			local h1a,h1b,h1c,h1d
			local h2a,h2b,h2c,h2d
			local h1,h2,_
			_,h2 = trace_gap(tx1,ty1+1.0,tz1)
			h1a,h2a = trace_gap(tx1-0.39,ty1+1.0,tz1-0.39)
			h1b,h2b = trace_gap(tx1+0.39,ty1+1.0,tz1-0.39)
			h1c,h2c = trace_gap(tx1-0.39,ty1+1.0,tz1+0.39)
			h1d,h2d = trace_gap(tx1+0.39,ty1+1.0,tz1+0.39)
			
			if (not h1a) or (h1b and h1a < h1b) then h1a = h1b end
			if (not h1a) or (h1c and h1a < h1c) then h1a = h1c end
			if (not h1a) or (h1d and h1a < h1d) then h1a = h1d end
			if (not h2a) or (h2b and h2a > h2b) then h2a = h2b end
			if (not h2a) or (h2c and h2a > h2c) then h2a = h2c end
			if (not h2a) or (h2d and h2a > h2d) then h2a = h2d end
			
			h1 = h1a
			h2 = h2a
			
			local dh1 = (h1 and -(h1 - ty1))
			local dh2 = (h2 and  (h2 - ty1))
			
			if dh2 and dh2 < by2 and dh2 > 0 then
				--print("old", ty1, dh2, by2, h1, h2)
				
				if (dh1 and dh1 < -by1) then
					-- crouch
					this.crouching = true
					ty1 = ty1 + 1
				else
					-- climb
					ty1 = h2 - by2
					local jdiff = jerky - ty1
					if math.abs(jdiff) > 0.1 then
						this.jerkoffs = this.jerkoffs + jdiff
					end
				end
				
				--print("new", ty1, this.vy)
				--if this.vy > 0 then this.vy = 0 end
			end
		end

		this.x, this.y, this.z = tx1, ty1, tz1
		
		local fgrounded = not box_is_clear(
			tx1-0.39, ty1+by2, tz1-0.39,
			tx1+0.39, ty1+by2+0.1, tz1+0.39)
		
		--print(fgrounded, tx1,ty1,tz1,by2)
		
		this.grounded = (MODE_AIRJUMP and this.grounded) or fgrounded
		
		if this.alive and this.vy > 0 and fgrounded then
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
			
			this.bld1 = td
			this.bld2 = td
			
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
		if not this.alive then
			-- do nothing --
		elseif this.tool == TOOL_SPADE then
			client.model_render_bone_global(mdl_spade, mdl_spade_bone,
				this.x+mdl_x, this.y+this.jerkoffs+mdl_y, this.z+mdl_z,
				--0.0, -this.angx-math.pi/2*0.90, this.angy, 1)
				0.0, -this.angx, this.angy, 1)
		elseif this.tool == TOOL_BLOCK then
			if this.blocks > 0 then
				client.model_render_bone_global(this.mdl_block, mdl_block_bone,
					this.x+mdl_x, this.y+this.jerkoffs+mdl_y, this.z+mdl_z,
					0.0, -this.angx, this.angy, 1)
			end
		elseif this.tool == TOOL_GUN then
			this.wpn.draw(this.x+mdl_x, this.y+this.jerkoffs+mdl_y, this.z+mdl_z,
				math.pi/2, -this.angx, this.angy)
		elseif this.tool == TOOL_NADE then
			client.model_render_bone_global(mdl_nade, mdl_nade_bone,
				this.x+mdl_x, this.y+this.jerkoffs+mdl_y, this.z+mdl_z,
				0.0, -this.angx, this.angy, 1.0)
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
	
	--[[create static widgets for hud.
		FIXME: share 1 instance across all players? (This makes ticking trickier)
	]]
	function this.create_hud()
		local scene = gui_create_scene(client.screen_get_dims())
		local root = scene.root
		local w = root.width
		local h = root.height
		
		-- tools
		
		this.tools_align = scene.display_object{x=root.l, y=root.t, visible=false}
		local bone_wslot1 = scene.bone{model=mdl_spade, bone=mdl_spade_bone,
			x=0.1*w*5/8}
		local bone_wslot2 = scene.bone{model=this.mdl_block, bone=this.mdl_block_bone,
			x=0.25*w*5/8}
		local bone_wslot3 = scene.bone{model=this.wpn.get_model(), bone=0,
			x=0.4*w*5/8}
		local bone_wslot4 = scene.bone{model=mdl_nade, bone=mdl_nade_bone,
			x=0.55*w*5/8}
		scene.root.add_child(this.tools_align)
		this.tools_align.add_child(bone_wslot1)
		this.tools_align.add_child(bone_wslot2)
		this.tools_align.add_child(bone_wslot3)
		this.tools_align.add_child(bone_wslot4)
		
		local tool_mappings = {TOOL_SPADE,TOOL_BLOCK,TOOL_GUN,TOOL_NADE}
		local tool_y = {0.3,0.25,0.25,0.25}
		local tool_scale = {0.2,0.1,0.2,0.1}
		local tool_pick_scale = {1.3,2.0,2.0,2.0}
		local bounce = 0
		local function bone_rotate(dT)
			for k,bone in pairs(this.tools_align.children) do
				bone.rot_y = bone.rot_y + dT * 120 * 0.01
				bone.y = tool_y[k]
				bone.scale = tool_scale[k]
				if this.tool == tool_mappings[k] then
					bone.y = bone.y + math.sin(bounce * 120 * 0.01) * 0.02
					bone.scale = bone.scale * tool_pick_scale[k]
				end
				bone.y = bone.y * h/2
				bounce = bounce + dT
			end
		end
		this.tools_align.add_listener(GE_DELTA_TIME, bone_rotate)
		
		bone_rotate(0)
		
		this.quit_msg = scene.textfield{wordwrap=false, color=0xFFFF3232, font=font_large, 
			text="Are you sure? (Y/N)", x = w/2, y = h/4, align_x = 0.5, align_y = 0.5,
			visible=false}
		scene.root.add_child(this.quit_msg)
		
		--TODO: update bluetext/greentext with the actual keys (if changed in controls.json)
		this.team_change_msg_b = scene.textfield{wordwrap=false, color=0xFF0000FF, font=font_large, 
			text="Press 1 to join Blue", x = w/2, y = h/4, align_x = 0.5, align_y = 0.5,
			visible=false}
		this.team_change_msg_g = scene.textfield{wordwrap=false, color=0xFF00FF00, font=font_large, 
			text="Press 2 to join Green", x = w/2, y = h/4 + 40, align_x = 0.5, align_y = 0.5,
			visible=false}
		scene.root.add_child(this.team_change_msg_b)
		scene.root.add_child(this.team_change_msg_g)
		
		local function update_viz(dT)
			this.team_change_msg_b.visible = team_change
			this.team_change_msg_g.visible = team_change
		end
		local function can_quit(options)
			if this.quit_msg.visible and options.state then
				if options.key == BTSK_YES then
					-- TODO: clean up
					client.hook_tick = nil
				elseif options.key == BTSK_NO then
					this.quit_msg.visible = false
				end
			elseif options.key == BTSK_QUIT then
				this.quit_msg.visible = true
			end
		end
		this.quit_msg.add_listener(GE_DELTA_TIME, update_viz)
		this.quit_msg.add_listener(GE_BUTTON, can_quit)
		
		this.scene = scene
	end

	function this.show_hud()
		local fogr,fogg,fogb,fogd = client.map_fog_get()

		local ays,ayc,axs,axc
		ays = math.sin(this.angy)
		ayc = math.cos(this.angy)
		axs = math.sin(this.angx)
		axc = math.cos(this.angx)

		--font_mini.print(64,8,0xFFFFFFFF,mouse_prettyprint())
		
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
		
		if not this.scene then
			this.create_hud()
		end
		this.scene.draw()
		
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

						font_mini.print(px-(6*#s_name)/2,py-7
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

		font_digits.print((w-32*#hstr)/2, h-48, hcolor, hstr)
		if this.tool == TOOL_GUN then
			font_digits.print(-16+w-32*#astr, h-48, acolor, astr)
		elseif this.tool == TOOL_NADE then
			font_digits.print(-16+w-32*#gstr, h-48, gcolor, gstr)
		else
			font_digits.print(-16+w-32*#bstr, h-48, bcolor+0xFF000000, bstr)
		end
		local i

		if debug_enabled then
			local camx,camy,camz
			camx,camy,camz = client.camera_get_pos()
			local cam_pos_str = string.format("x: %f y: %f z: %f j: %f c: %i"
				, camx, camy, camz, this.jerkoffs, (this.crouching and 1) or 0)

			font_mini.print(4, 4, 0x80FFFFFF, cam_pos_str)
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
					for i=0,10-1 do
						local d=i/math.sqrt(2)
						local u,v
						u = math.floor(x)+math.floor(d*math.sin(plr.angy))
						v = math.floor(y)+math.floor(d*math.cos(plr.angy))
						log_mspr[#log_mspr+1] = u
						log_mspr[#log_mspr+1] = v
						common.img_pixel_set(img_overview_icons, u, v, c)
					end
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

			for i=1,math.floor(oh/64+0.5) do
				font_mini.print(mx - 12, my + (i-0.5)*64,
					0xFFFFFFFF, ""..i)
				font_mini.print(mx + ow + 12-6, my + (i-0.5)*64,
					0xFFFFFFFF, ""..i)
			end

			for i=1,math.floor(ow/64+0.5) do
				font_mini.print(mx + (i-0.5)*64, my - 12,
					0xFFFFFFFF, ""..string.char(64+i))
				font_mini.print(mx + (i-0.5)*64, my + oh + 12-6,
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
			font_mini.print(w - mw/2 - 3*#s, mh + 2, 0xFFFFFFFF, s)
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
			font_mini.print(4, h-80, 0xFFFFFFFF, s)
		end

		if show_scores then
			local bi, gi
			bi = 1
			gi = 1
			for i=1,players.max do
				local plr = players_sorted[i]
				if plr ~= nil then
					local sn = plr.name
					if plr.squad then
						sn = sn.." ["..plr.squad.."]"
					end
					local s = sn.." #"..i..": "
						..plr.score.." ("..plr.kills.."/"..plr.deaths..")"
					if plr.team == 1 then
						font_mini.print(w / 2 + 50, gi * 15 + 150
							, argb_split_to_merged(150, 255, 150, 255)
							, s)
						gi = gi + 1
					else
						font_mini.print(w / 2 - 50 - (6 * #s), bi * 15 + 150
							, argb_split_to_merged(150, 150, 255, 255)
							, s)
						bi = bi + 1
					end
				end
 			end
 		end

	end

	return this
end

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

PLM_NORMAL = 1
PLM_SPECTATE = 2
PLM_BUILD = 3

if client then
	if not img_fsrect then
		img_fsrect = client.img_new(client.screen_get_dims())
		client.img_fill(img_fsrect, 0xFFFF0000)
	end

	mdl_player_head = model_load({
		kv6={bdir=DIR_PKG_KV6, name="playerhead.kv6", scale=10.0/256.0},
		pmf={bdir=DIR_PKG_PMF, name="player.pmf", bone=0},
	}, {"kv6","pmf"})
	mdl_player_body = model_load({
		kv6={bdir=DIR_PKG_KV6, name="playerbody.kv6", scale=7.0/256.0},
		pmf={bdir=DIR_PKG_PMF, name="player.pmf", bone=1},
	}, {"kv6","pmf"})
	mdl_player_arm = model_load({
		kv6={bdir=DIR_PKG_KV6, name="playerarm.kv6", scale=6.0/256.0},
		pmf={bdir=DIR_PKG_PMF, name="player.pmf", bone=2},
	}, {"kv6","pmf"})
	mdl_player_leg = model_load({
		kv6={bdir=DIR_PKG_KV6, name="playerleg.kv6", scale=5.0/256.0},
		pmf={bdir=DIR_PKG_PMF, name="player.pmf", bone=3},
	}, {"kv6","pmf"})

	mdl_player_head_outline = mdl_player_head {inscale=6.0}
	mdl_player_body_outline = mdl_player_body {inscale=6.0}
	mdl_player_arm_outline = mdl_player_arm {inscale=6.0}
	mdl_player_leg_outline = mdl_player_leg {inscale=6.0}
end

function new_player(settings)
	local this = {} this.this = this this.this.this = this this = this.this

	this.team = settings.team or math.floor(math.random()*2)
	this.squad = settings.squad or nil
	this.weapon = settings.weapon or WPN_RIFLE
	this.explosive = settings.explosive or EXPL_GRENADE

	-- TODO: move this to a function
	this.wpn_list = settings.wpn_list or nil
	if this.wpn_list == nil then
		this.wpn_list = {}
		local k,v
		for k,v in pairs(weapons_enabled) do
			if v then
				this.wpn_list[#this.wpn_list+1] = k
			end
		end
	end

	this.recoil_amt = 0

	this.pid = settings.pid or error("pid must be set when creating player!")
	this.neth = settings.neth
	this.alive = false
	this.spawned = false
	this.zooming = false
	this.inwater = false
	this.mode = settings.mode or PLM_NORMAL
	this.spectateindex = 0
	this.spectateplr = this

	function teamfilt(tr, tg, tb)
		return (function (r,g,b)
			if r == 0 and g == 0 and b == 0 then
				return tr, tg, tb
			else
				return r, g, b
			end
		end)
	end

	this.score = 0
	this.kills = 0
	this.deaths = 0

	this.dead_x = nil
	this.dead_y = nil
	this.dead_z = nil

	this.permissions = {}

	function this.has_permission(perm)
		return perm == nil or this.permissions[perm] ~= nil
	end

	function this.add_permission(perm)
		this.permissions[perm] = true
	end

	function this.remove_permission(perm)
		this.permissions[perm] = nil
	end

	function this.add_permission_group(perms)
		for k,v in pairs(perms) do
			this.add_permission(k)
		end
	end

	function this.remove_permission_group(perms)
		for k,v in pairs(perms) do
			this.remove_permission(k)
		end
	end

	function this.clear_permissions(perms)
		this.permissions = {}
	end

	local function prv_recolor_team(r,g,b)
		if not client then return end
		local mname,mdata
		local f = teamfilt(r,g,b)
		this.mdl_player_head = mdl_player_head {filt=f}
		this.mdl_player_body = mdl_player_body {filt=f}
		this.mdl_player_arm = mdl_player_arm {filt=f}
		this.mdl_player_leg = mdl_player_leg {filt=f}
	end

	function this.recolor_team()
		local c = teams[this.team].color_mdl
		local r,g,b
		r,g,b = c[1],c[2],c[3]
		prv_recolor_team(r,g,b)
	end

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

		this.ev_lmb = false
		this.ev_rmb = false
	end

	this.input_reset()

	function this.free()
		if this.mdl_player then common.model_free(this.mdl_player) end
	end

	this.t_rcirc = nil

	function this.prespawn()
		this.alive = false
		this.spawned = false

		this.grounded = false
		this.crouching = false
		this.spectateindex = 0
		this.spectateplr = this

		this.arm_rest_right = 0.0
		this.arm_rest_left = 1.0

		this.t_respawn = nil
		this.t_switch = nil
		this.t_newblock = nil
		this.t_newspade1 = nil
		this.t_newspade2 = nil
		this.t_step = nil
		this.t_piano = nil
		this.t_piano2 = nil

		this.dangx, this.dangy = 0, 0
		this.angx, this.angy = 0, 0
		this.vx, this.vy, this.vz = 0, 0, 0

		this.blx1, this.bly1, this.blz1 = nil, nil, nil
		this.blx2, this.bly2, this.blz2 = nil, nil, nil

		this.sx, this.sy, this.sz = 0, -1, 0
		this.drunkx, this.drunkz = 0, 0
		this.drunkfx, this.drunkfz = 0, 0

		this.blk_color = {0x7F,0x7F,0x7F}
		this.blk_color_changed = true
		this.blk_color_x = 3
		this.blk_color_y = 0

		this.jerkoffs = 0.0

		this.zoom = 1.0
		this.zooming = false

		this.health = 100
		this.blocks = MODE_BLOCKS_SPAWN

		function this.expl_ammo_checkthrow() return false end

		this.add_tools()

		this.ev_forward = this.key_forward
		this.ev_back = this.key_back
		this.ev_left = this.key_left
		this.ev_right = this.key_right
		this.ev_crouch = this.key_crouch
		this.ev_jump = this.key_jump
		this.ev_sneak = this.key_sneak
	end

	function this.add_tools()
		local i
		if this.tools then
			for i=1,#this.tools do
				this.tools[i].free()
			end
		end
		this.tools = {}
		this.add_tools_list()

		-- TODO: clean up scene properly
		this.scene = nil
	end

	function this.add_tools_list()
		this.tools[#(this.tools)+1] = tools[TOOL_SPADE](this)
		this.tools[#(this.tools)+1] = tools[TOOL_BLOCK](this)
		if MODE_ALLGUNS then
			local i
			for i=1,#weapons do
				if weapons_enabled[i] then
					this.tools[#(this.tools)+1] = weapons[i](this)
				end
			end
		else
			this.tools[#(this.tools)+1] = weapons[this.weapon](this)
		end
		this.tools[#(this.tools)+1] = explosives[this.explosive](this)

		if this.mode == PLM_BUILD then
			this.tools[#(this.tools)+1] = tools[TOOL_MARKER](this)
		end

		this.tool = 2
		this.tool_last = 0
	end

	function this.block_recolor()
		this.blk_color_changed = true
	end

	local function prv_spawn_cont1()
		this.prespawn()

		this.alive = true
		this.spawned = true
		this.t_switch = true
	end

	function this.spawn_at(x,y,z,ya,xa)
		prv_spawn_cont1()

		this.x = x
		this.y = y
		this.z = z
		this.angy = ya
		this.angx = xa
	end

	function this.spawn()
		local xlen,ylen,zlen
		xlen,ylen,zlen = common.map_get_dims()

		prv_spawn_cont1()

		while true do
			this.x = math.floor(math.random()*xlen/4.0)+0.5
			this.z = math.floor((math.random()/2.0+0.25)*zlen)+0.5
			if this.team == 1 then this.x = xlen - this.x end
			this.y = (common.map_pillar_get(this.x, this.z))[1+1]
			if this.y < ylen-1 then break end
		end
		this.y = this.y - 3.0
		this.angy, this.angx = math.pi/2.0, 0.0
		if this.team == 1 then this.angy = this.angy-math.pi end
	end

	this.name = settings.name or "Noob"
	if server then
		this.spawn()
	else
		this.prespawn()
	end

	function this.item_add(item)
		-- override me!
	end

	function this.item_remove(item)
		-- override me!
	end

	function this.tool_switch(tool)
		if not this.alive then return end
		if this.mode == PLM_SPECTATE then return end
		if tool == this.tool then return end
		if not this.tools[tool+1] then return end

		this.tool_last = this.tool

		this.tools[this.tool+1].unfocus()
		this.tools[tool+1].focus()

		this.t_switch = true
		if client and this == players[players.current] and this.tool ~= tool then
			net_send(nil, common.net_pack("BBB"
				, PKT_PLR_TOOL, 0x00, tool))
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
		new_tool = (this.tool + 1) % #this.tools
		this.tool_switch(new_tool)
	end

	function this.tool_switch_prev()
		new_tool = (this.tool - 1) % #this.tools
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

	function this.get_vel()
		return this.vx, this.vy, this.vz
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
		this.recoil_time = sec_current
	end

	function this.update_score()
		net_broadcast(nil, common.net_pack("BBBBBhhhzz",
			PKT_PLR_ADD, this.pid,
			this.team, this.weapon, this.mode,
			this.score, this.kills, this.deaths,
			this.name, this.squad))
	end

	function this.set_blocks(blocks)
		local oblocks = this.blocks
		this.blocks = blocks

		if not server then return end

		if (blocks == 0) ~= (oblocks == 0) then
			net_broadcast(nil, common.net_pack("BBH",
				PKT_PLR_BLK_COUNT, this.pid, this.blocks))
		else
			net_send(this.neth, common.net_pack("BBH",
				PKT_PLR_BLK_COUNT, this.pid, this.blocks))
		end
	end

	function this.tent_restock()
		this.health = 100
		local i
		for i=1,#this.tools do
			this.tools[i].restock()
		end
		if server then
			net_broadcast(nil, common.net_pack("BB", PKT_PLR_RESTOCK, this.pid))
		end
	end

	local function blood_particles()
		local i
		local blood_particlecount = math.random() * 10 + 20
		local pvel = 0.5
		blood_part_mdl = blood_part_mdl or new_particle_model(230, 70, 70)
		local mdl = blood_part_mdl
		--[[
		local mdl = new_particle_model(
			200 + math.random() * 55,
			60 + math.random() * 20,
			60 + math.random() * 20)
		]]

		for i=1,blood_particlecount do
			particles_add(new_particle{
				x = this.x,
				y = this.y,
				z = this.z,
				vx = pvel*(2*math.random()-1),
				vy = pvel*(2*math.random()-1.8),
				vz = pvel*(2*math.random()-1),
				model = mdl,
				size = 8 + math.random() * 16,
				lifetime = 1
			})
		end
	end

	function this.on_disconnect()
		-- override me!
	end

	function this.on_death(kcol, kmsg)
		-- override me!
	end

	function this.set_health_damage(amt, kcol, kmsg, enemy)
		local oldhealth = this.health
		this.health = math.max(amt, 0)
		local hdelta = this.health - oldhealth

		if this.health <= 0 and this.alive then
			this.on_death()
			if server then
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
				net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_KILLFEED, kcol, kmsg))
			end
			--chat_add(chat_killfeed, nil, kmsg, kcol)
			this.health = 0
			this.alive = false
			this.dead_x = this.x
			this.dead_y = this.y
			this.dead_z = this.z
		end

		if server then
			net_broadcast(nil, common.net_pack("BBB", PKT_PLR_DAMAGE, this.pid, this.health))
		end

		if client then
			if hdelta < 0 then
				local arr = wav_ouches
				if this.health <= 0 then arr = wav_splats end
				client.wav_play_global(arr[
					math.floor(math.random()*#arr)+1],
						this.x, this.y, this.z,
						1.0, 1.0)
			end
			blood_particles()	
		end
	end

	function this.damage(amt, kcol, kmsg, enemy)
		if this.mode ~= PLM_NORMAL then
			return nil
		end

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

	function this.wpn_damage(part, amt, enemy, dmsg)
		--print("damage",this.name,part,amt)

		if not server then
			return
		end

		local midmsg = " "..dmsg.." "
		if this.team == enemy.team then
			midmsg = " teamkilled "
			if not this.has_permission("teamkill") then
				return
			end
		end

		local r,g,b
		r,g,b = 0,0,0

		local l = teams[enemy.team].color_chat
		r,g,b = l[1],l[2],l[3]

		local c = argb_split_to_merged(r,g,b)

		local kmsg = enemy.name..midmsg..this.name
		this.damage(amt, c, kmsg, enemy)
	end

	function this.explosive_damage(amt, enemy)
		if enemy.mode ~= PLM_NORMAL then
			return nil
		end
		--print("damage",this.name,part,amt)
		local midmsg = " exploded "
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

	function this.tick_listeners(sec_current, sec_delta)
		if this.scene then
			this.scene.pump_listeners(sec_delta, input_events)
		end	
	end

	function this.tick_respawn(sec_current, sec_delta)
		if (not this.alive) and (not this.t_respawn) then
			this.t_respawn = sec_current + MODE_RESPAWN_TIME
			this.input_reset()
		end

		if this.t_respawn then
			if server and this.t_respawn <= sec_current then
				--print("server respawn!")
				this.t_respawn = nil
				this.spawn()
				net_broadcast(nil, common.net_pack("BBfffbb",
					PKT_PLR_SPAWN, this.pid,
					this.x, this.y, this.z,
					this.angy*128/math.pi, this.angx*256/math.pi))
			else
				-- any last requests?
			end
		end

		if not this.alive then
			this.input_reset()
		end

		if client and this.respawn_msg then
			if this.alive then
				this.respawn_msg.visible = false
			else
				this.respawn_msg.visible = true
				this.respawn_msg.text = "Respawning in " .. math.max(0, math.ceil(this.t_respawn - sec_current))
			end
		end
	end

	function this.tick_rotate(sec_current, sec_delta)
		-- calc X delta angle
		local nax = this.angx + this.dangx
		if nax > math.pi*0.49 then
			nax = math.pi*0.49
		elseif nax < -math.pi*0.49 then
			nax = -math.pi*0.49
		end
		this.dangx = (nax - this.angx)

		-- apply delta angles
		if (this.mode == PLM_SPECTATE or MODE_DRUNKCAM_LOCALTURN) and this.dangy ~= 0 then
			this.angx = this.angx + this.dangx

			local fx,fy,fz -- forward
			local sx,sy,sz -- sky
			local ax,ay,az -- horiz side
			local bx,by,bz -- vert side

			local sya = math.sin(this.angy)
			local cya = math.cos(this.angy)
			local sxa = math.sin(this.angx)
			local cxa = math.cos(this.angx)

			-- get vectors
			fx,fy,fz = vnorm(sya*cxa, sxa, cya*cxa)
			sx,sy,sz = vnorm(this.sx, this.sy, this.sz)
			ax,ay,az = vnorm(vcross(fx,fy,fz,sx,sy,sz))
			bx,by,bz = vnorm(vcross(fx,fy,fz,ax,ay,az))


			-- rotate forward and sky

			fx,fy,fz = vrotate(this.dangy,fx,fy,fz,bx,by,bz)
			sx,sy,sz = vrotate(this.dangy,sx,sy,sz,bx,by,bz)

			-- normalise F and S
			fx,fy,fz = vnorm(fx,fy,fz)
			sx,sy,sz = vnorm(sx,sy,sz)

			-- stash sky arrow
			this.sx = sx
			this.sy = sy
			this.sz = sz

			-- convert forward from vector to polar
			this.angx = math.asin(fy)
			local langx = this.angx

			if math.cos(langx) <= 0.0 then
				fx = -fx
				fz = -fz
			end

			this.angy = math.atan2(fx,fz)

			--print("polar",this.angx, this.angy)

		else
			this.angx = this.angx + this.dangx
			this.angy = this.angy + this.dangy
		end
		this.dangx = 0
		this.dangy = 0
	end

	function this.calc_motion_local(sec_current, sec_delta)
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

		if this.mode == PLM_NORMAL then
			if this.ev_crouch then
				if this.grounded and not this.crouching then
					if MODE_SOFTCROUCH then this.jerkoffs = this.jerkoffs - 1 end
					this.y = this.y + 1
				end
				this.crouching = true
			end
			if this.ev_jump and this.alive and (MODE_CHEAT_FLY or this.grounded) then
				this.vy = -MODE_JUMP_SPEED

				if not MODE_JUMP_POGO then
					this.ev_jump = false
				end

				if client then
					client.wav_play_global(wav_jump_up, this.x, this.y, this.z)
				end
			end
		else
			if this.ev_crouch then
				mvy = mvy + 1.0
			end
			if this.ev_jump then
				mvy = mvy - 1.0
			end
		end

		-- normalise mvx,mvy,mvz
		local mvd = math.max(0.00001,math.sqrt(mvx*mvx + mvy*mvy + mvz*mvz))
		mvx = mvx / mvd
		mvy = mvy / mvd
		mvz = mvz / mvd

		-- apply base slowdown
		local mvspd = MODE_PSPEED_NORMAL
		local mvchange = MODE_PSPEED_CHANGE
		if this.mode ~= PLM_NORMAL then mvspd = MODE_PSPEED_FLYMODE end
		mvx = mvx * mvspd
		mvy = mvy * mvspd
		mvz = mvz * mvspd

		-- apply extra slowdowns
		if this.mode == PLM_NORMAL then
			if not this.grounded then
				mvx = mvx * MODE_PSPEED_AIRSLOW
				mvz = mvz * MODE_PSPEED_AIRSLOW
				mvchange = mvchange * MODE_PSPEED_AIRSLOW_CHANGE
			end
			if this.inwater then
				mvx = mvx * MODE_PSPEED_WATER
				mvz = mvz * MODE_PSPEED_WATER
			end
			if this.crouching then
				mvx = mvx * MODE_PSPEED_CROUCH
				mvz = mvz * MODE_PSPEED_CROUCH
			end
			if this.zooming or this.ev_sneak then
				mvx = mvx * MODE_PSPEED_SNEAK
				mvz = mvz * MODE_PSPEED_SNEAK
			end
		end

		return mvx, mvy, mvz, mvchange
	end

	function this.calc_motion_global(sec_current, sec_delta, mvx, mvy, mvz, mvchange)
		if MODE_PSPEED_CONV_PHYSICS and this.mode == PLM_NORMAL then
			local alt_a = math.exp(-sec_delta*mvchange*MODE_PSPEED_CONV_BRAKES)
			local mmul = sec_delta*MODE_PSPEED_CONV_ACCEL
			if not this.grounded then alt_a = 1.0 end

			mvx = mvx * mmul
			mvz = mvz * mmul

			local md = 1.0/math.max(0.0001, math.sqrt(mvx*mvx + mvz*mvz))
			local dx = mvx*md
			local dz = mvz*md

			local dotspd = this.vx*dx + this.vz*dz
			--if client then print(dotspd, math.sqrt(this.vx*this.vx + this.vz*this.vz)) end
			if (not MODE_PSPEED_CONV_SPEEDCAP_ON) or dotspd < MODE_PSPEED_CONV_SPEEDCAP then
				this.vx = this.vx + mvx
				this.vz = this.vz + mvz
			end
			this.vx = this.vx * alt_a
			this.vz = this.vz * alt_a

			if this.mode == PLM_NORMAL then
				this.vy = (this.vy + 2.0*MODE_GRAVITY*sec_delta) * alt_a
			else
				this.vy = (this.vy + mvy*mmul) * alt_a
			end
		else
			this.vx = this.vx + (mvx - this.vx)*(1.0-math.exp(-sec_delta*mvchange))
			this.vz = this.vz + (mvz - this.vz)*(1.0-math.exp(-sec_delta*mvchange))
			if this.mode == PLM_NORMAL then
				this.vy = this.vy + 2*MODE_GRAVITY*sec_delta
			else
				this.vy = this.vy + (mvy - this.vy)*(1.0-math.exp(-sec_delta*mvchange))
			end
		end
		this.jerkoffs = this.jerkoffs * math.exp(-sec_delta*15.0)
	end

	function this.calc_motion_trace(sec_current, sec_delta, ox, oy, oz, nx, ny, nz)
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

			-- Inhibit movement into a wall
			local cox = math.floor(ox)
			local coz = math.floor(oz)
			local cnxp = math.floor(tx1 + 0.39 + 0.0012)
			local cnzp = math.floor(tz1 + 0.39 + 0.0012)
			local cnxn = math.floor(tx1 - 0.39 - 0.0012)
			local cnzn = math.floor(tz1 - 0.39 - 0.0012)

			if box_is_clear(cox+0.1, ty1+by1+1.0, coz+0.1, cox+0.9, ty1+by2, coz+0.9) then
				if nx > ox and not box_is_clear(cnxp+0.1, ty1+by1+1.0, coz+0.1, cnxp+0.9, ty1+by2, coz+0.9) then
					tx1 = cnxp - 0.39 - 0.001
				end
				if nx < ox and not box_is_clear(cnxn+0.1, ty1+by1+1.0, coz+0.1, cnxn+0.9, ty1+by2, coz+0.9) then
					tx1 = cnxn + 0.39 + 0.001
				end
				if nz > oz and not box_is_clear(cox+0.1, ty1+by1+1.0, cnzp+0.1, cox+0.9, ty1+by2, cnzp+0.9) then
					tz1 = cnzp - 0.39 - 0.001
				end
				if nz < oz and not box_is_clear(cox+0.1, ty1+by1+1.0, cnzn+0.1, cox+0.9, ty1+by2, cnzn+0.9) then
					tz1 = cnzp + 0.39 + 0.001
				end
			end
			
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
						this.vx = this.vx * 0.02
						this.vz = this.vz * 0.02
					end
				end

				--print("new", ty1, this.vy)
				--if this.vy > 0 then this.vy = 0 end
			end
		end

		if MODE_DRUNKCAM_VELOCITY then
			local xdiff = tx1-ox
			local zdiff = tz1-oz
			local dfac = math.sqrt(1.0-fwy*fwy) * 2.0
			xdiff = xdiff * dfac
			zdiff = zdiff * dfac
			this.drunkfx = this.drunkfx + (xdiff - this.drunkfx)*(1.0-math.exp(-5.0*sec_delta))
			this.drunkfz = this.drunkfz + (zdiff - this.drunkfz)*(1.0-math.exp(-5.0*sec_delta))
			xdiff = this.drunkfx
			zdiff = this.drunkfz
			this.sx = this.sx - (xdiff-this.drunkx)*20.0*sec_delta
			this.sz = this.sz - (zdiff-this.drunkz)*20.0*sec_delta
			this.drunkx = this.drunkx + (xdiff - this.drunkx)*(1.0-math.exp(-10.0*sec_delta))
			this.drunkz = this.drunkz + (zdiff - this.drunkz)*(1.0-math.exp(-10.0*sec_delta))
		end

		local fgrounded = not box_is_clear(
			tx1-0.39, ty1+by2, tz1-0.39,
			tx1+0.39, ty1+by2+0.1, tz1+0.39)

		--print(fgrounded, tx1,ty1,tz1,by2)

		local wasgrounded = this.grounded
		this.grounded = (MODE_AIRJUMP and this.grounded) or fgrounded

		if this.alive and this.vy > 0 and fgrounded then
			this.vy = 0
			if client and not wasgrounded then
				client.wav_play_global(wav_jump_down, this.x, this.y, this.z)
			end
		end

		-- fix sinking when no autoclimb
		if this.alive then
			local _,h2 = trace_gap(tx1,ty1,tz1)
			if ty1+by2+0.05 > h2 and ty1+by2+0.05 < h2+0.8 then
				ty1 = h2-by2-0.05
			end
		end

		return tx1, ty1, tz1
	end

	function this.tick(sec_current, sec_delta)
		local xlen,ylen,zlen
		xlen,ylen,zlen = common.map_get_dims()

		if not this.spawned then
			return
		end

		this.tick_respawn(sec_current, sec_delta)

		this.inwater = (this.y > ylen-3)

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

		if client then
			local moving = ((this.ev_left == not this.ev_right) or (this.ev_forward == not this.ev_back))
			local sneaking = (this.ev_crouch or this.ev_sneak or this.zooming)

			if moving and not sneaking then
				if not this.t_step then
					this.t_step = sec_current + 0.5
				end
				if this.t_step < sec_current then
					local stepsound, soundselect
					if this.inwater then
						soundselect = math.floor(math.random()*#wav_water_steps)+1
						stepsound = wav_water_steps[soundselect]
					else
						soundselect = math.floor(math.random()*#wav_steps)+1
						stepsound = wav_steps[soundselect]
					end
					local tdiff = 0.01
					if this.grounded then
						client.wav_play_global(stepsound,
								this.x, this.y, this.z,
								1.0, 1.0)
						tdiff = 0.5
					end
					this.t_step = this.t_step + tdiff
					if this.t_step < sec_current then
						this.t_step = sec_current + tdiff
					end
				end
			else
				this.t_step = nil
			end
		end

		this.tick_rotate(sec_current, sec_delta)

		if this.zooming then
			this.zoom = 3.0
		else
			this.zoom = 1.0
		end

		-- possibly drop a piano
		if this.t_piano then
			if this.t_piano == true then
				this.t_piano = sec_current + 0.5
			end

			this.t_piano_delta = this.t_piano - sec_current
			if this.t_piano and this.t_piano < sec_current then
				this.t_piano = nil
				if server then
					local l = teams[this.team].color_chat
					local r,g,b
					r,g,b = l[1], l[2], l[3]
					local c = argb_split_to_merged(r,g,b)
					this.set_health_damage(0, c, this.name.." displeased the gods", this)
				end
				if client then
					client.wav_play_global(wav_kapiano, this.x, this.y, this.z, 3.0)
					this.t_piano2 = sec_current + 5
				end
			end
		end

		if this.t_piano2 then
			this.t_piano2_delta = this.t_piano2 - sec_current
			if this.t_piano2 < sec_current then
				this.t_piano2 = nil
			end
		end

		-- set camera direction
		local sya = math.sin(this.angy)
		local cya = math.cos(this.angy)
		local sxa = math.sin(this.angx)
		local cxa = math.cos(this.angx)
		local fwx,fwy,fwz
		fwx,fwy,fwz = sya*cxa, sxa, cya*cxa

		if client and this.alive and (not this.t_switch) then
			if this.recoil_time then
				this.recoil_amt = (sec_current - this.recoil_time) * math.pow(2, 1 - 10 * (sec_current - this.recoil_time)) * 1.5
			else
				this.recoil_amt = 0
			end
		end

		-- apply local motion
		local mvx, mvy, mvz, mvchange = this.calc_motion_local(sec_current, sec_delta)

		-- apply rotation
		mvx, mvz = mvx*cya+mvz*sya, mvz*cya-mvx*sya

		-- apply global motion
		this.calc_motion_global(sec_current, sec_delta, mvx, mvy, mvz, mvchange)

		-- trace to next position
		local ox, oy, oz
		local nx, ny, nz
		local tx1,ty1,tz1
		ox, oy, oz = this.x, this.y, this.z
		nx, ny, nz = this.x + this.vx*sec_delta, this.y + this.vy*sec_delta, this.z + this.vz*sec_delta
		local wasgrounded = this.grounded
		tx1, ty1, tz1 = this.calc_motion_trace(sec_current, sec_delta, ox, oy, oz, nx, ny, nz)
		this.x, this.y, this.z = tx1, ty1, tz1

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
			= trace_map_ray_dist(camx,camy,camz, fwx,fwy,fwz, (this.mode == PLM_BUILD and 40) or 5, false)

			this.bld1 = td
			this.bld2 = td

			_,
			_, _, _,
			this.blx3, this.bly3, this.blz3
			= trace_map_ray_dist(camx,camy,camz, fwx,fwy,fwz, 127.5)
		end

		-- update items
		local i
		for i=1,#this.tools do
			this.tools[i].tick(sec_current, sec_delta)
		end
		if this.wpn then this.wpn.tick(sec_current, sec_delta) end
		if this.expl then this.expl.tick(sec_current, sec_delta) end
	end

	function this.drop_piano()
		this.t_piano = true
		if server then
			net_broadcast(nil, common.net_pack("BB", PKT_PIANO, this.pid))
		end
	end

        this.cam_angx = 0
        this.cam_angy = 0

	function this.camera_firstperson(sec_current, sec_delta)
		-- set camera position
		if this.alive then
			client.camera_move_to(this.x, this.y + this.jerkoffs, this.z)
			if MODE_FREEAIM and this.crosshair then
                	        local function ang_dist(a, b)
        	                        return math.atan2(math.sin(a-b), math.cos(a-b))
	                        end
                        	if ang_dist(this.cam_angy, this.angy) > math.pi / 16 then
                	                this.cam_angy = this.angy + math.pi / 16
        	                end
	                        if ang_dist(this.cam_angx, this.angx) > math.pi / 16 then
                                	this.cam_angx = this.angx + math.pi / 16
                        	end
                	        if ang_dist(this.cam_angy, this.angy) < -math.pi / 16 then
        	                        this.cam_angy = this.angy - math.pi / 16
	                        end
                        	if ang_dist(this.cam_angx, this.angx) < -math.pi / 16 then
                	                this.cam_angx = this.angx - math.pi / 16
        	                end
        	                this.crosshair.x = screen_width/2 + ang_dist(this.cam_angy, this.angy) * 400 * this.zoom
	                        this.crosshair.y = screen_height/2 - ang_dist(this.cam_angx, this.angx) * 400 * this.zoom
				this.crosshairhit.x = this.crosshair.x
				this.crosshairhit.y = this.crosshair.y
			end
		else
			if this.spectateplr.alive then
				client.camera_move_to(this.spectateplr.x , this.spectateplr.y , this.spectateplr.z)
			else
				client.camera_move_to(this.spectateplr.dead_x , this.spectateplr.dead_y , this.spectateplr.dead_z)
			end
		end

		local angy, angx
		if MODE_FREEAIM then
			angy = this.cam_angy
			angx = this.cam_angx
		else
			angy = this.angy
			angx = this.angx
		end

		-- calc camera forward direction
		local sya = math.sin(angy)
		local cya = math.cos(angy)
		local sxa = math.sin(angx)
		local cxa = math.cos(angx)
		local fwx,fwy,fwz
		fwx,fwy,fwz = sya*cxa, sxa, cya*cxa

		-- drunkencam correction
		this.sy = this.sy - MODE_DRUNKCAM_CORRECTSPEED*sec_delta
		local ds = math.sqrt(this.sx*this.sx + this.sy*this.sy + this.sz*this.sz)
		this.sx = this.sx / ds
		this.sy = this.sy / ds
		this.sz = this.sz / ds

		-- set camera direction
		client.camera_point_sky(fwx, fwy, fwz, this.zoom, this.sx, this.sy, this.sz)

		-- offset by eye pos
		-- slightly cheating here.
		if this.alive then
			client.camera_move_global(sya*0.4, 0, cya*0.4)
			--client.camera_point_sky(-fwx, -fwy, -fwz, this.zoom, this.sx, this.sy, this.sz)
			--client.camera_move_global(sya*4, 0, cya*4)
			--client.camera_point_sky(0, 0, 1, this.zoom, this.sx, this.sy, this.sz)
			--client.camera_move_global(0, 0, -4)

			-- move camera back if we're in a wall
			local dc = 0.5
			local df = 0.101
			local dt = trace_map_ray_dist(this.x + sya*(0.4-dc), this.y + this.jerkoffs, this.z + cya*(0.4-dc),
				sya, 0, cya, dc+df, true)

			if dt then
				local offs = dt-dc - df
				offs = offs * this.zoom
				client.camera_move_global(sya*offs, 0, cya*offs)
			end
		else
			-- move camera back as far as it can sanely go
			local dc = 10
			local df = 0.101
			if this.spectateplr.alive then
				local dt = trace_map_ray_dist(this.spectateplr.x , this.spectateplr.y , this.spectateplr.z ,
					-fwx, -fwy, -fwz, dc, true)
			else
				local dt = trace_map_ray_dist(this.spectateplr.dead_x , this.spectateplr.dead_y , this.spectateplr.dead_z ,
					-fwx, -fwy, -fwz, dc, true)
			end
			dt = dt or dc

			local offs = dt - df
			client.camera_move_global(-fwx*offs, -fwy*offs, -fwz*offs)
		end


		-- BUG WORKAROUND: adjust wav_cube_size dependent on zoom
		if client.renderer == "gl" then
			client.wav_cube_size(1.0*this.zoom)
		else
			client.wav_cube_size(1.0/this.zoom)
		end
	end

	function this.render(sec_current, sec_delta)
		if this.mode == PLM_SPECTATE then return end

		if this.t_piano and this.t_piano ~= true then
			local dt = this.t_piano_delta
			if dt < 0 then dt = 0 end
			if dt > 0.5 then dt = 0.5 end
			local size = (0.5-dt)/(0.5-0.4)
			if size > 1.0 then size = 1.0 end
			local dist = (dt/0.5) * -20
			mdl_piano_inst.render_global(this.x, this.y + dist + 2.5, this.z, 0, 0, 0, size*4)
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
			mdl_piano_inst.render_global(this.dead_x or this.x, py, this.dead_z or this.z, 0, 0, 0, dt*4)
		end
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
		elseif this.tools and this.tools[this.tool+1] then
			this.tools[this.tool+1].render(this.x+mdl_x, this.y+this.jerkoffs+mdl_y, this.z+mdl_z,
				math.pi/2, -this.angx + this.recoil_amt, this.angy)
		end

		this.mdl_player_arm.render_global(
			this.x+hand_x1, this.y+this.jerkoffs+hand_y1, this.z+hand_z1,
			0.0, rax_right-math.pi/2,
			this.angy-math.pi, 2.0)
		this.mdl_player_arm.render_global(
			this.x+hand_x2, this.y+this.jerkoffs+hand_y2, this.z+hand_z2,
			0.0, rax_left-math.pi/2,
			this.angy-math.pi, 2.0)

		this.mdl_player_leg.render_global(
			this.x+leg_x1, this.y+this.jerkoffs+leg_y1, this.z+leg_z1,
			0.0, swing, this.angy-math.pi, 2.2)
		this.mdl_player_leg.render_global(
			this.x+leg_x2, this.y+this.jerkoffs+leg_y2, this.z+leg_z2,
			0.0, -swing, this.angy-math.pi, 2.2)

		this.mdl_player_head.render_global(
			this.x, this.y+this.jerkoffs, this.z,
			0.0, this.angx, this.angy-math.pi, 1)

		this.mdl_player_body.render_global(
			this.x, this.y+this.jerkoffs+0.8, this.z,
			0.0, 0.0, this.angy-math.pi, 1.5)
	end

	--[[create static widgets for hud.
		FIXME: share 1 instance across all players? (This makes ticking trickier)
	]]
	function this.create_hud()
		local scene = gui_create_scene(screen_width, screen_height)
		this.scene = scene
		local root = scene.root
		local w = root.width
		local h = root.height

		-- tools

		this.tools_align = scene.display_object{x=root.l, y=root.t, visible=false}
		scene.root.add_child(this.tools_align)
		local i
		local xacc = 0
		local tool_y = {}
		local tool_scale = {}
		local tool_pick_scale = {}
		for i=1,#this.tools do
			xacc = xacc + this.tools[i].gui_x
			local va = (this.tools[i].get_va and this.tools[i].get_va())
			--print(va)
			this.tools_align.add_child(scene.bone{
				va=va,
				model=this.tools[i].get_model(), bone=0,
				x=xacc*w*5/8})
			tool_y[#tool_y+1] = this.tools[i].gui_y
			tool_scale[#tool_scale+1] = this.tools[i].gui_scale
			tool_pick_scale[#tool_pick_scale+1] = this.tools[i].gui_pick_scale
		end

		local bounce = 0. -- picked tool bounce

		local function bone_rotate(dT)
			local k, bone
			for k,bone in pairs(this.tools_align.children) do
				bone.rot_y = bone.rot_y + dT * 120 * 0.01
				bone.y = tool_y[k]
				bone.scale = tool_scale[k]
				if this.tool+1 == k then
					bone.y = bone.y + math.sin(bounce * 120 * 0.01) * 0.02
					bone.scale = bone.scale * tool_pick_scale[k]
				end
				bone.y = bone.y * h/2
			end
			bounce = bounce + dT * 4
		end
		this.tools_align.add_listener(GE_DELTA_TIME, bone_rotate)

		bone_rotate(0)

		--TODO: use the actual yes/no key mappings
		this.quit_msg = scene.textfield{wordwrap=false, color=0xFFFF3232, font=font_large, 
			text="Are you sure? (Y/N)", x = w/2, y = h/4, align_x = 0.5, align_y = 0.5,
			visible=false}

		this.reload_msg = scene.textfield{wordwrap=false, color=0xFFFF3232, font=font_large, 
			text="RELOAD", x = w/2, y = h/2+15, align_x = 0.5, align_y = 0,
			visible=false}

		this.enemy_name_msg = scene.textfield{wordwrap=false, color=0xFFFF3232, font=font_small, 
			text="", x = w/2, y = 3*h/4, align_x = 0.5, align_y = 0.5,
			visible=false}

		this.respawn_msg = scene.textfield{wordwrap=false, color=0xFFFF3232, font=font_large,
			text="", x = w/2, y = h-font_large.height-10, align_x = 0.5, align_y = 0,
			visible = false}

		--TODO: update bluetext/greentext with the actual keys (if changed in controls.json)
		this.team_change_msg_b = scene.textfield{wordwrap=false, color=0xFF0000FF, font=font_large, 
			text="Press 1 to join Blue", x = w/2, y = h/4, align_x = 0.5, align_y = 0.5}
		this.team_change_msg_g = scene.textfield{wordwrap=false, color=0xFF00FF00, font=font_large, 
			text="Press 2 to join Green", x = w/2, y = h/4 + 40, align_x = 0.5, align_y = 0.5}
		this.team_change = scene.display_object{visible=false}

		this.wpn_change_msgs = {}
		local i
		for i = 1,#this.wpn_list do
			this.wpn_change_msgs[i] = scene.textfield{wordwrap=false, color=0xFFFF0000, font=font_large,
				text="Press "..i.." to use "..weapon_names[this.wpn_list[i]],
				x = w/2, y = h/4 + 40*i, align_x = 0.5, align_y = 0.5}
		end
		this.wpn_change = scene.display_object{visible=false}

		-- chat and killfeed

		this.chat_text = scene.textfield{font=font_mini, ctab={}, 
			align_x=0, align_y=1, x = 4, y = h - 90}
		this.kill_text = scene.textfield{font=font_mini, ctab={}, 
			align_x=1, align_y=1, x = w - 4, y = h - 90}

		-- map (large_map and minimap)

		this.mini_map = scene.display_object{width=128, height=128, align_x = 1, align_y = 0,
			x=w, y=0, use_img = false}
		this.large_map = scene.display_object{x=w/2, y=h/2 - 24, visible=false, use_img = false}

		function this.large_map.update_size()
			local ow, oh
			ow, oh = common.img_get_dims(img_overview)
			this.large_map.width = ow
			this.large_map.height = oh
		end
		this.large_map.update_size()

		function this.map_gridname(x, y)
			return string.char(65+math.floor(x/64))..(1+math.floor(y/64))
		end

		function this.print_map_location(x, y)
			local s = "Location: "..this.map_gridname(this.x, this.z)
			font_mini.print(x - font_mini.width*#s/2, y, 0xFFFFFFFF, s)
		end

		function this.blit_overview_icons(mx, my, x1, y1, x2, y2)
			local i
			for i=1,#log_mspr do
				--print("blit", i, log_mspr[i][1], log_mspr[i][2], log_mspr[i][3])
				log_mspr[i][4].blit(
					log_mspr[i][1],
					log_mspr[i][2],
					log_mspr[i][3],
					mx, my,
					x1, y1, x2, y2)
			end
		end

		function this.update_overview_icons(dT)
			if this.alive then
				local i, j
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
							-- TODO: work out how to draw the line!
							c = 0xFF00FFFF
							--[[
							for i=0,10-1 do
								local d=i/math.sqrt(2)
								local u,v
								u = math.floor(x)+math.floor(d*math.sin(plr.angy))
								v = math.floor(y)+math.floor(d*math.cos(plr.angy))
								log_mspr[#log_mspr+1] = u
								log_mspr[#log_mspr+1] = v
								common.img_pixel_set(img_overview_icons, u, v, c)
							end
							]]
						elseif plr.team == this.team then
							c = 0xFFFFFFFF
						else
							c = 0xFFFF0000
							drawit = drawit and (this.t_rcirc ~= nil and
								(MODE_MINIMAP_RCIRC or this.large_map.visible))
						end

						if drawit then
							log_mspr[1+#log_mspr] = {math.floor(x), math.floor(y), c, mspr_player}
						end
					end
				end

				for j=1,#miscents do
					local obj = miscents[j]

					if obj.visible then
						local x,y
						x,y = obj.x, obj.z
						local l = obj.color_icon
						local c = argb_split_to_merged(l[1],l[2],l[3])
						log_mspr[1+#log_mspr] = {x, y, c, obj.mspr}
					end
				end
			end
		end

		function this.large_map.draw_update()
			this.large_map.update_size()
			local mx, my
			mx = this.large_map.l
			my = this.large_map.t
			client.img_blit(img_overview, mx, my)
			client.img_blit(img_overview_grid, mx, my,
				this.large_map.width, this.large_map.height, 
				0, 0, 0x80FFFFFF)
			--client.img_blit(img_overview_icons, mx, my)
			this.blit_overview_icons(mx, my, 0, 0, this.large_map.width, this.large_map.height)

			local i

			for i=1,math.floor(this.large_map.height/64+0.5) do
				font_mini.print(mx - 12, my + (i-0.5)*64,
					0xFFFFFFFF, ""..i)
				font_mini.print(mx + this.large_map.width + 12-6, 
					my + (i-0.5)*64,
					0xFFFFFFFF, ""..i)
			end

			for i=1,math.floor(this.large_map.width/64+0.5) do
				font_mini.print(mx + (i-0.5)*64, my - 12,
					0xFFFFFFFF, ""..string.char(64+i))
				font_mini.print(mx + (i-0.5)*64, 
					my + this.large_map.height + 12-6,
					0xFFFFFFFF, ""..string.char(64+i))
			end
		end

		local dt_samples = {}
		local dt_max = 0

		if SHOW_NETGRAPH then
			this.net_graph = scene.waveform{
				sample_sets={},
				width=200,
				height=50,
				x=w/4,
				y=h-30
			}
		else
			this.net_graph = nil
		end

		local function net_graph_update(delta_time)
			this.net_graph.visible = (this.mode ~= PLM_SPECTATE)
			-- the incoming dT is clamped, therefore we use delta_last instead
			table.insert(dt_samples, delta_last)
			dt_max = math.max(delta_last, dt_max)
			if #dt_samples > this.net_graph.width then
				table.remove(dt_samples, 1)
			end
			this.net_graph.push(
			{{dt_samples,0xFF00FF00,0xFF008800,-dt_max,dt_max}})
		end

		function this.mini_map.draw_update()
			if MODE_ENABLE_MINIMAP and this.alive then
				local mw, mh
				mw, mh = this.mini_map.width, this.mini_map.height

				local left, top
				left = math.floor(this.mini_map.l)
				top = math.floor(this.mini_map.t)

				local qx, qy
				for qy=-1,1 do
				for qx=-1,1 do
					local view_left, view_top
					view_left = math.floor(this.x-mw/2)+this.large_map.width*qx
					view_top = math.floor(this.z-mh/2)+this.large_map.height*qy

					client.img_blit(img_overview, left, top,
						mw, mh,
						view_left, view_top,
						0xFFFFFFFF)
					client.img_blit(img_overview_grid, left, top,
						mw, mh,
						view_left, view_top,
						0x80FFFFFF)
				end
				end
				local vx, vy = math.floor(this.x-mw/2), math.floor(this.z-mh/2)
				this.blit_overview_icons(left, top, vx, vy, vx+mw, vy+mh)
				this.print_map_location(this.mini_map.cx, this.mini_map.b + 2)
			end
		end

		function this.menus_visible()
			return this.quit_msg.visible or this.team_change.visible or this.wpn_change.visible
		end
		local function is_view_released()
			return gui_focus ~= nil
		end

		local function teamchange_events(options)
			local viz = this.team_change.visible
			if options.state and not is_view_released() then
				if viz then

					local team

					if options.key == BTSK_TOOLS[1] then viz = false; team = 0
					elseif options.key == BTSK_TOOLS[2] then viz = false; team = 1
					elseif (options.key == BTSK_QUIT or options.key == BTSK_TEAM)
						then viz = false 
					end

					local plr
					plr = players[players.current]
					if plr ~= nil and team ~= nil and team ~= plr.team then
						net_send(nil, common.net_pack("Bbbz", PKT_PLR_OFFER, team, plr.weapon, plr.name or ""))
					end					

				elseif options.key == BTSK_TEAM and not this.menus_visible() then
					viz = true
				end
			end		
			this.team_change.visible = viz
		end
		local function wpnchange_events(options)
			local viz = this.wpn_change.visible
			if options.state and not is_view_released() then
				if viz then
					local wpn

					if (options.key == BTSK_QUIT or options.key == BTSK_WPN)
						then viz = false 
					else
						local i
						for i = 1,#this.wpn_list do
							if options.key == BTSK_TOOLS[i] then
								viz = false
								wpn = this.wpn_list[i]
							end
						end
					end

					local plr
					plr = players[players.current]
					if plr ~= nil and wpn ~= nil and wpn ~= plr.weapon then
						net_send(nil, common.net_pack("Bbbz", PKT_PLR_OFFER, plr.team, wpn, plr.name or ""))
					end

				elseif options.key == BTSK_WPN and not this.menus_visible() then
					viz = true
				end
			end		
			this.wpn_change.visible = viz
		end
		local function toggle_map_state(options)
			if options.state and options.key == BTSK_MAP and not is_view_released() then
				this.mini_map.visible = not this.mini_map.visible
				this.large_map.visible = not this.large_map.visible
			end
		end
		local function feed_update(options)
			this.kill_text.ctab = chat_killfeed.render()
			this.chat_text.ctab = chat_text.render()
		end
		local function enemy_name_update(options)
			local sya = math.sin(this.angy)
			local cya = math.cos(this.angy)
			local sxa = math.sin(this.angx)
			local cxa = math.cos(this.angx)
			local fwx,fwy,fwz
			fwx,fwy,fwz = sya*cxa, sxa, cya*cxa

			-- perform a trace
			local d,cx1,cy1,cz1,cx2,cy2,cz2
			d,cx1,cy1,cz1,cx2,cy2,cz2
			= trace_map_ray_dist(this.x+sya*0.4,this.y,this.z+cya*0.4, fwx,fwy,fwz, 127.5)
			d = d or 75

			local target_idx = nil
			local target_dist = d*d
			local i,j

			for i=1,players.max do
				local p = players[i]
				if p and p ~= this and p.alive then
					local dx = p.x-this.x
					local dy = p.y-this.y+0.1
					local dz = p.z-this.z

					for j=1,3 do
						local dot, dd = isect_line_sphere_delta(dx,dy,dz,fwx,fwy,fwz)
						if dot and dot < 0.55 and dd < target_dist then
							target_idx = i
							break
						end
						dy = dy + 1.0
					end
				end
			end
			this.enemy_name_msg.visible = target_idx ~= nil
			if target_idx ~= nil then
				this.enemy_name_msg.text = players[target_idx].name
			end
		end

		this.crosshair = scene.image{img=img_crosshair, x=w/2, y=h/2}
		this.crosshairhit = scene.image{img=img_crosshairhit, x=w/2, y=h/2, visible=false}
		this.cpal = scene.image{img=img_cpal, x=0, y=h, align_x=0, align_y=1}
		this.cpal_rect = scene.image{img=img_cpal_rect, align_x=0, align_y=0}

		local function cpal_update(options)
			this.cpal_rect.x = this.blk_color_x * 8 + this.cpal.l
			this.cpal_rect.y = this.blk_color_y * 8 + this.cpal.t
		end

		cpal_update()

		this.health_text = scene.textfield{
			font=font_digits,
			text="100", 
			color=0xFFFF0000,
			align_x=0.5, 
			align_y=0, 
			x = w/2,
			y = h-48}

		local function health_update(options)
			if this.mode == PLM_NORMAL and this.alive then
				this.health_text.text = ""..this.health
			else
				this.health_text.text = ""
			end
		end

		this.ammo_text = scene.textfield{
			font=font_digits,
			text="",
			color=0xFFFFFFFF,
			align_x = 1,
			align_y = 0,
			x = w - 16,
			y = h - 48}

		local function ammo_update(options)
			this.ammo_text.color, this.ammo_text.text = this.tools[this.tool+1].textgen()
			if this.mode == PLM_SPECTATE or not this.alive then
				this.ammo_text.text = ""
			end
		end

		this.typing_type = this.typing_type or scene.textfield{
			text="",
			color=0xFFFFFFFF,
			align_x = 0,
			align_y = 0,
			x = 0,
			y = 0}
		this.typing_text = this.typing_text or scene.textfield{
			text="",
			color=0xFFFFFFFF,
			align_x = 0,
			align_y = 0,
			x = 0,
			y = 0,
			take_input = true}
		if not this.typing_layout then
			this.typing_layout = scene.hspacer{x=4, y=h - 80, spread = 0, align_x=0, align_y=0}
			this.typing_layout.add_child(this.typing_type)
			this.typing_layout.add_child(this.typing_text)
			this.typing_layout.visible = false
		end

		function this.typing_text.done_typing(options)
			this.typing_layout.visible = false
			discard_typing_state(this.typing_text)
		end

		function this.typing_text.on_return(options)
			if this.typing_text.text ~= "" then
				if this.typing_type.text == "Chat: " then
					net_send(nil, common.net_pack("Bz", PKT_CHAT_SEND, this.typing_text.text))
				elseif this.typing_type.text == "Team: " then
					net_send(nil, common.net_pack("Bz", PKT_CHAT_SEND_TEAM, this.typing_text.text))
				elseif this.typing_type.text == "Squad: " then
					net_send(nil, common.net_pack("Bz", PKT_CHAT_SEND_SQUAD, this.typing_text.text))
				end
			end

			this.typing_text.done_typing()
		end

		local box_spacer = scene.hspacer{x=w/2,y=h/2,spread=8}
		scene.root.add_child(box_spacer)
		local scoreboard_frames = {}
		local scoreboard_headers = {}
		local scoreboard_team_points = {}
		local scoreboard_individuals = {}
		local scoreboard_vspacers = {}
		local i
		for i=0, teams.max do
			local team_color = argb_split_to_merged(
				teams[i].color_chat[1],
				teams[i].color_chat[2],
				teams[i].color_chat[3]
				)
			local box = scene.tile9{
				width=20, 
				height=20, 
				tiles=img_tiles_roundrect
			}
			local header_text = scene.textfield{
				text=teams[i].name,
				color=team_color
			}
			local team_point_text = scene.textfield{
				text="0-10",
				font=font_digits,
				color=team_color
			}
			local individual_text = scene.textfield{
				text="moo",
				color=team_color
			}
			scoreboard_frames[i] = box
			scoreboard_headers[i] = header_text
			scoreboard_individuals[i] = individual_text
			scoreboard_team_points[i] = team_point_text
			box_spacer.add_child(box)
			local vspacer = scene.vspacer{x=0, y=0, spread = 8}
			box.add_child(vspacer)
			vspacer.add_child(team_point_text)
			vspacer.add_child(header_text)
			vspacer.add_child(individual_text)
			scoreboard_vspacers[i] = vspacer
			box_spacer.visible = false;
		end

		box_spacer.reflow()
		scoreboard_frames[1].add_listener(GE_DELTA_TIME, function(dT)
			box_spacer.visible = show_scores
			if box_spacer.visible then
				local tables = {}
				for i=0, teams.max do
					tables[i] = team_players(i)
					table.sort(tables[i], player_ranking)
				end
				-- we format each column by exploiting the fixed-width text.
				for k,v in pairs(tables) do

					local table_concat = {}
					if #v == 0 then
						table_concat = {{msg="NO PLAYERS",color=0xFFFFFFFF}}
					else
						-- find the max width of each column
						local strtable = {}
						table.insert(strtable, {
							"Name",
							"Squad",
							"#",
							"Score",
							"K",
							"D",
							"?"})
						for row=1, #v do
							local squad = ""
							local plr = v[row]
							if plr.squad ~= nil then 
								squad = "["..tostring(plr.squad).."]"
							end
							table.insert(strtable, {
								tostring(plr.name),
								squad,
								tostring(plr.pid),
								tostring(plr.score),
								tostring(plr.kills),
								tostring(plr.deaths),
								plr})
						end
						local widths = {}
						for row=1, #strtable do
							for col=1, #strtable[row] do
								widths[col] = math.max(#strtable[row][col], widths[col] or 0)
							end
						end
						-- pad the strings to the target width.asdf
						for row_idx,row in pairs(strtable) do
							if row[7] ~= nil then
								local concat = {msg="", color=0xAAAAAAFF}
								if row_idx == 1 then -- this is the header
									concat.color = 0xFF888888
								elseif row[7] == this then -- highlight the client's name
									concat.color = 0xFFFFFFFF
								elseif this.squad == row[7].squad and this.team == row[7].team and this.squad ~= "" and this.squad ~= nil then
									if row[7].alive then
										concat.color = 0xFF00FFFF
									else
										concat.color = 0xDD00DDDD
									end
								elseif not row[7].alive then
									concat.color = 0x88888888
								end
								for col_idx, val in pairs(row) do
									if col_idx ~= 7 then
										local msg = val
										while #msg < widths[col_idx] do
											msg = msg .. " "
										end
										concat.msg = concat.msg .. msg .. "  "
									end
								end
								table.insert(table_concat, concat)
							end
						end
					end

					scoreboard_individuals[k].ctab = table_concat
					scoreboard_team_points[k].text = teams[k].score .. "-" .. TEAM_SCORE_LIMIT
					local box = scoreboard_frames[k]
					local vspacer = scoreboard_vspacers[k]
					local dim = vspacer.full_dimensions
					box.width = dim.r - dim.l + 32
					box.height = dim.b - dim.t + 64

				end
				box_spacer.reflow()
			end
		end)
		-- Almost there.
		-- Table is not generated properly.
		-- Empty team case is not handled properly.		

		-- spacer test
		--[[local spacer = scene.hspacer{x=w/2,y=h/2,spread=8}
		scene.root.add_child(spacer)
		local boxes = {}
		local i
		for i=1, 10 do
			local box = scene.tile9{
				width=20+math.random(50), 
				height=20+math.random(50), 
				tiles=img_tiles_roundrect
			}
			table.insert(boxes, box)
			spacer.add_child(box)
		end
		spacer.reflow()
		boxes[1].add_listener(GE_DELTA_TIME, function(dT)
			for i=1, 10 do
				boxes[i].width=20+math.random(50)
				boxes[i].height=20+math.random(50)
			end
			spacer.reflow()
		end)]]

		this.team_change.add_listener(GE_BUTTON, teamchange_events)
		this.wpn_change.add_listener(GE_BUTTON, wpnchange_events)
		this.large_map.add_listener(GE_DELTA_TIME, this.update_overview_icons)
		this.mini_map.add_listener(GE_BUTTON, toggle_map_state)
		this.cpal_rect.add_listener(GE_DELTA_TIME, cpal_update)
		this.chat_text.add_listener(GE_DELTA_TIME, feed_update)
		this.health_text.add_listener(GE_DELTA_TIME, health_update)
		this.ammo_text.add_listener(GE_DELTA_TIME, ammo_update)
		if this.net_graph then
			this.net_graph.add_listener(GE_DELTA_TIME, net_graph_update)
		end
		this.enemy_name_msg.add_listener(GE_DELTA_TIME, enemy_name_update)

		scene.root.add_child(this.crosshair)
		scene.root.add_child(this.crosshairhit)
		scene.root.add_child(this.cpal)
		scene.root.add_child(this.cpal_rect)
		scene.root.add_child(this.mini_map)
		scene.root.add_child(this.large_map)
		scene.root.add_child(this.health_text)
		scene.root.add_child(this.ammo_text)
		scene.root.add_child(this.chat_text)
		scene.root.add_child(this.kill_text)
		scene.root.add_child(this.typing_layout)
		if this.net_graph then
			scene.root.add_child(this.net_graph)
		end
		this.team_change.add_child(this.team_change_msg_b)
		this.team_change.add_child(this.team_change_msg_g)
		local i
		for i=1,#this.wpn_change_msgs do
			this.wpn_change.add_child(this.wpn_change_msgs[i])
		end
		scene.root.add_child(this.team_change)
		scene.root.add_child(this.wpn_change)
		scene.root.add_child(this.quit_msg)
		scene.root.add_child(this.reload_msg)
		scene.root.add_child(this.enemy_name_msg)
		scene.root.add_child(this.respawn_msg)

		this.scene = scene
	end

	function this.show_hit()
		this.crosshair.visible = false
		this.crosshairhit.visible = true
		this.crosshairhit.static_alarm{name='hitviz', time=0.25, on_trigger=function()
			this.crosshair.visible = true
			this.crosshairhit.visible = false
		end}

	end

	function this.on_mouse_button(button, state)
		if this.mode == PLM_SPECTATE then
			return
		end

		if this.alive then
			this.tools[this.tool+1].click(button, state)
		elseif not state and (button == 1 or button == 3) and MODE_SPECTATE then
			local teamplayers = {}
			for i, v in ipairs(team_players(this.team)) do
				if v ~= this then
					table.insert(teamplayers, v)
				end
			end

			if button == 1 then
				this.spectateindex = this.spectateindex + 1
				if this.spectateindex > #teamplayers then
					this.spectateindex = 0
				end
			elseif button == 3 then
				this.spectateindex = this.spectateindex - 1
				if this.spectateindex < 0 then
					this.spectateindex = #teamplayers
				end
			end

			if this.spectateindex == 0 then
				this.spectateplr = this
			else
				this.spectateplr = teamplayers[this.spectateindex]
			end

		end
		if button == 1 then
			-- LMB
			this.ev_lmb = state
			if this.ev_lmb then
				this.ev_rmb = false
			end
		elseif button == 3 then
			-- RMB
			this.ev_rmb = state
			if this.ev_rmb then
				this.ev_lmb = false
			end
		elseif button == 4 then
			-- mousewheelup
			if state then
				this.tool_switch_prev()
			end
		elseif button == 5 then
			-- mousewheeldown
			if state then
				this.tool_switch_next()
			end
		elseif button == 2 then
			-- middleclick
		end
	end

	function this.on_mouse_motion(x, y, dx, dy)
		if user_config.invert_y then
			dy = -dy
		end

		this.dangy = this.dangy - dx*math.pi*sensitivity/this.zoom
		this.dangx = this.dangx + dy*math.pi*sensitivity/this.zoom
	end

	function this.focus_typing(typing_type, default_text)
		this.typing_type.text = typing_type
		gui_focus = this.typing_text
		this.typing_text.text = default_text
		this.typing_text.cursor_to_text_end()
		enter_typing_state()
		this.typing_layout.reflow()
		this.typing_layout.visible = true		
	end

	function this.on_key(key, state, modif)
		if key == BTSK_FORWARD then
			this.ev_forward = state
			this.key_forward = state
		elseif key == BTSK_BACK then
			this.ev_back = state
			this.key_back = state
		elseif key == BTSK_LEFT then
			this.ev_left = state
			this.key_left = state
		elseif key == BTSK_RIGHT then
			this.ev_right = state
			this.key_right = state
		elseif key == BTSK_CROUCH then
			this.ev_crouch = state
			this.key_crouch = state
		elseif key == BTSK_JUMP then
			this.ev_jump = state
			this.key_jump = state
		elseif key == BTSK_SNEAK then
			this.ev_sneak = state
			this.key_sneak = state
		elseif key == BTSK_SCORES then
			show_scores = state
		elseif state and not this.menus_visible() then
			this.tools[this.tool+1].key(key, state, modif)
			if state then
				if key == BTSK_DEBUG then
					debug_enabled = not debug_enabled
				elseif key == SDLK_F10 then
					--local s = "clsave/"..common.base_dir.."/vol/lastsav.icemap"
					local s = "clsave/vol/lastsav.icemap"
					print(s)
					--client.map_load(s)
					client.map_save(map_loaded, s, "icemap")
					chat_add(chat_text, sec_last, "Map saved to "..s, 0xFFC00000)
				elseif key == BTSK_TOOLLAST then
					this.tool_switch(this.tool_last)
				elseif key == BTSK_CHAT then
					this.focus_typing("Chat: ", "")
				elseif key == BTSK_COMMAND then
					this.focus_typing("Chat: ", "/")
				elseif key == BTSK_TEAMCHAT then
					this.focus_typing("Team: ", "")
				elseif key == BTSK_SQUADCHAT then
					this.focus_typing("Squad: ", "")
				elseif key == BTSK_QUIT then
					if gui_focus == nil then
						this.quit_msg.visible = true
					end
				else
					local i
					for i=1,#BTSK_TOOLS do
						if key == BTSK_TOOLS[i] then
							this.tool_switch(i-1)
						end
					end
				end
			end
		elseif state and key == BTSK_YES then
			if this.quit_msg.visible then
				-- TODO: clean up
				client.hook_tick = nil
			end
		elseif state and key == BTSK_NO then
			if this.quit_msg.visible then
				this.quit_msg.visible = false
			end
		end
	end

	local mdl_vpl, mdl_vpl_bone, mdl_vpl_done
	mdl_vpl_done = false

	function this.show_hud()
		local fogr,fogg,fogb,fogd = client.map_fog_get()

		local ays,ayc,axs,axc
		ays = math.sin(this.angy)
		ayc = math.cos(this.angy)
		axs = math.sin(this.angx)
		axc = math.cos(this.angx)

		--font_mini.print(64,8,0xFFFFFFFF,mouse_prettyprint())

		local i, j
		if not this.scene then
			this.create_hud()
		end

		if this.mode ~= PLM_SPECTATE then
			this.render()
		end

		if MODE_DEBUG_SHOWBOXES then
			client.model_render_bone_global(mdl_bbox,
				(this.crouching and mdl_bbox_bone2) or mdl_bbox_bone1,
				this.x, this.y, this.z, 0, 0, 0.0, 1)
		end

		for i=1,players.max do
			local plr = players[i]
			if plr and plr ~= this then
				if client.gfx_stencil_test and plr.team == this.team then
					client.gfx_stencil_test(true)

					-- PASS 1: set to 1 for enlarged model
					client.gfx_depth_mask(false)
					client.gfx_stencil_func("0", 1, 255)
					client.gfx_stencil_op("===")
					local s_va_render_global = client.va_render_global
					function client.va_render_global(va, px, py, pz, ry, rx, ry2, scale, ...)
						scale = scale or 1.0
						scale = scale * 1.4
						return s_va_render_global(va, px, py, pz, ry, rx, ry2, scale, ...)
					end
					plr.render()
					client.va_render_global = s_va_render_global
					client.gfx_depth_mask(true)

					-- PASS 2: set to 0 for regular model
					client.gfx_stencil_func("1", 0, 255)
					client.gfx_stencil_op("===")
					plr.render()

					-- PASS 3: draw red for stencil == 1; clear stencil
					client.gfx_stencil_func("==", 1, 255)
					client.gfx_stencil_op("000")
					local iw, ih = common.img_get_dims(img_fsrect)
					client.img_blit(img_fsrect, 0, 0, iw, ih, 0, 0, 0x7FFFFFFF)

					client.gfx_stencil_test(false)
				else
					plr.render()
				end

				if plr.alive and plr.team == this.team then
					local px,py
					local dx,dy,dz
					local x,y,z = client.camera_get_pos()
					dx,dy,dz = plr.x-x,
						plr.y+plr.jerkoffs-y-this.jerkoffs-0.5,
						plr.z-z
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
						px = screen_width/2-screen_width/2*dx*this.zoom/dz
						py = screen_height/2+screen_width/2*dy*this.zoom/dz
						local c
						if plr.squad and plr.squad == this.squad then
							client.img_blit(img_chevron, px - 4, py - 20)
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

		for i=1,#miscents do
			local obj = miscents[i]
			if obj.visible then
				obj.render()
			end
		end

		if this.mode == PLM_SPECTATE or not this.alive then
			this.cpal.visible = false
			this.cpal_rect.visible = false
		else
			this.cpal.visible = true
			this.cpal_rect.visible = true
		end

		if client.gfx_clear_depth then
			client.gfx_clear_depth()
		end
		this.scene.draw()

		if debug_enabled then
			local camx,camy,camz
			camx,camy,camz = client.camera_get_pos()
			local cam_pos_str = string.format("s2: %f x: %f y: %f z: %f j: %f c: %i"
				, math.sqrt(this.vx*this.vx + this.vz*this.vz)
				, camx, camy, camz, this.jerkoffs, (this.crouching and 1) or 0)

			font_mini.print(4, 4, 0x80FFFFFF, cam_pos_str)
		end

		-- VPL TEST
		if MODE_DEBUG_VPLTEST then
			if not mdl_vpl_done then
				if not mdl_vpl then
					mdl_vpl = common.model_new(1)
					mdl_vpl, mdl_vpl_bone = common.model_bone_new(mdl_vpl, 10)
				end
				local x,y,z
				x,y,z = this.x, this.y, this.z
				if VPLPOINT then
					x,y,z = VPLPOINT.x, VPLPOINT.y, VPLPOINT.z
				end
				local vpls = vpl_gen_from_sphere(x, y, z, MODE_NADE_VPL_MAX_COUNT, MODE_NADE_VPL_MAX_RANGE, MODE_NADE_VPL_MAX_TRIES)
				local i
				local l = {{x = x*8, y = y*8, z = z*8, r=255, g=255, b=255, radius = 2}}
				for i=1,#vpls do
					local v = vpls[i]
					local rad = MODE_NADE_VPL_MAX_RANGE - v.d
					l[#l+1] = {
						x = v.x*8, y = v.y*8, z = v.z*8,
						r=math.min(255, math.max(1, rad*255/MODE_NADE_VPL_MAX_RANGE)), g =16, b = 16,
						radius=1,
					}
				end
				common.model_bone_set(mdl_vpl, mdl_vpl_bone, "vplvpl", l)
				mdl_vpl_done = true
			end
			client.model_render_bone_global(mdl_vpl, mdl_vpl_bone, 0, 0, 0, 0, 0, 0, 256.0/8.0)
		end
	end

	function this.vpl()
		mdl_vpl_done = false
	end

	return this
end

function v(noreset)
	MODE_DEBUG_VPLTEST = true
	if not noreset then
		VPLPOINT = nil
	end
	players[players.current].vpl()
end


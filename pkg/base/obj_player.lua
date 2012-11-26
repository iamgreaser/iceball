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
	
	local function prv_recolor_component(r,g,b,mdata)
		for i=1,#mdata do
			if mdata[i].r == 0 and mdata[i].g == 0 and mdata[i].b == 0 then
				mdata[i].r = r
				mdata[i].g = g
				mdata[i].b = b
			end
		end
	end
	
	local function prv_recolor_team(r,g,b)
		local mname,mdata
		mname,mdata = common.model_bone_get(mdl_player, mdl_player_head)
		prv_recolor_component(r,g,b,mdata)
		common.model_bone_set(this.mdl_player, mdl_player_head, mname, mdata)
		mname,mdata = common.model_bone_get(mdl_player, mdl_player_body)
		prv_recolor_component(r,g,b,mdata)
		common.model_bone_set(this.mdl_player, mdl_player_body, mname, mdata)
		mname,mdata = common.model_bone_get(mdl_player, mdl_player_arm)
		prv_recolor_component(r,g,b,mdata)
		common.model_bone_set(this.mdl_player, mdl_player_arm, mname, mdata)
		mname,mdata = common.model_bone_get(mdl_player, mdl_player_leg)
		prv_recolor_component(r,g,b,mdata)
		common.model_bone_set(this.mdl_player, mdl_player_leg, mname, mdata)
	end
	
	local function prv_recolor_block(r,g,b)
		local mname,mdata
		mname,mdata = common.model_bone_get(mdl_block, mdl_block_bone)
		prv_recolor_component(r,g,b,mdata)
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
		
		this.vx, this.vy, this.vz = 0, 0, 0
		this.angy, this.angx = math.pi/2.0, 0.0
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
		this.ammo_clip = weapons[this.weapon].ammo_clip
		this.ammo_reserve = weapons[this.weapon].ammo_reserve
		
		this.name = settings.name or "Noob"
		
		this.tool = 2
	end
	
	this.spawn()
	
	function this.tick(sec_current, sec_delta)
		-- clamp angle, YOU MUST NOT LOOK DIRECTLY UP OR DOWN!
		if this.angx > math.pi*0.499 then
			this.angx = math.pi*0.499
		elseif this.angx < -math.pi*0.499 then
			this.angx = -math.pi*0.499
		end
		
		if this.tool ~= TOOL_GUN then
			this.zooming = false
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
		
		
		tx1,ty1,tz1 = trace_map_box(
			ox, oy, oz,
			nx, ny, nz,
			-0.4,  by1, -0.4,
			0.4,  by2,  0.4,
			false)
		if MODE_AUTOCLIMB then
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
		
		if this.vy > 0 and this.grounded then
			this.vy = 0
		end
		
		-- trace for stuff
		do
			local td
			local _
			
			td,
			this.blx1, this.bly1, this.blz1, 
			this.blx2, this.bly2, this.blz2
			= trace_map_ray_dist(this.x,this.y,this.z, fwx,fwy,fwz, 5)
			
			_,
			_, _, _, 
			this.blx3, this.bly3, this.blz3
			= trace_map_ray_dist(this.x,this.y,this.z, fwx,fwy,fwz, 127.5)
		end
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
		
		local mdl_x = hand_x1+axc*ays*0.8
		local mdl_y = hand_y1+axs*0.8
		local mdl_z = hand_z1+axc*ayc*0.8
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
			client.model_render_bone_global(mdl_rifle, mdl_rifle_bone,
				this.x+mdl_x, this.y+this.jerkoffs+mdl_y, this.z+mdl_z,
				math.pi/2, -this.angx, this.angy, 3)
		elseif this.tool == TOOL_NADE then
			client.model_render_bone_global(mdl_nade, mdl_nade_bone,
				this.x+mdl_x, this.y+this.jerkoffs+mdl_y, this.z+mdl_z,
				0.0, -this.angx, this.angy, 0.5)
		end
		
		local swing = math.sin(rotpos/30*2)
			*math.min(1.0, math.sqrt(
				 this.vx*this.vx
				+this.vz*this.vz)/8.0)
			*math.pi/4.0
		
		client.model_render_bone_global(this.mdl_player, mdl_player_arm,
			this.x+hand_x1, this.y+this.jerkoffs+hand_y1, this.z+hand_z1,
			0.0, this.angx-math.pi/2, this.angy-math.pi, 2.0)
		client.model_render_bone_global(this.mdl_player, mdl_player_arm,
			this.x+hand_x2, this.y+this.jerkoffs+hand_y2, this.z+hand_z2,
			0.0, 0-math.pi/4+swing, this.angy-math.pi, 2.0)
		
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
	end
	
	function this.show_hud()
		local fogr,fogg,fogb,fogd = client.map_fog_get()
		
		local ays,ayc,axs,axc
		ays = math.sin(this.angy)
		ayc = math.cos(this.angy)
		axs = math.sin(this.angx)
		axc = math.cos(this.angx)
		
		local w, h
		w, h = client.screen_get_dims()
		
		-- TODO: palettise this more nicely
		local i
		prv_recolor_block(this.blk_color[1],this.blk_color[2],this.blk_color[3])
		
		if this.blx1 then
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
		client.model_render_bone_local(mdl_rifle, mdl_rifle_bone,
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
				if plr.team == this.team then
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
							,(c[1]*256+c[2])*256+c[3]
							+0x01000000*math.floor(fatt*255)
							,s_name)
					end
				end
			end
		end
		
		local color = 0xFFA1FFA1
		local hstr = ""..this.health
		local astr = ""..this.ammo_clip.."-"..this.ammo_reserve
		local bstr = ""..this.blocks
		
		local i
		gui_print_digits((w-32*#hstr)/2, h-48, color, hstr)
		gui_print_digits(-16+w-32*#astr, h-48, 0xAA880000, astr)
		local cr,cg,cb
		cr,cg,cb = this.blk_color[1],this.blk_color[2],this.blk_color[3]
		local cw = (cr*256+cg)*256+cb
		gui_print_digits(16, h-48, cw+0xFF000000, bstr)
		
		if debug_enabled then
			local camx,camy,camz
			camx,camy,camz = client.camera_get_pos()
			local cam_pos_str = string.format("x: %f y: %f z: %f j: %f c: %i"
				, camx, camy, camz, this.jerkoffs, (this.crouching and 1) or 0)
			
			gui_print_mini(4, 4, 0x80FFFFFF, cam_pos_str)
		end
		
		client.img_blit(img_crosshair, w/2 - 8, h/2 - 8)
		
		local ow, oh
		ow, oh = common.img_get_dims(img_overview)
		if large_map then
			local mx, my
			mx = w/2 - ow/2
			my = h/2 - oh/2 - 24
			client.img_blit(img_overview, mx, my)
			client.img_blit(img_overview_grid, mx, my,
				ow, oh, 0, 0, 0x80FFFFFF)
			
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
		else
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
			end
			end
		end
	end
	
	return this
end

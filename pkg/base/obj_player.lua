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
	this.weapon = settings.weapon or WPN_RIFLE
	this.alive = false
	this.spawned = false
	this.zooming = false
	
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
	end
	
	function this.show_hud()
		local w, h
		w, h = client.screen_get_dims()
		
		-- TODO: palettise this more nicely
		local i
		for i=1,#mdl_block_data do
			mdl_block_data[i].r,
			mdl_block_data[i].g,
			mdl_block_data[i].b =
				this.blk_color[1],
				this.blk_color[2],
				this.blk_color[3]
		end
		client.model_bone_set(mdl_block, mdl_block_bone, "block", mdl_block_data)
		
		local ays,ayc
		ays = math.sin(this.angy)
		ayc = math.cos(this.angy)
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
		client.model_render_bone_local(mdl_test, mdl_test_bone,
			1-0.2, 600/800-0.2, 1.0,
			rotpos*0.01, rotpos*0.004, 0.0, 0.1)
		client.model_render_bone_global(mdl_bbox, 
			(this.crouching and mdl_bbox_bone2) or mdl_bbox_bone1,
			this.x, this.y, this.z, 0, 0, 0.0, 1)
		
		-- TODO: not have this on all the time
		client.model_render_bone_local(mdl_spade, mdl_spade_bone,
			1-0.15, -h/w+0.25, 1.0,
			rotpos*0.01, 0.0, 0.0, 0.2*((this.tool == TOOL_SPADE and 1.5) or 1.0))
		client.model_render_bone_local(mdl_block, mdl_block_bone,
			1-0.30, -h/w+0.2, 1.0,
			rotpos*0.01, 0.0, 0.0, 0.1*((this.tool == TOOL_BLOCK and 2.0) or 1.0))
		client.model_render_bone_local(mdl_rifle, mdl_rifle_bone,
			1-0.45, -h/w+0.2, 1.0,
			rotpos*0.01, 0.0, 0.0, 0.2*((this.tool == TOOL_GUN and 2.0) or 1.0))
		client.model_render_bone_local(mdl_nade, mdl_nade_bone,
			1-0.60, -h/w+0.2, 1.0,
			rotpos*0.01, 0.0, 0.0, 0.1*((this.tool == TOOL_NADE and 2.0) or 1.0))
		
		if this.tool == TOOL_SPADE then
			client.model_render_bone_global(mdl_spade, mdl_spade_bone,
				this.x-ayc*0.2, this.y+this.jerkoffs+0.2, this.z+ays*0.2,
				0.0, -this.angx-math.pi/2*0.90, this.angy, 1)
		elseif this.tool == TOOL_BLOCK then
			client.model_render_bone_global(mdl_block, mdl_block_bone,
				this.x-ayc*0.1+ays*0.1, this.y+this.jerkoffs+0.1, this.z+ays*0.1+ayc*0.1,
				0.0, -this.angx, this.angy, 0.2)
		elseif this.tool == TOOL_GUN then
			client.model_render_bone_global(mdl_rifle, mdl_rifle_bone,
				this.x-ayc*0.1+ays*0.1, this.y+this.jerkoffs+0.1, this.z+ays*0.1+ayc*0.1,
				math.pi/2, -this.angx, this.angy, 1)
		elseif this.tool == TOOL_NADE then
			client.model_render_bone_global(mdl_nade, mdl_nade_bone,
				this.x-ayc*0.1+ays*0.1, this.y+this.jerkoffs+0.1, this.z+ays*0.1+ayc*0.1,
				0.0, -this.angx, this.angy, 0.14)
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
	end
	
	return this
end

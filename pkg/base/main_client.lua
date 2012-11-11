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

print("pkg/base/main_client.lua starting")

-- load libs
dofile("pkg/base/lib_sdlkey.lua")
dofile("pkg/base/lib_vector.lua")

-- define keys
BTSK_FORWARD = SDLK_w
BTSK_BACK    = SDLK_s
BTSK_LEFT    = SDLK_a
BTSK_RIGHT   = SDLK_d
BTSK_JUMP    = SDLK_SPACE
BTSK_CROUCH  = SDLK_LCTRL
BTSK_SNEAK   = SDLK_v

BTSK_QUIT = SDLK_ESCAPE

BTSK_DEBUG = SDLK_F1

-- mode stuff
MODE_CHEAT_FLY = false

MODE_AUTOCLIMB = true
MODE_AIRJUMP = false
MODE_SOFTCROUCH = true

MODE_TILT_SLOWDOWN = false -- TODO!
MODE_TILT_DOWN_NOCLIMB = false -- TODO!

-- weapons
WPN_RIFLE = 0
WPN_NOOB = 1
WPN_SHOTTY = 2

math.random()

weapons = {
	[WPN_RIFLE] = {
		-- version: 0.60 with spread removed completely
		dmg_head = 100,
		dmg_body = 49,
		dmg_limb = 33,
		
		ammo_clip = 10,
		ammo_reserve = 50,
		ammo_pallets = 1,
		time_fire = 1/2,
		time_reload = 2.5,
		is_reload_perclip = false,
		
		spread = 0.0, -- THAT'S RIGHT, THE 0.75 RIFLE SUCKS
		recoil_x = 0.0001,
		recoil_y = -0.05,
		
		enabled = true,
	},
	[WPN_NOOB] = {
		-- version: hacked 0.60 patch 11
		dmg_head = 34,
		dmg_body = 30,
		dmg_limb = 21,
		
		ammo_clip = 20,
		ammo_reserve = 120,
		ammo_pallets = 1,
		time_fire = 1/15,
		time_reload = 5.0,
		is_reload_perclip = false,
		
		spread = 0.006, -- This is the 0.75 rifle spread.
		recoil_x = 0.001,
		recoil_y = -0.05,
		
		enabled = false,
	},
	[WPN_SHOTTY] = {
		-- version: something quite different.
		-- TODO: get the balance right!
		dmg_head = 26,
		dmg_body = 23,
		dmg_limb = 19,
		
		ammo_clip = 10,
		ammo_reserve = 50,
		ammo_pallets = 16,
		time_fire = 1/15,
		time_reload = 2.5,
		is_reload_perclip = false,
		
		spread = 0.015, -- No, this should not be good at range.
		recoil_x = 0.003,
		recoil_y = -0.12,
		
		enabled = false,
	},
}

function new_player(settings)
	local this = {} this.this = this this.this.this = this this = this.this
	
	this.team = settings.team or math.floor(math.random()*2)
	this.weapon = settings.weapon or WPN_RIFLE
	this.alive = false
	this.spawned = false
	
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
		this.x = math.floor(math.random()*xlen/4.0)+0.5
		this.z = math.floor(math.random()*zlen)+0.5
		this.y = (common.map_pillar_get(this.x, this.z))[1+1]-3.0
		
		if this.team == 1 then this.x = xlen - this.x end
		
		this.alive = true
		this.spawned = true
		
		this.grounded = false
		this.crouching = false
		this.scoped = false
		
		this.vx, this.vy, this.vz = 0, 0, 0
		this.angy, this.angx = math.pi/2.0, 0.0
		
		this.jerkoffs = 0.0
		
		this.zoom = 1.0
		
		this.health = 100
		this.ammo_clip = weapons[this.weapon].ammo_clip
		this.ammo_reserve = weapons[this.weapon].ammo_reserve
		
	end
	
	this.spawn()
	
	function this.tick(sec_current, sec_delta)
		-- clamp angle, YOU MUST NOT LOOK DIRECTLY UP OR DOWN!
		if this.angx > math.pi*0.499 then
			this.angx = math.pi*0.499
		elseif this.angx < -math.pi*0.499 then
			this.angx = -math.pi*0.499
		end
		
		-- set camera direction
		local sya = math.sin(this.angy)
		local cya = math.cos(this.angy)
		local sxa = math.sin(this.angx)
		local cxa = math.cos(this.angx)
		client.camera_point(sya*cxa, sxa, cya*cxa, zoom, 0.0)
		
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
		local mvspd = 8.0/this.zoom
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
		if this.scoped or this.ev_sneak then
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
			if MODE_SOFTCROUCH then this.jerkoffs = this.jerkoffs + jerky - ty1 end
		end
		
		this.x, this.y, this.z = tx1, ty1, tz1
		
		this.grounded = (MODE_AIRJUMP and this.grounded) or not box_is_clear(
			tx1-0.39, ty1+by2, tz1-0.39,
			tx1+0.39, ty1+by2+0.1, tz1+0.39)
		
		if this.vy > 0 and this.grounded then
			this.vy = 0
		end
	end
	
	function this.camera_firstperson()
		client.camera_move_to(this.x, this.y + this.jerkoffs, this.z)
		
	end
	
	function this.show_hud()
		client.model_render_bone_global(mdl_test, mdl_test_bone,
			120.5, 50.5, 150.5,
			rotpos*0.01, rotpos*0.004, 1.0+0.1*math.sin(rotpos*0.071))
		client.model_render_bone_local(mdl_test, mdl_test_bone,
			1-0.2, 600/800-0.2, 1.0,
			rotpos*0.01, rotpos*0.004, 0.1)
		client.model_render_bone_global(mdl_bbox, 
			(this.crouching and mdl_bbox_bone2) or mdl_bbox_bone1,
			this.x, this.y, this.z, 0, 0, 1)
		
		local w, h
		w, h = client.screen_get_dims()
		
		-- TODO ship this off to a library
		local function draw_digit(x, y, n, c)
			client.img_blit(img_font_numbers, x, y, 32, 48, digit_map[n]*32, 0, c)
		end
		
		local function print_mini(x, y, c, str)
			local i
			for i=1,#str do
				client.img_blit(img_font_mini, x, y, 6, 8, (string.byte(str,i)-32)*6, 0, c)
				x = x + 6
			end
		end
		
		local color = 0xFFA1FFA1
		local hstr = ""..this.health
		local astr = ""..this.ammo_clip.."-"..this.ammo_reserve
		
		local i
		for i=1,#hstr do
			draw_digit((i-1)*32+(w-32*#hstr)/2, h-48, string.sub(hstr,i,i), color)
		end
		for i=1,#astr do
			draw_digit((i-1)*32+w-32*#astr, h-48, string.sub(astr,i,i), 0xAA880000)
		end
		
		if debug_enabled then
			local camx,camy,camz
			camx,camy,camz = client.camera_get_pos()
			local cam_pos_str = string.format("x: %f y: %f z: %f c: %i"
				, camx, camy, camz, (this.crouching and 1) or 0)
			
			print_mini(4, 4, 0x80FFFFFF, cam_pos_str)
		end
	end
	
	return this
end

players = {max = 32}

-- set stuff
rotpos = 0.0
debug_enabled = false
mouse_released = false
sensitivity = 1.0/1000.0

-- create a test model

--[[
mdl_test = client.model_new(1)
print(client.model_len(mdl_test))
mdl_test_bone_data = {
	{radius=192, x= 0  ,y= 0  ,z= 0  , r=255,g=170,b=0  },
	{radius=96 , x= 256,y= 0  ,z= 0  , r=255,g=0  ,b=0  },
	{radius=96 , x= 0  ,y= 256,z= 0  , r=0  ,g=255,b=0  },
	{radius=96 , x= 0  ,y= 0  ,z= 256, r=0  ,g=0  ,b=255},
	{radius=96 , x=-256,y= 0  ,z= 0  , r=0  ,g=255,b=255},
	{radius=96 , x= 0  ,y=-256,z= 0  , r=255,g=0  ,b=255},
	{radius=96 , x= 0  ,y= 0  ,z=-256, r=255,g=255,b=0  },
}
mdl_test, mdl_test_bone = client.model_bone_new(mdl_test)
client.model_bone_set(mdl_test, mdl_test_bone, "test", mdl_test_bone_data)
]]
mdl_test = client.model_load_pmf("pkg/base/pmf/test.pmf")
mdl_test_bone = client.model_bone_find(mdl_test, "test")
--[[
client.model_bone_free(mdl_test, mdl_test_bone)
client.model_free(mdl_test)
mdl_test = nil -- PLEASE DO THIS, GUYS!
]]

mdl_bbox = client.model_new(1)
mdl_bbox_bone_data1 = {
	{radius=10, x = -100, y = -70, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = -70, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = -70, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = -70, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = 600, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = 600, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = 600, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = 600, z =  100, r = 255, g = 85, b = 85},
}
mdl_bbox_bone_data2 = {
	{radius=10, x = -100, y = -70, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = -70, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = -70, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = -70, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = 410, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = 410, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = 410, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = 410, z =  100, r = 255, g = 85, b = 85},
}
mdl_bbox, mdl_bbox_bone1 = client.model_bone_new(mdl_bbox)
mdl_bbox, mdl_bbox_bone2 = client.model_bone_new(mdl_bbox)
client.model_bone_set(mdl_bbox, mdl_bbox_bone1, "bbox_stand", mdl_bbox_bone_data1)
client.model_bone_set(mdl_bbox, mdl_bbox_bone2, "bbox_crouch", mdl_bbox_bone_data2)

-- load images
img_font_numbers = client.img_load("pkg/base/gfx/font-numbers.tga")
print(client.img_get_dims(img_font_numbers))
img_font_mini = client.img_load("pkg/base/gfx/font-mini.tga")
print(client.img_get_dims(img_font_mini))
--[[
client.img_free(img_font_numbers)
img_font_numbers = nil -- PLEASE DO THIS, GUYS!
]]

-- set hooks
function h_tick_camfly(sec_current, sec_delta)
	rotpos = rotpos + sec_delta*120.0
	
	players[1].tick(sec_current, sec_delta)
	players[1].camera_firstperson()
	-- wait a bit
	return 0.01
end


function h_tick_init(sec_current, sec_delta)
	players[1] = new_player({
		team = 0, -- 0 == blue, 1 == green
		weapon = WPN_RIFLE,
	})
	
	mouse_released = false
	client.mouse_lock_set(true)
	client.mouse_visible_set(false)
	
	client.hook_tick = h_tick_camfly
	return client.hook_tick(sec_current, sec_delta)
end

client.hook_tick = h_tick_init

function client.hook_key(key, state)
	if not players[1] then return end
	
	if key == SDLK_F5 then
		mouse_released = true
		client.mouse_lock_set(false)
		client.mouse_visible_set(true)
	elseif key == BTSK_QUIT then
		-- TODO: clean up
		client.hook_tick = nil
	elseif key == BTSK_FORWARD then
		players[1].ev_forward = state
	elseif key == BTSK_BACK then
		players[1].ev_back = state
	elseif key == BTSK_LEFT then
		players[1].ev_left = state
	elseif key == BTSK_RIGHT then
		players[1].ev_right = state
	elseif key == BTSK_CROUCH then
		players[1].ev_crouch = state
	elseif key == BTSK_JUMP then
		players[1].ev_jump = state
	elseif key == BTSK_SNEAK then
		players[1].ev_sneak = state
	elseif key == BTSK_DEBUG then
		if state then
			debug_enabled = not debug_enabled
		end
	end
end

function client.hook_mouse_button(button, state)
	-- TODO!
	mouse_released = false
	client.mouse_lock_set(true)
	client.mouse_visible_set(false)
end

function client.hook_mouse_motion(x, y, dx, dy)
	if not players[1] then return end
	if mouse_released then return end
	
	players[1].angy = players[1].angy - dx*math.pi*sensitivity
	players[1].angx = players[1].angx + dy*math.pi*sensitivity
end

digit_map = {
	[" "] = 0,
	["0"] = 1,
	["1"] = 2,
	["2"] = 3,
	["3"] = 4,
	["4"] = 5,
	["5"] = 6,
	["6"] = 7,
	["7"] = 8,
	["8"] = 9,
	["9"] = 10,
	["-"] = 11,
}

function client.hook_render()
	players[1].show_hud()
end

print("pkg/base/main_client.lua loaded.")

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

BTSK_LOOKUP    = SDLK_UP
BTSK_LOOKDOWN  = SDLK_DOWN
BTSK_LOOKLEFT  = SDLK_LEFT
BTSK_LOOKRIGHT = SDLK_RIGHT

BTSK_DEBUG = SDLK_F1

-- set stuff
zoom = 1.0
angx = 0.0
angy = 0.0
rotpos = 0.0
debug_enabled = false

pgravlev = 0.0

key_left = false
key_right = false
key_up = false
key_down = false

key_w = false
key_s = false
key_a = false
key_d = false
key_ctrl = false
key_space = false

-- create a test model
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
--[[
client.model_bone_free(mdl_test, mdl_test_bone)
client.model_free(mdl_test)
mdl_test = nil -- PLEASE DO THIS, GUYS!
]]

mdl_bbox = client.model_new(1)
mdl_bbox_bone_data = {
	{radius=10, x = -100, y = -70, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = -70, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = -70, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = -70, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = 600, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = 600, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = 600, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = 600, z =  100, r = 255, g = 85, b = 85},
}
mdl_bbox, mdl_bbox_bone = client.model_bone_new(mdl_bbox)
client.model_bone_set(mdl_bbox, mdl_bbox_bone, "bbox", mdl_bbox_bone_data)

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
	-- update angles
	if key_left then
		angy = angy + math.pi*sec_delta/zoom;
	end
	if key_right then
		angy = angy - math.pi*sec_delta/zoom;
	end
	if key_up then
		angx = angx - math.pi*sec_delta/zoom;
	end
	if key_down then
		angx = angx + math.pi*sec_delta/zoom;
	end
	
	-- clamp angle, YOU MUST NOT LOOK DIRECTLY UP OR DOWN!
	if angx > math.pi*0.499 then
		angx = math.pi*0.499
	elseif angx < -math.pi*0.499 then
		angx = -math.pi*0.499
	end
	
	-- set camera direction
	local sya = math.sin(angy)
	local cya = math.cos(angy)
	local sxa = math.sin(angx)
	local cxa = math.cos(angx)
	client.camera_point(sya*cxa, sxa, cya*cxa, zoom, 0.0)
	
	-- move along
	local mvx = 0.0
	local mvy = 0.0
	local mvz = 0.0
	
	if key_w then
		mvz = mvz + 1.0
	end
	if key_s then
		mvz = mvz - 1.0
	end
	if key_a then
		mvx = mvx + 1.0
	end
	if key_d then
		mvx = mvx - 1.0
	end
	if key_ctrl then
		--mvy = mvy + 1.0
		-- TODO: crouching
	end
	if key_space then
		pgravlev = -0.4
		key_space = false
	end
	mvy = mvy + pgravlev
	pgravlev = pgravlev + 1.5*sec_delta
	
	local mvspd = 8.0*sec_delta/zoom
	mvx = mvx * mvspd
	--mvy = mvy * mvspd
	mvz = mvz * mvspd
	
	local ox, oy, oz
	local nx, ny, nz
	ox, oy, oz = client.camera_get_pos()
	client.camera_move_local(mvx, 0, mvz)
	client.camera_move_global(0, mvy, 0)
	nx, ny, nz = client.camera_get_pos()
	
	ox, oy, oz = trace_map_box(
		ox, oy, oz,
		nx, ny, nz,
		-0.4, -0.3, -0.4,
		 0.4,  2.5,  0.4)
	
	if pgravlev > 0 and oy < ny then
		pgravlev = 0
	end
	
	client.camera_move_to(ox, oy, oz)
	
	rotpos = rotpos + sec_delta*120.0
	
	-- wait a bit
	return 0.01
end


function h_tick_init(sec_current, sec_delta)
	local xlen, ylen, zlen
	xlen, ylen, zlen = common.map_get_dims()
	print(xlen, ylen, zlen)
	
	local width, height
	width, height = client.screen_get_dims()
	print(width, height)
	
	local px, py, pz
	px = math.floor(xlen/4+0.5)
	pz = math.floor(zlen/4+0.5)
	
	local ptab = common.map_pillar_get(px, pz)
	py = ptab[1+ 1] - 3.5
	px = px + 0.5
	pz = pz + 0.5
	
	client.camera_move_to(px, py, pz)
	
	client.hook_tick = h_tick_camfly
	return client.hook_tick(sec_current, sec_delta)
end

client.hook_tick = h_tick_init

function client.hook_key(key, state)
	if key == BTSK_LOOKUP then
		key_up = state
	elseif key == BTSK_LOOKDOWN then
		key_down = state
	elseif key == BTSK_LOOKLEFT then
		key_left = state
	elseif key == BTSK_LOOKRIGHT then
		key_right = state
	elseif key == BTSK_FORWARD then
		key_w = state
	elseif key == BTSK_BACK then
		key_s = state
	elseif key == BTSK_LEFT then
		key_a = state
	elseif key == BTSK_RIGHT then
		key_d = state
	elseif key == BTSK_CROUCH then
		key_ctrl = state
	elseif key == BTSK_JUMP then
		key_space = state
	elseif key == BTSK_DEBUG then
		if state then
			debug_enabled = not debug_enabled
		end
	end
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
	local x,y,z
	x,y,z = client.camera_get_pos()
	client.model_render_bone_global(mdl_test, mdl_test_bone,
		120.5, 50.5, 150.5,
		rotpos*0.01, rotpos*0.004, 1.0+0.1*math.sin(rotpos*0.071))
	client.model_render_bone_local(mdl_test, mdl_test_bone,
		1-0.2, 600/800-0.2, 1.0,
		rotpos*0.01, rotpos*0.004, 0.1)
	client.model_render_bone_global(mdl_bbox, mdl_bbox_bone,
		x, y, z, 0, 0, 1)
	
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
	local health = 100
	local ammo_clip = 10
	local ammo_reserve = 50
	local hstr = ""..health
	local astr = ""..ammo_clip.."-"..ammo_reserve
	
	local i
	for i=1,#hstr do
		draw_digit((i-1)*32+(w-32*#hstr)/2, h-48, string.sub(hstr,i,i), color)
	end
	for i=1,#astr do
		draw_digit((i-1)*32+w-32*#astr, h-48, string.sub(astr,i,i), 0xAA880000)
	end
	
	if debug_enabled then
		local ox, oy, oz
		ox, oy, oz = client.camera_get_pos()
		local cam_pos_str = string.format("x: %f y: %f z: %f", ox, oy, oz)
		
		print_mini(4, 4, 0x80FFFFFF, cam_pos_str)
	end
end

print("pkg/base/main_client.lua loaded.")

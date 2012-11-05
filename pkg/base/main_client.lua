--[[
    This file is part of BtS Lua Components.

    BtS Lua Components is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    BtS Lua Components is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with BtS Lua Components.  If not, see <http://www.gnu.org/licenses/>.
]]

print("pkg/base/main_client.lua starting")

-- load libs
dofile("pkg/base/lib_sdlkey.lua")

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

-- set stuff
zoom = 1.0
angx = 0.0
angy = 0.0

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
		mvy = mvy + 1.0
	end
	if key_space then
		mvy = mvy - 1.0
	end
	
	local mvspd = 12.0*sec_delta/zoom
	mvx = mvx * mvspd
	mvy = mvy * mvspd
	mvz = mvz * mvspd
	
	client.camera_move_local(mvx, mvy, mvz)
	
	-- wait a bit
	return 0.01
end

function h_tick_init(sec_current, sec_delta)
	local xlen, ylen, zlen
	xlen, ylen, zlen = common.get_map_dims()
	print(xlen, ylen, zlen)
	
	local px, py, pz
	px = math.floor(xlen/4+0.5)
	pz = math.floor(zlen/4+0.5)
	
	local ptab = common.get_map_pillar(px, pz)
	py = ptab[1+ 1] - 2.5
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
	end
end

print("pkg/base/main_client.lua loaded.")

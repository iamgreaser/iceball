--[[
Copyright (c) 2014 Team Sparkle

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]

mouse_locked = true
mouse_dead_frames = 5
noclip = false

-- LOAD THE FONT STUFF EARLY.
dofile("pkg/iceball/lib/font.lua")

-- Include a bunch of libraries like a boss.
dofile("pkg/iceball/lib/map.lua")
dofile("pkg/iceball/lib/player.lua")
dofile("pkg/iceball/lib/phys.lua")
dofile("pkg/iceball/lib/vector.lua")
dofile("pkg/iceball/lib/wobj.lua")
dofile("pkg/base/lib_sdlkey.lua")

-- Here's some version information while you wait for me to do everything ever.
-- Or you could help by not making me have to do everything ever.
print("Iceball Version:  "..common.version.str)
print("MK Fork Revision: "..common.fork_marikiri_ver.num)

-- Set up the player stuff.
players = {
	p = {},
}

-- We can play music like this...
--mus = common.mus_load_it("pkg/iceball/launch/dfg.it")
--client.mus_play(mus)

-- Let's load a map!
map = common.map_load("*MAP")
-- BUG: locally-loaded maps will automatically set the map,
-- but server-loaded maps will NOT.
common.map_set(map)

local lx, ly, lz = common.map_get_dims()
client.map_fog_set(16, 0, 64, 1000)

-- Set up a "camera". This will be moved into some sort of "generic" "object" "class".
-- (3 OO terms in a row. Wow.)

do
	local lx, ly, lz = common.map_get_dims()
	cam = cam_new {
		p = vec(lx/2+0.5, common.map_pillar_get(lx/2, lz/2)[1+1]-2.6, lz/2+0.5, 1),
		f = norm3(vec(1.0, 0.0, 1.0)),
		phys = phys_map_abox {
			v1 = vec(-0.4, -0.4, -0.4),
			v2 = vec( 0.4,  2.5,  0.4),
		},
		phys_crouch = phys_map_abox {
			v1 = vec(-0.4, -0.4, -0.4),
			v2 = vec( 0.4,  1.5,  0.4),
		},
		vl2d = true,
		grav = 1,
		damp = 3.0,
		aclimb = true,
	}
end

-- Keyboard handler. Hopefully this time we'll actually read that "uni" thing when the chat is set up.
function client.hook_key(key, state, modif, uni)
	local kmul = (state and 1.0) or 0.0
	local spd = (noclip and 25.0) or 50.0
	local aspd = math.pi * 2 * 3/4

	if false then
	elseif key == SDLK_ESCAPE then client.hook_tick = nil
	elseif key == SDLK_w then cam.vp.z = kmul * spd
	elseif key == SDLK_s then cam.vn.z = kmul * spd
	elseif key == SDLK_d then cam.vp.x = kmul * spd
	elseif key == SDLK_a then cam.vn.x = kmul * spd
	--elseif key == SDLK_LEFT then cam.vayp = kmul * aspd
	--elseif key == SDLK_RIGHT then cam.vayn = kmul * aspd
	--elseif key == SDLK_DOWN then cam.vaxp = kmul * aspd
	--elseif key == SDLK_UP then cam.vaxn = kmul * aspd
	elseif cam.vl2d then
		if false then
		elseif key == SDLK_LCTRL then cam.crouch_key = state
		elseif key == SDLK_SPACE then cam.jump_key = state
		end
	else
		if false then
		elseif key == SDLK_LCTRL then cam.vp.y = kmul * spd
		elseif key == SDLK_SPACE then cam.vn.y = kmul * spd
		end
	end

	if state and key == SDLK_BACKSLASH then
		noclip = not noclip
		if noclip then
			cam.vl2d = false
			cam.grav = 0
		else
			cam.vl2d = true
			cam.grav = 1
		end
		cam.al = vec()
		cam.ag = vec()
		cam.vl = vec()
		cam.vg = vec()
	end

	if state and key == SDLK_F5 then
		mouse_locked = not mouse_locked
		client.mouse_lock_set(mouse_locked)
		client.mouse_visible_set(not mouse_locked)
	end
end

-- Mouse motion handler.
function client.hook_mouse_motion(x, y, dx, dy)
	if mouse_locked then
		if mouse_dead_frames > 0 then
			mouse_dead_frames = mouse_dead_frames - 1
		else
			cam.ay = cam.ay - dx*math.pi / 500.0
			cam.ax = cam.ax + dy*math.pi / 500.0
		end
	end
end

-- This happens every time the game decides we're going to do something.
function client.hook_tick(sec_current, sec_delta)
	-- Currently there's a "spike" with sec_delta.
	-- We need to curb this "spike".
	sec_delta = math.max(0.0, math.min(sec_delta, 1.0))
	--sec_delta = sec_delta * 0.30

	-- Move along.
	cam.tick(sec_current, sec_delta)

	-- Actually set the camera's position and direction.
	client.camera_move_to(devec3(add_vv(cam.p, cam.ac_jerk)))
	client.camera_point(cam.f.x, cam.f.y, cam.f.z, cam.zoom)

	-- TEST: Raise random pillars.
	-- NOTE: These do not result in a properly valid map.
	if false then
		local i
		for i=1,20 do
			local lx, ly, lz = common.map_get_dims()
			local x = math.floor(math.random() * lx)
			local z = math.floor(math.random() * lz)
			local l = common.map_pillar_get(x, z)
			if l[1+1] <= l[1+2] and l[1+1] > 0 then
				l[1+1] = l[1+1] - 1
				l[1+2] = l[1+2] - 1
				common.map_pillar_set(x, z, l)
			end
		end
	end

	return 1.0/60.0
end

function client.hook_render()
	local h = font_dejavu_bold[18].iheight
	font_dejavu_bold[18].render(0, h*0
		, string.format("Position:  %8.4f %8.4f %8.4f", devec3(cam.p))
		, 0x55FFFFFF)
	font_dejavu_bold[18].render(0, h*1
		, string.format("Direction: %8.4f %8.4f %8.4f", devec3(cam.f))
		, 0x55FFFFFF)
	font_dejavu_bold[18].render(0, h*2
		, "ESC = quit | F5 = toggle grab | \\ = toggle noclip"
		, 0x55FFFFFF)
end

-- Finally, lock the mouse.
client.mouse_lock_set(true)
client.mouse_visible_set(false)



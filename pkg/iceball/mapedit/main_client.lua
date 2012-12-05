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

print("Starting map editor...")

map_loaded = nil
do
	args = {...}
	if #args == 3 or #args == 4 then
		xlen, ylen, zlen = 0+args[1], 0+args[2], 0+args[3]
		fname = args[4] or "clsave/vol/newmap.icemap"
		map_loaded = common.map_new(xlen, ylen, zlen)
	elseif #args == 1 or #args == 2 then
		fname = args[1]
		map_loaded = common.map_load(fname)
		fname = args[2] or "clsave/vol/lastmap.icemap"
	else
		print("usage:")
		print("  iceball -s 0 pkg/iceball/mapedit loadmap.vxl/icemap savemap.icemap")
		print("  iceball -s 0 pkg/iceball/mapedit xlen ylen zlen savemap.icemap")
		error()
	end
end

common.map_set(map_loaded)
xlen, ylen, zlen = common.map_get_dims()

dofile("pkg/base/lib_gui.lua")
dofile("pkg/base/lib_sdlkey.lua")
dofile("pkg/base/lib_map.lua")
dofile("pkg/base/lib_vector.lua")

ev_mf = false
ev_mb = false
ev_ml = false
ev_mr = false
ev_mu = false
ev_md = false

ev_spd = false
ev_snk = false

camx, camy, camz = xlen/2+0.5, 0.5, zlen/2+0.5
camrx, camry = 0, 0
released = false
client.mouse_lock_set(true)
client.mouse_visible_set(false)

function cam_calc_fw()
	local sya = math.sin(camry)
	local cya = math.cos(camry)
	local sxa = math.sin(camrx)
	local cxa = math.cos(camrx)
	
	return sya*cxa, sxa, cya*cxa
end

function client.hook_key(key, state, modif)
	if key == SDLK_w then
		ev_mf = state
	elseif key == SDLK_s then
		ev_mb = state
	elseif key == SDLK_a then
		ev_ml = state
	elseif key == SDLK_d then
		ev_mr = state
	elseif key == SDLK_SPACE then
		ev_mu = state
	elseif key == SDLK_LCTRL then
		ev_md = state
	elseif key == SDLK_LSHIFT then
		ev_spd = state
	elseif key == SDLK_v then
		ev_snk = state
	elseif state then
		if key == SDLK_F5 then
			released = true
			client.mouse_lock_set(false)
			client.mouse_visible_set(true)
		end
	else
		if key == SDLK_ESCAPE then
			client.hook_tick = nil
		elseif key == SDLK_F10 then
			if common.map_save(map_loaded, fname) then
				print("map saved to "..fname)
			end
		end
	end
end

function client.hook_mouse_button(button, state)
	if released then
		if not state then
			client.mouse_lock_set(true)
			client.mouse_visible_set(false)
			released = false
		end
		return
	end
	if state then
		if button == 1 then
			-- LMB - BREAK
			if trx2 then
				map_block_delete(trx2,try2,trz2)
			end
		elseif button == 3 then
			-- RMB - BUILD
			if trx1 then
				-- TODO: allow setting block colour
				map_block_set(trx1,try1,trz1,1,128,128,128)
			end
		end
	else
		
	end
end

function client.hook_mouse_motion(x, y, dx, dy)
	if released then return end
	
	camry = camry - dx*math.pi/2000.0
	camrx = camrx + dy*math.pi/2000.0
end

trx1,try1,trz1 = nil, nil, nil
trx2,try2,trz2 = nil, nil, nil
trd = nil

function client.hook_tick(sec_current, sec_delta)
	-- update camera
	if camrx > math.pi*0.499 then
		camrx = math.pi*0.499
	elseif camrx < -math.pi*0.499 then
		camrx = -math.pi*0.499
	end
	
	local cvx,cvy,cvz
	cvx,cvy,cvz = 0,0,0
	if ev_mf then cvz = cvz + 1 end
	if ev_mb then cvz = cvz - 1 end
	if ev_ml then cvx = cvx - 1 end
	if ev_mr then cvx = cvx + 1 end
	if ev_mu then cvy = cvy - 1 end
	if ev_md then cvy = cvy + 1 end
	
	local cpx,cpy,cpz
	local cd2
	cpx,cpy,cpz = cam_calc_fw()
	cd2 = math.sqrt(cpx*cpx+cpz*cpz)
	cvx = cvx / cd2
	
	local cspd = sec_delta * 10.0
	if ev_spd then cspd = cspd * 3 end
	if ev_snk then cspd = cspd / 3 end
	camx = camx + cspd*(cvz*cpx-cvx*cpz)
	camz = camz + cspd*(cvz*cpz+cvx*cpx)
	camy = camy + cspd*(cvz*cpy+cvy)
	
	camx = math.min(math.max(0.5, camx), xlen-0.5)
	camy = math.min(math.max(0.5, camy), ylen-0.5)
	camz = math.min(math.max(0.5, camz), zlen-0.5)
	
	client.camera_point(cpx,cpy,cpz)
	client.camera_move_to(camx,camy,camz)
	
	-- do a trace
	trd, trx1,try1,trz1, trx2,try2,trz2
	= trace_map_ray_dist(camx,camy,camz, cpx,cpy,cpz, 10)
	
	return 0.001
end

function client.hook_render()
	local s
	s = string.format("EDITOR: %d %d %d"
		,camx,camy,camz)
	gui_print_mini(3, 3, 0xFF000000, s)
	gui_print_mini(2, 2, 0xFFFFFFFF, s)
	if trx2 then
		s = string.format("point %d %d %d"
			,trx2,try2,trz2)
		gui_print_mini(3, 11, 0xFF000000, s)
		gui_print_mini(2, 10, 0xFFFFFFFF, s)
	end
end

print("Loaded map editor.")

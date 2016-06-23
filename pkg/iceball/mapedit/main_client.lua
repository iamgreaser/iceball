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

screen_width, screen_height = client.screen_get_dims()

map_loaded = nil
fname = nil
do
	args = {...}
	if #args == 3 or #args == 4 then
		xlen, ylen, zlen = 0+args[1], 0+args[2], 0+args[3]
		fname = args[4] or "clsave/vol/newmap.icemap"
		map_loaded = common.map_new(xlen, ylen, zlen)
	elseif #args == 1 or #args == 2 then
		fname = args[1]
		map_loaded = common.map_load(fname)
		fname = args[2] or fname
	elseif #args == 0 then
		menu_main = {title="Main Menu", sel=2, "New Map", "Load Map"}
		menu_select = {title="Select Save Slot", sel=1, 0,1,2,3,4,5,6,7,8,9}
		menu_size_xlen = {title="Select Horiz Length", sel=3, 128, 256, 512}
		menu_size_zlen = {title="Select Vert Length", sel=3, 128, 256, 512}
		menu_size_ylen = {title="Select Height", sel=8, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128}
		
		menu_current = nil
		
		local function set_menu(menu)
			menu_current = menu
			menu_current.sel = menu_current.sel or 1
		end
		
		local function handle_menu()
			local menu = menu_current
			if menu == menu_main then
				set_menu(menu_select)
			elseif menu == menu_select then
				fname = "clsave/vol/save"..menu_select[menu_select.sel]..".icemap"
				if menu_main.sel == 1 then
					set_menu(menu_size_xlen)
				else
					map_loaded = common.map_load(fname)
					initiate_everything()
				end
			elseif menu == menu_size_xlen then
				set_menu(menu_size_zlen)
			elseif menu == menu_size_zlen then
				set_menu(menu_size_ylen)
			elseif menu == menu_size_ylen then
				xlen = menu_size_xlen[menu_size_xlen.sel]
				ylen = menu_size_ylen[menu_size_ylen.sel]
				zlen = menu_size_zlen[menu_size_zlen.sel]
				map_loaded = common.map_new(xlen, ylen, zlen)
				initiate_everything()
			else
				error("menu doesn't have a handler!")
			end
		end
		
		set_menu(menu_main)
		
		function client.hook_tick(sec_current, sec_delta)
			return 0.001
		end
		
		function client.hook_render()			
			local i, s
			
			s = menu_current.title
			font_mini.print(math.floor((screen_width-6*#s)/2), math.floor(screen_height/2-12),
				0xFF000000, s)
			
			for i=1,#menu_current do
				s = ""..menu_current[i]
				if menu_current.sel == i then
					s = "> "..s.." <"
				end
				
				font_mini.print(math.floor((screen_width-6*#s)/2), math.floor(screen_height/2+(i-1)*6),
					0xFF000000, s)
			end
		end
		
		function client.hook_key(key, state, modif)
			if state then
				if key == SDLK_UP then
					menu_current.sel = menu_current.sel - 1
					if menu_current.sel < 1 then
						menu_current.sel = #menu_current
					end
				elseif key == SDLK_DOWN then
					menu_current.sel = menu_current.sel + 1
					if menu_current.sel > #menu_current then
						menu_current.sel = 1
					end
				elseif key == SDLK_RETURN then
					handle_menu()
				end
			else
				if key == SDLK_ESCAPE then
					client.hook_tick = nil
				end
			end
		end
	else
		print("usage:")
		print("  iceball -l pkg/iceball/mapedit loadmap.vxl/icemap savemap.icemap")
		print("  iceball -l pkg/iceball/mapedit loadandsavemap.icemap")
		print("  iceball -l pkg/iceball/mapedit xlen ylen zlen savemap.icemap")
		error("check stdout for usage!")
	end
end

dofile("pkg/base/preconf.lua")
dofile("pkg/base/lib_bits.lua")
dofile("pkg/base/lib_gui.lua")
dofile("pkg/base/lib_sdlkey.lua")
dofile("pkg/base/lib_map.lua")
dofile("pkg/base/lib_util.lua")
dofile("pkg/base/lib_vector.lua")

function initiate_everything()
-- *** START INITIATION FUNCTION *** --

common.map_set(map_loaded)
client.map_fog_set(192, 238, 255, 1000)
xlen, ylen, zlen = common.map_get_dims()

mdl_test = client.model_load_pmf("pkg/base/pmf/test.pmf")
mdl_test_bone = client.model_bone_find(mdl_test, "test")

ev_mf = false
ev_mb = false
ev_ml = false
ev_mr = false
ev_mu = false
ev_md = false

ev_spd = false
ev_snk = false

TOOL_MCPAIR = 1
TOOL_SELECT = 2
TOOL_PAINT = 3

lastmx,lastmy = 0,0
camx, camy, camz = xlen/2+0.5, 0.5, zlen/2+0.5
camrx, camry = 0, 0
colr, colg, colb = 128, 128, 128
colt = 1
-- TODO: not hardcode the width/height
cpstartx, cpstarty = math.floor((800-768)/2), math.floor((600-512)/2)

selx1,sely1,selz1 = nil,nil,nil
selx2,sely2,selz2 = nil,nil,nil
tool = TOOL_MCPAIR
released = false
cpick = false
cpaint = false
client.mouse_lock_set(true)
client.mouse_visible_set(false)

function color_pick(x,y)
	local r = math.floor(255*(math.sin(x*math.pi/384)+1)/2)
	local g = math.floor(255*(math.sin(x*math.pi/384+2*math.pi/3)+1)/2)
	local b = math.floor(255*(math.sin(x*math.pi/384+4*math.pi/3)+1)/2)
	
	if y < 256 then
		local h = (255-y)/255
		return math.floor(r*(1-h)+255*h), math.floor(g*(1-h)+255*h), math.floor(b*(1-h)+255*h)
	else
		local h = (255-(y-256))/255
		return math.floor(r*h), math.floor(g*h), math.floor(b*h)
	end
end

function tool_getname()
	if tool == TOOL_MCPAIR then
		return "Minecraft"
	elseif tool == TOOL_SELECT then
		return "Select"
	elseif tool == TOOL_PAINT then
		return "Paint"
	else
		return "???"
	end
end

function cam_calc_fw()
	local sya = math.sin(camry)
	local cya = math.cos(camry)
	local sxa = math.sin(camrx)
	local cxa = math.cos(camrx)
	
	return sya*cxa, sxa, cya*cxa
end

function client.hook_key(key, state, modif)
	if key == SDLK_w and bit_and(modif,KMOD_LALT) == 0 then
		ev_mf = state
	elseif key == SDLK_s and bit_and(modif,KMOD_LALT) == 0 then
		ev_mb = state
	elseif key == SDLK_a and bit_and(modif,KMOD_LALT) == 0 then
		ev_ml = state
	elseif key == SDLK_d and bit_and(modif,KMOD_LALT) == 0 then
		ev_mr = state
	elseif key == SDLK_SPACE then
		ev_mu = state
	elseif key == SDLK_LCTRL then
		ev_md = state
	elseif key == SDLK_LSHIFT then
		ev_spd = state
	elseif key == SDLK_v and bit_and(modif,KMOD_LALT) == 0 then
		ev_snk = state
	elseif key == SDLK_1 then
		tool = TOOL_MCPAIR
	elseif key == SDLK_2 then
		tool = TOOL_SELECT
	elseif key == SDLK_3 then
		tool = TOOL_PAINT
	elseif state then
		if key == SDLK_F5 then
			released = true
			client.mouse_lock_set(false)
			client.mouse_visible_set(true)
		elseif key == SDLK_TAB then
			cpick = true
			released = true
			client.mouse_lock_set(false)
			client.mouse_visible_set(true)
		elseif key == SDLK_LEFTBRACKET then
			colt = colt - 1
			if colt < 1 then colt = 1 end
		elseif key == SDLK_RIGHTBRACKET then
			colt = colt + 1
			if colt > 255 then colt = 255 end
		elseif key == SDLK_INSERT then
			if selx1 and selx2 then
				local x,y,z
				for x=math.min(selx1,selx2),math.max(selx1,selx2) do
				for y=math.min(sely1,sely2),math.max(sely1,sely2) do
				for z=math.min(selz1,selz2),math.max(selz1,selz2) do
					map_block_set(x,y,z,colt,colr,colg,colb)
				end
				end
				end
			end
		elseif key == SDLK_DELETE then
			if selx1 and selx2 then
				local x,y,z
				for x=math.min(selx1,selx2),math.max(selx1,selx2) do
				for y=math.min(sely1,sely2),math.max(sely1,sely2) do
				for z=math.min(selz1,selz2),math.max(selz1,selz2) do
					map_block_delete(x,y,z)
				end
				end
				end
			end
		elseif key == SDLK_p and bit_and(modif,KMOD_LALT) == 0 then
			if selx1 and selx2 then
				local x,y,z
				for x=math.min(selx1,selx2),math.max(selx1,selx2) do
				for y=math.min(sely1,sely2),math.max(sely1,sely2) do
				for z=math.min(selz1,selz2),math.max(selz1,selz2) do
					if map_block_get(x,y,z) then
						map_block_paint(x,y,z,colt,colr,colg,colb)
					end
				end
				end
				end
			end
		elseif bit_and(modif,KMOD_LALT) ~= 0 then
			if not(selx1 and selx2) then
				----------------
				-- do nothing --
				----------------
			elseif key == SDLK_s then
				local cpx,cpy,cpz
				cpx,cpy,cpz = cam_calc_fw()
				local gx,gy,gz
				gx, gy, gz = 0, 0, 0
				if math.abs(cpx) > math.abs(cpy) and math.abs(cpx) > math.abs(cpz) then
					gx = (cpx < 0 and -1) or 1
				elseif math.abs(cpy) > math.abs(cpx) and math.abs(cpy) > math.abs(cpz) then
					gy = (cpy < 0 and -1) or 1
				else
					gz = (cpz < 0 and -1) or 1
				end
				
				gx = gx * (math.abs(selx1-selx2)+1)
				gy = gy * (math.abs(sely1-sely2)+1)
				gz = gz * (math.abs(selz1-selz2)+1)
				local x,y,z
				for x=math.min(selx1,selx2),math.max(selx1,selx2) do
				for y=math.min(sely1,sely2),math.max(sely1,sely2) do
				for z=math.min(selz1,selz2),math.max(selz1,selz2) do
					local l = map_block_get(x,y,z)
					if l then
						map_block_set(x+gx,y+gy,z+gz,l[1],l[2],l[3],l[4])
					elseif l == false then
						map_block_aerate(x+gx,y+gy,z+gz)
					else
						map_block_delete(x+gx,y+gy,z+gz)
					end
				end
				end
				end
				selx1 = selx1 + gx
				sely1 = sely1 + gy
				selz1 = selz1 + gz
				selx2 = selx2 + gx
				sely2 = sely2 + gy
				selz2 = selz2 + gz
			elseif key == SDLK_a then
				local cpx,cpy,cpz
				cpx,cpy,cpz = cam_calc_fw()
				local gx,gy,gz
				gx, gy, gz = 0, 0, 0
				if math.abs(cpx) > math.abs(cpy) and math.abs(cpx) > math.abs(cpz) then
					gx = (cpx < 0 and -1) or 1
				elseif math.abs(cpy) > math.abs(cpx) and math.abs(cpy) > math.abs(cpz) then
					gy = (cpy < 0 and -1) or 1
				else
					gz = (cpz < 0 and -1) or 1
				end
				
				gx = gx * (math.abs(selx1-selx2)+1)
				gy = gy * (math.abs(sely1-sely2)+1)
				gz = gz * (math.abs(selz1-selz2)+1)
				local x,y,z
				for x=math.min(selx1,selx2),math.max(selx1,selx2) do
				for y=math.min(sely1,sely2),math.max(sely1,sely2) do
				for z=math.min(selz1,selz2),math.max(selz1,selz2) do
					local l = map_block_get(x,y,z)
					if l then
						map_block_set(x+gx,y+gy,z+gz,l[1],l[2],l[3],l[4])
					elseif l == false then
						map_block_aerate(x+gx,y+gy,z+gz)
					end
				end
				end
				end
				selx1 = selx1 + gx
				sely1 = sely1 + gy
				selz1 = selz1 + gz
				selx2 = selx2 + gx
				sely2 = sely2 + gy
				selz2 = selz2 + gz
			end
		end
	else
		if key == SDLK_ESCAPE then
			if cpick then
				client.mouse_lock_set(true)
				client.mouse_visible_set(false)
				released = false
				cpick = false
			else
				client.hook_tick = nil
			end
		elseif key == SDLK_F10 then
			common.map_save(map_loaded, fname)
			print("map saved to: "..fname)
		end
	end
end

function client.hook_mouse_button(button, state)
	if released then
		if not state then
			client.mouse_lock_set(true)
			client.mouse_visible_set(false)
			released = false
			cpick = false
		elseif cpick then
			cpick = 2
		end
		return
	end
	if state then
		if button == 1 and tool == TOOL_MCPAIR then
			-- Minecraft tool: LMB - BREAK
			if trx2 then
				map_block_delete(trx2,try2,trz2)
			end
		elseif button == 1 and tool == TOOL_SELECT then
			-- Select tool: LMB - corner 1
			if trx2 then
				selx1,sely1,selz1 = trx2,try2,trz2
			end
		elseif button == 3 and tool == TOOL_MCPAIR then
			-- Minecraft tool: RMB - BUILD
			if trx1 then
				-- TODO: allow setting the type
				map_block_set(trx1,try1,trz1,colt,colr,colg,colb)
			end
		elseif button == 3 and tool == TOOL_PAINT then
			-- Paint tool: RMB - PAINT
			if trx2 then
				map_block_paint(trx2,try2,trz2,colt,colr,colg,colb)
			end
			paintx,painty,paintz = trx2,try2,trz2
			cpaint = true
		elseif button == 3 and tool == TOOL_SELECT then
			-- Select tool: LMB - corner 2
			if trx2 then
				selx2,sely2,selz2 = trx2,try2,trz2
			end
		elseif button == 2 and (tool == TOOL_MCPAIR or tool == TOOL_PAINT) then
			-- Minecraft / Paint tool: MMB - PICK
			if trx2 then
				-- TODO: allow setting the type
				local l = map_block_get(trx2,try2,trz2)
				colr,colg,colb = l[2],l[3],l[4]
				colt = l[1]
			end
		end
	else
		if button == 3 and tool == TOOL_PAINT then
			-- Paint tool: RMB - PAINT
			cpaint = false
		end
	end
end

function client.hook_mouse_motion(x, y, dx, dy)
	if released then
		if cpick == 2 then
			if x >= cpstartx and y >= cpstarty
			and x < cpstartx+768 and y < cpstarty+512 then
				colr, colg, colb = color_pick(x-cpstartx,y-cpstarty)
			end
		end
		return
	end
	
	camry = camry - dx*math.pi/200.0
	camrx = camrx + dy*math.pi/200.0
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
	camy = math.min(camy, ylen-0.5)
	camz = math.min(math.max(0.5, camz), zlen-0.5)
	
	client.camera_point(cpx,cpy,cpz)
	client.camera_move_to(camx,camy,camz)
	
	-- do a trace
	trd, trx1,try1,trz1, trx2,try2,trz2
	= trace_map_ray_dist(camx,camy,camz, cpx,cpy,cpz, 10)
	
	-- paint if necessary
	if cpaint and trx2 then
	if paintx ~= trx2 or painty ~= try2 or paintz ~= trz2 then
		map_block_paint(trx2,try2,trz2,colt,colr,colg,colb)
		paintx,painty,paintz = trx2,try2,trz2
	end
	end
	
	return 0.001
end

function client.hook_render()
	local sw,sh
	sw,sh = client.screen_get_dims()
	
	local s
	s = string.format("EDITOR: %d %d %d - tool = %s"
		,camx,camy,camz
		,tool_getname())
	font_mini.print(3, 3, 0xFF000000, s)
	font_mini.print(2, 2, 0xFFFFFFFF, s)
	
	s = string.format("COLOUR %d %d %d (#%02X%02X%02X)"
		,colr,colg,colb
		,colr,colg,colb)
	font_mini.print(sw-(2+6*#s), 2, argb_split_to_merged(colr, colg, colb, 255), s)
	
	s = string.format("Select: %d %d %d -> %d %d %d"
		,selx1 or -1,sely1 or -1,selz1 or -1
		,selx2 or -1,sely2 or -1,selz2 or -1)
	font_mini.print(sw-(2+6*#s)+1, 19, 0xFF000000, s)
	font_mini.print(sw-(2+6*#s), 18, 0xFFFFFFFF, s)
	
	s = string.format("Type = %d (%02X)"
		,colt,colt)
	font_mini.print(sw-(2+6*#s)+1, 11, 0xFF000000, s)
	font_mini.print(sw-(2+6*#s), 10, 0xFFFFFFFF, s)
	
	if trx2 then
		s = string.format("point %d %d %d"
			,trx2,try2,trz2)
		font_mini.print(3, 11, 0xFF000000, s)
		font_mini.print(2, 10, 0xFFFFFFFF, s)
	end
	
	if trx1 then
		client.model_render_bone_global(mdl_test, mdl_test_bone
			, trx1+0.5, try1+0.5, trz1+0.5
			, 0, 0, 0, 0.3)
	end
	if tool == TOOL_SELECT then
		if selx1 then
			client.model_render_bone_global(mdl_test, mdl_test_bone
				, selx1+0.5, sely1+0.5, selz1+0.5
				, 0, 0, 0, 1)
		end
		if selx2 then
			client.model_render_bone_global(mdl_test, mdl_test_bone
				, selx2+0.5, sely2+0.5, selz2+0.5
				, 0, 0, 0, 1)
		end
	end
	
	if cpick then
		client.img_blit(img_palette, cpstartx, cpstarty)
	end
end

img_palette = common.img_new(768,512)
do
	local x,y
	print("Generating colour pick image")
	for x=0,767 do
		for y=0,511 do
			local h = (255-y)/255
			
			local r,g,b
			r,g,b = color_pick(x,y)
			common.img_pixel_set(img_palette, x, y,
				argb_split_to_merged(r, g, b, 255))
		end
	end
	print("Done")
end

-- *** END INITIATION FUNCTION *** --
end

if map_loaded then initiate_everything() end

print("Loaded map editor.")

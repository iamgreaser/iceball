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

print("pmfedit selected")
PMFEDIT_FNAME = "clsave/vol/editor.pmf"

BTSK_PMF_EDIT = SDLK_F2

BTSK_PMF_MOVEXN = SDLK_l
BTSK_PMF_MOVEXP = SDLK_j
BTSK_PMF_MOVEYN = SDLK_i
BTSK_PMF_MOVEYP = SDLK_k
BTSK_PMF_MOVEZN = SDLK_u
BTSK_PMF_MOVEZP = SDLK_o

BTSK_PMF_SIZEP = SDLK_EQUALS
BTSK_PMF_SIZEN = SDLK_MINUS

BTSK_PMF_ROTYN = SDLK_LEFTBRACKET
BTSK_PMF_ROTYP = SDLK_RIGHTBRACKET

BTSK_PMF_BLKSET = SDLK_g
BTSK_PMF_BLKCLEAR = SDLK_b

BTSK_PMF_QUICKLOAD = SDLK_F3
BTSK_PMF_QUICKSAVE = SDLK_F10

pmfedit_enabled = false
pmfedit_x = 0
pmfedit_y = 0
pmfedit_z = 0
pmfedit_size = 16
pmfedit_data = {}
pmfedit_model = common.model_new(1)
pmfedit_model, pmfedit_model_bone = common.model_bone_new(pmfedit_model)
pmfedit_data[#pmfedit_data+1] = {x=0,y=0,z=0,r=0,g=0,b=0,radius=1}
pmfedit_rx = 0

do
local old_tickhook = client.hook_tick
function pmfhook_tick(sec_current, sec_delta)
	pmfedit_data[#pmfedit_data] = {
		x=pmfedit_x,y=pmfedit_y,z=pmfedit_z-0.01,
		r=math.sin(sec_current-2*math.pi/3)*127+128,
		g=math.sin(sec_current)*127+128,
		b=math.sin(sec_current+2*math.pi/3)*127+128,
		radius=pmfedit_size}
	common.model_bone_set(pmfedit_model, pmfedit_model_bone, "edit", pmfedit_data)
	
	-- chain along
	client.hook_tick = old_tickhook
	local ret = old_tickhook(sec_current, sec_delta)
	old_tickhook = client.hook_tick
	client.hook_tick = pmfhook_tick
	return ret
end
client.hook_tick = pmfhook_tick

local old_keyhook = client.hook_key
function client.hook_key(key, state, modif)
	if state then
		if pmfedit_enabled then
			if key == BTSK_PMF_MOVEXN then
				pmfedit_x = pmfedit_x - pmfedit_size
			elseif key == BTSK_PMF_MOVEXP then
				pmfedit_x = pmfedit_x + pmfedit_size
			elseif key == BTSK_PMF_MOVEYN then
				pmfedit_y = pmfedit_y - pmfedit_size
			elseif key == BTSK_PMF_MOVEYP then
				pmfedit_y = pmfedit_y + pmfedit_size
			elseif key == BTSK_PMF_MOVEZN then
				pmfedit_z = pmfedit_z - pmfedit_size
			elseif key == BTSK_PMF_MOVEZP then
				pmfedit_z = pmfedit_z + pmfedit_size
			elseif key == BTSK_PMF_SIZEN and pmfedit_size > 1 then
				pmfedit_size = pmfedit_size - 1
			elseif key == BTSK_PMF_SIZEP and pmfedit_size < 65535 then
				pmfedit_size = pmfedit_size + 1
			elseif key == SDLK_LEFTBRACKET then
				pmfedit_rx = pmfedit_rx + math.pi/16
			elseif key == SDLK_RIGHTBRACKET then
				pmfedit_rx = pmfedit_rx - math.pi/16
			elseif key == BTSK_PMF_BLKSET and #pmfedit_data < 4095 then
				local plr = players[players.current]
				pmfedit_data[#pmfedit_data].r = plr.blk_color[1]
				pmfedit_data[#pmfedit_data].g = plr.blk_color[2]
				pmfedit_data[#pmfedit_data].b = plr.blk_color[3]
				pmfedit_data[#pmfedit_data+1] = pmfedit_data[#pmfedit_data]
			elseif key == BTSK_PMF_BLKCLEAR then
				if #pmfedit_data > 1 then
					local i
					local dx,dy,dz
					local d
					local mi,md
					mi = 1
					md = nil
					
					-- find nearest piece
					for i=1,#pmfedit_data-1 do
						dx = pmfedit_data[i].x - pmfedit_x
						dy = pmfedit_data[i].y - pmfedit_y
						dz = pmfedit_data[i].z - pmfedit_z
						
						d = dx*dx+dy*dy+dz*dz
						if md == nil or d < md then
							md = d
							mi = i
						end
					end
					
					-- delete it and move to it
					pmfedit_x = pmfedit_data[mi].x
					pmfedit_y = pmfedit_data[mi].y
					pmfedit_z = pmfedit_data[mi].z
					pmfedit_size = pmfedit_data[mi].radius
					for i=mi,#pmfedit_data-1 do
						pmfedit_data[i] = pmfedit_data[i+1]
					end
					pmfedit_data[#pmfedit_data] = nil
				end
			elseif key == BTSK_PMF_QUICKLOAD then
				local xpmf = common.model_load_pmf(PMFEDIT_FNAME)
				if xpmf then
					common.model_free(pmfedit_model) -- YECCH! Forgot this line!
					pmfedit_model = xpmf
					pmfedit_model_bone = 0
					local bname
					bname, pmfedit_data = common.model_bone_get(pmfedit_model, pmfedit_model_bone)
					pmfedit_data[#pmfedit_data+1] = {}
					print("loaded!")
				else
					print("error during loading - NOT LOADED")
				end
			elseif key == BTSK_PMF_QUICKSAVE then
				local xpt = pmfedit_data[#pmfedit_data]
				pmfedit_data[#pmfedit_data] = nil
				local bname, blah
				bname, blah = common.model_bone_get(pmfedit_model, pmfedit_model_bone)
				common.model_bone_set(pmfedit_model, pmfedit_model_bone, bname, pmfedit_data)
				if common.model_save_pmf(pmfedit_model, PMFEDIT_FNAME) then
					print("saved!")
				else
					print("error during saving - NOT SAVED")
				end
				pmfedit_data[#pmfedit_data+1] = xpt
			end
		end
		if key == BTSK_PMF_EDIT then
			pmfedit_enabled = not pmfedit_enabled
		end
	end
	return old_keyhook(key, state, modif)
end

local old_renderhook = client.hook_render
-- I still believe the "Old Kenderhook" explanation for the meaning of O.K. is a load of crap. --GM
function client.hook_render()
	if pmfedit_enabled then
		gui_print_mini(4,40,0x80FFFFFF,string.format(
			"PMF - size: %-6i x: %-6i y: %6i z: %-6i - COUNT: %6i / rot: %3f"
			,pmfedit_size
			,pmfedit_x
			,pmfedit_y
			,pmfedit_z
			,#pmfedit_data-1
			,pmfedit_rx))
		
		client.model_render_bone_local(pmfedit_model, pmfedit_model_bone,
			0,0,1,
			pmfedit_rx,0,0,
			0.7)
	end
	return old_renderhook()
end
end

print("pmfedit loaded")

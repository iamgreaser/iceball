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

dofile("pkg/base/lib_gui.lua")
dofile("pkg/base/lib_pmf.lua")
dofile("pkg/base/lib_sdlkey.lua")

preload = ...
PMFEDIT_FNAME = "clsave/vol/editor.pmf"

BTSK_PMF_MOVEXN = SDLK_l
BTSK_PMF_MOVEXP = SDLK_j
BTSK_PMF_MOVEYN = SDLK_i
BTSK_PMF_MOVEYP = SDLK_k
BTSK_PMF_MOVEZN = SDLK_u
BTSK_PMF_MOVEZP = SDLK_o

BTSK_PMF_SIZEP = SDLK_EQUALS
BTSK_PMF_SIZEN = SDLK_MINUS

BTSK_PMF_ROTYN = SDLK_a
BTSK_PMF_ROTYP = SDLK_d
BTSK_PMF_ROTXN = SDLK_w
BTSK_PMF_ROTXP = SDLK_s
BTSK_PMF_ROTY2N = SDLK_q
BTSK_PMF_ROTY2P = SDLK_e

BTSK_QUIT = SDLK_ESCAPE
BTSK_COLORLEFT  = SDLK_LEFT
BTSK_COLORRIGHT = SDLK_RIGHT
BTSK_COLORUP    = SDLK_UP
BTSK_COLORDOWN  = SDLK_DOWN

BTSK_PMF_BLKSET = SDLK_g
BTSK_PMF_BLKCLEAR = SDLK_b

BTSK_PMF_QUICKLOAD = SDLK_F3
BTSK_PMF_QUICKSAVE = SDLK_F10

pmfedit_x = 0
pmfedit_y = 0
pmfedit_z = 0
pmfedit_size = 16
pmfedit_data = {}
pmfedit_model = common.model_new(1)
pmfedit_model, pmfedit_model_bone = common.model_bone_new(pmfedit_model)
pmfedit_data[#pmfedit_data+1] = {x=0,y=0,z=0,r=0,g=0,b=0,radius=1}
pmfedit_ry = 0
pmfedit_rx = 0
pmfedit_ry2 = 0

blk_color = {128,128,128}
blk_color_x = 3
blk_color_y = 0

cpalette_base = {
	0x7F,0x7F,0x7F,
	0xFF,0x00,0x00,
	0xFF,0x7F,0x00,
	0xFF,0xFF,0x00,
	0x00,0xFF,0x00,
	0x00,0xFF,0xFF,
	0x00,0x00,0xFF,
	0xFF,0x00,0xFF,
}

cpalette = {}
do
	local i,j
	for i=0,7 do
		local r,g,b
		r = cpalette_base[i*3+1]
		g = cpalette_base[i*3+2]
		b = cpalette_base[i*3+3]
		for j=0,3 do
			local cr = math.floor((r*j)/3)
			local cg = math.floor((g*j)/3)
			local cb = math.floor((b*j)/3)
			cpalette[#cpalette+1] = {cr,cg,cb}
		end
		for j=1,4 do
			local cr = r + math.floor(((255-r)*j)/4)
			local cg = g + math.floor(((255-g)*j)/4)
			local cb = b + math.floor(((255-b)*j)/4)
			cpalette[#cpalette+1] = {cr,cg,cb}
		end
	end
end

function client.hook_tick(sec_current, sec_delta)
	blk_color = cpalette[(blk_color_y*8)+blk_color_x+1]

	pmfedit_data[#pmfedit_data] = {
		x=pmfedit_x,y=pmfedit_y,z=pmfedit_z-0.01,
		r=math.sin(sec_current-2*math.pi/3)*127+128,
		g=math.sin(sec_current)*127+128,
		b=math.sin(sec_current+2*math.pi/3)*127+128,
		radius=pmfedit_size}
	common.model_bone_set(pmfedit_model, pmfedit_model_bone, "edit", pmfedit_data)

	return 0.005
end

function client.hook_key(key, state)
	if state then
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
		elseif key == BTSK_COLORLEFT then
			blk_color_x = blk_color_x - 1
			if blk_color_x < 0 then
				blk_color_x = 7
			end
			blk_color = cpalette[blk_color_x+blk_color_y*8+1]
		elseif key == BTSK_COLORRIGHT then
			blk_color_x = blk_color_x + 1
			if blk_color_x > 7 then
				blk_color_x = 0
			end
			blk_color = cpalette[blk_color_x+blk_color_y*8+1]
		elseif key == BTSK_COLORUP then
			blk_color_y = blk_color_y - 1
			if blk_color_y < 0 then
				blk_color_y = 7
			end
			blk_color = cpalette[blk_color_x+blk_color_y*8+1]
		elseif key == BTSK_COLORDOWN then
			blk_color_y = blk_color_y + 1
			if blk_color_y > 7 then
				blk_color_y = 0
			end
			blk_color = cpalette[blk_color_x+blk_color_y*8+1]
		elseif key == BTSK_PMF_ROTYN then
			pmfedit_ry = pmfedit_ry + math.pi/16
		elseif key == BTSK_PMF_ROTYP then
			pmfedit_ry = pmfedit_ry - math.pi/16
		elseif key == BTSK_PMF_ROTXN then
			pmfedit_rx = pmfedit_rx + math.pi/16
		elseif key == BTSK_PMF_ROTXP then
			pmfedit_rx = pmfedit_rx - math.pi/16
		elseif key == BTSK_PMF_ROTY2N then
			pmfedit_ry2 = pmfedit_ry2 + math.pi/16
		elseif key == BTSK_PMF_ROTY2P then
			pmfedit_ry2 = pmfedit_ry2 - math.pi/16
		elseif key == BTSK_QUIT then
			client.hook_tick = nil
		elseif key == BTSK_PMF_BLKSET and #pmfedit_data < 4095 then
			pmfedit_data[#pmfedit_data].r = blk_color[1]
			pmfedit_data[#pmfedit_data].g = blk_color[2]
			pmfedit_data[#pmfedit_data].b = blk_color[3]
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
end

function client.hook_render()
	local c = 0xFF000000+256*(256*blk_color[3]+blk_color[2])+blk_color[1]
	font_mini.print(4,40,c,string.format(
		"PMF - size: %-6i x: %-6i y: %6i z: %-6i - COUNT: %6i / rot: %3f, %3f, %3f"
		,pmfedit_size
		,pmfedit_x
		,pmfedit_y
		,pmfedit_z
		,#pmfedit_data-1
		,pmfedit_ry
		,pmfedit_rx
		,pmfedit_ry2))

	client.model_render_bone_local(pmfedit_model, pmfedit_model_bone,
		0,0,1,
		pmfedit_ry,pmfedit_rx,pmfedit_ry2,
		0.7)
end

if preload then
	local xpmf = common.model_load_pmf(preload)
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
end

client.map_fog_set(32, 32, 32, 60)

print("pmfedit successfully loaded!")

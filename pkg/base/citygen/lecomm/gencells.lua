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

ROAD_BLOCK = { r = 45, 
						g = 45,
						b = 45}

CONCRETE_BLOCK = { r = 128, 
								g = 128,
								b = 128}

GRASS_BLOCK = { r = 0, 
							g = 128,
							b = 0}

xcells=32
zcells=32
xcsize=0
zcsize=0

cells={}
celldata={}

MIN_BUILDING_H=2
MAX_BUILDING_H=64

ROAD_W=12

HROAD_W=ROAD_W/2

FLOOR_Y=0

function gen_grass(xc, zc, xnl, xnr, znl, znr)
	x1=xc*xcsize
	z1=zc*zcsize
	for x=0, xcsize-1 do
		for z=0, zcsize-1 do
			map_block_set_randc(x+x1, FLOOR_Y, z+z1, GRASS_BLOCK.r, GRASS_BLOCK.g, GRASS_BLOCK.b)
		end
	end
end

function load_buildings()
	dofile(DIR_CITYGEN_BUILDINGS.."/basic_building.lua")
end

function gen_building(xc, zc, xnl, xnr, znl, znr)
	building = new_building({})
	local width, depth, height
	width = xcsize
	height = zcsize
	depth = celldata[xc][zc]
	building.build(xc*xcsize, FLOOR_Y-depth, zc*zcsize, width, depth, height)
end

-- xc = grid x ; zc = grid z ; xnl, xnr = left/right neighbour tiles ; znl, znr = upper/lower neighbour tiles
function gen_road(xc, zc, xnl, xnr, znl, znr)
	x1=xc*xcsize
	z1=zc*zcsize
	x2=x1+xcsize
	z2=z1+zcsize
	white_r=255
	white_g=255
	white_b=255
	
	-- build base "circle"
	powrange=(ROAD_W/2.0)*(ROAD_W/2.0)
	for x=0, xcsize-1 do
		for z=0, zcsize-1 do
			if (x+.5-xcsize/2.0)*(x+.5-xcsize/2.0)+(z+.5-zcsize/2.0)*(z+.5-zcsize/2.0)<=powrange then
				map_block_set_randc(x+x1, FLOOR_Y, z+z1, ROAD_BLOCK.r, ROAD_BLOCK.g, ROAD_BLOCK.b)
			end
		end
	end
	--TODO: move this code to a function gen_road_build(needed_vars,..., rotation)
	if znl==gen_road then
		midx=x1+xcsize/2
		for z=z1, z1+zcsize/2 do
			build_white_line=(z%4)~=0
			for x=midx-HROAD_W, midx+HROAD_W do
				continue=0
				c=map_block_get(x, FLOOR_Y, z)
				if c[2]==white_r and c[3]==white_g and c[4]==white_b then
					continue=1
				end
				if (x==midx) and build_white_line and continue==0 then
					map_block_set_randc(x, FLOOR_Y, z,  white_r, white_g, white_b)
					continue=1
				end
				if continue==0 then
					map_block_set_randc(x, FLOOR_Y, z, ROAD_BLOCK.r, ROAD_BLOCK.g, ROAD_BLOCK.b)
				end
			end
		end
	end
	if znr==gen_road then
		midx=x1+xcsize/2
		for z=z1+zcsize/2, z2 do
			build_white_line=(z%4)~=0
			for x=midx-HROAD_W, midx+HROAD_W do
				continue=0
				c=map_block_get(x, FLOOR_Y, z)
				if c[2]==white_r and c[3]==white_g and c[4]==white_b then
					continue=1
				end
				if (x==midx) and build_white_line and continue==0 then
					map_block_set_randc(x, FLOOR_Y, z,  white_r, white_g, white_b)
					continue=1
				end
				if continue==0 then
					map_block_set_randc(x, FLOOR_Y, z,  ROAD_BLOCK.r, ROAD_BLOCK.g, ROAD_BLOCK.b)
				end
			end
		end
	end
	if xnl==gen_road then
		midz=z1+zcsize/2
		for x=x1, x1+xcsize/2 do
			build_white_line=(x%4)~=0
			for z=midz-HROAD_W, midz+HROAD_W do
				continue=0
				c=map_block_get(x, FLOOR_Y, z)
				if c[2]==white_r and c[3]==white_g and c[4]==white_b then
					continue=1
				end
				if (z==midz) and build_white_line and continue==0 then
					map_block_set_randc(x, FLOOR_Y, z,  white_r, white_g, white_b)
					continue=1
				end
				if continue==0 then
					map_block_set_randc(x, FLOOR_Y, z,  ROAD_BLOCK.r, ROAD_BLOCK.g, ROAD_BLOCK.b)
				end
			end
		end
	end
	if xnr==gen_road then
		midz=z1+zcsize/2
		for x=x1+xcsize/2, x2 do
			build_white_line=(x%4)~=0
			for z=midz-HROAD_W, midz+HROAD_W do
				continue=0
				c=map_block_get(x, FLOOR_Y, z)
				if c[2]==white_r and c[3]==white_g and c[4]==white_b then
					continue=1
				end
				if (z==midz) and build_white_line and continue==0 then
					map_block_set_randc(x, FLOOR_Y, z,  white_r, white_g, white_b)
					continue=1
				end
				if continue==0 then
					map_block_set_randc(x, FLOOR_Y, z,  ROAD_BLOCK.r, ROAD_BLOCK.g, ROAD_BLOCK.b)
				end
			end
		end
	end
end

gen_funcs={gen_building, gen_grass, gen_road}
gen_funcs_count=table.getn(gen_funcs)

function manufacture_buildings()
	local mx, my, mz = common.map_get_dims()
	
	load_buildings()
	
	xcells=mx/16
	zcells=mz/16
	FLOOR_Y=my-4
	xcsize=mx/xcells
	zcsize=mz/zcells
	--generate random cell types
	for x=0, xcells-1 do
		cells[x]={}
		celldata[x]={}
		for z=0, zcells-1 do
			cells[x][z]=choice(gen_funcs)
			if cells[x][z]==gen_building then
				celldata[x][z]=randint(MIN_BUILDING_H, MAX_BUILDING_H)
			end
		end
	end
	--call the building funcs of the appropriate cell types
	map_cache_start()
	z=randint(1, zcells-2)
	zd=0
	for x=0, xcells-1 do
		if not zd then
			zd=randint(-1, 1)
			z=z+zd
			if z>=zcells then
				z=0
			end
			if z<0 then
				z=zcells-1
			end
		else
			zd=0
		end
		cells[x][z]=gen_road
		if zd and x~=0 then
			cells[x-1][z]=gen_road
		end
	end
	for x=0, xcells-1 do
		for z=0, zcells-1 do
			xnl=0
			xnr=0
			znl=0
			znr=0
			if x>0 then
				xnl=cells[x-1][z]
			end
			if x<=xcells-2 then
				xnr=cells[x+1][z]
			end
			if z>0 then
				znl=cells[x][z-1]
			end
			if z<=zcells-2 then
				znr=cells[x][z+1]
			end
			cells[x][z](x, z, xnl, xnr, znl, znr)
		end
	end
	map_cache_end()
end
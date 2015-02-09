--Gen city by LeCom
--Nooby code, feel free to fix things and optimize the code for lua

--TODO: make noise and colour values more appropriate
function ROAD_COLOR() d=math.random(0, 1) return {d, d, d} end
function CONCRETE_GROUND_COLOR() d=math.random(-4, 4) return {128+d, 128+d, 128+d} end
function GRASS_COLOR() return {0, 128+math.random(-8, 8), 0} end

function BUILDING_WALL_COLOR() d=math.random(-4, 4) return {100+d, 100+d, 100+d} end
function BUILDING_FLOOR_COLOR() d=math.random(-4, 4) return {100+d, 100+d, 100+d} end
function BUILDING_STAIR_COLUMN_COLOR() return {32, 32, 32} end
function BUILDING_STAIR_COLOR() return {128, 128, 128} end

function BUILDING_TABLE_COLOR() return {128, 64, 0} end
TABLE_W=2
TABLE_L=5
function BUILDING_CHAIR_COLOR() return {128, 64, 0} end


function FENCE_COLOR() d=math.random(-32, 32) return {80+d, 80+d, 80+d} end
FENCE_HEIGHT=6

function RUBBISH_BIN_COLOR() d=math.random(-32, 32) return {55+d, 64+d, 64+d} end
function RUBBISH_BIN_TOP_COLOR() d=math.random(-16, 16) return {25+d, 32+d, 32+d} end

function BUSH_COLOR() return {0, 128+math.random(-16, 16), 0} end
function LANTERN_COLOR() return {64, 64, 64} end
function LANTERN_LAMP_COLOR() return {255, 255, 0} end
LANTERN_H=8
LANTERN_INTERVAL=8

xcells=32
zcells=32

cells={}
celldata={}

MIN_BUILDING_H=2
MAX_BUILDING_H=4
BUILDING_FLOOR_HEIGHT=6
WINDOW_WIDTH=3
WINDOW_HEIGHT=2
WINDOW_FRAME_WIDTH=4
WINDOW_OFFSET=3

ROAD_W=10

HROAD_W=math.floor(ROAD_W/2)

FLOOR_Y=0

function ternary(c, t, f)
	if c then
		return t
	else
		return f
	end
end

function gen_bush(x1, y1, z1, x2, y2, z2)
	r=3
	midy=(y2-y1)/2+y1
	midz=(z2-z1)/2+z1
	for x=x1, x2-1 do
		pow_r=r*r/4
		for z=z1, z2-1 do
			pow_z=(z-midz)*(z-midz)
			for y=y1, y2-1 do
				pow_y=(y-midy)*(y-midy)
				if pow_z+pow_y<pow_r and math.random(0, 2) ~=0 then
					map_block_set(x, y, z, 1, unpack(BUSH_COLOR()))
				end
			end
		end
		if math.random(0, 1)==0 then
			r=r+math.random(-1, 1)
		end
	end
end

function gen_table(x1, y1, z1)
	tx2=x1+TABLE_W
	ty2=y1-1
	tz2=z1+TABLE_L
	for x=x1, tx2 do
		for z=z1, tz2 do
			map_block_set(x, ty2, z, 1, unpack(BUILDING_TABLE_COLOR()))
		end
	end
	map_block_set(x1, y1, z1, 1, unpack(BUILDING_TABLE_COLOR()))
	map_block_set(x1, y1, tz2, 1, unpack(BUILDING_TABLE_COLOR()))
	map_block_set(tx2, y1, z1, 1, unpack(BUILDING_TABLE_COLOR()))
	map_block_set(tx2, y1, tz2, 1, unpack(BUILDING_TABLE_COLOR()))
end

function gen_chair(x1, y1, z1)
	map_block_set(x1, y1, z1, 1, unpack(BUILDING_CHAIR_COLOR()))
	map_block_set(x1, y1-1, z1, 1, unpack(BUILDING_CHAIR_COLOR()))
	map_block_set(x1-1, y1, z1, 1, unpack(BUILDING_CHAIR_COLOR()))
end

function gen_bin(x1, y1, z1)
	map_block_set(x1, y1, z1, 1, unpack(RUBBISH_BIN_COLOR()))
	map_block_set(x1, y1-1, z1, 1, unpack(RUBBISH_BIN_TOP_COLOR()))
end

function gen_lantern(x1, y1, z1, xd, zd)
	hy=y1-LANTERN_H
	for y=hy, y1 do
		map_block_set(x1, y, z1, 1, unpack(LANTERN_COLOR()))
	end
	for i=1, 2 do
		x=x1+xd*i
		z=z1+zd*i
		map_block_set(x+zd, hy, z+xd, 1, unpack(LANTERN_COLOR()))
		map_block_set(x-zd, hy, z-xd, 1, unpack(LANTERN_COLOR()))
	end
	for i=1, 2 do
		x=x1+xd*i
		z=z1+zd*i
		map_block_set(x, hy, z, 1, unpack(LANTERN_LAMP_COLOR()))
	end
	map_block_set(x1+xd*3, hy, z1+zd*3, 1, unpack(LANTERN_COLOR()))
end

function gen_grass(x1, z1, xsize, zsize, xnl, xnr, znl, znr)
	x2=x1+xsize
	z2=z1+zsize
	for x=0, xsize-1 do
		for z=0, zsize-1 do
			map_block_set(x+x1, FLOOR_Y, z+z1, 1, unpack(GRASS_COLOR()))
		end
	end
	wallxd=0
	wallzd=0
	if math.random(0, 3)==0 then
		wallxd=0
		wallzd=0
		while wallxd==0 and wallzd==0 do
			wallxd=math.random(-1, 1)
			wallzd=math.random(-1, 1)
		end
		mdl=0
		if wallxd~=0 then
			fencex=x1+xsize/2+(xsize/2-ternary(wallxd==1, 1, 0))*wallxd
			for z=z1, z1+xsize-1 do
				mdl=1-mdl
				for y=0, FENCE_HEIGHT do
					if(y%2)==mdl then
						map_block_set(fencex, FLOOR_Y-y, z, 1, unpack(FENCE_COLOR()))
					end
				end
			end
		else
			fencez=z1+zsize/2+(zsize/2-ternary(wallzd==1, 1, 0))*wallzd
			for x=x1, x1+xsize-1 do
				mdl=1-mdl
				for y=0, FENCE_HEIGHT do
					if(y%2)==mdl then
						map_block_set(x, FLOOR_Y-y, fencez, 1,  unpack(FENCE_COLOR()))
					end
				end
			end
		end
	end
	if math.random(0, 2)==0 and (wallxd~=0 or wallzd~=0) then
		b=math.random(1, 2)
		for i=0, b-1 do
			if wallxd~=0 then
				x=x1+xsize/2+(xsize/2-math.random(1, 2)-ternary(wallxd==1, 1, 0))*wallxd
				z=z1+math.random(1, zsize-1)
			else
				x=x1+math.random(1, xsize-1)
				z=z1+zsize/2+(zsize/2-math.random(1, 2)-ternary(wallzd==1, 1, 0))*wallzd
			end
			gen_bin(x, FLOOR_Y-1, z)
		end
	end
	bushes=math.random(0, 5)
	bush_w=4
	bush_l=6
	if bushes then
		for b=0, bushes-1 do
			x=math.random(x1+4, x2-bush_l-4)
			z=math.random(z1+4, z2-bush_w-4)
			gen_bush(x, FLOOR_Y-bush_w, z, x+bush_l, FLOOR_Y, z+bush_w)
		end
	end
end

--Array accesses need to be replaced by arrays passed to functions
function gen_building(x1, z1, xsize, zsize, xnl, xnr, znl, znr)
	x2=x1+xsize-1
	z2=z1+zsize-1
	xc=x1/xsize
	zc=z1/zsize
	h=celldata[xc][zc]
	xnl=xnl==gen_building
	xnr=xnr==gen_building
	znl=znl==gen_building
	znr=znr==gen_building
	--UNSAFE TERNARY OPERATOR
	xlh=(xnl and celldata[xc-1][zc] or -1)
	xrh=(xnr and celldata[xc+1][zc] or -1)
	zlh=(znl and celldata[xc][zc-1] or -1)
	zrh=(znr and celldata[xc][zc+1] or -1)
	neighbour_higher=xlh>h or xrh>h or zlh>h or xrh>h
	neighbour=xnl or xnr or znl or znr
	do_stairs=neighbour_higher==false or math.random(0, 3)==0
	midx=xsize/2+x1
	midz=zsize/2+z1
	--walls
	for f=0, h-1 do
		y1=FLOOR_Y-(f+1)*BUILDING_FLOOR_HEIGHT+1
		y2=FLOOR_Y-f*BUILDING_FLOOR_HEIGHT-1
		fy=y1-1
		--The floor (+ hole at stair positions)
		for x=x1, x2 do
			stairx=((x>=midx-1) and (x<midx+2)) and do_stairs
			for z=z1, z2 do
				continue=0
				if stairx then
					if z>=midz-1 and z<midz+2 then
						continue=1
					end
				end
				if continue==0 then
					map_block_set(x, fy, z, 1, unpack(BUILDING_FLOOR_COLOR()))
				end
			end
		end
		table_count=math.random(0, 2)
		if table_count~=0 then
			for i=0, table_count do
				gen_table(ternary(math.random(0, 1)==0, x1+1, x2-TABLE_W-1), y2, ternary(math.random(0, 1)==0, z1+1, z2-TABLE_L-1))
			end
		end
		chair_count=math.random(0, 5)
		if chair_count~=0 then
			for i=0, chair_count do
				gen_chair(ternary(math.random(0, 1)==0, x1+4, x2-5)+1, y2, ternary(math.random(0, 1)==0, z1+4, z2-5))
			end
		end

		do_zlhw=(zlh<=f or znl==false)
		do_zrhw=(zrh<=f or znr==false)
		do_xlhw=(xlh<=f or xnl==false)
		do_xrhw=(xrh<=f or xnr==false)

		door_side=0
		if f==0 then door_side=math.random(1, 8) end
		if xlh==f then door_side=bit_or(door_side, 1) end
		if xrh==f then door_side=bit_or(door_side, 2) end
		if zrh==f then door_side=bit_or(door_side, 4) end
		if zlh==f then door_side=bit_or(door_side, 8) end

		upper_window_y=y1+WINDOW_HEIGHT/2
		lower_window_y=y2-WINDOW_HEIGHT/2-(WINDOW_HEIGHT%2)

		--WALLS (x direction)
		if do_zlhw or do_zrhw then
			window_c=-1+WINDOW_OFFSET
			window=0
			for x=x1, x2 do		
				for y=y1, y2 do
					build_block=y>=lower_window_y or y<upper_window_y or window==0
					if do_zlhw and build_block and not (bit_and(door_side, 8)~=0 and window==1) then
						map_block_set(x, y, z1, 1, unpack(BUILDING_WALL_COLOR()))
					end
					if do_zrhw and build_block and not (bit_and(door_side, 4)~=0 and window==1) then
						map_block_set(x, y, z2, 1, unpack(BUILDING_WALL_COLOR()))
					end
				end
				if window==0 then
					if window_c>=WINDOW_FRAME_WIDTH then
						window=1
						window_c=0
					end
				else
					if window_c>=WINDOW_WIDTH then
						window=0
						window_c=0
					end
				end
				window_c=window_c+1
			end
		end
		--WALLS (z direction)
		if do_xlhw or do_xrhw then
			window_c=-1+WINDOW_OFFSET
			window=0
			for z=z1, z2 do		
				for y=y1, y2 do	
					build_block=y>=lower_window_y or y<upper_window_y or window==0
					if do_xlhw and build_block and not (bit_and(door_side, 1)~=0 and window==1) then
						map_block_set(x1, y, z, 1, unpack(BUILDING_WALL_COLOR()))
					end
					if do_xrhw and build_block and not (bit_and(door_side, 2)~=0 and window==1) then
						map_block_set(x2, y, z, 1, unpack(BUILDING_WALL_COLOR()))
					end
				end
				if window==0 then
					if window_c>=WINDOW_FRAME_WIDTH then
						window=1
						window_c=0
					end
				else
					if window_c>=WINDOW_WIDTH then
						window=0
						window_c=0
					end
				end
				window_c=window_c+1
			end
		end
		--Doors
		--[[
		DOOR_WIDTH=10
		if zlh==f or zrh==f then
			xs=x1+(xsize-DOOR_WIDTH)/2
			xe=x2-(xsize-DOOR_WIDTH)/2
			for x=xs, xe do
				for y=y1, y2 do
					if zlh==f then
						map_block_break(x, y, z1)
					end
					if zrh==f then
						map_block_break(x, y, z2)
					end
				end
			end
		end
		if xlh==f or xrh==f then
			zs=z1+(zsize-DOOR_WIDTH)/2
			ze=z2-(zsize-DOOR_WIDTH)/2
			for z=zs, ze do
				for y=y1, y2 do
					if xlh==f then
						map_block_break(x1, y, z)
					end
					if xrh==f then
						map_block_break(x2, y, z)
					end
				end
			end
		end
		--]]
		--Stairs
		if do_stairs then
			for y=FLOOR_Y-(f+1)*BUILDING_FLOOR_HEIGHT, FLOOR_Y-f*BUILDING_FLOOR_HEIGHT do
				x=midx
				z=midz
				map_block_set(x, y, z, 1, unpack(BUILDING_STAIR_COLUMN_COLOR()))
				ymod=(y-FLOOR_Y+1)%8
				if ymod>=1 and ymod<4 then
					x=x+1
				else
					if ymod>4 then
						x=x-1
					end
				end
				ymod=(y-FLOOR_Y-1)%8
				if ymod>=1 and ymod<4 then
					z=z+1
				else
					if ymod>4 then
						z=z-1
					end
				end
				map_block_set(x, y, z, 1, unpack(BUILDING_STAIR_COLOR()))
			end
		end
	end
end

-- xc = grid x ; zc = grid z ; xnl, xnr = left/right neighbour tiles ; znl, znr = upper/lower neighbour tiles
function gen_road(x1, z1, xsize, zsize, xnl, xnr, znl, znr)
	x2=x1+xsize
	z2=z1+zsize
	white_r=255
	white_g=255
	white_b=255
	powrange=(ROAD_W/2.0)*(ROAD_W/2.0)
	for x=0, xsize-1 do
		for z=0, zsize-1 do
			if (x+.5-xsize/2.0)*(x+.5-xsize/2.0)+(z+.5-zsize/2.0)*(z+.5-zsize/2.0)<=powrange then
				map_block_set(x+x1, FLOOR_Y, z+z1, 1, unpack(ROAD_COLOR()))
			end
		end
	end
	if znl==gen_road then
		midx=x1+xsize/2
		for z=z1, z1+zsize/2 do
			build_white_line=(z%4)~=0
			for x=midx-HROAD_W, midx+HROAD_W-1 do
				continue=0
				c=map_block_get(x, FLOOR_Y, z)
				if c[2]==white_r and c[3]==white_g and c[4]==white_b then
					continue=1
				end
				if (x==midx) and build_white_line and (continue==0) then
					map_block_set(x, FLOOR_Y, z, 1, white_r, white_g, white_b)
					continue=1
				end
				if continue==0 then
					map_block_set(x, FLOOR_Y, z, 1, unpack(ROAD_COLOR()))
				end
			end
		end
	end
	if znr==gen_road then
		midx=x1+xsize/2
		for z=z1+zsize/2, z2 do
			build_white_line=(z%4)~=0
			for x=midx-HROAD_W, midx+HROAD_W-1 do
				continue=0
				c=map_block_get(x, FLOOR_Y, z)
				if c[2]==white_r and c[3]==white_g and c[4]==white_b then
					continue=1
				end
				if (x==midx) and build_white_line and (continue==0) then
					map_block_set(x, FLOOR_Y, z, 1, white_r, white_g, white_b)
					continue=1
				end
				if continue==0 then
					map_block_set(x, FLOOR_Y, z, 1, unpack(ROAD_COLOR()))
				end
			end
		end
	end
	if xnl==gen_road then
		midz=z1+zsize/2
		for x=x1, x1+xsize/2 do
			build_white_line=(x%4)~=0
			for z=midz-HROAD_W, midz+HROAD_W-1 do
				continue=0
				c=map_block_get(x, FLOOR_Y, z)
				if c[2]==white_r and c[3]==white_g and c[4]==white_b then
					continue=1
				end
				if (z==midz) and build_white_line and continue==0 then
					map_block_set(x, FLOOR_Y, z, 1, white_r, white_g, white_b)
					continue=1
				end
				if continue==0 then
					map_block_set(x, FLOOR_Y, z, 1, unpack(ROAD_COLOR()))
				end
			end
		end
	end
	if xnr==gen_road then
		midz=z1+zsize/2
		for x=x1+xsize/2, x2 do
			build_white_line=(x%4)~=0
			for z=midz-HROAD_W, midz+HROAD_W-1 do
				continue=0
				c=map_block_get(x, FLOOR_Y, z)
				if c[2]==white_r and c[3]==white_g and c[4]==white_b then
					continue=1
				end
				if (z==midz) and build_white_line and (continue==0) then
					map_block_set(x, FLOOR_Y, z, 1, white_r, white_g, white_b)
					continue=1
				end
				if continue==0 then
					map_block_set(x, FLOOR_Y, z, 1, unpack(ROAD_COLOR()))
				end
			end
		end
	end
	if znl~=gen_road and znr~=gen_road then
		b=math.random(0, 2)
		if b==0 then
			b=math.random(1, 3)
			for i=0, b-1 do
				zd=math.random(0, 1)*2-1
				x=math.random(x1, x2-1)
				z=z1+zsize/2+(zsize/2-ternary(zd==1, 1, 0))*zd
				gen_bin(x, FLOOR_Y-1, z)
			end
		end
		if xnr==gen_road or xnl==gen_road then
			for x=x1+LANTERN_INTERVAL*ternary(xnl~=gen_road, 1, 0),  x2-1-LANTERN_INTERVAL*ternary(xnr~=gen_road, 1, 0), LANTERN_INTERVAL do
				gen_lantern(x, FLOOR_Y-1, z1+1, 0, 1)
				gen_lantern(x, FLOOR_Y-1, z2-2, 0, -1)
			end
		end
	end
	if xnr~=gen_road and xnl~=gen_road then
		b=math.random(0, 2)
		if b==0 then
			b=math.random(1, 3)
			for i=0, b-1 do
				xd=math.random(0, 1)*2-1
				z=math.random(x1, x2-1)
				x=x1+xsize/2+(xsize/2-ternary(wallxd==1, 1, 0))*xd
				gen_bin(x, FLOOR_Y-1, z)
			end
		end
		if znr==gen_road or znl==gen_road then
			for z=z1+LANTERN_INTERVAL*ternary(znl~=gen_road, 1, 0),  z2-1-LANTERN_INTERVAL*ternary(znr~=gen_road, 1, 0), LANTERN_INTERVAL do
				gen_lantern(x1+1, FLOOR_Y-1, z, 1, 0)
				gen_lantern(x2-2, FLOOR_Y-1, z, -1, 0)
			end
		end
	end
end

function gen_border(x1, z1, xsize, zsize, xnl, xnr, znl, znr)
	for x=0, xsize-1 do
		for z=0, zsize-1 do
			map_block_set(x+x1, FLOOR_Y, z+z1, 1, unpack(GRASS_COLOR()))
		end
	end
end


gen_funcs={gen_building, gen_grass, gen_road}
gen_funcs_count=3

function choice(array)
	return array[math.random(#array)]
end

do
	local loose, user_toggles, user_settings
	loose, user_toggles, user_settings = ...
	local mx=user_settings["mx"] or 512
	local my=user_settings["my"] or 96
	local mz=user_settings["mz"] or 512
	local ret=common.map_new(mx, my, mz)
	common.map_set(ret)
	xcells=mx/16
	zcells=mz/16
	FLOOR_Y=my-4
	xcsize=mx/xcells
	zcsize=mz/zcells
	for x=0, mx-1 do
		for z=0, mz-1 do
			c=CONCRETE_GROUND_COLOR()
			l={0, my-4, my-4, 0, c[1], c[2], c[3], 1}
			common.map_pillar_set(x, z, l)
		end
	end
	for x=0, xcells-1 do
		cells[x]={}
		celldata[x]={}
		xborder=x==0 or x==xcells-1
		for z=0, zcells-1 do
			zborder=z==0 or z==zcells-1
			if (xborder==false) and (zborder==false) then
				cell=choice(gen_funcs)
				cells[x][z]=cell
				if cell==gen_building then
					celldata[x][z]=math.random(MIN_BUILDING_H, MAX_BUILDING_H)
				end
			else
				cells[x][z]=gen_border
			end
		end
	end
	map_cache_start()
	z=math.random(1, zcells-2)
	zd=0
	for x=0, xcells-1 do
		if not zd then
			zd=math.random(-1, 1)
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
			cells[x][z](x*xcsize, z*zcsize, xcsize, zcsize, xnl, xnr, znl, znr)
		end
	end
	map_cache_end()
	return ret, "lecom_gencity("..mx..","..mz..","..my..")"
end

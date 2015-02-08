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

xcells=32
zcells=32
xcsize=0
zcsize=0

cells={}
celldata={}

MIN_BUILDING_H=2
MAX_BUILDING_H=4
BUILDING_FLOOR_HEIGHT=6
WINDOW_WIDTH=4

ROAD_W=12

HROAD_W=ROAD_W/2

FLOOR_Y=0

function ternary(c, t, f)
	if c then
		return t
	else
		return f
	end
end

function randint(x, y)
	return math.random(x, y)
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

function gen_bin(x, y, z)
	map_block_set(x, y, z, 1, unpack(RUBBISH_BIN_COLOR()))
	map_block_set(x, y-1, z, 1, unpack(RUBBISH_BIN_TOP_COLOR()))
end

function gen_grass(xc, zc, xnl, xnr, znl, znr)
	x1=xc*xcsize
	z1=zc*zcsize
	for x=0, xcsize-1 do
		for z=0, zcsize-1 do
			map_block_set(x+x1, FLOOR_Y, z+z1, 1, unpack(GRASS_COLOR()))
		end
	end
	if randint(0, 3)~=0 then
		return
	end
	xd=0
	zd=0
	while (xd==0) and (zd==0) do
		xd=randint(-1, 1)
		zd=randint(-1, 1)
	end
	mdl=0
	if xd~=0 then
		fencex=x1+xcsize/2+(xcsize/2-ternary(xd==1, 1, 0))*xd
		for z=z1, z1+xcsize-1 do
			mdl=1-mdl
			for y=0, FENCE_HEIGHT do
				if(y%2)==mdl then
					map_block_set(fencex, FLOOR_Y-y, z, 1, unpack(FENCE_COLOR()))
				end
			end
		end
	else
		fencez=z1+zcsize/2+(zcsize/2-ternary(zd==1, 1, 0))*zd
		for x=x1, x1+xcsize-1 do
			mdl=1-mdl
			for y=0, FENCE_HEIGHT do
				if(y%2)==mdl then
					map_block_set(x, FLOOR_Y-y, fencez, 1,  unpack(FENCE_COLOR()))
				end
			end
		end
	end
	b=randint(0, 2)
	if b==0 then
		b=randint(1, 2)
		for i=0, b-1 do
			if xd~=0 then
				x=x1+xcsize/2+(xcsize/2-randint(1, 2)-ternary(xd==1, 1, 0))*xd
				z=z1+randint(1, zcsize-1)
			else
				x=x1+randint(1, xcsize-1)
				z=z1+zcsize/2+(zcsize/2-randint(1, 2)-ternary(zd==1, 1, 0))*zd
			end
			gen_bin(x, FLOOR_Y-1, z)
		end
	end
end

function gen_building(xc, zc, xnl, xnr, znl, znr)
	x1=xc*xcsize
	z1=zc*zcsize
	x2=x1+xcsize-1
	z2=z1+zcsize-1
	h=celldata[xc][yc]
	h=4
	--UNSAFE TERNARY OPERATOR
	xlh=(xnl and celldata[xc-1][zc] or 1024)
	xrh=(xnr and celldata[xc+1][zc] or 1024)
	zlh=(znl and celldata[xc][zc-1] or 1024)
	zrh=(znr and celldata[xc][zc+1] or 1024)
	xnl=xnl==gen_building
	xnr=xnr==gen_building
	znl=znl==gen_building
	znr=znr==gen_building
	neighbour=xnl or xnr or znl or znr
	do_stairs=not neighbour or randint(0, 3)==0
	midx=xcsize/2+x1
	midz=zcsize/2+z1
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
		table_count=randint(0, 2)
		if table_count~=0 then
			for i=0, table_count do
				gen_table(ternary(randint(0, 1)==0, x1+1, x2-TABLE_W-1), y2, ternary(randint(0, 1)==0, z1+1, z2-TABLE_L-1))
			end
		end
		chair_count=randint(0, 5)
		if chair_count~=0 then
			for i=0, chair_count do
				gen_chair(ternary(randint(0, 1)==0, x1+4, x2-5)+1, y2, ternary(randint(0, 1)==0, z1+4, z2-5))
			end
		end
		do_zlhw=(zlh<=f or znl==false) or h==0
		do_zrhw=(zrh<=f or znr==false) or h==0
		do_xlhw=(xlh<=f or xnl==false) or h==0
		do_xrhw=(xrh<=f or xnr==false) or h==0
		if do_zlhw or do_zrhw then
			for x=x1, x2 do
				if do_zlhw then
					map_block_set(x, y1, z1, 1, unpack(BUILDING_WALL_COLOR()))
					map_block_set(x, y2, z1, 1, unpack(BUILDING_WALL_COLOR()))
				end
				if do_zrhw then
					map_block_set(x, y1, z2, 1,  unpack(BUILDING_WALL_COLOR()))
					map_block_set(x, y2, z2, 1,  unpack(BUILDING_WALL_COLOR()))
				end
				if ((x-x1)%WINDOW_WIDTH)==0 or x==x1 or x==x2 then
					for y=y1, y2 do
						if do_zlhw then
							map_block_set(x, y, z1, 1, unpack(BUILDING_WALL_COLOR()))
						end
						if do_zrhw then
							map_block_set(x, y, z2, 1, unpack(BUILDING_WALL_COLOR()))
						end
					end
				end
			end
		end
		--WALLS (z direction)
		for z=z1, z2 do
			if do_xlhw then
				map_block_set(x1, y1, z, 1, unpack(BUILDING_WALL_COLOR()))
				map_block_set(x1, y2, z, 1, unpack(BUILDING_WALL_COLOR()))
			end
			if do_xrhw then
				map_block_set(x2, y1, z, 1, unpack(BUILDING_WALL_COLOR()))
				map_block_set(x2, y2, z, 1, unpack(BUILDING_WALL_COLOR()))
			end
			if ((z-z1)%WINDOW_WIDTH)==0 or z==z1 or z==z2 then
				for y=y1, y2 do
					if do_xlhw then
						map_block_set(x1, y, z, 1, unpack(BUILDING_WALL_COLOR()))
					end
					if do_xrhw then
						map_block_set(x2, y, z, 1, unpack(BUILDING_WALL_COLOR()))
					end
				end
			end
		end
		--Stairs
		if do_stairs then
			for y=FLOOR_Y-h*BUILDING_FLOOR_HEIGHT, FLOOR_Y do
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
function gen_road(xc, zc, xnl, xnr, znl, znr)
	x1=xc*xcsize
	z1=zc*zcsize
	x2=x1+xcsize
	z2=z1+zcsize
	white_r=255
	white_g=255
	white_b=255
	powrange=(ROAD_W/2.0)*(ROAD_W/2.0)
	for x=0, xcsize-1 do
		for z=0, zcsize-1 do
			if (x+.5-xcsize/2.0)*(x+.5-xcsize/2.0)+(z+.5-zcsize/2.0)*(z+.5-zcsize/2.0)<=powrange then
				map_block_set(x+x1, FLOOR_Y, z+z1, 1, unpack(ROAD_COLOR()))
			end
		end
	end
	if znl==gen_road then
		midx=x1+xcsize/2
		for z=z1, z1+zcsize/2 do
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
		midx=x1+xcsize/2
		for z=z1+zcsize/2, z2 do
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
		midz=z1+zcsize/2
		for x=x1, x1+xcsize/2 do
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
		midz=z1+zcsize/2
		for x=x1+xcsize/2, x2 do
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
		b=randint(0, 2)
		if b==0 then
			b=randint(1, 3)
			for i=0, b-1 do
				zd=randint(0, 1)*2-1
				x=randint(x1, x2-1)
				z=z1+zcsize/2+(zcsize/2-ternary(zd==1, 1, 0))*zd
				gen_bin(x, FLOOR_Y-1, z)
			end
		end
	end
	if xnr~=gen_road and xnl~=gen_road then
		b=randint(0, 2)
		if b==0 then
			b=randint(1, 3)
			for i=0, b-1 do
				xd=randint(0, 1)*2-1
				z=randint(x1, x2-1)
				x=x1+xcsize/2+(xcsize/2-ternary(xd==1, 1, 0))*xd
				gen_bin(x, FLOOR_Y-1, z)
			end
		end
	end
end

function gen_border(xc, zc, xnl, xnr, znl, znr)
	x1=xc*xcsize
	z1=zc*zcsize
	for x=0, xcsize-1 do
		for z=0, zcsize-1 do
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
					celldata[x][z]=randint(MIN_BUILDING_H, MAX_BUILDING_H)
					celldata[x][z]=4
				end
			else
				cells[x][z]=gen_border
			end
		end
	end
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
	return ret, "lecom_gencity("..mx..","..mz..","..my..")"
end

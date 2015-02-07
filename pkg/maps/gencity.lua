--Gen city by LeCom
--Lacks the code for gen_building
--(tho' it already has everything else, so one can also just plug in some function, like Dany0's building gen)

--Nooby code, feel free to fix things and optimize the code for lua


--These should really be converted into arrays ASAP
ROAD_R=0
ROAD_G=0
ROAD_B=0

CONCRETE_R=128
CONCRETE_G=128
CONCRETE_B=128

GRASS_R=0
GRASS_G=128
GRASS_B=0

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
			map_block_set(x+x1, FLOOR_Y, z+z1, 1, GRASS_R, GRASS_G, GRASS_B)
		end
	end
end

function gen_building(xc, zc, xnl, xnr, znl, znr)

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
				map_block_set(x+x1, FLOOR_Y, z+z1, 1, ROAD_R, ROAD_G, ROAD_B)
			end
		end
	end
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
				if (x==midx) and build_white_line and (continue==0) then
					map_block_set(x, FLOOR_Y, z, 1, white_r, white_g, white_b)
					continue=1
				end
				if continue==0 then
					map_block_set(x, FLOOR_Y, z, 1, ROAD_R, ROAD_G, ROAD_B)
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
				if (x==midx) and build_white_line and (continue==0) then
					map_block_set(x, FLOOR_Y, z, 1, white_r, white_g, white_b)
					continue=1
				end
				if continue==0 then
					map_block_set(x, FLOOR_Y, z, 1, ROAD_R, ROAD_G, ROAD_B)
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
					map_block_set(x, FLOOR_Y, z, 1, white_r, white_g, white_b)
					continue=1
				end
				if continue==0 then
					map_block_set(x, FLOOR_Y, z, 1, ROAD_R, ROAD_G, ROAD_B)
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
				if (z==midz) and build_white_line and (continue==0) then
					map_block_set(x, FLOOR_Y, z, 1, white_r, white_g, white_b)
					continue=1
				end
				if continue==0 then
					map_block_set(x, FLOOR_Y, z, 1, ROAD_R, ROAD_G, ROAD_B)
				end
			end
		end
	end
end


gen_funcs={gen_building, gen_grass, gen_road}
gen_funcs_count=3

function randint(x, y)
	return x+math.floor(tonumber(math.random()*(y-x)))
end

function choice(array)
	return array[math.random(#array)]
end

do
	local loose, user_toggles, user_settings
	loose, user_toggles, user_settings = ...
	local mx=user_settings["mx"] or 512
	local my=user_settings["my"] or 96
	local mz=user_settings["mz"] or 512
	--mx=256
	--mz=256
	local ret=common.map_new(mx, my, mz)
	common.map_set(ret)
	xcells=mx/16
	zcells=mz/16
	FLOOR_Y=my-4
	xcsize=mx/xcells
	zcsize=mz/zcells
	for x=0, mx-1 do
		for z=0, mz-1 do
			l={0, my-4, my-4, 0, CONCRETE_R, CONCRETE_G, CONCRETE_B, 1}
			common.map_pillar_set(x, z, l)
		end
	end
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
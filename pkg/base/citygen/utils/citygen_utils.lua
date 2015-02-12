
--subtly sweeten up block colour with a little bit of noise
--only solid blocks have colour anyway so dropping the type param
function map_block_set_randc(x, y, z, r, g, b)
	rand = 1+(math.random()/11) --todo: param to control noise amount
	map_block_set(x, y, z, 1,
					math.max(math.min(r*rand, 255), 0),
					math.max(math.min(g*rand, 255), 0),
					math.max(math.min(b*rand, 255), 0))
end

function map_pillar_add_block(x, y, z, r, g, b)
	r, g, b = math.floor(r), math.floor(g), math.floor(b) --sanity
	
	--pillar_table = {chunk_header, starting_block, ending_block, 0}
	pillar_table = common.map_pillar_get(x, z)
	-- if (pillar_table[2] > y) then --MODE add block over
		-- pillar_table[1] = pillar_table[1] + 1
		 pillar_table[2] = pillar_table[2] - 1
		-- pillar_table[3] = pillar_table[3] - 1
		pillar_table[#pillar_table+1] = b
		pillar_table[#pillar_table+1] = g
		pillar_table[#pillar_table+1] = r
		pillar_table[#pillar_table+1] = 1 -- type of block: solid
		pillar_table[#pillar_table-7], pillar_table[#pillar_table-6], pillar_table[#pillar_table-5], pillar_table[#pillar_table-4], pillar_table[#pillar_table-3], pillar_table[#pillar_table-2], pillar_table[#pillar_table-1], pillar_table[#pillar_table] = pillar_table[#pillar_table-3], pillar_table[#pillar_table-2], pillar_table[#pillar_table-1], pillar_table[#pillar_table],  pillar_table[#pillar_table-7], pillar_table[#pillar_table-6], pillar_table[#pillar_table-5], pillar_table[#pillar_table-4]
	-- end
	-- for i=y,y+depth do
		-- pillar_table[#pillar_table+1] = b
		-- pillar_table[#pillar_table+1] = g
		-- pillar_table[#pillar_table+1] = r
		-- pillar_table[#pillar_table+1] = type_of_block
	-- end
	common.map_pillar_set(x, z, pillar_table)
end

function map_pillar_set_column(x, y, z, height, r, g, b)
	chunk_header = 0
	starting_block = y-height
	ending_block = y
	air_start = 0
	
	type_of_block = 1
	pillar_table = {chunk_header, starting_block, ending_block, 0}
	for i=y,y+height do
		pillar_table[#pillar_table+1] = b
		pillar_table[#pillar_table+1] = g
		pillar_table[#pillar_table+1] = r
		pillar_table[#pillar_table+1] = type_of_block
	end
	common.map_pillar_set(x, z, pillar_table)
end

--TODO: bersenham algo, could be useful some time
function draw_line_no_support() end

--waiting for this to appear in some lib
function citygen_ternary(condition, return_if_condition_true, return_if_condition_false)
	if condition then
		return return_if_condition_true
	else
		return return_if_condition_false
	end
end

-- function math.sign(x)
  -- return x>0 and 1 or x<0 and -1 or 0
-- end

--draws a line
--NOTE: this REALLY doesn't like float values, but I won't sanity check for you!
function map_draw_line(x1,y1,z1,x2,y2,z2, r, g, b)	
	local x1idx = math.floor(x1)
	local y1idx = math.floor(y1)
	local z1idx = math.floor(z1)
	local x2idx = math.floor(x2)
	local y2idx = math.floor(y2)
	local z2idx = math.floor(z2)
	local sx = citygen_ternary(x2idx > x1idx, 1, citygen_ternary(x2idx < x1idx, -1, 0))
	local sy = citygen_ternary(y2idx > y1idx, 1, citygen_ternary(y2idx < y1idx, -1, 0))
	local sz = citygen_ternary(z2idx > z1idx, 1, citygen_ternary(z2idx < z1idx, -1, 0))
	local x = x1idx
	local y = y1idx
	local z = z1idx
	local xp = x1idx + citygen_ternary(x2idx > x1idx, 1, 0)
	local yp = y1idx + citygen_ternary(y2idx > y1idx, 1, 0)
	local zp = z1idx + citygen_ternary(z2idx > z1idx, 1, 0)
	local vx = citygen_ternary(x2 == x1, 1, x2-x1)
	local vy = citygen_ternary(y2 == y1, 1, y2-y1)
	local vz = citygen_ternary(z2 == z1, 1, z2-z1)
	local vxvy = vx * vy
	local vxvz = vx * vz
	local vyvz = vy * vz
	local errx = (xp - x1) * vyvz
	local erry = (yp - y1) * vxvz
	local errz = (zp - z1) * vxvy
	local derrx = sx * vyvz
	local derry = sy * vxvz
	local derrz = sz * vxvy

	local testEscape = 2048 -- there is probably a case when this could (try to) run forever, 2048 is more than enough okay
	repeat
		map_block_set(x, y, z, 1, r, g, b)
		if (x == x2idx and y == y2idx and z == z2idx) then
			break
		end

		local xr = math.abs(errx)
		local yr = math.abs(erry)
		local zr = math.abs(errz)
		if (sx ~= 0 and (sy == 0 or xr < yr) and (sz == 0 or xr < zr)) then
			x = x + sx
			errx = errx + derrx
		elseif (sy ~= 0 and (sz == 0 or yr < zr)) then
			y = y + sy
			erry = erry + derry
		elseif (sz ~= 0) then
			z = z + sz
			errz = errz + derrz
		end
		testEscape = testEscape - 1
	until testEscape <= 0

end

--creates a frame
--USE MAP CACHE
function map_create_frame(x1,y1,z1,x2,y2,z2, r, g, b)
	
	map_draw_line( x1,y1,z1,
							x2,y1,z1,
							r, g, b)
	map_draw_line( x1,y1,z1,
							x1,y2,z1,
							r, g, b)
	map_draw_line( x1,y1,z1,
							x1,y1,z2,
							r, g, b)
	map_draw_line( x1,y2,z1,
							x1,y2,z2,
							r, g, b)
	map_draw_line( x1,y2,z1,
							x2,y2,z1,
							r, g, b)
	map_draw_line( x1,y2,z1,
							x1,y2,z2,
							r, g, b)
	map_draw_line( x1,y2,z2,
							x2,y2,z2,
							r, g, b)
	map_draw_line( x2,y2,z1,
							x2,y2,z2,
							r, g, b)
	map_draw_line( x2,y1,z1,
							x2,y2,z1,
							r, g, b)
	map_draw_line( x2,y1,z1,
							x2,y1,z2,
							r, g, b)
	map_draw_line( x1,y1,z2,
							x2,y1,z2,
							r, g, b)
	map_draw_line( x2,y1,z2,
							x2,y2,z2,
							r, g, b)
	map_draw_line( x1,y1,z2,
							x1,y2,z2,
							r, g, b)
							
end

--TODO: deprecate these
function randint(x, y)
	return x+math.floor(tonumber(math.random()*(y-x)))
end

function choice(array)
	return array[math.random(#array)]
end
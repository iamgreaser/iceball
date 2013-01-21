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

-- returns a list consisting of {t,r,g,b} tuplets
function map_pillar_raw_unpack(tpack)
	local xlen,ylen,zlen 
	xlen,ylen,zlen = common.map_get_dims()
	local t = {}
	local i,j,y
	i = 1
	y = 0
	
	while true do
		-- fill with air
		while y < tpack[i+1] do
			t[y+1] = nil
			y = y + 1
		end
		
		-- fill with top data
		j = i + 4
		while y <= tpack[i+2] do
			t[y+1] = {tpack[j+3],tpack[j+2],tpack[j+1],tpack[j+0]}
			y = y + 1
			j = j + 4
		end
		
		-- check if end
		if tpack[i] == 0 then
			-- fill the rest with invisible
			while y < ylen do
				t[y+1] = false
				y = y + 1
			end
			-- that's it
			break
		end
		
		local ntr = tpack[i]-1-(tpack[i+2]-tpack[i+1]+1)
		i = i + 4*tpack[i]
		ntr = tpack[i+3] - ntr
		
		-- fill with invisible
		while y < ntr do
			t[y+1] = false
			y = y + 1
		end
		
		-- fill with bottom data
		while y < tpack[i+3] do
			t[y+1] = {tpack[j+3],tpack[j+2],tpack[j+1],tpack[j+0]}
			y = y + 1
			j = j + 4
		end
	end
	
	return t
end

function map_pillar_raw_get(x,z)
	return map_pillar_raw_unpack(common.map_pillar_get(x,z))
end

function map_pillar_raw_pack(t)
	local xlen,ylen,zlen 
	xlen,ylen,zlen = common.map_get_dims()
	local tpack = {}
	local y,i
	local rmode = 0
	local n,s,e,a
	a = 0
	i = nil
	y = 0
	
	while true do
		-- skip air
		while t[y+1] == nil do
			y = y + 1
			if y >= ylen then break end
		end
		if y >= ylen then break end
		
		if i then tpack[i] = n end
		
		-- allocate slot
		i = #tpack+1
		tpack[i+0] = 0
		tpack[i+1] = y
		tpack[i+2] = 0
		tpack[i+3] = a
		
		-- copy top run
		n = 1
		while t[y+1] do
			tpack[#tpack+1] = t[y+1][4]
			tpack[#tpack+1] = t[y+1][3]
			tpack[#tpack+1] = t[y+1][2]
			tpack[#tpack+1] = t[y+1][1]
			y = y + 1
			n = n + 1
		end
		tpack[i+2] = y-1
		
		-- skip dirt
		while t[y+1] == false do
			y = y + 1
			if y >= ylen then break end
		end
		if y >= ylen then break end
		
		-- build bottom run
		while t[y+1] do
			tpack[#tpack+1] = t[y+1][4]
			tpack[#tpack+1] = t[y+1][3]
			tpack[#tpack+1] = t[y+1][2]
			tpack[#tpack+1] = t[y+1][1]
			n = n + 1
			y = y + 1
		end
		
		a = y
	end
	
	return tpack
end

function map_pillar_raw_set(x,z,t)
	local tpack = map_pillar_raw_pack(t)
	
	common.map_pillar_set(x,z,tpack)
	
	if img_overview and tpack[5] then
		-- TODO: check for wrapping
		local r,g,b
		b = tpack[5]
		g = tpack[6]
		r = tpack[7]
		local c = argb_split_to_merged(r,g,b)
		common.img_pixel_set(img_overview, x, z, c)
	end
end

function map_block_aerate(x,y,z)
	return ({
		1,
		64+math.sin((x+z-y)*math.pi/4)*8,
		32-math.sin((x-z+y)*math.pi/4)*8,
		0
	})
end

function map_pillar_aerate(x,z)
	local xlen,ylen,zlen 
	xlen,ylen,zlen = common.map_get_dims()
	local t = map_pillar_raw_get(x,z)
	local l = {
		map_pillar_raw_get(x-1,z),
		map_pillar_raw_get(x+1,z),
		map_pillar_raw_get(x,z-1),
		map_pillar_raw_get(x,z+1),
	}
	local y
	
	for y=1,ylen do
		if t[y] then
			if l[1][y] ~= nil and l[2][y] ~= nil
					and l[3][y] ~= nil and l[4][y] ~= nil
					and t[y-1] ~= nil and (y == ylen or t[y+1] ~= nil) then
				t[y] = false
			end
		elseif t[y] == false then
			if l[1][y] == nil or l[2][y] == nil
					or l[3][y] == nil or l[4][y] == nil
					or t[y-1] == nil or (y ~= ylen and t[y+1] == nil) then
				t[y] = map_block_aerate(x,y-1,z)
			end
		end
	end
	
	map_pillar_raw_set(x,z,t)
end

function map_hashcoord3(x,y,z)
	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	
	return 
		 (y % ylen) + ylen*((x % xlen) + xlen*(z % zlen))
end

function map_hashcoord2(x,z)
	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	
	return (x % xlen)
		+xlen*(z % zlen)
end

function map_chkdisbrk(x,y,z)
	-- A* ftw
	local loadq = {
		{x-1,y,z},
		{x+1,y,z},
		{x,y-1,z},
		{x,y+1,z},
		{x,y,z-1},
		{x,y,z+1},
	}
	local tmap = {}
	local pmap = {}
	local plist = {}
	local ptag = {}
	local ptaglist = {}
	local nukeq = {}
	
	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	
	-- build chunks
	local i,j
		for i=1,#loadq do
		local prio,tx,ty,tz
		tx,ty,tz = loadq[i][1],loadq[i][2],loadq[i][3]
			
		if not pmap[map_hashcoord2(tx,tz)] then
			pmap[map_hashcoord2(tx,tz)] = map_pillar_raw_get(tx,tz)
			plist[#plist+1] = {tx,tz}
		end
		
		if (not tmap[map_hashcoord3(tx,ty,tz)]) and pmap[map_hashcoord2(tx,tz)][ty+1] ~= nil then
			local pq = collect_new_prioq(function(p,q)
				return p[1] < q[1]
			end)
			
			tmap[map_hashcoord3(tx,ty,tz)] = {
				heur = -ty,
				dist = 0,
				i = i,
			}
			pq.push({-ty,tx,ty,tz})
			
			local nukeasm = {}
			while nukeasm and not pq.empty() do
				local c = pq.pop()
				prio,tx,ty,tz = c[1],c[2],c[3],c[4]
				--print(prio,tx,ty,tz)
				local tm = tmap[map_hashcoord3(tx,ty,tz)]
				if prio <= tm.heur + tm.dist then
					--print(i,prio,tx,ty,tz)
					nukeasm[#nukeasm+1] = {tx,ty,tz}
					if not pmap[map_hashcoord2(tx,tz)] then
						pmap[map_hashcoord2(tx,tz)] = map_pillar_raw_get(tx,tz)
						plist[#plist+1] = {tx,tz}
					end
					
					local nb = {
						{tx-1,ty,tz},
						{tx+1,ty,tz},
						{tx,ty-1,tz},
						{tx,ty+1,tz},
						{tx,ty,tz-1},
						{tx,ty,tz+1},
					}
					
					local dist = tm.dist+1
					for j=1,6 do
						local cx,cy,cz = nb[j][1], nb[j][2], nb[j][3]
						local cm = tmap[map_hashcoord3(cx,cy,cz)]
						if cy == ylen or (cm and cm.i ~= i) then
							--print("BAIL!")
							nukeasm = nil
							break
						end
						
						if not pmap[map_hashcoord2(cx,cz)] then
							pmap[map_hashcoord2(cx,cz)] = map_pillar_raw_get(cx,cz)
							plist[#plist+1] = {cx,cz}
						end
						
						if pmap[map_hashcoord2(cx,cz)][cy+1] ~= nil then
							local heur = -cy
							if not cm then
								cm = {
									heur = heur,
									dist = dist,
									i = i,
								}
								tmap[map_hashcoord3(cx,cy,cz)] = cm
								pq.push({heur+dist,cx,cy,cz})
							else
								if cm.heur+cm.dist > heur+dist then
									cm.heur = heur
									cm.dist = dist
									pq.push({heur+dist,cx,cy,cz})
								end
							end
						end
					end
				end
			end
			
			if nukeasm then
				nukeq[#nukeq+1] = nukeasm
				--print(#nukeq,#nukeasm)
			end
		end
	end
	
	-- nuke it all
	-- TODO: assemble falling PMFs and drop the buggers
	local brokestuff = false
	for i=1,#nukeq do
		local tx,ty,tz
		local nl = nukeq[i]
		if #nl > 0 then brokestuff = true end
		for j=1,#nl do
			local c = nl[j]
			tx,ty,tz = c[1],c[2],c[3]
			if not ptag[map_hashcoord2(tx,tz)] then
				ptag[map_hashcoord2(tx,tz)] = true
				ptaglist[#ptaglist+1] = {tx,tz}
			end
			pmap[map_hashcoord2(tx,tz)][ty+1] = nil
		end
	end
	
	if brokestuff and client then
		client.wav_play_global(wav_grif,x+0.5,y+0.5,z+0.5)
	end
	
	-- apply nukings
	local nptag = {}
	local nptaglist = {}
	for i=1,#ptaglist do
		local tx,tz
		local c = ptaglist[i]
		tx,tz = c[1], c[2]
		map_pillar_raw_set(tx,tz,pmap[map_hashcoord2(tx,tz)])
		
		if not nptag[map_hashcoord2(tx,tz)] then
			nptag[map_hashcoord2(tx,tz)] = true
			nptaglist[#nptaglist+1] = {tx,tz}
		end
	end
	
	-- aerate
	for i=1,#nptaglist do
		local tx,tz
		local c = nptaglist[i]
		tx,tz = c[1], c[2]
		
		map_pillar_aerate(tx,tz)
	end
end

function map_block_get(x,y,z)
	local xlen,ylen,zlen 
	xlen,ylen,zlen = common.map_get_dims()
	if y < 0 or y >= ylen then return end
	
	local t = map_pillar_raw_get(x,z)
	return t[y+1]
end

function map_block_set(x,y,z,typ,r,g,b)
	local xlen,ylen,zlen 
	xlen,ylen,zlen = common.map_get_dims()
	if y < 0 or y >= ylen then return end
	
	local t = map_pillar_raw_get(x,z)
	t[y+1] = {typ, r, g, b}
	map_pillar_raw_set(x,z,t)
	
	map_pillar_aerate(x,z)
	map_pillar_aerate(x-1,z)
	map_pillar_aerate(x+1,z)
	map_pillar_aerate(x,z-1)
	map_pillar_aerate(x,z+1)
end

function map_block_paint(x,y,z,typ,r,g,b)
	local xlen,ylen,zlen 
	xlen,ylen,zlen = common.map_get_dims()
	if y < 0 or y >= ylen then return end
	
	local t = map_pillar_raw_get(x,z)
	if t[y+1] then
		t[y+1] = {typ, r, g, b}
		map_pillar_raw_set(x,z,t)
	end
end

function map_block_break(x,y,z)
	local xlen,ylen,zlen 
	xlen,ylen,zlen = common.map_get_dims()
	if y < 0 or y >= ylen-1 then return false end
	
	local t = map_pillar_raw_get(x,z)
	if t[y+1] == nil then return false end
	t[y+1] = nil
	map_pillar_raw_set(x,z,t)
	
	map_pillar_aerate(x,z)
	map_pillar_aerate(x-1,z)
	map_pillar_aerate(x+1,z)
	map_pillar_aerate(x,z-1)
	map_pillar_aerate(x,z+1)
	
	map_chkdisbrk(x,y,z)
	
	return true
end

function map_block_delete(x,y,z)
	local xlen,ylen,zlen 
	xlen,ylen,zlen = common.map_get_dims()
	if y < 0 or y >= ylen-1 then return end
	
	local t = map_pillar_raw_get(x,z)
	t[y+1] = nil
	map_pillar_raw_set(x,z,t)
	
	map_pillar_aerate(x,z)
	map_pillar_aerate(x-1,z)
	map_pillar_aerate(x+1,z)
	map_pillar_aerate(x,z-1)
	map_pillar_aerate(x,z+1)
end

function map_block_pick(x,y,z)
	local xlen,ylen,zlen 
	xlen,ylen,zlen = common.map_get_dims()
	if x < 0 or x >= xlen then return end
	if y < 0 or y >= ylen then return end
	if z < 0 or z >= zlen then return end
	
	local t = map_pillar_raw_get(x,z)
	local c = t[y+1]
	
	if c==nil then error(x..","..y..","..z) end
	
	return c[1],c[2],c[3],c[4]
end

--checks for neighbors
function map_is_buildable(x, y, z)
	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	--warning! a long condition
	if map_block_get(x,y,z) == nil then
		if map_block_get(x + 1,y,z) ~= nil or map_block_get(x - 1,y,z) ~= nil or map_block_get(x,y + 1,z) ~= nil or map_block_get(x,y - 1,z) ~= nil or map_block_get(x,y,z - 1) ~= nil or map_block_get(x,y,z + 1) ~= nil then
			if x >=0 and x < xlen and y >= 0 and y < ylen - 2 and z >= 0 and z < zlen then
				return true;
			end
		end
	else
		return false;
	end
end
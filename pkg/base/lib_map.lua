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
function map_pillar_raw_get(x,z)
	local xlen,ylen,zlen 
	xlen,ylen,zlen = common.map_get_dims()
	local tpack = common.map_pillar_get(x,z)
	local t = {}
	local i,j,y
	i = 1
	y = 0
	
	while true do
		while y < tpack[i+1] do
			t[y+1] = nil
			y = y + 1
		end
		
		j = i + 4
		while y <= tpack[i+2] do
			t[y+1] = {tpack[j+3],tpack[j+2],tpack[j+1],tpack[j+0]}
			y = y + 1
			j = j + 4
		end
		
		if tpack[i] == 0 then
			while y < ylen do
				t[y+1] = false
				y = y + 1
			end
			break
		end
		
		local ntr = tpack[i]-(tpack[i+2]-tpack[i+1])
		i = i + 4*tpack[i]
		ntr = tpack[i] - ntr
		
		while y < ntr do
			t[y+1] = false
			y = y + 1
		end
		
		while y < tpack[i+3] do
			t[y+1] = {tpack[j+3],tpack[j+2],tpack[j+1],tpack[j+0]}
			y = y + 1
			j = j + 4
		end
	end
	
	return t
end

function map_pillar_raw_set(x,z,t)
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
		
		-- allocate slot
		i = #tpack+1
		tpack[i+0] = 0
		tpack[i+1] = y
		tpack[i+2] = 0
		tpack[i+3] = a
		
		-- copy top run
		while t[y+1] do
			tpack[#tpack+1] = t[y+1][4]
			tpack[#tpack+1] = t[y+1][3]
			tpack[#tpack+1] = t[y+1][2]
			tpack[#tpack+1] = t[y+1][1]
			y = y + 1
		end
		tpack[i+2] = y-1
		
		-- skip dirt
		while t[y+1] == false do
			y = y + 1
			if y >= ylen then break end
		end
		if y >= ylen then break end
		
		tpack[i] = tpack[i+2]-tpack[i+1]+2
		-- build bottom run
		while t[y+1] do
			tpack[#tpack+1] = t[y+1][4]
			tpack[#tpack+1] = t[y+1][3]
			tpack[#tpack+1] = t[y+1][2]
			tpack[#tpack+1] = t[y+1][1]
			tpack[i] = tpack[i] + 1
			y = y + 1
		end
		
		a = y
	end
	
	common.map_pillar_set(x,z,tpack)
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
	
	-- TODO!
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

function map_block_break(x,y,z)
	local xlen,ylen,zlen 
	xlen,ylen,zlen = common.map_get_dims()
	if y < 0 or y >= ylen then return end
	
	local t = map_pillar_raw_get(x,z)
	t[y+1] = nil
	map_pillar_raw_set(x,z,t)
	
	map_pillar_aerate(x,z)
	map_pillar_aerate(x-1,z)
	map_pillar_aerate(x+1,z)
	map_pillar_aerate(x,z-1)
	map_pillar_aerate(x,z+1)
end

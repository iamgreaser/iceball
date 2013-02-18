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

do
	local loose, user_toggles, user_settings
	loose, user_toggles, user_settings = ...
	local mw,mh
	mw = user_settings["mw"] or 512
	mh = user_settings["mh"] or 512
	local xs,zs
	xs = math.floor(512/mw)
	zs = math.floor(512/mh)

	local lmap = common.map_get()
	local function rnd()
		return (math.random()*2-1)
	end

	local function lfilt(l)
		local rl = {}
		local i,j
		for i=1,#l do
			for j=1,#(l[i]) do
				rl[#rl+1] = l[i][j]
			end
		end
		return rl
	end

	local ret = common.map_new(mw, 96, mh)
	common.map_set(ret)
	local hmap = {}
	local x,y,z
	
	for z=1,512 do
		hmap[z] = {}
		for x=1,512 do
			hmap[z][x] = 0
		end
	end
	
	local s=256
	hmap[1][1] = rnd()*64
	while s >= 1 do
		for y=s,512-1,s*2 do
			for x=s,512-1,s*2 do
				local x1=(x-s)%512+1
				local x2=(x+s)%512+1
				local y1=(y-s)%512+1
				local y2=(y+s)%512+1
				local c11=hmap[y1][x1]
				local c12=hmap[y1][x2]
				local c21=hmap[y2][x1]
				local c22=hmap[y2][x2]
				
				hmap[y1][x+1] = (c11+c12)/2+rnd()*math.min(64,s)
				hmap[y+1][x1] = (c11+c21)/2+rnd()*math.min(64,s)
				hmap[y+1][x+1] = (c11+c12+c21+c22)/4+rnd()*math.min(64,s)
			end
		end
		s = s / 2
	end
	
	local function hbias(x,y)
		return -math.sin(math.pi*0.125+math.pi*2*x/512)
	end
	
	local m1,m2
	m1=hmap[1][1]
	m2=m1
	for y=1,512 do for x=1,512 do
		local c = hmap[y][x]
		if c < m1 then m1 = c end
		if c > m2 then m2 = c end
	end end
	
	for y=1,512 do for x=1,512 do
		hmap[y][x] = (hmap[y][x] - m1)/(m2-m1)*2.2 + hbias(x,y)
		hmap[y][x] = math.sin(hmap[y][x]*math.pi*1.1/4)*32+64
	end end
	
	local water_lo = 97
	local water_hi = water_lo - 2
	local water_dist = water_lo - water_hi
	local land_lo = water_hi - 4
	local function cpal(y, highest)
		if water_hi < y or highest >= water_hi then
			local water_depth = math.min(1, math.max(0,(water_lo-y)/water_dist))
			return {water_depth*63+192,
					water_depth*32,
					0,
					1} 
		else
			local land_height = math.min(1,(water_hi-y)/land_lo)
			return {255*land_height,
					128+127*land_height,
					32+223*land_height,
					1}
		end
	end

	for z=0,511,zs do for x=0,511,xs do
		local cb=hmap[z+1][x+1]
		local cx1 = hmap[z+1][(x-xs)%512+1]
		local cx2 = hmap[z+1][(x+xs)%512+1]
		local cz1 = hmap[(z-zs)%512+1][x+1]
		local cz2 = hmap[(z+zs)%512+1][x+1]

		local y1 = math.floor(0.5+math.min(math.min(cx1,cx2),math.min(cz1,cz2)))
		local y2 = math.floor(0.5+math.max(math.max(cx1,cx2),math.max(cz1,cz2)))
		local ps = math.min(95,math.floor(0.5+math.max(cb,y1)))
		local pe = math.min(95,math.floor(0.5+math.max(cb,y2)))

		local l = {{0, ps, pe, 0}}
		for y=ps,pe do
			l[#l+1] = cpal(cb, ps)
			cb = cb + 1
		end
		common.map_pillar_set(x/xs, z/zs, lfilt(l))
	end end

	common.map_set(lmap)
	print("gen finished")
	return ret	
end


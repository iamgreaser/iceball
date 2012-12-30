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

-- Example mod. NOT RELIABLE.

loadfile("pkg/base/client_start.lua")(...)

do
	local xlen,ylen,zlen
	local x,y,z,i,j,ci
	
	xlen,ylen,zlen = common.map_get_dims()
	
	-- get top height map
	print("Calculating top height map")
	local hm = {}
	for z=0,zlen-1 do
		hm[z] = {}
		for x=0,xlen-1 do
			local l = common.map_pillar_get(x,z)
			hm[z][x] = l[1+1]
		end
	end
	
	-- build pillar table
	print("Building pillar run table")
	local pm = {}
	for z=0,zlen-1 do
		pm[z] = {}
		for x=0,xlen-1 do
			local pma = {}
			local l = common.map_pillar_get(x,z)
			i = 1
			while true do
				pma[#pma+1] = l[i+3]
				pma[#pma+1] = l[i+1]
				if l[i+0] == 0 then
					break
				end
				i = i + 4*l[i+0]
			end
			pma[1] = 0
			pm[z][x] = pma
		end
	end
	
	-- some functions for density calculation
	local function calcdens_pillar(x,z,y1,y2)
		local pma = pm[z%zlen][x%xlen]
		local y,i
		local d = 0
		for i=1,#pma,2 do
			local h1 = pma[i+0]
			local h2 = pma[i+1]
			if h1 > y2 then break end
			if h2 > y1 then
				for y=y1,y2 do
					if y >= h1 and y <= h2 then
						d = d + 1
					end
				end
			end
		end
		return d/(y2-y1+1)
	end
	
	function calcdens(x1,y1,z1,x2,y2,z2)
		local x,z
		local d = 0.0
		
		for z=z1,z2 do
		for x=x1,x2 do
			d = d + calcdens_pillar(x,z,y1,y2)
		end
		end
		
		return d/((x2-x1+1)*(z2-z1+1))
	end
	
	--print("TEST: Calculate air density")
	--print(calcdens(0,0,0,xlen-1,ylen-1,zlen-1))
	
	-- initialise light map
	print("Initialising light map")
	local lm = {}
	for z=0,zlen-1 do
		lm[z] = {}
		for x=0,xlen-1 do
			local l = common.map_pillar_get(x,z)
			local lma = {}
			i = 1
			local lti = 0
			local lt = 1.0
			local bn = nil
			local le = 0
			while true do
				local n = l[i+0]
				local tn = (l[i+2]-l[i+1]+1)
				local rn = (n ~= 0 and n-1) or tn
				local nbn = rn-tn
				
				if bn then
					local ca = l[i+3]-bn
					for j=le+1,ca do
						lt = lt * 0.8
					end
					for j=1,bn do
						lti = lti + 1
						lma[lti] = lt
						lt = lt * 0.8
					end
				end
				le = l[i+2]
				bn = nbn
				
				lti = lti + 1
				lma[lti] = nil
				i = i + n*4
				
				for j=1,tn do
					lti = lti + 1
					lma[lti] = lt
					lt = lt * 0.8
				end
				
				if n == 0 then break end
			end
			lma.len = lti
			lm[z][x] = lma
		end
	end
	
	-- spread
	-- TODO!
	
	-- apply lightmap
	print("Applying lightmap")
	for z=0,zlen-1 do
		for x=0,xlen-1 do
			local l = common.map_pillar_get(x,z)
			local lma = lm[z][x]
			for i=1,lma.len do
				if lma[i] then
					local lt = math.max(0.2,math.min(1.0,lma[i]))
					for j=1,3 do
						local ci = (i-1)*4+j
						l[ci] = math.floor(lt*l[ci]+0.5)
					end
				end
			end
			common.map_pillar_set(x,z,l)
		end
	end
	
	-- clean up
	lm = nil

	print("TODO: nicer stuff")
	-- done!
	print("Lighting done")
end

do
	local densbase = 0.01
	local h_tick_main_old = h_tick_main
	h_tick_main = function (sec_current, sec_delta)
		local ret = h_tick_main_old(sec_current, sec_delta)
		local cx,cy,cz
		cx,cy,cz = client.camera_get_pos()
		local dens = calcdens(
			math.floor(cx+0.5-5),
			math.floor(cy+0.5-7),
			math.floor(cz+0.5-5),
			math.floor(cx+0.5+5),
			math.floor(cy+0.5+3),
			math.floor(cz+0.5+5))
		
		densbase = densbase + (dens - densbase) * (1.0-math.exp(-3.0*sec_delta))
		
		client.map_fog_set(
			math.floor(0.5+192*densbase),
			math.floor(0.5+238*densbase),
			math.floor(0.5+255*densbase),
			math.floor(0.5+60*densbase))
		
		return ret
	end
end

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

function snow_init_pissdown(p_snow)
	print("Snowing the map...")
	local xlen,ylen,zlen
	local x,y,z,i
	xlen,ylen,zlen = common.map_get_dims()
	
	for z=0,zlen-1 do
	for x=0,xlen-1 do
		local t = common.map_pillar_get(x,z)
		--[[local s = ""
		for i=1,#t do
			s = s.." "..t[i]
		end
		print(s)]]
		if t[1+1] > 0 and t[1+1] < ylen-1 and math.random() < p_snow then
			for i=#t,5,-1 do t[i+4] = t[i] end
			if t[1+0] ~= 0 then t[1+0] = t[1+0] + 1 end
			t[1+1] = t[1+1] - 1
			t[5+0] = 255
			t[5+1] = 255
			t[5+2] = 255
			t[5+3] = 2
			if img_overview then
				common.img_pixel_set(img_overview,x,z,0xFFFFFFFF)
			end
		end
		--print(x,z)
		common.map_pillar_set(x,z,t)
	end
	end
	print("Done!")
end

function snow_init_hook()
	do
		local function mpgnew(mpgold)
			return function(px,pz)
				local t = map_pillar_raw_unpack(mpgold(px,pz))
				local i
				local xlen,ylen,zlen
				xlen,ylen,zlen = common.map_get_dims()
				for i=0,ylen-1 do
					if t[i] and t[i][1] == 2 then
						t[i] = nil
					end
				end
				return map_pillar_raw_pack(t)
			end
		end
		
		local bicold = box_is_clear
		function box_is_clear(x1,y1,z1,x2,y2,z2,canwrap)
			local mpgold = common.map_pillar_get
			common.map_pillar_get = mpgnew(mpgold)
			local ret = bicold(x1,y1,z1,x2,y2,z2,canwrap)
			common.map_pillar_get = mpgold
			return ret
		end
		
		local trgold = trace_gap
		function trace_gap(x,y,z)
			local mpgold = common.map_pillar_get
			common.map_pillar_get = mpgnew(mpgold)
			local r1,r2
			r1,r2 = trgold(x,y,z)
			common.map_pillar_get = mpgold
			return r1,r2
		end
	end
end

if server then
	snow_init_pissdown(0.1)
	snow_init_hook()
end

if client then
	snow_init_hook()
end

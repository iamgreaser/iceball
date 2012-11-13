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

function snow_init()
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
		if t[1+1] > 0 and math.random() < 0.9 then
			for i=#t,5,-1 do t[i+4] = t[i] end
			if t[1+0] ~= 0 then t[1+0] = t[1+0] + 1 end
			t[1+1] = t[1+1] - 1
			t[5+0] = 255
			t[5+1] = 255
			t[5+2] = 255
			t[5+3] = 2
		end
		--print(x,z)
		common.map_pillar_set(x,z,t)
	end
	end
	
	do
		local bicold = box_is_clear
		local mpgold = common.map_pillar_get
		function box_is_clear(x1,y1,z1,x2,y2,z2,canwrap)
			common.map_pillar_get = function (px,pz)
				local t = mpgold(px,pz)
				if t[5+3] == 2 then
					local i
					for i=5,#t-4,1 do t[i] = t[i+4] end
					if t[1+0] ~= 0 then t[1+0] = t[1+0] - 1 end
					t[1+1] = t[1+1] + 1
					for i=1,4 do t[#t] = nil end
					if math.random() < 0.05 then
						common.map_pillar_set(px,pz,t)
					end
				end
				return t
			end
			local ret = bicold(x1,y1,z1,x2,y2,z2,canwrap)
			common.map_pillar_get = mpgold
			return ret
		end
	end
end

do
	local snow_oldtick = client.hook_tick
	function client.hook_tick(...)
		snow_init()
		client.hook_tick = snow_oldtick
		return client.hook_tick(...)
	end
end

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


function snow_drop_part(x,z,t,bcast)
	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	
	local ty = t[1+1]
	if ty > 0 and ty < ylen-1 then
		map_block_set(x,ty-1,z,2,255,255,255)
		if img_overview then
			common.img_pixel_set(img_overview,x,z,0xFFFFFFFF)
		end
		if bcast then
			net_broadcast(nil, common.net_pack("BHHHBBBB",
				0x08,x,ty-1,z,255,255,255,2))
		end
	end
end

function snow_drop(x,z,bcast)
	local tl = common.map_pillar_get(x-1,z)
	local tr = common.map_pillar_get(x+1,z)
	local tu = common.map_pillar_get(x,z-1)
	local td = common.map_pillar_get(x,z+1)
	local tc = common.map_pillar_get(x,z)
	
	if tl[1+1] > tc[1+1] then
		snow_drop_part(x-1,z,tl,bcast)
	elseif tr[1+1] > tc[1+1] then
		snow_drop_part(x+1,z,tr,bcast)
	elseif tu[1+1] > tc[1+1] then
		snow_drop_part(x,z-1,tu,bcast)
	elseif td[1+1] > tc[1+1] then
		snow_drop_part(x,z+1,td,bcast)
	else
		snow_drop_part(x,z,tc)
	end
end

function snow_init_pissdown(p_snow)
	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	print("Snowing the map...",xlen,ylen,zlen)
	local x,y,z,i
	
	for z=0,zlen-1 do
	if z%8 == 0 then print(z) end
	for x=0,xlen-1 do
		if math.random() < p_snow then
			snow_drop(x,z,false)
		end
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
	--snow_init_pissdown(0.1)
	snow_init_hook()
	local snow_lasttime = nil
	local snow_freq = 0.1
	local snow_oldtick = server.hook_tick
	function snow_tick(sec_current, sec_delta)
		snow_lasttime = snow_lasttime or sec_current
		local ct = 5
		local i
		
		-- hack to work around a bug
		if snow_lasttime - sec_current > 5 then
			snow_lasttime = sec_current
		end
		
		while sec_current >= snow_lasttime + snow_freq do
			local xlen,ylen,zlen
			xlen,ylen,zlen = common.map_get_dims()
			for i=1,5 do
				snow_drop(math.floor(math.random()*xlen),math.floor(math.random()*zlen),true)
			end
			snow_lasttime = snow_lasttime + snow_freq
			ct = ct - 1
			if ct <= 0 then
				snow_lasttime = sec_current
				break
			end
		end
		server.hook_tick = snow_oldtick
		local ret = server.hook_tick(sec_current, sec_delta)
		snow_oldtick = server.hook_tick
		server.hook_tick = snow_tick
		return ret
	end
	
	server.hook_tick = snow_tick
end

if client then
	snow_init_hook()
end

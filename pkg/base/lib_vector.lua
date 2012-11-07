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

function box_is_clear(x1,y1,z1,x2,y2,z2)
	local x,z,i
	
	x1 = math.floor(x1)
	y1 = math.floor(y1)
	z1 = math.floor(z1)
	x2 = math.ceil(x2)-1
	y2 = math.ceil(y2)-1
	z2 = math.ceil(z2)-1
	
	for z=z1,z2 do
	for x=x1,x2 do
		local l = common.map_pillar_get(x, z)
		while true do
			if y2 < l[i+2] then break end
			if l[i] == 0 then return false end
			i = i + l[i]*4
			if y1 < l[i+3] then return false end
		end
	end
	end
	
	return true
end

function trace_map_box(x1,y1,z1, x2,y2,z2, bx1,by1,bz1, bx2,by2,bz2)
	-- delta
	local dx,dy,dz
	dx = x2-x1
	dy = y2-y1
	dz = z2-z1
	
	-- offsets
	local fx,fy,fz
	if dx < 0 then fx = bx1 else fx = bx2 end
	if dy < 0 then fy = by1 else fy = by2 end
	if dz < 0 then fz = bz1 else fz = bz2 end
	
	-- direction
	local gx,gy,gz
	if dx < 0 then gx = -1 else gx = 1 end
	if dy < 0 then gy = -1 else gy = 1 end
	if dz < 0 then gz = -1 else gz = 1 end
	dx = dx * gx
	dy = dy * gy
	dz = dz * gz
	
	-- apply offset
	x1 = x1 + fx
	y1 = y1 + fy
	z1 = z1 + fz
	x2 = x2 + fx
	y2 = y2 + fy
	z2 = z2 + fz
	
	-- cell
	local cx,cy,cz
	cx = x1
	cy = y1
	cz = z1
	
	-- sub deltas
	local sx, sy, sz
	sx = math.fmod(dx, 1.0)
	sy = math.fmod(dy, 1.0)
	sz = math.fmod(dz, 1.0)
	if gx >= 0 then sx = 1-sx end
	if gy >= 0 then sy = 1-sy end
	if gz >= 0 then sz = 1-sz end
	
	
	-- TODO!
	return nil
	
	--return x1-fx, y1-fy, z1-fz
end

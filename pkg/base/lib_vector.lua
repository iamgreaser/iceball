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

function vcross(x1,y1,z1,x2,y2,z2)
	return    y1*z2 - z1*y2
		, z1*x2 - x1*z2
		, x1*y2 - y1*x2
end

function vdot(x1,y1,z1,x2,y2,z2)
	return x1*x2 + y1*y2 + z1*z2
end

function vlen2(x,y,z)
	return x*x + y*y + z*z
end

function vlen(x,y,z)
	return math.sqrt(vlen2(x,y,z))
end

function vnorm(x,y,z)
	local d = math.max(0.0000001,vlen(x,y,z))
	return x/d, y/d, z/d
end

function vrotate(theta,x,y,z,bx,by,bz)
	-- glRotate as specified by SGI :D
	bx,by,bz = vnorm(bx,by,bz)
	
	-- S = [  0 -z  y ]
	--     [  z  0 -x ]
	--     [ -y  x  0 ]
	-- R = uuT + cosO (I - uuT) + sinO S
	-- alternatively
	-- R = uuT * (1 - cosO) + IcosO + sinO S
	
	local ct = math.cos(theta)
	local st = math.sin(theta)
	
	return
		x*(bx*bx*(1-ct)+ct)       + y*(bx*by*(1-ct) + st*-bz)  + z*(bx*bz*(1-ct) + st*by),
		x*(by*bx*(1-ct) + st*bz)  + y*(by*by*(1-ct)*(1-ct)+ct) + z*(by*bz*(1-ct) + st*-bx),
		x*(bz*bx*(1-ct) + st*-by) + y*(bz*by*(1-ct) + st*bx)   + z*(bz*bz*(1-ct)+ct)
end

function trace_gap(x,y,z)
	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	
	local l = common.map_pillar_get(math.floor(x), math.floor(z))
	i = 1
	local h1,h2
	h1 = nil
	while true do
		h2 = l[i+1]
		if h2 == ylen-1 then h2 = ylen end
		if y < l[i+1] or l[i] == 0 then return h1, h2 end
		i = i + l[i]*4
		if y < l[i+3] then return h1, h2 end
		h1 = l[i+3]
		h2 = l[i+1]
	end
end

function box_is_clear(x1,y1,z1,x2,y2,z2,canwrap)
	local x,z,i
	
	x1 = math.floor(x1)
	y1 = math.floor(y1)
	z1 = math.floor(z1)
	x2 = math.floor(x2)
	y2 = math.floor(y2)
	z2 = math.floor(z2)
	
	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	
	if not canwrap then
		if x1 < 0 or z1 < 0 then
			return false
		elseif x2 >= xlen or z2 >= zlen then
			return false
		end
	end
	
	for z=z1,z2 do
	for x=x1,x2 do
		local l = common.map_pillar_get(x, z)
		i = 1
		while true do
			if l[i+1] == ylen-1 and y2 < ylen then break end
			if y2 < l[i+1] then break end
			if l[i] == 0 then return false end
			i = i + l[i]*4
			if y1 < l[i+3] then return false end
		end
	end
	end
	
	return true
end

function trace_map_ray_dist(x1,y1,z1, vx,vy,vz, maxdist, nil_on_maxdist)
	if nil_on_maxdist == nil then nil_on_maxdist = true end

	local function depsilon(d)
		if d < 0.0000001 then
			return 0.0000001
		else
			return d
		end
	end
	
	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	
	-- offsets
	local fx,fy,fz
	if vx < 0 then fx = bx1 else fx = bx2 end
	if vy < 0 then fy = by1 else fy = by2 end
	if vz < 0 then fz = bz1 else fz = bz2 end
	
	-- direction
	local gx,gy,gz
	if vx < 0 then gx = -1 else gx = 1 end
	if vy < 0 then gy = -1 else gy = 1 end
	if vz < 0 then gz = -1 else gz = 1 end
	vx = vx * gx
	vy = vy * gy
	vz = vz * gz
	
	-- cell
	local cx,cy,cz
	cx = math.floor(x1)
	cy = math.floor(y1)
	cz = math.floor(z1)
	
	-- subpos
	local sx,sy,sz
	sx = x1-cx
	sy = y1-cy
	sz = z1-cz
	if gx >= 0 then sx = 1-sx end
	if gy >= 0 then sy = 1-sy end
	if gz >= 0 then sz = 1-sz end
	
	local dist = 0
	local pillar, npillar
	npillar = common.map_pillar_get(cx,cz)
	pillar = npillar
	
	while true do
		local tx = sx/depsilon(vx)
		local ty = sy/depsilon(vy)
		local tz = sz/depsilon(vz)
		local t,d
		local ncx,ncy,ncz
		ncx,ncy,ncz = cx,cy,cz
		
		if tx < ty and tx < tz then
			t = tx
			d = 0
			ncx = cx + gx
			npillar = common.map_pillar_get(ncx,ncz)
		elseif ty < tx and ty < tz then
			t = ty
			d = 1
			ncy = cy + gy
		else
			t = tz
			d = 2
			ncz = cz + gz
			npillar = common.map_pillar_get(ncx,ncz)
		end
		
		dist = dist + t
		
		if dist > maxdist and nil_on_maxdist then
			return nil, nil, nil, nil, nil, nil, nil
		elseif dist > maxdist and not nil_on_maxdist then
			return dist, cx, cy, cz, ncx, ncy, ncz
		end
		
		local i=1
		while true do
			if ncy < npillar[i+1] then break end
			if npillar[i] == 0 then return dist, cx, cy, cz, ncx, ncy, ncz end
			i = i + npillar[i]*4
			if ncy < npillar[i+3] then return dist, cx, cy, cz, ncx, ncy, ncz end
		end
		
		sx = sx - vx*t
		sy = sy - vy*t
		sz = sz - vz*t
		
		cx,cy,cz = ncx,ncy,ncz
		
		if d == 0 then sx = 1
		elseif d == 1 then sy = 1
		else sz = 1 end
		
		pillar = npillar
	end
end

function trace_map_box(x1,y1,z1, x2,y2,z2, bx1,by1,bz1, bx2,by2,bz2, canwrap)
	local function depsilon(d)
		if d < 0.0000001 then
			return 0.0000001
		else
			return d
		end
	end
	
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
	
	-- combined box size
	local bcx,bcy,bcz
	bcx = (bx2-bx1)
	bcy = (by2-by1)
	bcz = (bz2-bz1)
	
	-- top left offset (note, incorrect name!)
	local tlx,tly,tlz
	if gx >= 0 then tlx = 0.999 else tlx = 0.001 end
	if gy >= 0 then tly = 0.999 else tly = 0.001 end
	if gz >= 0 then tlz = 0.999 else tlz = 0.001 end
	
	-- apply offset
	x1 = x1 + fx
	y1 = y1 + fy
	z1 = z1 + fz
	bx1 = bx1 - fx
	by1 = by1 - fy
	bz1 = bz1 - fz
	bx2 = bx2 - fx
	by2 = by2 - fy
	bz2 = bz2 - fz
	
	-- cell
	local cx,cy,cz
	cx = math.floor(x1)
	cy = math.floor(y1)
	cz = math.floor(z1)
	
	-- target cell
	local tcx,tcy,tcz
	tcx = math.floor(x2+fx+gx*0.002)
	tcy = math.floor(y2+fy+gy*0.002)
	tcz = math.floor(z2+fz+gz*0.002)
	
	-- sub deltas
	local sx, sy, sz
	sx = (x1 % 1.0) - 0.001
	sy = (y1 % 1.0) - 0.001
	sz = (z1 % 1.0) - 0.001
	if gx >= 0 then sx = 1-sx end
	if gy >= 0 then sy = 1-sy end
	if gz >= 0 then sz = 1-sz end
	
	-- restricted x/y/z
	local rx,ry,rz
	rx = nil
	ry = nil
	rz = nil
	
	-- TODO: unset these when another boundary is crossed
	
	local i
	local iend = (
		  math.abs(tcx-cx)
		+ math.abs(tcy-cy)
		+ math.abs(tcz-cz)
	)
	
	for i=1,iend do
		-- get the time it takes to hit the boundary
		local tx = sx/depsilon(dx)
		local ty = sy/depsilon(dy)
		local tz = sz/depsilon(dz)
		
		local t, d, ck
		
		if tx < ty and tx < tz then
			-- X first
			d = 0
			t = tx
		elseif ty < tx and ty < tz then
			-- Y first
			d = 1
			t = ty
		else
			-- Z first
			d = 2
			t = tz
		end
		
		sx = sx - t*dx
		sy = sy - t*dy
		sz = sz - t*dz
		x1 = rx or x1 + t*dx*gx
		y1 = ry or y1 + t*dy*gy
		z1 = rz or z1 + t*dz*gz
		
		if d == 0 then
			-- X first
			sx = 1.0
			ck = rx or box_is_clear(cx+gx,y1+by1,z1+bz1,cx+gx,y1+by2,z1+bz2,canwrap)
			if not ck then rx = cx + tlx end
			if not rx then cx = cx + gx end
		elseif d == 1 then
			-- Y first
			sy = 1.0
			ck = ry or box_is_clear(x1+bx1,cy+gy,z1+bz1,x1+bx2,cy+gy,z1+bz2,canwrap)
			if not ck then ry = cy + tly end
			if not ry then cy = cy + gy end
		else
			-- Z first
			sz = 1.0
			ck = rz or box_is_clear(x1+bx1,y1+by1,cz+gz,x1+bx2,y1+by2,cz+gz,canwrap)
			if not ck then rz = cz + tlz end
			if not rz then cz = cz + gz end
		end
		
		--if not ck then return x1-bx1, y1-by1, z1-bz1 end
	end
	--
	if rx then rx = rx - fx end
	if ry then ry = ry - fy end
	if rz then rz = rz - fz end
	
	return rx or x2, ry or y2, rz or z2
end

function isect_line_sphere_delta(dx,dy,dz,fwx,fwy,fwz)
	local dd = dx*dx+dy*dy+dz*dz
	local dotk = dx*fwx+dy*fwy+dz*fwz
	if dotk <= 0 then return nil end
	local dot = math.sqrt(dd-dotk*dotk)
	return dot, dd
end

function isect_line_sphere(x1,y1,z1,fx,fy,fz,x2,y2,z2)
	return isect_line_sphere_delta(x2-x1,y2-y1,z2-z1,fx,fy,fz)
end


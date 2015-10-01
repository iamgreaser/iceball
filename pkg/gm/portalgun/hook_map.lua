--[[
    This file is derived from code from Ice Lua Components.

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

local portal_transforms = {}
local portal_traces = {}
local portal_traces_mcache = {}
portal_traces_enabled = true

portal_transforms_performed = {}

local function trace_portal_get_transform(cx, cy, cz)
	if not(portal_traces[cz] and portal_traces[cz][cx] and portal_traces[cz][cx][cy]) then
		return nil
	end

	local tidx = portal_traces[cz][cx][cy]
	local tf = portal_transforms[tidx]

	return tf
end

function trace_portal_transform(tf, cx, cy, cz, vx, vy, vz)
	print("ENTRY", cx, cy, cz, vx, vy, vz)

	-- Get origins
	local cx1 = tf[1][1] + 0.5 + tf[1][4]*0.5
	local cy1 = tf[1][2] + 0.5 + tf[1][5]*0.5
	local cz1 = tf[1][3] + 0.5 + tf[1][6]*0.5
	local cx2 = tf[2][1] + 0.5 + tf[2][4]*0.5
	local cy2 = tf[2][2] + 0.5 + tf[2][5]*0.5
	local cz2 = tf[2][3] + 0.5 + tf[2][6]*0.5

	-- Get normals
	local nx1 = tf[1][4]
	local ny1 = tf[1][5]
	local nz1 = tf[1][6]
	local nx2 = tf[2][4]
	local ny2 = tf[2][5]
	local nz2 = tf[2][6]

	-- Get sky vectors
	local sx1 = tf[1][7]
	local sy1 = tf[1][8]
	local sz1 = tf[1][9]
	local sx2 = tf[2][7]
	local sy2 = tf[2][8]
	local sz2 = tf[2][9]

	-- Get horiz vectors
	local hx1 = ny1*sz1-nz1*sy1
	local hy1 = nz1*sx1-nx1*sz1
	local hz1 = nx1*sy1-ny1*sx1
	local hx2 = ny2*sz2-nz2*sy2
	local hy2 = nz2*sx2-nx2*sz2
	local hz2 = nx2*sy2-ny2*sx2

	-- Get offsets
	local no1 = nx1*cx1 + ny1*cy1 + nz1*cz1
	local no2 = nx2*cx2 + ny2*cy2 + nz2*cz2
	local so1 = sx1*cx1 + sy1*cy1 + sz1*cz1
	local so2 = sx2*cx2 + sy2*cy2 + sz2*cz2
	local ho1 = hx1*cx1 + hy1*cy1 + hz1*cz1
	local ho2 = hx2*cx2 + hy2*cy2 + hz2*cz2

	print("NORMS", nx1, ny1, nz1, nx2, ny2, nz2, no1)
	print("SKIES", sx1, sy1, sz1, sx2, sy2, sz2, so1)
	print("HORIZ", hx1, hy1, hz1, hx2, hy2, hz2, ho1)

	-- Get source offsets
	local noP = nx1*cx + ny1*cy + nz1*cz - no1
	local soP = sx1*cx + sy1*cy + sz1*cz - so1
	local hoP = hx1*cx + hy1*cy + hz1*cz - ho1

	-- Update position
	cx = nx2*noP + sx2*soP + hx2*hoP + no2*nx2 + so2*sx2 + ho2*hx2
	cy = ny2*noP + sy2*soP + hy2*hoP + no2*ny2 + so2*sy2 + ho2*hy2
	cz = nz2*noP + sz2*soP + hz2*hoP + no2*nz2 + so2*sz2 + ho2*hz2

	-- Get direction offsets
	local noV = nx1*vx + ny1*vy + nz1*vz
	local soV = sx1*vx + sy1*vy + sz1*vz
	local hoV = hx1*vx + hy1*vy + hz1*vz

	-- Update direction
	vx = -(nx2*noV + sx2*soV + hx2*hoV)
	vy = -(ny2*noV + sy2*soV + hy2*hoV)
	vz = -(nz2*noV + sz2*soV + hz2*hoV)

	-- Return!
	print("EXIT ", cx, cy, cz, vx, vy, vz)
	return cx, cy, cz, vx, vy, vz

end

local function trace_portal_set_mark(pid, portal_select, cx, cy, cz)
	local l = portal_traces
	if not l[cz] then l[cz] = {} end
	if not l[cz][cx] then l[cz][cx] = {} end
	l[cz][cx][cy] = pid*2+portal_select
	--print(cx, cy, cz)
end

local function trace_portal_insert(p, pid, portal_select)
	local cx, cy, cz = p[1], p[2], p[3]
	local dx, dy, dz = p[4], p[5], p[6]
	local sx, sy, sz = p[7], p[8], p[9]
	local hx = dy*sz-dz*sy
	local hy = dz*sx-dx*sz
	local hz = dx*sy-dy*sx

	-- Mark area
	trace_portal_set_mark(pid, portal_select, cx   , cy   , cz   )
	trace_portal_set_mark(pid, portal_select, cx-sx, cy-sy, cz-sz)
	trace_portal_set_mark(pid, portal_select, cx+sx, cy+sy, cz+sz)
	trace_portal_set_mark(pid, portal_select, cx   +hx, cy   +hy, cz   +hz)
	trace_portal_set_mark(pid, portal_select, cx-sx+hx, cy-sy+hy, cz-sz+hz)
	trace_portal_set_mark(pid, portal_select, cx+sx+hx, cy+sy+hy, cz+sz+hz)
	trace_portal_set_mark(pid, portal_select, cx   -hx, cy   -hy, cz   -hz)
	trace_portal_set_mark(pid, portal_select, cx-sx-hx, cy-sy-hy, cz-sz-hz)
	trace_portal_set_mark(pid, portal_select, cx+sx-hx, cy+sy-hy, cz+sz-hz)
end

local function trace_portal_setup()
	local i

	portal_traces = {}
	portal_transforms = {}

	if not portal_traces_enabled then return end

	-- Gather portal info
	for i=1,players.max do
		local plr = players[i]
		if plr then
			local p1 = plr.portal_list[1]
			local p2 = plr.portal_list[2]

			if p1 and p2 then
				-- Create transformation!
				local t1 = {p1, p2}
				local t2 = {p2, p1}

				-- Save transformation!
				portal_transforms[i*2+1] = t1
				portal_transforms[i*2+2] = t2
				-- TODO! (instead we're drilling the map)

				-- Place marks which indicate the transformation thing!
				trace_portal_insert(p1, i, 1)
				trace_portal_insert(p2, i, 2)
			end
		end
	end
end

local function map_pillar_get_fake(x, z)
	-- Check if we have a portal list
	if not (portal_traces[z] and portal_traces[z][x]) then
		return common.map_pillar_get(x, z)
	end

	-- Check if we have a cache
	if portal_traces_mcache[z] and portal_traces_mcache[z][x] then
		return portal_traces_mcache[z][x]
	end

	--print("TRACES EXIST", x, z)

	-- We have to edit because of this portal list
	local l = common.map_pillar_get(x, z)
	local pl = portal_traces[z][x]

	-- Unpack
	local ul = map_pillar_raw_unpack(l)

	-- Replace things
	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()
	local i
	for i=1,ylen do
		if pl[i-1] then
			--print("DELETE", x, i, z)
			ul[i] = nil
		end
	end

	-- Repack
	l = map_pillar_raw_pack(ul)

	-- Dump this into the cache
	if not portal_traces_mcache[z] then portal_traces_mcache[z] = {} end
	portal_traces_mcache[z][x] = l

	-- Return
	return l
end

-- need to copy-paste these functions from lib_vector.lua in order to mangle them
-- Map helpers
function trace_gap(x,y,z)
	local xlen,ylen,zlen
	xlen,ylen,zlen = common.map_get_dims()

	local l = map_pillar_get_fake(math.floor(x), math.floor(z))
	local i = 1
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
		local l = map_pillar_get_fake(x, z)
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
-- Ray tracing
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
	if not x1 then return nil end
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
	npillar = map_pillar_get_fake(cx,cz)
	pillar = npillar

	trace_portal_setup() -- Have to do this!
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
			npillar = map_pillar_get_fake(ncx,ncz)
		elseif ty < tx and ty < tz then
			t = ty
			d = 1
			ncy = cy + gy
		else
			t = tz
			d = 2
			ncz = cz + gz
			npillar = map_pillar_get_fake(ncx,ncz)
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

	trace_portal_setup() -- Have to do this!
	-- TODO: unset these when another boundary is crossed

	local i
	local iend = (
		  math.abs(tcx-cx)
		+ math.abs(tcy-cy)
		+ math.abs(tcz-cz)
	)

	portal_transforms_performed = {}
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
		local tf = trace_portal_get_transform(cx, cy, cz)
		if tf then
			table.insert(portal_transforms_performed, tf)
			cx, cy, cz, dx, dy, dz = trace_portal_transform(tf, cx, cy, cz, dx, dy, dz)
			x1, y1, z1, gx, gy, gz = trace_portal_transform(tf, x1, y1, z1, gx, gy, gz)
			x2, y2, z2 = trace_portal_transform(tf, x2, y2, z2, 0, 0, 0)
			if dx < 0 then sx = 1.0 - sx; dx = -dx end
			if dy < 0 then sy = 1.0 - sy; dy = -dy end
			if dz < 0 then sz = 1.0 - sz; dz = -dz end
		end
	end
	--
	if rx then rx = rx - fx end
	if ry then ry = ry - fy end
	if rz then rz = rz - fz end

	return rx or x2, ry or y2, rz or z2
end


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

-- Vertex array API stuff
-- Basically, loaders and whatnot.
-- VA API available since 0.2a-1.

--function parsekv6(pkt, name, ptsize, ptspacing)
function parsekv6(pkt, scale)
	scale = scale or 1.0
	local ptsize = 1
	local ptspacing = scale
	if pkt:sub(1,4) ~= "Kvxl" then
		error("not a KV6 model")
	end

	local _

	-- load header
	local xsiz, ysiz, zsiz
	_, xsiz, ysiz, zsiz, pkt = common.net_unpack("IIII", pkt)
	local xpivot, ypivot, zpivot
	xpivot, ypivot, zpivot, pkt = common.net_unpack("fff", pkt)
	local blklen
	blklen, pkt = common.net_unpack("I", pkt)

	-- load blocks
	local l = {}
	local i
	for i=1,blklen do
		local r,g,b,z,vis
		b,g,r,_,z,vis,_,pkt = common.net_unpack("BBBBHBB", pkt)

		local vnx = (math.floor(vis/1 ) % 2) ~= 0
		local vpx = (math.floor(vis/2 ) % 2) ~= 0
		local vnz = (math.floor(vis/4 ) % 2) ~= 0
		local vpz = (math.floor(vis/8 ) % 2) ~= 0
		local vny = (math.floor(vis/16) % 2) ~= 0
		local vpy = (math.floor(vis/32) % 2) ~= 0

		l[i] = {
			radius = ptsize,
			x = nil, z = nil, y = (z-zpivot)*ptspacing,
			r = r, g = g, b = b,
			vnx = vnx, vny = vny, vnz = vnz,
			vpx = vpx, vpy = vpy, vpz = vpz,
		}
	end

	-- skip x offsets
	pkt = pkt:sub(4*xsiz+1)

	-- load xy offsets
	-- TODO: check order
	local x,y,i,j
	i=1
	for x=1,xsiz do
	for y=1,ysiz do
		local ct
		ct, pkt = common.net_unpack("H", pkt)
		for j=1,ct do
			l[i].x = (x-xpivot)*ptspacing
			l[i].z = (y-ypivot)*ptspacing
			i = i + 1
		end
	end
	end

	-- create model
	--[[
	local mdl, mdl_bone
	mdl = common.model_new(1)
	mdl, mdl_bone = common.model_bone_new(mdl, #l)
	common.model_bone_set(mdl, mdl_bone, name, l)
	print("model data len:", #l)
	return mdl
	]]

	local vl = {}
	for i=1,#l do
		local x0 = l[i].x
		local y0 = l[i].y
		local z0 = l[i].z
		local x1 = l[i].x+scale
		local y1 = l[i].y+scale
		local z1 = l[i].z+scale
		local r  = l[i].r/255.0
		local g  = l[i].g/255.0
		local b  = l[i].b/255.0

		if l[i].vnx then
			vl[1+#vl] = {x0,y0,z0,r,g,b}
			vl[1+#vl] = {x0,y1,z0,r,g,b}
			vl[1+#vl] = {x0,y0,z1,r,g,b}
			vl[1+#vl] = {x0,y0,z1,r,g,b}
			vl[1+#vl] = {x0,y1,z0,r,g,b}
			vl[1+#vl] = {x0,y1,z1,r,g,b}
		end

		if l[i].vpx then
			vl[1+#vl] = {x1,y0,z0,r,g,b}
			vl[1+#vl] = {x1,y0,z1,r,g,b}
			vl[1+#vl] = {x1,y1,z0,r,g,b}
			vl[1+#vl] = {x1,y1,z0,r,g,b}
			vl[1+#vl] = {x1,y0,z1,r,g,b}
			vl[1+#vl] = {x1,y1,z1,r,g,b}
		end

		if l[i].vny then
			vl[1+#vl] = {x0,y0,z0,r,g,b}
			vl[1+#vl] = {x0,y0,z1,r,g,b}
			vl[1+#vl] = {x1,y0,z0,r,g,b}
			vl[1+#vl] = {x1,y0,z0,r,g,b}
			vl[1+#vl] = {x0,y0,z1,r,g,b}
			vl[1+#vl] = {x1,y0,z1,r,g,b}
		end

		if l[i].vpy then
			vl[1+#vl] = {x0,y1,z0,r,g,b}
			vl[1+#vl] = {x1,y1,z0,r,g,b}
			vl[1+#vl] = {x0,y1,z1,r,g,b}
			vl[1+#vl] = {x0,y1,z1,r,g,b}
			vl[1+#vl] = {x1,y1,z0,r,g,b}
			vl[1+#vl] = {x1,y1,z1,r,g,b}
		end

		if l[i].vnz then
			vl[1+#vl] = {x0,y0,z0,r,g,b}
			vl[1+#vl] = {x1,y0,z0,r,g,b}
			vl[1+#vl] = {x0,y1,z0,r,g,b}
			vl[1+#vl] = {x0,y1,z0,r,g,b}
			vl[1+#vl] = {x1,y0,z0,r,g,b}
			vl[1+#vl] = {x1,y1,z0,r,g,b}
		end

		if l[i].vpz then
			vl[1+#vl] = {x0,y0,z1,r,g,b}
			vl[1+#vl] = {x0,y1,z1,r,g,b}
			vl[1+#vl] = {x1,y0,z1,r,g,b}
			vl[1+#vl] = {x1,y0,z1,r,g,b}
			vl[1+#vl] = {x0,y1,z1,r,g,b}
			vl[1+#vl] = {x1,y1,z1,r,g,b}
		end
	end
	return common.va_make(vl)
end

--[[
function loadkv6(fname, name, ptsize, ptspacing)
	return parsekv6(common.bin_load(fname), name, ptsize, ptspacing)
end
]]
function loadkv6(fname, scale)
	return parsekv6(common.bin_load(fname), scale)
end


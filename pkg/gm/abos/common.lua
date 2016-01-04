math.randomseed(common.time())

function tri_to_plane(p1, p2, p3)
	-- Form triangle
	local x1,y1,z1 = p1[1], p1[2], p1[3]
	local x2,y2,z2 = p2[1], p2[2], p2[3]
	local x3,y3,z3 = p3[1], p3[2], p3[3]

	-- Get deltas
	local dx1,dy1,dz1 = x3-x1, y3-y1, z3-z1
	local dx2,dy2,dz2 = x3-x2, y3-y2, z3-z2

	-- Form normal
	local nx = dy1*dz2 - dz1*dy2
	local ny = dz1*dx2 - dx1*dz2
	local nz = dx1*dy2 - dy1*dx2

	-- Normalise normal
	local nd2 = nx*nx + ny*ny + nz*nz
	local nd = math.sqrt(nd2)
	local ndi = -1.0/nd -- yes, we have the cross product args backwards, so compensate here
	nx = nx * ndi
	ny = ny * ndi
	nz = nz * ndi

	-- Get offset
	local nw = -(x3*nx + y3*ny + z3*nz)

	-- Return plane
	return nx, ny, nz, nw
end

function autonormal(l)
	local i, j
	for i=1,#l,3 do
		-- Theorem: 1-based indexing is a pile of shit
		-- Proof:
		local p1 = l[i+0]
		local p2 = l[i+1]
		local p3 = l[i+2]

		local nx, ny, nz, nw = tri_to_plane(p1, p2, p3)

		for j=1,3 do
			l[i+j-1][1+(3+0)] = nx
			l[i+j-1][1+(3+1)] = ny
			l[i+j-1][1+(3+2)] = nz
		end
		-- QED
	end
end


function epsileq(u, v)
	return math.abs(u - v) < 0.0000000001
end

function anytostring(v)
	if type(v) == "table" then
		local s = "{"
		local k, sv
		for k, sv in pairs(v) do
			s = s .. "[".. anytostring(k) .. "] = " .. anytostring(sv) .. ", "
		end
		s = s .. "}"
		return s
	elseif type(v) == "string" then
		-- TODO: do this properly
		return "\"" .. v .. "\""
	else
		return tostring(v)
	end
end

function quad_expand(l)
	local newl = {}
	local i

	for i=1,#l,4 do
		newl[1+#newl] = l[i+0]
		newl[1+#newl] = l[i+1]
		newl[1+#newl] = l[i+2]
		newl[1+#newl] = l[i+2]
		newl[1+#newl] = l[i+1]
		newl[1+#newl] = l[i+3]
	end

	return newl
end

function lathe(l, udivs, vdivs, vsiz, ypivot, do_caps, fuv, fsiz)
	local u, v

	for v=0,vdivs-1 do
		local y0 = vsiz*((v+0)/vdivs-ypivot)
		local y1 = vsiz*((v+1)/vdivs-ypivot)
		local amp0 = fsiz(y0)
		local amp1 = fsiz(y1)
		local v0 = y0
		local v1 = y1

		for u=0,udivs-1 do
			local x00 = amp0*math.sin((u+0)*math.pi*2.0/udivs)
			local z00 = amp0*math.cos((u+0)*math.pi*2.0/udivs)
			local x01 = amp1*math.sin((u+0)*math.pi*2.0/udivs)
			local z01 = amp1*math.cos((u+0)*math.pi*2.0/udivs)
			local x10 = amp0*math.sin((u+1)*math.pi*2.0/udivs)
			local z10 = amp0*math.cos((u+1)*math.pi*2.0/udivs)
			local x11 = amp1*math.sin((u+1)*math.pi*2.0/udivs)
			local z11 = amp1*math.cos((u+1)*math.pi*2.0/udivs)

			l[1+#l] = fuv(x00, y0, z00, u0, v0)
			l[1+#l] = fuv(x01, y1, z01, u0, v1)
			l[1+#l] = fuv(x10, y0, z10, u1, v0)
			l[1+#l] = fuv(x10, y0, z10, u1, v0)
			l[1+#l] = fuv(x01, y1, z01, u0, v1)
			l[1+#l] = fuv(x11, y1, z11, u1, v1)
		end
	end

	if do_caps then
		local y0 = vsiz*(0-ypivot)
		local y1 = vsiz*(1-ypivot)
		local amp0 = fsiz(y0)
		local amp1 = fsiz(y1)
		local v0 = y0
		local v1 = y1

		for u=0,udivs-1 do
			local x00 = amp0*math.sin((u+0)*math.pi*2.0/udivs)
			local z00 = amp0*math.cos((u+0)*math.pi*2.0/udivs)
			local x01 = amp1*math.sin((u+0)*math.pi*2.0/udivs)
			local z01 = amp1*math.cos((u+0)*math.pi*2.0/udivs)
			local x10 = amp0*math.sin((u+1)*math.pi*2.0/udivs)
			local z10 = amp0*math.cos((u+1)*math.pi*2.0/udivs)
			local x11 = amp1*math.sin((u+1)*math.pi*2.0/udivs)
			local z11 = amp1*math.cos((u+1)*math.pi*2.0/udivs)

			l[1+#l] = fuv(x00, y0, z00, u0, v0)
			l[1+#l] = fuv(x10, y0, z10, u1, v0)
			l[1+#l] = fuv(  0, y0,   0, u0, v0)
			l[1+#l] = fuv(x11, y1, z11, u1, v1)
			l[1+#l] = fuv(x01, y1, z01, u0, v1)
			l[1+#l] = fuv(  0, y1,   0, u0, v1)
		end
	end
end


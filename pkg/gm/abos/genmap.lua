function bsp_new(settings)
	--[[
		true = air
		false = solid
		nil = unfinalised solid (call flush_tris to finalise)
		{nx=, ny=, nz=, nw=, c1=, c2=, parent=} = split
	]]

	local this = {
		root = true,
	}

	function this.print()
		local recurse
		recurse = function(root, tabs)
			if root == true then
				print(tabs.."a")
			elseif root == false then
				print(tabs.."S")
			elseif root == nil then
				print(tabs.."S (uncommitted)")
			else
				print(tabs.."|"
					.." "..root.nx
					.." "..root.ny
					.." "..root.nz
					.." "..root.nw)
				recurse(root.c1, tabs.."  ")
				recurse(root.c2, tabs.."  ")
			end
		end
		recurse(this.root, "")
	end

	function this.point_side(root, x, y, z)
		return root.nx*x + root.ny*y + root.nz*z + root.nw
	end

	function this.is_inside(x, y, z)
		local recurse
		recurse = function(root)
			if root == true then return false end
			if root == false or root == nil then return true end
			local s = this.point_side(root, x, y, z)

			if s >= 0 then return recurse(root.c1)
			else return recurse(root.c2)
			end
		end
		return recurse(this.root)
	end

	function this.trace_to(x1, y1, z1, x2, y2, z2)
		-- Get deltas
		local xd = x2-x1
		local yd = y2-y1
		local zd = z2-z1

		-- Start recursive function
		--print(xd, yd, zd)
		local recurse
		recurse = function(parent, root, o1, o2)
			-- Check if air, if so return false
			if root == true then return false end

			-- Check if solid, if so return o1
			if root == false or root == nil then return {o1, parent} end

			-- Calculate sides
			local s1 = this.point_side(root, x1+xd*o1, y1+yd*o1, z1+zd*o1)
			local s2 = this.point_side(root, x1+xd*o2, y1+yd*o2, z1+zd*o2)

			-- Check if we cross the centre
			if (s1 < 0) == (s2 < 0) then
				-- We don't - traverse the node we're on
				if s1 >= 0 then return recurse(parent, root.c1, o1, o2)
				else return recurse(parent, root.c2, o1, o2)
				end
			else
				-- We do - find the centre and recurse in the correct order
				local od = o2 - o1
				local sd = s2 - s1
				local soffs = -s1/sd
				local oc = soffs*od + o1
				--print("split", oc)

				if s1 >= 0 then
					-- c1 -> c2
					return false
						or recurse(root, root.c1, o1, oc)
						or recurse(root, root.c2, oc, o2)
				else
					-- c2 -> c1
					return false
						or recurse(root, root.c2, o1, oc)
						or recurse(root, root.c1, oc, o2)
				end
			end
		end
		local ret = recurse(nil, this.root, 0, 1.000001)

		if ret == false then
			return {1, nil}
		else
			--print(ret[1])
			return ret
		end
	end

	function this.add_tri(ap1, ap2, ap3)
		-- Get plane
		local nx, ny, nz, nw = tri_to_plane(ap1, ap2, ap3)

		-- Start recursive function
		local recurse
		recurse = function(root, p1, p2, p3)
			if root ~= true and root ~= false and root ~= nil then
				-- Check against split
				local s1 = this.point_side(root, p1[1], p1[2], p1[3])
				local s2 = this.point_side(root, p2[1], p2[2], p2[3])
				local s3 = this.point_side(root, p3[1], p3[2], p3[3])
				print(s1,s2,s3)

				local sf = math.max(math.max(s1, s2), s3)
				local sb = math.min(math.min(s1, s2), s3)
				
				if sf >  0.0000001 then
					root.c1 = recurse(root.c1, p1, p2, p3)
				end

				if sb < -0.0000001 then
					root.c2 = recurse(root.c2, p1, p2, p3)
				end
			elseif root == true or root == nil then
				-- Create split
				root = {
					nx = nx, ny = ny, nz = nz, nw = nw,
					c1 = true,
					c2 = nil,
				}
			else
				-- Committed solid - do not do anything to this
			end
			return root
		end
		this.root = recurse(this.root, ap1, ap2, ap3)
	end

	function this.flush_tris()
		-- Start recursive function
		local flush
		flush = function(root, parent)
			-- Filter nil -> false
			if root == nil then return false end

			-- Recurse
			if root ~= true and root ~= false and root ~= nil then
				root.parent = parent
				root.c1 = flush(root.c1, root)
				root.c2 = flush(root.c2, root)
			end
			return root
		end
		this.root = flush(this.root, nil)
	end

	return this
end

function level_new(settings)
	local this = {
		ents = {},
		vas = {},

		pts = nil,
		tris = nil,
		planes = nil,
		bsp = nil,
	}

	function this.render()
		local k,v
		for k,v in pairs(this.vas) do
			client.va_render_global(v.va, 0, 0, 0, 0, 0, 0, 1.0, v.tex)
		end
	end

	function this.assemble()
		local i,j
		local k,v

		-- TODO: balanced ordering
		this.bsp = bsp_new {
		}

		for k,v in pairs(this.vas) do
			local l = v.l
			for i=1,#l,3 do
				-- Get points
				local p1 = l[i+0]
				local p2 = l[i+1]
				local p3 = l[i+2]

				-- Add triangle
				this.bsp.add_tri(p1, p2, p3)
			end

			-- Commit solids
			this.bsp.flush_tris()
		end

		-- DEBUG: Print tree
		this.bsp.print()
	end

	function this.add_funbox(settings)
		local x1 = settings.pt1[1]
		local y1 = settings.pt1[2]
		local z1 = settings.pt1[3]
		local x2 = settings.pt2[1]
		local y2 = settings.pt2[2]
		local z2 = settings.pt2[3]
		local yd = y2-y1
		local xd = x2-x1
		local s = 1.0/math.sqrt(2.0)

		local tx1, ty1 = 0.0, 0.0
		local tx2, ty2 = 0.5, 0.5

		-- flatten a bit
		yd = yd*2

		local pdiff = yd/xd
		local px1, py1 = 0.0+pdiff, 1.0-pdiff
		local px2, py2 = 1.0-pdiff, 1.0-pdiff
		local px3, py3 = 0.0, 1.0
		local px4, py4 = 1.0, 1.0

		local l = {}

		-- plane -y
		l[1+#l] = {x1+yd, y1, z1+yd, 0,-1, 0, tx1, ty1}
		l[1+#l] = {x1+yd, y1, z2-yd, 0,-1, 0, tx1, ty2}
		l[1+#l] = {x2-yd, y1, z1+yd, 0,-1, 0, tx2, ty1}
		l[1+#l] = {x2-yd, y1, z2-yd, 0,-1, 0, tx2, ty2}

		-- plane +y
		l[1+#l] = {x1, y2, z1, 0, 1, 0, tx2, ty2}
		l[1+#l] = {x2, y2, z1, 0, 1, 0, tx1, ty2}
		l[1+#l] = {x1, y2, z2, 0, 1, 0, tx2, ty1}
		l[1+#l] = {x2, y2, z2, 0, 1, 0, tx1, ty1}

		-- funbox plane -x
		l[1+#l] = {x1+yd, y1, z1+yd,-s,-s, 0, px1, py1}
		l[1+#l] = {x1   , y2, z1   ,-s,-s, 0, px3, py3}
		l[1+#l] = {x1+yd, y1, z2-yd,-s,-s, 0, px2, py2}
		l[1+#l] = {x1   , y2, z2   ,-s,-s, 0, px4, py4}

		-- funbox plane +x
		l[1+#l] = {x2-yd, y1, z1+yd, s,-s, 0, px2, py2}
		l[1+#l] = {x2-yd, y1, z2-yd, s,-s, 0, px1, py1}
		l[1+#l] = {x2   , y2, z1   , s,-s, 0, px4, py4}
		l[1+#l] = {x2   , y2, z2   , s,-s, 0, px3, py3}

		-- funbox plane -z
		l[1+#l] = {x1+yd, y1, z1+yd, 0,-s,-s, px2, py2}
		l[1+#l] = {x2-yd, y1, z1+yd, 0,-s,-s, px1, py1}
		l[1+#l] = {x1   , y2, z1   , 0,-s,-s, px4, py4}
		l[1+#l] = {x2   , y2, z1   , 0,-s,-s, px3, py3}

		-- funbox plane +z
		l[1+#l] = {x1+yd, y1, z2-yd, 0,-s, s, px1, py1}
		l[1+#l] = {x1   , y2, z2   , 0,-s, s, px3, py3}
		l[1+#l] = {x2-yd, y1, z2-yd, 0,-s, s, px2, py2}
		l[1+#l] = {x2   , y2, z2   , 0,-s, s, px4, py4}

		-- expand
		l = quad_expand(l)

		this.vas[1+#(this.vas)] = {
			va = common.va_make(l, nil, "3v,3n,2t"),
			l = l,
			rails = {},
			tex = img_funbox,
		}
	end

	function this.add_qpipe(settings)
		-- TODO make this pipey
		local x1 = settings.pt1[1]
		local y1 = settings.pt1[2]
		local z1 = settings.pt1[3]
		local x2 = settings.pt2[1]
		local y2 = settings.pt2[2]
		local z2 = settings.pt2[3]

		local rxn = (settings.ramps.xn or 0)*(y2-y1)
		local rxp = (settings.ramps.xp or 0)*(y2-y1)
		local rzn = (settings.ramps.zn or 0)*(y2-y1)
		local rzp = (settings.ramps.zp or 0)*(y2-y1)

		local tx1, ty1 = 0.00, 0.00
		local tx2, ty2 = 1.00, 0.25
		local rx1, ry1 = 0.00, 0.25
		local rx2, ry2 = 1.00, 1.00

		local ry1xn = (settings.ramps.xn and ry1) or ty1
		local ry2xn = (settings.ramps.xn and ry2) or ty2
		local ry1xp = (settings.ramps.xp and ry1) or ty1
		local ry2xp = (settings.ramps.xp and ry2) or ty2
		local ry1zn = (settings.ramps.zn and ry1) or ty1
		local ry2zn = (settings.ramps.zn and ry2) or ty2
		local ry1zp = (settings.ramps.zp and ry1) or ty1
		local ry2zp = (settings.ramps.zp and ry2) or ty2

		local l = {}

		-- plane -y
		l[1+#l] = {x1, y1, z1, 0,-1, 0, tx1, ty1}
		l[1+#l] = {x1, y1, z2, 0,-1, 0, tx2, ty1}
		l[1+#l] = {x2, y1, z1, 0,-1, 0, tx1, ty2}
		l[1+#l] = {x2, y1, z2, 0,-1, 0, tx2, ty2}

		-- plane +y
		l[1+#l] = {x1, y2, z1, 0, 1, 0, tx1, ty1}
		l[1+#l] = {x2, y2, z1, 0, 1, 0, tx2, ty1}
		l[1+#l] = {x1, y2, z2, 0, 1, 0, tx1, ty2}
		l[1+#l] = {x2, y2, z2, 0, 1, 0, tx2, ty2}

		-- plane -z
		l[1+#l] = {x1, y1, z1, 0, 0,-1, x1, ry1zn}
		l[1+#l] = {x2, y1, z1, 0, 0,-1, x2, ry1zn}
		l[1+#l] = {x1-rxn, y2, z1-rzn, 0, 0,-1, x1-rxn, ry2zn}
		l[1+#l] = {x2+rxp, y2, z1-rzn, 0, 0,-1, x2+rxp, ry2zn}

		-- plane +z
		l[1+#l] = {x1, y1, z2, 0, 0, 1, x1, ry1zp}
		l[1+#l] = {x1-rxn, y2, z2+rzp, 0, 0, 1, x1-rxn, ry2zp}
		l[1+#l] = {x2, y1, z2, 0, 0, 1, x2, ry1zp}
		l[1+#l] = {x2+rxp, y2, z2+rzp, 0, 0, 1, x2+rxp, ry2zp}

		-- plane -x
		l[1+#l] = {x1, y1, z1,-1, 0, 0, z1, ry1xn}
		l[1+#l] = {x1-rxn, y2, z1-rzn,-1, 0, 0, z1-rzn, ry2xn}
		l[1+#l] = {x1, y1, z2,-1, 0, 0, z2, ry1xn}
		l[1+#l] = {x1-rxn, y2, z2+rzp,-1, 0, 0, z2+rzp, ry2xn}

		-- plane +x
		l[1+#l] = {x2, y1, z1, 1, 0, 0, z1, ry1xp}
		l[1+#l] = {x2, y1, z2, 1, 0, 0, z2, ry1xp}
		l[1+#l] = {x2+rxp, y2, z1-rzn, 1, 0, 0, z1-rzn, ry2xp}
		l[1+#l] = {x2+rxp, y2, z2+rzp, 1, 0, 0, z2+rzp, ry2xp}

		-- expand
		l = quad_expand(l)

		-- autonormal
		autonormal(l)

		this.vas[1+#(this.vas)] = {
			va = common.va_make(l, nil, "3v,3n,2t"),
			l = l,
			rails = {
				{{x1,y1,z1},{x2,y1,z1}},
				{{x1,y1,z1},{x1,y1,z2}},
				{{x2,y1,z2},{x2,y1,z1}},
				{{x2,y1,z2},{x1,y1,z2}},
			},
			tex = img_ramp,
		}
	end

	function this.add_box(settings)
		local x1 = settings.pt1[1]
		local y1 = settings.pt1[2]
		local z1 = settings.pt1[3]
		local x2 = settings.pt2[1]
		local y2 = settings.pt2[2]
		local z2 = settings.pt2[3]

		local l = {}

		-- plane -y
		l[1+#l] = {x1, y1, z1, 0,-1, 0, x1, z1}
		l[1+#l] = {x1, y1, z2, 0,-1, 0, x1, z2}
		l[1+#l] = {x2, y1, z1, 0,-1, 0, x2, z1}
		l[1+#l] = {x2, y1, z2, 0,-1, 0, x2, z2}

		-- plane +y
		l[1+#l] = {x1, y2, z1, 0, 1, 0, x1, z1}
		l[1+#l] = {x2, y2, z1, 0, 1, 0, x1, z2}
		l[1+#l] = {x1, y2, z2, 0, 1, 0, x2, z1}
		l[1+#l] = {x2, y2, z2, 0, 1, 0, x2, z2}

		-- plane -z
		l[1+#l] = {x1, y1, z1, 0, 0,-1, x1, y1}
		l[1+#l] = {x2, y1, z1, 0, 0,-1, x2, y1}
		l[1+#l] = {x1, y2, z1, 0, 0,-1, x1, y2}
		l[1+#l] = {x2, y2, z1, 0, 0,-1, x2, y2}

		-- plane +z
		l[1+#l] = {x1, y1, z2, 0, 0, 1, x1, y1}
		l[1+#l] = {x1, y2, z2, 0, 0, 1, x1, y2}
		l[1+#l] = {x2, y1, z2, 0, 0, 1, x2, y1}
		l[1+#l] = {x2, y2, z2, 0, 0, 1, x2, y2}

		-- plane -x
		l[1+#l] = {x1, y1, z1,-1, 0, 0, y1, z1}
		l[1+#l] = {x1, y2, z1,-1, 0, 0, y2, z1}
		l[1+#l] = {x1, y1, z2,-1, 0, 0, y1, z2}
		l[1+#l] = {x1, y2, z2,-1, 0, 0, y2, z2}

		-- plane +x
		l[1+#l] = {x2, y1, z1, 1, 0, 0, y1, z1}
		l[1+#l] = {x2, y1, z2, 1, 0, 0, y1, z2}
		l[1+#l] = {x2, y2, z1, 1, 0, 0, y2, z1}
		l[1+#l] = {x2, y2, z2, 1, 0, 0, y2, z2}

		-- expand
		l = quad_expand(l)

		this.vas[1+#(this.vas)] = {
			va = common.va_make(l, nil, "3v,3n,2t"),
			l = l,
			rails = {
				{{x1,y1,z1},{x2,y1,z1}},
				{{x1,y1,z1},{x1,y1,z2}},
				{{x2,y1,z2},{x2,y1,z1}},
				{{x2,y1,z2},{x1,y1,z2}},
			},
			tex = img_genbox,
		}
	end

	return this
end

function genmap_default()
	local lev = level_new {
	}

	-- Build walls
	lev.add_box { pt1 = {-21,  4, -21}, pt2 = { 21,  6,  21}, }
	lev.add_box { pt1 = {-22, -1, -22}, pt2 = { 22,  6, -20}, }
	lev.add_box { pt1 = {-22, -1, -22}, pt2 = {-20,  6,  22}, }
	lev.add_box { pt2 = { 22,  6,  22}, pt1 = { 20, -1, -20}, }
	lev.add_box { pt2 = { 22,  6,  22}, pt1 = {-20, -1,  20}, }

	-- Build a funbox
	lev.add_funbox { pt1 = { -3,  3.0,  -3}, pt2 = {  3,  4,   3}, }
	lev.add_funbox { pt1 = {-14,  3.0,  -1}, pt2 = { -8,  4,   5}, }

	-- Build a low wall between the funboxes
	lev.add_box { pt1 = { -6,  2.4,  -3}, pt2 = { -4,  4,   3}, }

	-- Build qpipes
	lev.add_qpipe { pt1 = {  7,  2.4,  -12}, pt2 = {  9,  4,   -5},
		ramps = {xp=2, zp=2} }
	lev.add_qpipe { pt1 = {  7,  2.4,   5}, pt2 = {  9,  4,   12},
		ramps = {xp=2, zn=2} }
	lev.add_qpipe { pt1 = {  18,  2.4,  -12}, pt2 = {  20,  4,   12},
		ramps = {xn=2} }

	-- Assemble
	lev.assemble()

	-- Return
	return lev
end


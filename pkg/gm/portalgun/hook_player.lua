do
	local s_new_player = new_player

	print(new_player)
	function new_player(settings, ...)
		local this = s_new_player(settings, ...)

		this.portal_list = {}
		this.portal_list_va = {}

		local s_calc_motion_trace = this.calc_motion_trace
		function this.calc_motion_trace(sec_current, sec_delta, ox, oy, oz, nx, ny, nz, ...)
			local tx1, ty1, tz1 = s_calc_motion_trace(sec_current, sec_delta, ox, oy, oz, nx, ny, nz, ...)
			if #portal_transforms_performed == 0 then
				return tx1, ty1, tz1
			end

			local k, v, _
			for k, v in pairs(portal_transforms_performed) do
				-- Apply to velocity
				_, _, _, this.vx, this.vy, this.vz = trace_portal_transform(
					v, 0, 0, 0, this.vx, this.vy, this.vz)

				-- Get camera direction
				local sya = math.sin(this.angy)
				local cya = math.cos(this.angy)
				local sxa = math.sin(this.angx)
				local cxa = math.cos(this.angx)
				local fwx,fwy,fwz = sya*cxa, sxa, cya*cxa

				-- Apply to camera
				_, _, _, fwx, fwy, fwz = trace_portal_transform(
					v, 0, 0, 0, fwx, fwy, fwz)

				-- Apply roll
				this.sx, this.sy, this.sz = sxa*sya, -cxa, sxa*cya
				_, _, _, this.sx, this.sy, this.sz = trace_portal_transform(
					v, 0, 0, 0, this.sx, this.sy, this.sz)
				local ds = math.sqrt(this.sx*this.sx + this.sy*this.sy + this.sz*this.sz)
				this.sx = this.sx / ds
				this.sy = this.sy / ds
				this.sz = this.sz / ds

				-- Set camera direction
				this.angy = math.atan2(fwx, fwz)
				this.angx = math.asin(fwy)
			end

			return tx1, ty1, tz1
		end
		local function render_portals()
			local i

			for i=1,2 do
				local p = this.portal_list[i]
				if p then
					local other = this.portal_list[3-i]
					local cx, cy, cz = p[1], p[2], p[3]
					local dx, dy, dz = p[4], p[5], p[6]
					local sx, sy, sz = p[7], p[8], p[9]

					local hx = dy*sz-dz*sy
					local hy = dz*sx-dx*sz
					local hz = dx*sy-dy*sx

					cx = cx + 0.5
					cy = cy + 0.5
					cz = cz + 0.5

					--print("PORTAL", cx, cy, cz, dx, dy, dz, sx, sy, sz, i)
					if not p.va then
						local cr,cg,cb
						if i == 1 then
							cr,cg,cb = 0,0.5,1
						else
							cr,cg,cb = 1,0.5,0
						end

						local doffs = 0.5+0.02
						local rh = 1.5-0.12
						local rs = 1.5-0.12

						local x1 = cx - doffs*dx - rh*hx - rs*sx
						local y1 = cy - doffs*dy - rh*hy - rs*sy
						local z1 = cz - doffs*dz - rh*hz - rs*sz
						local x2 = cx - doffs*dx + rh*hx - rs*sx
						local y2 = cy - doffs*dy + rh*hy - rs*sy
						local z2 = cz - doffs*dz + rh*hz - rs*sz
						local x3 = cx - doffs*dx - rh*hx + rs*sx
						local y3 = cy - doffs*dy - rh*hy + rs*sy
						local z3 = cz - doffs*dz - rh*hz + rs*sz
						local x4 = cx - doffs*dx + rh*hx + rs*sx
						local y4 = cy - doffs*dy + rh*hy + rs*sy
						local z4 = cz - doffs*dz + rh*hz + rs*sz

						p.va = {}
						this.portal_list_va[i] = this.portal_list_va[i] or {}
						p.va.border = common.va_make({
							{x1,y1,z1,cr,cg,cb,-dx,-dy,-dz},
							{x3,y3,z3,cr,cg,cb,-dx,-dy,-dz},
							{x2,y2,z2,cr,cg,cb,-dx,-dy,-dz},
							{x4,y4,z4,cr,cg,cb,-dx,-dy,-dz},
							{x2,y2,z2,cr,cg,cb,-dx,-dy,-dz},
							{x3,y3,z3,cr,cg,cb,-dx,-dy,-dz},
						}, this.portal_list_va[i].border, "3v,3c,3n")

						doffs = doffs+0.05
						rh = rh-0.12
						rs = rs-0.12

						x1 = cx - doffs*dx - rh*hx - rs*sx
						y1 = cy - doffs*dy - rh*hy - rs*sy
						z1 = cz - doffs*dz - rh*hz - rs*sz
						x2 = cx - doffs*dx + rh*hx - rs*sx
						y2 = cy - doffs*dy + rh*hy - rs*sy
						z2 = cz - doffs*dz + rh*hz - rs*sz
						x3 = cx - doffs*dx - rh*hx + rs*sx
						y3 = cy - doffs*dy - rh*hy + rs*sy
						z3 = cz - doffs*dz - rh*hz + rs*sz
						x4 = cx - doffs*dx + rh*hx + rs*sx
						y4 = cy - doffs*dy + rh*hy + rs*sy
						z4 = cz - doffs*dz + rh*hz + rs*sz

						cr = cr/2
						cg = cg/2
						cb = cb/2

						p.va.stencil = common.va_make({
							{x1,y1,z1,cr,cg,cb},
							{x3,y3,z3,cr,cg,cb},
							{x2,y2,z2,cr,cg,cb},
							{x4,y4,z4,cr,cg,cb},
							{x2,y2,z2,cr,cg,cb},
							{x3,y3,z3,cr,cg,cb},
						}, this.portal_list_va[i].stencil, "3v,3c")
					end

					if (not p.va.box) and other and other.va then
						local radius = 10

						local x1 = cx - radius*(0+hx+sx-dx)
						local y1 = cy - radius*(0+hy+sy-dy)
						local z1 = cz - radius*(0+hz+sz-dz)
						local x2 = cx - radius*(0-hx+sx-dx)
						local y2 = cy - radius*(0-hy+sy-dy)
						local z2 = cz - radius*(0-hz+sz-dz)
						local x3 = cx - radius*(0+hx-sx-dx)
						local y3 = cy - radius*(0+hy-sy-dy)
						local z3 = cz - radius*(0+hz-sz-dz)
						local x4 = cx - radius*(0-hx-sx-dx)
						local y4 = cy - radius*(0-hy-sy-dy)
						local z4 = cz - radius*(0-hz-sz-dz)

						local x5 = cx - radius*(0+hx+sx)
						local y5 = cy - radius*(0+hy+sy)
						local z5 = cz - radius*(0+hz+sz)
						local x6 = cx - radius*(0-hx+sx)
						local y6 = cy - radius*(0-hy+sy)
						local z6 = cz - radius*(0-hz+sz)
						local x7 = cx - radius*(0+hx-sx)
						local y7 = cy - radius*(0+hy-sy)
						local z7 = cz - radius*(0+hz-sz)
						local x8 = cx - radius*(0-hx-sx)
						local y8 = cy - radius*(0-hy-sy)
						local z8 = cz - radius*(0-hz-sz)

						local fr, fg, fb, fd = client.map_fog_get()
						fr = fr / 255.0
						fg = fg / 255.0
						fb = fb / 255.0
						fr = fr / 2.0
						fg = fg / 2.0
						fb = fb / 2.0
						--print(fr, fg, fb)

						p.va.box = common.va_make({
							{x1,y1,z1,fr,fg,fb,-dx,-dy,-dz},
							{x3,y3,z3,fr,fg,fb,-dx,-dy,-dz},
							{x2,y2,z2,fr,fg,fb,-dx,-dy,-dz},
							{x4,y4,z4,fr,fg,fb,-dx,-dy,-dz},
							{x2,y2,z2,fr,fg,fb,-dx,-dy,-dz},
							{x3,y3,z3,fr,fg,fb,-dx,-dy,-dz},

							{x1,y1,z1,fr,fg,fb,sx,sy,sz},
							{x2,y2,z2,fr,fg,fb,sx,sy,sz},
							{x5,y5,z5,fr,fg,fb,sx,sy,sz},
							{x6,y6,z6,fr,fg,fb,sx,sy,sz},
							{x5,y5,z5,fr,fg,fb,sx,sy,sz},
							{x2,y2,z2,fr,fg,fb,sx,sy,sz},

							{x3,y3,z3,fr,fg,fb,-sx,-sy,-sz},
							{x7,y7,z7,fr,fg,fb,-sx,-sy,-sz},
							{x4,y4,z4,fr,fg,fb,-sx,-sy,-sz},
							{x8,y8,z8,fr,fg,fb,-sx,-sy,-sz},
							{x4,y4,z4,fr,fg,fb,-sx,-sy,-sz},
							{x7,y7,z7,fr,fg,fb,-sx,-sy,-sz},

							{x1,y1,z1,fr,fg,fb,hx,hy,hz},
							{x5,y5,z5,fr,fg,fb,hx,hy,hz},
							{x3,y3,z3,fr,fg,fb,hx,hy,hz},
							{x7,y7,z7,fr,fg,fb,hx,hy,hz},
							{x3,y3,z3,fr,fg,fb,hx,hy,hz},
							{x5,y5,z5,fr,fg,fb,hx,hy,hz},

							{x2,y2,z2,fr,fg,fb,-hx,-hy,-hz},
							{x4,y4,z4,fr,fg,fb,-hx,-hy,-hz},
							{x6,y6,z6,fr,fg,fb,-hx,-hy,-hz},
							{x8,y8,z8,fr,fg,fb,-hx,-hy,-hz},
							{x6,y6,z6,fr,fg,fb,-hx,-hy,-hz},
							{x4,y4,z4,fr,fg,fb,-hx,-hy,-hz},
						}, this.portal_list_va[i].box, "3v,3c,3n")

						-- Build front-to-back
						local x,y,z
						local r
						local l = {}
						local tf = {other, p}

						cx, cy, cz = p[1], p[2], p[3]
						local tcx, tcy, tcz = other[1], other[2], other[3]
						local tdx, tdy, tdz = other[4], other[5], other[6]
						local tsx, tsy, tsz = other[7], other[8], other[9]

						local thx = tdy*tsz-tdz*tsy
						local thy = tdz*tsx-tdx*tsz
						local thz = tdx*tsy-tdy*tsx

						local taxx = hx*thx + hy*tsx + hz*tdx
						local taxy = hx*thy + hy*tsy + hz*tdy
						local taxz = hx*thz + hy*tsz + hz*tdz
						local tayx = sx*thx + sy*tsx + sz*tdx
						local tayy = sx*thy + sy*tsy + sz*tdy
						local tayz = sx*thz + sy*tsz + sz*tdz
						local tazx = dx*thx + dy*tsx + dz*tdx
						local tazy = dx*thy + dy*tsy + dz*tdy
						local tazz = dx*thz + dy*tsz + dz*tdz

						local function add_block(rx, ry, rz, t, tx, ty, tz)
							local x1 = rx
							local y1 = ry
							local z1 = rz
							local x2 = rx+1
							local y2 = ry+1
							local z2 = rz+1

							local cr,cg,cb = t[2], t[3], t[4]
							cr = cr / 255.0
							cg = cg / 255.0
							cb = cb / 255.0
							cr = cr / 2.0
							cg = cg / 2.0
							cb = cb / 2.0

							local ALL_FACES = true -- TODO: make this work properly when set to false

							if ALL_FACES or map_block_get(tx-tazx,ty-tazy,tz-tazz) == nil then
							--print("block", rx, ry, rz, cr, cg, cb)
							l[1+#l] = {x1,y1,z1,cr,cg,cb,0,0,-1}
							l[1+#l] = {x2,y1,z1,cr,cg,cb,0,0,-1}
							l[1+#l] = {x1,y2,z1,cr,cg,cb,0,0,-1}
							l[1+#l] = {x2,y2,z1,cr,cg,cb,0,0,-1}
							l[1+#l] = {x1,y2,z1,cr,cg,cb,0,0,-1}
							l[1+#l] = {x2,y1,z1,cr,cg,cb,0,0,-1}
							end

							if ALL_FACES or map_block_get(tx+tazx,ty+tazy,tz+tazz) == nil then
							l[1+#l] = {x1,y1,z2,cr,cg,cb,0,0,1}
							l[1+#l] = {x1,y2,z2,cr,cg,cb,0,0,1}
							l[1+#l] = {x2,y1,z2,cr,cg,cb,0,0,1}
							l[1+#l] = {x2,y2,z2,cr,cg,cb,0,0,1}
							l[1+#l] = {x2,y1,z2,cr,cg,cb,0,0,1}
							l[1+#l] = {x1,y2,z2,cr,cg,cb,0,0,1}
							end

							if ALL_FACES or map_block_get(tx-tayx,ty-tayy,tz-tayz) == nil then
							l[1+#l] = {x1,y1,z1,cr,cg,cb,0,-1,0}
							l[1+#l] = {x1,y1,z2,cr,cg,cb,0,-1,0}
							l[1+#l] = {x2,y1,z1,cr,cg,cb,0,-1,0}
							l[1+#l] = {x2,y1,z2,cr,cg,cb,0,-1,0}
							l[1+#l] = {x2,y1,z1,cr,cg,cb,0,-1,0}
							l[1+#l] = {x1,y1,z2,cr,cg,cb,0,-1,0}
							end

							if ALL_FACES or map_block_get(tx+tayx,ty+tayy,tz+tayz) == nil then
							l[1+#l] = {x1,y2,z1,cr,cg,cb,0,1,0}
							l[1+#l] = {x2,y2,z1,cr,cg,cb,0,1,0}
							l[1+#l] = {x1,y2,z2,cr,cg,cb,0,1,0}
							l[1+#l] = {x2,y2,z2,cr,cg,cb,0,1,0}
							l[1+#l] = {x1,y2,z2,cr,cg,cb,0,1,0}
							l[1+#l] = {x2,y2,z1,cr,cg,cb,0,1,0}
							end

							if ALL_FACES or map_block_get(tx-taxx,ty-taxy,tz-taxz) == nil then
							l[1+#l] = {x1,y1,z1,cr,cg,cb,-1,0,0}
							l[1+#l] = {x1,y2,z1,cr,cg,cb,-1,0,0}
							l[1+#l] = {x1,y1,z2,cr,cg,cb,-1,0,0}
							l[1+#l] = {x1,y2,z2,cr,cg,cb,-1,0,0}
							l[1+#l] = {x1,y1,z2,cr,cg,cb,-1,0,0}
							l[1+#l] = {x1,y2,z1,cr,cg,cb,-1,0,0}
							end

							if ALL_FACES or map_block_get(tx+taxx,ty+taxy,tz+taxz) == nil then
							l[1+#l] = {x2,y1,z1,cr,cg,cb,1,0,0}
							l[1+#l] = {x2,y1,z2,cr,cg,cb,1,0,0}
							l[1+#l] = {x2,y2,z1,cr,cg,cb,1,0,0}
							l[1+#l] = {x2,y2,z2,cr,cg,cb,1,0,0}
							l[1+#l] = {x2,y2,z1,cr,cg,cb,1,0,0}
							l[1+#l] = {x2,y1,z2,cr,cg,cb,1,0,0}
							end
						end

						tdx = -tdx
						tdy = -tdy
						tdz = -tdz

						for r=radius*3,1,-1 do
						for z=0,r do
							local az = math.abs(z)
							local ystep = r-az
						for y=-ystep,ystep do
							if ystep < 0 then break end
							-- Get abs values for calculation
							local ay = math.abs(y)
							local xstep = r-(ay+az)
						for x=-xstep,xstep,2*xstep do
							if xstep < 0 then break end
							local ax = math.abs(x)
							local ma = math.max(math.max(ax,ay),az)
							local _

							-- Ensure in range
							if ma <= radius and ax+ay+az == r then
							--if ax+ay+az == r then
								-- LET'S DO IT

								-- Get source coordinates
								local rx = cx + dx*z - hx*x + sx*y
								local ry = cy + dy*z - hy*x + sy*y
								local rz = cz + dz*z - hz*x + sz*y

								rx = math.floor(rx+0.5)
								ry = math.floor(ry+0.5)
								rz = math.floor(rz+0.5)

								-- Get target coordinates
								local tx = tcx + tdx*(z+1) + thx*x + tsx*y
								local ty = tcy + tdy*(z+1) + thy*x + tsy*y
								local tz = tcz + tdz*(z+1) + thz*x + tsz*y

								tx = math.floor(tx+0.5)
								ty = math.floor(ty+0.5)
								tz = math.floor(tz+0.5)
								--print("tf", tx, ty, tz, "->", rx, ry, rz)

								-- Get target block
								local b = map_block_get(tx,ty,tz)

								-- Add block if necessary
								if b then
									add_block(rx, ry, rz, b, tx, ty, tz)
								end

							end

							if xstep == 0 then break end

						end end end end

						p.va.scene = common.va_make(l,
							this.portal_list_va[i].scene, "3v,3c,3n")
					end

					this.portal_list_va[i] = p.va

					client.va_render_global(p.va.border, 0, 0, 0, 0, 0, 0, 1)

					if other and other.va and other.va.scene then
						-- Mark stencil region
						client.gfx_stencil_test(true)
						client.gfx_stencil_func("1", 1, 255)
						client.gfx_stencil_op(";;=")
						client.va_render_global(p.va.stencil, 0, 0, 0, 0, 0, 0, 1, nil, "10")

						-- Clear depth
						-- FIXME: engine needs support for glDepthFunc(GL_ALWAYS)
						-- (ATM we have to generate the block list back-to-front)
						client.gfx_stencil_func("==", 1, 255)
						client.gfx_stencil_op(";;;")
						client.gfx_depth_test(false)
						client.va_render_global(p.va.box, 0, 0, 0, 0, 0, 0, 1)
						client.va_render_global(p.va.scene, 0, 0, 0, 0, 0, 0, 1)
						client.gfx_depth_test(true)

						-- Clear stencil region
						client.gfx_stencil_func("1", 0, 255)
						client.gfx_stencil_op("===")
						client.va_render_global(p.va.stencil, 0, 0, 0, 0, 0, 0, 1, nil, "10")
						client.gfx_stencil_func("1", 0, 255)
						client.gfx_stencil_op(";;;")
						client.gfx_stencil_test(false)
					end
				end
			end

		end

		local s_render = this.render
		function this.render(...)
			render_portals()

			local ret = s_render(...)

			return ret
		end

		return this
	end
end


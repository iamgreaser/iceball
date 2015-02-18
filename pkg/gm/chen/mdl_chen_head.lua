
mdl_chen_head_tex = mdl_chen_head_tex or common.img_load(DIR_CHENMOD.."/mdl_chen_head.png", "png")

do
	local settings = ...

	local this = {}

	this.tex = mdl_chen_head_tex

	do
		local l = {}

		-- Head
		local function add_sphere(l, ucount, vcount, rscale, vscale, yoffs, xoffs, zoffs)
			local function uvmap(u, v)
				local amp = math.sin(v)
				amp = amp*rscale
				local rs = math.sin(u*2)
				local rc = math.cos(u*2)

				return rs*amp + xoffs, -(math.cos(v)-1)*vscale + yoffs, rc*amp + zoffs
			end

			local function vfilt(v)
				return 1-math.acos((v*2-1)/2)
			end

			local iu, iv
			local u0 = 0
			local v0 = 0
			local u1 = 1/ucount
			local v1 = 1/vcount
			local au0 = 0
			local av0 = 0
			local au1 = math.pi/ucount
			local av1 = math.pi/vcount
			for iu=0,ucount-1 do
			for iv=0,vcount-1 do
				local u = iu*math.pi/ucount
				local v = iv*math.pi/vcount
				local x00, y00, z00 = uvmap(u+au0, v+av0)
				local x01, y01, z01 = uvmap(u+au0, v+av1)
				local x10, y10, z10 = uvmap(u+au1, v+av0)
				local x11, y11, z11 = uvmap(u+au1, v+av1)

				u = (iu/ucount)%1
				v = math.max(0.0, math.min(1.0, iv/vcount))

				l[1+#l] = {x00, y00, z00, u+u0, vfilt(v+v0)}
				l[1+#l] = {x01, y01, z01, u+u0, vfilt(v+v1)}
				l[1+#l] = {x10, y10, z10, u+u1, vfilt(v+v0)}
				l[1+#l] = {x10, y10, z10, u+u1, vfilt(v+v0)}
				l[1+#l] = {x01, y01, z01, u+u0, vfilt(v+v1)}
				l[1+#l] = {x11, y11, z11, u+u1, vfilt(v+v1)}
			end
			end
		end

		add_sphere(l, 16, 10, 0.55, 0.4, -0.4, 0, 0)
		--add_sphere(l, 16, 10, 0.1, 0.15, 0.2, -0.22, -0.7)

		this.va_base = common.va_make(l, nil, "3v,2t")
		l = {}

		-- Cat ears
		local i
		for i=-1,1,2 do
			local r0,g0,b0 = 0x6b/255, 0x59/255, 0x36/255
			local r1,g1,b1 = 0xf3/255, 0xb5/255, 0xbe/255
			local x0,y0,z0 = i*0.5, -0.0,-0.1
			local x1,y1,z1 = i*0.3, -0.5,-0.1
			local x2,y2,z2 = i*0.3, -0.3, 0.2
			local x3,y3,z3 = i*0.1, -0.3,-0.1

			if i < 0 then
				r0,g0,b0,r1,g1,b1 = r1,g1,b1,r0,g0,b0
			end

			l[1+#l] = {x0, y0, z0, r0, g0, b0}
			l[1+#l] = {x1, y1, z1, r0, g0, b0}
			l[1+#l] = {x2, y2, z2, r0, g0, b0}
			l[1+#l] = {x2, y2, z2, r1, g1, b1}
			l[1+#l] = {x1, y1, z1, r1, g1, b1}
			l[1+#l] = {x0, y0, z0, r1, g1, b1}
			l[1+#l] = {x3, y3, z3, r0, g0, b0}
			l[1+#l] = {x2, y2, z2, r0, g0, b0}
			l[1+#l] = {x1, y1, z1, r0, g0, b0}
			l[1+#l] = {x1, y1, z1, r1, g1, b1}
			l[1+#l] = {x2, y2, z2, r1, g1, b1}
			l[1+#l] = {x3, y3, z3, r1, g1, b1}
		end

		-- Night cap
		do
			local function point(a, y, hamp)
				local sa = math.sin(a*math.pi*2)
				local ca = math.cos(a*math.pi*2)

				return ca*hamp, y, sa*hamp
			end
			local xc,yc,zc = 0,-0.5,0
			local r0,g0,b0 = 0x0b/255, 0xf4/255, 0x57/255
			local r1,g1,b1 = 0xf0/255, 0xff/255, 0xf0/255
			local i
			for i=0,(10-1) do
				local a0 = i/10
				local a1 = (i+1)/10
				local x0,y0,z0 = point(a0,-0.4,0.2)
				local x1,y1,z1 = point(a1,-0.4,0.2)
				local x2,y2,z2 = point((a0+a1)/2,-0.3,0.3)
				--local x3,y3,z3 = point(a1,-0.3,0.3)
				l[1+#l] = {x1, y1, z1, r0, g0, b0}
				l[1+#l] = {x0, y0, z0, r0, g0, b0}
				l[1+#l] = {xc, yc, zc, r0, g0, b0}

				l[1+#l] = {x0, y0, z0, r1, g1, b1}
				l[1+#l] = {x1, y1, z1, r1, g1, b1}
				l[1+#l] = {x2, y2, z2, r1, g1, b1}
			end
		end

		this.va_aux = common.va_make(l, nil, "3v,3c")
		l = {}

	end

	function this.render_global(x, y, z, r1, r2, r3, s)
		client.va_render_global(this.va_base, x, y, z, r1, r2, r3, s, this.tex)
		client.va_render_global(this.va_aux, x, y, z, r1, r2, r3, s, nil)
	end

	function this.render_local(x, y, z, r1, r2, r3, s)
		client.va_render_local(this.va_base, -x, y, z, r1, r2, r3, s, this.tex)
		client.va_render_local(this.va_aux, x, y, z, r1, r2, r3, s, nil)
	end

	return this

end


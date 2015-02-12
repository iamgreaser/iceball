
do
	local settings = ...

	local this = {}

	this.tex = skin_load("png", "mdl_ball.png", "pkg/iceball/rugby")

	do
		local ucount = 16
		local vcount = 10
		local scale = 0.4
		function uvmap(u, v)
			local amp = math.sin(v)
			amp = amp*0.4*scale
			local rs = math.sin(u)
			local rc = math.cos(u)

			return rs*amp, (math.cos(v)-1)*0.7*scale, rc*amp
		end

		local l = {}
		local iu, iv
		local u0 = 0
		local v0 = 0
		local u1 = 2/ucount
		local v1 = 1/vcount
		local au0 = 0
		local av0 = 0
		local au1 = 2*math.pi/ucount
		local av1 = math.pi/vcount
		for iu=0,ucount-1 do
		for iv=0,vcount-1 do
			local u = 2*iu*math.pi/ucount
			local v = iv*math.pi/vcount
			local x00, y00, z00 = uvmap(u+au0, v+av0)
			local x01, y01, z01 = uvmap(u+au0, v+av1)
			local x10, y10, z10 = uvmap(u+au1, v+av0)
			local x11, y11, z11 = uvmap(u+au1, v+av1)

			u = (iu*2/ucount)%1
			v = (iv/vcount)%1

			l[1+#l] = {x00, y00, z00, v+v0, u+u0}
			l[1+#l] = {x10, y10, z10, v+v0, u+u1}
			l[1+#l] = {x01, y01, z01, v+v1, u+u0}
			l[1+#l] = {x01, y01, z01, v+v1, u+u0}
			l[1+#l] = {x10, y10, z10, v+v0, u+u1}
			l[1+#l] = {x11, y11, z11, v+v1, u+u1}
		end
		end

		this.va = common.va_make(l, nil, "3v,2t")
	end

	function this.render_global(x, y, z, r1, r2, r3, s)
		client.va_render_global(this.va, x, y, z, r1, r2, r3, s, this.tex)
	end

	function this.render_local(x, y, z, r1, r2, r3, s)
		client.va_render_local(this.va, -x, y, z, r1, r2, r3, s, this.tex)
	end

	return this

end


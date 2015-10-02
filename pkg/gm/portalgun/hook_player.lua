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

				-- Apply to camera direction
				_, _, _, fwx, fwy, fwz = trace_portal_transform(
					v, 0, 0, 0, fwx, fwy, fwz)

				-- Set camera direction
				-- TODO: angx
				this.angy = -math.atan2(fwx, fwz)

			end

			return tx1, ty1, tz1
		end
		local function render_portals()
			local i

			for i=1,2 do
				local p = this.portal_list[i]
				if p then
					local cx, cy, cz = p[1], p[2], p[3]
					local dx, dy, dz = p[4], p[5], p[6]
					local sx, sy, sz = p[7], p[8], p[9]

					--print("PORTAL", cx, cy, cz, dx, dy, dz, sx, sy, sz, i)
					if not p.va then
						local hx = dy*sz-dz*sy
						local hy = dz*sx-dx*sz
						local hz = dx*sy-dy*sx

						local cr,cg,cb
						if i == 1 then
							cr,cg,cb = 0,0.5,1
						else
							cr,cg,cb = 1,0.5,0
						end

						cx = cx + 0.5
						cy = cy + 0.5
						cz = cz + 0.5

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

						p.va = common.va_make({
							{x1,y1,z1,cr,cg,cb},
							{x3,y3,z3,cr,cg,cb},
							{x2,y2,z2,cr,cg,cb},
							{x4,y4,z4,cr,cg,cb},
							{x2,y2,z2,cr,cg,cb},
							{x3,y3,z3,cr,cg,cb},
						}, this.portal_list_va[i], "3v,3c")

						this.portal_list_va[i] = p.va
					end

					client.va_render_global(p.va, 0, 0, 0, 0, 0, 0, 1)
				end
			end

		end

		local s_render = this.render
		function this.render(...)
			local ret = s_render(...)

			render_portals()

			return ret
		end

		return this
	end
end


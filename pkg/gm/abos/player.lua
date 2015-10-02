do
	local l = {}
	local a = 0.5
	local al = 1.0
	local x0 = math.sin(0*math.pi*2.0/3.0)*a
	local y0 = math.cos(0*math.pi*2.0/3.0)*a
	local x1 = math.sin(1*math.pi*2.0/3.0)*a
	local y1 = math.cos(1*math.pi*2.0/3.0)*a
	local x2 = math.sin(2*math.pi*2.0/3.0)*a
	local y2 = math.cos(2*math.pi*2.0/3.0)*a
	l[1+#l] = {x0, 0, y0, 0, 0, 1, 1, 0.5, 0.5, al}
	l[1+#l] = {x2, 0, y2, 0, 0, 1, 1, 0.5, 0.5, al}
	l[1+#l] = {x1, 0, y1, 0, 0, 1, 1, 0.5, 0.5, al}

	l[1+#l] = {x0, 0, y0, 0, 0, 1, 1, 0.5, 0.5, al}
	l[1+#l] = {x1, 0, y1, 0, 0, 1, 1, 0.5, 0.5, al}
	l[1+#l] = { 0,-1,  0, 0, 0, 1, 1, 0.5, 0.5, al}

	l[1+#l] = {x1, 0, y1, 0, 0, 1, 1, 0.5, 0.5, al}
	l[1+#l] = {x2, 0, y2, 0, 0, 1, 1, 0.5, 0.5, al}
	l[1+#l] = { 0,-1,  0, 0, 0, 1, 0, 0.5, 0.5, al}

	l[1+#l] = {x2, 0, y2, 0, 0, 1, 1, 0.5, 0.5, al}
	l[1+#l] = {x0, 0, y0, 0, 0, 1, 1, 0.5, 0.5, al}
	l[1+#l] = { 0,-1,  0, 0, 0, 1, 1, 0.5, 0.5, al}

	-- Autonormals!
	autonormal(l)

	va_player = common.va_make(l, nil, "3v,3n,4c")
end

function player_new(settings)
	local this = {
		pos = {
			x = settings.pos[1],
			y = settings.pos[2],
			z = settings.pos[3],
		},
		vel = {
			x = 0,
			y = 0,
			z = 0,
		},

		ya = 0, xa = 0,
		goof_invert = false,
		rot_yapos = false, rot_yaneg = false,
		rot_xapos = false, rot_xaneg = false,
		grounded = nil
	}

	function this.render()
		client.va_render_global(va_player, this.pos.x, this.pos.y, this.pos.z, 0,
			-this.xa, this.ya + ((this.goof_invert and math.pi) or 0), 1.0,
			nil, "ah")
	end

	function this.move(sec_current, sec_delta)
		if not lev_current then return end

		local roty = 0
		local rotx = 0
		if this.rot_yapos then roty = roty - 1 end
		if this.rot_yaneg then roty = roty + 1 end
		if this.rot_xapos then rotx = rotx + 1 end
		if this.rot_xaneg then rotx = rotx - 1 end
		roty = roty * sec_delta
		roty = roty * math.pi
		rotx = rotx * sec_delta
		rotx = rotx * math.pi

		this.ya = this.ya + roty
		--this.xa = this.xa + rotx

		local fwx = math.sin(this.ya)*math.cos(this.xa)
		local fwy = math.sin(this.xa)
		local fwz = math.cos(this.ya)*math.cos(this.xa)

		-- check if grounded
		local still_grounded = (lev_current.bsp.trace_to(
			this.pos.x, this.pos.y + 0.0, this.pos.z,
			this.pos.x, this.pos.y + 0.8, this.pos.z)[2])

		-- calc velocity
		--print(sec_delta, 1.0/sec_delta, this.pos.x, this.pos.y, this.pos.z)
		local fws = 5
		local vx = this.vel.x*sec_delta
		local vy = this.vel.y*sec_delta
		local vz = this.vel.z*sec_delta

		if this.grounded then
			this.vel.x = fwx*fws
			this.vel.z = fwz*fws
			vx = vx + (fwx*fws)*sec_delta
			vz = vz + (fwz*fws)*sec_delta
		end

		-- set vlen
		local vlen = math.sqrt(vx*vx + vy*vy + vz*vz)

		-- tweak velocity to be inline with plane
		local gplane = this.grounded
		if gplane and still_grounded then
			gplane = still_grounded
		end

		if gplane and this.vel.y > -0.5 then
			local x1 = this.pos.x
			local y1 = this.pos.y
			local z1 = this.pos.z
			local s0 = lev_current.bsp.point_side(gplane, x1, y1, z1)
			local st

			if s0 < 0 then
				st = -0.01
			else
				st = 0.01
			end

			-- Move position inline with plane
			local poffs = st-s0
			x1 = x1 + gplane.nx*poffs
			y1 = y1 + gplane.ny*poffs
			z1 = z1 + gplane.nz*poffs

			-- Move velocity inline with plane
			local sv = lev_current.bsp.point_side(gplane, vx, vy, vz)
				- gplane.nw
			local voffs = 0-sv
			vx = vx + gplane.nx*voffs
			vy = vy + gplane.ny*voffs
			vz = vz + gplane.nz*voffs
		end

		--[[
		this.pos.x = this.pos.x + sec_delta*vx
		this.pos.y = this.pos.y + sec_delta*vy
		this.pos.z = this.pos.z + sec_delta*vz
		]]

		-- trace repeatedly
		local old_rem = 1
		local old_x = this.pos.x
		local old_y = this.pos.y
		local old_z = this.pos.z
		local trem = 1
		local did_hit = nil
		--print(lev_current.bsp.is_inside(this.pos.x, this.pos.y, this.pos.z))
		for i=1,10 do
			local xt = this.pos.x + vx*trem
			local yt = this.pos.y + vy*trem
			local zt = this.pos.z + vz*trem
			local tdat = lev_current.bsp.trace_to(this.pos.x, this.pos.y, this.pos.z, xt, yt, zt)
			local toffs = tdat[1]

			this.pos.x = this.pos.x + toffs*vx
			this.pos.y = this.pos.y + toffs*vy
			this.pos.z = this.pos.z + toffs*vz

			trem = trem * (1 - toffs)
			if trem < 0.000001 then break end

			if tdat[2] then
				did_hit = tdat[2]
				print("did_hit")

				-- apply force off normal
				--local noffs = lev_current.bsp.point_side(tdat[2], this.pos.x, this.pos.y, this.pos.z)
				--local noffs = (1 - toffs) * vlen
				local noffs = (1 - toffs) * vlen
				local bouncefac = 0.505
				--print("noffs", noffs)
				--[[
				vx = vx + tdat[2].nx * noffs
				vy = vy + tdat[2].ny * noffs
				vz = vz + tdat[2].nz * noffs
				vlen = math.sqrt(vx*vx + vy*vy + vz*vz)
				]]

				if true then
					-- HACK
					this.pos.x = this.pos.x + (tdat[2].nx*bouncefac + vx) * noffs
					this.pos.y = this.pos.y + (tdat[2].ny*bouncefac + vy) * noffs
					this.pos.z = this.pos.z + (tdat[2].nz*bouncefac + vz) * noffs
					break

				elseif false then
					-- inline the points
					local gplane = tdat[2]
					local x1 = this.pos.x - toffs*vx
					local y1 = this.pos.y - toffs*vy
					local z1 = this.pos.z - toffs*vz
					local s0 = lev_current.bsp.point_side(gplane, x1, y1, z1)
					local st

					if s0 > 0 then
						st = -0.01
					else
						st = 0.01
					end

					-- Move position inline with plane
					local poffs = st-s0
					x1 = x1 + gplane.nx*poffs
					y1 = y1 + gplane.ny*poffs
					z1 = z1 + gplane.nz*poffs

					-- Move velocity inline with plane
					local sv = lev_current.bsp.point_side(gplane, vx, vy, vz)
						- gplane.nw
					local voffs = 0-sv
					vx = vx + gplane.nx*voffs
					vy = vy + gplane.ny*voffs
					vz = vz + gplane.nz*voffs
					this.vel.x = vx
					--this.vel.y = vy
					this.vel.z = vz
					vlen = math.sqrt(vx*vx + vy*vy + vz*vz)

				else
					-- FIXME
					this.pos.x = this.pos.x - 0.01*vx
					this.pos.y = this.pos.y - 0.01*vy
					this.pos.z = this.pos.z - 0.01*vz
					old_x = this.pos.x
					--old_y = this.pos.y
					old_z = this.pos.z
					old_rem = trem
					vx = (vx*noffs + tdat[2].nx*bouncefac*noffs)
					vy = (vy*noffs + tdat[2].ny*bouncefac*noffs)
					vz = (vz*noffs + tdat[2].nz*bouncefac*noffs)
					this.vel.x = vx/trem
					--this.vel.y = vy/trem
					this.vel.z = vz/trem
					vlen = math.sqrt(vx*vx + vy*vy + vz*vz)
				end
			end
		end
		
		--print(lev_current.bsp.is_inside(this.pos.x, this.pos.y, this.pos.z))

		-- grounding
		--print(this.grounded, still_grounded, did_hit)

		if this.grounded then
			this.grounded = still_grounded
		end

		if still_grounded and did_hit then
			if not this.grounded then
				if vx*fwx + vz*fwz < 0.0 then
					this.goof_invert = not this.goof_invert
					this.ya = this.ya + math.pi
				end
			end
			this.grounded = did_hit
		end

		if this.grounded and -this.grounded.ny < math.cos(math.rad(30)) then
			this.grounded = nil
		end

		if did_hit and -did_hit.ny < math.cos(math.rad(30)) then
			local vlen2 = math.sqrt(vx*vx + vz*vz)
			print("WALLRIDE")
			-- TODO: fix properly
			this.vel.x = did_hit.nx*vlen2
			this.vel.z = did_hit.nz*vlen2
			--this.grounded = nil
		end

		-- gravity
		local new_x = this.pos.x
		local new_y = this.pos.y
		local new_z = this.pos.z
		local old_vx = this.vel.x
		local old_vy = this.vel.y
		local old_vz = this.vel.z
		--this.vel.x = (new_x - old_x)/sec_delta/old_rem
		this.vel.y = (new_y - old_y)/sec_delta--/old_rem
		--this.vel.z = (new_z - old_z)/sec_delta/old_rem
		-- TODO apply gravity consistently
		this.vel.y = this.vel.y + sec_delta*9.0

		-- jumping
		if this.grounded then
			if this.do_jump then
				this.vel.y = this.vel.y - 3.4
				--print("JUMP", this.vel.y)
				this.grounded = nil
			end
			this.do_jump = false
		end
	end

	return this
end


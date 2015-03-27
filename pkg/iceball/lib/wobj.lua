--[[
Copyright (c) 2014 Team Sparkle

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]

-- World object class. Ideally, everything should inherit from this.
function wobj_new(settings)
	local this = {
		p = settings.p,
		f = settings.f or vec(0,0,1),
		vl = settings.vl or vec(0,0,0),
		vg = settings.vg or vec(0,0,0),
		al = settings.al or vec(0,0,0),
		ag = settings.ag or vec(0,0,0),
		phys = settings.phys or phys_map_none(),
		vl2d = settings.vl2d or false,
		grav = settings.grav or nil,
		aclimb = settings.aclimb or false,
		damp = settings.damp or 0.0,
		ac_jerk = vec(),
	} this.this = this

	-- Getter for the position.
	-- DO NOT ALTER THE TABLE DIRECTLY.
	function this.pos_get()
		return this.p
	end

	-- Calculate jump speed required to jump d blocks high.
	function this.get_jump_speed(d)
		local grav = this.grav or 1.0
		local acc = MODE_GRAVITY*4.0*grav

		-- d = a*t*t/2
		-- d, a known; find t
		---- 2*d/a = t*t
		---- t = sqrt(2*d/a)
		local t = math.sqrt(2*d/acc)

		-- v = a*t
		-- a, t known; find v
		local v = acc * t

		return v
	end

	-- Gets called every tick to deal with world collisions and whatnot.
	function this.on_blockage(blockage, delta)
		if blockage.x ~= 0 then
			this.vg.x = 0.0
		end

		if blockage.z ~= 0 then
			this.vg.z = 0.0
		end

		if blockage.y ~= 0 then
			this.vg.y = 0.0
		end
	end

	-- Call this if you want to advance this by some amount.
	function this.phys_advance(sec_delta)
		-- Build a matrix for moving stuff around.
		local fs = vec(0,1,0)
		local fz = norm3(cam.f)
		if this.vl2d then
			local suby = math.sqrt(1.0 - fz.y*fz.y)
			if suby <= -EPSILON or suby >= EPSILON then
				fz = mul_cv(1.0/suby, fz)
			end
			fz.y = 0.0
		end
		local fx = norm3(cross(fz, fs))
		local fy = norm3(cross(fx, fz))
		local m = mat3(fx, fy, fz)

		-- Apply gravity.
		-- d = v*t + (a*t*t)/2
		-- Tested to be consistent over a wide variety of sec_delta values.
		if this.grav then
			local acc = MODE_GRAVITY*4.0*this.grav
			this.vg.y = this.vg.y + sec_delta*acc
		end

		-- Apply acceleration.
		this.vg = add_vv(this.vg, mul_cv(sec_delta, add_vv(
			mul_mv(m, this.al),
			this.ag
		)))

		-- Dampen.
		local oldvgy = this.vg.y
		this.vg = mul_cv(math.exp(-sec_delta*this.damp), this.vg)
		this.vg.y = oldvgy

		-- Advance.
		local np = add_vv(this.p, mul_cv(sec_delta,
			add_vv(
				mul_mv(m, this.vl),
				this.vg
			)
		))

		local delta = sub_vv(np, this.p)
		local mdelta = this.phys.move_by(this, vec(), delta)
		local blockage = ftzv(sub_vv(delta, mdelta), 100)
		
		this.ac_jerk = mul_cv(math.exp(-sec_delta * 10.0), this.ac_jerk)
		if this.aclimb then
			local ac_mdelta = this.phys.move_by(this, vec(0,-1.01,0), delta)
			local ac_blockage = ftzv(sub_vv(delta, ac_mdelta), 100)
			ac_blockage.y = blockage.y
			if len3(ac_blockage) - len3(blockage) < -0.01 then
				mdelta = ac_mdelta
				blockage = ac_blockage
				this.p.y = this.p.y - 1.01
				this.ac_jerk.y = this.ac_jerk.y + 1.01
			end
		end

		this.p = add_vv(this.p, mdelta)

		-- Apply blockages
		this.on_blockage(blockage, delta)
	end

	-- Called every time this feels it needs to be updated.
	function this.tick(sec_current, sec_delta)
		this.phys_advance(sec_delta)
	end

	return this
end

-- Camera class.
function cam_new(settings)
	local this = wobj_new(settings)

	this.phys_stand = this.phys
	this.phys_crouch = settings.phys_crouch or this.phys
	this.phys_noclip = phys_map_none {}
	this.aclimb_stand = this.aclimb
	this.zoom = 1.0
	this.is_zoomed = false

	this.vp = vec()
	this.vn = vec()
	this.ay = math.pi*2.0
	this.ax = 0.0
	this.vax = 0
	this.vay = 0
	this.vaxp = 0
	this.vayp = 0
	this.vaxn = 0
	this.vayn = 0

	this.jump_height = settings.jump_height or 3.2

	this.jump_key = false
	this.crouch_key = false
	this.grounded = false

	local s_on_blockage = this.on_blockage
	function this.on_blockage(blockage, delta, ...)
		if blockage.y > 0 then
			this.grounded = true
		end

		return s_on_blockage(blockage, delta, ...)
	end

	local s_tick = this.tick
	function this.tick(sec_current, sec_delta)
		if this.vl2d then
			-- Undo noclip.
			if this.phys == this.phys_noclip then this.phys = this.phys_stand end

			-- Apply crouch if need be.
			if this.crouch_key then
				if this.phys == this.phys_stand then
					if this.grounded then
						this.p.y = this.p.y + 1
						this.ac_jerk.y = this.ac_jerk.y - 1
					end
					this.phys = this.phys_crouch
					this.aclimb = false
				end
			else
				if this.phys == this.phys_crouch then
					if not this.phys_stand.collides_with_map(this, vec(0, -1.01, 0)) then
						if this.grounded then
							this.p.y = this.p.y - 1
							this.ac_jerk.y = this.ac_jerk.y + 1
						end
						this.phys = this.phys_stand
						this.aclimb = this.aclimb_stand
					end
				end
			end
			-- Apply jump if need be.
			if this.jump_key then
				if this.grounded then
					this.vg.y = -this.get_jump_speed(this.jump_height)
					this.grounded = false
				end

				this.jump_key = false
			end

			-- Check if we can still jump.
			-- TODO.

			-- Calculate the forward vector.
			this.ax = this.ax + sec_delta * (this.vaxp - this.vaxn)
			local max_ax = math.pi*0.49
			if this.ax >  max_ax then this.ax =  max_ax end
			if this.ax < -max_ax then this.ax = -max_ax end
			this.ay = this.ay + sec_delta * (this.vayp - this.vayn)
			this.f = vec(
				math.cos(this.ax)*math.sin(this.ay),
				math.sin(this.ax),
				math.cos(this.ax)*math.cos(this.ay),
				0)

			-- Set local motion
			this.al = sub_vv(this.vp, this.vn)
		else
			-- Assuming noclip.
			-- Set physics.
			this.phys = this.phys_noclip

			-- Calculate the forward vector.
			this.ax = this.ax + sec_delta * (this.vaxp - this.vaxn)
			local max_ax = math.pi*0.49
			if this.ax >  max_ax then this.ax =  max_ax end
			if this.ax < -max_ax then this.ax = -max_ax end
			this.ay = this.ay + sec_delta * (this.vayp - this.vayn)
			this.f = vec(
				math.cos(this.ax)*math.sin(this.ay),
				math.sin(this.ax),
				math.cos(this.ax)*math.cos(this.ay),
				0)

			-- Set local motion
			this.vl = sub_vv(this.vp, this.vn)
		end

		-- Move along.
		return s_tick(sec_current, sec_delta)
	end

	return this
end


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

-- No physics. Pass through map.
function phys_map_none()
	return {
		collides_with_map = function () return false end,
		move_by = function (obj, offset, delta) return delta end,
	}
end

-- Point.
function phys_map_point(settings)
	local this = {
		ref = mul_vv(settings.ref or vec(), vec(1,1,1,0)),
	}

	function this.collides_with_map(offset)
		-- Get the offset we want.
		offset = offset or vec()
		local v = add_vv(add_vv(obj.pos_get(), this.ref), offset)

		-- Now just look it up!
		return map_solid_get(devec3(floorv(v)))
	end

	function this.move_by(obj, offset, delta)
		-- Let's get some useful vectors.
		offset = offset or vec()
		local from = add_vv(offset, obj.pos_get())
		local cell = floorv(from)
		local dir = signhardv(delta)

		-- TODO!
		return delta
	end

	return this
end

-- Axis-aligned box.
function phys_map_abox(settings)
	local this = {
		v1 = mul_vv(settings.v1 or vec(), vec(1,1,1,0)),
		v2 = mul_vv(settings.v2 or vec(), vec(1,1,1,0)),
	}

	function this.collides_with_map(obj, offset)
		-- Get two offsets, and floor them both.
		offset = offset or vec()
		offset = add_vv(offset, obj.pos_get())
		local v1 = floorv(add_vv(this.v1, offset))
		local v2 = floorv(add_vv(this.v2, offset))

		-- Loop away!
		local x,y,z
		for z=v1.z,v2.z do
		for x=v1.x,v2.x do
		for y=v1.y,v2.y do
			if map_solid_get(x,y,z) then
				return true
			end
		end end end
		
		return false
	end

	function this.move_by(obj, offset, delta)
		-- Let's get some useful vectors.
		offset = offset or vec()
		local from = add_vv(offset, obj.pos_get())
		local size = sub_vv(this.v2, this.v1)
		local dir = signhardv(delta)

		-- Corner point.
		local corner = blendv(function (c) return c < 0 end, dir, this.v1, this.v2)
		local point = add_vv(from, corner)
		local cell = floorv(point)
		local bound1 = sub_vv(this.v1, corner)
		local bound2 = sub_vv(this.v2, corner)

		-- Distance to coordinate boundary.
		local ndist = sub_vv(point, cell)
		local pdist = sub_vv(vec(1,1,1), ndist)
		local dist = blendv(function (c) return c < 0 end, dir, ndist, pdist)

		-- Some other things.
		local chcounts = absv(sub_vv(floorv(add_vv(point, delta)), cell))
		local chcmax = dot3(chcounts, vec(1,1,1))
		local can_move = vec(1,1,1,0)
		local vel = absv(norm3(delta))
		vel = mapv(function (c) return ((c < -EPSILON or c > EPSILON) and c)
			or ((c < 0 and -EPSILON) or EPSILON) end, vel)

		-- Here's a useful function.
		-- TODO: Make this do a 2D slice, rather than the whole 3D box.
		-- TODO: Use a "get floor/ceiling" function instead of a "get this voxel" function.
		local function block_me(v1, v2)
			local x,y,z
			for z=v1.z,v2.z do
			for x=v1.x,v2.x do
			for y=v1.y,v2.y do
				if map_solid_get(x,y,z) then
					return true
				end
			end end end

			return false
		end

		-- Some more setup.
		local missed = vec()
		local timeleft = len3(delta)

		-- Move to cells.
		local i
		for i=1,chcmax do
			-- Find the first coordinate we will hit.
			local det = div_vv(dist, vel)
			local cmp

			if det.x < det.y and det.x < det.z then cmp = "x"
			elseif det.y < det.z then cmp = "y"
			else cmp = "z" end

			-- Move that distance along.
			local movement = mul_cv(det[cmp], vel)
			point = add_vv(point, mul_vv(mul_vv(can_move, dir), movement))
			dist = sub_vv(dist, movement)
			timeleft = timeleft - det[cmp]

			local displ = 0.001
			local cbounds = mapvv(function (d, c)
				return c + ((d < 0 and displ) or (1-displ)) end, dir, cell)
			point = blendv(function(c) return c ~= 0 end, can_move, point, cbounds)

			-- Now collide!
			local ctest1 = floorv(add_vv(point, bound1))
			local ctest2 = floorv(add_vv(point, bound2))
			ctest1[cmp] = cell[cmp] + dir[cmp]
			ctest2[cmp] = cell[cmp] + dir[cmp]
			can_move[cmp] = (block_me(ctest1, ctest2) and 0) or 1
			cell[cmp] = cell[cmp] + dir[cmp] * can_move[cmp]
			dist[cmp] = dist[cmp] + 1
		end

		-- Final movement
		local movement = mul_cv(timeleft, vel)
		point = add_vv(point, mul_vv(mul_vv(can_move, dir), movement))

		-- Check to see if our point is in the correct cell
		-- -1 -> displ
		--  1 -> 1-displ
		local displ = 0.001
		local cbounds = mapvv(function (d, c)
			return c + ((d < 0 and displ) or (1-displ)) end, dir, cell)
		--local pcell = floorv(point)
		--point = blendv(function(c) return c == 0 end, sub_vv(pcell, cell), point, cbounds)
		point = blendv(function(c) return c ~= 0 end, can_move, point, cbounds)

		-- Return our point
		--return sub_vv(delta, missed)
		return sub_vv(sub_vv(point, corner), from)
	end

	return this
end



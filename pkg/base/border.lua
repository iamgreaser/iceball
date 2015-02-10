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

function new_border(x, y, z, nx, ny, nz, r, g, b)
	local this = {} this.this = this

	-- load parameters
	this.x, this.y, this.z = x, y, z
	this.nx, this.ny, this.nz = nx, ny, nz
	this.r, this.g, this.b = r, g, b
	
	-- set starting values
	this.ang, this.amp = 0, 0
	this.u, this.v = 0, 0
	this.t_next = nil

	-- generate model
	if client then
		if common.version.num >= 8421376+1 then
			local i, j
			local l = {}

			local function point(i, j, u)
				local v = (j/16+1)/2
				return {
					(this.ny*i + this.nz*j)*8,
					(this.nz*i + this.nx*j)*8,
					(this.nx*i + this.ny*j)*8,
					r/255.0, g/255.0, b/255.0, (math.max(i*i, j*j)/256)*0.5+0.3,
					u, v,
				}
			end
			for i=-16,15,8 do
			for j=-16,15,8 do
				local p00 = point(i+0, j+0, 0)
				local p01 = point(i+0, j+8, 0)
				local p10 = point(i+8, j+0, 1)
				local p11 = point(i+8, j+8, 1)

				l[1+#l] = p00
				l[1+#l] = p10
				l[1+#l] = p01
				l[1+#l] = p01
				l[1+#l] = p10
				l[1+#l] = p11

				l[1+#l] = p11
				l[1+#l] = p10
				l[1+#l] = p01
				l[1+#l] = p01
				l[1+#l] = p10
				l[1+#l] = p00
			end
			end

			this.va_border = common.va_make(l, nil, "3v,4c,2t")
		else
			this.mdl_border = common.model_new(1)
			this.mdl_border, this.mdl_border_bone = common.model_bone_new(this.mdl_border, 1024)

			local i, j
			local l = {}
			for i=-16,15 do
			for j=-16,15 do
				l[#l+1] = {
					x = (this.ny*i + this.nz*j)*8,
					y = (this.nz*i + this.nx*j)*8,
					z = (this.nx*i + this.ny*j)*8,
					r = this.r, g = this.g, b = this.b,
					radius = 1,
				}
			end
			end
			common.model_bone_set(this.mdl_border, this.mdl_border_bone, "border", l)
		end
	end

	function this.tick(sec_current, sec_delta)
		if not (this.t_next and this.t_next > sec_current) then
			this.t_next = sec_current + 0.2 + math.random()*0.6
			this.amp = math.random()*50.0+10.0
			this.ang = math.random()*math.pi*2
		end

		this.u = this.u + this.amp*math.cos(this.ang)*sec_delta
		this.v = this.v + this.amp*math.sin(this.ang)*sec_delta
		this.u = this.u % 8.0
		this.v = this.v % 8.0
	end

	function this.render()
		local gran = 8
		local cx, cy, cz
		cx, cy, cz = client.camera_get_pos()
		cx = math.floor(cx/gran)*gran
		cy = math.floor(cy/gran)*gran
		cz = math.floor(cz/gran)*gran

		local x, y, z
		if this.va_border then
			this.u = 0
			this.v = 0
		end
		x = this.x*this.nx + cx*(1-this.nx) + this.ny*this.u + this.nz*this.v
		y = this.y*this.ny + cy*(1-this.ny) + this.nz*this.u + this.nx*this.v
		z = this.z*this.nz + cz*(1-this.nz) + this.nx*this.u + this.ny*this.v

		if this.va_border then
			client.va_render_global(this.va_border,
				x, y, z, 0, 0, 0, 1,
				nil, "ah")
		else
			client.model_render_bone_global(this.mdl_border, this.mdl_border_bone,
				x, y, z, 0, 0, 0, 256)
		end
	end
	
	return this
end


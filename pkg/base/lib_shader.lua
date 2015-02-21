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

do

local shader_stack = {}

function shader_push_nil()
	shader_stack[1+#shader_stack] = true
	client.glsl_use(nil)
end

function shader_pop_nil()
	if shader_stack[#shader_stack] ~= true then
		error("mismatched shader pop")
	end

	shader_stack[#shader_stack] = nil
	if #shader_stack == 0 or shader_stack[#shader_stack] == true then
		client.glsl_use(nil)
	else
		local shader = shader_stack[#shader_stack]
		shader.activate()
	end
end

function shader_new(settings)
	local this = {
		vert = settings.vert or error("must provide vert shader source"),
		frag = settings.frag or error("must provide frag shader source"),
		unif = {},
	}

	this.prog, this.result = client.glsl_create(this.vert, this.frag)
	print("Shader", this.prog, this.result)

	if not this.prog then
		return nil, this.result
	end

	function this.push()
		shader_stack[1+#shader_stack] = this
		this.activate()
	end

	function this.pop()
		if shader_stack[#shader_stack] ~= this then
			error("mismatched shader pop")
		end

		shader_stack[#shader_stack] = nil
		if #shader_stack == 0 or shader_stack[#shader_stack] == true then
			client.glsl_use(nil)
		else
			local shader = shader_stack[#shader_stack]
			shader.activate()
		end
	end

	function this.activate()
		local k, v

		client.glsl_use(this.prog)
		for k, v in pairs(this.unif) do
			local loc = client.glsl_get_uniform_loc(this.prog, k)
			if loc then
				if #(v[2]) < 1 or #(v[2]) > 4 then
					error("too many dimensions for uniform")
				end

				if v[1] == "f" then
					client.glsl_set_uniform_f(loc, unpack(v[2]))
				elseif v[1] == "i" then
					client.glsl_set_uniform_i(loc, unpack(v[2]))
				elseif v[1] == "ui" then
					client.glsl_set_uniform_ui(loc, unpack(v[2]))
				else 
					error("invalid uniform type")
				end
			end
		end
	end

	function this.set_uniform_f(name, ...)
		this.unif[name] = {"f", {...}}
	end

	function this.set_uniform_i(name, ...)
		this.unif[name] = {"i", {...}}
	end

	function this.set_uniform_ui(name, ...)
		this.unif[name] = {"ui", {...}}
	end

	return this, this.result
end

end


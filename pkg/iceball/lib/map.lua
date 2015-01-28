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

function map_solid_get(x, y, z)
	-- They might be floats. Turn them into ints.
	x = math.floor(x)
	y = math.floor(y)
	z = math.floor(z)

	-- Check against the boundary.
	local lx, ly, lz = common.map_get_dims()
	if x < 0 or x >= lx or z < 0 or z >= lz or y >= ly then return true end
	if y < 0 then return false end

	-- Get the pillar and start reading.
	local l = common.map_pillar_get(x, z)
	local o = 1

	while true do
		if y < l[o+1] then return false end
		if l[o+0] ==0 then return true end
		o = o + 4*l[o+0]
		if y < l[o+3] then return true end
	end
end


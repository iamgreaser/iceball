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

EPSILON = 1 / 1024.0 / 1024.0 / 1024.0 / 1024.0 / 1024.0

function vec(x, y, z, w)
	return {
		x = x or 0.0,
		y = y or 0.0,
		z = z or 0.0,
		w = w or 0.0,
	}
end

function devec2(v) return v.x, v.y end
function devec3(v) return v.x, v.y, v.z end
function devec4(v) return v.x, v.y, v.z, v.w end

function dupv(v)
	return {
		x = v.x,
		y = v.y,
		z = v.z,
		w = v.w,
	}
end

function stripw(v)
	return {
		x = v.x,
		y = v.y,
		z = v.z,
		w = 0.0,
	}
end

function mat3(a, b, c)
	return {
		stripw(a or vec(1,0,0,0)),
		stripw(b or vec(0,1,0,0)),
		stripw(c or vec(0,0,1,0)),
		vec(0,0,0,1),
	}
end

function mat4(a, b, c, d)
	return {
		a or vec(1,0,0,0),
		b or vec(0,1,0,0),
		c or vec(0,0,1,0),
		d or vec(0,0,0,1),
	}
end

function iden()
	return mat()
end

function add_vv(v1, v2)
	return {
		x = v1.x + v2.x,
		y = v1.y + v2.y,
		z = v1.z + v2.z,
		w = v1.w + v2.w,
	}
end

function sub_vv(v1, v2)
	return {
		x = v1.x - v2.x,
		y = v1.y - v2.y,
		z = v1.z - v2.z,
		w = v1.w - v2.w,
	}
end

function mul_cv(c, v)
	return {
		x = c * v.x,
		y = c * v.y,
		z = c * v.z,
		w = c * v.w,
	}
end

function mul_vv(v1, v2)
	return {
		x = v1.x * v2.x,
		y = v1.y * v2.y,
		z = v1.z * v2.z,
		w = v1.w * v2.w,
	}
end

function div_vv(v1, v2)
	return {
		x = v1.x / v2.x,
		y = v1.y / v2.y,
		z = v1.z / v2.z,
		w = v1.w / v2.w,
	}
end

function mul_mv(m, v)
	return add_vv(
		add_vv(
			mul_cv(v.x, m[1]),
			mul_cv(v.y, m[2])
		), add_vv(
			mul_cv(v.z, m[3]),
			mul_cv(v.w, m[4])
		)
	)
end

function cross(v1, v2)
	return {
		x = v1.y*v2.z - v1.z*v2.y,
		y = v1.z*v2.x - v1.x*v2.z,
		z = v1.x*v2.y - v1.y*v2.x,
		w = (v1.w + v2.w)/2,
	}
end

function dot2(v1, v2)
	return 0.0
		+ v1.x*v2.x
		+ v1.y*v2.y
end

function dot3(v1, v2)
	return 0.0
		+ v1.x*v2.x
		+ v1.y*v2.y
		+ v1.z*v2.z
end

function dot4(v1, v2)
	return 0.0
		+ v1.x*v2.x
		+ v1.y*v2.y
		+ v1.z*v2.z
		+ v1.w*v2.w
end

function mapv(f, v)
	return {
		x = f(v.x),
		y = f(v.y),
		z = f(v.z),
		w = f(v.w),
	}
end

function mapvv(f, v1, v2)
	return {
		x = f(v1.x, v2.x),
		y = f(v1.y, v2.y),
		z = f(v1.z, v2.z),
		w = f(v1.w, v2.w),
	}
end

function blendv(f, vs, vt, vf)
	return {
		x = (f(vs.x) and vt.x) or vf.x,
		y = (f(vs.y) and vt.y) or vf.y,
		z = (f(vs.z) and vt.z) or vf.z,
		w = (f(vs.w) and vt.w) or vf.w,
	}
end

function len2(v) return math.sqrt(dot2(v, v)) end
function len3(v) return math.sqrt(dot3(v, v)) end
function len4(v) return math.sqrt(dot4(v, v)) end

function norm2(v) return mul_cv(1.0 / len2(v), v) end
function norm3(v) return mul_cv(1.0 / len3(v), v) end
function norm4(v) return mul_cv(1.0 / len4(v), v) end

function absv(v)
	return {
		x = math.abs(v.x),
		y = math.abs(v.y),
		z = math.abs(v.z),
		w = math.abs(v.w),
	}
end

function signv(v)
	-- The nice thing about this is that w stays the same when 1 or 0.
	return {
		x = (v.x <= -EPSILON and -1) or (v.x >= EPSILON and 1) or 0,
		y = (v.y <= -EPSILON and -1) or (v.y >= EPSILON and 1) or 0,
		z = (v.z <= -EPSILON and -1) or (v.z >= EPSILON and 1) or 0,
		w = (v.w <= -EPSILON and -1) or (v.w >= EPSILON and 1) or 0,
	}
end

function signhardv(v)
	-- I refuse to put a hard sign on w. w should always be 1 or 0, anyway.
	return {
		x = (v.x < 0 and -1) or 1,
		y = (v.y < 0 and -1) or 1,
		z = (v.z < 0 and -1) or 1,
		w = (v.w <= -EPSILON and -1) or (v.w >= EPSILON and 1) or 0,
	}
end

function floorv(v)
	return {
		x = math.floor(v.x),
		y = math.floor(v.y),
		z = math.floor(v.z),
		w = math.floor(v.w),
	}
end

function homog(v)
	if math.abs(v.w) < EPSILON then return v end

	return {
		x = v.x / v.w,
		y = v.y / v.w,
		z = v.z / v.w,
		w = 1,
	}
end

function ftzv(v, strength)
	strength = strength or 1
	return mapv(function (c)
		return ((c > -strength*EPSILON and c < strength*EPSILON) and 0) or c
	end, v)
end


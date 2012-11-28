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

function bit_unsign(a,m)
	m = math.pow(2,m)
	local v = math.fmod(a,m)
	if v < 0 then
		v = v + m
	end
	return v
end

function bit_xor(a,b)
	local shift = 1
	local v = 0
	while a > 0 and b > 0 do
		if (math.fmod(a,2) ~= 0) ~= (math.fmod(b,2) ~= 0) then
			v = v + shift
		end
		shift = shift * 2
		a = math.floor(a/2)
		b = math.floor(b/2)
	end
	return v + a*shift + b*shift
end

function bit_or(a,b)
	local shift = 1
	local v = 0
	while a > 0 and b > 0 do
		if (math.fmod(a,2) ~= 0) or (math.fmod(b,2) ~= 0) then
			v = v + shift
		end
		shift = shift * 2
		a = math.floor(a/2)
		b = math.floor(b/2)
	end
	return v + a*shift + b*shift
end

function bit_and(a,b)
	local shift = 1
	local v = 0
	while a > 0 and b > 0 do
		if (math.fmod(a,2) ~= 0) and (math.fmod(b,2) ~= 0) then
			v = v + shift
		end
		shift = shift * 2
		a = math.floor(a/2)
		b = math.floor(b/2)
	end
	return v
end

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

argv = argv or {...}

common.mk_compat_disable()

-- Player list.
players = {
	max = 64,
	p = {},
	neth_to_index = {},
}

-- Load some libraries.
dofile("pkg/iceball/lib/heartbeat.lua")
dofile("pkg/iceball/lib/map.lua")
dofile("pkg/iceball/lib/player.lua")
dofile("pkg/iceball/lib/phys.lua")
dofile("pkg/iceball/lib/vector.lua")
dofile("pkg/iceball/lib/wobj.lua")

function server.hook_file(neth, ftype, fname)
	-- TODO: All the necessary security crap that goes here
	if fname == "*MAP" then
		return map
	else
		return true
	end
end

function server.hook_tick(sec_curtime, sec_delta)
	heartbeat_update(sec_curtime, sec_delta)
	
	return 0.01
end

-- Let's load a map!
map = nil
map = map or (argv[1] and common.map_load(argv[1]))

if not map then
	local h = 100
	-- The default is a low XOR pattern.
	map = map or common.map_new(256, h, 256)

	-- Punch a hole in it.
	do
		local x,z
		for z=100,256-100,1 do
		for x=100,256-100,1 do
			common.map_pillar_set(x, z, {0, h, h-1, 0})
		end end
	end
end

-- Start heartbeat
heartbeat_init()



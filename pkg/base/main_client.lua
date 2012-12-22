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

print("pkg/base/main_client.lua starting")

dofile("pkg/base/version.lua")

local vernotes = ""
local cver = common.version
local bug_str

local function bug_str_gen()
	local i
	local s = ""
	
	for i=1,#VERSION_BUGS do
		local bug = VERSION_BUGS[i]
		if ((not bug.intro) or bug.intro <= cver.num) and
			((not bug.fix) or bug.fix > cver.num) then
			s = s.."- "..bug.msg.."\n"
		end
	end
	
	return (s ~= "" and "\nCLIENT ISSUES:\n"..s) or ""
end

if cver == nil then
	cver = {
		cmp={0,0,0,0,-1004},
		num=-1,
		str="iceballfornoobs-004 (or pre-0.0-1 git)",
	}
	bug_str = bug_str_gen(cver.num)
	vernotes = [[
This is one of a multitude of old versions,
most likely iceballfornoobs-004.
]]..bug_str..[[
We will inform you once we have a newer noob build.

If you're using a git build, please upgrade!]]
elseif cver.num == VERSION_ENGINE.num then
	bug_str = bug_str_gen(cver.num)
	vernotes = [[
This is the expected version.
]]..bug_str..[[]]
elseif cver.num > VERSION_ENGINE.num and cver.cmp[5] == 0 then
	bug_str = bug_str_gen(cver.num)
	vernotes = [[
This is a newer version than this mod expects.
Please tell the server owner to upgrade.
]]..bug_str..[[]]
elseif cver.num > VERSION_ENGINE.num then
	bug_str = bug_str_gen(cver.num)
	vernotes = [[
This is a newer version than this mod expects.
The bug information here might not apply.
]]..bug_str..[[]]
else
	bug_str = bug_str_gen(cver.num)
	vernotes = [[
This is an older version than this mod expects.
You should have at least ]]..VERSION_ENGINE.str..[[.
]]..bug_str..[[]]
end

-- please excuse this hack.
a1,a2,a3,a4,a5,a6,a7,a8,a9,a10 = ...

dofile("pkg/base/lib_gui.lua")

do
	local scriptcache = {}
	
	local fnlist = {}
	function load_screen_fetch(ftype, fname)
		local cname = ftype.."!"..fname
		local cacheable = ftype ~= "map" and ftype ~= "icemap" and ftype ~= "vxl"
		if cacheable and scriptcache[cname] then
			fnlist[#fnlist+1] = fname.." [CACHED]"
			return scriptcache[cname]
		end
		
		fnlist[#fnlist+1] = fname
		
		local map,r,g,b,dist
		map = common.map_get()
		r,g,b,dist = client.map_fog_get()
		
		local old_tick = client.hook_tick
		local old_render = client.hook_render
		local old_key = client.hook_key
		local old_mouse_button = client.hook_mouse_button
		local old_mouse_motion = client.hook_mouse_motion
		
		function client.hook_key(key, state, modif)
			-- TODO!
		end
		
		function client.hook_mouse_button(button, state)
			-- TODO!
		end
		
		function client.hook_mouse_motion(x, y, dx, dy)
			-- TODO!
		end
		
		common.map_set(nil)
		client.map_fog_set(85, 85, 85, 127.5)
		local csize, usize, amount
		local obj = common.fetch_start(ftype, fname)
		
		local loadstr = "Fetching..."
		
		function client.hook_render()
			local i
			local sw,sh
			sw,sh = client.screen_get_dims()
			local koffs = math.max(#fnlist-10,1)
			for i=koffs,#fnlist do
				font_mini.print(2, 2+(i-koffs)*8, 0xFFFFFFFF, "LOAD: "..fnlist[i])
			end
			font_mini.print(2, sh-10, 0xFFFFFFFF, loadstr)
			
			font_mini.print(2, 2+(12)*8, 0xFFFFFFFF, "Version: "..cver.str)
			local l = string.split(vernotes,"\n")
			for i=1,#l do
				font_mini.print(2, 2+(i+14)*8, 0xFFFFFFFF, l[i])
			end
		end
		
		function client.hook_tick(sec_current, sec_delta)
			-- TODO!
			print("tick called.")
			return 0.005
		end
		
		csize = nil
		usize = nil
		amount = 0.0
		if obj == true then
			while true do
				obj, csize, usize, amount = common.fetch_poll()
				--print("obj:", obj, csize, usize, amount)
				if obj ~= false then break end
				
				if csize then
					loadstr = "Fetching... "
						..(math.floor(amount*100.0))
						.."% ("
						..(math.floor(amount*csize))
						.."/"
						..csize
						.." - uncompressed = "
						..usize
						..")"
				end
			end
		end
		
		client.hook_tick = old_tick
		client.hook_render = old_render
		client.hook_key = old_key
		client.hook_mouse_button = old_mouse_button
		client.hook_mouse_motion = old_mouse_motion
		
		common.map_set(map)
		client.map_fog_set(r,g,b,dist)
		
		if cacheable then
			scriptcache[cname] = obj
		end
		
		return obj
	end
end

common.fetch_block = load_screen_fetch

function client.hook_tick()
	client.hook_tick = nil
	loadfile("pkg/"..common.base_dir.."/client_start.lua")(a1,a2,a3,a4,a5,a6,a7,a8,a9,a10)
	return 0.005
end

--dofile("pkg/base/client_start.lua")
print("pkg/base/main_client.lua loaded.")


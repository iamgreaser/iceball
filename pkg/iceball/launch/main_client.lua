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

-- Master server to use.
MASTER_URL = "http://magicannon.com:27790/master.json"

-- Some arguments...
argv = {...}

-- Connect to master server
dofile("pkg/iceball/lib/http.lua")
server_list = true
master_http = http_new {url = MASTER_URL}
if not master_http then
	server_lsit = false
end

-- A creative hack to make this whole thing work.
function arg_closure(arg_array, offset)
	offset = offset or 1

	if #arg_array == 0 then
		return
	elseif offset == #arg_array then
		return arg_array[offset]
	else
		return arg_array[offset], arg_closure(arg_array, offset+1)
	end
end

-- Some libraries
dofile("pkg/iceball/lib/font.lua")
dofile("pkg/iceball/lib/sdlkey.lua")

-- Some hooks
function client.hook_key(key, state, modif, uni)
	if not state then
		if key == SDLK_l then
			client.mk_sys_execv("-s", "20737", "pkg/base", arg_closure(argv))
		elseif key == SDLK_ESCAPE then
			client.hook_tick = nil
		elseif key >= SDLK_1 and key <= SDLK_9 then
			local idx = (key - SDLK_1) + 1
			if idx <= #server_list then
				local sv = server_list[idx]
				client.mk_sys_execv("-c", sv.address, sv.port, arg_closure(argv))
			end
		end
	end
end

client.map_fog_set(0, 0, 170, 100)
function client.hook_render()
	local font = font_dejavu_bold[18]
	local ch = font.iheight
	font.render(0, ch*0, "Press L for a local server on port 20737")
	font.render(0, ch*1, "Press Escape to quit")
	font.render(0, ch*2, "Press a number to join a server")
	font.render(0, ch*4, "Server list:")

	local i
	if server_list == true then
		font.render(0, ch*6, "Fetching...", 0xFFAAAAAA)
	elseif server_list == nil then
		font.render(0, ch*6, "Failed to fetch the server list.", 0xFFFF5555)
	else
		for i=1,#server_list do
			local sv = server_list[i]
			font.render(0, ch*(6+i-1), i..": "..sv.name
				.." - "..sv.players_current.."/"..sv.players_max
				.." - "..sv.mode
				.." - "..sv.map)
		end
	end
end

function client.hook_tick(sec_current, sec_delta)
	-- Fetch the master server list if possible.
	if master_http then
		local status = master_http.update()
		if status == nil then
			master_http = nil
			server_list = nil
		elseif status ~= true then
			print(status)
			server_list = common.json_parse(status)
			server_list = server_list and server_list.servers
			master_http = nil
		end
	end
	return 0.01
end


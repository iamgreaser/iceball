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

-- Simple, not necessarily secure sandbox.
-- More like a VM.
sandbox = {}

do

local sb_counter = 1
local sb_list = {}
local sb_aux = {}
local sb_ctl = {}
local sb_current = ""

local sb_wrap_fetch = loadfile("pkg/base/sandbox/fetch.lua")(sb_list, sb_aux, sb_ctl)
local sb_wrap_audio = loadfile("pkg/base/sandbox/wav.lua")(sb_list, sb_aux, sb_ctl)
local sb_wrap_gfx = loadfile("pkg/base/sandbox/gfx.lua")(sb_list, sb_aux, sb_ctl)

local function table_dup(S)
	if S == nil then return nil end

	local D = {}
	local k, v

	for k, v in pairs(S) do
		if type(v) == "table" then
			D[k] = table_dup(v)
		else
			D[k] = v
		end
	end

	return D
end

-- Creates a new sandbox with a given name.
-- Returns actual name in case of collision.
function sandbox.new(name, fname, ...)
	-- Pick a name
	if sb_list[name] then
		while sb_list[name.."-"..sb_counter] do
			sb_counter = sb_counter + 1
		end

		name = name.."-"..sb_counter
		sb_counter = sb_counter + 1
	end

	print("Creating sandbox \""..name.."\"")

	-- Create new environment
	local SG = {}
	SG._G = SG
	sb_list[name] = SG
	sb_aux[name] = {}

	sb_aux[name].tick_enabled = true

	-- Copy some builtins
	SG.string = string
	SG.math = math
	SG.table = table

	SG.assert = assert
	SG.collectgarbage = collectgarbage
	SG.error = error
	SG.getfenv = getfenv
	SG.getmetatable = getmetatable
	SG.ipairs = ipairs
	SG.next = next
	SG.pairs = pairs
	SG.pcall = pcall
	SG.print = print
	SG.rawequal = rawequal
	SG.rawget = rawget
	SG.rawset = rawset
	SG.select = select
	SG.setfenv = setfenv
	SG.setmetatable = setmetatable
	SG.tonumber = tonumber
	SG.tostring = tostring
	SG.type = type
	SG.unpack = unpack
	SG._VERSION = _VERSION
	SG.xpcall = xpcall

	-- Copy main things
	setfenv(table_dup, _G)
	SG.client = table_dup(client)
	SG.common = table_dup(common)
	SG.server = table_dup(server)
	SG.sandbox = table_dup(sandbox)

	-- Remove hooks
	local k,v
	local clsv = (SG.client or SG.server)
	for k,v in pairs(clsv) do
		if k:sub(1,5) == "hook_" then
			clsv[k] = nil
		end
	end

	-- Enable wrappers
	sb_wrap_fetch(sb_list, sb_aux, sb_ctl, name)
	sb_wrap_audio(sb_list, sb_aux, sb_ctl, name)
	sb_wrap_gfx(sb_list, sb_aux, sb_ctl, name)

	function SG.sandbox.this()
		return name
	end

	-- Do file
	-- Return name
	return name, (SG.loadfile(fname))(...)
end

-- Kills a sandbox.
function sandbox.kill(name)
	if not sb_list[name] then
		error("nonexistant sandbox \""..tostring(name).."\"")
	end

	if client then
		sb_ctl.gfx_kill(name)
	end

	sb_list[name] = nil
	sb_aux[name] = nil
end

if client then
	function client.hook_tick(...)
		local k, v
		local hadf = false
		local retacc = 1
		local kill_list = {}
		for k, v in pairs(sb_list) do
			if sb_aux[k].tick_enabled then
				local f = v.client.hook_tick
				if f then
					hadf = true
					sb_ctl.gfx_api_push(k)
					retacc = math.min(retacc, f(...))
					sb_ctl.gfx_api_pop()
				else
					kill_list[1+#kill_list] = k
				end
			end
		end

		for k, v in pairs(kill_list) do
			print("Killing sandbox \""..tostring(v).."\"")
			sandbox.kill(v)
		end

		if not hadf then
			client.hook_tick = nil
		end
		sb_ctl.gfx_api_prerender()
	end

	function client.hook_key(...)
		if not sb_list[sb_ctl.gfx_select] then return end
		local f = sb_list[sb_ctl.gfx_select].client.hook_key
		if f then
			sb_ctl.gfx_api_push(sb_ctl.gfx_select)
			f(...)
			sb_ctl.gfx_api_pop()
		end
		sb_ctl.gfx_api_prerender()
	end

	function client.hook_mouse_button(...)
		if not sb_list[sb_ctl.gfx_select] then return end
		local f = sb_list[sb_ctl.gfx_select].client.hook_mouse_button
		if f then
			sb_ctl.gfx_api_push(sb_ctl.gfx_select)
			f(...)
			sb_ctl.gfx_api_pop()
		end
		sb_ctl.gfx_api_prerender()
	end

	function client.hook_mouse_motion(...)
		if not sb_list[sb_ctl.gfx_select] then return end
		local f = sb_list[sb_ctl.gfx_select].client.hook_mouse_motion
		if f then
			sb_ctl.gfx_api_push(sb_ctl.gfx_select)
			f(...)
			sb_ctl.gfx_api_pop()
		end
		sb_ctl.gfx_api_prerender()
	end

	function client.hook_render(...)
		if not sb_list[sb_ctl.gfx_select] then return end
		local f = sb_list[sb_ctl.gfx_select].client.hook_render

		if f then
			sb_ctl.gfx_api_push(sb_ctl.gfx_select)
			f(...)
			sb_ctl.gfx_api_pop()
		end
		sb_ctl.gfx_api_prerender()
	end

	function client.hook_kick(...)
		local k, v
		for k, v in pairs(sb_list) do
			local f = v.client.hook_kick
			if f then
				f(...)
			end
		end
	end

elseif server then
	function server.hook_tick(...)
		local k, v
		local hadf = false
		local retacc = 1
		for k, v in pairs(sb_list) do
			if sb_aux[k].tick_enabled then
				local f = v.server.hook_tick
				if f then
					hadf = true
					retacc = math.min(retacc, f(...))
				end
			end
		end

		if not hadf then
			server.hook_tick = nil
		end
	end

	function server.hook_file(...)
		local f = sb_list[sb_current].server.hook_file
		if f then
			return f(...)
		end
	end

	function server.hook_connect(...)
		local f = sb_list[sb_current].server.hook_connect
		if f then
			return f(...)
		end
	end

	function server.hook_disconnect(...)
		local f = sb_list[sb_current].server.hook_disconnect
		if f then
			return f(...)
		end
	end
end

sb_current = "root" -- TO BE PHASED OUT

end

-- Do initial sandbox
if client then
	sandbox.new("root", "pkg/base/main_client.lua", ...)
elseif server then
	sandbox.new("root", "pkg/base/main_server.lua", ...)
else
	error("Cannot determine if client or server!")
end


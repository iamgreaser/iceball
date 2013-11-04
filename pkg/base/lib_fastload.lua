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

local function copytab(t)
	local nt = {}
	local k,v
	for k,v in pairs(t) do
		if type(v) == type({}) then
			nt[k] = copytab(v)
		else
			nt[k] = v
		end
	end
	return nt
end

local function wrapenv(f, state)
	print("wrap", f, state)
	return function(...)
		local oldenv = getfenv(f)
		setfenv(f, state.e)
		return (function (...)
			setfenv(f, oldenv)
			return ...
		end)(f(...))
	end
end

function fastload_getfile(fname, state)
	-- Get our file if we don't have it already
	if state.f[fname] == nil then
		if fname == "*GAMEMODE" then
			state.f[fname] = wrapenv(loadfile(GAME_MODE), state)
		else
			state.cache["lua:" .. fname] = common.bin_load(fname)
			state.f[fname] = wrapenv(loadfile(fname), state)
		end
	end

	return state.f[fname]
end

function fastload_analyse_client()
	local k,v

	-- Create our state
	state = {
		cache = {},
		e = {
			client = {},
			--server = {},
			common = {
				version = copytab(common.version)
			},
			math = {},
			string = {},
			table = {},
		},
		f = {},
	}

	-- _G refers to the environment
	state.e._G = state.e

	-- Stash the current map
	local svmap = common.map_get()
	local svmap_copy = common.map_new(common.map_get_dims())
	print("Copying server map")
	do
		local x,y
		local w,h,_
		w, _, h = common.map_get_dims()
		for y=0,h-1 do
		for x=0,w-1 do
			common.map_set(svmap)
			local l = common.map_pillar_get(x, y)
			common.map_set(svmap_copy)
			common.map_pillar_set(x, y, l)
		end
		end
	end
	common.map_set(nil)
	print("Server map copied!")

	-- Functions we need to dummy out
	for k,v in pairs({
		"print",
	}) do state.e[v] = function(...) end end

	-- Function tables we need to copy
	for k,v in pairs(math) do state.e.math[k] = v end
	for k,v in pairs(string) do state.e.string[k] = v end
	for k,v in pairs(table) do state.e.table[k] = v end

	-- Special wrappers

	-- loadfile: we need to feed through fastload_analyse
	local function loadfile_wrap(fn)
		return fastload_getfile(fn, state)
	end
	state.e.loadfile = loadfile_wrap

	-- loadstring: we need to wrap what we've got
	function state.e.loadstring(...)
		return wrapenv(loadstring, state)(...)
	end

	-- dofile: depends on loadfile
	function state.e.dofile(fn)
		local f = state.e.loadfile(fn)
		return f()
	end

	-- Some things we need to just pass through
	state.e.getfenv = getfenv
	state.e.setfenv = setfenv
	state.e.getmetatable = getmetatable
	state.e.setmetatable = setmetatable
	state.e.rawget = rawget
	state.e.rawset = rawset
	state.e.pcall = pcall
	state.e.pairs = pairs
	state.e.ipairs = ipairs

	-- client.wav_play_local/global
	function state.e.client.wav_play_local(...) return 1 end
	function state.e.client.wav_play_global(...) return 1 end

	-- common.map_set/get: Pass straight through
	state.e.common.map_set = common.map_set
	state.e.common.map_get = common.map_get

	-- client.map_fog_set/get: Stash some defaults
	do
		local fog = {192, 238, 255, 60}

		function state.e.client.map_fog_set(r, g, b, dist)
			fog[1] = r
			fog[2] = g
			fog[3] = b
			fog[4] = dist
		end

		function state.e.client.map_fog_get()
			return fog[1], fog[2], fog[3], fog[4]
		end
	end

	-- common.json_load: refers to stuff in clsave as well as other stuff
	function state.e.common.json_load(fname)
		print("json_load", fname)
		if fname == "clsave/pub/user.json" then
			return {
				name = "FastLoadTest",
				kick_on_join = false,
				sensitivity = 1.0,
				hold_to_zoom = false,
				fog = 127.5,

				skins = {},
			}
		elseif fname == "clsave/pub/controls.json" then
			return {
			}
		elseif fname == "*MODCFG" then
			return common.json_load(mod_conf_file)
		else
			state.cache["json:" .. fname] = common.bin_load(fname)
			return common.json_load(fname)
		end
	end

	-- common.map_load: *MAP anyone?
	function state.e.common.map_load(fname, fmt)
		print("map_load", fname, fmt)
		if fname == "*MAP" then
			return svmap_copy
		else
			state.cache[fmt .. ":" .. fname] = common.bin_load(fname)
			return common.map_load(fname, fmt)
		end
	end

	-- common.img_load
	function state.e.common.img_load(fname, fmt)
		if fname:find("clsave/pub/skin/", 1, true) == 1 then
			return nil
		end

		print("fetch_img", fmt, fname)
		if fname == "*MAPIMG" then
			return common.img_new(800, 600)
		else
			fmt = fmt or "tga"
			state.cache[fmt .. ":" .. fname] = common.bin_load(fname)
			return common.img_load(fname, fmt)
		end
	end

	-- Some direct functions
	state.e.common.time = common.time
	state.e.common.img_get_dims = common.img_get_dims
	state.e.common.img_free = common.img_free
	state.e.common.model_bone_find = common.model_bone_find
	state.e.common.model_bone_get = common.model_bone_get
	state.e.common.model_new = common.model_new
	state.e.common.model_bone_new = common.model_bone_new
	state.e.common.model_bone_set = common.model_bone_set
	state.e.common.map_get_dims = common.map_get_dims
	state.e.common.img_new = common.img_new
	state.e.common.map_pillar_get = common.map_pillar_get
	state.e.common.img_pixel_set = common.img_pixel_set
	--state.e.common.@ = common.@
	--state.e.common.@ = common.@

	-- client.screen_get_dims: 800, 600
	function state.e.client.screen_get_dims() return 800, 600 end

	-- client.wav_cube_size: dummy
	function state.e.client.wav_cube_size() end

	-- common.fetch_block: Need to cache all the things, except for the things that we can't
	local function fetch_block(typ, fname)
		print("fetch", typ, fname)

		if fname:find("clsave/pub/skin/", 1, true) == 1 then
			return nil
		end

		if typ == "lua" then
			return loadfile_wrap(fname)
		else
			state.cache[typ .. ":" .. fname] = common.bin_load(fname)
			return common.fetch_block(typ, fname)
		end
	end
	state.e.common.fetch_block = fetch_block

	-- common.fetch_start: Call fetch_block instead
	function state.e.common.fetch_start(ftype, fname)
		print(ftype, fname)
		return fetch_block(ftype, fname)
	end


	-- Make copies of the common functions we're using
	for k,v in pairs(state.e.common) do
		state.e.client[k] = v
		--state.e.server[k] = v
	end

	-- Load and run.
	state.e.dofile("pkg/base/main_client.lua")
	state.e.dofile("pkg/base/client_start.lua")

	-- Restore the current map
	common.map_set(svmap)

	print("Destroying map copy!")
	common.map_free(svmap_copy)

	print("Cache analysed.")

	local cstr = ""
	for k,v in pairs(state.cache) do
		cstr = cstr .. " " .. k
	end
	print("Cached files:"..cstr)

	print("TODO: dump this list somewhere")
end


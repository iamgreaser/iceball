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
	
	-- Tell it there's a sandbox
	state.e.sandbox = {}

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
	state.e.common.net_unpack = common.net_unpack
	--state.e.common.@ = common.@
	--state.e.common.@ = common.@

	-- client.screen_get_dims: 800, 600
	function state.e.client.screen_get_dims() return 800, 600 end

	-- client.wav_cube_size: dummy
	function state.e.client.wav_cube_size() end

	-- client.va_make: dummy
	function state.e.client.va_make() end
	function state.e.common.va_make() end

	-- client.img_fill: dummy
	function state.e.client.img_fill() end

	-- common.fetch_block: Need to cache all the things, except for the things that we can't
	local function fetch_block(typ, fname)
		print("fetch", typ, fname)

		if fname:find("clsave/pub/skin/", 1, true) == 1 then
			return nil
		end

		if typ == "lua" then
			return loadfile_wrap(fname)
		elseif typ == "png" and fname == "*MAPIMG" then
			return common.img_new(800, 600)
		else
			state.cache[typ .. ":" .. fname] = common.bin_load(fname)
			return common.fetch_block(typ, fname)
		end
	end
	state.e.common.fetch_block = fetch_block

	-- common.bin_load: Call fetch_block instead
	function state.e.common.bin_load(fname)
		return fetch_block("bin", fname)
	end

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
	local clist = {}
	for k,v in pairs(state.cache) do
		cstr = cstr .. " " .. k
		clist[1+#clist] = k
	end
	print("Cached files:"..cstr)

	common.json_write("svsave/vol/fastload.json", {
		files = clist,
	})

	local clcmp = common.json_load("svsave/vol/fastload.json")
	print(clcmp.files[1])

	print("Filenames dumped to svsave/vol/fastload.json")
end

function fastload_pack_client()
	local r1, r2
	r1, r2 = pcall(function ()
		return common.json_load("svsave/vol/fastload.json")
	end)

	if not r1 then
		print("Error loading fastload names: "..r2)
		print("Run the server with the -flcache flag to generate svsave/vol/fastload.json")
		return string.char(0)
	elseif not r2 then
		print("Error loading fastload names - file not found")
		print("Run the server with the -flcache flag to generate svsave/vol/fastload.json")
		return string.char(0)
	end

	print("Generating fastload pack")

	local dat = ""
	
	local k,v

	for k,v in pairs(r2.files) do
		local r1, r2
		r1, r2 = pcall(function ()
			local pivot = v:find(":", 1, true)
			local fmt = v:sub(1, pivot-1)
			local fname = v:sub(pivot+1)
			print("load:", fmt, fname)

			local body = common.fetch_block("bin", fname)
			if body == nil then error("fetch_block returned nil") end

			dat = dat .. string.char(#v) .. v

			dat = dat .. string.char(math.floor(((#body) / (2^0)) % 256))
			dat = dat .. string.char(math.floor(((#body) / (2^8)) % 256))
			dat = dat .. string.char(math.floor(((#body) / (2^16)) % 256))
			dat = dat .. string.char(math.floor(((#body) / (2^24)) % 256))
			dat = dat .. body
		end)

		if not r1 then
			print("ERROR: Fastload failed to pack file \"" .. v .. "\"! (Is the cache outdated?)")
		end
	end

	dat = dat .. string.char(0)
	print(string.format("fastload data size: %i bytes", #dat))
	common.bin_save("svsave/vol/fldata.bin", dat)
end

local fldata_int = nil
function fastload_fetch()
	local body = common.bin_load("*FASTLOAD")
	if body == nil then
		print("ERROR: Server does not provide fastload. Loading more slowly now!")
		return
	end
	fldata_int = {}

	local i = 1
	while body:byte(i) ~= 0 do
		local len = body:byte(i)
		i = i + 1
		local fnp = body:sub(i, i+len-1)
		i = i + len
		local dlen = (body:byte(i+0) * (2^0)
			+ body:byte(i+1) * (2^8)
			+ body:byte(i+2) * (2^16)
			+ body:byte(i+3) * (2^24))
		i = i + 4
		local dat = body:sub(i, i+dlen-1)
		i = i + dlen
		print("fastload data: fnpair", len, fnp, #fnp, dlen, #dat)
		common.bin_save("clsave/vol/fastload.tmp", dat)
		local pivot = fnp:find(":", 1, true)
		local fmt = fnp:sub(1, pivot-1)
		local r1,r2
		r1,r2 = pcall(function ()
			fldata_int[fnp] = common.fetch_block(fmt, "clsave/vol/fastload.tmp")
		end)

		if not r1 then
			print("ERROR: failed to preload \"" ..fnp.. "\": ".. r2)
		end
	end
end

function fastload_check(fmt, fname)
	if fldata_int == nil then return nil end
	local pname = fmt..":"..fname
	return fldata_int[pname]
end


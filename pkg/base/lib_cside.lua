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

-- Create the table for clientside code
_CSIDE_G = {}
_CSIDE_G._G = _CSIDE_G
_CSIDE_G.hooks = {}

local builtins_main = {
	"_VERSION",
	"assert",
	"collectgarbage",
	"dofile",
	"error",
	"getfenv",
	"getmetatable",
	"ipairs",
	"load",
	"loadfile",
	"loadstring",
	"module",
	"next",
	"pairs",
	"pcall",
	"print",
	"rawequal",
	"rawget",
	"rawset",
	"require",
	"select",
	"setfenv",
	"setmetatable",
	"tonumber",
	"tostring",
	"type",
	"unpack",
	"xpcall",
}

-- Deep-copy a few builtins
do
	local k,v

	for k,v in pairs(builtins_main) do
		_CSIDE_G[v] = _G[v]
	end

	_CSIDE_G.coroutine = {}
	for k,v in pairs(coroutine) do
		_CSIDE_G.coroutine[k] = v
	end

	_CSIDE_G.math = {}
	for k,v in pairs(math) do
		_CSIDE_G.math[k] = v
	end

	_CSIDE_G.string = {}
	for k,v in pairs(string) do
		_CSIDE_G.string[k] = v
	end

	_CSIDE_G.table = {}
	for k,v in pairs(table) do
		_CSIDE_G.table[k] = v
	end
end

-- Wrap the loaders
do
	-- TODO ensure that load is secure!
	local s_load = load
	function _CSIDE_G.load(...)
		local ret = {s_load(...)}

		if ret[1] ~= nil then
			setfenv(ret[1], _CSIDE_G)
		end

		return unpack(ret)
	end

	local s_loadstring = loadstring
	function _CSIDE_G.loadstring(...)
		local ret = {s_loadstring(...)}

		if ret[1] ~= nil then
			setfenv(ret[1], _CSIDE_G)
		end

		return unpack(ret)
	end

	local s_loadfile = loadfile
	function _CSIDE_G.loadfile(fname, ...)
		-- XXX: do we attempt any pathname checks?
		local ret = {s_loadfile(fname, ...)}

		if ret[1] ~= nil then
			setfenv(ret[1], _CSIDE_G)
		end

		return unpack(ret)
	end

	function _CSIDE_G.dofile(fname)
		local ret, ret2 = s_loadfile(fname)
		assert(ret, ret2)
		setfenv(ret[1], _CSIDE_G)
		ret()
	end
end

-- Wrap getfenv
do
	local s_getfenv = getfenv
	function _CSIDE_G.getfenv(f)
		local ret = s_getfenv(f)

		if ret == _G then
			ret = _CSIDE_G
		end

		return ret
	end
end

-- Load the file
do
	print("Attempting to load clientside VM function")
	local err = {pcall(function()
		local err
		cside_vm_func, err = _CSIDE_G.loadfile("clsave/pub/vm/main.lua")
		if not cside_vm_func then
			print("Failed:", err)
		else
			print("Success, now running")
			print("Result:", cside_vm_func()) -- if your hook is broken, this should crash on error
		end
	end)}
	if (not err[1]) then
		print("Failed to fetch:", unpack(err))
	end
end


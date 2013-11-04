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

local loaded = {}
local failed = {}
local prevmod = {}

function get_mod_name(path)
	if path ~= path:lower() then
		error("Someone didn't follow the convention of all-lowercase names! This is more important than you futile Windows users think.")
	end
	while path:sub(path:len()) == "/" do
		path = path:sub(1,path:len()-1)
	end
	path = path:lower()
	return path
end

function load_mod(env, path, stages, ...)
	print("Loading "..path)
	if failed[path] then
		error("Already failed earlier")
	end
	failed[path] = true -- pre-fail to avoid infinite loop
	local mdata = loaded[path] or common.json_load(path.."/mod.json") -- use cached version if necessary
	loaded[path] = nil -- remove from loaded list just in case we fail

	-- check for any dependencies
	local deps = mdata.depends
	if deps then
		local i

		-- pre-scan dependencies
		for i=1,#deps do
			if failed[deps[i]] then
				error("Mod failed a dependency before we got to it: "..deps[i])
				return false
			end
		end

		-- load dependencies
		for i=1,#deps do
			load_mod(env, get_mod_name(deps[i]), stages, ...)
			if not loaded[deps[i]] then
				error("Dependency failed: "..deps[i])
				return false
			end
		end
	end

	-- load our scripts
	local i
	local farr = {}
	for i=1,#stages do
		local arr = mdata[stages[i]]
		if arr then
			local j

			-- load files
			for j=1,#arr do
				local fname = path.."/"..arr[j]
				print("- Loading file "..fname)
				local f = loadfile(fname)
				if not f then
					error("Script failed to load: "..fname)
					return false
				end
				farr[#farr+1] = {fname, f}
			end
		end
	end

	-- execute our scripts
	for i=1,#farr do
		-- if they throw an error... good. it can crash.
		local f = farr[i][2]
		setfenv(f, env)
		f(...)
	end

	-- add ourselves to the loaded list and unfail ourselves
	loaded[path] = mdata
	failed[path] = nil
end

function load_mod_list(env, arr, stages, ...)
	local i
	arr = arr or prevmod
	prevmod = arr
	print(#arr)
	for i=1,#arr do
		load_mod(env, get_mod_name(arr[i]), stages, ...)
	end
end


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

-- Wrappers for fetching stuff.

do

return function(sb_list, sb_aux, sb_ctl, name)
	local SG = sb_list[name]

	-- Set up function wrapper
	local function wrapfn(f)
		setfenv(f, SG)
	end

	local s_fetch_start = common.fetch_start
	local s_fetch_poll = common.fetch_poll
	local s_fetch_block = common.fetch_block

	local fetch_last_ftype = nil
	local fetch_last_fname = nil
	function SG.common.fetch_start(ftype, fname)
		local obj = s_fetch_start(ftype, fname)

		if obj ~= true and obj ~= nil then
			if ftype == "lua" and obj ~= nil then
				wrapfn(obj)
			end
		end

		fetch_last_ftype = nil
		fetch_last_fname = nil
		if obj == true then
			fetch_last_ftype = ftype
			fetch_last_fname = fname
		end

		return obj
	end

	function SG.common.fetch_poll()
		local oldmap = common.map_get()
		sb_ctl.gfx_api_prerender()

		local function ff(obj, ...)
			if obj ~= false then
				if fetch_last_ftype == "lua" and obj ~= nil then
					wrapfn(obj)
				end

				fetch_last_ftype = nil
				fetch_last_fname = nil
			end

			sb_ctl.gfx_api_postrender(name)

			return obj, ...
		end

		return ff(s_fetch_poll())
	end

	function SG.common.fetch_block(ftype, fname)
		local fetch_start = common.fetch_start
		local fetch_poll = common.fetch_poll
		common.fetch_start = SG.common.fetch_start
		common.fetch_poll = SG.common.fetch_poll

		--print("BLOCK", ftype, fname)
		local obj = s_fetch_block(ftype, fname)
		if ftype == "lua" and obj ~= nil then
			wrapfn(obj)
		end
		--print("BLOCK END", ftype, fname, obj)

		common.fetch_start = fetch_start
		common.fetch_poll = fetch_poll

		return obj
	end

	function SG.loadstring(...)
		local f = loadstring(...)
		wrapfn(f)
		return f
	end

	function SG.loadfile(...)
		return SG.common.fetch_block("lua", ...)
	end

	function SG.dofile(...)
		return SG.loadfile(...)()
	end

	-- mirrors
	if client then
		SG.client.fetch_block = SG.common.fetch_block
		SG.client.fetch_start = SG.common.fetch_start
		SG.client.fetch_poll = SG.common.fetch_poll
	end

	if server then
		SG.server.fetch_block = SG.common.fetch_block
		SG.server.fetch_start = SG.common.fetch_start
		SG.server.fetch_poll = SG.common.fetch_poll
	end

	-- other things that are basically fetch_block
	function SG.common.bin_load(...) return SG.common.fetch_block("bin", ...) end
	function SG.common.json_load(...) return SG.common.fetch_block("json", ...) end
	function SG.common.wav_load(...) return SG.common.fetch_block("wav", ...) end
	function SG.common.mus_load_it(...) return SG.common.fetch_block("it", ...) end
	function SG.common.model_load_pmf(...) return SG.common.fetch_block("pmf", ...) end
	function SG.common.map_load(fname, fmt)
		if fmt == nil or fmt == "auto" then
			fmt = "map"
		end
		return SG.common.fetch_block(fmt, fname)
	end
	function SG.common.img_load(fname, fmt)
		print("IMG!", fmt, fname)
		local img = SG.common.fetch_block(fmt or "tga", fname)
		print("IMG!", img)
		if not img then return nil, nil, nil end
		return img, common.img_get_dims(img)
	end

	-- more aliases
	if client then
		SG.client.img_load = SG.common.img_load
	end
end

end


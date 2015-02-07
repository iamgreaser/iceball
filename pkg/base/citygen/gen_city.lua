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
DIR_CITYGEN = "pkg/base/citygen/"
DIR_CITYGEN_BUILDINGS = DIR_CITYGEN.."buildings/"
dofile(DIR_CITYGEN.."utils/citygen_utils.lua")
--OVERRIDE ME! I am called 1st.
function gen_terrain(mx, my, mz) end --mx = mapx = map "width"

--OVERRIDE ME! I am called 2nd.
function load_buildings() end

--OVERRIDE ME! I am called 3rd.
function create_city_grid() end

--OVERRIDE ME! I am called 4th and last.
function manufacture_buildings() end

do
	local ret
	local loose, user_toggles, user_settings
	loose, user_toggles, user_settings = ...
	local mx,my,mz,mode
	mx = user_settings["mx"] or 512
	my = user_settings["my"] or 96
	mz = user_settings["mz"] or 512
	mode = user_settings["mode"] or "default"
	
	modes_config = common.json_load(DIR_CITYGEN.."modes.json")
	
	local i = 1
	repeat
		dofile(DIR_CITYGEN..modes_config[mode][i]) --so you caught a "nil" error here? setting at least one file is mandatory!
		i = i + 1
	until modes_config[mode][i] == nil
	
	--this isn't supposed to be overridden --also the reason why it's hidden away here
	function execute_map_gen(mx, my, mz, mode)
		ret = common.map_new(mx, my, mz)
		common.map_set(ret)
		print("Generating terrain")
		gen_terrain(mx, my, mz)
		print("Loading buildings")
		load_buildings()
		--print("Loading prefabs")
		--load_kv6()
		print("Generating the city outline")
		create_city_grid()
		print("Making buildings")
		--map_cache_start() -- please handle map caching yourselves!
		manufacture_buildings()
		
		--collectgarbage() --waiting for this to be implemented
		print("gen finished")		
		return ret, "citygen_"..mode.."("..mx..","..mz..","..my..")"		
	end
	
	return execute_map_gen(mx, my, mz, mode)

end

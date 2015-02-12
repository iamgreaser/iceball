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

--TODO: implement building template interface
--build() - given an area to build in, build inside it - possibly code to protect parts of map not accessible? hm, maybe something like map_secure_build() which error()s when attempt to change blocks outside
--special_build() - optional overridable function for exchangeable nested builds. I see this used for interiors, where you can have extra building types for the interior (like, add a garage, change styling etc.) without having to copy the outside building code
--load_prefabs() - load prefabs (kv6, pmf, etc.), gets called first
--kill_and_dispose() - if the map generation is dirty and stupid, you should be able to call this to clean up the building's area

function new_building(settings)
	local this = {} this.this = this

	this.type = "building template - I'm not supposed to be built! change this"
	this.x, this.y, this.z, this.width, this.length, this.height = settings.x, settings.y, settings.z, settings.width, settings.length, settings.height
	
	function this.build()
		this.build_at(this.x, this.y, this.z, this.width, this.length, this.height)
	end
	
	function this.build_at(x, y, z, width, length, height)
	end
	
	return this
end


-- 1CTF: Half the flags, half the fun! ...actually it's still pretty fun
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

dofile("pkg/base/mode/mode_ctf.lua")

function mode_create_server()
	TEAM_SCORE_LIMIT = TEAM_SCORE_LIMIT_CTF

	miscents = {}
	miscents[#miscents+1] = new_tent({team = 0, iid = #miscents+1})
	miscents[#miscents+1] = new_tent({team = 1, iid = #miscents+1})
	miscents[#miscents+1] = new_intel({team = nil, iid = #miscents+1})

	do
		local i
		for i=1,#miscents do
			miscents[i].spawn()
		end
	end
end

function mode_create_client()
	TEAM_SCORE_LIMIT = TEAM_SCORE_LIMIT_CTF

	miscents = {}
	miscents[#miscents+1] = new_tent({team = 0, iid = #miscents+1})
	miscents[#miscents+1] = new_tent({team = 1, iid = #miscents+1})
	miscents[#miscents+1] = new_intel({team = nil, iid = #miscents+1})
end


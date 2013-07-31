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

-- boo ~Dany0

DEUCE_NAME = server_config.deucename or "Deuce"

function name_generate()
	local i
	local max_id = 0
	
	for i=1,players.max do
		if players[i] ~= nil then
			local deuceid = tonumber(string.sub(players[i].name or "", string.len(DEUCE_NAME) + 1) or 0)
			if deuceid == max_id then
				max_id = deuceid + 1
			end
		end
	end
	return DEUCE_NAME..max_id
end



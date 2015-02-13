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

-- Simple test of the sandbox API.

local super = new_player
function new_player(...)
	local this = super(...)

	local s_create_hud = this.create_hud
	local function f_create_hud(...)
		local ret = s_create_hud(...)
		
		local s_chat_on_return = this.typing_text.on_return
		function this.typing_text.on_return(...)
			if this.typing_text.text == "/snake" then
				local snake = sandbox.new("snake", "pkg/br/snake/main_client.lua")
				sandbox.gfx_select(snake)
				this.typing_text.text = ""
			end

			return s_chat_on_return(...)
		end
	end

	function this.create_hud(...)
		local ret = s_create_hud(...)
		f_create_hud(...)
		return ret
	end

	if this.scene then
		f_create_hud(...)
	end

	return this
end


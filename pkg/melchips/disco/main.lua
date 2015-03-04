--[[
    This file is derived from a part of Ice Lua Components.

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

--[[
	This server plugin adds the command /disco based on pyspades original script by mat^2
	To load on your server, add this script to svsave/pub/mods.json
]]

if server then
	local disco_enabled = false

	local fog_original_color = {0, 0, 0}

	local disco_color_index = 1

	local disco_colors_total = 6

	local disco_colors = {
		{235, 64, 0},
		{128, 232, 121},
		{220, 223, 12},
		{43, 72, 228},
		{216, 94, 231},
		{255, 255, 255}
	}

	-- in seconds
	local disco_delay_between_color_change = 0.3

	local disco_last_color_change_time = 0

	-- register disco command
	command_register({
		command = "disco",
		permission = "resetgame",
		usage = "/disco",
		func = function(plr, plrid, neth, prms, msg)
			local r, g, b

			-- disable disco mode
			if disco_enabled then
				-- reset fog color
				fog_set(fog_original_color[1], fog_original_color[2], fog_original_color[3])
				disco_enabled = false
				--command_msg("text", neth, "The party has been stopped.")
				net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFFDDDDFF, "The party has been stopped."))
			-- enable disco mode
			else
				-- save current fog color
				r, g, b = fog_get()
				fog_original_color[1] = r
				fog_original_color[2] = g
				fog_original_color[3] = b
				disco_enabled = true
				--command_msg("success", neth, "DISCO PARTY MODE ENABLED!")
				net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF66FF66, "DISCO PARTY MODE ENABLED!"))
				disco_last_color_change_time = 0
			end
		end
	})

	-- save current server tick
	local disco_oldtick = server.hook_tick

	-- custom server tick
	function disco_tick(sec_current, sec_delta)
		-- call original server tick
		local ret = disco_oldtick(sec_current, sec_delta)

		-- change fog color if enabled
		if disco_enabled then
			if sec_current - disco_last_color_change_time > disco_delay_between_color_change then
				disco_last_color_change_time = sec_current
				-- set fog to current color
				fog_set(disco_colors[disco_color_index][1],disco_colors[disco_color_index][2],disco_colors[disco_color_index][3])

				-- set index to next color
				disco_color_index = disco_color_index + 1
				if (disco_color_index > disco_colors_total) then
					disco_color_index = 1
				end
			end
		end

		return ret
	end

	-- replace server tick with custom one
	server.hook_tick = disco_tick
end

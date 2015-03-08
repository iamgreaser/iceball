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
	Add the 'disco' permission to users allowed to use the command
]]

--[[ CUSTOM SETTINGS START ]] --
local DISCO_DIR="pkg/melchips/disco/"

local disco_music = common.mus_load_it(DISCO_DIR.."7thdiscoheaven.it")

-- set the music bpm (two color changes per beat)
local disco_music_bpm = 125

local disco_colors_total = 6

local disco_colors = {
	{235, 64, 0},
	{128, 232, 121},
	{220, 223, 12},
	{43, 72, 228},
	{216, 94, 231},
	{255, 255, 255}
}

local disco_starting_message = "DISCO PARTY MODE ENABLED !"
local disco_stopping_message = "The party has been stopped."

--[[ CUSTOM SETTINGS END ]] --

local PKT_TOGGLE_DISCO = network.sys_alloc_packet()

local DISCO_DISABLED = 0
local DISCO_ENABLED = 1

local disco_status = DISCO_DISABLED

-- server code
if server then
	local fog_original_color = {0, 0, 0}

	-- register disco command
	command_register({
		command = "disco",
		permission = "disco",
		usage = "/disco",
		func = function(plr, plrid, neth, prms, msg)
			local r, g, b

			-- disable disco mode
			if disco_status == DISCO_ENABLED then
				disco_status = DISCO_DISABLED
				net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFFDDDDFF, disco_stopping_message))
				net_broadcast(nil, common.net_pack("BBB", PKT_TOGGLE_DISCO, DISCO_DISABLED))
				-- reset fog color
				fog_set(fog_original_color[1], fog_original_color[2], fog_original_color[3])
			-- enable disco mode
			elseif disco_status == DISCO_DISABLED then
				-- save current fog color
				r, g, b = fog_get()
				fog_original_color[1] = r
				fog_original_color[2] = g
				fog_original_color[3] = b
				disco_status = DISCO_ENABLED
				net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF66FF66, disco_starting_message))
				net_broadcast(nil, common.net_pack("BBB", PKT_TOGGLE_DISCO, DISCO_ENABLED))
			end
		end
	})

	-- if a new player connects, send the current disco status
	local s_pkt_plr_offer = network.sys_tab_handlers[PKT_PLR_OFFER].f
	network.sys_tab_handlers[PKT_PLR_OFFER].f = function (neth, cli, plr, sec_current, tidx, wpn, name, pkt, ...)
		net_send(neth, common.net_pack("BBB", PKT_TOGGLE_DISCO, disco_status))
		return s_pkt_plr_offer(neth, cli, plr, sec_current, tidx, wpn, name, pkt, ...)
	end
end

-- client code
if client then

	local disco_color_index = 1

	local original_fog_color = {0, 0, 0};
	local original_fog_distance = 0;

	-- in seconds
	local disco_delay_between_color_change = 1/(disco_music_bpm / 60) / 2

	local disco_last_color_change_time = 0

	network.sys_handle_s2c(PKT_TOGGLE_DISCO, "BB", function (neth, cli, plr, sec_current, state, pkt)
		if state == DISCO_DISABLED then
			if disco_status == DISCO_ENABLED then
				client.mus_stop()
				disco_status = DISCO_DISABLED
				client.map_fog_set(original_fog_color[1], original_fog_color[2], original_fog_color[3], original_fog_distance)
			end
		elseif state == DISCO_ENABLED then
			if disco_status == DISCO_DISABLED then
				local xr, xg, xb, fdist = client.map_fog_get()
				original_fog_color[1] = xr;
				original_fog_color[2] = xg;
				original_fog_color[3] = xb;
				original_fog_distance = fdist;

				disco_status = DISCO_ENABLED
				disco_last_color_change_time = sec_current
				client.mus_play(disco_music)
			end
		end
	end)

	
	local disco_oldtick = client.hook_tick
	function disco_tick(sec_current, sec_delta)
	
		client.hook_tick = disco_oldtick
		local ret = client.hook_tick(sec_current, sec_delta)
		disco_oldtick = client.hook_tick
		client.hook_tick = disco_oldtick and disco_tick

		-- change fog color if enabled
		if disco_status == DISCO_ENABLED then
			if sec_current - disco_last_color_change_time > disco_delay_between_color_change then
				disco_last_color_change_time = sec_current
				-- set fog to current color
				client.map_fog_set(disco_colors[disco_color_index][1],disco_colors[disco_color_index][2],disco_colors[disco_color_index][3],original_fog_distance)

				-- set index to next color
				disco_color_index = disco_color_index + 1
				if (disco_color_index > disco_colors_total) then
					disco_color_index = 1
				end
			end
		end


		return ret
	end
	
	client.hook_tick = disco_tick
end

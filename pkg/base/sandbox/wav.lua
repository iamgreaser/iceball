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

-- Wrappers for the audio system.

do

return function (sb_list, sb_aux, sb_ctl, name)
	local SG = sb_list[name]

	sb_aux[name].mus_ref = nil
	sb_aux[name].mus_order = 0
	sb_aux[name].mus_row = 0
	sb_aux[name].mus_vol = 1.0
	sb_aux[name].wav_enabled = true --(name == "root")
	sb_aux[name].wav_cube_size = 1.0

	if client then
		function SG.client.wav_cube_size(size)
			sb_aux[name].wav_cube_size = size
			if sb_aux[name].wav_enabled then
				return client.wav_cube_size(size)
			end
		end

		function SG.client.wav_play_global(...)
			if sb_aux[name].wav_enabled then
				return client.wav_play_global(...)
			end

			return nil
		end

		function SG.client.wav_play_local(...)
			if sb_aux[name].wav_enabled then
				return client.wav_play_local(...)
			end

			return nil
		end

		function SG.client.mus_play(mus, order, row)
			order = order or 0
			row = row or 0

			sb_aux[name].mus_ref = mus
			sb_aux[name].mus_order = order
			sb_aux[name].mus_row = row
			if sb_aux[name].wav_enabled then
				return client.mus_play(mus, order, row)
			end
		end

		function SG.client.mus_stop()
			sb_aux[name].mus_ref = nil
			sb_aux[name].mus_order = 0
			sb_aux[name].mus_row = 0
			if sb_aux[name].wav_enabled then
				return client.mus_stop()
			end
		end

		function SG.client.mus_vol_set(vol)
			sb_aux[name].mus_vol = vol
			if sb_aux[name].wav_enabled then
				return client.mus_vol_set(vol)
			end
		end
	end
end

end


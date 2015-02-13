
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

-- Wrappers for graphical stuff. Also handles input.

do

local sb_list, sb_aux, sb_ctl = ...
sb_ctl.gfx_select = "root"
sb_ctl.gfx_map_stack = {idx = 0}

-- Select sandbox to use for graphics and input.
function sandbox.gfx_select(name)
	if not sb_list[name] then
		error("invalid VM \""..tostring(name).."\" for gfx_select")
	end

	sb_ctl.gfx_select = name

	client.mouse_lock_set(sb_aux[name].gfx_mouse_grab)
	client.mouse_visible_set(sb_aux[name].gfx_mouse_vis)
	local l = sb_aux[name].gfx_map_fog
	client.map_fog_set(l[1], l[2], l[3], l[4])
end

-- INTERNAL API: Begin / end of hooks
function sb_ctl.gfx_api_push(name)
	local map = nil
	if sb_aux[name] then
		map = sb_aux[name].gfx_map
	end

	sb_ctl.gfx_map_stack.idx = sb_ctl.gfx_map_stack.idx + 1
	sb_ctl.gfx_map_stack[sb_ctl.gfx_map_stack.idx] = {name, common.map_get()}
	common.map_set(map)
end
function sb_ctl.gfx_api_pop()
	local name = sb_ctl.gfx_map_stack[sb_ctl.gfx_map_stack.idx][1]
	if sb_aux[name] then
		sb_aux[name].gfx_map = common.map_get()
	end
	common.map_set(sb_ctl.gfx_map_stack[sb_ctl.gfx_map_stack.idx][2])
	sb_ctl.gfx_map_stack[sb_ctl.gfx_map_stack.idx] = nil
	sb_ctl.gfx_map_stack.idx = sb_ctl.gfx_map_stack.idx - 1
end
function sb_ctl.gfx_api_prerender()
	local map = nil
	if sb_aux[sb_ctl.gfx_select] then
		map = sb_aux[sb_ctl.gfx_select].gfx_map
	end
	common.map_set(map)
end
function sb_ctl.gfx_api_postrender(name)
	local map = nil
	if sb_aux[name] then
		map = sb_aux[name].gfx_map
	end
	common.map_set(map)
end

function sb_ctl.gfx_kill(name)
	if name == sb_ctl.gfx_select then
		-- TODO: properly return to parent
		if name ~= "root" then
			sandbox.gfx_select("root")
		end
	end
end

return function(sb_list, sb_aux, sb_ctl, name)
	local SG = sb_list[name]

	sb_aux[name].gfx_mouse_vis = true
	sb_aux[name].gfx_mouse_grab = false
	sb_aux[name].gfx_map_fog = {208, 224, 255, 60.0}
	sb_aux[name].gfx_map = map

	if client then
		local s_img_blit = SG.client.img_blit
		function SG.client.img_blit(...)
			if sb_ctl.gfx_select == name then
				return s_img_blit(...)
			end
		end

		local s_va_render_global = SG.client.va_render_global
		function SG.client.va_render_global(...)
			if sb_ctl.gfx_select == name then
				return s_va_render_global(...)
			end
		end

		local s_va_render_local = SG.client.va_render_local
		function SG.client.va_render_local(...)
			if sb_ctl.gfx_select == name then
				return s_va_render_local(...)
			end
		end

		local s_model_render_bone_global = SG.client.model_render_bone_global
		function SG.client.model_render_bone_global(...)
			if sb_ctl.gfx_select == name then
				return s_model_render_bone_global(...)
			end
		end

		local s_model_render_bone_local = SG.client.model_render_bone_local
		function SG.client.model_render_bone_local(...)
			if sb_ctl.gfx_select == name then
				return s_model_render_bone_local(...)
			end
		end

		local s_mouse_lock_set = SG.client.mouse_lock_set
		function SG.client.mouse_lock_set(state)
			sb_aux[name].gfx_mouse_grab = state
			if sb_ctl.gfx_select == name then
				return s_mouse_lock_set(state)
			end
		end

		local s_mouse_visible_set = SG.client.mouse_visible_set
		function SG.client.mouse_visible_set(state)
			sb_aux[name].gfx_mouse_vis = state
			if sb_ctl.gfx_select == name then
				return s_mouse_visible_set(state)
			end
		end

		local s_map_set = SG.common.map_set
		function SG.common.map_set(map)
			print("map", name, map)
			sb_aux[name].gfx_map = map
			return s_map_set(map)
		end
		SG.client.map_set = SG.common.map_set

		local s_map_fog_set = SG.client.map_fog_set
		function SG.client.map_fog_set(r, g, b, dist)
			sb_aux[name].gfx_map_fog = {r, g, b, dist}
			if sb_ctl.gfx_select == name then
				return s_map_fog_set(r, g, b, dist)
			end
		end

		local s_map_fog_get = SG.client.map_fog_get
		function SG.client.map_fog_get()
			if sb_ctl.gfx_select == name then
				return s_map_fog_get()
			else
				local l = sb_aux[name].gfx_map_fog
				return l[1], l[2], l[3], l[4]
			end
		end
	end

end

end


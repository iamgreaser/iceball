-- CTF: Accept no substitutes.
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

dofile("pkg/base/mode/obj_tent.lua")
dofile("pkg/base/mode/obj_intel.lua")

function mode_reset()
	local i
	for i=1,players.max do
		if players[i] ~= nil then
			players[i].spawn()
			net_broadcast(nil, common.net_pack("BBfffBB",
				PKT_PLR_SPAWN, i,
				players[i].x, players[i].y, players[i].z,
				players[i].angy*128/math.pi, players[i].angx*256/math.pi))
		end
	end
	for i=1,#miscents do
		miscents[i].spawn()
		local x,y,z
		x,y,z = miscents[i].get_pos()
		miscents[i].player = nil
		net_broadcast(nil, common.net_pack("BHhhhB", PKT_ITEM_POS,
			i, x,y,z, miscents[i].get_flags() ))
		net_broadcast(nil, common.net_pack("BHB", PKT_ITEM_CARRIER, i, 0))
	end
	for i=0,teams.max do
		if teams[i] ~= nil then
			teams[i].score = 0
			net_broadcast(nil, common.net_pack("Bbh", PKT_TEAM_SCORE, i, teams[i].score))
		end
	end
end

function mode_create_server()
	TEAM_SCORE_LIMIT = TEAM_SCORE_LIMIT_CTF

	miscents = {}
	miscents[#miscents+1] = new_intel({team = 0, iid = #miscents+1})
	miscents[#miscents+1] = new_tent({team = 0, iid = #miscents+1})
	miscents[#miscents+1] = new_intel({team = 1, iid = #miscents+1})
	miscents[#miscents+1] = new_tent({team = 1, iid = #miscents+1})

	do
		local i
		for i=1,4 do
			miscents[i].spawn()
		end
	end
end

function mode_create_client()
	TEAM_SCORE_LIMIT = TEAM_SCORE_LIMIT_CTF

	miscents = {}
	miscents[#miscents+1] = new_intel({team = 0, iid = #miscents+1})
	miscents[#miscents+1] = new_tent({team = 0, iid = #miscents+1})
	miscents[#miscents+1] = new_intel({team = 1, iid = #miscents+1})
	miscents[#miscents+1] = new_tent({team = 1, iid = #miscents+1})
end

function mode_relay_items(plr, neth)
	for i=1,#miscents do
		local f,x,y,z
		x,y,z = miscents[i].get_pos()
		f = miscents[i].get_flags()
		net_send(neth, common.net_pack("BHhhhB",
			PKT_ITEM_POS, i, x, y, z, f))
		local plr = miscents[i].player
		if plr then
			net_send(neth, common.net_pack("BHB",
				PKT_ITEM_CARRIER, i, plr.pid))
		end
	end
end

local s_new_player = new_player
function new_player(...)
	local this = s_new_player(...)

	local s_prespawn = this.prespawn
	function this.prespawn()
		local ret = s_prespawn()

		this.has_intel = nil

		return ret
	end

	local s_on_disconnect = this.on_disconnect
	function this.on_disconnect(...)
		local ret = s_on_disconnect(...)
		plr.intel_drop()
		return ret
	end

	function this.intel_drop()
		if server then
			local intel = this.has_intel
			--print("dropped", intel)
			if not intel then
				return
			end
			
			intel.intel_drop()
			this.has_intel = nil
			
			local s = "* "..this.name.." has dropped the "..intel.get_name().."."
			net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF800000, s))
		end
	end

	local s_create_hud = this.create_hud
	function this.create_hud(...)
		local ret = s_create_hud(...)
		local scene = this.scene

		local bone_intel = scene.bone{model=mdl_intel, bone=mdl_intel_bone,
			x=w*0.1,y=h*0.5,scale=0.18,visible=false}
		scene.root.add_child(bone_intel)
		
		local function bone_rotate(dT)
			local k, bone
			for k,bone in pairs({bone_intel}) do
				bone.rot_y = bone.rot_y + dT * 120 * 0.01
			end
			bone_intel.visible = (this.has_intel ~= nil)
			if this.has_intel then
				bone_intel.model = this.has_intel.mdl_intel
			end
		end
		this.tools_align.add_listener(GE_DELTA_TIME, bone_rotate)
		
		bone_rotate(0)

		return ret
	end

	function this.intel_capture(sec_current)
		if server then
			local intel = this.has_intel
			if not intel then
				return
			end
			
			intel.intel_capture(sec_current)
			this.has_intel = nil
			
			local s = "* "..this.name.." has captured the "..intel.get_name().."."
			net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF800000, s))
			net_broadcast_team(this.team, common.net_pack("B", PKT_MAP_RCIRC))
		end
	end

	local s_render = this.render
	function this.render(sec_current, sec_delta, ...)
		local ret = s_render(sec_current, sec_delta, ...)

		if this.has_intel then
			this.has_intel.render_backpack()
		end
	end

	local s_on_death = this.on_death
	function this.on_death(kcol, kmsg, ...)
		local ret = s_on_death(kcol, kmsg, ...)

		if server then
			this.intel_drop()
		end

		return ret
	end

	function this.intel_pickup(intel)
		if not this.has_permission("intel") then return false end

		if this.mode ~= PLM_NORMAL or this.has_intel or intel.team == this.team then
			return false
		end
		
		if server then
			local x,y,z,f
			x,y,z = intel.get_pos()
			intel.visible = false
			f = intel.get_flags()
			net_broadcast(nil, common.net_pack("BHhhhB", PKT_ITEM_POS, intel.iid, x,y,z,f))
			net_broadcast(nil, common.net_pack("BHB", PKT_ITEM_CARRIER, intel.iid, this.pid))
			local s = "* "..this.name.." has picked up the "..intel.get_name().."."
			net_broadcast(nil, common.net_pack("BIz", PKT_CHAT_ADD_TEXT, 0xFF800000, s))
			this.has_intel = intel
		end

		return true
	end

	local s_item_add = this.item_add
	function this.item_add(item, ...)
		local ret = s_item_add(item, ...)
		if item.type == "intel" then
			this.has_intel = item
		end
		return ret
	end

	local s_item_remove = this.item_remove
	function this.item_remove(item, ...)
		local ret = s_item_remove(item, ...)
		if this.has_intel == item then
			this.has_intel = nil
		end
		return ret
	end

	return this
end


local s_new_tent = new_tent
function new_tent(...)
	local this = s_new_tent(...)

	local s_player_in_range = this.player_in_range
	function this.player_in_range(plr, sec_current, ...)
		local ret = s_player_in_range(plr, ...)

		if plr.has_intel and plr.team == this.team then
			plr.intel_capture(sec_current)
		end

		return ret
	end

	return this
end


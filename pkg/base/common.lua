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

-- base dir stuff
DIR_PKG_ROOT = DIR_PKG_ROOT or "pkg/base"
DIR_PKG_LIB = DIR_PKG_LIB or DIR_PKG_ROOT
DIR_PKG_PMF = DIR_PKG_PMF or DIR_PKG_ROOT.."/pmf"
DIR_PKG_GFX = DIR_PKG_GFX or DIR_PKG_ROOT.."/gfx"
DIR_PKG_WAV = DIR_PKG_WAV or DIR_PKG_ROOT.."/wav"
DIR_PKG_MAP = DIR_PKG_MAP or "pkg/maps"

MAP_DEFAULT = MAP_DEFAULT or DIR_PKG_MAP.."/mesa.vxl"

LIB_LIST = LIB_LIST or {
	DIR_PKG_LIB.."/lib_collect.lua",
	DIR_PKG_LIB.."/lib_gui.lua",
	DIR_PKG_LIB.."/lib_map.lua",
	DIR_PKG_LIB.."/lib_namegen.lua",
	DIR_PKG_LIB.."/lib_pmf.lua",
	DIR_PKG_LIB.."/lib_sdlkey.lua",
	DIR_PKG_LIB.."/lib_vector.lua",
	
	DIR_PKG_LIB.."/obj_player.lua",
	DIR_PKG_LIB.."/obj_intent.lua",
}

-- load libs
local i
for i=1,#LIB_LIST do
	local asdf_qwerty = i
	i = nil
	dofile(LIB_LIST[asdf_qwerty])
	i = asdf_qwerty
end
i = nil


-- mode stuff
MODE_DEBUG_SHOWBOXES = false
MODE_CHEAT_FLY = false

MODE_AUTOCLIMB = true
MODE_AIRJUMP = false
MODE_SOFTCROUCH = true
MODE_MINIMAP_RCIRC = false

MODE_TILT_SLOWDOWN = false -- TODO!
MODE_TILT_DOWN_NOCLIMB = false -- TODO!

MODE_DELAY_SPADE_DIG = 1.0
MODE_DELAY_SPADE_HIT = 0.25
MODE_DELAY_BLOCK_BUILD = 0.5
MODE_DELAY_TOOL_CHANGE = 0.4

-- tools
TOOL_SPADE = 0
TOOL_BLOCK = 1
TOOL_GUN = 2
TOOL_NADE = 3

-- weapons
WPN_RIFLE = 1

weapon_models = {}

weapons = {
	[WPN_RIFLE] = function (plr)
		local this = {} this.this = this
		
		this.cfg = {
			dmg = {
				head = 100,
				body = 49,
				legs = 33,
			},
			
			ammo_clip = 10,
			ammo_reserve = 50,
			time_fire = 1/2,
			time_reload = 2.5,
			
			recoil_x = 0.0001,
			recoil_y = -0.05,
			
			name = "Rifle"
		}
		
		function this.restock()
			this.ammo_clip = this.cfg.ammo_clip
			this.ammo_reserve = this.cfg.ammo_reserve
		end
		
		function this.reset()
			this.t_fire = nil
			this.t_reload = nil
			this.reloading = false
			this.restock()
		end
		
		this.reset()
		
		local function prv_fire(sec_current)
			local sya = math.sin(plr.angy)
			local cya = math.cos(plr.angy)
			local sxa = math.sin(plr.angx)
			local cxa = math.cos(plr.angx)
			local fwx,fwy,fwz
			fwx,fwy,fwz = sya*cxa, sxa, cya*cxa
			
			-- perform a trace
			local d,cx1,cy1,cz1,cx2,cy2,cz2
			d,cx1,cy1,cz1,cx2,cy2,cz2
			= trace_map_ray_dist(plr.x,plr.y,plr.z, fwx,fwy,fwz, 127.5)
			
			if d then
				-- TODO: block health rather than instant block removal
				map_block_break(cx2,cy2,cz2)
			else
				d = 127.5
			end
			
			-- TODO: kill people
			-- TODO: fire a tracer
			
			-- apply recoil
			-- attempting to emulate classic behaviour provided i have it right
			plr.recoil(sec_current, this.cfg.recoil_y, this.cfg.recoil_x)
		end
		
		function this.reload()
			if this.ammo_clip ~= this.cfg.ammo_clip then
			if this.ammo_reserve ~= 0 then
			if not this.reloading then
				this.reloading = true
				plr.zooming = false
				this.t_reload = nil
			end end end
		end
		
		function this.click(button, state)
			if button == 1 then
				-- LMB
				if this.ammo_clip > 0 then
					this.firing = state
				else
					this.firing = false
					-- TODO: play sound
				end
			elseif button == 3 then
				-- RMB
				if state and not this.reloading then
					plr.zooming = not plr.zooming
				end
			end
		end
		
		function this.get_model()
			return weapon_models[WPN_RIFLE]
		end
		
		function this.draw(px, py, pz, ya, xa, ya2)
			client.model_render_bone_global(this.get_model(), 0,
				px, py, pz, ya, xa, ya2, 3)
		end
		
		function this.tick(sec_current, sec_delta)
			if this.reloading then
				if not this.t_reload then
					this.t_reload = sec_current + this.cfg.time_reload
				end
				
				if sec_current >= this.t_reload then
					local adelta = this.cfg.ammo_clip - this.ammo_clip
					if adelta > this.ammo_reserve then
						adelta = this.ammo_reserve
					end
					this.ammo_reserve = this.ammo_reserve - adelta
					this.ammo_clip = this.ammo_clip + adelta
					this.t_reload = nil
					this.reloading = false
					plr.arm_rest_right = 0
				else
					local tremain = this.t_reload - sec_current
					local telapsed = this.cfg.time_reload - tremain
					local roffs = math.min(tremain,telapsed)
					roffs = math.min(roffs,0.3)/0.3
					
					plr.arm_rest_right = roffs
				end
			elseif this.firing and this.ammo_clip == 0 then
				this.firing = false
			elseif this.firing and ((not this.t_fire) or sec_current >= this.t_fire) then
				prv_fire(sec_current)
				
				this.t_fire = this.t_fire or sec_current
				this.t_fire = this.t_fire + this.cfg.time_fire
				if this.t_fire < sec_current then
					this.t_fire = sec_current
				end
				
				this.ammo_clip = this.ammo_clip - 1
				
				-- TODO: poll: do we want to require a new click per shot?
			end
			
			if this.t_fire and this.t_fire < sec_current then
				this.t_fire = nil
			end
		end
		
		return this
	end,
}

weapons_enabled = {}
weapons_enabled[WPN_RIFLE] = true

-- teams
teams = {
	[0] = {
		name = "Blue Master Race",
		color_mdl = {16,32,128},
		color_chat = {0,0,255},
	},
	[1] = {
		name = "Green Master Race",
		color_mdl = {16,128,32},
		color_chat = {0,192,0},
	},
}

cpalette_base = {
	0x7F,0x7F,0x7F,
	0xFF,0x00,0x00,
	0xFF,0x7F,0x00,
	0xFF,0xFF,0x00,
	0x00,0xFF,0x00,
	0x00,0xFF,0xFF,
	0x00,0x00,0xFF,
	0xFF,0x00,0xFF,
}

cpalette = {}
do
	local i,j
	for i=0,7 do
		local r,g,b
		r = cpalette_base[i*3+1]
		g = cpalette_base[i*3+2]
		b = cpalette_base[i*3+3]
		for j=0,3 do
			local cr = math.floor((r*j)/3)
			local cg = math.floor((g*j)/3)
			local cb = math.floor((b*j)/3)
			cpalette[#cpalette+1] = {cr,cg,cb}
		end
		for j=1,4 do
			local cr = r + math.floor(((255-r)*j)/4)
			local cg = g + math.floor(((255-g)*j)/4)
			local cb = b + math.floor(((255-b)*j)/4)
			cpalette[#cpalette+1] = {cr,cg,cb}
		end
	end
end

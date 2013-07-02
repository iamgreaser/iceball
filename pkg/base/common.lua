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

print("base dir:",common.base_dir)

dofile("pkg/base/version.lua")
dofile("pkg/base/network.lua")

MAP_DEFAULT = MAP_DEFAULT or DIR_PKG_MAP.."/mesa.vxl"

LIB_LIST = LIB_LIST or {
	DIR_PKG_LIB.."/icegui/widgets.lua",

	DIR_PKG_LIB.."/lib_bits.lua",
	DIR_PKG_LIB.."/lib_collect.lua",
	DIR_PKG_LIB.."/lib_gui.lua",
	DIR_PKG_LIB.."/lib_map.lua",
	DIR_PKG_LIB.."/lib_namegen.lua",
	DIR_PKG_LIB.."/lib_pmf.lua",
	DIR_PKG_LIB.."/lib_sdlkey.lua",
	DIR_PKG_LIB.."/lib_util.lua",
	DIR_PKG_LIB.."/lib_vector.lua",
	
	DIR_PKG_LIB.."/obj_player.lua",
	DIR_PKG_LIB.."/obj_nade.lua",
	DIR_PKG_LIB.."/obj_particle.lua",
	((server and GAME_MODE) or "*GAMEMODE"),
}

-- load libs
local i
for i=1,#LIB_LIST do
	print(LIB_LIST[i])
	local asdf_qwerty = i
	i = nil

	-- a quick workaround.
	-- seems the anal-retentive pathname security bug wasn't QUITE fixed.
	common.fetch_block("lua", LIB_LIST[asdf_qwerty])()
	i = asdf_qwerty
end
i = nil

-- mode stuff
MODE_DEBUG_SHOWBOXES = false
MODE_DEBUG_VPLTEST = false
MODE_CHEAT_FLY = false

MODE_PLAYERS_MAX = 64

MODE_MAX_FOG = 127.5
MODE_DEFAULT_FOG = 60
-- v This extends the fog distance a bit for gl users, to match the softgm renderer at the screen centre.
MODE_FOG_GL_EXTEND = true 

MODE_AUTOCLIMB = true
MODE_AIRJUMP = false
MODE_SOFTCROUCH = true

MODE_JUMP_SPEED = 7.0
MODE_GRAVITY = 9.81

MODE_PSPEED_NORMAL = 7.0
MODE_PSPEED_FLYMODE = 20.0
MODE_PSPEED_CHANGE = 5.0
MODE_PSPEED_AIRSLOW = 0.3
MODE_PSPEED_AIRSLOW_CHANGE = 0.3
MODE_PSPEED_WATER = 0.6
MODE_PSPEED_CROUCH = 0.5
MODE_PSPEED_SNEAK = 0.5
MODE_PSPEED_SPADE = 1.25

MODE_NADE_SPEED = 30.0
MODE_NADE_STEP = 0.1
MODE_NADE_FUSE = 3.0
MODE_NADE_ADAMP = 0.5
MODE_NADE_BDAMP = 1.0
MODE_NADE_RANGE = 8.0
MODE_NADE_DAMAGE = 110.0

-- WARNING: EXPERIMENTAL - set to false if your server slows down an awful lot or locks up!
MODE_NADE_VPL_ENABLE = true
MODE_NADE_VPL_MAX_COUNT = 300 -- O(n*m) stuff, n == number of players, m == THIS
MODE_NADE_VPL_MAX_TRIES = 1000
MODE_NADE_VPL_MAX_RANGE = 30.0
MODE_NADE_VPL_DIRECT_STRENGTH = 1.0
MODE_NADE_VPL_DAMAGE_1 = 2000.0

MODE_TEAM_GUNS = false

MODE_MINIMAP_RCIRC = false
MODE_ENABLE_MINIMAP = true
MODE_MAP_TRACERS = false -- TODO!

MODE_TILT_SLOWDOWN = false -- TODO!
MODE_TILT_DOWN_NOCLIMB = false -- TODO!

MODE_DRUNKCAM_VELOCITY = false -- keep this off unless you want to throw up
MODE_DRUNKCAM_LOCALTURN = true -- this is the one you're looking for.
MODE_DRUNKCAM_CORRECTSPEED = 10.0

MODE_DELAY_SPADE_DIG = 1.0
MODE_DELAY_SPADE_HIT = 0.25
MODE_DELAY_BLOCK_BUILD = 0.5
MODE_DELAY_TOOL_CHANGE = 0.2
MODE_DELAY_NADE_THROW = 0.5

MODE_BLOCK_HEALTH = 100
MODE_BLOCK_DAMAGE_SPADE = 34
MODE_BLOCK_DAMAGE_RIFLE = 34
MODE_BLOCK_REGEN_TIME = 15.0
MODE_BLOCK_PLACE_IN_AIR = false --TODO: make this a server config variable, maybe godmode?
MODE_BLOCK_NO_RED_MARKER = false

MODE_RCIRC_LINGER = 60.0
MODE_RESPAWN_TIME = 8.0

MODE_CHAT_LINGER = 15.0
MODE_CHAT_MAX = 10
MODE_CHAT_STRMAX = 102

-- scoring
SCORE_INTEL = 10
SCORE_KILL = 1
SCORE_TEAMKILL = -1
SCORE_SUICIDE = -1

-- tools
TOOL_SPADE = 0
TOOL_BLOCK = 1
TOOL_GUN = 2
TOOL_EXPL = 3

-- sounds
if client then
	client.wav_cube_size(1)
	wav_rifle_shot = skin_load("wav", "rifle-shot.wav", DIR_PKG_WAV)
	wav_rifle_reload = skin_load("wav", "rifle-reload.wav", DIR_PKG_WAV)
	wav_whoosh = skin_load("wav", "whoosh.wav", DIR_PKG_WAV)
	wav_buld = skin_load("wav", "buld.wav", DIR_PKG_WAV)
	wav_grif = skin_load("wav", "grif.wav", DIR_PKG_WAV)
	wav_hammer = skin_load("wav", "hammer.wav", DIR_PKG_WAV)
	wav_swish = skin_load("wav", "swish.wav", DIR_PKG_WAV)
	wav_jump_up = skin_load("wav", "jump-up.wav", DIR_PKG_WAV)
	wav_jump_down = skin_load("wav", "jump-down.wav", DIR_PKG_WAV)
	wav_pin = skin_load("wav", "pin.wav", DIR_PKG_WAV)
	wav_kapiano = skin_load("wav", "kapiano.wav", DIR_PKG_WAV)
	wav_nade_boom = skin_load("wav", "nade-boom.wav", DIR_PKG_WAV)
	wav_pop = skin_load("wav", "pop.wav", DIR_PKG_WAV)
	wav_steps = {}
	wav_ouches = {}
	wav_splats = {}
	local i
	for i=1,8 do
		wav_steps[i] = skin_load("wav", "step"..i..".wav", DIR_PKG_WAV)
	end
	for i=1,3 do
		wav_ouches[i] = skin_load("wav", "ouch"..i..".wav", DIR_PKG_WAV)
	end
	for i=1,1 do
		wav_splats[i] = skin_load("wav", "splat"..i..".wav", DIR_PKG_WAV)
	end
end

-- weapons
WPN_RIFLE = 1
WPN_LEERIFLE = 2

weapon_models = {}

tpl_gun = loadfile(DIR_PKG_ROOT.."/ent/tpl_gun.lua")()
weapons = {
	[WPN_RIFLE] = loadfile(DIR_PKG_ROOT.."/ent/gun_rifle.lua")(),
	[WPN_LEERIFLE] = loadfile(DIR_PKG_ROOT.."/ent/gun_leerifle.lua")(),
}

tools = {
	[TOOL_SPADE] = loadfile(DIR_PKG_ROOT.."/ent/tool_spade.lua")(),
}

weapons_enabled = {}
weapons_enabled[WPN_RIFLE] = true
weapons_enabled[WPN_LEERIFLE] = true

-- explosives
EXPL_GRENADE = 1

explosive_models = {}

explosives = {
	[EXPL_GRENADE] = loadfile(DIR_PKG_ROOT.."/ent/expl_grenade.lua")(),
}

explosives_enabled = {}
explosives_enabled[EXPL_GRENADE] = true

-- teams
TEAM_SCORE_LIMIT_CTF = 10
TEAM_SCORE_LIMIT_TDM = 1000
TEAM_SCORE_LIMIT = 0 -- your game mode should set this variable

teams = {
	max = 1,
	[0] = {
		name = "Blue Master Race",
		color_mdl = {16,32,128},
		color_chat = {0,0,255},
		score = 0,
	},
	[1] = {
		name = "Green Master Race",
		color_mdl = {16,128,32},
		color_chat = {0,192,0},
		score = 0,
	},
}

function team_players(team)
	local result = {}
	local k
	for k=1,players.max do
		if k then
			local v = players[k]
			if v and v.team == team then
				table.insert(result, v)
			end
		end
	end
	return result
end

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

damage_blk = {}
players = {max = MODE_PLAYERS_MAX, current = 1}
miscents = {}
nades = {head = 1, tail = 0}

function player_ranking(x, y)
	if x.score == y.score then
		if x.kills == y.kills then
			if x.deaths == y.deaths then
				return x.pid < y.pid
			end
			return x.deaths < y.deaths
		end
		return x.kills > y.kills
	end
	return x.score > y.score
end

bhealth = {head = 1, tail = 0, time = 0, map = {}}

function bhealth_clear(x,y,z,repaint)
	local map = bhealth.map
	
	local bh = map[x] and map[x][y] and map[x][y][z]
	
	if bh then
		if repaint then
			map_block_paint(bh.x,bh.y,bh.z,
				bh.c[1],bh.c[2],bh.c[3],bh.c[4])
		end
		
		map[x][y][z] = nil
	end
end

function bhealth_damage(x,y,z,amt,plr)
	local c = map_block_get(x,y,z)
	if c == false then
		map_pillar_aerate(x,z)
		c = map_block_get(x,y,z)
	end
	if not c then return end
	
	local map = bhealth.map
	
	map[x] = map[x] or {}
	map[x][y] = map[x][y] or {}
	map[x][y][z] = map[x][y][z] or {
		c = c,
		damage = 0,
		time = nil,
		qidx = nil,
		x = x, y = y, z = z,
	}
	local blk = map[x][y][z]
	
	blk.time = bhealth.time + MODE_BLOCK_REGEN_TIME
	blk.damage = blk.damage + amt
	
	if server and blk.damage >= MODE_BLOCK_HEALTH then
		if map_block_break(x,y,z) then
			net_broadcast(nil, common.net_pack("BHHH",
				PKT_BLK_RM1, x, y, z))
			if plr.tool == TOOL_SPADE then
				local oblocks = plr.blocks
				oblocks = oblocks + 1
				if oblocks > 100 then
					oblocks = 100
				end
				
				plr.set_blocks(oblocks)
			end
		end
	end
	
	local c = blk.c
	local darkfac = 0.8*MODE_BLOCK_HEALTH
	local light = darkfac/(darkfac + blk.damage)
	
	map_block_paint(x,y,z,c[1],
		math.floor(c[2]*light+0.5),
		math.floor(c[3]*light+0.5),
		math.floor(c[4]*light+0.5))
	
	bhealth.tail = bhealth.tail + 1
	bhealth[bhealth.tail] = {x=x,y=y,z=z,time=blk.time}
	
	blk.qidx = bhealth.tail
	
	if client then
		local block_particlecount = math.random() * 20 + 10
		for i=1,block_particlecount do
			particles_add(new_particle{
				x = x + 0.5,
				y = y + 0.5,
				z = z + 0.5,
				vx = math.random() * 2 - 1,
				vy = math.random(),
				vz = math.random() * 2 - 1,
				r = math.floor(c[2]*light+0.5),
				g = math.floor(c[3]*light+0.5),
				b = math.floor(c[4]*light+0.5),
				lifetime = 0.5 + math.random() * 0.25
			})
		end
	end
end

function bhealth_prune(time)
	--print("prune", bhealth.head, bhealth.tail)
	while bhealth.head <= bhealth.tail do
		local bhi = bhealth[bhealth.head]
		if time < bhi.time then break end
		bhealth[bhealth.head] = nil
		
		--print("bhi", bhi.x,bhi.y,bhi.z,bhi.time,time)
		
		local map = bhealth.map
		local bh = map[bhi.x] and map[bhi.x][bhi.y] and map[bhi.x][bhi.y][bhi.z]
		
		if bh and bh.qidx == bhealth.head then
			map_block_paint(bh.x,bh.y,bh.z,
				bh.c[1],bh.c[2],bh.c[3],bh.c[4])
			bhealth.map[bh.x][bh.y][bh.z] = nil
		end
		
		bhealth.head = bhealth.head + 1
	end
	
	if bhealth.head > bhealth.tail then
		bhealth.head = 1
		bhealth.tail = 0
	end
	
	bhealth.time = time
end


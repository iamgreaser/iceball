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

print("pkg/base/client_start.lua starting")
print(...)

map_fname = nil

-- yeah this really should happen ASAP so we can boot people who suck
dofile("pkg/base/lib_util.lua")

--dofile("pkg/base/serpent.lua") -- serpent.block is a great debugging aid

local loose, user_toggles, user_settings = parse_commandline_options({...})
local user_config_filename = user_settings['user'] or "clsave/pub/user.json"
local controls_config_filename = user_settings['controls'] or "clsave/pub/controls.json"
-- FIXME: we don't expose documentation for valid user settings anywhere

user_config = common.json_load(user_config_filename)
if user_config.kick_on_join then
	error([[
		Once you've set your nickname in clsave/pub/user.json,
		set your nickname in clsave/pub/user.json,
		remember to set your nickname in clsave/pub/user.json,
		look for any connect-*.bat files,
		and set your nickname in clsave/pub/user.json.
		
		Oh, and then after you set your nickname in clsave/pub/user.json,
		you can run said connect-*.bat file,
		having set your nickname in clsave/pub/user.json.]])
end
print("json done!")
print("name:", user_config.name)
print("bio desc:", user_config.bio and user_config.bio.description)

-- OK, *NOW* we can load stuff.
dofile("pkg/base/common.lua")

tracers = {head = 1, tail = 0, time = 0}

client_tick_accum = 0.

map_fname = "*MAP"

if common.version.num < 5 then
	error("Your version is too old! Please upgrade to 0.0-5 at least!")
end
if common.version.num >= 19 and common.version.num <= 21 then
	error("0.0-19 through 0.0-21 have an incomplete OpenGL renderer. Due to the potential abuse, these versions are not allowed. Please upgrade to 0.0-22 at the least!")
end

-- define keys
controls_config = common.json_load(controls_config_filename) or {}
BTSK_FORWARD = controls_config.forward or SDLK_w
BTSK_BACK    = controls_config.back or SDLK_s
BTSK_LEFT    = controls_config.left or SDLK_a
BTSK_RIGHT   = controls_config.right or SDLK_d
BTSK_JUMP    = controls_config.jump or SDLK_SPACE
BTSK_CROUCH  = controls_config.crouch or SDLK_LCTRL
BTSK_SNEAK   = controls_config.sneak or SDLK_v
BTSK_RELOAD  = controls_config.reload or SDLK_r

BTSK_TOOL1 = controls_config.tool1 or SDLK_1
BTSK_TOOL2 = controls_config.tool2 or SDLK_2
BTSK_TOOL3 = controls_config.tool3 or SDLK_3
BTSK_TOOL4 = controls_config.tool4 or SDLK_4
BTSK_TOOL5 = controls_config.tool5 or SDLK_5
BTSK_TOOLLAST = controls_config.toollast or SDLK_q

BTSK_COLORLEFT  = controls_config.colorleft or SDLK_LEFT
BTSK_COLORRIGHT = controls_config.colorright or SDLK_RIGHT
BTSK_COLORUP    = controls_config.colorup or SDLK_UP
BTSK_COLORDOWN  = controls_config.colordown or SDLK_DOWN

BTSK_CHAT      = controls_config.chat or SDLK_t
BTSK_COMMAND   = SDLK_SLASH
BTSK_TEAMCHAT  = controls_config.teamchat or SDLK_y
BTSK_SQUADCHAT = controls_config.squadchat or SDLK_u
BTSK_SCORES    = controls_config.scores or SDLK_TAB

BTSK_QUIT = controls_config.quit or SDLK_ESCAPE
BTSK_YES  = SDLK_y
BTSK_NO   = SDLK_n

BTSK_DEBUG = SDLK_F1
BTSK_MAP = controls_config.map or SDLK_m

BTSK_TEAM = controls_config.team or SDLK_COMMA

--[[ For user messages and hooking up GUI elements, we have a need for mapping 
the key variables to names and back. We also need to seperate the internal 
names with the natural-language descriptions. (Someday desc could be localized.)
]]

button_map = {

	forward={key=BTSK_FORWARD,desc="Forward"},
	back={key=BTSK_BACK,desc="Back"},
	left={key=BTSK_LEFT,desc="Left"},
	right={key=BTSK_RIGHT,desc="Right"},
	jump={key=BTSK_JUMP,desc="Jump"},
	crouch={key=BTSK_CROUCH,desc="Crouch"},
	sneak={key=BTSK_SNEAK,desc="Sneak"},
	reload={key=BTSK_RELOAD,desc="Reload"},
	
	tool1={key=BTSK_TOOL1,desc="Tool 1"},
	tool2={key=BTSK_TOOL2,desc="Tool 2"},
	tool3={key=BTSK_TOOL3,desc="Tool 3"},
	tool4={key=BTSK_TOOL4,desc="Tool 4"},
	tool5={key=BTSK_TOOL5,desc="Tool 5"},
	
	color_left={key=BTSK_COLORLEFT,desc="Color Left"},
	color_right={key=BTSK_COLORRIGHT,desc="Color Right"},
	color_up={key=BTSK_COLORUP,desc="Color Up"},
	color_down={key=BTSK_COLORDOWN,desc="Color Down"},
	
	chat={key=BTSK_CHAT,desc="Chat"},
	command={key=BTSK_COMMAND,desc="Command"},
	teamchat={key=BTSK_TEAMCHAT,desc="Team Chat"},
	scores={key=BTSK_SCORES,desc="Scoreboard"},
	
	quit={key=BTSK_QUIT,desc="Quit"},
	yes={key=BTSK_YES,desc="Yes"},
	no={key=BTSK_NO,desc="No"},
	
	debug={key=BTSK_DEBUG,desc="Debug"},
	map={key=BTSK_MAP,desc="Map"},
	team={key=BTSK_TEAM,desc="Change Team"},
	
}

-- equivalent - find a button from a keybinding
key_map = {}
for k, v in pairs(button_map) do
	key_map[v.key] = {name=k, desc=v.desc}
end

-- map keysyms to their unicode values to fix keyup being an idiot
keys = {}

-- a list of arbitrary data with a "camera" that can render sublists.
function scroll_list(data, cam_start, cam_height)
	
	local this = {list={},cam={
		start=cam_start or 1,
		height=cam_height-1 or 0}}
	
	-- return a subset of the list table based on the camera position and height
	function this.render(cam)
		cam = cam or this.cam
		local result = {}
		local i
		for i=cam.start, cam.start+cam.height do
			table.insert(result, this.list[i])
		end
		return result
	end
	
	return this	
end

chat_killfeed = scroll_list({}, 0, 10)
chat_text = scroll_list({}, 0, 6)

NET_MOVE_DELAY = 0.5
NET_ORIENT_DELAY = 0.1
t_net_move = nil
t_net_orient = nil

function tracer_add(x,y,z,ya,xa,time)
	local tc = {
		x=x,y=y,z=z,
		ya=ya,xa=xa,
		time=time or tracers.time,
		chn=client.wav_play_global(wav_whoosh,x,y,z,4.0)
	}
	
	tracers.tail = tracers.tail + 1
	tracers[tracers.tail] = tc
end

function tracer_prune(time)
	while tracers.head <= tracers.tail and tracers[tracers.head].time >= time + 0.4 do
		tracers[tracers.head] = nil
		tracers.head = tracers.head + 1
	end
	
	if tracers.head > tracers.tail then
		tracers.head = 1
		tracers.tail = 0
	end
	
	tracers.time = time
end

function chat_add(scrollist, mtime, msg, color)
	table.insert(scrollist.list, #scrollist.list+1, {
		mtime = mtime,
		color = color,
		msg = msg,
	})
	table.sort(scrollist.list, function(a, b) return a.mtime < b.mtime end)
end

function chat_prune(scrollist, mtime)
	-- prune lines over the stored limit
	-- prune lines that are old
	while #scrollist.list > 0 and 
		(scrollist.list[1].mtime <= mtime - MODE_CHAT_LINGER or
		#scrollist.list > MODE_CHAT_MAX) do
		table.remove(scrollist.list, 1)
	end
	
	scrollist.cam.start = #scrollist.list - scrollist.cam.height	
end

-- create map sprites
log_mspr = {}

mspr_player = {
	                -1,-3,   0,-3,   1,-3,

	        -2,-2,                           2,-2,

	-3,-1,                                           3,-1,

	-3, 0,                                           3, 0,

	-3, 1,                                           3, 1,

	        -2, 2,                           2, 2,

	                -1, 3,   0, 3,   1, 3,
}

-- TODO: confirm the correct size of the intel + tent icons
mspr_intel = {
	-3,-3,  -2,-3,  -1,-3,   0,-3,   1,-3,   2,-3,   3,-3,

	-3,-2,                                           3,-2,

	-3,-1,                                           3,-1,

	-3, 0,                                           3, 0,

	-3, 1,                                           3, 1,

	-3, 2,                                           3, 2,

	-3, 3,  -2, 3,  -1, 3,   0, 3,   1, 3,   2, 3,   3, 3,
}

mspr_tent = {
	                         0,-3,

	                         0,-2,

	                         0,-1,

	-3, 0,  -2, 0,  -1, 0,   0, 0,   1, 0,   2, 0,   3, 0,

	                         0, 1,

	                         0, 2,

	                         0, 3,
}

-- TODO: up/down arrows

-- set stuff
rotpos = 0.0
sec_last = 0.
delta_last = 0.
debug_enabled = false
mouse_released = false
sensitivity = user_config.sensitivity or 1.0
sensitivity = sensitivity/1000.0
hold_to_zoom = user_config.hold_to_zoom or false
mouse_skip = 3
input_events = {}

gui_focus = nil
window_activated = true

show_scores = false

-- load images
img_crosshair = client.img_load("pkg/base/gfx/crosshair.tga")
img_crosshairhit = client.img_load("pkg/base/gfx/crosshairhit.tga")

-- load/make models
mdl_test = client.model_load_pmf("pkg/base/pmf/test.pmf")
mdl_test_bone = client.model_bone_find(mdl_test, "test")
mdl_cube = client.model_load_pmf("pkg/base/pmf/cube.pmf")
mdl_cube_bone = client.model_bone_find(mdl_cube, "bncube")
mdl_Xcube = client.model_load_pmf("pkg/base/pmf/Xcube.pmf")
mdl_Xcube_bone = client.model_bone_find(mdl_cube, "bnXcube")
mdl_spade, mdl_spade_bone = client.model_load_pmf("pkg/base/pmf/spade.pmf"), 0
mdl_block, mdl_block_bone = client.model_load_pmf("pkg/base/pmf/block.pmf"), 0
weapon_models[WPN_RIFLE] = client.model_load_pmf("pkg/base/pmf/rifle.pmf")
weapon_models[WPN_LEERIFLE] = client.model_load_pmf("pkg/base/pmf/leerifle.pmf")
mdl_nade, mdl_nade_bone = client.model_load_pmf("pkg/base/pmf/nade.pmf"), 0

mdl_tent, mdl_tent_bone = client.model_load_pmf("pkg/base/pmf/tent.pmf"), 0
mdl_intel, mdl_intel_bone = client.model_load_pmf("pkg/base/pmf/intel.pmf"), 0
mdl_tracer, mdl_tracer_bone = client.model_load_pmf("pkg/base/pmf/tracer.pmf"), 0

-- quick hack to stitch a player model together
if false then
	local head,body,arm,leg
	head = client.model_load_pmf("pkg/base/pmf/src/playerhead.pmf")
	body = client.model_load_pmf("pkg/base/pmf/src/playerbody.pmf")
	arm = client.model_load_pmf("pkg/base/pmf/src/playerarm.pmf")
	leg = client.model_load_pmf("pkg/base/pmf/src/playerleg.pmf")

	local mname, mdata, mbone
	local mbase = client.model_new(6)
	mname, mdata = client.model_bone_get(head, 0)
	mbase, mbone = client.model_bone_new(mbase)
	client.model_bone_set(mbase, mbone, "head", mdata)
	mname, mdata = client.model_bone_get(body, 0)
	mbase, mbone = client.model_bone_new(mbase)
	client.model_bone_set(mbase, mbone, "body", mdata)
	mname, mdata = client.model_bone_get(arm, 0)
	mbase, mbone = client.model_bone_new(mbase)
	client.model_bone_set(mbase, mbone, "arm", mdata)
	mname, mdata = client.model_bone_get(leg, 0)
	mbase, mbone = client.model_bone_new(mbase)
	client.model_bone_set(mbase, mbone, "leg", mdata)

	client.model_save_pmf(mbase, "clsave/player.pmf")
end

mdl_player = client.model_load_pmf("pkg/base/pmf/player.pmf")
mdl_player_head = client.model_bone_find(mdl_player, "head")
mdl_player_body = client.model_bone_find(mdl_player, "body")
mdl_player_arm = client.model_bone_find(mdl_player, "arm")
mdl_player_leg = client.model_bone_find(mdl_player, "leg")

local _
_, mdl_block_data = client.model_bone_get(mdl_block, mdl_block_bone)


mdl_bbox = client.model_new(1)
mdl_bbox_bone_data1 = {
	{radius=10, x = -100, y = -70, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = -70, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = -70, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = -70, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = 600, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = 600, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = 600, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = 600, z =  100, r = 255, g = 85, b = 85},
}
mdl_bbox_bone_data2 = {
	{radius=10, x = -100, y = -70, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = -70, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = -70, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = -70, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = 410, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = 410, z = -100, r = 255, g = 85, b = 85},
	{radius=10, x = -100, y = 410, z =  100, r = 255, g = 85, b = 85},
	{radius=10, x =  100, y = 410, z =  100, r = 255, g = 85, b = 85},
}
mdl_bbox, mdl_bbox_bone1 = client.model_bone_new(mdl_bbox)
mdl_bbox, mdl_bbox_bone2 = client.model_bone_new(mdl_bbox)
client.model_bone_set(mdl_bbox, mdl_bbox_bone1, "bbox_stand", mdl_bbox_bone_data1)
client.model_bone_set(mdl_bbox, mdl_bbox_bone2, "bbox_crouch", mdl_bbox_bone_data2)


-- set hooks
function h_tick_main(sec_current, sec_delta)

	--FIXME: why is this POS prototyping variable still here, it is being used to control the player model's leg swing >:(
	rotpos = rotpos + sec_delta*120.0

	chat_prune(chat_text, sec_current)
	chat_prune(chat_killfeed, sec_current)

	local pkt, sockfd
	while true do
		pkt, sockfd = common.net_recv()
		if not pkt then break end

		local cid
		cid, pkt = common.net_unpack("B", pkt)
		--print("pkt", cid)

		if cid == 0x03 then
			local pid, x, y, z
			pid, x, y, z, pkt = common.net_unpack("Bhhh", pkt)
			x = x/32.0
			y = y/32.0
			z = z/32.0

			local plr = players[pid]

			if plr then
				plr.set_pos_recv(x, y, z)
			end
		elseif cid == 0x04 then
			local pid, ya, xa, keys
			pid, ya, xa, keys = common.net_unpack("BbbB", pkt)
			ya = ya*math.pi/128
			xa = xa*math.pi/256

			local plr = players[pid]

			if plr then
				plr.set_orient_recv(ya, xa, keys)
			end
		elseif cid == 0x05 then
			-- 0x05 pid team weapon mode score.s16 kills.s16 deaths.s16 name.z squad.z: (S->C)
			local pid, tidx, wpn, mode, score, kills, deaths, name, squad
			pid, tidx, wpn, mode, score, kills, deaths, name, squad, pkt
				= common.net_unpack("Bbbbhhhzz", pkt)
			
			if players[pid] then
				-- TODO: update wpn/name
				players[pid].squad = (squad ~= "" and squad) or nil
				players[pid].name = name
				players[pid].team = tidx
				players[pid].mode = mode
				players[pid].recolor_team()
			else
				players[pid] = new_player({
					name = name,
					--[=[squad = squads[(i-1) % 2][
						(math.floor((i-1)/2) % 4)+1],]=]
					squad = (squad ~= "" and squad) or nil,
					team = tidx,
					weapon = wpn,
					mode = mode,
					pid = pid,
					sockfd = sockfd
				})
			end
			
			players[pid].score = score
			players[pid].kills = kills
			players[pid].deaths = deaths
		elseif cid == 0x06 then
			local pid, pkt = common.net_unpack("B", pkt)
			players.current = pid
		elseif cid == 0x07 then
			local pid, pkt = common.net_unpack("B", pkt)
			-- TODO fix crash bug
			--players[pid].free()
			players[pid] = nil
		elseif cid == 0x08 then
			local x,y,z,cb,cg,cr,ct
			x,y,z,cb,cg,cr,ct,pkt = common.net_unpack("HHHBBBB", pkt)
			bhealth_clear(x,y,z,false)
			client.wav_play_global(wav_buld,x+0.5,y+0.5,z+0.5)
			map_block_set(x,y,z,ct,cr,cg,cb)
		elseif cid == 0x09 then
			local x,y,z
			x,y,z = common.net_unpack("HHH", pkt)
			bhealth_clear(x,y,z,false)
			map_block_break(x,y,z)
		elseif cid == 0x0E then
			-- add to chat
			local color, msg
			color, msg, pkt = common.net_unpack("Iz", pkt)
			chat_add(chat_text, sec_current, msg, color)
		elseif cid == 0x0F then
			-- add to killfeed
			local color, msg
			color, msg, pkt = common.net_unpack("Iz", pkt)
			chat_add(chat_killfeed, sec_current, msg, color)
		elseif cid == 0x10 then
			local pid, x,y,z, ya,xa
			pid, x,y,z, ya,xa, pkt = common.net_unpack("Bfffbb", pkt)
			local plr = players[pid]
			--print("client respawn!", players.current, pid, plr)
			if plr then
				plr.spawn_at(x,y,z,ya*math.pi/128,xa*math.pi/256)
			end
		elseif cid == 0x12 then
			local iid, x,y,z, f
			iid, x,y,z, f, pkt = common.net_unpack("HhhhB", pkt)
			if intent[iid] then
				--print("intent",iid,x,y,z,f)
				if not intent[iid].spawned then
					intent[iid].spawn_at(x,y,z)
					--print(intent[iid].spawned, intent[iid].alive, intent[iid].visible)
				else
					intent[iid].set_pos_recv(x,y,z)
				end
				intent[iid].set_flags_recv(f)
				--print(intent[iid].spawned, intent[iid].alive, intent[iid].visible)
			end
		elseif cid == 0x14 then
			local pid, amt
			pid, amt, pkt = common.net_unpack("BB", pkt)

			local plr = players[pid]
			--print("hit pkt", pid, amt)
			if plr then
				plr.set_health_damage(amt, nil, nil, nil)
			end
		elseif cid == 0x15 then
			local pid
			pid, pkt = common.net_unpack("B", pkt)

			local plr = players[pid]
			if plr then
				plr.tent_restock()
			end
		elseif cid == 0x16 then
			local iid, pid
			iid, pid = common.net_unpack("HB", pkt)
			local plr = (pid ~= 0 and players[pid]) or nil
			local item = intent[iid]
			--print(">",iid,pid,plr,item)
			if (pid == 0 or plr) and item then
				local hplr = item.player
				if hplr then
					hplr.has_intel = nil
				end
				
				item.player = plr
				if plr then
					plr.has_intel = item
				end
			end
		elseif cid == 0x17 then
			local pid, tool
			pid, tool, pkt = common.net_unpack("BB", pkt)
			
			local plr = players[pid]
			
			if plr then
				plr.tool_switch(tool)
			end
		elseif cid == 0x18 then
			local pid, cr,cg,cb
			pid, cr,cg,cb, pkt = common.net_unpack("BBBB", pkt)

			local plr = players[pid]

			--print("recol",cr,cg,cb)

			if plr then
				plr.blk_color = {cr,cg,cb}
				plr.block_recolor()
			end
		elseif cid == 0x19 then
			local pid, blocks
			pid, blocks, pkg = common.net_unpack("BB", pkt)

			local plr = players[pid]
			
			--print("19",pid,blocks)
			
			if plr then
				plr.blocks = blocks
			end
		elseif cid == 0x1A then
			local pid
			pid, pkg = common.net_unpack("B", pkt)
			
			local plr = players[pid]
			
			if plr then
				tracer_add(plr.x,plr.y,plr.z,
					plr.angy,plr.angx,
					sec_current)
				client.wav_play_global(wav_rifle_shot, plr.x, plr.y, plr.z)
				particles_add(new_particle{
					x = plr.x,
					y = plr.y,
					z = plr.z,
					vx = math.sin(plr.angy - math.pi / 4) / 2,
					vy = 0.1,
					vz = math.cos(plr.angy - math.pi / 4) / 2,
					r = 250,
					g = 215,
					b = 0,
					size = 8,
					lifetime = 5
				})
			end
		elseif cid == 0x1B then
			local x,y,z,vx,vy,vz,fuse
			x,y,z,vx,vy,vz,fuse, pkt = common.net_unpack("hhhhhhH", pkt)
			
			local n = new_nade({
				x = x/32,
				y = y/32,
				z = z/32,
				vx = vx/256,
				vy = vy/256,
				vz = vz/256,
				fuse = fuse/100
			})
			client.wav_play_global(wav_whoosh, x, y, z)
			nade_add(n)
		elseif cid == 0x1C then
			local plr = players[players.current]
			if plr then
				plr.t_rcirc = sec_current + MODE_RCIRC_LINGER
			end
		elseif cid == 0x1D then
			local pid
			pid, pkg = common.net_unpack("B", pkt)
			
			local plr = players[pid]
			
			if plr then
				client.wav_play_global(wav_rifle_reload, plr.x, plr.y, plr.z)
			end
		elseif cid == 0x1F then
			local tidx, score
			tidx, score = common.net_unpack("bh", pkt)
			teams[tidx].score = score
		elseif cid == 0x20 then
			local x, y, z, amt
			x, y, z, amt = common.net_unpack("HHHH", pkt)
			bhealth_damage(x, y, z, amt)
		end
	end
	tracer_prune(sec_current)
	bhealth_prune(sec_current)

	local tickrate = 1/60.
	local lowest_fps = 15
	local max_ticksize = 1/lowest_fps
	
	if sec_delta > max_ticksize then sec_delta = max_ticksize end
	
	local moment = sec_current - sec_delta
	client_tick_accum = client_tick_accum + sec_delta
	
	for i=1,players.max do
		local plr = players[i]
		if plr then
			plr.tick_listeners(sec_current, sec_delta)
		end
	end
	
	while client_tick_accum > tickrate do
		moment = moment + tickrate
		local i
		for i=1,players.max do
			local plr = players[i]
			if plr then
				plr.tick(moment, tickrate)
			end
		end
		for i=nades.head,nades.tail do
			if nades[i] then nades[i].tick(moment, tickrate) end
		end
		for i=particles.head,particles.tail do
			if particles[i] then particles[i].tick(moment, tickrate) end
		end
		nade_prune(sec_current)
		particles_prune(sec_current)
		
		for i=1,#intent do
			intent[i].tick(moment, tickrate)
		end				
		client_tick_accum = client_tick_accum - tickrate
	end
	
	if players.current and players[players.current] then
		local plr = players[players.current]

		if t_net_move and sec_current >= t_net_move then t_net_move = nil end
		if t_net_orient and sec_current >= t_net_orient then t_net_orient = nil end
		if not t_net_move then
			t_net_move = sec_current + NET_MOVE_DELAY
			local x,y,z
			x,y,z = plr.get_pos()
			x = x * 32.0
			y = y * 32.0
			z = z * 32.0
			common.net_send(nil, common.net_pack("BBhhh"
				, 0x03, 0x00, x, y, z))
		end
		if not t_net_orient then
			t_net_orient = sec_current + NET_ORIENT_DELAY
			local ya,xa,keys
			ya,xa,keys = plr.get_orient()
			ya = ya*128/math.pi
			xa = xa*256/math.pi

			common.net_send(nil, common.net_pack("BBbbB"
				, 0x04, 0x00, ya, xa, keys))
		end

		plr.camera_firstperson(sec_current, sec_delta)
	else
		-- TODO: idle camera
	end
	
	input_events = {}
	
	sec_last = sec_current
	delta_last = sec_delta
	
	-- wait a bit
	return 0.005
end

function h_tick_init(sec_current, sec_delta)
	local i
	--[[local squads = {[0]={},[1]={}}
	for i=1,4 do
		squads[0][i] = name_generate()
		squads[1][i] = name_generate()
	end]]

	players.current = nil

	--[[
	for i=1,players.max do
		players[i] = new_player({
			name = (players.current == i and user_config.name) or name_generate(),
			--[=[squad = squads[(i-1) % 2][
				(math.floor((i-1)/2) % 4)+1],]=]
			squad = nil,
			team = (i-1) % 2, -- 0 == blue, 1 == green
			weapon = WPN_RIFLE,
		})
	end
	]]
	
	intent[#intent+1] = new_intel({team = 0, iid = #intent+1})
	intent[#intent+1] = new_tent({team = 0, iid = #intent+1})
	intent[#intent+1] = new_intel({team = 1, iid = #intent+1})
	intent[#intent+1] = new_tent({team = 1, iid = #intent+1})
	
	--[[
	chat_add(chat_text, sec_current, "Just testing the chat...", 0xFFFFFFFF)
	chat_add(chat_text, sec_current, "BLUE MASTER RACE", 0xFF0000FF)
	chat_add(chat_text, sec_current, "GREEN MASTER RACE", 0xFF00C000)
	chat_add(chat_text, sec_current, "SALLY MASTER RACE", 0xFFAA00FF)
	chat_add(chat_text, sec_current, "YOU ALL SUCK", 0xFFC00000)
	]]
	chat_add(chat_text, sec_current, "Welcome to Iceball!", 0xFFFF00AA)
	chat_add(chat_killfeed, sec_current, "Please send all flames to /dev/null.", 0xFFFF00AA)
	chat_add(chat_killfeed, sec_current, "Vucgy, this includes you.", 0xFFFF00AA)
	
	mouse_released = false
	client.mouse_lock_set(true)
	client.mouse_visible_set(false)

	common.net_send(nil, common.net_pack("Bbbz", 0x11, -1, WPN_RIFLE, user_config.name or ""))

	client.hook_tick = h_tick_main
	return client.hook_tick(sec_current, sec_delta)
end
	
local function push_keypress(key, state, modif)
	table.insert(input_events, {GE_KEY, {key=key,state=state,modif=modif}})
	if key_map[key] ~= nil then
		table.insert(input_events, {GE_BUTTON, {key=key,button=key_map[key],state=state,modif=modif}})		
	end
end

local w, h = client.screen_get_dims()
stored_pointer = {x=w/4, y=h*3/4} -- default to around the lower-left, where the text box is

function enter_typing_state()
	mouse_released = true
	client.mouse_lock_set(false)
	client.mouse_visible_set(true)
	if client.mouse_warp ~= nil then
		client.mouse_warp(stored_pointer.x, stored_pointer.y)
	end
end

function discard_typing_state(widget)
	gui_focus = nil
	if widget.clear_keyrepeat then widget.clear_keyrepeat() end
	mouse_released = false
	client.mouse_lock_set(true)
	client.mouse_visible_set(false)
	if client.mouse_warp ~= nil then
		stored_pointer.x = mouse_xy.x
		stored_pointer.y = mouse_xy.y
		local w, h = client.screen_get_dims()
		client.mouse_warp(w/2, h/2)
		mouse_skip = 2
	end
end

function h_key(sym, uni, state, modif)
    local key = sym
	
	if key <= 256 then
		local tmp
		if state then tmp = 1 else tmp = 0 end

		--print("key = " .. key .. " | state = " .. tmp)

		if uni and state then
			keys[sym] = uni
			key = uni
		elseif uni and not state then
			if keys[sym] then
				key = keys[sym]
			end
		end

		--print("key = " .. key .. " | state = " .. tmp)
	end

	push_keypress(key, state, modif)

	-- disconnected ai
	
	if not players[players.current] then
		if state and key == SDLK_ESCAPE then
			client.hook_tick = nil
		end

		return
	end
	
	-- typing text
	
	if gui_focus ~= nil then
		mouse_released = true
		client.mouse_lock_set(false)
		client.mouse_visible_set(true)
		gui_focus.on_key(key, state, modif)
		return
	end
	
	if not window_activated then
		mouse_released = true
		client.mouse_lock_set(false)
		client.mouse_visible_set(true)
		return
	end
	
	-- player entity ai
	
	local plr = players[players.current]

	if plr then
		mouse_released = false
		client.mouse_lock_set(true)
		client.mouse_visible_set(false)
		return plr.on_key(key, state, modif)
	end
end

local function push_mouse_button(button, state)
	table.insert(input_events, {GE_MOUSE_BUTTON, {button=button,down=state}})
end

local function push_mouse(x, y, dx, dy)
	table.insert(input_events, {GE_MOUSE, {x=x, y=y, dx=dx, dy=dy}})
end

-- a nice little tool for checking the mouse state
function mouse_prettyprint()
	
	local function xyp(n)
		local s = tostring(mouse_xy[n])
		if #s == 1 then return n..s.."    "
		elseif #s == 2 then return n..s.."   "
		elseif #s == 3 then return n..s.."  "
		elseif #s == 4 then return n..s.." "
		else return n..s end
	end
	
	local function pollp(n)
		if mouse_poll[n] then return n..'X ' else return n..'  ' end
	end
	
	return xyp('x')..xyp('y')..xyp('dx')..xyp('dy')..
	"  "..pollp(1)..pollp(2)..pollp(3)..pollp(4)..pollp(5)
end

mouse_poll = {false,false,false,false,false}
mouse_xy = {x=0,y=0,dx=0,dy=0}

function h_mouse_button(button, state)
	
	if mouse_poll[button] ~= state then
		mouse_poll[button] = state
		push_mouse_button(button, state)
	end
	
	if mouse_released and gui_focus == nil then
		mouse_released = false
		client.mouse_lock_set(true)
		client.mouse_visible_set(false)
		return
	end
	
	-- player entity ai
	-- FIXME: no reassignable mouse button controls?

	local plr = players[players.current]
	if plr and gui_focus == nil then
		return plr.on_mouse_button(button, state)
	end
end

function h_mouse_motion(x, y, dx, dy)
	
	mouse_xy.x = x
	mouse_xy.y = y
	mouse_xy.dx = dx
	mouse_xy.dy = dy
	
	push_mouse(x, y, dx, dy)

	-- player entity ai
	
	if not players[players.current] then return end
	if mouse_released then return end
	if mouse_skip > 0 then
		mouse_skip = mouse_skip - 1
		return
	end

	local plr = players[players.current]
	if plr and gui_focus == nil then
		return plr.on_mouse_motion(x, y, dx, dy)
	end
end

function h_window_activate(active)
	window_activated = active
	if active then
		mouse_released = false
		client.mouse_lock_set(true)
		client.mouse_visible_set(false)
	else
		mouse_released = true
		client.mouse_lock_set(false)
		client.mouse_visible_set(true)
	end
end

-- load map
map_loaded = common.map_load(map_fname, "auto")
common.map_set(map_loaded)

print(client.map_fog_get())
--client.map_fog_set(24,0,32,60)
client.map_fog_set(192,238,255,60)
print(client.map_fog_get())

-- create map overview
-- TODO: update image when map gets mutilated
do
	local xlen, ylen, zlen
	xlen, ylen, zlen = common.map_get_dims()
	img_overview = common.img_new(xlen, zlen)
	img_overview_grid = common.img_new(xlen, zlen)
	img_overview_icons = common.img_new(xlen, zlen)
	local x,z

	for z=0,zlen-1 do
	for x=0,xlen-1 do
		local l = common.map_pillar_get(x,z)
		local c = argb_split_to_merged(l[7],l[6],l[5])
		common.img_pixel_set(img_overview, x, z, c)
	end
	end
	
	for z=63,zlen-1,64 do
	for x=0,xlen-1 do
		common.img_pixel_set(img_overview_grid, x, z, 0xFFFFFFFF)
	end
	end
	for z=0,zlen-1 do
	for x=63,xlen-1,64 do
		common.img_pixel_set(img_overview_grid, x, z, 0xFFFFFFFF)
	end
	end
	
	for x=0,xlen-1 do
		common.img_pixel_set(img_overview_grid, x, zlen-1, 0xFFFF0000)
	end
	for z=0,zlen-1 do
		common.img_pixel_set(img_overview_grid, xlen-1, z, 0xFFFF0000)
	end
end

-- create colour palette image
img_cpal = common.img_new(64,64)
img_cpal_rect = common.img_new(8,8)
do
	local cx,cy,x,y
	for cy=0,7 do
	for cx=0,7 do
		local r,g,b
		r = cpalette[cy*8+cx+1][1]
		g = cpalette[cy*8+cx+1][2]
		b = cpalette[cy*8+cx+1][3]
		local c = argb_split_to_merged(r,g,b)

		for y=cy*8+1,cy*8+6 do
		for x=cx*8+1,cx*8+6 do
			common.img_pixel_set(img_cpal, x, y, c)
		end
		end
	end
	end

	local i
	for i=0,6 do
		common.img_pixel_set(img_cpal_rect, i, 0, 0xFFFFFFFF)
		common.img_pixel_set(img_cpal_rect, 7, i, 0xFFFFFFFF)
		common.img_pixel_set(img_cpal_rect, 7-i, 7, 0xFFFFFFFF)
		common.img_pixel_set(img_cpal_rect, 0, 7-i, 0xFFFFFFFF)
	end
end

-- hooks in place!
function client.hook_render()
	if players and players[players.current] then
		players[players.current].show_hud()
	end
	
	local i
	for i=tracers.head,tracers.tail do
		local tc = tracers[i]
		
		local x,y,z
		x,y,z = tc.x, tc.y, tc.z
		
		local sya = math.sin(tc.ya)
		local cya = math.cos(tc.ya)
		local sxa = math.sin(tc.xa)
		local cxa = math.cos(tc.xa)
		
		local d = tracers.time - tc.time
		d = d + 0.005
		d = d * 600.0
		x = x + sya*cxa*d
		y = y + sxa*d
		z = z + cya*cxa*d
		
		client.wav_chn_update(tracers.chn, x, y, z)
		
		client.model_render_bone_global(mdl_tracer, mdl_tracer_bone,
			x,y,z,
			0.0, -tc.xa, tc.ya, 1)
	end
	
	for i=nades.head,nades.tail do
		if nades[i] then nades[i].render() end
	end
	
	for i=particles.head,particles.tail do
		if particles[i] then particles[i].render() end
	end
	
end

client.hook_tick = h_tick_init
client.hook_key = h_key
client.hook_mouse_button = h_mouse_button
client.hook_mouse_motion = h_mouse_motion
client.hook_window_activate = h_window_activate

print("pkg/base/client_start.lua loaded.")

--dofile("pkg/base/plug_snow.lua")
--dofile("pkg/base/plug_pmfedit.lua")

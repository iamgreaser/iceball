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

local loose, user_toggles, user_settings = parse_commandline_options({...})
local user_config_filename = user_settings['user'] or "clsave/pub/user.json"
-- FIXME: we don't expose documentation for valid user settings anywhere

user_config = common.json_load(user_config_filename)
print("json done!")
print("name:", user_config.name)
print("kick on join:", user_config.kick_on_join)
print("bio desc:", user_config.bio and user_config.bio.description)

-- OK, *NOW* we can load stuff.
dofile("pkg/base/common.lua")

tracers = {head = 1, tail = 0, time = 0}
bhealth = {head = 1, tail = 0, time = 0, map = {}}

--[[
while true do
	local pkt, sockfd, cid
	pkt, sockfd = common.net_recv()
	cid, pkt = common.net_unpack("B", pkt)
	if cid == 0xE0 then
		map_fname, pkt = common.net_unpack("z", pkt)
		break
	else
		error("should not receive non-map-filename packets until map filename arrives!")
	end
end]]

--map_fname = "*MAP"
map_fname = "pkg/MAP" -- hackish workaround so iceballfornoobs-004 still works

if not map_fname then
	error("server should have sent map name by now")
end

-- define keys
BTSK_FORWARD = SDLK_w
BTSK_BACK    = SDLK_s
BTSK_LEFT    = SDLK_a
BTSK_RIGHT   = SDLK_d
BTSK_JUMP    = SDLK_SPACE
BTSK_CROUCH  = SDLK_LCTRL
BTSK_SNEAK   = SDLK_v
BTSK_RELOAD  = SDLK_r

BTSK_TOOL1 = SDLK_1
BTSK_TOOL2 = SDLK_2
BTSK_TOOL3 = SDLK_3
BTSK_TOOL4 = SDLK_4
BTSK_TOOL5 = SDLK_5

BTSK_COLORLEFT  = SDLK_LEFT
BTSK_COLORRIGHT = SDLK_RIGHT
BTSK_COLORUP    = SDLK_UP
BTSK_COLORDOWN  = SDLK_DOWN

BTSK_CHAT     = SDLK_t
BTSK_COMMAND  = SDLK_SLASH
BTSK_TEAMCHAT = SDLK_y
BTSK_SCORES   = SDLK_TAB

BTSK_QUIT = SDLK_ESCAPE
BTSK_YES  = SDLK_y
BTSK_NO   = SDLK_n

BTSK_DEBUG = SDLK_F1
BTSK_MAP = SDLK_m

chat_killfeed = {head = 1, scroll = nil, queue = {}}
chat_text = {head = 1, scroll = nil, queue = {}}

NET_MOVE_DELAY = 0.5
NET_ORIENT_DELAY = 0.1
t_net_move = nil
t_net_orient = nil

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

function bhealth_damage(x,y,z,amt)
	local map = bhealth.map
	
	map[x] = map[x] or {}
	map[x][y] = map[x][y] or {}
	map[x][y][z] = map[x][y][z] or {
		c = map_block_get(x,y,z),
		damage = 0,
		time = nil,
		qidx = nil,
		x = x, y = y, z = z,
	}
	local blk = map[x][y][z]
	
	blk.time = bhealth.time + MODE_BLOCK_REGEN_TIME
	blk.damage = blk.damage + amt
	
	if blk.damage >= MODE_BLOCK_HEALTH then
		common.net_send(nil, common.net_pack("BHHH",
			0x09, x, y, z))
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

function tracer_add(x,y,z,ya,xa,time)
	local tc = {
		x=x,y=y,z=z,
		ya=ya,xa=xa,
		time=time or tracers.time,
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

function chat_add(ctab, mtime, msg, color)
	local l = {
		mtime = mtime,
		color = color,
		msg = msg,
	}

	if mtime then
		ctab[#ctab+1] = l
	else
		ctab.queue[#(ctab.queue)+1] = l
	end
end

function chat_prune(ctab, mtime)
	local i

	for i=1,#(ctab.queue) do
		local l = ctab.queue[i]
		l.mtime = mtime
		ctab[#ctab+1] = l
	end
	ctab.queue = {}

	mtime = mtime - MODE_CHAT_LINGER
	while ctab.head <= #ctab and (
			#ctab-ctab.head > MODE_CHAT_MAX
			or ctab[ctab.head].mtime <= mtime) do
		ctab.head = ctab.head + 1
	end
end

function chat_draw(ctab, fn_pos)
	-- TODO: scrollback
	local i
	local w,h
	w,h = client.screen_get_dims()

	for i=ctab.head,#ctab do
		local x,y
		local ri = i-ctab.head
		x,y = fn_pos(ri,ctab[i].msg,w,h)
		font_mini.print(x,y,ctab[i].color,ctab[i].msg)
	end
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
debug_enabled = false
mouse_released = false
large_map = false
sensitivity = user_config.sensitivity or 1.0
sensitivity = sensitivity/1000.0
mouse_skip = 3

typing_type = nil
typing_msg = nil

show_scores = false

quitting = false

-- load images
img_crosshair = client.img_load("pkg/base/gfx/crosshair.tga")

-- load/make models
mdl_test = client.model_load_pmf("pkg/base/pmf/test.pmf")
mdl_test_bone = client.model_bone_find(mdl_test, "test")
mdl_spade, mdl_spade_bone = client.model_load_pmf("pkg/base/pmf/spade.pmf"), 0
mdl_block, mdl_block_bone = client.model_load_pmf("pkg/base/pmf/block.pmf"), 0
weapon_models[WPN_RIFLE] = client.model_load_pmf("pkg/base/pmf/rifle.pmf")
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
			-- 0x05 pid team weapon score.s16 kills.s16 deaths.s16 namelen name[namelen]: (S->C)
			local pid, tidx, wpn, score, kills, deaths, name
			pid, tidx, wpn, score, kills, deaths, name, pkt
				= common.net_unpack("Bbbhhhz", pkt)
			
			if players[pid] then
				-- TODO: update wpn/tidx/name
			else
				players[pid] = new_player({
					name = name,
					--[=[squad = squads[math.fmod(i-1,2)][
						math.fmod(math.floor((i-1)/2),4)+1],]=]
					squad = nil,
					team = tidx,
					weapon = wpn,
					pid = pid,
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
			chat_add(chat_text, nil, msg, color)
		elseif cid == 0x0F then
			-- add to killfeed
			local color, msg
			color, msg, pkt = common.net_unpack("Iz", pkt)
			chat_add(chat_killfeed, nil, msg, color)
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
			end
		end
	end
	tracer_prune(sec_current)
	bhealth_prune(sec_current)

	local i
	for i=1,players.max do
		local plr = players[i]
		if plr then
			plr.tick(sec_current, sec_delta)
		end
	end

	for i=1,#intent do
		intent[i].tick(sec_current, sec_delta)
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

		plr.camera_firstperson()
	else
		-- TODO: idle camera
	end

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
			--[=[squad = squads[math.fmod(i-1,2)][
				math.fmod(math.floor((i-1)/2),4)+1],]=]
			squad = nil,
			team = math.fmod(i-1,2), -- 0 == blue, 1 == green
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
	chat_add(chat_text, sec_current, "Please send all flames to /dev/null.", 0xFFFF00AA)
	chat_add(chat_text, sec_current, "Vucgy, this includes you.", 0xFFFF00AA)
	
	mouse_released = false
	client.mouse_lock_set(true)
	client.mouse_visible_set(false)

	common.net_send(nil, common.net_pack("Bbbz", 0x11, -1, WPN_RIFLE, user_config.name or ""))

	client.hook_tick = h_tick_main
	return client.hook_tick(sec_current, sec_delta)
end

function h_key(key, state, modif)
	if state and key == SDLK_F5 then
		mouse_released = true
		client.mouse_lock_set(false)
		client.mouse_visible_set(true)
	end

	if not players[players.current] then
		if state and key == SDLK_ESCAPE then
			client.hook_tick = nil
		end

		return
	end
	local plr = players[players.current]

	if typing_type then
		if state then
			if key == SDLK_ESCAPE then
				typing_type = nil
				typing_msg = nil
			elseif key == SDLK_RETURN then
				if typing_msg ~= "" then
					if typing_type == "Chat: " then
						-- TODO: get this supported - needs to be serverside!
						--[[
						if typing_msg == "/kill" then
							plr.damage(100, 0xFFC00000, plr.name.." committed suicide")
						end]]

						if not common.net_send(nil, common.net_pack("Bz", 0x0C, typing_msg)) then
							print("ERR!")
						end
					elseif typing_type == "Team: " then
						common.net_send(nil, common.net_pack("Bz", 0x0D, typing_msg))
					end
				end
				typing_type = nil
				typing_msg = nil
			else
				typing_msg = gui_string_edit(typing_msg, MODE_CHAT_STRMAX, key, modif)
			end
		end
	elseif key == BTSK_FORWARD then
		plr.ev_forward = state
	elseif key == BTSK_BACK then
		plr.ev_back = state
	elseif key == BTSK_LEFT then
		plr.ev_left = state
	elseif key == BTSK_RIGHT then
		plr.ev_right = state
	elseif key == BTSK_CROUCH then
		plr.ev_crouch = state
	elseif key == BTSK_JUMP then
		plr.ev_jump = state
	elseif key == BTSK_SNEAK then
		plr.ev_sneak = state
	elseif key == BTSK_SCORES then
		show_scores = state
	elseif state then
		if quitting then
			if key == BTSK_YES then
				-- TODO: clean up
				client.hook_tick = nil
			elseif key == BTSK_NO then
				quitting = false
			end
		end
		if key == BTSK_DEBUG then
			debug_enabled = not debug_enabled
		elseif key == BTSK_QUIT then
			quitting = true
		elseif key == SDLK_F10 then
			local s = "clsave/"..common.base_dir.."/vol/lastsav.icemap"
			print(s)
			--client.map_load(s)
			client.map_save(map_loaded, s, "icemap")
			chat_add(chat_text, nil, "Map saved to "..s, 0xFFC00000)
		elseif key == BTSK_MAP then
			large_map = not large_map
		elseif key == BTSK_RELOAD then
			if plr.alive and plr.wpn and plr.tool == TOOL_GUN then
				plr.wpn.reload()
			end
		elseif key == BTSK_TOOL1 then
			plr.tool_switch(TOOL_SPADE)
		elseif key == BTSK_TOOL2 then
			plr.tool_switch(TOOL_BLOCK)
		elseif key == BTSK_TOOL3 then
			plr.tool_switch(TOOL_GUN)
		elseif key == BTSK_TOOL4 then
			plr.tool_switch(TOOL_NADE)
		elseif key == BTSK_TOOL5 then
			-- TODO
		elseif key == BTSK_CHAT then
			typing_type = "Chat: "
			typing_msg = ""
		elseif key == BTSK_COMMAND then
			typing_type = "Chat: "
			typing_msg = "/"
		elseif key == BTSK_TEAMCHAT then
			typing_type = "Team: "
			typing_msg = ""
		elseif plr.alive and key == BTSK_COLORLEFT then
			plr.blk_color_x = plr.blk_color_x - 1
			if plr.blk_color_x < 0 then
				plr.blk_color_x = 7
			end
			plr.blk_color = cpalette[plr.blk_color_x+plr.blk_color_y*8+1]
			common.net_send(nil, common.net_pack("BBBBB",
				0x18, 0x00,
				plr.blk_color[1],plr.blk_color[2],plr.blk_color[3]))
		elseif plr.alive and key == BTSK_COLORRIGHT then
			plr.blk_color_x = plr.blk_color_x + 1
			if plr.blk_color_x > 7 then
				plr.blk_color_x = 0
			end
			plr.blk_color = cpalette[plr.blk_color_x+plr.blk_color_y*8+1]
			common.net_send(nil, common.net_pack("BBBBB",
				0x18, 0x00,
				plr.blk_color[1],plr.blk_color[2],plr.blk_color[3]))
		elseif plr.alive and key == BTSK_COLORUP then
			plr.blk_color_y = plr.blk_color_y - 1
			if plr.blk_color_y < 0 then
				plr.blk_color_y = 7
			end
			plr.blk_color = cpalette[plr.blk_color_x+plr.blk_color_y*8+1]
			common.net_send(nil, common.net_pack("BBBBB",
				0x18, 0x00,
				plr.blk_color[1],plr.blk_color[2],plr.blk_color[3]))
		elseif plr.alive and key == BTSK_COLORDOWN then
			plr.blk_color_y = plr.blk_color_y + 1
			if plr.blk_color_y > 7 then
				plr.blk_color_y = 0
			end
			plr.blk_color = cpalette[plr.blk_color_x+plr.blk_color_y*8+1]
			common.net_send(nil, common.net_pack("BBBBB",
				0x18, 0x00,
				plr.blk_color[1],plr.blk_color[2],plr.blk_color[3]))
		end
	end
end

function h_mouse_button(button, state)
	if mouse_released then
		mouse_released = false
		client.mouse_lock_set(true)
		client.mouse_visible_set(false)
		return
	end

	local plr = players[players.current]
	if not plr then return end

	local xlen, ylen, zlen
	xlen, ylen, zlen = common.map_get_dims()

	if plr.tool == TOOL_GUN and plr.alive then
		plr.wpn.click(button, state)
	end

	if button == 1 then
		-- LMB
		plr.ev_lmb = state
		if plr.ev_lmb then
			plr.ev_rmb = false
		end
	elseif button == 3 then
		-- RMB
		plr.ev_rmb = state
		if plr.ev_rmb then
			plr.ev_lmb = false
		end
	elseif button == 2 then
		-- middleclick
	end
end

function h_mouse_motion(x, y, dx, dy)
	if not players[players.current] then return end
	if mouse_released then return end
	if mouse_skip > 0 then
		mouse_skip = mouse_skip - 1
		return
	end

	local plr = players[players.current]

	plr.dangy = plr.dangy - dx*math.pi*sensitivity/plr.zoom
	plr.dangx = plr.dangx + dy*math.pi*sensitivity/plr.zoom
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
		
		client.model_render_bone_global(mdl_tracer, mdl_tracer_bone,
			x,y,z,
			0.0, -tc.xa, tc.ya, 1)
	end
	
end

client.hook_tick = h_tick_init
client.hook_key = h_key
client.hook_mouse_button = h_mouse_button
client.hook_mouse_motion = h_mouse_motion

print("pkg/base/client_start.lua loaded.")

--dofile("pkg/base/plug_snow.lua")
--dofile("pkg/base/plug_pmfedit.lua")

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
frame_delay_ctr = 0.0001
render_sec_current = nil

VA_TEST = false

-- Ensure we have VA support
if VA_TEST then
	if not common.va_make then
		VA_TEST = false
	end
end

-- yeah this really should happen ASAP so we can boot people who suck
dofile("pkg/base/lib_util.lua")

--dofile("pkg/base/serpent.lua") -- serpent.block is a great debugging aid

local loose, user_toggles, user_settings = parse_commandline_options({...})
local user_config_filename = user_settings['user'] or "clsave/pub/user.json"
local controls_config_filename = user_settings['controls'] or "clsave/pub/controls.json"
-- FIXME: we don't expose documentation for valid user settings anywhere

user_config = common.json_load(user_config_filename)
if MODE_NUB_KICKONJOIN and user_config.kick_on_join then
	error([[
Edit your clsave/pub/user.json file, and set kick_on_join to false.]])
end
print("json done!")
print("name:", user_config.name)
print("bio desc:", user_config.bio and user_config.bio.description)

if user_config.frame_limit and user_config.frame_limit > 0.01 then
	frame_delay_ctr = 1.0 / user_config.frame_limit
	if frame_delay_ctr <= 0.0001 then
		frame_delay_ctr = 0.0001
	end
	print("frame delay:", frame_delay_ctr)
end

-- OK, *NOW* we can load stuff.
dofile("pkg/base/lib_va.lua")
dofile("pkg/base/common.lua")
dofile("pkg/base/border.lua")

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
BTSK_CHATUP  = controls_config.chatup or SDLK_PAGEUP
BTSK_CHATDN  = controls_config.chatdn or SDLK_PAGEDOWN

BTSK_TOOLS = {}
do
	local i
	local defvals = {49,50,51,52,53,54,55,56,57,48}
	for i=1,10 do
		BTSK_TOOLS[i] = (controls_config.tools and controls_config.tools[i]) or controls_config["tool"..i] or defvals[i]
	end
end
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
BTSK_WPN = controls_config.wpn or SDLK_PERIOD

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
	wpn={key=BTSK_WPN,desc="Change Weapon"},
}
do
	local i
	for i=1,#BTSK_TOOLS do
		button_map["tool"..i]={key=BTSK_TOOLS[i],desc="Tool "..i}
	end
end

-- equivalent - find a button from a keybinding
key_map = {}
for k, v in pairs(button_map) do
	key_map[v.key] = {name=k, desc=v.desc}
end

-- map keysyms to their unicode values to fix keyup being an idiot
keys = {}

-- a list of arbitrary data with a "camera" that can render sublists.
function scroll_list(data, cam_start, cam_height, scrollbackable)
	
	local this = {list={},cam={
		start=cam_start or 1,
		height=cam_height-1 or 0},
		scrollback = false,
		scrollbackable = scrollbackable,
		head = 1}
	
	-- return a subset of the list table based on the camera position and height
	function this.render(cam)
		cam = cam or this.cam
		local result = {}
		local i
		for i=cam.start, math.min(#this.list, cam.start+cam.height) do
			table.insert(result, this.list[i])
		end
		return result
	end
	
	return this	
end

chat_killfeed = scroll_list({}, 0, 10, false)
chat_text = scroll_list({}, 0, 10, true)

NET_MOVE_DELAY = 0.1
NET_ORIENT_DELAY = 0.1
t_net_move = nil
t_net_orient = nil

function tracer_add(x,y,z,ya,xa,time)
	x = x or 0
	y = y or 0
	z = z or 0
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
	while tracers.head <= tracers.tail and tracers[tracers.head].time + 0.4 <= time do
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
	while scrollist.head <= #scrollist.list and 
		(scrollist.list[scrollist.head].mtime <= mtime - MODE_CHAT_LINGER or
		#scrollist.list - (scrollist.head-1) > MODE_CHAT_MAX) do
		if scrollist.scrollbackable then
			scrollist.head = scrollist.head + 1
		else
			table.remove(scrollist.list, scrollist.head)
		end
	end
	
	if not scrollist.scrollback then
		scrollist.cam.start = math.max(math.max(scrollist.cam.start, scrollist.head)
			, #scrollist.list - scrollist.cam.height)
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
img_chevron = client.img_load("pkg/base/gfx/chevron.tga")

-- load kv6 models
-- TODO: remove the pmfs

-- load/make models
mdl_test = skin_load("pmf", "test.pmf", DIR_PKG_PMF)
mdl_test_bone = client.model_bone_find(mdl_test, "test")
mdl_cube = skin_load("pmf", "cube.pmf", DIR_PKG_PMF)
mdl_cube_bone = client.model_bone_find(mdl_cube, "bncube")
mdl_spade, mdl_spade_bone = skin_load("pmf", "spade.pmf", DIR_PKG_PMF), 0
mdl_block, mdl_block_bone = skin_load("pmf", "block.pmf", DIR_PKG_PMF), 0
mdl_piano, mdl_piano_bone = skin_load("pmf", "piano.pmf", DIR_PKG_PMF), 0
mdl_marker, mdl_marker_bone = skin_load("pmf", "marker.pmf", DIR_PKG_PMF), 0
mdl_tracer, mdl_tracer_bone = skin_load("pmf", "tracer.pmf", DIR_PKG_PMF), 0

if common.va_make then
	va_Xcube = loadkv6(DIR_PKG_KV6.."/xcube.kv6", 1.0/256.0)
else
	mdl_Xcube = skin_load("pmf", "xcube.pmf", DIR_PKG_PMF)
	mdl_Xcube_bone = client.model_bone_find(mdl_cube, "bnXcube")
end

-- quick hack to stitch a player model together
if false then
	local head,body,arm,leg
	head = skin_load("pmf", "src/playerhead.pmf", DIR_PKG_PMF)
	body = skin_load("pmf", "src/playerbody.pmf", DIR_PKG_PMF)
	arm = skin_load("pmf", "src/playerarm.pmf", DIR_PKG_PMF)
	leg = skin_load("pmf", "src/playerleg.pmf", DIR_PKG_PMF)

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

	client.model_save_pmf(mbase, "clsave/vol/player.pmf")
end

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

-- profile bone count
if false then
	local bone_ctr = 0
	function bone_ctr_reset()
		local ret = bone_ctr
		print("bones:", bone_ctr)
		bone_ctr = 0
		return ret
	end

	local old_model_render_bone_global = client.model_render_bone_global
	local old_model_render_bone_local = client.model_render_bone_local

	function client.model_render_bone_global(...)
		bone_ctr = bone_ctr + 1
		return old_model_render_bone_global(...)
	end

	function common.model_render_bone_global(...)
		bone_ctr = bone_ctr + 1
		return old_model_render_bone_global(...)
	end

	function client.model_render_bone_local(...)
		bone_ctr = bone_ctr + 1
		return old_model_render_bone_local(...)
	end

	function common.model_render_bone_local(...)
		bone_ctr = bone_ctr + 1
		return old_model_render_bone_local(...)
	end
end

-- set hooks
lflush = nil
function h_tick_main(sec_current, sec_delta)
	render_sec_current = sec_current
	if bone_ctr_reset then
		bone_ctr_reset()
	end

	if (not lflush) or sec_current < lflush - 0.8 then
		lflush = sec_current
	end
	if sec_current >= lflush then
		net_send_flush()
		lflush = lflush + NET_FLUSH_C2S
		if sec_current <= lflush then
			lflush = sec_current
		end
	end
	--FIXME: why is this POS prototyping variable still here, it is being used to control the player model's leg swing >:(
	rotpos = rotpos + sec_delta*120.0

	chat_prune(chat_text, sec_current)
	chat_prune(chat_killfeed, sec_current)

	local pkt, neth
	while true do
		pkt, neth = common.net_recv()
		if not pkt then break end

		local cid
		cid, pkt = common.net_unpack("B", pkt)
		--print("pkt", cid)
		
		local hdl = network.sys_tab_handlers[cid]
		if hdl then
			hdl.f(neth, cli, plr, sec_current, common.net_unpack(hdl.s, pkt))
		else
			print(string.format("C: unhandled packet %02X", cid))
		end
	end
	tracer_prune(sec_current)
	bhealth_prune(sec_current)

	local tickrate = 1/60.
	local lowest_fps = 7.5 -- some people have REALLY shit GPUs. might as well lower this requirement.
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
		for i=1,#borders do
			borders[i].tick(moment, tickrate)
		end
		nade_prune(sec_current)
		particles_prune(sec_current)
		
		for i=1,#miscents do
			miscents[i].tick(moment, tickrate)
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
			local vx,vy,vz
			x,y,z = plr.get_pos()
			vx,vy,vz = plr.get_vel
			net_send(nil, common.net_pack("BBffffff"
				, PKT_PLR_POS, 0x00, x, y, z, vx, vy, vz))
		end
		if not t_net_orient then
			t_net_orient = sec_current + NET_ORIENT_DELAY
			local ya,xa,keys
			ya,xa,keys = plr.get_orient()
			ya = ya*128/math.pi
			xa = xa*256/math.pi

			net_send(nil, common.net_pack("BBbbB"
				, PKT_PLR_ORIENT, 0x00, ya, xa, keys))
		end

		plr.camera_firstperson(sec_current, sec_delta)
	else
		-- TODO: idle camera
	end
	
	input_events = {}
	
	sec_last = sec_current
	delta_last = sec_delta
	
	-- wait a bit
	local d = math.max(0.00001, frame_delay_ctr - delta_last)
	return d
end

function h_tick_init(sec_current, sec_delta)
	render_sec_current = sec_current
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
	
	mode_create_client()

	chat_add(chat_text, sec_current, "Welcome to Iceball!", 0xFFFF00AA)
	--chat_add(chat_killfeed, sec_current, "If it's broken, fix it yourself", 0xFFFF00AA)
	chat_add(chat_killfeed, sec_current, "If you have any questions, file a GitHub issue.", 0xFFFF00AA)
	
	mouse_released = false
	client.mouse_lock_set(true)
	client.mouse_visible_set(false)

	net_send(nil, common.net_pack("Bbbz", PKT_PLR_OFFER, -1, WPN_RIFLE, user_config.name or ""))

	client.hook_tick = h_tick_main
	net_send_flush()
	return client.hook_tick(sec_current, sec_delta)
end
	
local function push_keypress(key, state, modif, sym, uni)
	table.insert(input_events, {GE_KEY, {key=key,state=state,modif=modif,uni=uni}})
	if key_map[sym] ~= nil then
		table.insert(input_events, {GE_BUTTON, {key=sym,button=key_map[sym],state=state,modif=modif,uni=uni}})
	end
end

stored_pointer = {x=screen_width/4, y=screen_height*3/4} -- default to around the lower-left, where the text box is

function enter_typing_state()
	chat_text.scrollback = true
	chat_text.cam.start = math.max(1, #chat_text.list - chat_text.cam.height)
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
	chat_text.scrollback = false
	mouse_released = false
	client.mouse_lock_set(true)
	client.mouse_visible_set(false)
	if client.mouse_warp ~= nil then
		stored_pointer.x = mouse_xy.x
		stored_pointer.y = mouse_xy.y
		client.mouse_warp(screen_width/2, screen_height/2)
		mouse_skip = 2
	end
end

function h_key(sym, state, modif, uni)
	local key = sym

	push_keypress(key, state, modif, sym, uni)

	-- disconnected ai
	
	if not players[players.current] then
		if state and key == BTSK_QUIT then
			client.hook_tick = nil
		end

		return
	end
	
	-- typing text
	
	if gui_focus ~= nil then
		mouse_released = true
		client.mouse_lock_set(false)
		client.mouse_visible_set(true)
		gui_focus.on_key(key, state, modif, uni)
		if state and chat_text.scrollback then
			if key == BTSK_CHATUP then
				chat_text.cam.start = math.max(1, chat_text.cam.start - math.floor(chat_text.cam.height/2+0.5))
			elseif key == BTSK_CHATDN then
				chat_text.cam.start = math.max(1, math.min(
					chat_text.cam.start + math.floor(chat_text.cam.height/2+0.5),
					#chat_text.list - chat_text.cam.height))
			end
		end
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
		return plr.on_key(key, state, modif, uni)
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
borders = {}

-- set fog
print(client.map_fog_get())
--client.map_fog_set(24,0,32,60)
foglvl = user_config.fog or MODE_DEFAULT_FOG
if foglvl <= 1 then foglvl = MODE_MAX_FOG end
if MODE_MAX_FOG and foglvl > MODE_MAX_FOG then
	foglvl = MODE_MAX_FOG
end
if MODE_FOG_GL_EXTEND and client.renderer == "gl" then
	foglvl = foglvl * math.sqrt(2)
end
client.map_fog_set(192,238,255,foglvl)
print(client.map_fog_get())

-- set borders
do
	local xlen, ylen, zlen
	xlen, ylen, zlen = common.map_get_dims()
	local r,g,b
	r,g,b = client.map_fog_get()
	if MODE_BORDER_SHOW then
		borders = {
			new_border(-1, 0, 0, 1, 0, 0, r,g,b),
			new_border(xlen+1, ylen, zlen, 1, 0, 0, r,g,b),
			new_border(0, 0, -1, 0, 0, 1, r,g,b),
			new_border(xlen, ylen, zlen+1, 0, 0, 1, r,g,b),
			new_border(-1, 0, 0, 1, 0, 0, r,g,b),
			new_border(xlen+1, ylen, zlen, 1, 0, 0, r,g,b),
			new_border(0, 0, -1, 0, 0, 1, r,g,b),
			new_border(xlen, ylen, zlen+1, 0, 0, 1, r,g,b),
		}
	end
end

-- create map overview
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
if VA_TEST then
	--[[
	va_test = common.va_make({
		{0, 0, 0, 1, 0.5, 0.5}, {1, 0, 0, 1, 0, 0}, {0, 1, 0, 1, 0, 0},
		{0, 0, 0, 0.5, 1, 0.5}, {0, 0, 1, 0, 1, 0}, {1, 0, 0, 0, 1, 0},
		{0, 0, 0, 0.5, 0.5, 1}, {0, 1, 0, 0, 0, 1}, {0, 0, 1, 0, 0, 1},
		{1, 0, 0, 0.7, 0, 0.7}, {0, 0, 1, 0.7, 0, 0.7}, {0, 1, 0, 0.7, 0, 0.7},
	})
	]]
	--va_test = loadkv6("pkg/base/kv6/playerheadalt.kv6", 1.0/16.0)
	va_test = common.va_make({
		{0, 0, 0, 0, 0}, {1, 0, 0, 0, 1}, {0, 1, 0, 1, 0},
		{0, 0, 0, 0, 0}, {0, 0, 1, 0, 1}, {1, 0, 0, 1, 0},
		{0, 0, 0, 0, 0}, {0, 1, 0, 0, 1}, {0, 0, 1, 1, 0},
		{1, 0, 0, 0, 0}, {0, 0, 1, 0, 1}, {0, 1, 0, 1, 0},
	}, nil, "3v,2t")
	--[[
	va_test = common.va_make({
		{0, 0, 0, 1, 0.5, 0.5, 0, 0}, {1, 0, 0, 1, 0, 0, 0, 1}, {0, 1, 0, 1, 0, 0, 1, 0},
		{0, 0, 0, 0.5, 1, 0.5, 0, 0}, {0, 0, 1, 0, 1, 0, 0, 1}, {1, 0, 0, 0, 1, 0, 1, 0},
		{0, 0, 0, 0.5, 0.5, 1, 0, 0}, {0, 1, 0, 0, 0, 1, 0, 1}, {0, 0, 1, 0, 0, 1, 1, 0},
		{1, 0, 0, 0.7, 0, 0.7, 0, 0}, {0, 0, 1, 0.7, 0, 0.7, 0, 1}, {0, 1, 0, 0.7, 0, 0.7, 1, 0},
	}, nil, "3v,3c,2t")
	]]
end
function client.hook_render()
	local sec_current = render_sec_current
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

	for i=1,#borders do
		borders[i].render()
	end

	if players and players[players.current] then
		players[players.current].show_hud()
	end
	if VA_TEST and sec_current then
		client.va_render_local(va_test, -0.8, 0.35, 1, sec_current, sec_current*0.8, sec_current*0.623, 0.1, img_overview)
	end
end

client.hook_tick = h_tick_init
client.hook_key = h_key
client.hook_mouse_button = h_mouse_button
client.hook_mouse_motion = h_mouse_motion
client.hook_window_activate = h_window_activate

function client.hook_kick(reason)
	print("Kicked - "..reason)
	function client.hook_tick()
		client.mouse_lock_set(false)
		client.mouse_visible_set(true)
		return 0.01
	end
	function client.hook_key(sym, state, modif, uni)
		if state and key == BTSK_QUIT then
			client.hook_tick = nil
		end
	end
	local old_render = client.hook_render
	local new_render = nil
	function new_render_fn(...)
		client.hook_render = old_render
		local ret = client.hook_render(...)
		old_render = client.hook_render
		client.hook_render = new_render
		font_large.print(30, 30, 0xFFAA0000, "KICKED")
		font_mini.print(30, 65, 0xFFAA0000, reason)
	end
	new_render = new_render_fn
	client.hook_render = new_render
end

print("pkg/base/client_start.lua: Loading mods...")
load_mod_list(getfenv(), nil, {"load", "load_client"}, client_config)
print("pkg/base/client_start.lua loaded.")


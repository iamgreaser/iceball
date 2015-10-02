dofile("pkg/gm/abos/common.lua")
dofile("pkg/gm/abos/genmap.lua")
dofile("pkg/gm/abos/player.lua")
dofile("pkg/iceball/lib/sdlkey.lua")

client.mk_compat_disable()
client.mk_set_title("A Buttfull Of Skateboards")

render_sec_current = 0

mouse_x, mouse_y = client.screen_get_dims()
mouse_x = mouse_x / 2
mouse_y = mouse_y / 2

client.map_enable_autorender(false)
client.map_enable_ao(false)
client.map_enable_side_shading(false)

img_funbox = common.img_load("pkg/gm/abos/funbox.png", "png")
img_genbox = common.img_load("pkg/gm/abos/genbox.png", "png")
img_ramp = common.img_load("pkg/gm/abos/ramp.png", "png")

function load_shaders()
	shader_main, result = client.glsl_create([==[
		#version 120
		varying vec4 vnorm;
		varying vec4 vpos;

		void main()
		{
			vpos = gl_ModelViewMatrix * gl_Vertex;
			gl_Position = gl_ProjectionMatrix * vpos;
			gl_FrontColor = vec4(1.0);//gl_Color;
			gl_TexCoord[0] = gl_MultiTexCoord0;
			vnorm = gl_ModelViewMatrix * vec4(gl_Normal, 0.0);
		}

	]==], [==[
		#version 120
		varying vec4 vnorm;
		varying vec4 vpos;
		uniform sampler2D smp0;

		void main()
		{
			float amb_fac = 0.2;
			float diff_fac = max(0.0, min(1.0,
				-dot(normalize(vnorm), normalize(vpos))
				));
			float diff = amb_fac + (diff_fac * (1.0 - amb_fac));
			vec4 ct0 = texture2D(smp0, gl_TexCoord[0].st);
			gl_FragColor = (gl_Color * ct0) * diff;
			gl_FragColor.a = 1.0;
		}

	]==], {})
	print(result)

	shader_player, result = client.glsl_create([==[
		#version 120
		varying vec4 vnorm;
		varying vec4 vpos;

		void main()
		{
			vpos = gl_ModelViewMatrix * gl_Vertex;
			gl_Position = gl_ProjectionMatrix * vpos;
			gl_FrontColor = gl_Color;
			gl_TexCoord[0] = gl_MultiTexCoord0;
			vnorm = gl_ModelViewMatrix * vec4(gl_Normal, 0.0);
		}

	]==], [==[
		#version 120
		varying vec4 vnorm;
		varying vec4 vpos;

		void main()
		{
			float amb_fac = 0.2;
			float diff_fac = max(0.0, min(1.0,
				-dot(normalize(vnorm), normalize(vpos))
				));
			float diff = amb_fac + (diff_fac * (1.0 - amb_fac));
			gl_FragColor = gl_Color * diff;
			gl_FragColor.a = 1.0;
		}

	]==], {})
	print(result)
end

do
	local l = {}
	local a = 1.0
	local al = 0.4
	local x0 = math.sin(0*math.pi*2.0/3.0)*a
	local y0 = math.cos(0*math.pi*2.0/3.0)*a
	local x1 = math.sin(1*math.pi*2.0/3.0)*a
	local y1 = math.cos(1*math.pi*2.0/3.0)*a
	local x2 = math.sin(2*math.pi*2.0/3.0)*a
	local y2 = math.cos(2*math.pi*2.0/3.0)*a
	l[1+#l] = {x0, y0, 0, 1, 0, 0, al}
	l[1+#l] = {x2, y2, 0, 1, 0, 0, al}
	l[1+#l] = {x1, y1, 0, 1, 0, 0, al}
	va_tri_red = common.va_make(l, nil, "3v,4c")
end

player = player_new {
	pos = {0, 0.5, 0},
}

function client.hook_tick(sec_current, sec_delta)
	render_sec_current = sec_current
	player.move(sec_current, sec_delta)
	--return math.max(0.001, math.min(0.02, 0.02*2.0 - sec_delta))
	return 0.0001
end

function h_render_main()
	local screen_w, screen_h = client.screen_get_dims()
	local smx = -(mouse_x-screen_w/2)/screen_w*2.0
	local smy = (mouse_y-screen_h/2)/screen_w*2.0
	local ra = render_sec_current * math.pi*2.0 / 3.0 * 3.0

	-- render shit
	client.camera_move_to(player.pos.x, player.pos.y, player.pos.z)
	local fwx = math.sin(player.ya)--*math.cos(player.xa)
	local fwy = 0.5--math.sin(player.xa)
	local fwz = math.cos(player.ya)--*math.cos(player.xa)
	fwx = player.vel.x
	--fwy = player.vel.y
	fwz = player.vel.z
	print(fwx, fwz)
	local fwid2 = 1.0/math.max(0.0001, math.sqrt(fwx*fwx + fwz*fwz))
	fwx = fwx * fwid2
	fwz = fwz * fwid2
	local fwd = math.sqrt(fwx*fwx + fwy*fwy + fwz*fwz)
	if fwid2 > 2.0 then
		fwx = math.sin(player.ya)
		fwz = math.cos(player.ya)
		fwd = math.sqrt(fwx*fwx + fwy*fwy + fwz*fwz)
		print(fwx, fwy, fwz)
	end
	local fwid = 1.0/math.max(0.001, fwd)
	fwx = fwx * fwid
	fwy = fwy * fwid
	fwz = fwz * fwid
	client.camera_point_sky(fwx, fwy, fwz, 1.0, 0, -1, 0) 
	client.camera_move_local(0, 0, -5)
	client.glsl_use(shader_main)
	lev_current.render()
	client.glsl_use(shader_player)
	player.render()

	-- render mouse
	--[[
	client.gfx_clear_depth()
	local wgx = smx
	local wgy = smy
	local xi, xf = math.modf(wgx)
	local yi, yf = math.modf(wgy)
	xi = xi % 32.0
	yi = yi % 32.0
	wgz = -4.0
	client.va_render_global(va_tri_red, wgx, wgy, wgz, math.pi/2.0, ra, -math.pi/2.0, 0.2,
		nil, "ah")
	]]
end

function h_render_init()
	client.hook_render = h_render_main
	client.map_fog_set(0, 0, 85, 200)
	client.camera_move_to(0, -1, -10)
	client.camera_point_sky(0, 1, 2, 1.0, 0, -1, 0) 
	load_shaders()
	lev_current = genmap_default()
end

function client.hook_kick(reason)
	print("KICKED", tostring(reason))
	client.hook_tick = nil
end

function client.hook_key(key, state, modif, uni)
	if false then
	elseif key == SDLK_UP  then player.rot_xaneg = state
	elseif key == SDLK_DOWN then player.rot_xapos = state
	elseif key == SDLK_LEFT  then player.rot_yaneg = state
	elseif key == SDLK_RIGHT then player.rot_yapos = state
	elseif key == SDLK_SPACE then player.do_jump = state
	end
end

function client.hook_mouse_button(button, state)
end

function client.hook_mouse_motion(mx, my, dx, dy)
	mouse_x = mx
	mouse_y = my
end

client.hook_render = h_render_init

print(anytostring(common.version))


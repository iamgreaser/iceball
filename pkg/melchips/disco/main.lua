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

-- shader
if client then
	disco_shader_world = USE_GLSL and shader_new{name="world_diff_disco", vert=[=[
	// Vertex shader

	varying vec4 cpos;
	varying vec4 wpos;
	varying vec4 wnorm;
	varying float fogmul;
	uniform float time;

	void main()
	{
		wpos = gl_Vertex;
		cpos = (gl_ModelViewMatrixInverse * vec4(0.0, 0.0, 0.0, 1.0));
		wnorm = vec4(normalize(gl_Normal), 0.0);
		fogmul = 1.0 / (length(gl_ModelViewMatrixInverse * vec4(0.0, 0.0, -1.0, 0.0)) * gl_Fog.end);

		gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * wpos;
		gl_FrontColor = gl_Color;
		//gl_TexCoord[0] = (gl_MultiTexCoord0 * 64.0 + vec4(64.0*4.0, 64.0*4.0, 0.0, 0.0))/512.0;
		gl_TexCoord[0] = vec4(
			dot(wpos.xyz, gl_Normal.yzx)/16.0,
			dot(wpos.xyz, gl_Normal.zxy)/16.0,
			0.0, 0.0);
		gl_TexCoord[0] -= vec4(ivec4(gl_TexCoord[0]));
	}

	]=], frag=[=[
	// Fragment shader

	varying vec4 cpos;
	varying vec4 wpos;
	varying vec4 wnorm;
	varying float fogmul;

	uniform vec4 sun;
	uniform sampler2D tex0;
	uniform vec2 map_idims;
	uniform float time;

	const vec4 dcentre = vec4(256.0, -256.0, 256.0, 1.0);

	void main()
	{
		float fog_strength = min(1.0, length((wpos - cpos).xyz) * fogmul);
		fog_strength *= fog_strength;

		vec4 color = gl_Color;
		vec4 camto = vec4(normalize((wpos - cpos).xyz), 0.0);

		// Diffuse
		float diff = max(0.0, dot(-camto, wnorm));
		diff = 0.2 + 0.5*diff;

		// Sky shadow
		vec4 owpos = wpos + wnorm*0.001;
		owpos.x -= 0.5;
		owpos.z -= 0.5;
		vec2 subpos1 = sin((fract(owpos.xz)*2.0-1.0)*3.141593/2.0)*0.5+0.5;
		vec2 subpos0 = 1.0 - subpos1;
		float t00 = texture2D(tex0, (owpos.xz + vec2(0.01,  0.01)) * map_idims).b * 255.0;
		float t01 = texture2D(tex0, (owpos.xz + vec2(0.01,  0.99)) * map_idims).b * 255.0;
		float t10 = texture2D(tex0, (owpos.xz + vec2(0.99,  0.01)) * map_idims).b * 255.0;
		float t11 = texture2D(tex0, (owpos.xz + vec2(0.99,  0.99)) * map_idims).b * 255.0;
		t00 = (owpos.y < t00 ? 1.0 : 0.0)*subpos0.x*subpos0.y;
		t01 = (owpos.y < t01 ? 1.0 : 0.0)*subpos0.x*subpos1.y;
		t10 = (owpos.y < t10 ? 1.0 : 0.0)*subpos1.x*subpos0.y;
		t11 = (owpos.y < t11 ? 1.0 : 0.0)*subpos1.x*subpos1.y;
		float ddiff = 1.2*(t00+t01+t10+t11);

		// Disco lighting
		vec4 ball_rel = normalize(wpos - dcentre);
		vec2 ball_uv = ball_rel.xz*512.0;
		float stime = time * 0.03;
		ball_uv = vec2(
			ball_uv.x*sin(stime) + ball_uv.y*cos(stime),
			ball_uv.x*cos(stime) - ball_uv.y*sin(stime));
		ball_uv = fract(ball_uv*0.5);
		ball_uv -= 0.5;
		ball_uv *= 2.0*2.5;
		ddiff *= sqrt(max(0.0, 1.0 - dot(ball_uv, ball_uv)));

		// Specular
		// disabling until it makes sense
		/*
		vec4 specdir = normalize(2.0*dot(wnorm, -sun)*wnorm - -sun);
		float spec = max(0.0, dot(-camto, specdir));
		spec = pow(spec, 32.0)*0.6;
		*/

		diff = diff * (1.0 - fog_strength);
		diff = min(1.5, diff);
		color = vec4(color.rgb * diff, color.a);
		color += vec4(color.rgb * gl_Fog.color.rgb * ddiff, 0.0);
		color = max(vec4(0.0), min(vec4(1.0), color));
		//color = vec4(0.5+0.5*sin(3.141593*(color.rgb-0.5)), color.a);

		gl_FragColor = color * (1.0 - fog_strength)
			+ gl_Fog.color * fog_strength;
	}
	]=]}
end

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
				if shader_world and disco_shader_world and shader_world == disco_shader_world then
					shader_world.pop()
					shader_world = disco_old_shader_world
					shader_world.push()
				end
				client.mus_stop()
				disco_status = DISCO_DISABLED
				client.map_fog_set(original_fog_color[1], original_fog_color[2], original_fog_color[3], original_fog_distance)
			end
		elseif state == DISCO_ENABLED then
			if disco_status == DISCO_DISABLED then
				if shader_world and disco_shader_world and shader_world ~= disco_shader_world then
					disco_old_shader_world = shader_world
					shader_world.pop()
					shader_world = disco_shader_world
					shader_world.push()
				end
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

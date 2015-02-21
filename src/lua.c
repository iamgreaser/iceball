/*
    This file is part of Iceball.

    Iceball is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Iceball is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Iceball.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "common.h"

struct icelua_entry {
	int (*fn) (lua_State *L);
	char *name;
};

lua_State *lstate_client = NULL;
lua_State *lstate_server = NULL;

struct icelua_whitelist {
	char *addr;
	int port;
};

struct icelua_whitelist *raw_whitelist = NULL; int raw_whitelist_len = 0;

int bin_storage_allowed = 0;

int whitelist_validate(const char *name, int port)
{
	if(name == NULL || port == 0 || port == -1)
		return 0;

	int i;

	for(i = 0; i < raw_whitelist_len; i++)
		if(!strcmp(raw_whitelist[i].addr, name) && (raw_whitelist[i].port == -1 || port == raw_whitelist[i].port))
			return 1;

	return 0;
}

// helper functions
int icelua_assert_stack(lua_State *L, int smin, int smax)
{
	int top = lua_gettop(L);

	if(smin != -1 && top < smin)
		return luaL_error(L, "expected at least %d arguments, got %d", smin, top);
	if(smax != -1 && top > smax)
		return luaL_error(L, "expected at most %d arguments, got %d", smax, top);

	return top;
}

int icelua_force_get_integer(lua_State *L, int table, char *name)
{
	lua_getfield(L, table, name);

	if(!lua_isnumber(L, -1))
		return luaL_error(L, "expected integer for \"%s\", got something else", name);

	int ret = lua_tointeger(L, -1);
	lua_pop(L, 1);

	return ret;
}

// To be moved. Maybe.
int icelua_fn_common_mk_compat_disable(lua_State *L)
{
	mk_compat_mode = 0;
	return 0;
}
#ifndef DEDI
int icelua_fn_client_mk_sys_execv(lua_State *L)
{
	if((boot_mode & 3) != 3 || net_port != 0)
		return luaL_error(L, "mk_sys_execv called when not in -s 0 mode");

	int top = lua_gettop(L);
	char **arglist = malloc(sizeof(char *) * (top+2));
	int i;

	for(i = 1; i <= top; i++)
		arglist[i] = strdup(lua_tostring(L, i));

	arglist[0] = strdup(main_argv0);
	arglist[top+1] = NULL;

	SDL_Quit();
#ifdef WIN32
#if 1
	//if(main_oldcwd != NULL)
	//	_chdir(main_oldcwd);
	
	char cwd[2048] = "";
	GetModuleFileName(NULL, cwd, 2047);
	char *v = cwd + strlen(cwd) - 1;
	while (v >= cwd)
	{
		if (*v == '\\')
		{
			v++;
			break;
		}
		v--;
	}
	arglist[0] = v;
	
	for (i = 0; i <= top; i++)
	{
		int new_size = strlen(arglist[i]) + 3;
		int j;
		for (j = 0; j < strlen(arglist[i]); j++)
		{
			if (arglist[i][j] == '"' || arglist[i][j] == '\\')
				new_size++;
		}
		char *new_arg = malloc(new_size);
		char *k = new_arg;
		char *l = arglist[i];
		*(k++) = '"';
		while (*l != 0)
		{
			if (*l == '"' || *l == '\\')
				*(k++) = '\\';
			*(k++) = *(l++);
		}
		*(k++) = '"';
		*(k++) = 0;
		arglist[i] = new_arg;
	}
	/*FILE *fp = fopen("FUCK.txt", "w");
	for (i = 0; i <= top; i++)
	{
		fprintf(fp, "%s ", arglist[i]);
		fflush(fp);
	}*/
#else
	char *v = strdup("iceball.exe");
	arglist[0] = v;
	main_argv0 = v;
#endif
#endif
	printf("argv0: [%s]\n", main_argv0);
	fflush(stdout);
#ifdef WIN32
	execv(v, arglist);
#else
	execv(main_argv0, arglist);
#endif
	printf("WORK YOU FUCKASS: %s\n", strerror(errno));
	fflush(stdout);

	// DOES NOT RETURN.
	fprintf(stderr, "ABORT: sys_execv must not return!\n");
	fflush(stderr);
	abort();
	return 0;
}

extern char mk_app_title[];
int icelua_fn_client_mk_set_title(lua_State *L)
{
	int top = icelua_assert_stack(L, 1, 1);
	const char *title = lua_tostring(L, 1);

	strncpy(mk_app_title, title, 128);
	mk_app_title[127] = '\x00';

	return 0;
}
#endif

#include "lua_fetch.h"

#include "lua_base.h"
#include "lua_bin.h"
#include "lua_camera.h"
#include "lua_gfx.h"
#include "lua_glsl.h"
#include "lua_image.h"
#include "lua_input.h"
#include "lua_json.h"
#include "lua_map.h"
#include "lua_mus.h"
#include "lua_model.h"
#include "lua_net.h"
#include "lua_tcp.h"
#include "lua_udp.h"
#include "lua_util.h"
#include "lua_wav.h"
#include "lua_va.h"

// common functions

// client functions

// server functions

#ifndef DEDI
struct icelua_entry icelua_client[] = {
	{icelua_fn_client_mk_set_title, "mk_set_title"},
	{icelua_fn_client_mk_sys_execv, "mk_sys_execv"},

	{icelua_fn_client_mouse_lock_set, "mouse_lock_set"},
	{icelua_fn_client_mouse_visible_set, "mouse_visible_set"},
	{icelua_fn_client_mouse_visible_set, "mouse_visible_set"},
	{icelua_fn_client_mouse_warp, "mouse_warp"},
	{icelua_fn_client_map_fog_get, "map_fog_get"},
	{icelua_fn_client_map_fog_set, "map_fog_set"},
	{icelua_fn_client_camera_point, "camera_point"},
	{icelua_fn_client_camera_point_sky, "camera_point_sky"},
	{icelua_fn_client_camera_move_local, "camera_move_local"},
	{icelua_fn_client_camera_move_global, "camera_move_global"},
	{icelua_fn_client_camera_move_to, "camera_move_to"},
	{icelua_fn_client_camera_get_pos, "camera_get_pos"},
	{icelua_fn_client_camera_get_forward, "camera_get_forward"},
	{icelua_fn_client_camera_shading_set, "camera_shading_set"},
	{icelua_fn_client_screen_get_dims, "screen_get_dims"},
	{icelua_fn_client_gfx_alpha_test, "gfx_alpha_test"},
	{icelua_fn_client_gfx_clear_depth, "gfx_clear_depth"},
	{icelua_fn_client_gfx_depth_mask, "gfx_depth_mask"},
	{icelua_fn_client_gfx_depth_test, "gfx_depth_test"},
	{icelua_fn_client_gfx_stencil_test, "gfx_stencil_test"},
	{icelua_fn_client_gfx_stencil_op, "gfx_stencil_op"},
	{icelua_fn_client_gfx_stencil_func, "gfx_stencil_func"},
	{icelua_fn_client_gfx_tex_available, "gfx_tex_available"},
	{icelua_fn_client_gfx_glsl_available, "gfx_glsl_available"},
	{icelua_fn_client_glsl_create, "glsl_create"},
	{icelua_fn_client_glsl_use, "glsl_use"},
	{icelua_fn_client_glsl_get_uniform_loc, "glsl_get_uniform_loc"},
	{icelua_fn_client_glsl_set_uniform_f, "glsl_set_uniform_f"},
	{icelua_fn_client_glsl_set_uniform_i, "glsl_set_uniform_i"},
	{icelua_fn_client_glsl_set_uniform_ui, "glsl_set_uniform_ui"},
	{icelua_fn_client_model_render_bone_global, "model_render_bone_global"},
	{icelua_fn_client_model_render_bone_local, "model_render_bone_local"},
	{icelua_fn_client_img_blit, "img_blit"},
	{icelua_fn_client_img_blit_to, "img_blit_to"},
	{icelua_fn_client_wav_cube_size, "wav_cube_size"},
	{icelua_fn_client_wav_play_global, "wav_play_global"},
	{icelua_fn_client_wav_play_local, "wav_play_local"},
	{icelua_fn_client_wav_chn_exists, "wav_chn_exists"},
	{icelua_fn_client_wav_chn_update, "wav_chn_update"},
	{icelua_fn_client_va_render_global, "va_render_global"},
	{icelua_fn_client_va_render_local, "va_render_local"},
	{icelua_fn_client_wav_kill, "wav_kill"},
	{icelua_fn_client_mus_play, "mus_play"},
	{icelua_fn_client_mus_stop, "mus_stop"},
	{icelua_fn_client_mus_vol_set, "mus_vol_set"},
	{NULL, NULL}
};
#endif

struct icelua_entry icelua_server[] = {
	{NULL, NULL}
};
struct icelua_entry icelua_common[] = {
	{icelua_fn_common_mk_compat_disable, "mk_compat_disable"},

	{icelua_fn_common_fetch_start, "fetch_start"},
	{icelua_fn_common_fetch_poll, "fetch_poll"},
	{icelua_fn_common_fetch_block, "fetch_block"},
	{icelua_fn_common_map_load, "map_load"},
	{icelua_fn_common_map_new, "map_new"},
	{icelua_fn_common_map_free, "map_free"},
	{icelua_fn_common_map_get, "map_get"},
	{icelua_fn_common_map_set, "map_set"},
	{icelua_fn_common_map_save, "map_save"},
	{icelua_fn_common_map_get_dims, "map_get_dims"},
	{icelua_fn_common_map_pillar_get, "map_pillar_get"},
	{icelua_fn_common_map_pillar_set, "map_pillar_set"},
	{icelua_fn_common_map_mapents_get, "map_mapents_get"},
	{icelua_fn_common_map_mapents_set, "map_mapents_set"},
	{icelua_fn_common_model_new, "model_new"},
	{icelua_fn_common_model_load_pmf, "model_load_pmf"},
	{icelua_fn_common_model_save_pmf, "model_save_pmf"},
	{icelua_fn_common_model_free, "model_free"},
	{icelua_fn_common_model_len, "model_len"},
	{icelua_fn_common_model_bone_new, "model_bone_new"},
	{icelua_fn_common_model_bone_free, "model_bone_free"},
	{icelua_fn_common_model_bone_get, "model_bone_get"},
	{icelua_fn_common_model_bone_set, "model_bone_set"},
	{icelua_fn_common_model_bone_find, "model_bone_find"},
	{icelua_fn_common_img_load, "img_load"},
	{icelua_fn_common_img_new, "img_new"},
	{icelua_fn_common_img_pixel_set, "img_pixel_set"},
	{icelua_fn_common_img_pixel_get, "img_pixel_get"},
	{icelua_fn_common_img_fill, "img_fill"},
	{icelua_fn_common_img_free, "img_free"},
	{icelua_fn_common_img_get_dims, "img_get_dims"},
	{icelua_fn_common_json_parse, "json_parse"},
	{icelua_fn_common_json_load, "json_load"},
	{icelua_fn_common_json_write, "json_write"},
	{icelua_fn_common_net_pack, "net_pack"},
	{icelua_fn_common_net_unpack, "net_unpack"},
	{icelua_fn_common_net_send, "net_send"},
	{icelua_fn_common_net_recv, "net_recv"},
	{icelua_fn_common_tcp_connect, "tcp_connect"},
	{icelua_fn_common_tcp_send, "tcp_send"},
	{icelua_fn_common_tcp_recv, "tcp_recv"},
	{icelua_fn_common_tcp_close, "tcp_close"},
	{icelua_fn_common_udp_open, "udp_open"},
	{icelua_fn_common_udp_sendto, "udp_sendto"},
	{icelua_fn_common_udp_recvfrom, "udp_recvfrom"},
	{icelua_fn_common_udp_close, "udp_close"},
	{icelua_fn_common_wav_load, "wav_load"},
	{icelua_fn_common_wav_free, "wav_free"},
	{icelua_fn_common_mus_load_it, "mus_load_it"},
	{icelua_fn_common_mus_free, "mus_free"},
	{icelua_fn_common_bin_load, "bin_load"},
	{icelua_fn_common_bin_save, "bin_save"},
	{icelua_fn_common_argb_split_to_merged, "argb_split_to_merged"},
	{icelua_fn_common_argb_merged_to_split, "argb_merged_to_split"},
	{icelua_fn_common_time, "time"},
	{icelua_fn_common_va_make, "va_make"},

	{NULL, NULL}
};

#ifndef DEDI
struct icelua_entry icelua_common_client[] = {
	{NULL, NULL}
};
#endif

struct icelua_entry icelua_common_server[] = {
	{icelua_fn_server_net_kick, "net_kick"},
	{NULL, NULL}
};

void icelua_loadfuncs(lua_State *L, char *table, struct icelua_entry *fnlist)
{
	if(L == NULL)
		return;

	lua_getglobal(L, table);

	while(fnlist->fn != NULL)
	{
		lua_pushcfunction(L, fnlist->fn);
		lua_setfield (L, -2, fnlist->name);
		fnlist++;
	}

	lua_pop(L, 1);
}

void icelua_loadbasefuncs(lua_State *L)
{
	if(L == NULL)
		return;

	// load base library
	// TODO: whitelist the functions by spawning a new environment.
	// this is harder than it sounds.
	lua_pushcfunction(L, luaopen_base);
	lua_call(L, 0, 0);

	// here's the other three
	lua_pushcfunction(L, luaopen_string);
	lua_call(L, 0, 0);
	lua_pushcfunction(L, luaopen_math);
	lua_call(L, 0, 0);
	lua_pushcfunction(L, luaopen_table);
	lua_call(L, 0, 0);

	// overwrite dofile/loadfile.
	lua_pushcfunction(L, icelua_fn_base_loadfile);
	lua_setglobal(L, "loadfile");
	lua_pushcfunction(L, icelua_fn_base_dofile);
	lua_setglobal(L, "dofile");
}

int icelua_initfetch(void)
{
	int i;
	char xpath[128+1];
	int argct = (main_largstart == -1 || (main_largstart >= main_argc)
		? 0
		: main_argc - main_largstart);

	if(to_client_local.sockfd == -1)
		to_client_local.sockfd = SOCKFD_LOCAL;

	lua_getglobal(lstate_client, "client");
	lua_pushstring(lstate_client, mod_basedir+4);
	lua_setfield(lstate_client, -2, "base_dir");
	lua_pop(lstate_client, 1);

	lua_getglobal(lstate_client, "common");
	lua_pushstring(lstate_client, mod_basedir+4);
	lua_setfield(lstate_client, -2, "base_dir");
	lua_pop(lstate_client, 1);

	lua_getglobal(lstate_client, "client");
	lua_pushstring(lstate_client, "gl"); // Only one renderer now. -mk<3
	lua_setfield(lstate_client, -2, "renderer");
	lua_pop(lstate_client, 1);

	snprintf(xpath, 128, "%s/main_client.lua", mod_basedir);
	lua_pushcfunction(lstate_client, icelua_fn_common_fetch_block);
	lua_pushstring(lstate_client, "lua");
	lua_pushstring(lstate_client, xpath);
	printf("Now loading client; please wait! [%s]\n", xpath);
	if(lua_pcall(lstate_client, 2, 1, 0) != 0)
	{
		printf("ERROR fetching client Lua: %s\n", lua_tostring(lstate_client, -1));
		lua_pop(lstate_client, 1);
		return 1;
	}

	printf("Client loaded! Initialising...\n");
	for(i = 0; i < argct; i++)
		lua_pushstring(lstate_client, main_argv[i+main_largstart]);
	if((boot_mode & 1) && net_addr_xbuf[1] != '\x00')
	{
		lua_pushstring(lstate_client, net_addr_xbuf);
		argct++;
	}
	if(lua_pcall(lstate_client, argct, 0, 0) != 0)
	{
		printf("ERROR running client Lua: %s\n", lua_tostring(lstate_client, -1));
		lua_pop(lstate_client, 1);
		return 1;
	}

	printf("Done!\n");
	boot_mode |= 4;

	return 0;
}

void icelua_pushversion(lua_State *L, const char *tabname)
{
	char vbuf[32];

	snprintf(vbuf, 31, "%i.%i", VERSION_W, VERSION_X);
	if(VERSION_Y != 0)
		snprintf(vbuf+strlen(vbuf), 31-strlen(vbuf), ".%i", VERSION_Y);
	if(VERSION_A != 0)
		snprintf(vbuf+strlen(vbuf), 31-strlen(vbuf), "%c", VERSION_A+96);
	if(VERSION_Z != 0)
		snprintf(vbuf+strlen(vbuf), 31-strlen(vbuf), "-%i", VERSION_Z);

	lua_getglobal(L, tabname);

	lua_newtable(L);

	lua_pushstring(L, vbuf);
	lua_setfield(L, -2, "str");

	lua_pushinteger(L, 
		(((((((VERSION_W<<5) + VERSION_X
		)<<7) + VERSION_Y
		)<<5) + VERSION_A
		)<<10) + VERSION_Z);
	lua_setfield(L, -2, "num");

	lua_newtable(L);
	lua_pushinteger(L, 1); lua_pushinteger(L, VERSION_W); lua_settable(L, -3);
	lua_pushinteger(L, 2); lua_pushinteger(L, VERSION_X); lua_settable(L, -3);
	lua_pushinteger(L, 3); lua_pushinteger(L, VERSION_Y); lua_settable(L, -3);
	lua_pushinteger(L, 4); lua_pushinteger(L, VERSION_A); lua_settable(L, -3);
	lua_pushinteger(L, 5); lua_pushinteger(L, VERSION_Z); lua_settable(L, -3);
	lua_setfield(L, -2, "cmp");

	lua_setfield(L, -2, "version");

	// -mk<3
	lua_newtable(L);
	lua_pushinteger(L, MK_REVISION);
	lua_setfield(L, -2, "num");
	lua_setfield(L, -2, "fork_marikiri_ver");

	lua_pop(L, 1);
}

int icelua_init(void)
{
	int i, argct;

	// create states
	if(boot_mode & 1)
	{
		// create temp state for loading config
		lua_State *Lc = luaL_newstate();
		int v;
		float f;

		// load config
#ifndef DEDI
		if(!json_load(Lc, "clsave/config.json"))
		{
			// set video stuff 
			lua_getfield(Lc, -1, "video");

			lua_getfield(Lc, -1, "width");
			v = lua_tointeger(Lc, -1);
			if(v >= 0) screen_width = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "height");
			v = lua_tointeger(Lc, -1);
			if(v >= 0) screen_height = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "cubeshift");
			v = lua_tointeger(Lc, -1);
			if(v != 0) screen_cubeshift = -v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "antialiasinglevel");
			v = lua_tointeger(Lc, -1);
			if(v >= 0) screen_antialiasing_level = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "smoothlighting");
			v = lua_toboolean(Lc, -1);
			if(!lua_isnil(Lc, -1)) screen_smooth_lighting = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "gl_vsync");
			v = lua_toboolean(Lc, -1);
			if(v >= 0) gl_vsync = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "gl_quality");
			v = lua_tointeger(Lc, -1);
			if(v >= 0) gl_quality = v;
			lua_pop(Lc, 1);

			// backwards compatibility
			lua_getfield(Lc, -1, "vbo");
			v = lua_toboolean(Lc, -1);
			if(!lua_isnil(Lc, -1)) {
				gl_use_vbo = v;
				printf("WARNING: clsave/config.json: \"vbo\" is deprecated - use \"gl_vbo\" instead\n");
			}
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "gl_vbo");
			v = lua_toboolean(Lc, -1);
			if(!lua_isnil(Lc, -1)) gl_use_vbo = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "gl_flip_quads");
			v = lua_toboolean(Lc, -1);
			if(!lua_isnil(Lc, -1)) gl_flip_quads = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "gl_frustum_cull");
			v = lua_toboolean(Lc, -1);
			if(!lua_isnil(Lc, -1)) gl_frustum_cull = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "gl_occlusion_cull");
			v = lua_tointeger(Lc, -1);
			if(!lua_isnil(Lc, -1)) gl_occlusion_cull = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "gl_expand_textures");
			v = lua_toboolean(Lc, -1);
			if(!lua_isnil(Lc, -1)) gl_expand_textures = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "gl_chunk_size");
			v = lua_tointeger(Lc, -1);
			if(v > 0) gl_chunk_size = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "gl_visible_chunks");
			v = lua_tointeger(Lc, -1);
			if(v > 0) gl_visible_chunks = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "gl_chunks_tesselated_per_frame");
			v = lua_tointeger(Lc, -1);
			if(v > 0) gl_chunks_tesselated_per_frame = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "gl_shaders");
			v = lua_toboolean(Lc, -1);
			if(v >= 0) gl_shaders = v;
			lua_pop(Lc, 1);


			lua_getfield(Lc, -1, "fullscreen");
			v = lua_toboolean(Lc, -1);
			if(!lua_isnil(Lc, -1)) screen_fullscreen = v;
			lua_pop(Lc, 1);

			// drop table
			lua_pop(Lc, 1);

			// set audio stuff 
			lua_getfield(Lc, -1, "audio");

			lua_getfield(Lc, -1, "freq");
			v = lua_tointeger(Lc, -1);
			if(v >= 0) wav_mfreq = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "bufsize");
			v = lua_tointeger(Lc, -1);
			if(v >= 0) wav_bufsize = v;
			lua_pop(Lc, 1);

			lua_getfield(Lc, -1, "volume");
			f = lua_tonumber(Lc, -1);
			if(!lua_isnil(Lc, -1)) wav_gvol = f;
			lua_pop(Lc, 1);

			// drop table
			lua_pop(Lc, 1);

			// set security stuff 
			lua_getfield(Lc, -1, "security");

			lua_getfield(Lc, -1, "bin_storage_allowed");
			v = lua_toboolean(Lc, -1);
			if(!lua_isnil(Lc, -1)) bin_storage_allowed = v;
			lua_pop(Lc, 1);

			{
				if(lua_istable(Lc, -1))
					lua_getfield(Lc, -1, "raw_whitelist");
				else
					lua_newtable(Lc);

				// allocate whitelist
				raw_whitelist_len = lua_objlen(Lc, -1);
				raw_whitelist = malloc(sizeof(struct icelua_whitelist)*raw_whitelist_len);

				// read each entry
				for(i = 0; i < raw_whitelist_len; i++)
				{
					printf("entry %i/%i\n", i+1, raw_whitelist_len);
					// get entry
					lua_pushinteger(Lc, i+1);
					lua_gettable(Lc, -2);

					if(lua_istable(Lc, -1))
					{
						// check entries
						lua_pushinteger(Lc, 1);
						lua_gettable(Lc, -2);
						lua_pushinteger(Lc, 2);
						lua_gettable(Lc, -3);

						// check entries
						if(lua_isstring(Lc, -2) && lua_isnumber(Lc, -1))
						{
							raw_whitelist[i].addr = strdup(lua_tostring(Lc, -2));
							raw_whitelist[i].port = lua_tointeger(Lc, -1);
							printf("Whitelist entry %i/%i: \"%s\" port %i \n", i+1, raw_whitelist_len,
								raw_whitelist[i].addr, raw_whitelist[i].port);
						} else {
							// mark as invalid
							fprintf(stderr, "invalid entry %i/%i in whitelist!\n", i+1, raw_whitelist_len);
							raw_whitelist[i].addr = NULL;
						}

						// pop entries
						lua_pop(Lc, 2);
					} else {
						// mark as invalid
						fprintf(stderr, "invalid entry %i/%i in whitelist!\n", i+1, raw_whitelist_len);
						raw_whitelist[i].addr = NULL;
					}

					// pop entry
					lua_pop(Lc, 1);
				}

				// drop table
				lua_pop(Lc, 1);
			}

			// drop table
			lua_pop(Lc, 1);
		}
#endif
	}

	lstate_client = (boot_mode & 1 ? luaL_newstate() : NULL);
	lstate_server = (boot_mode & 2 ? luaL_newstate() : NULL);

	// create tables
	if(lstate_client != NULL)
	{
		lua_newtable(lstate_client);
		lua_setglobal(lstate_client, "client");
		lua_newtable(lstate_client);
		lua_setglobal(lstate_client, "common");
		lua_pushvalue(lstate_client, LUA_GLOBALSINDEX);
		lua_setglobal(lstate_client, "_G");
	}

	if(lstate_server != NULL)
	{
		lua_newtable(lstate_server);
		lua_setglobal(lstate_server, "server");
		lua_newtable(lstate_server);
		lua_setglobal(lstate_server, "common");
		lua_pushvalue(lstate_server, LUA_GLOBALSINDEX);
		lua_setglobal(lstate_server, "_G");
	}

	// load stuff into them
#ifndef DEDI
	icelua_loadfuncs(lstate_client, "client", icelua_client);
	icelua_loadfuncs(lstate_client, "client", icelua_common);
	icelua_loadfuncs(lstate_client, "common", icelua_common);
	icelua_loadfuncs(lstate_client, "client", icelua_common_client);
	icelua_loadfuncs(lstate_client, "common", icelua_common_client);
#endif
	icelua_loadfuncs(lstate_server, "server", icelua_server);
	icelua_loadfuncs(lstate_server, "server", icelua_common);
	icelua_loadfuncs(lstate_server, "common", icelua_common);
	icelua_loadfuncs(lstate_server, "server", icelua_common_server);
	icelua_loadfuncs(lstate_server, "common", icelua_common_server);

	// load some lua base libraries
	icelua_loadbasefuncs(lstate_client);
	icelua_loadbasefuncs(lstate_server);

	// shove some pathnames / versions in
	if(lstate_server != NULL)
	{
		lua_getglobal(lstate_server, "common");
		lua_getglobal(lstate_server, "server");
		lua_pushstring(lstate_server, mod_basedir+4);
		lua_setfield(lstate_server, -2, "base_dir");
		lua_pop(lstate_server, 1);
		lua_pushstring(lstate_server, mod_basedir+4);
		lua_setfield(lstate_server, -2, "base_dir");
		lua_pop(lstate_server, 1);

		icelua_pushversion(lstate_server, "common");
		icelua_pushversion(lstate_server, "server");

		lua_getglobal(lstate_server, "server");
		lua_pushinteger(lstate_server, net_port);
		lua_setfield(lstate_server, -2, "port");
		lua_pop(lstate_server, 1);
	}

	if(lstate_client != NULL)
	{
		icelua_pushversion(lstate_client, "common");
		icelua_pushversion(lstate_client, "client");
	}

	/*
	NOTE:
	to call stuff, use lua_pcall.
	DO NOT use lua_call! if it fails, it will TERMINATE the program!
	*/

	// quick test
	// TODO: set up a "convert/filter file path" function
	// TODO: split the client/server inits
	char xpath[128];
	snprintf(xpath, 128, "%s/main_server.lua", mod_basedir);

	if((lstate_server != NULL) && luaL_loadfile(lstate_server, xpath) != 0)
	{
		printf("ERROR loading server Lua: %s\n", lua_tostring(lstate_server, -1));
		return 1;
	}

	argct = (main_largstart == -1 || (main_largstart >= main_argc)
		? 0
		: main_argc - main_largstart);

	if(lstate_server != NULL)
	{
		for(i = 0; i < argct; i++)
			lua_pushstring(lstate_server, main_argv[i+main_largstart]);
		if(lua_pcall(lstate_server, argct, 0, 0) != 0)
		{
			printf("ERROR running server Lua: %s\n", lua_tostring(lstate_server, -1));
			lua_pop(lstate_server, 1);
			return 1;
		}
	}

	if(lstate_client != NULL && mod_basedir != NULL)
		if(icelua_initfetch())
			return 1;

	// dispatch initial connect
	if(lstate_server != NULL && lstate_client != NULL)
	{
		lua_getglobal(lstate_server, "server");
		lua_getfield(lstate_server, -1, "hook_connect");
		lua_remove(lstate_server, -2);
		if(!lua_isnil(lstate_server, -1))
		{
			lua_pushboolean(lstate_server, 1);
			lua_newtable(lstate_server);

			lua_pushstring(lstate_server, "local");
			lua_setfield(lstate_server, -2, "proto");
			lua_pushnil(lstate_server);
			lua_setfield(lstate_server, -2, "addr");

			if(lua_pcall(lstate_server, 2, 0, 0) != 0)
			{
				printf("ERROR running server Lua (hook_connect): %s\n", lua_tostring(lstate_server, -1));
				lua_pop(lstate_server, 2);
				return 1;
			}
		} else {
			lua_pop(lstate_server, 1);
		}
	}

	return 0;
}

void icelua_deinit(void)
{
	// TODO!
}


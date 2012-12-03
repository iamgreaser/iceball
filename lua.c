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

#include "lua_fetch.h"

#include "lua_base.h"
#include "lua_camera.h"
#include "lua_image.h"
#include "lua_input.h"
#include "lua_json.h"
#include "lua_map.h"
#include "lua_model.h"
#include "lua_net.h"

// common functions

// client functions

// server functions

struct icelua_entry icelua_client[] = {
	{icelua_fn_client_mouse_lock_set, "mouse_lock_set"},
	{icelua_fn_client_mouse_visible_set, "mouse_visible_set"},
	{icelua_fn_client_map_fog_get, "map_fog_get"},
	{icelua_fn_client_map_fog_set, "map_fog_set"},
	{icelua_fn_client_camera_point, "camera_point"},
	{icelua_fn_client_camera_move_local, "camera_move_local"},
	{icelua_fn_client_camera_move_global, "camera_move_global"},
	{icelua_fn_client_camera_move_to, "camera_move_to"},
	{icelua_fn_client_camera_get_pos, "camera_get_pos"},
	{icelua_fn_client_camera_get_forward, "camera_get_forward"},
	{icelua_fn_client_screen_get_dims, "screen_get_dims"},
	{icelua_fn_client_model_render_bone_global, "model_render_bone_global"},
	{icelua_fn_client_model_render_bone_local, "model_render_bone_local"},
	{icelua_fn_client_img_blit, "img_blit"},
	{NULL, NULL}
};

struct icelua_entry icelua_server[] = {
	{NULL, NULL}
};
struct icelua_entry icelua_common[] = {
	{icelua_fn_common_fetch_start, "fetch_start"},
	{icelua_fn_common_fetch_poll, "fetch_poll"},
	{icelua_fn_common_fetch_block, "fetch_block"},
	{icelua_fn_common_map_load, "map_load"},
	{icelua_fn_common_map_new, "map_new"},
	{icelua_fn_common_map_free, "map_free"},
	{icelua_fn_common_map_set, "map_set"},
	{icelua_fn_common_map_save, "map_save"},
	{icelua_fn_common_map_get_dims, "map_get_dims"},
	{icelua_fn_common_map_pillar_get, "map_pillar_get"},
	{icelua_fn_common_map_pillar_set, "map_pillar_set"},
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
	{icelua_fn_common_img_free, "img_free"},
	{icelua_fn_common_img_get_dims, "img_get_dims"},
	{icelua_fn_common_json_parse, "json_parse"},
	{icelua_fn_common_json_load, "json_load"},
	{icelua_fn_common_net_pack, "net_pack"},
	{icelua_fn_common_net_unpack, "net_unpack"},
	
	{NULL, NULL}
};

struct icelua_entry icelua_common_client[] = {
	{NULL, NULL}
};

struct icelua_entry icelua_common_server[] = {
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
	
	// here's the other two
	lua_pushcfunction(L, luaopen_string);
	lua_call(L, 0, 0);
	lua_pushcfunction(L, luaopen_math);
	lua_call(L, 0, 0);
	
	// overwrite dofile/loadfile.
	lua_pushcfunction(L, icelua_fn_base_loadfile);
	lua_setglobal(L, "loadfile");
	lua_pushcfunction(L, icelua_fn_base_dofile);
	lua_setglobal(L, "dofile");
}

int icelua_init(void)
{
	int i, argct;
	
	// create states
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
	icelua_loadfuncs(lstate_client, "client", icelua_client);
	icelua_loadfuncs(lstate_server, "server", icelua_server);
	icelua_loadfuncs(lstate_client, "client", icelua_common);
	icelua_loadfuncs(lstate_server, "server", icelua_common);
	icelua_loadfuncs(lstate_client, "common", icelua_common);
	icelua_loadfuncs(lstate_server, "common", icelua_common);
	icelua_loadfuncs(lstate_client, "client", icelua_common_client);
	icelua_loadfuncs(lstate_server, "server", icelua_common_server);
	icelua_loadfuncs(lstate_client, "common", icelua_common_client);
	icelua_loadfuncs(lstate_server, "common", icelua_common_server);
	
	// load some lua base libraries
	icelua_loadbasefuncs(lstate_client);
	icelua_loadbasefuncs(lstate_server);
	
	// shove some pathnames in
	{
		lua_getglobal(lstate_client, "common");
		lua_getglobal(lstate_client, "client");
		lua_pushstring(lstate_client, mod_basedir+4);
		lua_setfield(lstate_client, -2, "base_dir");
		lua_pop(lstate_client, 1);
		lua_pushstring(lstate_client, mod_basedir+4);
		lua_setfield(lstate_client, -2, "base_dir");
		lua_pop(lstate_client, 1);
		
		lua_getglobal(lstate_server, "common");
		lua_getglobal(lstate_server, "server");
		lua_pushstring(lstate_server, mod_basedir+4);
		lua_setfield(lstate_server, -2, "base_dir");
		lua_pop(lstate_server, 1);
		lua_pushstring(lstate_server, mod_basedir+4);
		lua_setfield(lstate_server, -2, "base_dir");
		lua_pop(lstate_server, 1);
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
	
	snprintf(xpath, 128, "%s/main_client.lua", mod_basedir);
	if((lstate_client != NULL) && luaL_loadfile(lstate_client, xpath) != 0)
	{
		printf("ERROR loading client Lua: %s\n", lua_tostring(lstate_client, -1));
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
		}
		lua_pop(lstate_server, 1);
	}
	
	if(lstate_client != NULL)
	{
		for(i = 0; i < argct; i++)
			lua_pushstring(lstate_client, main_argv[i+main_largstart]);
		if(lua_pcall(lstate_client, argct, 0, 0) != 0)
		{
			printf("ERROR running client Lua: %s\n", lua_tostring(lstate_client, -1));
			lua_pop(lstate_client, 1);
		}
		lua_pop(lstate_client, 1);
	}
	
	return 0;
}

void icelua_deinit(void)
{
	// TODO!
}


/*
    This file is part of Buld Then Snip.

    Buld Then Snip is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Buld Then Snip is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Buld Then Snip.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "common.h"

struct btslua_entry {
	int (*fn) (lua_State *L);
	char *name;
};

lua_State *lstate_client = NULL;
lua_State *lstate_server = NULL;

// helper functions
int btslua_assert_stack(lua_State *L, int smin, int smax)
{
	int top = lua_gettop(L);
	
	if(smin != -1 && top < smin)
		return luaL_error(L, "expected at least %i arguments, got %i\n", smin, top);
	if(smax != -1 && top > smax)
		return luaL_error(L, "expected at most %i arguments, got %i\n", smax, top);
	
	return top;
}

// common functions

// client functions
int btslua_fn_client_camera_point(lua_State *L)
{
	int top = btslua_assert_stack(L, 3, 5);
	float dx, dy, dz;
	float zoom = 1.0f, roll = 0.0f;
	
	dx = lua_tonumber(L, 1);
	dy = lua_tonumber(L, 2);
	dz = lua_tonumber(L, 3);
	if(top <= 4)
		zoom = lua_tonumber(L, 4);
	if(top <= 5)
		roll = lua_tonumber(L, 5);
	
	cam_point_dir(&tcam, dx, dy, dz, zoom, roll);
	
	return 0;
}

int btslua_fn_client_camera_move_local(lua_State *L)
{
	int top = btslua_assert_stack(L, 3, 3);
	float dx, dy, dz;
	
	dx = lua_tonumber(L, 1);
	dy = lua_tonumber(L, 2);
	dz = lua_tonumber(L, 3);
	
	tcam.mpx += dx*tcam.mxx+dy*tcam.myx+dz*tcam.mzx;
	tcam.mpy += dx*tcam.mxy+dy*tcam.myy+dz*tcam.mzy;
	tcam.mpz += dx*tcam.mxz+dy*tcam.myz+dz*tcam.mzz;

	return 0;
}

int btslua_fn_client_camera_move_global(lua_State *L)
{
	int top = btslua_assert_stack(L, 3, 3);
	float dx, dy, dz;
	
	dx = lua_tonumber(L, 1);
	dy = lua_tonumber(L, 2);
	dz = lua_tonumber(L, 3);
	
	tcam.mpx += dx;
	tcam.mpy += dy;
	tcam.mpz += dz;

	return 0;
}

int btslua_fn_client_camera_move_to(lua_State *L)
{
	int top = btslua_assert_stack(L, 3, 3);
	float px, py, pz;
	
	px = lua_tonumber(L, 1);
	py = lua_tonumber(L, 2);
	pz = lua_tonumber(L, 3);
	
	tcam.mpx = px;
	tcam.mpy = py;
	tcam.mpz = pz;

	return 0;
}

// server functions

struct btslua_entry btslua_client[] = {
	{btslua_fn_client_camera_point, "camera_point"},
	{btslua_fn_client_camera_move_local, "camera_move_local"},
	{btslua_fn_client_camera_move_global, "camera_move_global"},
	{btslua_fn_client_camera_move_to, "camera_move_to"},
	{NULL, NULL}
};

struct btslua_entry btslua_server[] = {
	{NULL, NULL}
};

struct btslua_entry btslua_common[] = {
	{NULL, NULL}
};

struct btslua_entry btslua_common_client[] = {
	{NULL, NULL}
};

struct btslua_entry btslua_common_server[] = {
	{NULL, NULL}
};

void btslua_loadfuncs(lua_State *L, char *table, struct btslua_entry *fnlist)
{
	lua_getglobal(L, table);
	
	while(fnlist->fn != NULL)
	{
		lua_pushcfunction(L, fnlist->fn);
		lua_setfield (L, -2, fnlist->name);
		fnlist++;
	}
	
	lua_pop(L, 1);
}

void btslua_loadbasefuncs(lua_State *L)
{
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
}

int btslua_init(void)
{
	// create states
	lstate_client = luaL_newstate();
	lstate_server = luaL_newstate();
	
	// create tables
	lua_newtable(lstate_client);
	lua_setglobal(lstate_client, "client");
	lua_newtable(lstate_client);
	lua_setglobal(lstate_client, "common");
	
	lua_newtable(lstate_server);
	lua_setglobal(lstate_server, "server");
	lua_newtable(lstate_server);
	lua_setglobal(lstate_server, "common");
	
	// load stuff into them
	btslua_loadfuncs(lstate_client, "client", btslua_client);
	btslua_loadfuncs(lstate_server, "server", btslua_server);
	btslua_loadfuncs(lstate_client, "client", btslua_common);
	btslua_loadfuncs(lstate_server, "server", btslua_common);
	btslua_loadfuncs(lstate_client, "common", btslua_common);
	btslua_loadfuncs(lstate_server, "common", btslua_common);
	btslua_loadfuncs(lstate_client, "client", btslua_common_client);
	btslua_loadfuncs(lstate_server, "server", btslua_common_server);
	btslua_loadfuncs(lstate_client, "common", btslua_common_client);
	btslua_loadfuncs(lstate_server, "common", btslua_common_server);
	
	// load some lua base libraries
	btslua_loadbasefuncs(lstate_client);
	btslua_loadbasefuncs(lstate_server);
	
	/*
	NOTE:
	to call stuff, use lua_pcall.
	DO NOT use lua_call! if it fails, it will TERMINATE the program!
	*/
	
	// quick test
	// TODO: set up a "convert/filter file path" function
	// TODO: split the client/server inits
	if(luaL_loadfile(lstate_server, "pkg/base/main_server.lua") != 0)
	{
		printf("ERROR loading server Lua: %s\n", lua_tostring(lstate_server, -1));
		return 1;
	}
	
	if(luaL_loadfile(lstate_client, "pkg/base/main_client.lua") != 0)
	{
		printf("ERROR loading client Lua: %s\n", lua_tostring(lstate_client, -1));
		return 1;
	}
	
	if(lua_pcall(lstate_server, 0, 0, 0) != 0)
	{
		printf("ERROR running server Lua: %s\n", lua_tostring(lstate_server, -1));
		lua_pop(lstate_server, 1);
	}
	lua_pop(lstate_server, 1);
	
	if(lua_pcall(lstate_client, 0, 0, 0) != 0)
	{
		printf("ERROR running client Lua: %s\n", lua_tostring(lstate_client, -1));
		lua_pop(lstate_client, 1);
	}
	lua_pop(lstate_client, 1);
	
	return 0;
}

void btslua_deinit(void)
{
	// TODO!
}


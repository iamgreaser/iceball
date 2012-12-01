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

void *cfetch_cbuf = NULL;
void *cfetch_ubuf = NULL;
int cfetch_clen = 0;
int cfetch_ulen = 0;
int cfetch_udtype = UD_INVALID;

void *sfetch_ubuf = NULL;
int sfetch_ulen = 0;
int sfetch_udtype = UD_INVALID;

// aux helpers
int icelua_fnaux_common_fetch_immediate(lua_State *L, const char *ftype, const char *fname)
{
	if(!strcmp(ftype, "lua"))
	{
		if(luaL_loadfile(L, fname) != 0)
			return luaL_error(L, "%s", lua_tostring(L, -1));
		
		return 1;
	} else if(!strcmp(ftype, "map")) {
		map_t *map = NULL;
		
		map = map_load_icemap(fname);
		if(map == NULL)
			map = map_load_aos(fname);
		
		lua_pushlightuserdata(L, map);
		return 1;
	} else if(!strcmp(ftype, "icemap")) {
		map_t *map = map_load_icemap(fname);
		
		lua_pushlightuserdata(L, map);
		return 1;
	} else if(!strcmp(ftype, "vxl")) {
		map_t *map = map_load_aos(fname);
		
		lua_pushlightuserdata(L, map);
		return 1;
	} else if(!strcmp(ftype, "pmf")) {
		model_t *pmf = model_load_pmf(fname);
		
		if(pmf == NULL)
			return 0;
		
		lua_pushlightuserdata(L, pmf);
		return 1;
	} else if(!strcmp(ftype, "tga")) {
		img_t *img = img_load_tga(fname);
		if(img == NULL)
			return 0;
		if(!strcmp(ftype, "lua"))
	{
		if(luaL_loadfile(L, fname) != 0)
			return luaL_error(L, "%s", lua_tostring(L, -1));
		
		return 1;
	} else if(!strcmp(ftype, "map")) {
		map_t *map = NULL;
		
		map = map_load_icemap(fname);
		if(map == NULL)
			map = map_load_aos(fname);
		
		lua_pushlightuserdata(L, map);
		return 1;
	} else if(!strcmp(ftype, "icemap")) {
		map_t *map = map_load_icemap(fname);
		
		lua_pushlightuserdata(L, map);
		return 1;
	} else if(!strcmp(ftype, "vxl")) {
		map_t *map = map_load_aos(fname);
		
		lua_pushlightuserdata(L, map);
		return 1;
	} else if(!strcmp(ftype, "pmf")) {
		model_t *pmf = model_load_pmf(fname);
		
		if(pmf == NULL)
			return 0;
		
		lua_pushlightuserdata(L, pmf);
		return 1;
	} else if(!strcmp(ftype, "tga")) {
		img_t *img = img_load_tga(fname);
		if(img == NULL)
			return 0;
		
		lua_pushlightuserdata(L, img);
		return 1;
	} else if(!strcmp(ftype, "json")) {
		// TODO!
		return luaL_error(L, "format not supported yet!");
	} else if(!strcmp(ftype, "log")) {
		// TODO!
		return luaL_error(L, "format not supported yet!");
	} else {
		return luaL_error(L, "unsupported format for fetch");
	}
		lua_pushlightuserdata(L, img);
		return 1;
	} else if(!strcmp(ftype, "json")) {
		// TODO!
		return luaL_error(L, "format not supported yet!");
	} else if(!strcmp(ftype, "log")) {
		// TODO!
		return luaL_error(L, "format not supported yet!");
	} else {
		return luaL_error(L, "unsupported format for fetch");
	}
}

// common functions
int icelua_fn_common_fetch_start(lua_State *L)
{
	int top = icelua_assert_stack(L, 2, 2);
	const char *ftype = lua_tostring(L, 1);
	const char *fname = lua_tostring(L, 2);
	
	if(L == lstate_server
		? !path_type_server_readable(path_get_type(fname))
		: !path_type_client_readable(path_get_type(fname)))
	{
		return luaL_error(L, "cannot read from there");
	}
	
	return icelua_fnaux_common_fetch_immediate(L, ftype, fname);
}

int icelua_fn_common_fetch_poll(lua_State *L)
{
	// TODO!
	return 0;
}

int icelua_fn_common_fetch_block(lua_State *L)
{
	// TODO: base this on common.fetch_*
	// TODO: run this through a network
	
	int top = icelua_assert_stack(L, 2, 2);
	const char *ftype = lua_tostring(L, 1);
	const char *fname = lua_tostring(L, 2);
	
	if(L == lstate_server
		? !path_type_server_readable(path_get_type(fname))
		: !path_type_client_readable(path_get_type(fname)))
	{
		return luaL_error(L, "cannot read from there");
	}
	
	// TODO: set up network fetching
	return icelua_fnaux_common_fetch_immediate(L, ftype, fname);
}
